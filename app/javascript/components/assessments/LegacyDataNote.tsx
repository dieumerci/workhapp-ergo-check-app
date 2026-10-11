import { Link, usePage } from '@inertiajs/react'
import ProgressBar from '@/components/exports/ProgressBar'
import type { LegacyNote } from '@/types/assessments'

const plural = (count: number, one: string, many: string) => `${count} ${count === 1 ? one : many}`

// Years of data hold spellings such as "comp" or "n/a". The page already counts
// them under their standard status; this says so, instead of hiding the mess.
export default function LegacyDataNote({ legacy }: { legacy: LegacyNote }) {
  const { ops_pages } = usePage().props
  const total = legacy.standard + legacy.records
  const percent = Math.round((legacy.standard / total) * 100)

  const parts: string[] = []
  if (legacy.aliases > 0) {
    parts.push(`${plural(legacy.aliases, 'record uses', 'records use')} an older spelling (${legacy.spellings.join(', ')}), shown under its standard status`)
  }
  if (legacy.blank > 0) {
    parts.push(`${plural(legacy.blank, 'record has', 'records have')} no status or "n/a", shown as Pending`)
  }
  if (legacy.unknown > 0) {
    parts.push(`${plural(legacy.unknown, 'record has', 'records have')} an unrecognised value, shown as Needs follow-up for a person to review`)
  }

  return (
    <div className="flex flex-wrap items-center gap-x-6 gap-y-2 border-b border-line-soft bg-canvas px-4 py-3 text-[13px]">
      <div className="min-w-[180px]">
        <div className="font-semibold text-ink">
          {legacy.standard} of {total} use a standard status
        </div>
        <div className="mt-1.5">
          <ProgressBar value={percent} label="Records already using a standard status" />
        </div>
      </div>
      <div className="min-w-0 flex-1 text-muted">
        {parts.join('; ')}.{' '}
        <span className="text-ink-2">Anything saved from now on is always one of the five.</span>{' '}
        {ops_pages && (
          <Link href="/release_plan" className="font-semibold text-brand hover:underline">
            How the clean-up is planned
          </Link>
        )}
      </div>
    </div>
  )
}
