import { useRef, useState } from 'react'
import { Head, router, usePage } from '@inertiajs/react'
import AssessmentTable from '@/components/assessments/AssessmentTable'
import DetailDrawer from '@/components/assessments/DetailDrawer'
import FilterBar from '@/components/assessments/FilterBar'
import Pager from '@/components/assessments/Pager'
import { DownloadIcon } from '@/components/Icons'
import { useExports } from '@/components/exports/ExportProvider'
import type { AssessmentRow, AssessmentsIndexProps, Filters } from '@/types/assessments'

type Query = Record<string, string | number>

// Always sends status and preset explicitly: an explicit query beats any
// remembered-filters cookie on the server, which is what makes "Clear" work.
function buildQuery(filters: Filters, page = 1): Query {
  const query: Query = { status: filters.status, preset: filters.preset }
  if (filters.preset === 'custom') {
    query.from = filters.from
    query.to = filters.to
  }
  if (page > 1) query.page = page
  return query
}

// Wait a beat before showing the skeleton so fast responses don't flash it.
const SKELETON_DELAY_MS = 150

export default function Index({ filters, assessments, counts, pagination, selected }: AssessmentsIndexProps) {
  const { status_options } = usePage().props
  const { openExport } = useExports()
  const [loading, setLoading] = useState(false)
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)

  const visit = (next: Partial<Filters>, page = 1) => {
    router.get('/assessments', buildQuery({ ...filters, ...next }, page), {
      preserveScroll: true,
      preserveState: true,
      onStart: () => {
        timer.current = setTimeout(() => setLoading(true), SKELETON_DELAY_MS)
      },
      onFinish: () => {
        clearTimeout(timer.current)
        setLoading(false)
      },
    })
  }

  const clear = () => visit({ status: 'all', preset: 'all', from: '', to: '' })

  const openDetail = (row: AssessmentRow) =>
    router.get(
      '/assessments',
      { ...buildQuery(filters, pagination.page), selected: row.id },
      { only: ['selected'], preserveScroll: true, preserveState: true },
    )

  const closeDetail = () =>
    router.get('/assessments', buildQuery(filters, pagination.page), {
      only: ['selected'],
      preserveScroll: true,
      preserveState: true,
    })

  const hasFilters = filters.status !== 'all' || filters.preset !== 'all'

  return (
    <>
      <Head title="Assessments" />
      <section className="flex flex-col gap-[18px]">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <h1 className="text-[28px] font-bold tracking-tight">Assessments</h1>
            <div className="mt-0.5 text-muted">Ergonomic and health assessments for your employees.</div>
          </div>
          <button
            type="button"
            onClick={() => openExport({ from: filters.from, to: filters.to, status: filters.status })}
            className="inline-flex items-center gap-2 rounded-[9px] bg-brand px-4 py-2.5 text-sm font-semibold text-white hover:bg-brand-dark"
          >
            <DownloadIcon size={15} />
            Export CSV
          </button>
        </div>

        <div className="overflow-hidden rounded-[14px] border border-line bg-white">
          <FilterBar
            filters={filters}
            counts={counts}
            statusOptions={status_options}
            hasFilters={hasFilters}
            onChange={visit}
            onClear={clear}
          />
          <AssessmentTable rows={assessments} loading={loading} onOpen={openDetail} onClear={clear} />
          <Pager pagination={pagination} onPage={(page) => visit({}, page)} />
        </div>
      </section>

      <DetailDrawer detail={selected} statusOptions={status_options} onClose={closeDetail} />
    </>
  )
}
