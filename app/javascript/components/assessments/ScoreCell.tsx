import { scoreTone } from '@/lib/status'
import { cx } from '@/lib/cx'

export default function ScoreCell({ score }: { score: number | null }) {
  if (score === null) return <span className="text-[13px] text-subtle">Not scored yet</span>

  const tone = scoreTone(score)
  return (
    <div className="flex items-center gap-2.5">
      <div className="h-1.5 max-w-[90px] flex-1 rounded-[3px] bg-skeleton" aria-hidden="true">
        <div className={cx('h-1.5 rounded-[3px]', tone.bar)} style={{ width: `${score}%` }} />
      </div>
      <div className={cx('min-w-6 font-semibold tabular-nums', tone.text)}>
        <span className="sr-only">Score </span>
        {score}
      </div>
    </div>
  )
}
