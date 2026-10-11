import type { KeyboardEvent } from 'react'
import Highlight from '@/components/Highlight'
import StatusBadge from '@/components/StatusBadge'
import ScoreCell from '@/components/assessments/ScoreCell'
import { SearchIcon } from '@/components/Icons'
import { formatDate } from '@/lib/format'
import type { AssessmentRow } from '@/types/assessments'

const GRID = 'md:grid md:grid-cols-[84px_minmax(180px,1.6fr)_1fr_112px_150px_minmax(150px,1fr)] md:items-center md:gap-x-4'

type Props = {
  rows: AssessmentRow[]
  search: string
  loading: boolean
  onOpen: (row: AssessmentRow) => void
  onClear: () => void
}

function SkeletonRow() {
  return (
    <div className="animate-pulse-soft px-4 py-[18px]" aria-hidden="true">
      <div className="flex items-center gap-4">
        <div className="h-3 w-14 rounded-full bg-skeleton" />
        <div className="h-3.5 w-40 rounded-full bg-skeleton" />
        <div className="ml-auto h-3 w-24 rounded-full bg-skeleton" />
      </div>
    </div>
  )
}

export default function AssessmentTable({ rows, search, loading, onOpen, onClear }: Props) {
  const terms = search.split(' ').filter(Boolean).slice(0, 4)

  const open = (row: AssessmentRow) => (event: KeyboardEvent) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      onOpen(row)
    }
  }

  return (
    <div role="table" aria-label="Assessments" aria-busy={loading}>
      <div role="row" className={`hidden px-4 pb-3 ${GRID} eyebrow`}>
        <div role="columnheader">ID</div>
        <div role="columnheader">Employee</div>
        <div role="columnheader">Department</div>
        <div role="columnheader">Created</div>
        <div role="columnheader">Status</div>
        <div role="columnheader">Score</div>
      </div>

      <div className="divide-y divide-line-soft border-y border-line-soft">
        {loading && Array.from({ length: 6 }, (_, index) => <SkeletonRow key={index} />)}

        {!loading &&
          rows.map((row) => (
            <div
              key={row.id}
              role="row"
              tabIndex={0}
              onClick={() => onOpen(row)}
              onKeyDown={open(row)}
              className="group relative cursor-pointer px-4 py-4 transition-colors outline-none hover:bg-paper focus-visible:bg-paper focus-visible:ring-2 focus-visible:ring-brand focus-visible:ring-inset"
            >
              {/* Wide screens: a table row. */}
              <div className={`hidden ${GRID}`}>
                <div role="cell" className="font-mono text-[12.5px] text-muted">
                  <Highlight text={row.code} terms={terms} />
                </div>
                <div role="cell" className="min-w-0">
                  <div className="truncate text-[15px] font-semibold">
                    <Highlight text={row.employee_name} terms={terms} />
                  </div>
                  <div className="font-mono text-[11.5px] text-subtle">{row.employee_ref}</div>
                </div>
                <div role="cell" className="text-ink-2">
                  <Highlight text={row.department} terms={terms} />
                </div>
                <div role="cell" className="text-ink-2 tabular-nums">
                  {formatDate(row.created_on)}
                </div>
                <div role="cell">
                  <StatusBadge status={row.status} label={row.status_label} />
                </div>
                <div role="cell">
                  <ScoreCell score={row.score} />
                </div>
              </div>

              {/* Phones: the same facts as a two-line item. */}
              <div className="flex flex-col gap-1.5 md:hidden">
                <div className="flex items-baseline justify-between gap-3">
                  <div className="min-w-0 truncate text-[15px] font-semibold">
                    <Highlight text={row.employee_name} terms={terms} />
                  </div>
                  <StatusBadge status={row.status} label={row.status_label} />
                </div>
                <div className="flex items-end justify-between gap-3 text-[13px] text-muted">
                  <div className="min-w-0">
                    <span className="font-mono text-xs">
                      <Highlight text={row.code} terms={terms} />
                    </span>{' '}
                    · <Highlight text={row.department} terms={terms} /> · {formatDate(row.created_on)}
                  </div>
                  <ScoreCell score={row.score} />
                </div>
              </div>
            </div>
          ))}

        {!loading && rows.length === 0 && (
          <div className="flex flex-col items-center px-4 py-16 text-center">
            <div className="grid size-12 place-items-center rounded-full bg-brand-tint text-brand-ink">
              <SearchIcon size={20} />
            </div>
            <div className="display mt-4 text-[26px]">{search ? `Nothing matches “${search}”` : 'No assessments match these filters'}</div>
            <div className="mt-1.5 max-w-[44ch] text-muted">
              {search ? 'Check the spelling, or search a department or an A-code.' : 'Try a wider date range or a different status.'}
            </div>
            <button type="button" onClick={onClear} className="btn btn-quiet mt-5">
              {search ? 'Clear search and filters' : 'Clear filters'}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
