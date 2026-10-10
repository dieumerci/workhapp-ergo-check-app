import type { StatusValue } from '@/types'

export type StatusOption = { value: StatusValue; label: string }

export type Filters = {
  status: StatusValue | 'all'
  preset: '7' | '30' | '90' | 'all' | 'custom'
  from: string
  to: string
}

export type AssessmentRow = {
  id: number
  code: string
  employee_name: string
  employee_ref: string
  department: string
  created_on: string
  status: StatusValue
  status_label: string
  score: number | null
}

export type SectionScore = { key: string; label: string; value: number }

export type AssessmentDetail = AssessmentRow & {
  score_state: 'scored' | 'awaiting_completion' | 'incomplete'
  sections: SectionScore[]
}

export type Counts = Record<StatusValue | 'all', number>

export type Pagination = { page: number; pages: number; total: number; per_page: number }

export type AssessmentsIndexProps = {
  filters: Filters
  status_options: StatusOption[]
  assessments: AssessmentRow[]
  counts: Counts
  pagination: Pagination
  selected: AssessmentDetail | null
}
