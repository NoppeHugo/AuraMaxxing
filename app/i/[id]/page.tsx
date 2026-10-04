import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { GetAppButtons } from "@/components/GetAppButtons";
import { APP_STORE_URL, inviteDeepLink } from "@/lib/league/links";
import { inviterInfo } from "@/lib/league/store";

export const dynamic = "force-dynamic";

type Props = { params: Promise<{ id: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const u = await inviterInfo((await params).id);
  const title = u ? `${u.pseudo} t'invite sur AuraMaxxing` : "AuraMaxxing";
  return { title, description: "T'as combien d'aura ? L'IA note ta vidéo, et chaque semaine tu affrontes 30 joueurs de ton niveau.", openGraph: { title } };
}

export default async function InvitePage({ params }: Props) {
  const u = await inviterInfo((await params).id);
  if (!u) notFound();

  return (
    <div className="stack" style={{ alignItems: "center", textAlign: "center", maxWidth: 420, margin: "0 auto", paddingTop: 24 }}>
      <div className="orb" style={{ width: 180 }}>
        <div className="orb-core">🗿</div>
      </div>
      <h1 className="page-title" style={{ fontSize: 34 }}>
        <span className="gradient-text">@{u.pseudo}</span> t&apos;invite
      </h1>
      <p className="muted" style={{ margin: 0 }}>
        {u.league.emoji} {u.league.name}
        {u.bestScore > 0 ? ` · record de ${u.bestScore} d'aura` : ""}
      </p>
      <p>
        Poste une vidéo, l&apos;IA te donne ton score d&apos;aura sur 1000. Chaque semaine, tu affrontes 30 joueurs de ton
        niveau : le top 7 monte de ligue.
      </p>
      <GetAppButtons code={u.code} appStoreUrl={APP_STORE_URL} deepLink={inviteDeepLink(u.code)} />
    </div>
  );
}
