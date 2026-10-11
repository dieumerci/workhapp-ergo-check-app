import { STATUS_STYLES } from '@/lib/status'
import { cx } from '@/lib/cx'
import type { StatusValue } from '@/types'

// A quiet marker plus the label, in the status's ink colour: no filled pill,
// so a table of statuses reads as a column of words, not a row of stickers.
export default function StatusBadge({ status, label }: { status: StatusValue; label: string }) {
  const style = STATUS_STYLES[status]
  return (
    <span className={cx('inline-flex items-center gap-2 text-[13.5px] font-semibold', style.fg)}>
      <span className={cx('size-2 rounded-full', style.dot)} aria-hidden="true" />
      {label}
    </span>
  )
}
