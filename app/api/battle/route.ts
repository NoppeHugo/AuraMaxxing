import { AuraError, judgeBattle } from "@/lib/ai";
import { errorResponse, parseImage, parsePseudo, parseThumb, rateLimit } from "@/lib/input";
import { playerId, recordBattle } from "@/lib/store";

export const runtime = "nodejs";
export const maxDuration = 120;

export async function POST(request: Request) {
  try {
    rateLimit(request);
    const body = await request.json();
    const pseudoA = parsePseudo(body.a?.pseudo, "le pseudo du joueur 1");
    const pseudoB = parsePseudo(body.b?.pseudo, "le pseudo du joueur 2");
    if (playerId(pseudoA) === playerId(pseudoB)) throw new AuraError("Les deux joueurs doivent avoir des pseudos différents.");
    const imageA = parseImage(body.a?.image, "la photo du joueur 1");
    const imageB = parseImage(body.b?.image, "la photo du joueur 2");

    const verdict = await judgeBattle(imageA, imageB, pseudoA, pseudoB);
    const result = await recordBattle(
      { pseudo: pseudoA, thumb: parseThumb(body.a.thumb), showPhoto: body.a.showPhoto === true },
      { pseudo: pseudoB, thumb: parseThumb(body.b.thumb), showPhoto: body.b.showPhoto === true },
      verdict,
    );
    return Response.json({ verdict, ...result });
  } catch (error) {
    return errorResponse(error);
  }
}
