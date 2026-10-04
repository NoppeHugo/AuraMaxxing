import { challengeInfo } from "@/lib/league/store";

export const dynamic = "force-dynamic";

/** Infos publiques d'un défi (page web du lien + écran « on t'a défié » dans l'app). */
export async function GET(_request: Request, { params }: { params: Promise<{ code: string }> }) {
  const info = await challengeInfo((await params).code);
  return info ? Response.json(info) : Response.json({ error: "Défi introuvable." }, { status: 404 });
}
