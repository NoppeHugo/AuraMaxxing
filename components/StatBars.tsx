import { STAT_KEYS, STAT_LABELS, type StatKey } from "@/lib/schemas";

export function StatBars({ stats }: { stats: Partial<Record<StatKey, number>> }) {
  return (
    <div className="stack" style={{ gap: 10 }}>
      {STAT_KEYS.filter((k) => stats[k] !== undefined).map((k, i) => (
        <div key={k} className="stat-row">
          <span className="muted">{STAT_LABELS[k]}</span>
          <div className="stat-track">
            <div className="stat-fill" style={{ width: `${stats[k]}%`, animationDelay: `${0.3 + i * 0.12}s` }} />
          </div>
          <span className="stat-value">{stats[k]}</span>
        </div>
      ))}
    </div>
  );
}
