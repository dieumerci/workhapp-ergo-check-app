import type { KeyboardEvent } from 'react'
import StatusBadge from '@/components/StatusBadge'
import ScoreCell from '@/components/assessments/ScoreCell'
import Highlight from '@/components/Highlight'
import { formatDate } from '@/lib/format'
import type { AssessmentRow } from '@/types/assessments'

const GRID = 'grid grid-cols-[96px_minmax(190px,1.5fr)_1fr_116px_150px_minmax(150px,1fr)] gap-3 px-4'

type Props = {
  rows: AssessmentRow[]
  search: string
  loading: boolean
  onOpen: (row: AssessmentRow) => void
  onClear: () => void
}

function SkeletonRow() {
  return (
    <div className={`${GRID} animate-pulse-soft border-b border-line-soft py-[15px]`} aria-hidden="true">
      <div className="h-3 w-[60px] rounded bg-skeleton" />
      <div className="h-3 w-[70%] rounded bg-skeleton" />
      <div className="h-3 w-1/2 rounded bg-skeleton" />
      <div className="h-3 w-[70px] rounded bg-skeleton" />
      <div className="h-5 w-[90px] rounded-full bg-skeleton" />
      <div className="h-3 w-4/5 rounded bg-skeleton" />
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
    <div className="overflow-x-auto">
      <div role="table" aria-label="Assessments" aria-busy={loading} className="min-w-[780px]">
        <div
          role="row"
          className={`${GRID} border-b border-line bg-head py-2.5 text-xs font-semibold tracking-wider text-muted uppercase`}
        >
          <div role="columnheader">ID</div>
          <div role="columnheader">Employee</div>
          <div role="columnheader">Department</div>
          <div role="columnheader">Created</div>
          <div role="columnheader">Status</div>
          <div role="columnheader">Score</div>
        </div>

        {loading && Array.from({ length: 6 }, (_, index) => <SkeletonRow key={index} />)}

        {!loading &&
          rows.map((row) => (
            <div
              key={row.id}
              role="row"
              tabIndex={0}
              onClick={() => onOpen(row)}
              onKeyDown={open(row)}
              className={`${GRID} cursor-pointer items-center border-b border-line-soft py-3 hover:bg-row-hover`}
            >
              <div role="cell" className="font-mono text-[12.5px] text-muted">
                <Highlight text={row.code} terms={terms} />
              </div>
              <div role="cell" className="min-w-0">
                <div className="truncate font-semibold">
                  <Highlight text={row.employee_name} terms={terms} />
                </div>
                <div className="font-mono text-[11.5px] text-subtle">{row.employee_ref}</div>
              </div>
              <div role="cell" className="text-ink-2">
                <Highlight text={row.department} terms={terms} />
              </div>
              <div role="cell" className="text-ink-2">
                {formatDate(row.created_on)}
              </div>
              <div role="cell">
                <StatusBadge status={row.status} label={row.status_label} />
              </div>
              <div role="cell">
                <ScoreCell score={row.score} />
              </div>
            </div>
          ))}

        {!loading && rows.length === 0 && (
          <div className="px-4 py-14 text-center text-muted">
            <div className="text-[15px] font-semibold text-ink">
              {search ? `No assessments match “${search}”` : 'No assessments match these filters'}
            </div>
            <div className="mt-1">
              {search ? 'Check the spelling, or search a department or an A-code.' : 'Try a wider date range or a different status.'}
            </div>
            <button
              type="button"
              onClick={onClear}
              className="mt-3.5 rounded-lg border border-control bg-white px-3.5 py-[7px] text-[13px] font-semibold hover:bg-hover"
            >
              {search ? 'Clear search and filters' : 'Clear filters'}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
