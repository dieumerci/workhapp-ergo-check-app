import { useEffect, useState } from 'react'
import { Link, router, usePage } from '@inertiajs/react'
import Dialog from '@/components/Dialog'
import { DownloadIcon } from '@/components/Icons'
import { CompanyLock, Notice, SheetHeader } from '@/components/ui'
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
  const { status_options, export_columns, errors } = usePage().props
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
    <div className="flex flex-col gap-6">
      <SheetHeader id="export-title" title="Export assessments" subtitle="Choose a date range and status. Everything else is fixed." onClose={onClose} />

      <CompanyLock />

      <div className="grid gap-4 sm:grid-cols-2">
        <label className="field">
          <span className="eyebrow">From</span>
          <input type="date" value={filters.from} max={filters.to || undefined} onChange={(event) => setFilters({ ...filters, from: event.target.value })} className="input" />
        </label>
        <label className="field">
          <span className="eyebrow">To</span>
          <input type="date" value={filters.to} min={filters.from || undefined} onChange={(event) => setFilters({ ...filters, to: event.target.value })} className="input" />
        </label>
      </div>

      <label className="field">
        <span className="eyebrow">Status</span>
        <select value={filters.status} onChange={(event) => setFilters({ ...filters, status: event.target.value as ExportFilters['status'] })} className="input">
          <option value="all">All statuses</option>
          {status_options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
        <span className="text-[12.5px] text-muted">An export uses exactly these two filters. A search on the page is not part of it.</span>
      </label>

      <div className="flex flex-col gap-3 border-l-[3px] border-ok-dot/60 pl-4">
        <div className="eyebrow !text-ok">What&apos;s in the file</div>
        <div className="flex flex-wrap gap-1.5">
          {export_columns.map((column) => (
            <span key={column} className="rounded-md bg-ok-tint px-2 py-0.5 font-mono text-xs text-ok">
              {column}
            </span>
          ))}
        </div>
        <div className="text-[13px] text-muted">
          <strong className="text-ink">Left out:</strong> names, email addresses, free-text answers and raw responses. Employees appear as a
          one-way reference (<span className="font-mono text-xs">emp_a41f9c02d7e1</span>).
        </div>
      </div>

      {errors.export && (
        <Notice tone="danger" role="alert">
          {errors.export.map((problem) => (
            <div key={problem}>{problem}</div>
          ))}
        </Notice>
      )}

      <div className="flex flex-wrap items-center justify-between gap-3">
        <div role="status" className={cx('font-semibold', ok ? 'text-ok' : match.loading && !backwards ? 'text-muted' : 'text-danger')}>
          {message}
        </div>
        <div className="flex gap-2.5">
          <button type="button" onClick={onClose} className="btn btn-quiet">
            Cancel
          </button>
          <button type="button" onClick={request} disabled={!ok || submitting} className="btn btn-primary">
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
    <div className="flex flex-col gap-6">
      <SheetHeader id="export-title" title={title} subtitle={`${formatRange(job.from, job.to)} · ${job.status_label}`} onClose={onClose} />

      {running && (
        <div className="flex flex-col gap-2.5">
          <ProgressBar value={job.progress} label="Export progress" thick />
          <div role="status" className="text-[13px] text-muted">
            {job.state_label}… You can close this and keep working — we&apos;ll let you know when it&apos;s ready.
          </div>
        </div>
      )}

      {job.state === 'ready' && (
        <Notice tone="ok" role="status">
          <span className="font-semibold">{job.row_count} rows ready.</span> Link valid for 24 hours.
        </Notice>
      )}

      {job.error && (
        <Notice tone="danger" role="alert">
          {job.error}
        </Notice>
      )}

      {job.state === 'expired' && <Notice tone="neutral">The 24-hour download link has expired. Request the export again.</Notice>}

      <div className="flex justify-end gap-2.5">
        <Link href="/exports" onClick={onClose} className="btn btn-quiet">
          View all exports
        </Link>
        {job.download_path && (
          <a href={job.download_path} className="btn btn-primary">
            <DownloadIcon size={15} />
            Download CSV
          </a>
        )}
      </div>
    </div>
  )
}
