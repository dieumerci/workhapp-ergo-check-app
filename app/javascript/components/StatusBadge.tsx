import { STATUS_STYLES } from '@/lib/status'
import { cx } from '@/lib/cx'
import type { StatusValue } from '@/types'

export default function StatusBadge({ status, label }: { status: StatusValue; label: string }) {
  const style = STATUS_STYLES[status]
  return (
    <span
      className={cx(
        'inline-flex items-center gap-1.5 rounded-full py-[3px] pr-2.5 pl-2 text-[12.5px] font-semibold',
        style.bg,
        style.fg,
      )}
    >
      <span className={cx('size-1.5 rounded-full', style.dot)} aria-hidden="true" />
      {label}
    </span>
  )
}
