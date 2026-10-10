import { useEffect, useState } from 'react'
import { Link, router, usePage } from '@inertiajs/react'
import Dialog from '@/components/Dialog'
import { CloseIcon, LockIcon } from '@/components/Icons'
import ProgressBar from '@/components/exports/ProgressBar'
import { formatRange } from '@/lib/format'
import { cx } from '@/lib/cx'
import type { ExportFilters, ExportView } from '@/types/exports'

type Props = {
  open: boolean
  jobId: number | null
  initial: ExportFilters
  onJob: (id: number) => void
  onClose: () => void
}

type Match = { loading: boolean; count: number; error: string | null }

const labelClass = 'flex flex-col gap-1.5 text-xs font-semibold tracking-wider text-muted uppercase'
const controlClass =
  'rounded-[9px] border border-control bg-white px-2.5 py-[9px] text-sm font-normal tracking-normal text-ink normal-case'
const ghostButton = 'rounded-[9px] border border-control bg-white px-3.5 py-[9px] font-semibold hover:bg-hover'
const primaryButton = 'rounded-[9px] bg-brand px-4 py-[9px] font-semibold text-white hover:bg-brand-dark'

export default function ExportModal({ open, jobId, initial, onJob, onClose }: Props) {
  const { exports } = usePage().props
  const job = jobId === null ? undefined : exports.find((candidate) => candidate.id === jobId)

  return (
    <Dialog open={open} onClose={onClose} labelledBy="export-title">
      {job ? <JobView job={job} onClose={onClose} /> : <FormView key={String(open)} initial={initial} onJob={onJob} onClose={onClose} />}
    </Dialog>
  )
}

function FormView({ initial, onJob, onClose }: { initial: ExportFilters; onJob: (id: number) => void; onClose: () => void }) {
  const { auth, status_options, export_columns, errors } = usePage().props
  const [filters, setFilters] = useState(initial)
  const [match, setMatch] = useState<Match>({ loading: true, count: 0, error: null })
  const [submitting, setSubmitting] = useState(false)

  const backwards = Boolean(filters.from && filters.to && filters.from > filters.to)

  // How many rows this export would contain, from the same server code that builds the file.
  useEffect(() => {
    if (backwards) return
    const controller = new AbortController()
    const timer = setTimeout(async () => {
      setMatch((current) => ({ ...current, loading: true }))
      const query = new URLSearchParams({ status: filters.status })
      if (filters.from) query.set('from', filters.from)
      if (filters.to) query.set('to', filters.to)
      try {
        const response = await fetch(`/exports/preview?${query}`, {
          headers: { Accept: 'application/json' },
          credentials: 'same-origin',
          signal: controller.signal,
        })
        const body = (await response.json()) as { count: number; error: string | null }
        setMatch({ loading: false, count: body.count, error: body.error })
      } catch (error) {
        if ((error as Error).name !== 'AbortError') setMatch({ loading: false, count: 0, error: 'Could not check how many rows match.' })
      }
    }, 200)
    return () => {
      clearTimeout(timer)
      controller.abort()
    }
  }, [filters, backwards])

  const ok = !backwards && !match.loading && match.count > 0 && !match.error
  const message = backwards
    ? 'Start date is after end date'
    : match.error
      ? match.error
      : match.loading
        ? 'Checking…'
        : match.count > 0
          ? `${match.count} assessments will be exported`
          : 'No assessments match'

  const request = () => {
    if (!ok) return
    setSubmitting(true)
    router.post('/exports', { ...filters }, {
      preserveScroll: true,
      preserveState: true,
      onSuccess: (page) => {
        if (page.flash.export_id) onJob(page.flash.export_id)
      },
      onFinish: () => setSubmitting(false),
    })
  }

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-start justify-between">
        <div>
          <h2 id="export-title" className="text-xl font-bold tracking-tight">
            Export assessments
          </h2>
          <div className="mt-0.5 text-muted">Choose a date range and status. Everything else is fixed.</div>
        </div>
        <button type="button" onClick={onClose} aria-label="Close" className="grid size-8 flex-none place-items-center rounded-lg bg-canvas hover:bg-hover">
          <CloseIcon size={14} />
        </button>
      </div>

      <div className="flex items-center gap-2.5 rounded-[10px] bg-brand-tint px-3 py-2.5 text-[13px] text-brand-dark">
        <LockIcon size={15} className="flex-none" />
        <div>
          <strong>{auth.company?.name}</strong> only — set by your account, not editable.
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <label className={labelClass}>
          From
          <input type="date" value={filters.from} max={filters.to || undefined} onChange={(event) => setFilters({ ...filters, from: event.target.value })} className={controlClass} />
        </label>
        <label className={labelClass}>
          To
          <input type="date" value={filters.to} min={filters.from || undefined} onChange={(event) => setFilters({ ...filters, to: event.target.value })} className={controlClass} />
        </label>
      </div>

      <label className={labelClass}>
        Status
        <select value={filters.status} onChange={(event) => setFilters({ ...filters, status: event.target.value as ExportFilters['status'] })} className={controlClass}>
          <option value="all">All statuses</option>
          {status_options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </label>

      <div className="flex flex-col gap-2.5 rounded-xl border border-line p-3.5">
        <div className="text-[13px] font-semibold">What&apos;s in the file</div>
        <div className="flex flex-wrap gap-1.5">
          {export_columns.map((column) => (
            <span key={column} className="rounded-[5px] bg-ok-tint px-[7px] py-0.5 font-mono text-xs text-ok">
              {column}
            </span>
          ))}
        </div>
        <div className="text-[13px] text-muted">
          <strong className="text-ink">Left out:</strong> names, email addresses, free-text answers and raw responses. Employees appear as a
          one-way reference (<span className="font-mono text-xs">emp_a41f9c02</span>).
        </div>
      </div>

      {errors.export && (
        <div role="alert" className="rounded-[10px] bg-danger-tint px-3 py-2.5 text-[13px] font-medium text-danger">
          {errors.export.map((problem) => (
            <div key={problem}>{problem}</div>
          ))}
        </div>
      )}

      <div className="flex flex-wrap items-center justify-between gap-3">
        <div role="status" className={cx('font-semibold', ok ? 'text-ok' : match.loading && !backwards ? 'text-muted' : 'text-danger')}>
          {message}
        </div>
        <div className="flex gap-2">
          <button type="button" onClick={onClose} className={ghostButton}>
            Cancel
          </button>
          <button type="button" onClick={request} disabled={!ok || submitting} className={cx(primaryButton, (!ok || submitting) && 'opacity-40')}>
            {submitting ? 'Requesting…' : 'Request export'}
          </button>
        </div>
      </div>
    </div>
  )
}

function JobView({ job, onClose }: { job: ExportView; onClose: () => void }) {
  const running = job.state === 'queued' || job.state === 'processing'
  const title = job.state === 'ready' ? 'Export ready' : job.state === 'failed' ? 'Export failed' : job.state === 'expired' ? 'Export expired' : 'Preparing your export'

  return (
    <div className="flex flex-col gap-[18px]">
      <div className="flex items-start justify-between">
        <div>
          <h2 id="export-title" className="text-xl font-bold tracking-tight">
            {title}
          </h2>
          <div className="mt-0.5 text-muted">
            {formatRange(job.from, job.to)} · {job.status_label}
          </div>
        </div>
        <button type="button" onClick={onClose} aria-label="Close" className="grid size-8 flex-none place-items-center rounded-lg bg-canvas hover:bg-hover">
          <CloseIcon size={14} />
        </button>
      </div>

      {running && (
        <div className="flex flex-col gap-2">
          <ProgressBar value={job.progress} label="Export progress" thick />
          <div role="status" className="text-[13px] text-muted">
            {job.state_label}… You can close this and keep working — we&apos;ll let you know when it&apos;s ready.
          </div>
        </div>
      )}

      {job.state === 'ready' && (
        <div role="status" className="rounded-[10px] bg-ok-tint px-3.5 py-3 font-semibold text-ok">
          {job.row_count} rows ready. Link valid for 24 hours.
        </div>
      )}

      {job.error && (
        <div role="alert" className="rounded-[10px] bg-danger-tint px-3.5 py-3 text-[13px] font-medium text-danger">
          {job.error}
        </div>
      )}

      {job.state === 'expired' && (
        <div className="rounded-[10px] bg-canvas px-3.5 py-3 text-[13px] text-muted">The 24-hour download link has expired. Request the export again.</div>
      )}

      <div className="flex justify-end gap-2">
        <Link href="/exports" onClick={onClose} className={ghostButton}>
          View all exports
        </Link>
        {job.download_path && (
          <a href={job.download_path} className={primaryButton}>
            Download CSV
          </a>
        )}
      </div>
    </div>
  )
}
