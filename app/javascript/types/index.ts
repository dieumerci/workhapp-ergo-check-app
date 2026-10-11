import type { ExportView } from '@/types/exports'

// `scored`: the status shows an ergonomic score (so section scores can be entered for it).
export type StatusOption = { value: StatusValue; label: string; scored: boolean }

export type ScoreSection = { key: string; label: string }

export type FlashData = {
  notice?: string
  alert?: string
  export_id?: number
}

export type AuthAdmin = { name: string; initials: string }

export type SharedProps = {
  auth: {
    admin: AuthAdmin | null
    company: { name: string } | null
  }
  cookie_consent: { decided: boolean; preferences: boolean }
  exports: ExportView[]
  export_columns: string[]
  status_options: StatusOption[]
  score_sections: ScoreSection[]
  ops_pages: boolean
  // Off unless a key (or the offline rules) is configured on the server.
  assistant: { enabled: false } | { enabled: true; provider: string; offline: boolean }
}

export type StatusValue =
  | 'pending'
  | 'in_progress'
  | 'completed'
  | 'needs_follow_up'
  | 'archived'
