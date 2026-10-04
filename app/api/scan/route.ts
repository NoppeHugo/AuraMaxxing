import { analyzeAura } from "@/lib/ai";
import { errorResponse, parseCaption, parseImage, parsePseudo, parseThumb, rateLimit } from "@/lib/input";
import { recordScan } from "@/lib/store";

export const runtime = "nodejs";
export const maxDuration = 120;

export async function POST(request: Request) {
  try {
    rateLimit(request);
    const body = await request.json();
    const pseudo = parsePseudo(body.pseudo);
    const image = parseImage(body.image);
    const showPhoto = body.showPhoto === true;

    const analysis = await analyzeAura(image, parseCaption(body.caption));
    const { player, isRecord, rank } = await recordScan(pseudo, analysis, parseThumb(body.thumb), showPhoto);
    return Response.json({ analysis, player, isRecord, rank });
  } catch (error) {
    return errorResponse(error);
  }
}
