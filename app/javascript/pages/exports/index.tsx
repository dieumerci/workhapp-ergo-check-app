import { Head, router, usePage } from '@inertiajs/react'
import { DownloadIcon } from '@/components/Icons'
import ExportLink from '@/components/exports/ExportLink'
import ProgressBar from '@/components/exports/ProgressBar'
import StateBadge from '@/components/exports/StateBadge'
import { useExports } from '@/components/exports/ExportProvider'
import { PageHeader } from '@/components/ui'
import { formatDownloads, formatRange, formatRequested } from '@/lib/format'
import type { ExportView } from '@/types/exports'

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
      <section className="flex flex-col gap-8">
        <PageHeader
          title="Exports"
          lead="CSV files are built in the background. Personal identifiers and free-text answers are never included."
          actions={
            <button type="button" onClick={() => openExport()} className="btn btn-primary">
              <DownloadIcon size={15} />
              New export
            </button>
          }
        />

        <div className="divide-y divide-line-soft border-y border-line-soft">
          {exports.length === 0 && (
            <div className="flex flex-col items-center px-4 py-16 text-center">
              <div className="grid size-12 place-items-center rounded-full bg-brand-tint text-brand-ink">
                <DownloadIcon size={20} />
              </div>
              <div className="display mt-4 text-[26px]">No exports yet</div>
              <div className="mt-1.5 max-w-[44ch] text-muted">Request one to get a CSV of your company&apos;s assessments, with no names or e-mail addresses in it.</div>
              <button type="button" onClick={() => openExport()} className="btn btn-quiet mt-5">
                New export
              </button>
            </div>
          )}

          {exports.map((job) => (
            <div key={job.id} className="grid items-center gap-x-6 gap-y-3 px-4 py-5 md:grid-cols-[minmax(0,1.7fr)_150px_minmax(120px,1fr)_150px]">
              <div className="min-w-0">
                <div className="text-[16px] font-semibold">{formatRange(job.from, job.to)}</div>
                <div className="mt-1 text-[13px] text-muted">
                  {job.status_label} · Requested {formatRequested(job.requested_at)} by {job.requested_by}
                </div>
                {job.state === 'ready' && <div className="mt-0.5 text-[13px] text-muted">{formatDownloads(job.download_count, job.last_downloaded_at)}</div>}
                {job.error && <div className="mt-1.5 text-[13px] font-medium text-danger">{job.error}</div>}
                <ExportLink job={job} />
              </div>
              <div>
                <StateBadge state={job.state} label={job.state_label} />
              </div>
              <div>
                {(job.state === 'queued' || job.state === 'processing') && <ProgressBar value={job.progress} label="Export progress" />}
                {job.state === 'ready' && <span className="tabular-nums text-muted">{job.row_count} rows</span>}
              </div>
              <div className="md:text-right">
                {job.download_path && (
                  <a href={job.download_path} className="btn btn-quiet btn-sm">
                    <DownloadIcon size={13} />
                    Download CSV
                  </a>
                )}
                {job.can_retry && (
                  <button type="button" onClick={() => retry(job)} className="btn btn-quiet btn-sm">
                    Retry
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>

        <div className="max-w-[70ch] text-[13px] text-muted">
          Download links stay valid for 24 hours. Exports are limited to {auth.company?.name}, taken from your signed-in account.
          Every export records who requested it and how often it was downloaded, so you can see where this data went.
        </div>
      </section>
    </>
  )
}
