/** Toutes les règles du jeu au même endroit, pour pouvoir les ajuster facilement. */

export const LEAGUES = [
  { name: "Ligue Fantôme", emoji: "👻", color: "#9ca3af" },
  { name: "Ligue Néon", emoji: "💡", color: "#3de8ff" },
  { name: "Ligue Chrome", emoji: "🪩", color: "#c0c7d6" },
  { name: "Ligue Diamant", emoji: "💎", color: "#7dd3fc" },
  { name: "Ligue Mythique", emoji: "👑", color: "#ffd25e" },
] as const;
export const TOP_LEAGUE = LEAGUES.length - 1;

/** Taille max d'un groupe de ligue : on est comparé à 30 joueurs de son niveau, pas au monde entier. */
export const LOBBY_SIZE = 30;

/** Seules les N meilleures vidéos de la semaine comptent : poster plus ne sert à rien, poster mieux oui. */
export const BEST_OF = 3;

/** Nombre de vidéos analysables par jour (rareté + maîtrise du coût de l'IA). */
export const DAILY_UPLOADS = 3;

/** Bonus si la vidéo colle au thème du jour. */
export const THEME_BONUS = 0.25;

/** +5 % par jour de série, plafonné à +30 %. */
export const STREAK_STEP = 0.05;
export const STREAK_MAX_BONUS = 0.3;

export const CREW_MAX_MEMBERS = 20;

/** Nombre de signalements avant qu'un profil soit masqué en attendant une vérification. */
export const REPORTS_TO_HIDE = 3;

/**
 * Zones de montée / descente selon la taille du groupe.
 * Groupe plein (30) : 7 montent, 5 descendent. Petits groupes (début de l'app) : proportionnel.
 */
export function zones(size: number, league: number) {
  const promote = league >= TOP_LEAGUE ? 0 : Math.max(1, Math.round(size * (7 / 30)));
  const demote = league === 0 || size < 10 ? 0 : Math.round(size * (5 / 30));
  return { promote: Math.min(promote, size), demote };
}

export function streakBonus(streak: number) {
  return Math.min(STREAK_MAX_BONUS, Math.max(0, streak - 1) * STREAK_STEP);
}

export function videoPoints(score: number, themeMatch: boolean, streak: number) {
  return Math.round(score * (1 + (themeMatch ? THEME_BONUS : 0) + streakBonus(streak)));
}

/** Un thème par jour, le même pour tout le monde : ça crée un rendez-vous quotidien. */
export const THEMES = [
  { title: "Walk-in de main character", hint: "Entre dans le champ comme si t'étais attendu·e." },
  { title: "Fit check du jour", hint: "Montre la tenue de la tête aux pieds." },
  { title: "Regard caméra sigma", hint: "Trois secondes de silence, zéro sourire." },
  { title: "Transition de fou", hint: "Avant / après en un cut." },
  { title: "Ton spot préféré", hint: "Fais-nous visiter l'endroit où t'as le plus d'aura." },
  { title: "Le rire contagieux", hint: "Une vidéo qui fait sourire en 5 secondes." },
  { title: "Slow motion héroïque", hint: "Filme au ralenti, musique épique dans ta tête." },
  { title: "Talent caché", hint: "Montre un truc que tu sais faire et que personne ne sait." },
  { title: "Old money vibes", hint: "Chic, calme, élégant." },
  { title: "Streetwear check", hint: "Sneakers, baggy, accessoires : on veut tout voir." },
  { title: "Golden hour", hint: "Filme pendant la lumière du coucher de soleil." },
  { title: "Danse en une prise", hint: "Une chorée, un plan séquence." },
  { title: "Duo d'aura", hint: "Filme-toi avec ton/ta meilleur·e pote." },
  { title: "Le POV", hint: "Raconte une scène en POV, version aura." },
  { title: "Sport mode", hint: "Ton meilleur geste : skate, foot, basket, muscu…" },
  { title: "Room tour express", hint: "Ta chambre en 10 secondes." },
  { title: "L'entrée en soirée", hint: "Comment t'arrives quand t'es le/la plus attendu·e." },
  { title: "Monochrome", hint: "Une seule couleur dans toute la tenue." },
  { title: "Mode NPC → Main character", hint: "Commence NPC, finis légendaire." },
  { title: "Le flex calme", hint: "Montre un truc dont t'es fier·e, sans en faire trop." },
  { title: "Thème libre", hint: "Surprends-nous." },
] as const;

/** Chaque pote invité qui poste sa 1re vidéo donne +1 vidéo par jour, jusqu'à +3. */
export const REFERRAL_BONUS_MAX = 3;

/** Durée de validité d'un lien de défi. */
export const CHALLENGE_TTL_MS = 72 * 60 * 60 * 1000;

/** Hashtag commun, repris dans les vidéos et textes de partage. */
export const DAILY_HASHTAG = "#AuraDuJour";
