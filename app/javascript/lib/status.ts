import type { StatusValue } from '@/types'

// Labels and ordering come from the server (Status::LABELS), so there is one
// definition. Only the presentation lives here, and only as design tokens:
// ink = text, tint = soft fill, dot = the marker (always paired with the label).
export const STATUS_STYLES: Record<StatusValue, { bg: string; fg: string; dot: string }> = {
  pending: { bg: 'bg-warn-tint', fg: 'text-warn', dot: 'bg-warn-dot' },
  in_progress: { bg: 'bg-info-tint', fg: 'text-info', dot: 'bg-info-dot' },
  completed: { bg: 'bg-ok-tint', fg: 'text-ok', dot: 'bg-ok-dot' },
  needs_follow_up: { bg: 'bg-danger-tint', fg: 'text-danger', dot: 'bg-danger-dot' },
  archived: { bg: 'bg-neutral-tint', fg: 'text-neutral', dot: 'bg-neutral-dot' },
}

// Green at 80 and above, amber at 60 to 79, clay below 60. The number is always shown too.
export function scoreTone(score: number): { text: string; bar: string } {
  if (score >= 80) return { text: 'text-ok', bar: 'bg-ok-dot' }
  if (score >= 60) return { text: 'text-warn', bar: 'bg-warn-dot' }
  return { text: 'text-danger', bar: 'bg-danger-dot' }
}
