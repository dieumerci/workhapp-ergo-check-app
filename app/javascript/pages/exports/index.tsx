import { Head, router, usePage } from '@inertiajs/react'
import { DownloadIcon } from '@/components/Icons'
import ProgressBar from '@/components/exports/ProgressBar'
import StateBadge from '@/components/exports/StateBadge'
import { useExports } from '@/components/exports/ExportProvider'
import { formatRange, formatRequested } from '@/lib/format'
import type { ExportView } from '@/types/exports'

const GRID = 'grid grid-cols-[minmax(0,1.6fr)_150px_minmax(120px,1fr)_150px] items-center gap-4'

export default function Index() {
  const { exports, auth } = usePage().props
  const { openExport, openJob } = useExports()

  const retry = (job: ExportView) =>
    router.post(`/exports/${job.id}/retry`, {}, {
      preserveScroll: true,
      onSuccess: (page) => {
        if (page.flash.export_id) openJob(page.flash.export_id)
      },
    })

  return (
    <>
      <Head title="Exports" />
      <section className="flex flex-col gap-[18px]">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <h1 className="text-[28px] font-bold tracking-tight">Exports</h1>
            <div className="mt-0.5 text-muted">
              CSV files are built in the background. Personal identifiers and free-text answers are never included.
            </div>
          </div>
          <button
            type="button"
            onClick={() => openExport()}
            className="inline-flex items-center gap-2 rounded-[9px] bg-brand px-4 py-2.5 text-sm font-semibold text-white hover:bg-brand-dark"
          >
            New export
          </button>
        </div>

        <div className="overflow-hidden rounded-[14px] border border-line bg-white">
          {exports.length === 0 && (
            <div className="px-4 py-14 text-center text-muted">
              <div className="text-[15px] font-semibold text-ink">No exports yet</div>
              <div className="mt-1">Request one to get a CSV of your company&apos;s assessments.</div>
            </div>
          )}

          {exports.map((job) => (
            <div key={job.id} className={`${GRID} border-b border-line-soft p-4 last:border-b-0`}>
              <div className="min-w-0">
                <div className="font-semibold">{formatRange(job.from, job.to)}</div>
                <div className="mt-0.5 text-[13px] text-muted">
                  {job.status_label} · Requested {formatRequested(job.requested_at)}
                </div>
                {job.error && <div className="mt-1 text-[13px] text-danger">{job.error}</div>}
              </div>
              <div>
                <StateBadge state={job.state} label={job.state_label} />
              </div>
              <div>
                {(job.state === 'queued' || job.state === 'processing') && <ProgressBar value={job.progress} label="Export progress" />}
                {job.state === 'ready' && <span className="tabular-nums text-muted">{job.row_count} rows</span>}
              </div>
              <div className="text-right">
                {job.download_path && (
                  <a
                    href={job.download_path}
                    className="inline-flex items-center gap-1.5 rounded-lg border border-brand bg-white px-3 py-1.5 text-[13px] font-semibold text-brand hover:bg-brand-tint"
                  >
                    <DownloadIcon size={13} />
                    Download CSV
                  </a>
                )}
                {job.can_retry && (
                  <button
                    type="button"
                    onClick={() => retry(job)}
                    className="rounded-lg border border-control bg-white px-3 py-1.5 text-[13px] font-semibold hover:bg-canvas"
                  >
                    Retry
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>

        <div className="text-[13px] text-muted">
          Download links stay valid for 24 hours. Exports are limited to {auth.company?.name}, taken from your signed-in account.
        </div>
      </section>
    </>
  )
}
