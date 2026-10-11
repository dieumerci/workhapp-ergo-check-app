import { cx } from '@/lib/cx'
import type { ExportState } from '@/types/exports'

const STYLES: Record<ExportState, { text: string; dot: string }> = {
  queued: { text: 'text-neutral', dot: 'bg-neutral-dot' },
  processing: { text: 'text-info', dot: 'bg-info-dot animate-pulse-soft' },
  ready: { text: 'text-ok', dot: 'bg-ok-dot' },
  failed: { text: 'text-danger', dot: 'bg-danger-dot' },
  expired: { text: 'text-neutral', dot: 'bg-neutral-dot' },
}

export default function StateBadge({ state, label }: { state: ExportState; label: string }) {
  const style = STYLES[state]
  return (
    <span className={cx('inline-flex items-center gap-2 text-[13.5px] font-semibold', style.text)}>
      <span className={cx('size-2 rounded-full', style.dot)} aria-hidden="true" />
      {label}
    </span>
  )
}
