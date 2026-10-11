import { useEffect, useState } from 'react'
import { router } from '@inertiajs/react'
import Dialog from '@/components/Dialog'
import { CloseIcon, LockIcon } from '@/components/Icons'
import { formatDate } from '@/lib/format'
import { STATUS_STYLES, scoreTone } from '@/lib/status'
import { cx } from '@/lib/cx'
import type { AssessmentDetail } from '@/types/assessments'
import type { StatusOption, StatusValue } from '@/types'

type Props = { detail: AssessmentDetail | null; statusOptions: StatusOption[]; onClose: () => void }

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

  // A fresh response (saved or rejected) is the source of truth for the control.
  useEffect(() => setStatus(detail.status), [detail])

  const change = (next: StatusValue) => {
    if (next === status) return
    setStatus(next)
    router.patch(`/assessments/${detail.id}`, { status: next }, { preserveScroll: true, preserveState: true })
  }

  const tone = detail.score === null ? null : scoreTone(detail.score)

  return (
    <div className="flex flex-col gap-7">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="eyebrow font-mono !tracking-[0.08em] !normal-case">{detail.code}</div>
          <h2 id="drawer-title" className="display mt-1.5 text-[34px]">
            {detail.employee_name}
          </h2>
          <div className="mt-2 text-[14px] text-muted">
            {detail.department} · Created {formatDate(detail.created_on)}
          </div>
          <div className="mt-1 font-mono text-[11.5px] text-subtle">{detail.employee_ref}</div>
        </div>
        <button type="button" onClick={onClose} aria-label="Close" className="icon-btn -mt-1 -mr-2 flex-none">
          <CloseIcon size={15} />
        </button>
      </div>

      <section aria-labelledby="status-label" className="flex flex-col gap-3">
        <div id="status-label" className="eyebrow">
          Status
        </div>
        <div role="radiogroup" aria-labelledby="status-label" className="flex flex-wrap gap-2">
          {statusOptions.map((option) => {
            const active = status === option.value
            return (
              <button
                key={option.value}
                type="button"
                role="radio"
                aria-checked={active}
                onClick={() => change(option.value)}
                className={cx(
                  'inline-flex h-10 items-center gap-2 rounded-full border px-4 text-[13.5px] font-semibold transition-all',
                  active ? 'border-ink bg-ink text-white shadow-[0_4px_14px_rgb(24_32_28/0.22)]' : 'border-line bg-paper text-ink-2 hover:border-control',
                )}
              >
                <span className={cx('size-2 rounded-full', STATUS_STYLES[option.value].dot)} aria-hidden="true" />
                {option.label}
              </button>
            )
          })}
        </div>
        <div className="text-[12.5px] text-muted">Only the five standard statuses can be saved.</div>
      </section>

      <section className="flex flex-col gap-4">
        <div className="flex items-end justify-between">
          <div className="eyebrow">Ergonomic score</div>
          {tone && detail.score !== null && (
            <div className={cx('display text-[56px] leading-none', tone.text)}>
              {detail.score}
              <span className="ml-1 font-sans text-sm font-medium text-subtle">/ 100</span>
            </div>
          )}
        </div>

        {detail.score_state === 'scored' ? (
          <>
            <div className="-mt-1 text-[13px] text-muted">Average of the four section scores, rounded.</div>
            <div className="flex flex-col gap-3.5">
              {detail.sections.map((section) => (
                <div key={section.key} className="grid grid-cols-[148px_1fr_30px] items-center gap-3 text-[13px]">
                  <div className="text-ink-2">{section.label}</div>
                  <div className="h-1.5 overflow-hidden rounded-full bg-ink/8" aria-hidden="true">
                    <div className={cx('h-full rounded-full', scoreTone(section.value).bar)} style={{ width: `${section.value}%` }} />
                  </div>
                  <div className="text-right font-semibold tabular-nums">{section.value}</div>
                </div>
              ))}
            </div>
          </>
        ) : (
          <div className="border-l-[3px] border-line py-1 pl-4 text-muted">{EXPLANATIONS[detail.score_state]}</div>
        )}
      </section>

      <div className="flex gap-3 border-t border-line-soft pt-5 text-[13px] text-muted">
        <LockIcon size={16} className="mt-0.5 flex-none" strokeWidth={1.6} />
        <div>Free-text answers and raw responses are not shown here and are never included in exports.</div>
      </div>
    </div>
  )
}
