# AuraMaxxing ⚡ Battle d'aura

App web où les jeunes font noter leur **aura** par l'IA (Claude), s'affrontent en **battles 1v1** et grimpent au **classement**. L'app analyse aussi les **trends** mode/lifestyle détectées dans toutes les photos (Old Money, Streetwear, Y2K, Gorpcore, Opium…).

## Fonctionnalités

| Écran | Ce que ça fait |
|---|---|
| 🔮 **Scan** (`/scan`) | Photo → score d'aura sur 1000, tier (NPC → Mythique), surnom, stats (Drip, Vibe, Confiance, Originalité, Trend fit), trends détectées, hype + roast gentil, conseils pour gagner de l'aura. Effets : scan laser, particules aux couleurs de l'aura, compteur animé, confettis. **Carte d'aura format story** à partager ou télécharger. |
| ⚔️ **Battle** (`/battle`) | Deux photos, cinq rounds commentés par l'IA révélés un par un, couronne + confettis pour le gagnant, points **ELO** échangés. |
| 🏆 **Classement** (`/classement`) | Podium + liste, deux modes : ELO des battles ou meilleur score d'aura. Dernières battles. |
| 📈 **Trends** (`/trends`) | Trends les plus portées, celles qui montent sur 7 jours, celles qui donnent le plus d'aura, stats moyennes de la communauté. |

Côté sécurité : l'IA note le style, la vibe et l'attitude, **jamais le physique** (visage, corps, poids, origine…), et les roasts restent gentils. Les photos ne sont pas stockées par l'app ; seule une miniature l'est, et uniquement si la personne coche la case. Il y a aussi une limite de débit par IP.

## Lancer en local

```bash
npm install
cp .env.example .env.local   # puis mets ta clé ANTHROPIC_API_KEY
npm run dev                  # http://localhost:3000
```

Pour tester l'interface sans clé API (résultats simulés) :

```bash
AURA_DEMO_MODE=true npm run dev
```

### Variables d'environnement

| Variable | Rôle |
|---|---|
| `ANTHROPIC_API_KEY` | Clé API Anthropic (obligatoire hors mode démo) |
| `AURA_DEMO_MODE` | `true` = aucun appel IA, résultats simulés |
| `AURA_EFFORT` | `low` / `medium` (défaut) / `high` : plus haut = analyse plus fine mais plus lente et plus chère |
| `AURA_DATA_DIR` | Dossier de la base JSON (défaut `./data`) |

## Stack

- **Next.js 16** (App Router) + React 19 + TypeScript, CSS pur (pas de framework UI)
- **Claude Opus 5.5** via `@anthropic-ai/sdk` : vision + sorties structurées (schémas Zod), avec repli automatique (`fallbacks: "default"`) si une requête est refusée
- Stockage : un fichier JSON (`lib/store.ts`) avec écritures sérialisées

```
app/
  page.tsx              accueil
  scan/ battle/ classement/ trends/
  api/scan  api/battle  api/leaderboard  api/trends
components/             AuraField (particules), Confetti, PhotoPicker, StatBars…
lib/
  ai.ts                 prompts + appels Claude + normalisation + mode démo
  schemas.ts            schémas de sortie de l'IA (Zod), liste des trends et tiers
  store.ts              joueurs, scans, battles, ELO, agrégation des trends
  shareCard.ts          génération de la carte d'aura 1080×1920
```

## Mettre en production

Le stockage JSON convient à un seul serveur (VPS, Railway, Render, Fly.io avec un volume). Sur un hébergement serverless comme Vercel, le disque n'est pas persistant : il faut remplacer `lib/store.ts` par une vraie base (Supabase/Postgres, Firestore…). Les fonctions exportées restent les mêmes, donc le reste de l'app ne change pas.

Pistes pour la suite : comptes utilisateurs (pour qu'on ne puisse pas jouer sous le pseudo de quelqu'un d'autre), battles à distance par lien d'invitation, saisons de classement, modération des pseudos, et une version mobile (PWA ou React Native).
