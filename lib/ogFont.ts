/**
 * Police condensée pour les images d'aperçu (next/og ne lit pas le woff2 de next/font).
 * Téléchargée une fois depuis Google Fonts puis gardée en mémoire ; en cas d'échec,
 * l'image est rendue avec la police par défaut.
 */
let cache: Promise<ArrayBuffer | null> | null = null;

export function displayFont(): Promise<ArrayBuffer | null> {
  cache ??= (async () => {
    try {
      const css = await fetch("https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@800").then((r) => r.text());
      const url = /src: url\((.+?)\) format\('(?:opentype|truetype)'\)/.exec(css)?.[1];
      return url ? await fetch(url).then((r) => r.arrayBuffer()) : null;
    } catch {
      return null;
    }
  })();
  return cache;
}
