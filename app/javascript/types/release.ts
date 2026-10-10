import type { StatusValue } from '@/types'

export type MappingRow = { from: string[]; to: StatusValue; label: string; rule: string }
export type PlanStep = { title: string; detail: string; command: string; window: boolean }
export type RollbackRung = { when: string; what: string }

export type NormalizeResult = {
  backfill: { status: StatusValue; label: string; why: string }
  save: { accepted: boolean; status: StatusValue | null; label: string | null; title: string; why: string }
}

export type ReleasePlanProps = {
  mapping: MappingRow[]
  steps: PlanStep[]
  rollback: RollbackRung[]
  samples: string[]
}
