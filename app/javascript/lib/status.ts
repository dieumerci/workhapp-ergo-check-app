import type { StatusValue } from '@/types'

export const STATUS_LABELS: Record<StatusValue, string> = {
  pending: 'Pending',
  in_progress: 'In progress',
  completed: 'Completed',
  needs_follow_up: 'Needs follow-up',
  archived: 'Archived',
}

export const STATUS_ORDER: StatusValue[] = [
  'pending',
  'in_progress',
  'completed',
  'needs_follow_up',
  'archived',
]

// Background + text colour classes per status (design: "each has its own colour and label everywhere").
export const STATUS_STYLES: Record<StatusValue, { bg: string; fg: string; dot: string }> = {
  pending: { bg: 'bg-warn-tint', fg: 'text-warn', dot: 'bg-warn' },
  in_progress: { bg: 'bg-info-tint', fg: 'text-info', dot: 'bg-info' },
  completed: { bg: 'bg-ok-tint', fg: 'text-ok', dot: 'bg-ok' },
  needs_follow_up: { bg: 'bg-danger-tint', fg: 'text-danger', dot: 'bg-danger' },
  archived: { bg: 'bg-neutral-tint', fg: 'text-neutral', dot: 'bg-neutral' },
}

// Green at 80 and above, amber at 60 to 79, red below 60.
export function scoreTone(score: number): { text: string; bar: string } {
  if (score >= 80) return { text: 'text-ok', bar: 'bg-ok' }
  if (score >= 60) return { text: 'text-warn', bar: 'bg-warn' }
  return { text: 'text-danger', bar: 'bg-danger' }
}
