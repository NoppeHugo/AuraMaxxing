/**
 * Calendrier du jeu, à l'heure de Paris : la journée change à minuit,
 * la saison (semaine) change le lundi à minuit.
 */
const TZ = "Europe/Paris";
const DAY_MS = 24 * 60 * 60 * 1000;

const dateFmt = new Intl.DateTimeFormat("en-CA", { timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit" });

/** "2026-10-04" (date locale à Paris) */
export function dayKey(ts = Date.now()) {
  return dateFmt.format(ts);
}

function utcDate(day: string) {
  const [y, m, d] = day.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

export function addDays(day: string, n: number) {
  return new Date(utcDate(day).getTime() + n * DAY_MS).toISOString().slice(0, 10);
}

/** Semaine ISO : "2026-W40" */
export function weekKey(ts = Date.now()) {
  const date = utcDate(dayKey(ts));
  const weekday = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - weekday); // jeudi de la semaine
  const yearStart = Date.UTC(date.getUTCFullYear(), 0, 1);
  const week = Math.ceil(((date.getTime() - yearStart) / DAY_MS + 1) / 7);
  return `${date.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

/** Numéro court affiché dans l'app : "S40" */
export function weekLabel(week: string) {
  return `S${Number(week.split("-W")[1])}`;
}

function parisOffsetMs(ts: number) {
  const name = new Intl.DateTimeFormat("en-US", { timeZone: TZ, timeZoneName: "longOffset" })
    .formatToParts(ts)
    .find((p) => p.type === "timeZoneName")?.value; // "GMT+02:00"
  const m = /GMT([+-])(\d{2}):(\d{2})/.exec(name ?? "");
  return m ? (m[1] === "-" ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3])) * 60_000 : 0;
}

/** Instant (UTC, ms) où la semaine en cours se termine : lundi prochain 00:00 à Paris. */
export function weekEndsAt(ts = Date.now()) {
  const today = dayKey(ts);
  const weekday = utcDate(today).getUTCDay() || 7;
  const nextMonday = utcDate(addDays(today, 8 - weekday)).getTime();
  return nextMonday - parisOffsetMs(nextMonday);
}

/** Instant où la journée se termine (minuit à Paris). */
export function dayEndsAt(ts = Date.now()) {
  const tomorrow = utcDate(addDays(dayKey(ts), 1)).getTime();
  return tomorrow - parisOffsetMs(tomorrow);
}

export function dayIndex(day: string) {
  return Math.floor(utcDate(day).getTime() / DAY_MS);
}
