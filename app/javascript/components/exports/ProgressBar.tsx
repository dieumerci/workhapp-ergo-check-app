import { cx } from '@/lib/cx'

type Props = { value: number; label: string; thick?: boolean }

export default function ProgressBar({ value, label, thick = false }: Props) {
  return (
    <div
      role="progressbar"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={value}
      className={cx('rounded bg-skeleton', thick ? 'h-2' : 'h-1.5')}
    >
      <div
        className={cx('rounded bg-brand transition-[width] duration-500', thick ? 'h-2' : 'h-1.5')}
        style={{ width: `${Math.max(value, 4)}%` }}
      />
    </div>
  )
}
