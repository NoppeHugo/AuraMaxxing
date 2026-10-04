import Link from "next/link";
import { Avatar } from "@/components/Avatar";
import { leaderboard, trendStats } from "@/lib/store";

export const dynamic = "force-dynamic";

export default async function Home() {
  const [{ players }, trends] = await Promise.all([leaderboard("aura", 3), trendStats()]);
  const topTrend = trends.trends[0];

  return (
    <>
      <section className="hero">
        <div>
          <h1 className="hero-title">
            T&apos;as combien
            <br />
            <span className="gradient-text">d&apos;aura ?</span>
          </h1>
          <p className="page-sub" style={{ fontSize: 18 }}>
            L&apos;IA analyse ton fit, ta vibe et ton énergie. Score sur 1000, tier, trends — puis défie tes potes en
            battle et grimpe au classement.
          </p>
          <div className="hero-ctas">
            <Link href="/scan" className="btn btn-primary">
              Scanner mon aura
            </Link>
            <Link href="/battle" className="btn btn-ghost">
              Battle d&apos;aura
            </Link>
          </div>
        </div>
        <div className="orb">
          <div className="orb-core">847</div>
        </div>
      </section>

      <div className="grid-3">
        <Link href="/scan" className="card feature">
          <span className="feature-icon">01</span>
          <h3>Scan d&apos;aura</h3>
          <p className="muted small" style={{ margin: 0 }}>
            Score de 0 à 1000, du NPC au Mythique, avec stats drip / vibe / confiance et conseils pour monter.
          </p>
        </Link>
        <Link href="/battle" className="card feature">
          <span className="feature-icon">02</span>
          <h3>Battle 1v1</h3>
          <p className="muted small" style={{ margin: 0 }}>
            Cinq rounds commentés par l&apos;IA. Le gagnant prend des points ELO au perdant.
          </p>
        </Link>
        <Link href="/trends" className="card feature">
          <span className="feature-icon">03</span>
          <h3>Trends</h3>
          <p className="muted small" style={{ margin: 0 }}>
            {topTrend
              ? `Trend n°1 en ce moment : ${topTrend.name} (${Math.round(topTrend.share * 100)}% des analyses).`
              : "Old money, streetwear, Y2K… découvre ce qui domine dans la commu."}
          </p>
        </Link>
      </div>

      {players.length > 0 && (
        <>
          <h2 className="section-title">Top aura</h2>
          <div className="card" style={{ padding: 8 }}>
            {players.map((p, i) => (
              <div key={p.id} className="lb-row">
                <span className="lb-rank">{i + 1}</span>
                <Avatar pseudo={p.pseudo} thumb={p.thumb} color={p.auraColor} color2={p.auraColor2} />
                <div className="lb-main">
                  <div className="lb-name">{p.pseudo}</div>
                  <div className="lb-meta">
                    {p.tier}
                  </div>
                </div>
                <span className="lb-score">{p.bestScore}</span>
              </div>
            ))}
          </div>
          <div style={{ textAlign: "center", marginTop: 14 }}>
            <Link href="/classement" className="btn btn-ghost">
              Voir tout le classement
            </Link>
          </div>
        </>
      )}
    </>
  );
}
