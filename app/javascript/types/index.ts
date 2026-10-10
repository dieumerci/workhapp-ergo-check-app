import type { ExportView } from '@/types/exports'

export type StatusOption = { value: StatusValue; label: string }

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
}

export type StatusValue =
  | 'pending'
  | 'in_progress'
  | 'completed'
  | 'needs_follow_up'
  | 'archived'
