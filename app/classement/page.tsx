"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Avatar } from "@/components/Avatar";
import type { Player } from "@/lib/store";

type Battle = { id: string; a: string; b: string; winner: string; eloDelta: number; verdict: string };
type Board = { players: Player[]; recentBattles: Battle[] };
type Mode = "elo" | "aura";

export default function ClassementPage() {
  const [mode, setMode] = useState<Mode>("elo");
  const [board, setBoard] = useState<Board | null>(null);

  useEffect(() => {
    setBoard(null);
    fetch(`/api/leaderboard?by=${mode}`)
      .then((r) => r.json())
      .then(setBoard)
      .catch(() => setBoard({ players: [], recentBattles: [] }));
  }, [mode]);

  const value = (p: Player) => (mode === "elo" ? p.elo : p.bestScore);
  const meta = (p: Player) =>
    mode === "elo" ? `${p.wins}V · ${p.losses}D · ${p.tier}` : `${p.emoji} ${p.tier}${p.title ? ` · ${p.title}` : ""}`;
  const players = board?.players ?? [];
  const podium = [players[1], players[0], players[2]];

  return (
    <>
      <h1 className="page-title">
        <span className="gradient-text">Classement</span>
      </h1>
      <p className="page-sub">Qui a le plus d&apos;aura ? ELO des battles ou meilleur score de scan.</p>

      <div className="tabs" role="tablist">
        {(["elo", "aura"] as const).map((m) => (
          <button key={m} role="tab" aria-selected={mode === m} className={`tab ${mode === m ? "active" : ""}`} onClick={() => setMode(m)}>
            {m === "elo" ? "⚔️ ELO Battle" : "🔮 Aura max"}
          </button>
        ))}
      </div>

      {!board ? (
        <p className="muted">Chargement…</p>
      ) : players.length === 0 ? (
        <div className="card empty">
          <p>Personne au classement pour l&apos;instant.</p>
          <Link className="btn btn-primary" href={mode === "elo" ? "/battle" : "/scan"}>
            Sois le premier
          </Link>
        </div>
      ) : (
        <>
          <div className="podium">
            {podium.map((p, i) => {
              if (!p) return <div key={i} />;
              const place = i === 1 ? 1 : i === 0 ? 2 : 3;
              return (
                <div key={p.id} className="podium-spot" style={{ animationDelay: `${place * 0.15}s` }}>
                  <div style={{ fontSize: 26 }}>{["🥇", "🥈", "🥉"][place - 1]}</div>
                  <Avatar pseudo={p.pseudo} thumb={p.thumb} color={p.auraColor} color2={p.auraColor2} size={place === 1 ? 76 : 60} />
                  <div className="podium-name">{p.pseudo}</div>
                  <div className="lb-score">{value(p)}</div>
                  <div className="podium-block" style={{ height: [110, 80, 60][place - 1] }}>
                    {place}
                  </div>
                </div>
              );
            })}
          </div>

          <div className="card" style={{ padding: 8 }}>
            {players.slice(3).map((p, i) => (
              <div key={p.id} className="lb-row" style={{ animationDelay: `${Math.min(i, 15) * 0.03}s` }}>
                <span className="lb-rank">{i + 4}</span>
                <Avatar pseudo={p.pseudo} thumb={p.thumb} color={p.auraColor} color2={p.auraColor2} />
                <div className="lb-main">
                  <div className="lb-name">{p.pseudo}</div>
                  <div className="lb-meta">{meta(p)}</div>
                </div>
                <span className="lb-score">{value(p)}</span>
              </div>
            ))}
            {players.length <= 3 && <p className="muted small" style={{ textAlign: "center" }}>Plus de joueurs bientôt…</p>}
          </div>
        </>
      )}

      {board && board.recentBattles.length > 0 && (
        <>
          <h2 className="section-title">Dernières battles</h2>
          <div className="stack" style={{ gap: 8 }}>
            {board.recentBattles.map((b) => (
              <div key={b.id} className="card small" style={{ padding: 14 }}>
                <strong>{b.winner}</strong> a battu <strong>{b.winner === b.a ? b.b : b.a}</strong>{" "}
                <span className="delta-up">+{b.eloDelta}</span>
                <div className="muted" style={{ marginTop: 4 }}>{b.verdict}</div>
              </div>
            ))}
          </div>
        </>
      )}
    </>
  );
}
