/** Europe/Prague wall clock. EU DST: last Sunday of March/October, 01:00 UTC. */

function lastSundayUtc(year: number, month: number): Date {
  const nextMonth = month === 12
    ? Date.UTC(year + 1, 0, 1)
    : Date.UTC(year, month, 1);
  const last = new Date(nextMonth - 24 * 60 * 60 * 1000);
  const weekday = last.getUTCDay();
  last.setUTCDate(last.getUTCDate() - weekday);
  return new Date(Date.UTC(last.getUTCFullYear(), last.getUTCMonth(), last.getUTCDate()));
}

function pragueOffsetHours(utc: Date): number {
  const year = utc.getUTCFullYear();
  const start = lastSundayUtc(year, 3).getTime() + 60 * 60 * 1000;
  const end = lastSundayUtc(year, 10).getTime() + 60 * 60 * 1000;
  const t = utc.getTime();
  return t >= start && t < end ? 2 : 1;
}

export function pragueParts(instant: Date): { year: number; month: number; day: number } {
  const utc = new Date(instant.getTime());
  const shifted = new Date(utc.getTime() + pragueOffsetHours(utc) * 60 * 60 * 1000);
  return {
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth() + 1,
    day: shifted.getUTCDate(),
  };
}

export function pragueIsoDate(instant: Date): string {
  const parts = pragueParts(instant);
  const mm = String(parts.month).padStart(2, "0");
  const dd = String(parts.day).padStart(2, "0");
  return `${parts.year}-${mm}-${dd}`;
}

/** Product line (cs). "dne dd.mm.yyyy", never "za N dní". */
export function completionLabel(instant: Date): string {
  const parts = pragueParts(instant);
  const dd = String(parts.day).padStart(2, "0");
  const mm = String(parts.month).padStart(2, "0");
  return `dne ${dd}.${mm}.${parts.year}`;
}
