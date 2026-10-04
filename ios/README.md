# AuraMaxxing — iOS (SwiftUI)

> Tu postes une vidéo, l'IA te donne un score d'aura sur 1000, et chaque semaine tu affrontes 30 joueurs de ton niveau.

> ⚠️ **Code non compilé ici.** Le code a été écrit hors Mac/Xcode (environnement Linux), comme pour VlogMe. La syntaxe des 26 fichiers Swift est validée par un parseur, mais pas les types : attends-toi à quelques petits ajustements au premier build.

## Le concept du classement : les Ligues d'aura

Un classement mondial unique décourage tout le monde sauf le top 10 : impossible de rattraper les premiers, alors on ne joue pas. Le système reprend ce qui marche dans Duolingo et Clash Royale, à la sauce aura.

| Mécanique | Règle | Pourquoi ça donne envie |
|---|---|---|
| **5 ligues** | 👻 Fantôme → 💡 Néon → 🪩 Chrome → 💎 Diamant → 👑 Mythique | Tu vois où tu es et où tu peux aller. |
| **Groupes de 30** | Chaque semaine, tu es placé avec 29 joueurs de ta ligue | Être #1 sur 30, c'est atteignable. Être #1 sur 100 000, non. |
| **Montée / descente** | Le top 7 monte, les 5 derniers descendent (proportionnel dans les petits groupes) | Peur de descendre le dimanche soir, et le lundi un écran plein de célébration quand on monte. |
| **Saison d'une semaine** | Reset tous les lundis à minuit (heure de Paris) | Les nouveaux ont toujours une chance, rien n'est figé. |
| **Top 3 vidéos** | Seules tes 3 meilleures vidéos de la semaine comptent | On ne gagne pas en spammant : on gagne en faisant mieux. |
| **3 vidéos par jour** | Limite côté serveur | Rareté, et coût de l'IA maîtrisé. |
| **Thème du jour** | Un thème commun à tout le monde (« Walk-in de main character », « Fit check »…), +25 % si la vidéo colle | Un rendez-vous quotidien et une idée de vidéo toute prête. |
| **Série** | +5 % par jour consécutif, jusqu'à +30 % | On revient chaque jour pour ne pas casser sa série. |
| **Message de motivation** | « Il te manque 132 pts pour la zone de promotion », « Plus que 40 pts pour passer devant @leo » | Un objectif concret et proche. |
| **Crews** | Groupe de potes / de lycée via un code à 6 caractères ; les points des membres s'additionnent | Rivalité entre classes et lycées, et un code qui se partage en story : bouche-à-oreille. |
| **Badges et légendes** | Le #1 de chaque groupe gagne un badge de saison ; les vainqueurs de la Ligue Mythique entrent dans les Légendes | Une trace permanente à montrer. |
| **Carte d'aura** | Image format story générée après chaque analyse | Chaque partage est une pub gratuite. |
| **Rappels locaux** | Thème du jour (17h30), série en danger (21h), fin de saison (dimanche 18h) | Ramène les joueurs sans serveur de push. |

Toutes ces valeurs se règlent dans `lib/league/rules.ts` côté backend.

## Comment marche l'analyse vidéo

1. La personne filme (caméra frontale, 60 s max) ou choisit une vidéo dans sa galerie.
2. L'iPhone extrait **8 images clés** (`FrameExtractor`, `AVAssetImageGenerator`). **La vidéo ne quitte jamais le téléphone.**
3. Le backend envoie ces images, dans l'ordre et avec leurs timestamps, à Claude : score, tier, stats, trends, moment du pic d'aura, correspondance au thème, et conformité aux règles (contenu inapproprié = 0 point).
4. Le serveur calcule les points de ligue (bonus thème et série), met à jour le groupe et renvoie le nouveau rang.

Coût indicatif : 8 images d'environ 600 tokens chacune, plus la réponse de l'IA, soit de l'ordre de 5 centimes par analyse avec Claude Opus 5.5 (estimation à vérifier sur ta console Anthropic). Pour baisser ce coût : `AURA_EFFORT=low`, 6 images au lieu de 8, ou un modèle plus léger.

## Écrans

| Onglet | Contenu |
|---|---|
| **Aura** | Thème du jour avec compte à rebours, série 🔥, rang dans la ligue, vidéos restantes, bouton « Analyser une vidéo », dernières vidéos |
| **Analyse** | Choix (caméra / galerie) → aperçu en boucle → scan laser sur les images clés → révélation : halo et particules aux couleurs de l'aura, compteur, tier, confettis, +X pts, évolution du rang, stats, hype/roast, conseils, partage de la carte |
| **Ligue** | Échelle des 5 ligues, fin de saison, groupe de 30 avec zones de promotion/relégation, message de motivation, onglets Monde et Légendes. Appui long sur un joueur : signaler / bloquer |
| **Crew** | Créer / rejoindre avec un code, membres, classement des crews |
| **Profil** | Record, badges, rappels, règles, déconnexion, suppression du compte |
| **Fin de semaine** | Écran plein « PROMU·E ! » / « Relégation… », affiché une fois le lundi |

## Générer et lancer

```bash
brew install xcodegen
cd ios
xcodegen generate
open AuraMaxxing.xcodeproj
```

1. Dans Xcode : target **AuraMaxxing** → *Signing & Capabilities* → ton équipe.
2. Lance le backend (`npm run dev` à la racine du repo). En Debug, l'app appelle `http://localhost:3000`, ce qui marche depuis le simulateur. Sur un vrai iPhone, mets l'IP locale de ton Mac dans `project.yml` (`AURA_API_URL`), ou le backend déployé.
3. Pour tester sans clé API : `AURA_DEMO_MODE=true npm run dev` (scores simulés).

## Avant la soumission App Store

- **Contenu des utilisateurs (règle 1.2)** : règles acceptées à l'inscription, signalement et blocage (appui long), masquage automatique après 3 signalements, filtre de pseudos. Il faudra aussi une **adresse de contact** publiée et une modération humaine des profils signalés.
- **Public jeune** : case « 13 ans ou plus » à l'inscription. Vérifie les obligations RGPD pour les mineurs (consentement parental sous 15 ans en France) avec un juriste avant le lancement.
- **Comptes** : pour l'instant, un compte anonyme par appareil (jeton dans le trousseau). Ajouter *Sign in with Apple* permettra de récupérer son compte sur un nouveau téléphone.
- **Icône** : ajoute ton icône 1024×1024 dans `Assets.xcassets/AppIcon.appiconset`.
- **Backend** : le stockage JSON convient au prototype. Pour la prod, passer `lib/league/store.ts` sur Postgres/Supabase.

## Architecture

```
AuraMaxxing/
├─ App/          AuraMaxxingApp · RootView (onglets, écran de fin de semaine)
├─ Models/       APIModels (miroir du JSON de l'API v1)
├─ Services/     APIClient · SessionStore · KeychainStore · FrameExtractor · Reminders · Analytics (PostHog) · Haptics
└─ Views/
   ├─ Onboarding/  3 slides + pseudo + règles
   ├─ Home/        accueil
   ├─ Upload/      UploadFlowView · AnalyzingView · ResultView · AuraCardView
   ├─ League/      LeagueView · WeekResultView
   ├─ Crew/        CrewView
   ├─ Profile/     ProfileView
   └─ Components/  AuraBackground · ParticleField · ConfettiView · CountingText · AvatarView · Theme
```
