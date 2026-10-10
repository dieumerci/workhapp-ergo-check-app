import { useEffect, useState } from 'react'
import { router } from '@inertiajs/react'
import Dialog from '@/components/Dialog'
import { CloseIcon, LockIcon } from '@/components/Icons'
import { formatDate } from '@/lib/format'
import { scoreTone } from '@/lib/status'
import { cx } from '@/lib/cx'
import type { AssessmentDetail, StatusOption } from '@/types/assessments'
import type { StatusValue } from '@/types'

type Props = { detail: AssessmentDetail | null; statusOptions: StatusOption[]; onClose: () => void }

const sectionLabel = 'text-xs font-semibold tracking-wider text-muted uppercase'

const EXPLANATIONS = {
  awaiting_completion: 'A score is calculated once the assessment is marked completed.',
  incomplete: 'Some section scores are missing or unreadable, so no score can be calculated for this assessment.',
} as const

export default function DetailDrawer({ detail, statusOptions, onClose }: Props) {
  return (
    <Dialog open={detail !== null} onClose={onClose} labelledBy="drawer-title" variant="drawer">
      {detail && <DrawerBody detail={detail} statusOptions={statusOptions} onClose={onClose} />}
    </Dialog>
  )
}

function DrawerBody({ detail, statusOptions, onClose }: { detail: AssessmentDetail } & Omit<Props, 'detail'>) {
  const [status, setStatus] = useState<StatusValue>(detail.status)

  // A fresh response (saved or rejected) is the source of truth for the select.
  useEffect(() => setStatus(detail.status), [detail])

  const change = (next: StatusValue) => {
    setStatus(next)
    router.patch(`/assessments/${detail.id}`, { status: next }, { preserveScroll: true, preserveState: true })
  }

  const tone = detail.score === null ? null : scoreTone(detail.score)

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="font-mono text-[12.5px] text-muted">{detail.code}</div>
          <h2 id="drawer-title" className="mt-0.5 text-[22px] font-bold tracking-tight">
            {detail.employee_name}
          </h2>
          <div className="text-muted">
            {detail.department} · Created {formatDate(detail.created_on)}
          </div>
          <div className="mt-0.5 font-mono text-[11.5px] text-subtle">{detail.employee_ref}</div>
        </div>
        <button
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="grid size-8 flex-none place-items-center rounded-lg bg-canvas hover:bg-hover"
        >
          <CloseIcon size={14} />
        </button>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="status-select" className={sectionLabel}>
          Status
        </label>
        <select
          id="status-select"
          value={status}
          onChange={(event) => change(event.target.value as StatusValue)}
          className="rounded-[9px] border border-control bg-white px-2.5 py-[9px] text-sm text-ink"
        >
          {statusOptions.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
        <div className="text-[12.5px] text-muted">Only the five standard statuses can be saved.</div>
      </div>

      <div className="flex flex-col gap-3">
        <div className="flex items-baseline justify-between">
          <div className={sectionLabel}>Ergonomic score</div>
          {tone && detail.score !== null && (
            <div className={cx('text-[30px] font-bold tracking-tight', tone.text)}>
              {detail.score}
              <span className="text-sm font-medium text-subtle"> / 100</span>
            </div>
          )}
        </div>

        {detail.score_state === 'scored' ? (
          <>
            <div className="-mt-1.5 text-[13px] text-muted">Average of the four section scores, rounded.</div>
            {detail.sections.map((section) => (
              <div key={section.key} className="grid grid-cols-[150px_1fr_28px] items-center gap-2.5 text-[13px]">
                <div className="text-ink-2">{section.label}</div>
                <div className="h-1.5 rounded-[3px] bg-skeleton" aria-hidden="true">
                  <div
                    className={cx('h-1.5 rounded-[3px]', scoreTone(section.value).bar)}
                    style={{ width: `${section.value}%` }}
                  />
                </div>
                <div className="text-right font-semibold tabular-nums">{section.value}</div>
              </div>
            ))}
          </>
        ) : (
          <div className="rounded-[10px] bg-canvas p-3.5 text-muted">{EXPLANATIONS[detail.score_state]}</div>
        )}
      </div>

      <div className="flex gap-2.5 rounded-[10px] bg-canvas px-3.5 py-3 text-[13px] text-muted">
        <LockIcon size={16} className="mt-0.5 flex-none" strokeWidth={1.6} />
        <div>Free-text answers and raw responses are not shown here and are never included in exports.</div>
      </div>
    </div>
  )
}
