import { promises as fs } from "fs";
import path from "path";

/**
 * Petite base JSON sur disque avec écritures sérialisées.
 * Suffisant pour un prototype sur un serveur unique ; à remplacer par Postgres/Supabase en prod.
 */
export function jsonDb<T>(file: string, empty: () => T) {
  const dir = path.resolve(/*turbopackIgnore: true*/ process.env.AURA_DATA_DIR ?? "./data");
  const full = path.join(dir, file);
  let cache: T | null = null;
  let queue: Promise<unknown> = Promise.resolve();

  async function load(): Promise<T> {
    if (cache) return cache;
    try {
      cache = { ...empty(), ...(JSON.parse(await fs.readFile(full, "utf8")) as T) };
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      cache = empty();
    }
    return cache;
  }

  async function save(db: T) {
    await fs.mkdir(dir, { recursive: true });
    const tmp = `${full}.${process.pid}.tmp`;
    await fs.writeFile(tmp, JSON.stringify(db));
    await fs.rename(tmp, full);
  }

  /** Exécute fn sur la base puis sauvegarde, une opération à la fois. */
  function mutate<R>(fn: (db: T) => R): Promise<R> {
    const run = queue.then(async () => {
      const db = await load();
      const result = fn(db);
      await save(db);
      return result;
    });
    queue = run.catch(() => undefined);
    return run;
  }

  /** Lecture après les écritures en attente. */
  async function read<R>(fn: (db: T) => R): Promise<R> {
    await queue;
    return fn(await load());
  }

  return { mutate, read };
}
