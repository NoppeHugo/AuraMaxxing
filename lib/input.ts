import { AuraError, type ImageInput } from "./ai";

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_THUMB_CHARS = 60_000;
const DATA_URL = /^data:(image\/(?:jpeg|png|webp));base64,([A-Za-z0-9+/=]+)$/;

export function parseImage(value: unknown, label = "la photo"): ImageInput {
  const match = typeof value === "string" ? DATA_URL.exec(value) : null;
  if (!match) throw new AuraError(`Ajoute ${label} (JPEG, PNG ou WebP).`);
  if ((match[2].length * 3) / 4 > MAX_IMAGE_BYTES) throw new AuraError("Image trop lourde (5 Mo max).");
  return { mediaType: match[1] as ImageInput["mediaType"], data: match[2] };
}

export function parseThumb(value: unknown): string | undefined {
  return typeof value === "string" && value.length < MAX_THUMB_CHARS && DATA_URL.test(value) ? value : undefined;
}

export function parsePseudo(value: unknown, label = "ton pseudo"): string {
  const pseudo = typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
  if (pseudo.length < 2 || pseudo.length > 20 || !/[a-z0-9]/i.test(pseudo)) {
    throw new AuraError(`Choisis ${label} (2 à 20 caractères).`);
  }
  return pseudo;
}

export function parseCaption(value: unknown): string {
  return typeof value === "string" ? value.trim().slice(0, 140) : "";
}

// Limiteur de débit en mémoire, par IP : protège la facture API d'un spam de clics.
const hits = new Map<string, number[]>();
export function rateLimit(request: Request, max = 10, windowMs = 60_000) {
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "local";
  const now = Date.now();
  const recent = (hits.get(ip) ?? []).filter((t) => now - t < windowMs);
  if (recent.length >= max) throw new AuraError("Doucement ! Attends une minute avant de relancer.", 429);
  recent.push(now);
  hits.set(ip, recent);
}

export function errorResponse(error: unknown) {
  if (error instanceof AuraError) return Response.json({ error: error.message }, { status: error.status });
  console.error(error);
  return Response.json({ error: "Erreur interne, réessaie." }, { status: 500 });
}
