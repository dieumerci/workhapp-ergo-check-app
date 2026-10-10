import { cx } from '@/lib/cx'
import type { Pagination } from '@/types/assessments'

type Props = { pagination: Pagination; onPage: (page: number) => void }

const buttonClass = 'grid size-8 place-items-center rounded-lg border border-control bg-white text-base'

export default function Pager({ pagination, onPage }: Props) {
  const { page, pages, total, per_page } = pagination
  const first = total === 0 ? 0 : (page - 1) * per_page + 1
  const last = Math.min(total, page * per_page)

  return (
    <div className="flex items-center justify-between px-4 py-3 text-[13px] text-muted">
      <div>{total === 0 ? 'No results' : `Showing ${first}–${last} of ${total}`}</div>
      <div className="flex items-center gap-2">
        <button
          type="button"
          aria-label="Previous page"
          disabled={page <= 1}
          onClick={() => onPage(page - 1)}
          className={cx(buttonClass, page <= 1 && 'opacity-40')}
        >
          ‹
        </button>
        <span className="whitespace-nowrap tabular-nums">
          Page {page} of {pages}
        </span>
        <button
          type="button"
          aria-label="Next page"
          disabled={page >= pages}
          onClick={() => onPage(page + 1)}
          className={cx(buttonClass, page >= pages && 'opacity-40')}
        >
          ›
        </button>
      </div>
    </div>
  )
}
