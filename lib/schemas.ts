import { z } from "zod";

/** Trends suivies par l'app. L'IA doit choisir parmi cette liste pour que les stats restent agrégeables. */
export const TRENDS = [
  "Old Money",
  "Quiet Luxury",
  "Streetwear",
  "Baggy / Skate",
  "Y2K",
  "Clean Girl / Clean Boy",
  "Gorpcore",
  "Techwear",
  "Opium / Dark",
  "Coquette",
  "Dark Academia",
  "Blokecore",
  "Sporty / Athleisure",
  "Vintage / Thrift",
  "Minimaliste",
  "E-girl / E-boy",
  "Cottagecore",
  "Autre",
] as const;

export const TIERS = [
  "NPC",
  "En chargement",
  "Lowkey Aura",
  "Main Character",
  "Aura Farmer",
  "Mythique",
] as const;

export const STAT_KEYS = ["drip", "vibe", "confiance", "originalite", "trend_fit"] as const;
export type StatKey = (typeof STAT_KEYS)[number];

export const STAT_LABELS: Record<StatKey, string> = {
  drip: "Drip",
  vibe: "Vibe",
  confiance: "Confiance",
  originalite: "Originalité",
  trend_fit: "Trend fit",
};

const Stats = z.object({
  drip: z.number().int().describe("Style / tenue, 0 à 100"),
  vibe: z.number().int().describe("Énergie générale de la photo, 0 à 100"),
  confiance: z.number().int().describe("Assurance de la pose et de l'attitude, 0 à 100"),
  originalite: z.number().int().describe("Créativité, prise de risque, 0 à 100"),
  trend_fit: z.number().int().describe("À quel point c'est dans les trends actuelles, 0 à 100"),
});

export const AuraAnalysisSchema = z.object({
  aura_score: z.number().int().describe("Score d'aura global, de 0 à 1000"),
  tier: z.enum(TIERS),
  title: z.string().describe("Surnom court et stylé, ex. « Le Prince du Quiet Luxury »"),
  emoji: z.string().describe("Un seul emoji qui résume l'aura"),
  aura_color: z.string().describe("Couleur principale de l'aura en hex #RRGGBB"),
  aura_color_2: z.string().describe("Couleur secondaire de l'aura en hex #RRGGBB"),
  stats: Stats,
  trends: z
    .array(z.object({ name: z.enum(TRENDS), confidence: z.number().int().describe("0 à 100") }))
    .describe("1 à 3 trends détectées, de la plus évidente à la moins évidente"),
  hype: z.string().describe("Une phrase qui hype la personne, 25 mots max"),
  roast: z.string().describe("Un petit roast gentil sur la tenue / le décor / la pose, 25 mots max"),
  tips: z.array(z.string()).describe("2 ou 3 conseils concrets pour gagner de l'aura"),
});
export type AuraAnalysis = z.infer<typeof AuraAnalysisSchema>;

export const BattleVerdictSchema = z.object({
  winner: z.enum(["A", "B"]),
  rounds: z
    .array(
      z.object({
        category: z.enum(STAT_KEYS),
        winner: z.enum(["A", "B"]),
        comment: z.string().describe("Commentaire façon commentateur sportif, 15 mots max"),
      }),
    )
    .describe("Exactement un round par catégorie, dans l'ordre drip, vibe, confiance, originalite, trend_fit"),
  score_a: z.number().int().describe("Score d'aura du joueur A, 0 à 1000"),
  score_b: z.number().int().describe("Score d'aura du joueur B, 0 à 1000"),
  aura_color_a: z.string().describe("Couleur d'aura du joueur A en hex #RRGGBB"),
  aura_color_b: z.string().describe("Couleur d'aura du joueur B en hex #RRGGBB"),
  trends_a: z.array(z.enum(TRENDS)).describe("1 à 2 trends du joueur A"),
  trends_b: z.array(z.enum(TRENDS)).describe("1 à 2 trends du joueur B"),
  verdict: z.string().describe("Verdict final hype, 35 mots max"),
  finisher: z.string().describe("Nom du « coup final » qui a fait gagner, ex. « Combo Drip Ultime »"),
});
export type BattleVerdict = z.infer<typeof BattleVerdictSchema>;

/** Analyse d'une vidéo (envoyée sous forme d'images clés extraites sur l'iPhone). */
export const VideoAuraSchema = AuraAnalysisSchema.extend({
  content_ok: z
    .boolean()
    .describe("false si la vidéo contient de la nudité, de la violence, un danger, de la haine ou du harcèlement"),
  theme_match: z.boolean().describe("true si la vidéo correspond clairement au thème du jour"),
  peak_frame: z.number().int().describe("Index (à partir de 0) de l'image clé où l'aura est la plus forte"),
  peak_moment: z.string().describe("Ce qui se passe au moment du pic d'aura, 12 mots max"),
});
export type VideoAura = z.infer<typeof VideoAuraSchema>;
