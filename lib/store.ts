import { promises as fs } from "fs";
import path from "path";
import { randomUUID } from "crypto";
import type { AuraAnalysis, BattleVerdict, StatKey } from "./schemas";
import { tierFor } from "./ai";

/**
 * Base de données ultra simple : un fichier JSON sur disque.
 * Suffisant pour un prototype / un serveur unique. Pour la prod multi-instances,
 * remplacer ce module par une vraie base (Postgres, Supabase, Firestore…) en gardant les mêmes fonctions.
 */

export type Player = {
  id: string;
  pseudo: string;
  elo: number;
  wins: number;
  losses: number;
  bestScore: number;
  lastScore: number;
  scans: number;
  tier: string;
  title: string;
  emoji: string;
  auraColor: string;
  auraColor2: string;
  thumb?: string; // miniature (data URL) seulement si la personne l'accepte
  updatedAt: number;
};

export type ScanRecord = {
  id: string;
  playerId: string;
  score: number;
  trends: string[];
  stats: Record<StatKey, number>;
  createdAt: number;
};

export type BattleRecord = {
  id: string;
  aId: string;
  bId: string;
  winnerId: string;
  scoreA: number;
  scoreB: number;
  eloDelta: number;
  trendsA: string[];
  trendsB: string[];
  verdict: string;
  createdAt: number;
};

type DB = { players: Record<string, Player>; scans: ScanRecord[]; battles: BattleRecord[] };

const DATA_DIR = path.resolve(/*turbopackIgnore: true*/ process.env.AURA_DATA_DIR ?? "./data");
const DB_FILE = path.join(DATA_DIR, "aura-db.json");
const MAX_HISTORY = 5000;
const START_ELO = 1000;
const K_FACTOR = 32;

let cache: DB | null = null;
let queue: Promise<unknown> = Promise.resolve();

async function load(): Promise<DB> {
  if (cache) return cache;
  try {
    cache = JSON.parse(await fs.readFile(DB_FILE, "utf8")) as DB;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    cache = { players: {}, scans: [], battles: [] };
  }
  return cache;
}

async function save(db: DB) {
  await fs.mkdir(DATA_DIR, { recursive: true });
  const tmp = `${DB_FILE}.${process.pid}.tmp`;
  await fs.writeFile(tmp, JSON.stringify(db));
  await fs.rename(tmp, DB_FILE);
}

/** Sérialise les écritures pour éviter que deux requêtes simultanées s'écrasent. */
function mutate<T>(fn: (db: DB) => T): Promise<T> {
  const run = queue.then(async () => {
    const db = await load();
    const result = fn(db);
    await save(db);
    return result;
  });
  queue = run.catch(() => undefined);
  return run;
}

export function playerId(pseudo: string) {
  return pseudo
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function getOrCreate(db: DB, pseudo: string): Player {
  const id = playerId(pseudo);
  db.players[id] ??= {
    id,
    pseudo,
    elo: START_ELO,
    wins: 0,
    losses: 0,
    bestScore: 0,
    lastScore: 0,
    scans: 0,
    tier: "NPC",
    title: "",
    emoji: "🗿",
    auraColor: "#a855f7",
    auraColor2: "#22d3ee",
    updatedAt: Date.now(),
  };
  const player = db.players[id];
  player.pseudo = pseudo; // garde la dernière casse choisie
  return player;
}

function trim<T>(list: T[]) {
  if (list.length > MAX_HISTORY) list.splice(0, list.length - MAX_HISTORY);
}

function setThumb(player: Player, thumb: string | undefined, showPhoto: boolean) {
  if (!showPhoto) delete player.thumb;
  else if (thumb) player.thumb = thumb;
}

export function recordScan(pseudo: string, analysis: AuraAnalysis, thumb: string | undefined, showPhoto: boolean) {
  return mutate((db) => {
    const player = getOrCreate(db, pseudo);
    const isRecord = analysis.aura_score > player.bestScore;
    player.scans += 1;
    player.lastScore = analysis.aura_score;
    if (isRecord) {
      player.bestScore = analysis.aura_score;
      player.tier = analysis.tier;
      player.title = analysis.title;
      player.emoji = analysis.emoji;
      player.auraColor = analysis.aura_color;
      player.auraColor2 = analysis.aura_color_2;
    }
    setThumb(player, thumb, showPhoto);
    player.updatedAt = Date.now();

    db.scans.push({
      id: randomUUID(),
      playerId: player.id,
      score: analysis.aura_score,
      trends: analysis.trends.map((t) => t.name),
      stats: analysis.stats,
      createdAt: Date.now(),
    });
    trim(db.scans);
    return { player: { ...player }, isRecord, rank: rankOf(db, player.id, "aura") };
  });
}

type Side = { pseudo: string; thumb?: string; showPhoto: boolean };

export function recordBattle(a: Side, b: Side, verdict: BattleVerdict) {
  return mutate((db) => {
    const pa = getOrCreate(db, a.pseudo);
    const pb = getOrCreate(db, b.pseudo);
    const aWins = verdict.winner === "A";
    const expectedA = 1 / (1 + 10 ** ((pb.elo - pa.elo) / 400));
    const expectedWinner = aWins ? expectedA : 1 - expectedA;
    const delta = Math.max(1, Math.round(K_FACTOR * (1 - expectedWinner)));
    const before = { a: pa.elo, b: pb.elo };

    pa.elo += aWins ? delta : -delta;
    pb.elo += aWins ? -delta : delta;
    (aWins ? pa : pb).wins += 1;
    (aWins ? pb : pa).losses += 1;

    for (const [p, side, score, c] of [
      [pa, a, verdict.score_a, verdict.aura_color_a],
      [pb, b, verdict.score_b, verdict.aura_color_b],
    ] as const) {
      p.lastScore = score;
      if (score > p.bestScore) {
        p.bestScore = score;
        p.tier = tierFor(score);
        p.auraColor = c;
      }
      setThumb(p, side.thumb, side.showPhoto);
      p.updatedAt = Date.now();
    }

    db.battles.push({
      id: randomUUID(),
      aId: pa.id,
      bId: pb.id,
      winnerId: aWins ? pa.id : pb.id,
      scoreA: verdict.score_a,
      scoreB: verdict.score_b,
      eloDelta: delta,
      trendsA: verdict.trends_a,
      trendsB: verdict.trends_b,
      verdict: verdict.verdict,
      createdAt: Date.now(),
    });
    trim(db.battles);

    return {
      eloDelta: delta,
      a: { ...pa, eloBefore: before.a },
      b: { ...pb, eloBefore: before.b },
    };
  });
}

function rankOf(db: DB, id: string, by: "elo" | "aura") {
  return sortedPlayers(db, by).findIndex((p) => p.id === id) + 1;
}

function sortedPlayers(db: DB, by: "elo" | "aura") {
  const players = Object.values(db.players);
  return by === "elo"
    ? players.filter((p) => p.wins + p.losses > 0).sort((x, y) => y.elo - x.elo || y.wins - x.wins)
    : players.filter((p) => p.bestScore > 0).sort((x, y) => y.bestScore - x.bestScore);
}

export async function leaderboard(by: "elo" | "aura", limit = 100) {
  await queue;
  const db = await load();
  return {
    players: sortedPlayers(db, by).slice(0, limit),
    recentBattles: db.battles
      .slice(-8)
      .reverse()
      .map((b) => ({
        ...b,
        a: db.players[b.aId]?.pseudo ?? "?",
        b: db.players[b.bId]?.pseudo ?? "?",
        winner: db.players[b.winnerId]?.pseudo ?? "?",
      })),
  };
}

const DAY = 24 * 60 * 60 * 1000;

/** Agrège les trends détectées par l'IA dans tous les scans et battles. */
export async function trendStats(now = Date.now()) {
  await queue;
  const db = await load();
  const events: { trends: string[]; score: number; at: number }[] = [
    ...db.scans.map((s) => ({ trends: s.trends, score: s.score, at: s.createdAt })),
    ...db.battles.flatMap((b) => [
      { trends: b.trendsA, score: b.scoreA, at: b.createdAt },
      { trends: b.trendsB, score: b.scoreB, at: b.createdAt },
    ]),
  ];

  const byTrend = new Map<string, { count: number; scoreSum: number; week: number; prevWeek: number }>();
  for (const e of events) {
    for (const name of new Set(e.trends)) {
      const t = byTrend.get(name) ?? { count: 0, scoreSum: 0, week: 0, prevWeek: 0 };
      t.count += 1;
      t.scoreSum += e.score;
      if (now - e.at < 7 * DAY) t.week += 1;
      else if (now - e.at < 14 * DAY) t.prevWeek += 1;
      byTrend.set(name, t);
    }
  }

  const total = events.length;
  const trends = [...byTrend.entries()]
    .map(([name, t]) => ({
      name,
      count: t.count,
      share: total ? t.count / total : 0,
      avgAura: Math.round(t.scoreSum / t.count),
      momentum: t.week - t.prevWeek,
    }))
    .sort((x, y) => y.count - x.count);

  const statTotals = db.scans.reduce(
    (acc, s) => {
      for (const k of Object.keys(s.stats) as StatKey[]) acc[k] = (acc[k] ?? 0) + s.stats[k];
      return acc;
    },
    {} as Partial<Record<StatKey, number>>,
  );
  const avgStats = Object.fromEntries(
    Object.entries(statTotals).map(([k, v]) => [k, Math.round(v / Math.max(1, db.scans.length))]),
  );

  return {
    totalAnalyses: total,
    totalPlayers: Object.keys(db.players).length,
    totalBattles: db.battles.length,
    avgAura: total ? Math.round(events.reduce((s, e) => s + e.score, 0) / total) : 0,
    trends,
    rising: trends.filter((t) => t.momentum > 0).sort((x, y) => y.momentum - x.momentum).slice(0, 3),
    bestAura: [...trends].filter((t) => t.count >= 2).sort((x, y) => y.avgAura - x.avgAura).slice(0, 3),
    avgStats,
  };
}
