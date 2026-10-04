"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Confetti } from "@/components/Confetti";
import { CountUp } from "@/components/CountUp";
import { PhotoPicker, type Photo } from "@/components/PhotoPicker";
import { STAT_LABELS, type BattleVerdict } from "@/lib/schemas";

type Fighter = { pseudo: string; photo: Photo | null; showPhoto: boolean };
type PlayerResult = { pseudo: string; elo: number; eloBefore: number };
type Result = { verdict: BattleVerdict; eloDelta: number; a: PlayerResult; b: PlayerResult };

const empty = (): Fighter => ({ pseudo: "", photo: null, showPhoto: false });
const ROUND_DELAY = 900;

export default function BattlePage() {
  const [a, setA] = useState<Fighter>(empty);
  const [b, setB] = useState<Fighter>(empty);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [result, setResult] = useState<Result | null>(null);
  const [shownRounds, setShownRounds] = useState(0);

  useEffect(() => {
    try {
      const saved = localStorage.getItem("aura-pseudo");
      if (saved) setA((f) => ({ ...f, pseudo: saved }));
    } catch {}
  }, []);

  // Révèle les rounds un par un pour le suspense.
  useEffect(() => {
    if (!result) return;
    setShownRounds(0);
    const id = setInterval(() => setShownRounds((n) => (n > result.verdict.rounds.length ? n : n + 1)), ROUND_DELAY);
    return () => clearInterval(id);
  }, [result]);

  const ready = a.photo && b.photo && a.pseudo.trim().length >= 2 && b.pseudo.trim().length >= 2;

  const fight = async () => {
    if (!ready) return;
    setError("");
    setLoading(true);
    try {
      const side = (f: Fighter) => ({ pseudo: f.pseudo, image: f.photo!.image, thumb: f.photo!.thumb, showPhoto: f.showPhoto });
      const res = await fetch("/api/battle", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ a: side(a), b: side(b) }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Erreur inconnue");
      setResult(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erreur réseau");
    } finally {
      setLoading(false);
    }
  };

  const reset = () => {
    setResult(null);
    setB(empty());
  };

  if (result) return <BattleResult result={result} a={a} b={b} shownRounds={shownRounds} onReset={reset} />;

  return (
    <>
      <h1 className="page-title">
        Battle <span className="gradient-text">d&apos;aura</span>
      </h1>
      <p className="page-sub">Deux photos, cinq rounds, un seul gagnant. L&apos;IA arbitre, le classement ELO bouge.</p>

      <div className="battle-grid">
        <FighterSlot label="Joueur 1" fighter={a} onChange={setA} fighting={loading} side="left" />
        <div className="vs">VS</div>
        <FighterSlot label="Joueur 2" fighter={b} onChange={setB} fighting={loading} side="right" />
      </div>

      {error && (
        <div className="error" style={{ marginTop: 16 }}>
          {error}
        </div>
      )}
      <button className="btn btn-primary btn-block" style={{ marginTop: 20 }} disabled={!ready || loading} onClick={fight}>
        {loading ? "⚡ Combat en cours…" : "⚔️ Lancer la battle"}
      </button>
    </>
  );
}

function FighterSlot({
  label,
  fighter,
  onChange,
  fighting,
  side,
}: {
  label: string;
  fighter: Fighter;
  onChange: (f: Fighter) => void;
  fighting: boolean;
  side: "left" | "right";
}) {
  if (fighting && fighter.photo) {
    return (
      <div className={`fighter fighting ${side}`}>
        <img src={fighter.photo.preview} alt="" />
        <div className="fighter-name">{fighter.pseudo}</div>
      </div>
    );
  }
  return (
    <div className="stack" style={{ gap: 10 }}>
      <PhotoPicker photo={fighter.photo} onChange={(photo) => onChange({ ...fighter, photo })} label={label} />
      <input
        className="input"
        placeholder={`Pseudo ${label.toLowerCase()}`}
        value={fighter.pseudo}
        maxLength={20}
        onChange={(e) => onChange({ ...fighter, pseudo: e.target.value })}
      />
      <label className="check small">
        <input
          type="checkbox"
          checked={fighter.showPhoto}
          onChange={(e) => onChange({ ...fighter, showPhoto: e.target.checked })}
        />
        Photo visible au classement
      </label>
    </div>
  );
}

function BattleResult({
  result,
  a,
  b,
  shownRounds,
  onReset,
}: {
  result: Result;
  a: Fighter;
  b: Fighter;
  shownRounds: number;
  onReset: () => void;
}) {
  const v = result.verdict;
  const done = shownRounds > v.rounds.length;
  const winsA = v.rounds.slice(0, shownRounds).filter((r) => r.winner === "A").length;
  const winsB = Math.min(shownRounds, v.rounds.length) - winsA;
  const winnerColor = v.winner === "A" ? v.aura_color_a : v.aura_color_b;

  const card = (f: Fighter, key: "A" | "B", color: string) => (
    <div
      className={`fighter ${done ? (v.winner === key ? "winner" : "loser") : ""}`}
      style={{ "--c1": color } as React.CSSProperties}
    >
      <img src={f.photo!.preview} alt="" />
      {done && v.winner === key && <div className="crown">👑</div>}
      <div className="fighter-name">
        {f.pseudo}
        {done && (
          <div className="small" style={{ fontWeight: 600 }}>
            <CountUp to={key === "A" ? v.score_a : v.score_b} duration={1000} /> aura
          </div>
        )}
      </div>
    </div>
  );

  const eloLine = (p: PlayerResult) => {
    const d = p.elo - p.eloBefore;
    return (
      <div>
        <strong>{p.pseudo}</strong> · {p.elo} ELO{" "}
        <span className={d >= 0 ? "delta-up" : "delta-down"}>
          ({d >= 0 ? "+" : ""}
          {d})
        </span>
      </div>
    );
  };

  return (
    <div className="stack">
      {done && <Confetti colors={[winnerColor, "#ffd25e", "#ffffff"]} />}
      <div className="battle-grid">
        {card(a, "A", v.aura_color_a)}
        <div style={{ textAlign: "center" }}>
          <div className="vs" style={{ animation: "none" }}>
            {winsA}-{winsB}
          </div>
        </div>
        {card(b, "B", v.aura_color_b)}
      </div>

      <div className="stack" style={{ gap: 8 }}>
        {v.rounds.slice(0, shownRounds).map((r, i) => (
          <div key={r.category} className="round">
            <span className="round-side">{r.winner === "A" ? "✅" : "·"}</span>
            <span className="round-cat">
              Round {i + 1} · {STAT_LABELS[r.category]}
            </span>
            <span className="round-side right">{r.winner === "B" ? "✅" : "·"}</span>
            <span className="round-comment">{r.comment}</span>
          </div>
        ))}
        {!done && <p className="muted small" style={{ textAlign: "center" }}>Round suivant…</p>}
      </div>

      {done && (
        <div className="card stack reveal" style={{ textAlign: "center" }}>
          <div className="quote-label">Coup final : {v.finisher}</div>
          <h2 style={{ fontSize: 28 }}>
            🏆 {v.winner === "A" ? a.pseudo : b.pseudo} gagne la battle !
          </h2>
          <p style={{ margin: 0 }}>{v.verdict}</p>
          <div className="grid-2 small" style={{ textAlign: "left" }}>
            {eloLine(result.a)}
            <div style={{ textAlign: "right" }}>{eloLine(result.b)}</div>
          </div>
          <div className="hero-ctas" style={{ justifyContent: "center", marginTop: 0 }}>
            <button className="btn btn-primary" onClick={onReset}>
              ⚔️ Nouvelle battle
            </button>
            <Link className="btn btn-ghost" href="/classement">
              🏆 Voir le classement
            </Link>
          </div>
        </div>
      )}
    </div>
  );
}
