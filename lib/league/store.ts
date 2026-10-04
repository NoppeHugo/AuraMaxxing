import { createHash, randomBytes, randomUUID } from "crypto";
import { AuraError } from "../ai";
import { jsonDb } from "../jsonDb";
import type { StatKey, VideoAura } from "../schemas";
import {
  BEST_OF,
  CHALLENGE_TTL_MS,
  CREW_MAX_MEMBERS,
  DAILY_HASHTAG,
  DAILY_UPLOADS,
  LEAGUES,
  LOBBY_SIZE,
  REFERRAL_BONUS_MAX,
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
  /** Parrainage : qui m'a invité, qui j'ai invité. */
  referredBy?: string;
  referrals?: string[];
  /** Joueurs devant moi la dernière fois que j'ai regardé ma ligue (alertes « il t'a dépassé »). */
  aheadSnapshot?: { week: string; ids: string[] };
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
export type CrewKind = "school" | "friends";
type Crew = {
  id: string;
  name: string;
  code: string;
  ownerId: string;
  members: string[];
  createdAt: number;
  kind?: CrewKind;
  city?: string;
};

/** Défi 1v1 partagé par lien : n'importe qui peut y répondre avec sa propre vidéo. */
type Challenge = {
  code: string;
  fromId: string;
  videoId: string;
  score: number;
  tier: string;
  title: string;
  emoji: string;
  auraColor: string;
  auraColor2: string;
  createdAt: number;
  expiresAt: number;
  answers: { userId: string; score: number; videoId: string; at: number; won: boolean }[];
};
type HallEntry = { week: string; userId: string; pseudo: string; points: number };

type DB = {
  users: Record<string, User>;
  videos: Video[];
  lobbies: Record<string, Lobby>;
  crews: Record<string, Crew>;
  hall: HallEntry[];
  challenges: Record<string, Challenge>;
};

const db = jsonDb<DB>("league-db.json", () => ({ users: {}, videos: [], lobbies: {}, crews: {}, hall: [], challenges: {} }));

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

// Sans 0/O ni 1/I/L : facile à recopier à l'oral ou depuis une story.
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
function newCode(taken: (code: string) => boolean) {
  let code: string;
  do code = Array.from(randomBytes(6), (b) => CODE_ALPHABET[b % CODE_ALPHABET.length]).join("");
  while (taken(code));
  return code;
}

/** Potes invités qui ont réellement joué (au moins une vidéo) : ça évite les faux comptes. */
function activeReferrals(d: DB, u: User) {
  return (u.referrals ?? []).filter((id) => (d.users[id]?.videos ?? 0) > 0).length;
}

function dailyLimit(d: DB, u: User) {
  return DAILY_UPLOADS + Math.min(REFERRAL_BONUS_MAX, activeReferrals(d, u));
}

function usedToday(d: DB, userId: string, today = dayKey()) {
  return d.videos.filter((v) => v.userId === userId && v.day === today).length;
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

export async function register(rawPseudo: unknown, rawRef?: unknown) {
  const pseudo = typeof rawPseudo === "string" ? rawPseudo.trim() : "";
  if (!/^[\p{L}\p{N}_.]{3,16}$/u.test(pseudo)) {
    throw new AuraError("Pseudo : 3 à 16 caractères, lettres, chiffres, _ ou . uniquement.");
  }
  const id = pseudoId(pseudo);
  if (BANNED.some((w) => id.replace(/_/g, "").includes(w))) throw new AuraError("Ce pseudo n'est pas autorisé.");

  const token = randomBytes(32).toString("base64url");
  return db.mutate((d) => {
    if (d.users[id]) throw new AuraError("Ce pseudo est déjà pris.", 409);
    const inviter = resolveRef(d, rawRef);
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
      referrals: [],
      referredBy: inviter?.id,
    };
    if (inviter) (inviter.referrals ??= []).push(id);
    return { token, user: publicUser(d.users[id]), invitedBy: inviter?.pseudo ?? null };
  });
}

/** Un code de parrainage est soit un code de défi (« K7XP2M »), soit le pseudo d'un joueur. */
function resolveRef(d: DB, raw: unknown): User | undefined {
  if (typeof raw !== "string" || !raw.trim()) return undefined;
  const challenge = d.challenges[raw.trim().toUpperCase()];
  return challenge ? d.users[challenge.fromId] : d.users[pseudoId(raw)];
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
    for (const [code, c] of Object.entries(d.challenges)) {
      if (c.fromId === user.id) delete d.challenges[code];
      else c.answers = c.answers.filter((a) => a.userId !== user.id);
    }
    for (const other of Object.values(d.users)) other.referrals = other.referrals?.filter((r) => r !== user.id);
    delete d.users[user.id];
  });
}

// ---------- Profil ----------

export async function profile(user: User, publicUrl: string) {
  return db.read((d) => {
    const u = d.users[user.id];
    const week = weekKey();
    const today = dayKey();
    const points = weeklyPoints(d, week);
    const lobby = u.lobby?.week === week ? d.lobbies[u.lobby.id] : undefined;
    const rank = lobby ? rankLobby(d, lobby, points).indexOf(u.id) + 1 : null;
    const used = usedToday(d, u.id, today);
    const limit = dailyLimit(d, u);
    const theme = themeOfDay(today);
    const crew = u.crewId ? d.crews[u.crewId] : undefined;

    return {
      user: publicUser(u),
      league: { index: u.league, ...LEAGUES[u.league] },
      week: { id: week, label: weekLabel(week), endsAt: weekEndsAt(), points: points.get(u.id) ?? 0, rank, size: lobby?.members.length ?? 0 },
      today: {
        theme: theme.title,
        hint: theme.hint,
        hashtag: DAILY_HASHTAG,
        uploadsLeft: Math.max(0, limit - used),
        uploadsMax: limit,
        resetsAt: dayEndsAt(),
        postedToday: u.lastPostDay === today,
      },
      streak: { days: liveStreak(u, today), bonus: streakBonus(liveStreak(u, today) + (u.lastPostDay === today ? 0 : 1)) },
      lastResult: u.lastResult && !u.lastResult.seen ? { ...u.lastResult, leagueInfo: LEAGUES[u.lastResult.newLeague] } : null,
      crew: crew ? { id: crew.id, name: crew.name, code: crew.code } : null,
      rivals: lobby ? rivalInfo(d, u, lobby, points) : { ahead: null, overtakenBy: [] },
      invite: {
        code: u.id,
        url: `${publicUrl}/i/${encodeURIComponent(u.id)}`,
        invited: (u.referrals ?? []).length,
        active: activeReferrals(d, u),
        bonus: Math.min(REFERRAL_BONUS_MAX, activeReferrals(d, u)),
        max: REFERRAL_BONUS_MAX,
      },
      badges: u.badges.slice(-12).reverse(),
      stats: { videos: u.videos, bestScore: u.bestScore },
      recent: d.videos
        .filter((v) => v.userId === u.id)
        .slice(-10)
        .reverse(),
    };
  });
}

/** Le joueur juste devant moi + ceux qui m'ont dépassé depuis ma dernière visite de la ligue. */
function rivalInfo(d: DB, u: User, lobby: Lobby, points: Map<string, number>) {
  const ranked = rankLobby(d, lobby, points).filter((id) => id === u.id || visibleTo(u)(d.users[id]));
  const myIndex = ranked.indexOf(u.id);
  const aheadId = myIndex > 0 ? ranked[myIndex - 1] : undefined;
  const nowAhead = ranked.slice(0, Math.max(0, myIndex));
  const before = u.aheadSnapshot?.week === lobby.week ? new Set(u.aheadSnapshot.ids) : undefined;
  return {
    ahead: aheadId
      ? { pseudo: d.users[aheadId].pseudo, gap: (points.get(aheadId) ?? 0) - (points.get(u.id) ?? 0) + 1 }
      : null,
    overtakenBy: before ? nowAhead.filter((id) => !before.has(id)).map((id) => d.users[id].pseudo).slice(0, 3) : [],
  };
}

function snapshotAhead(d: DB, u: User, lobby: Lobby, points: Map<string, number>) {
  const ranked = rankLobby(d, lobby, points);
  u.aheadSnapshot = { week: lobby.week, ids: ranked.slice(0, Math.max(0, ranked.indexOf(u.id))) };
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
  const { used, limit } = await db.read((d) => ({ used: usedToday(d, user.id, today), limit: dailyLimit(d, d.users[user.id]) }));
  if (used >= limit) {
    throw new AuraError(
      `T'as utilisé tes ${limit} vidéos du jour. Reviens demain, ou invite un pote pour +1 vidéo par jour !`,
      429,
    );
  }
}

export async function recordVideo(
  user: User,
  a: VideoAura,
  cover: { consent: boolean; image?: string },
  challengeCode?: string,
) {
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
    snapshotAhead(d, u, lobby, after);
    const challenge = challengeCode ? answerChallenge(d, u, video, challengeCode) : null;
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
      uploadsLeft: Math.max(0, dailyLimit(d, u) - usedToday(d, u.id, today)),
      challenge,
    };
  });
}

// ---------- Classements ----------

/** Mon groupe de ligue de la semaine, avec les zones de montée et de descente. */
export async function lobbyView(user: User) {
  return db.mutate((d) => {
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
    snapshotAhead(d, u, lobby, points); // base des alertes « il t'a dépassé »
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

function normalizeCity(raw: unknown) {
  const city = typeof raw === "string" ? raw.trim().replace(/\s+/g, " ").slice(0, 40) : "";
  return city ? city.charAt(0).toUpperCase() + city.slice(1).toLowerCase() : undefined;
}
const sameCity = (a?: string | null, b?: string | null) => !!a && !!b && pseudoId(a) === pseudoId(b);

export async function createCrew(user: User, rawName: unknown, rawKind?: unknown, rawCity?: unknown) {
  const kind: CrewKind = rawKind === "school" ? "school" : "friends";
  const city = normalizeCity(rawCity);
  if (kind === "school" && !city) throw new AuraError("Indique la ville de ton établissement.");
  const name = typeof rawName === "string" ? rawName.trim().replace(/\s+/g, " ") : "";
  if (name.length < 3 || name.length > 24) throw new AuraError("Nom du crew : 3 à 24 caractères.");
  if (BANNED.some((w) => pseudoId(name).replace(/_/g, "").includes(w))) throw new AuraError("Ce nom n'est pas autorisé.");
  return db.mutate((d) => {
    const u = d.users[user.id];
    leaveCrewIn(d, u);
    const code = newCode((c) => Object.values(d.crews).some((crew) => crew.code === c));
    const crew: Crew = { id: randomUUID(), name, code, ownerId: u.id, members: [u.id], createdAt: Date.now(), kind, city };
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
      .map((c) => ({
        id: c.id,
        name: c.name,
        members: c.members.length,
        points: crewPoints(c),
        kind: c.kind ?? "friends",
        city: c.city ?? null,
      }))
      .sort((a, b) => b.points - a.points);
    const me = d.users[user.id];
    const mine = me.crewId ? d.crews[me.crewId] : undefined;
    const ranked = <T extends { id: string }>(list: T[]) =>
      list.slice(0, 50).map((c, i) => ({ ...c, rank: i + 1, isMine: c.id === mine?.id }));
    const show = visibleTo(me);

    return {
      week: { id: week, label: weekLabel(week), endsAt: weekEndsAt() },
      crew: mine
        ? {
            id: mine.id,
            name: mine.name,
            code: mine.code,
            kind: mine.kind ?? "friends",
            city: mine.city ?? null,
            rank: ranking.findIndex((c) => c.id === mine.id) + 1,
            points: crewPoints(mine),
            members: mine.members
              .map((id) => d.users[id])
              .filter(show)
              .map((m) => ({ ...publicUser(m), points: points.get(m.id) ?? 0, isMe: m.id === user.id }))
              .sort((a, b) => b.points - a.points),
          }
        : null,
      top: ranked(ranking),
      // « Le lycée avec le plus d'aura » : établissements seulement, en France puis dans ma ville.
      schools: ranked(ranking.filter((c) => c.kind === "school")),
      city: mine?.city
        ? { name: mine.city, crews: ranked(ranking.filter((c) => c.kind === "school" && sameCity(c.city, mine.city))) }
        : null,
    };
  });
}

// ---------- Défis 1v1 par lien ----------

function challengePublic(d: DB, c: Challenge) {
  const from = d.users[c.fromId];
  return {
    code: c.code,
    from: from ? { pseudo: from.pseudo, league: LEAGUES[from.league] } : null,
    score: c.score,
    tier: c.tier,
    title: c.title,
    emoji: c.emoji,
    auraColor: c.auraColor,
    auraColor2: c.auraColor2,
    expiresAt: c.expiresAt,
    expired: Date.now() > c.expiresAt,
    answers: c.answers.length,
    beaten: c.answers.filter((x) => x.won).length,
  };
}

/** Crée (ou réutilise) le défi lié à une de mes vidéos. */
export async function createChallenge(user: User, videoId: unknown) {
  return db.mutate((d) => {
    const video = d.videos.find((v) => v.id === videoId && v.userId === user.id);
    if (!video || video.points === 0) throw new AuraError("Vidéo introuvable.", 404);
    const existing = Object.values(d.challenges).find((c) => c.videoId === video.id && Date.now() < c.expiresAt);
    if (existing) return challengePublic(d, existing);
    const u = d.users[user.id];
    const challenge: Challenge = {
      code: newCode((c) => !!d.challenges[c]),
      fromId: u.id,
      videoId: video.id,
      score: video.score,
      tier: video.tier,
      title: video.title,
      emoji: video.emoji,
      auraColor: u.auraColor,
      auraColor2: u.auraColor2,
      createdAt: Date.now(),
      expiresAt: Date.now() + CHALLENGE_TTL_MS,
      answers: [],
    };
    d.challenges[challenge.code] = challenge;
    return challengePublic(d, challenge);
  });
}

export async function challengeInfo(rawCode: unknown) {
  const code = typeof rawCode === "string" ? rawCode.trim().toUpperCase() : "";
  return db.read((d) => (d.challenges[code] ? challengePublic(d, d.challenges[code]) : null));
}

/** Infos publiques d'un joueur pour sa page d'invitation. */
export async function inviterInfo(rawId: unknown) {
  const id = typeof rawId === "string" ? pseudoId(decodeURIComponent(rawId)) : "";
  return db.read((d) => {
    const u = d.users[id];
    if (!u || u.hidden) return null;
    return { code: u.id, pseudo: u.pseudo, league: LEAGUES[u.league], bestScore: u.bestScore, tier: u.tier, auraColor: u.auraColor, auraColor2: u.auraColor2 };
  });
}

function answerChallenge(d: DB, u: User, video: Video, rawCode: string) {
  const c = d.challenges[rawCode.trim().toUpperCase()];
  if (!c || c.fromId === u.id || Date.now() > c.expiresAt || video.points === 0) return null;
  const opponent = d.users[c.fromId];
  if (!opponent) return null;
  const won = video.score > c.score;
  // On garde la meilleure réponse de chaque joueur.
  const previous = c.answers.find((x) => x.userId === u.id);
  if (!previous) c.answers.push({ userId: u.id, score: video.score, videoId: video.id, at: Date.now(), won });
  else if (video.score > previous.score) Object.assign(previous, { score: video.score, videoId: video.id, at: Date.now(), won });
  return { code: c.code, opponent: opponent.pseudo, opponentScore: c.score, myScore: video.score, won };
}

/** Mes défis envoyés (avec les réponses) et ceux auxquels j'ai répondu. */
export async function myChallenges(user: User) {
  return db.read((d) => {
    const all = Object.values(d.challenges);
    return {
      sent: all
        .filter((c) => c.fromId === user.id)
        .sort((a, b) => b.createdAt - a.createdAt)
        .slice(0, 10)
        .map((c) => ({
          ...challengePublic(d, c),
          results: c.answers
            .filter((x) => d.users[x.userId])
            .map((x) => ({ pseudo: d.users[x.userId].pseudo, score: x.score, won: x.won }))
            .sort((a, b) => b.score - a.score),
        })),
      received: all
        .filter((c) => c.answers.some((x) => x.userId === user.id))
        .sort((a, b) => b.createdAt - a.createdAt)
        .slice(0, 10)
        .map((c) => {
          const mine = c.answers.find((x) => x.userId === user.id)!;
          return { ...challengePublic(d, c), myScore: mine.score, won: mine.won };
        }),
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
