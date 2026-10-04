import { createHash, randomBytes, randomUUID } from "crypto";
import { AuraError } from "../ai";
import { jsonDb } from "../jsonDb";
import type { StatKey, VideoAura } from "../schemas";
import {
  BEST_OF,
  CREW_MAX_MEMBERS,
  DAILY_UPLOADS,
  LEAGUES,
  LOBBY_SIZE,
  REPORTS_TO_HIDE,
  THEMES,
  TOP_LEAGUE,
  streakBonus,
  videoPoints,
  zones,
} from "./rules";
import { addDays, dayEndsAt, dayIndex, dayKey, weekEndsAt, weekKey, weekLabel } from "./time";

// ---------- Modèle ----------

export type WeekResult = {
  week: string;
  league: number;
  newLeague: number;
  rank: number;
  size: number;
  points: number;
  outcome: "up" | "down" | "stay";
  seen: boolean;
};

export type User = {
  id: string;
  pseudo: string;
  tokenHash: string;
  createdAt: number;
  league: number;
  lobby?: { week: string; id: string };
  streak: number;
  lastPostDay?: string;
  bestScore: number;
  videos: number;
  tier: string;
  title: string;
  emoji: string;
  auraColor: string;
  auraColor2: string;
  cover?: string;
  crewId?: string;
  badges: { week: string; label: string }[];
  lastResult?: WeekResult;
  reportedBy: string[];
  hidden: boolean;
  blocked: string[];
};

export type Video = {
  id: string;
  userId: string;
  week: string;
  day: string;
  score: number;
  points: number;
  themeMatch: boolean;
  streakBonus: number;
  tier: string;
  title: string;
  emoji: string;
  trends: string[];
  stats: Record<StatKey, number>;
  createdAt: number;
};

type Lobby = { id: string; week: string; league: number; members: string[]; settled: boolean };
type Crew = { id: string; name: string; code: string; ownerId: string; members: string[]; createdAt: number };
type HallEntry = { week: string; userId: string; pseudo: string; points: number };

type DB = {
  users: Record<string, User>;
  videos: Video[];
  lobbies: Record<string, Lobby>;
  crews: Record<string, Crew>;
  hall: HallEntry[];
};

const db = jsonDb<DB>("league-db.json", () => ({ users: {}, videos: [], lobbies: {}, crews: {}, hall: [] }));

// ---------- Utilitaires ----------

const hashToken = (token: string) => createHash("sha256").update(token).digest("hex");

export function pseudoId(pseudo: string) {
  return pseudo
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_|_$/g, "");
}

// Filtre minimal : à compléter / remplacer par un vrai service de modération.
const BANNED = ["pute", "salope", "encule", "nazi", "hitler", "nigg", "negro", "bougnoul", "pd", "fdp", "connard", "sex", "porn"];

export function themeOfDay(day = dayKey()) {
  return THEMES[dayIndex(day) % THEMES.length];
}

/** Série effective : elle tombe à 0 si on a raté hier. */
function liveStreak(u: User, today = dayKey()) {
  return u.lastPostDay === today || u.lastPostDay === addDays(today, -1) ? u.streak : 0;
}

/** Points de la semaine par joueur = somme de ses BEST_OF meilleures vidéos. */
function weeklyPoints(d: DB, week: string) {
  const byUser = new Map<string, number[]>();
  for (const v of d.videos) {
    if (v.week !== week) continue;
    const list = byUser.get(v.userId) ?? [];
    list.push(v.points);
    byUser.set(v.userId, list);
  }
  return new Map(
    [...byUser].map(([id, pts]) => [
      id,
      pts
        .sort((a, b) => b - a)
        .slice(0, BEST_OF)
        .reduce((s, p) => s + p, 0),
    ]),
  );
}

function rankLobby(d: DB, lobby: Lobby, points: Map<string, number>) {
  return [...lobby.members].sort(
    (a, b) => (points.get(b) ?? 0) - (points.get(a) ?? 0) || d.users[a].pseudo.localeCompare(d.users[b].pseudo),
  );
}

function publicUser(u: User) {
  return {
    id: u.id,
    pseudo: u.pseudo,
    league: u.league,
    tier: u.tier,
    title: u.title,
    emoji: u.emoji,
    auraColor: u.auraColor,
    auraColor2: u.auraColor2,
    cover: u.hidden ? undefined : u.cover,
    bestScore: u.bestScore,
    streak: liveStreak(u),
  };
}

const visibleTo = (viewer: User | undefined) => (u: User) =>
  u.id === viewer?.id || (!u.hidden && !viewer?.blocked.includes(u.id));

// ---------- Fin de semaine : montées / descentes ----------

function settle(d: DB, currentWeek: string) {
  const pending = Object.values(d.lobbies)
    .filter((l) => !l.settled && l.week < currentWeek)
    .sort((a, b) => a.week.localeCompare(b.week));

  for (const lobby of pending) {
    const points = weeklyPoints(d, lobby.week);
    const ranked = rankLobby(d, lobby, points);
    const { promote, demote } = zones(ranked.length, lobby.league);

    ranked.forEach((id, i) => {
      const u = d.users[id];
      const pts = points.get(id) ?? 0;
      let newLeague = lobby.league;
      if (i < promote && pts > 0) newLeague = Math.min(TOP_LEAGUE, lobby.league + 1);
      else if (i >= ranked.length - demote) newLeague = Math.max(0, lobby.league - 1);

      u.league = newLeague;
      u.lastResult = {
        week: lobby.week,
        league: lobby.league,
        newLeague,
        rank: i + 1,
        size: ranked.length,
        points: pts,
        outcome: newLeague > lobby.league ? "up" : newLeague < lobby.league ? "down" : "stay",
        seen: false,
      };
      if (i === 0 && pts > 0) {
        u.badges.push({ week: lobby.week, label: `🥇 ${weekLabel(lobby.week)} · ${LEAGUES[lobby.league].name}` });
        if (lobby.league === TOP_LEAGUE) d.hall.push({ week: lobby.week, userId: id, pseudo: u.pseudo, points: pts });
      }
    });
    lobby.settled = true;
  }
}

async function ensureSettled() {
  const week = weekKey();
  const needed = await db.read((d) => Object.values(d.lobbies).some((l) => !l.settled && l.week < week));
  if (needed) await db.mutate((d) => settle(d, week));
}

// ---------- Comptes ----------

export async function register(rawPseudo: unknown) {
  const pseudo = typeof rawPseudo === "string" ? rawPseudo.trim() : "";
  if (!/^[\p{L}\p{N}_.]{3,16}$/u.test(pseudo)) {
    throw new AuraError("Pseudo : 3 à 16 caractères, lettres, chiffres, _ ou . uniquement.");
  }
  const id = pseudoId(pseudo);
  if (BANNED.some((w) => id.replace(/_/g, "").includes(w))) throw new AuraError("Ce pseudo n'est pas autorisé.");

  const token = randomBytes(32).toString("base64url");
  return db.mutate((d) => {
    if (d.users[id]) throw new AuraError("Ce pseudo est déjà pris.", 409);
    d.users[id] = {
      id,
      pseudo,
      tokenHash: hashToken(token),
      createdAt: Date.now(),
      league: 0,
      streak: 0,
      bestScore: 0,
      videos: 0,
      tier: "NPC",
      title: "",
      emoji: "🗿",
      auraColor: "#b46bff",
      auraColor2: "#3de8ff",
      badges: [],
      reportedBy: [],
      hidden: false,
      blocked: [],
    };
    return { token, user: publicUser(d.users[id]) };
  });
}

export async function authenticate(request: Request): Promise<User> {
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) throw new AuraError("Connexion requise.", 401);
  const hash = hashToken(token);
  await ensureSettled();
  const user = await db.read((d) => Object.values(d.users).find((u) => u.tokenHash === hash));
  if (!user) throw new AuraError("Session expirée, reconnecte-toi.", 401);
  return user;
}

export async function deleteAccount(user: User) {
  return db.mutate((d) => {
    if (user.crewId) leaveCrewIn(d, d.users[user.id]);
    for (const lobby of Object.values(d.lobbies)) lobby.members = lobby.members.filter((m) => m !== user.id);
    d.videos = d.videos.filter((v) => v.userId !== user.id);
    d.hall = d.hall.filter((h) => h.userId !== user.id);
    delete d.users[user.id];
  });
}

// ---------- Profil ----------

export async function profile(user: User) {
  return db.read((d) => {
    const u = d.users[user.id];
    const week = weekKey();
    const today = dayKey();
    const points = weeklyPoints(d, week);
    const lobby = u.lobby?.week === week ? d.lobbies[u.lobby.id] : undefined;
    const rank = lobby ? rankLobby(d, lobby, points).indexOf(u.id) + 1 : null;
    const usedToday = d.videos.filter((v) => v.userId === u.id && v.day === today).length;
    const theme = themeOfDay(today);
    const crew = u.crewId ? d.crews[u.crewId] : undefined;

    return {
      user: publicUser(u),
      league: { index: u.league, ...LEAGUES[u.league] },
      week: { id: week, label: weekLabel(week), endsAt: weekEndsAt(), points: points.get(u.id) ?? 0, rank, size: lobby?.members.length ?? 0 },
      today: {
        theme: theme.title,
        hint: theme.hint,
        uploadsLeft: Math.max(0, DAILY_UPLOADS - usedToday),
        uploadsMax: DAILY_UPLOADS,
        resetsAt: dayEndsAt(),
        postedToday: u.lastPostDay === today,
      },
      streak: { days: liveStreak(u, today), bonus: streakBonus(liveStreak(u, today) + (u.lastPostDay === today ? 0 : 1)) },
      lastResult: u.lastResult && !u.lastResult.seen ? { ...u.lastResult, leagueInfo: LEAGUES[u.lastResult.newLeague] } : null,
      crew: crew ? { id: crew.id, name: crew.name, code: crew.code } : null,
      badges: u.badges.slice(-12).reverse(),
      stats: { videos: u.videos, bestScore: u.bestScore },
      recent: d.videos
        .filter((v) => v.userId === u.id)
        .slice(-10)
        .reverse(),
    };
  });
}

export async function markResultSeen(user: User) {
  await db.mutate((d) => {
    const r = d.users[user.id]?.lastResult;
    if (r) r.seen = true;
  });
}

// ---------- Vidéos ----------

export async function assertCanUpload(user: User) {
  const today = dayKey();
  const used = await db.read((d) => d.videos.filter((v) => v.userId === user.id && v.day === today).length);
  if (used >= DAILY_UPLOADS) {
    throw new AuraError(`T'as utilisé tes ${DAILY_UPLOADS} vidéos du jour. Reviens demain pour farmer plus d'aura !`, 429);
  }
}

export async function recordVideo(user: User, a: VideoAura, cover: { consent: boolean; image?: string }) {
  return db.mutate((d) => {
    const u = d.users[user.id];
    const now = Date.now();
    const today = dayKey(now);
    const week = weekKey(now);

    // Série de jours consécutifs
    if (u.lastPostDay !== today) {
      u.streak = u.lastPostDay === addDays(today, -1) ? u.streak + 1 : 1;
      u.lastPostDay = today;
    }

    // Groupe de ligue de la semaine (rejoint à la première vidéo)
    if (u.lobby?.week !== week) {
      const open = Object.values(d.lobbies).find((l) => l.week === week && l.league === u.league && l.members.length < LOBBY_SIZE);
      const lobby = open ?? { id: randomUUID(), week, league: u.league, members: [], settled: false };
      lobby.members.push(u.id);
      d.lobbies[lobby.id] = lobby;
      u.lobby = { week, id: lobby.id };
    }
    const lobby = d.lobbies[u.lobby.id];
    const before = weeklyPoints(d, week);
    const rankBefore = rankLobby(d, lobby, before).indexOf(u.id) + 1;

    const ok = a.content_ok;
    const video: Video = {
      id: randomUUID(),
      userId: u.id,
      week,
      day: today,
      score: a.aura_score,
      points: ok ? videoPoints(a.aura_score, a.theme_match, u.streak) : 0,
      themeMatch: ok && a.theme_match,
      streakBonus: streakBonus(u.streak),
      tier: a.tier,
      title: a.title,
      emoji: a.emoji,
      trends: a.trends.map((t) => t.name),
      stats: a.stats,
      createdAt: now,
    };
    d.videos.push(video);
    u.videos += 1;

    const isRecord = ok && a.aura_score > u.bestScore;
    if (isRecord) {
      Object.assign(u, {
        bestScore: a.aura_score,
        tier: a.tier,
        title: a.title,
        emoji: a.emoji,
        auraColor: a.aura_color,
        auraColor2: a.aura_color_2,
      });
    }
    if (!cover.consent) delete u.cover;
    else if (cover.image && isRecord) u.cover = cover.image;

    const after = weeklyPoints(d, week);
    const ranked = rankLobby(d, lobby, after);
    const weekVideos = d.videos.filter((v) => v.userId === u.id && v.week === week).map((v) => v.points);
    const counted = [...weekVideos].sort((x, y) => y - x).slice(0, BEST_OF);

    return {
      video,
      isRecord,
      counted: counted.includes(video.points) && video.points > 0,
      weekPoints: after.get(u.id) ?? 0,
      gained: (after.get(u.id) ?? 0) - (before.get(u.id) ?? 0),
      rankBefore: rankBefore || null,
      rankAfter: ranked.indexOf(u.id) + 1,
      lobbySize: ranked.length,
      streak: u.streak,
      uploadsLeft: Math.max(0, DAILY_UPLOADS - d.videos.filter((v) => v.userId === u.id && v.day === today).length),
    };
  });
}

// ---------- Classements ----------

/** Mon groupe de ligue de la semaine, avec les zones de montée et de descente. */
export async function lobbyView(user: User) {
  return db.read((d) => {
    const u = d.users[user.id];
    const week = weekKey();
    const lobby = u.lobby?.week === week ? d.lobbies[u.lobby.id] : undefined;
    const base = {
      week: { id: week, label: weekLabel(week), endsAt: weekEndsAt() },
      league: { index: u.league, ...LEAGUES[u.league] },
      leagues: LEAGUES,
    };
    if (!lobby) return { ...base, joined: false, zones: zones(LOBBY_SIZE, u.league), entries: [] };

    const points = weeklyPoints(d, week);
    const ranked = rankLobby(d, lobby, points);
    const z = zones(ranked.length, lobby.league);
    const show = visibleTo(u);
    return {
      ...base,
      joined: true,
      zones: z,
      entries: ranked
        .map((id, i) => ({ id, i }))
        .filter(({ id }) => show(d.users[id]))
        .map(({ id, i }) => ({
          rank: i + 1,
          points: points.get(id) ?? 0,
          zone: i < z.promote ? "up" : i >= ranked.length - z.demote ? "down" : "stay",
          isMe: id === u.id,
          ...publicUser(d.users[id]),
        })),
    };
  });
}

/** Meilleures vidéos de la semaine, toutes ligues confondues + légendes (vainqueurs de la Ligue Mythique). */
export async function globalView(viewer?: User) {
  return db.read((d) => {
    const week = weekKey();
    const show = visibleTo(viewer && d.users[viewer.id]);
    const best = new Map<string, Video>();
    for (const v of d.videos) {
      if (v.week !== week || v.points === 0) continue;
      if (!best.has(v.userId) || best.get(v.userId)!.score < v.score) best.set(v.userId, v);
    }
    return {
      week: { id: week, label: weekLabel(week), endsAt: weekEndsAt() },
      topVideos: [...best.values()]
        .filter((v) => d.users[v.userId] && show(d.users[v.userId]))
        .sort((a, b) => b.score - a.score)
        .slice(0, 50)
        .map((v) => ({ ...publicUser(d.users[v.userId]), score: v.score, title: v.title, emoji: v.emoji, tier: v.tier })),
      legends: d.hall
        .slice(-20)
        .reverse()
        .filter((h) => d.users[h.userId] && show(d.users[h.userId]))
        .map((h) => ({ ...h, label: weekLabel(h.week), ...publicUser(d.users[h.userId]) })),
    };
  });
}

// ---------- Crews (potes, lycée…) ----------

function leaveCrewIn(d: DB, u: User) {
  const crew = u.crewId ? d.crews[u.crewId] : undefined;
  delete u.crewId;
  if (!crew) return;
  crew.members = crew.members.filter((m) => m !== u.id);
  if (crew.members.length === 0) delete d.crews[crew.id];
  else if (crew.ownerId === u.id) crew.ownerId = crew.members[0];
}

// Sans 0/O ni 1/I/L : facile à recopier à l'oral ou depuis une story.
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

export async function createCrew(user: User, rawName: unknown) {
  const name = typeof rawName === "string" ? rawName.trim().replace(/\s+/g, " ") : "";
  if (name.length < 3 || name.length > 24) throw new AuraError("Nom du crew : 3 à 24 caractères.");
  if (BANNED.some((w) => pseudoId(name).replace(/_/g, "").includes(w))) throw new AuraError("Ce nom n'est pas autorisé.");
  return db.mutate((d) => {
    const u = d.users[user.id];
    leaveCrewIn(d, u);
    let code: string;
    do code = Array.from(randomBytes(6), (b) => CODE_ALPHABET[b % CODE_ALPHABET.length]).join("");
    while (Object.values(d.crews).some((c) => c.code === code));
    const crew: Crew = { id: randomUUID(), name, code, ownerId: u.id, members: [u.id], createdAt: Date.now() };
    d.crews[crew.id] = crew;
    u.crewId = crew.id;
    return { id: crew.id, name, code };
  });
}

export async function joinCrew(user: User, rawCode: unknown) {
  const code = typeof rawCode === "string" ? rawCode.trim().toUpperCase() : "";
  return db.mutate((d) => {
    const crew = Object.values(d.crews).find((c) => c.code === code);
    if (!crew) throw new AuraError("Code de crew introuvable.", 404);
    if (crew.members.includes(user.id)) return { id: crew.id, name: crew.name, code };
    if (crew.members.length >= CREW_MAX_MEMBERS) throw new AuraError(`Ce crew est complet (${CREW_MAX_MEMBERS} max).`);
    const u = d.users[user.id];
    leaveCrewIn(d, u);
    crew.members.push(u.id);
    u.crewId = crew.id;
    return { id: crew.id, name: crew.name, code };
  });
}

export async function leaveCrew(user: User) {
  await db.mutate((d) => leaveCrewIn(d, d.users[user.id]));
}

/** Mon crew (classement interne) + classement des crews de la semaine. */
export async function crewView(user: User) {
  return db.read((d) => {
    const week = weekKey();
    const points = weeklyPoints(d, week);
    const crewPoints = (c: Crew) => c.members.reduce((s, id) => s + (points.get(id) ?? 0), 0);
    const ranking = Object.values(d.crews)
      .map((c) => ({ id: c.id, name: c.name, members: c.members.length, points: crewPoints(c) }))
      .sort((a, b) => b.points - a.points);
    const me = d.users[user.id];
    const mine = me.crewId ? d.crews[me.crewId] : undefined;
    const show = visibleTo(me);

    return {
      week: { id: week, label: weekLabel(week), endsAt: weekEndsAt() },
      crew: mine
        ? {
            id: mine.id,
            name: mine.name,
            code: mine.code,
            rank: ranking.findIndex((c) => c.id === mine.id) + 1,
            points: crewPoints(mine),
            members: mine.members
              .map((id) => d.users[id])
              .filter(show)
              .map((m) => ({ ...publicUser(m), points: points.get(m.id) ?? 0, isMe: m.id === user.id }))
              .sort((a, b) => b.points - a.points),
          }
        : null,
      top: ranking.slice(0, 50).map((c, i) => ({ ...c, rank: i + 1, isMine: c.id === mine?.id })),
    };
  });
}

// ---------- Modération (exigée par l'App Store pour le contenu des utilisateurs) ----------

export async function report(user: User, targetId: unknown) {
  if (typeof targetId !== "string" || targetId === user.id) throw new AuraError("Profil invalide.");
  await db.mutate((d) => {
    const target = d.users[targetId];
    if (!target) throw new AuraError("Profil introuvable.", 404);
    if (!target.reportedBy.includes(user.id)) target.reportedBy.push(user.id);
    if (target.reportedBy.length >= REPORTS_TO_HIDE) target.hidden = true;
    if (!d.users[user.id].blocked.includes(targetId)) d.users[user.id].blocked.push(targetId);
  });
}

export async function block(user: User, targetId: unknown) {
  if (typeof targetId !== "string" || targetId === user.id) throw new AuraError("Profil invalide.");
  await db.mutate((d) => {
    if (!d.users[user.id].blocked.includes(targetId)) d.users[user.id].blocked.push(targetId);
  });
}
