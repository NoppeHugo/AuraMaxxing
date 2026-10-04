/** Liens de l'app iOS (à régler une fois l'app publiée). */
export const APP_STORE_URL = process.env.AURA_APP_STORE_URL ?? "https://apps.apple.com/app/auramaxxing";
export const challengeDeepLink = (code: string) => `auramaxxing://challenge/${code}`;
export const inviteDeepLink = (code: string) => `auramaxxing://invite/${encodeURIComponent(code)}`;
