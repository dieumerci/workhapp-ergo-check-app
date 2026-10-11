import { useRef, useState } from 'react'
import { Head, router, usePage } from '@inertiajs/react'
import AssessmentTable from '@/components/assessments/AssessmentTable'
import DetailDrawer from '@/components/assessments/DetailDrawer'
import FilterBar from '@/components/assessments/FilterBar'
import LegacyDataNote from '@/components/assessments/LegacyDataNote'
import NewAssessmentDialog from '@/components/assessments/NewAssessmentDialog'
import Pager from '@/components/assessments/Pager'
import StatusSpectrum from '@/components/assessments/StatusSpectrum'
import { DownloadIcon, PlusIcon } from '@/components/Icons'
import { useExports } from '@/components/exports/ExportProvider'
import { PageHeader } from '@/components/ui'
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
  if (filters.q) query.q = filters.q
  if (page > 1) query.page = page
  return query
}

// Wait a beat before showing the skeleton so fast responses don't flash it.
const SKELETON_DELAY_MS = 150

export default function Index({ filters, assessments, counts, legacy, pagination, selected, employees }: AssessmentsIndexProps) {
  const { status_options } = usePage().props
  const { openExport } = useExports()
  const [loading, setLoading] = useState(false)
  const [newOpen, setNewOpen] = useState(false)
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

  const clear = () => visit({ status: 'all', preset: 'all', from: '', to: '', q: '' })

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

  // The employee list is not part of the dashboard load; fetch it as the dialog opens.
  const openNew = () => {
    setNewOpen(true)
    router.reload({ only: ['employees'] })
  }

  const hasFilters = filters.status !== 'all' || filters.preset !== 'all' || filters.q !== ''

  return (
    <>
      <Head title="Assessments" />
      <section className="flex flex-col gap-8">
        <PageHeader
          title="Assessments"
          lead="Ergonomic and health assessments for your employees. Search them, filter them, and export them without personal identifiers."
          actions={
            <>
              <button type="button" onClick={openNew} className="btn btn-quiet">
                <PlusIcon size={15} />
                New assessment
              </button>
              <button type="button" onClick={() => openExport({ from: filters.from, to: filters.to, status: filters.status })} className="btn btn-primary">
                <DownloadIcon size={15} />
                Export CSV
              </button>
            </>
          }
        />

        <div className="flex flex-col gap-5">
          <div className="flex flex-col gap-3">
            <div className="flex items-baseline gap-3">
              <div className="display text-[56px] leading-none tabular-nums" aria-hidden="true">
                {counts.all}
              </div>
              <div className="text-[15px] text-muted">{counts.all === 1 ? 'assessment' : 'assessments'} in this view</div>
            </div>
            <StatusSpectrum counts={counts} statusOptions={status_options} />
          </div>
          <FilterBar
            filters={filters}
            counts={counts}
            statusOptions={status_options}
            hasFilters={hasFilters}
            onChange={visit}
            onClear={clear}
          />
        </div>

        {legacy && <LegacyDataNote legacy={legacy} />}

        <div className="flex flex-col gap-3">
          <AssessmentTable rows={assessments} search={filters.q} loading={loading} onOpen={openDetail} onClear={clear} />
          <Pager pagination={pagination} onPage={(page) => visit({}, page)} />
        </div>
      </section>

      <DetailDrawer detail={selected} statusOptions={status_options} onClose={closeDetail} />
      <NewAssessmentDialog open={newOpen} employees={employees} onClose={() => setNewOpen(false)} />
    </>
  )
}
