import Link from "next/link";
import { StatBars } from "@/components/StatBars";
import { trendStats } from "@/lib/store";

export const dynamic = "force-dynamic";

const pct = (n: number) => `${Math.round(n * 100)}%`;

export default async function TrendsPage() {
  const s = await trendStats();
  const max = Math.max(1, ...s.trends.map((t) => t.count));

  return (
    <>
      <h1 className="page-title">
        Les <span className="gradient-text">trends</span> du moment
      </h1>
      <p className="page-sub">Ce que l&apos;IA détecte dans toutes les photos analysées sur AuraMaxxing.</p>

      <div className="grid-3">
        <div className="card kpi">
          <span className="kpi-value">{s.totalAnalyses}</span>
          <span className="kpi-label">photos analysées</span>
        </div>
        <div className="card kpi">
          <span className="kpi-value">{s.totalBattles}</span>
          <span className="kpi-label">battles jouées</span>
        </div>
        <div className="card kpi">
          <span className="kpi-value">{s.avgAura}</span>
          <span className="kpi-label">aura moyenne</span>
        </div>
      </div>

      {s.trends.length === 0 ? (
        <div className="card empty" style={{ marginTop: 20 }}>
          <p>Pas encore assez de données. Lance des scans pour faire émerger les trends.</p>
          <Link className="btn btn-primary" href="/scan">
            🔮 Scanner mon aura
          </Link>
        </div>
      ) : (
        <>
          <h2 className="section-title">Trends les plus portées</h2>
          <div className="card" style={{ padding: "8px 16px" }}>
            {s.trends.map((t, i) => (
              <div key={t.name} className="trend-row" tabIndex={0}>
                <span className="lb-rank">{i + 1}</span>
                <strong>
                  {t.name}{" "}
                  {t.momentum > 0 && <span className="delta-up small">▲ {t.momentum}</span>}
                  {t.momentum < 0 && <span className="delta-down small">▼ {-t.momentum}</span>}
                </strong>
                <span className="small muted">
                  {pct(t.share)} · {t.count}
                </span>
                <div className="trend-bar-track">
                  <div className="trend-bar" style={{ width: `${(t.count / max) * 100}%`, animationDelay: `${i * 0.05}s` }} />
                </div>
                <div className="tooltip">
                  <strong>{t.name}</strong> — {t.count} analyses ({pct(t.share)})
                  <br />
                  Aura moyenne : {t.avgAura} · 7 j vs 7 j précédents : {t.momentum >= 0 ? "+" : ""}
                  {t.momentum}
                </div>
              </div>
            ))}
          </div>

          <div className="grid-2" style={{ marginTop: 20 }}>
            <div className="card stack">
              <h3>🚀 En hausse cette semaine</h3>
              {s.rising.length ? (
                s.rising.map((t) => (
                  <div key={t.name} style={{ display: "flex", justifyContent: "space-between" }}>
                    <span>{t.name}</span>
                    <span className="delta-up">+{t.momentum}</span>
                  </div>
                ))
              ) : (
                <p className="muted small">Rien ne décolle encore — reviens dans quelques jours.</p>
              )}
            </div>
            <div className="card stack">
              <h3>👑 Trends qui donnent le plus d&apos;aura</h3>
              {s.bestAura.length ? (
                s.bestAura.map((t) => (
                  <div key={t.name} style={{ display: "flex", justifyContent: "space-between" }}>
                    <span>{t.name}</span>
                    <strong>{t.avgAura}</strong>
                  </div>
                ))
              ) : (
                <p className="muted small">Il faut au moins 2 analyses par trend.</p>
              )}
            </div>
          </div>

          {Object.keys(s.avgStats).length > 0 && (
            <div className="card stack" style={{ marginTop: 20 }}>
              <h3>Stats moyennes de la communauté</h3>
              <StatBars stats={s.avgStats} />
            </div>
          )}
        </>
      )}
    </>
  );
}
