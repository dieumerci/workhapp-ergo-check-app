import { scoreTone } from '@/lib/status'
import { cx } from '@/lib/cx'

export default function ScoreCell({ score }: { score: number | null }) {
  if (score === null) return <span className="text-[13px] whitespace-nowrap text-subtle">Not scored yet</span>

  const tone = scoreTone(score)
  return (
    <div className="flex items-center gap-3">
      <div className={cx('min-w-7 text-[17px] leading-none font-bold tabular-nums', tone.text)}>
        <span className="sr-only">Score </span>
        {score}
      </div>
      <div className="h-[5px] w-14 overflow-hidden rounded-full bg-skeleton" aria-hidden="true">
        <div className={cx('h-full rounded-full transition-[width] duration-500', tone.bar)} style={{ width: `${score}%` }} />
      </div>
    </div>
  )
}
