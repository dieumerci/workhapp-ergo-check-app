import { cx } from '@/lib/cx'
import type { ExportState } from '@/types/exports'

const STYLES: Record<ExportState, string> = {
  queued: 'bg-neutral-tint text-neutral',
  processing: 'bg-info-tint text-info',
  ready: 'bg-ok-tint text-ok',
  failed: 'bg-danger-tint text-danger',
  expired: 'bg-neutral-tint text-neutral',
}

export default function StateBadge({ state, label }: { state: ExportState; label: string }) {
  return (
    <span className={cx('inline-flex items-center gap-1.5 rounded-full px-2.5 py-[3px] text-[12.5px] font-semibold', STYLES[state])}>
      {label}
    </span>
  )
}
