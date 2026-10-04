"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Confetti } from "@/components/Confetti";
import { CountUp } from "@/components/CountUp";
import { PhotoPicker, type Photo } from "@/components/PhotoPicker";
import { StatBars } from "@/components/StatBars";
import type { AuraAnalysis } from "@/lib/schemas";
import { makeShareCard, shareOrDownload } from "@/lib/shareCard";

type Result = { analysis: AuraAnalysis; isRecord: boolean; rank: number };

const LOADING_MSGS = [
  "Calibrage du détecteur d'aura…",
  "Analyse du drip en cours…",
  "Mesure de l'énergie main character…",
  "Comparaison avec les trends du moment…",
  "Calcul des points d'aura…",
];

export default function ScanPage() {
  const [pseudo, setPseudo] = useState("");
  const [caption, setCaption] = useState("");
  const [showPhoto, setShowPhoto] = useState(false);
  const [photo, setPhoto] = useState<Photo | null>(null);
  const [loading, setLoading] = useState(false);
  const [msg, setMsg] = useState(0);
  const [error, setError] = useState("");
  const [result, setResult] = useState<Result | null>(null);

  useEffect(() => {
    try {
      setPseudo(localStorage.getItem("aura-pseudo") ?? "");
    } catch {}
  }, []);

  useEffect(() => {
    if (!loading) return;
    const id = setInterval(() => setMsg((m) => (m + 1) % LOADING_MSGS.length), 1800);
    return () => clearInterval(id);
  }, [loading]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!photo) return setError("Ajoute une photo d'abord.");
    setError("");
    setLoading(true);
    setMsg(0);
    try {
      localStorage.setItem("aura-pseudo", pseudo.trim());
    } catch {}
    try {
      const res = await fetch("/api/scan", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pseudo, caption, showPhoto, image: photo.image, thumb: photo.thumb }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Erreur inconnue");
      setResult(data);
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erreur réseau");
    } finally {
      setLoading(false);
    }
  };

  if (result && photo) {
    return <ScanResult result={result} photo={photo.preview} pseudo={pseudo} onRetry={() => setResult(null)} />;
  }

  if (loading && photo) {
    return (
      <div className="stack" style={{ alignItems: "center", paddingTop: 40, textAlign: "center" }}>
        <div className="scanning">
          <img src={photo.preview} alt="" />
          <div className="scan-grid" />
          <div className="scan-line" />
        </div>
        <p key={msg} className="loading-msg">
          {LOADING_MSGS[msg]}
        </p>
      </div>
    );
  }

  return (
    <>
      <h1 className="page-title">
        Scanne ton <span className="gradient-text">aura</span>
      </h1>
      <p className="page-sub">Une photo, et l&apos;IA te donne ton score d&apos;aura, ton tier et tes trends.</p>
      <form onSubmit={submit} className="grid-2" style={{ alignItems: "start" }}>
        <PhotoPicker photo={photo} onChange={setPhoto} />
        <div className="stack">
          <div className="field">
            <label htmlFor="pseudo">Pseudo</label>
            <input
              id="pseudo"
              className="input"
              value={pseudo}
              onChange={(e) => setPseudo(e.target.value)}
              placeholder="ex. sigma_leo"
              maxLength={20}
              required
            />
          </div>
          <div className="field">
            <label htmlFor="caption">Légende (optionnel)</label>
            <input
              id="caption"
              className="input"
              value={caption}
              onChange={(e) => setCaption(e.target.value)}
              placeholder="ex. fit du jour pour la soirée"
              maxLength={140}
            />
          </div>
          <label className="check">
            <input type="checkbox" checked={showPhoto} onChange={(e) => setShowPhoto(e.target.checked)} />
            Afficher ma photo en miniature dans le classement (sinon, juste mes initiales)
          </label>
          {error && <div className="error">{error}</div>}
          <button className="btn btn-primary btn-block" disabled={!photo || pseudo.trim().length < 2}>
            Lancer le scan
          </button>
          <p className="muted small">
            L&apos;IA juge le style, la vibe et l&apos;attitude — jamais le physique. La photo sert uniquement à
            l&apos;analyse et n&apos;est pas stockée par l&apos;app (sauf la miniature si tu l&apos;acceptes).
          </p>
        </div>
      </form>
    </>
  );
}

function ScanResult({
  result,
  photo,
  pseudo,
  onRetry,
}: {
  result: Result;
  photo: string;
  pseudo: string;
  onRetry: () => void;
}) {
  const a = result.analysis;
  const [sharing, setSharing] = useState(false);
  const colors = [a.aura_color, a.aura_color_2, "#ffffff"];
  const vars = { "--c1": a.aura_color, "--c2": a.aura_color_2 } as React.CSSProperties;

  const share = async () => {
    setSharing(true);
    try {
      await shareOrDownload(await makeShareCard(photo, pseudo, a), `aura-${pseudo}.png`);
    } finally {
      setSharing(false);
    }
  };

  return (
    <div className="stack" style={{ ...vars, alignItems: "center", textAlign: "center" }}>
      {a.aura_score >= 600 && <Confetti colors={colors} />}
      <div className="aura-wrap" style={{ margin: "40px 0 10px" }}>
        <img className="aura-photo" src={photo} alt="Ta photo" />
      </div>

      <div className="score-big">
        <CountUp to={a.aura_score} />
      </div>
      <div className="muted small" style={{ marginTop: -8 }}>
        points d&apos;aura
      </div>
      <span className="tier-badge" style={{ animationDelay: "1.4s" }}>
        {a.tier}
      </span>
      <h2 className="reveal" style={{ animationDelay: "1.6s", fontSize: 24 }}>
        {a.title}
      </h2>
      <p className="reveal muted" style={{ animationDelay: "1.7s", margin: 0 }}>
        {result.isRecord ? "Nouveau record perso ! " : ""}#{result.rank} au classement Aura
      </p>

      <div className="grid-2 reveal" style={{ width: "100%", textAlign: "left", animationDelay: "1.8s" }}>
        <div className="card stack">
          <h3>Stats</h3>
          <StatBars stats={a.stats} />
        </div>
        <div className="card stack">
          <h3>Trends détectées</h3>
          <div className="chips">
            {a.trends.map((t) => (
              <span key={t.name} className="chip">
                {t.name}
                <b>{t.confidence}%</b>
              </span>
            ))}
          </div>
          <div className="quote">
            <div className="quote-label">Hype</div>
            {a.hype}
          </div>
          <div className="quote">
            <div className="quote-label">Roast</div>
            {a.roast}
          </div>
        </div>
      </div>

      <div className="card reveal" style={{ width: "100%", textAlign: "left", animationDelay: "2s" }}>
        <h3 style={{ marginBottom: 10 }}>Comment gagner +aura</h3>
        <ul style={{ margin: 0, paddingLeft: 20, lineHeight: 1.7 }}>
          {a.tips.map((t) => (
            <li key={t}>{t}</li>
          ))}
        </ul>
      </div>

      <div className="hero-ctas" style={{ justifyContent: "center", marginTop: 8 }}>
        <button className="btn btn-primary" onClick={share} disabled={sharing}>
          {sharing ? "Création…" : "Partager ma carte"}
        </button>
        <Link href="/battle" className="btn btn-ghost">
          Défier un pote
        </Link>
        <button className="btn btn-ghost" onClick={onRetry}>
          Rescanner
        </button>
      </div>
    </div>
  );
}
