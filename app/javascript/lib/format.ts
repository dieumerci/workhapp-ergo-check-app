// "2026-10-09" -> "Oct 9, 2026". Parsed as a local date so the day never shifts with the time zone.
export function formatDate(iso: string): string {
  return new Date(`${iso}T00:00:00`).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
}
