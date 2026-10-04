import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { GetAppButtons } from "@/components/GetAppButtons";
import { APP_STORE_URL, challengeDeepLink } from "@/lib/league/links";
import { challengeInfo } from "@/lib/league/store";

export const dynamic = "force-dynamic";

type Props = { params: Promise<{ code: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const c = await challengeInfo((await params).code);
  if (!c) return { title: "Défi introuvable — AuraMaxxing" };
  const title = `${c.from?.pseudo ?? "Quelqu'un"} t'a défié : ${c.score} d'aura`;
  return { title, description: "T'as plus d'aura ? Relève le défi sur AuraMaxxing.", openGraph: { title } };
}

export default async function ChallengePage({ params }: Props) {
  const c = await challengeInfo((await params).code);
  if (!c) notFound();
  const vars = { "--c1": c.auraColor, "--c2": c.auraColor2 } as React.CSSProperties;

  return (
    <div className="stack" style={{ ...vars, alignItems: "center", textAlign: "center", maxWidth: 420, margin: "0 auto", paddingTop: 24 }}>
      <p className="muted" style={{ margin: 0 }}>DÉFI D&apos;AURA</p>
      <h1 className="page-title" style={{ fontSize: 34 }}>
        <span className="gradient-text">@{c.from?.pseudo}</span> t&apos;a défié
      </h1>
      <div className="score-big" style={{ borderBottom: `8px solid ${c.auraColor}`, paddingBottom: 6 }}>
        {c.score}
      </div>
      <span className="tier-badge">
        {c.tier}
      </span>
      <p style={{ margin: 0 }}>« {c.title} »</p>
      <p className="muted">
        {c.expired
          ? "Ce défi a expiré, mais tu peux quand même tester ton aura."
          : c.answers > 0
            ? `${c.answers} personne${c.answers > 1 ? "s ont" : " a"} déjà relevé le défi, ${
                c.beaten === 0 ? "personne ne l'a encore battu" : `${c.beaten} l'${c.beaten > 1 ? "ont" : "a"} battu`
              }. À toi.`
            : "Poste ta vidéo, l'IA compare. T'as plus d'aura ?"}
      </p>
      <GetAppButtons code={c.code} appStoreUrl={APP_STORE_URL} deepLink={challengeDeepLink(c.code)} />
    </div>
  );
}
