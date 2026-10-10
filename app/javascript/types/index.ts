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
}

export type StatusValue =
  | 'pending'
  | 'in_progress'
  | 'completed'
  | 'needs_follow_up'
  | 'archived'
