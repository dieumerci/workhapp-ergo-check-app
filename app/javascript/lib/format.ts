// "2026-10-09" -> "Oct 9, 2026". Parsed as a local date so the day never shifts with the time zone.
export function formatDate(iso: string): string {
  return new Date(`${iso}T00:00:00`).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
}

// "Just now", "12 min ago", then the date once it is more than an hour old.
export function formatRequested(isoTimestamp: string, now = Date.now()): string {
  const minutes = Math.floor((now - new Date(isoTimestamp).getTime()) / 60_000)
  if (minutes < 1) return 'Just now'
  if (minutes < 60) return `${minutes} min ago`
  return formatDate(isoTimestamp.slice(0, 10))
}

// 86_461 -> "24h 01m 01s", 2_467 -> "41m 07s", 7 -> "7s". The seconds always show, so it visibly counts down.
export function formatCountdown(totalSeconds: number): string {
  const seconds = Math.max(0, Math.floor(totalSeconds))
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  const two = (value: number) => String(value).padStart(2, '0')
  if (h > 0) return `${h}h ${two(m)}m ${two(s)}s`
  if (m > 0) return `${m}m ${two(s)}s`
  return `${s}s`
}

// "Sep 1, 2026 – Sep 30, 2026", "Start – Today" or "All dates".
export function formatRange(from: string, to: string): string {
  if (!from && !to) return 'All dates'
  return `${from ? formatDate(from) : 'Start'} – ${to ? formatDate(to) : 'Today'}`
}

// "Downloaded 2 times, last Oct 12, 2026" or "Not downloaded yet".
export function formatDownloads(count: number, lastIso: string | null): string {
  if (count === 0 || !lastIso) return 'Not downloaded yet'
  return `Downloaded ${count} ${count === 1 ? 'time' : 'times'}, last ${formatRequested(lastIso).toLowerCase()}`
}
