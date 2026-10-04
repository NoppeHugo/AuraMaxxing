import { errorResponse } from "../input";
import { authenticate, type User } from "./store";

/** Enveloppe commune des routes de l'API mobile : auth + gestion d'erreurs. */
export function authed(handler: (user: User, request: Request) => Promise<unknown>) {
  return async (request: Request) => {
    try {
      const user = await authenticate(request);
      return Response.json(await handler(user, request));
    } catch (error) {
      return errorResponse(error);
    }
  };
}

export async function body(request: Request): Promise<Record<string, unknown>> {
  try {
    const json = await request.json();
    return json && typeof json === "object" ? json : {};
  } catch {
    return {};
  }
}

/** URL publique du site (liens de défi / d'invitation partagés). */
export function publicUrl(request: Request) {
  return (process.env.AURA_PUBLIC_URL ?? new URL(request.url).origin).replace(/\/$/, "");
}
