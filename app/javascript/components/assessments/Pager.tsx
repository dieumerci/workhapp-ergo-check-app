import { ChevronIcon } from '@/components/Icons'
import type { Pagination } from '@/types/assessments'

type Props = { pagination: Pagination; onPage: (page: number) => void }

export default function Pager({ pagination, onPage }: Props) {
  const { page, pages, total, per_page } = pagination
  const first = total === 0 ? 0 : (page - 1) * per_page + 1
  const last = Math.min(total, page * per_page)

  return (
    <div className="flex items-center justify-between gap-4 pt-1 text-[13px] text-muted">
      <div className="tabular-nums">{total === 0 ? 'No results' : `Showing ${first}–${last} of ${total}`}</div>
      <div className="flex items-center gap-2">
        <button type="button" aria-label="Previous page" disabled={page <= 1} onClick={() => onPage(page - 1)} className="btn btn-quiet !h-9 !w-9 !p-0">
          <ChevronIcon direction="left" size={15} />
        </button>
        <span className="min-w-[88px] text-center whitespace-nowrap tabular-nums">
          Page {page} of {pages}
        </span>
        <button type="button" aria-label="Next page" disabled={page >= pages} onClick={() => onPage(page + 1)} className="btn btn-quiet !h-9 !w-9 !p-0">
          <ChevronIcon direction="right" size={15} />
        </button>
      </div>
    </div>
  )
}
