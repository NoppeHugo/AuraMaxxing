import { authed, body, publicUrl } from "@/lib/league/http";
import { createChallenge, myChallenges } from "@/lib/league/store";

export const dynamic = "force-dynamic";

export const GET = authed((user) => myChallenges(user));

/** Crée un défi à partir d'une de mes vidéos et renvoie le lien à partager. */
export const POST = authed(async (user, request) => {
  const challenge = await createChallenge(user, (await body(request)).videoId);
  const url = `${publicUrl(request)}/d/${challenge.code}`;
  return {
    ...challenge,
    url,
    shareText: `J'ai ${challenge.score} d'aura sur AuraMaxxing 🗿 Tu fais mieux ? Relève le défi (code ${challenge.code}) : ${url} #AuraDuJour`,
  };
});
