import { AuraError, analyzeVideo, type ImageInput } from "@/lib/ai";
import { errorResponse, parseCaption, parseImage, parseThumb, rateLimit } from "@/lib/input";
import { body } from "@/lib/league/http";
import { assertCanUpload, authenticate, recordVideo, themeOfDay } from "@/lib/league/store";

export const runtime = "nodejs";
export const maxDuration = 120;

const MIN_FRAMES = 3;
const MAX_FRAMES = 12;
const MAX_DURATION = 90;

/**
 * L'iPhone extrait les images clés de la vidéo (la vidéo elle-même n'est jamais envoyée)
 * et les poste ici avec leurs timestamps.
 */
export async function POST(request: Request) {
  try {
    rateLimit(request, 6);
    const user = await authenticate(request);
    await assertCanUpload(user);

    const b = await body(request);
    const rawFrames = Array.isArray(b.frames) ? b.frames : [];
    if (rawFrames.length < MIN_FRAMES || rawFrames.length > MAX_FRAMES) {
      throw new AuraError(`La vidéo doit être envoyée en ${MIN_FRAMES} à ${MAX_FRAMES} images clés.`);
    }
    const frames: ImageInput[] = rawFrames.map((f) => parseImage(f, "une image de la vidéo"));
    const duration = Number(b.duration);
    if (!Number.isFinite(duration) || duration <= 0 || duration > MAX_DURATION) {
      throw new AuraError(`La vidéo doit durer moins de ${MAX_DURATION} secondes.`);
    }
    const timestamps = Array.isArray(b.timestamps) ? b.timestamps.map(Number) : [];

    const analysis = await analyzeVideo({
      frames,
      timestamps,
      duration,
      caption: parseCaption(b.caption),
      theme: themeOfDay().title,
    });
    const challengeCode = typeof b.challengeCode === "string" ? b.challengeCode : undefined;
    const result = await recordVideo(
      user,
      analysis,
      { consent: b.coverConsent === true, image: parseThumb(b.cover) },
      challengeCode,
    );
    return Response.json({ analysis, ...result });
  } catch (error) {
    return errorResponse(error);
  }
}
