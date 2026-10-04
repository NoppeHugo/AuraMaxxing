# AuraMaxxing ⚡ Battle d'aura

> **📱 App iOS** : voir [`ios/README.md`](ios/README.md). Tu postes une vidéo, l'IA te donne un score d'aura, et chaque semaine tu joues dans des **Ligues d'aura** (groupes de 30, montées et descentes, thème du jour, séries, crews). Le serveur Next.js de ce repo sert de backend à l'app via `/api/v1/*` (code dans `lib/league/`).

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

## API mobile (`/api/v1`)

| Route | Rôle |
|---|---|
| `POST /register` | Crée un compte anonyme (pseudo) et renvoie un jeton |
| `GET /me` · `DELETE /me` | Profil (ligue, semaine, thème du jour, série, vidéos restantes) · suppression du compte |
| `POST /videos` | Images clés d'une vidéo → analyse IA + points de ligue |
| `GET /league` | Mon groupe de la semaine avec les zones de montée et de descente |
| `GET /global` | Meilleures vidéos de la semaine + légendes |
| `GET/POST /crew`, `POST /crew/join`, `POST /crew/leave` | Crews |
| `POST /report`, `POST /block` | Modération |
| `POST /result-seen` | Marque le résultat de fin de semaine comme vu |
| `GET /theme` | Thème du jour |
| `POST /challenges` · `GET /challenges` | Créer un défi à partir d'une vidéo (lien + texte à partager) · mes défis envoyés et reçus |
| `GET /challenges/:code` | Infos publiques d'un défi |

Pages web servies pour les liens partagés depuis l'app : `/d/CODE` (défi, avec image d'aperçu générée pour Snap/iMessage/Insta) et `/i/PSEUDO` (invitation). Variables : `AURA_PUBLIC_URL`, `AURA_APP_STORE_URL`.

Les règles du jeu (taille des groupes, bonus, limites) sont dans `lib/league/rules.ts`.

## Mettre en production

Le stockage JSON convient à un seul serveur (VPS, Railway, Render, Fly.io avec un volume). Sur un hébergement serverless comme Vercel, le disque n'est pas persistant : il faut remplacer `lib/store.ts` par une vraie base (Supabase/Postgres, Firestore…). Les fonctions exportées restent les mêmes, donc le reste de l'app ne change pas.

La même chose vaut pour `lib/league/store.ts` (backend de l'app iOS).

Pistes pour la suite : Sign in with Apple, liens universels, notifications push de rivalité, modération humaine des profils signalés.
