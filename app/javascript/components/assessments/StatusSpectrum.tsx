import { STATUS_STYLES } from '@/lib/status'
import { cx } from '@/lib/cx'
import type { StatusOption } from '@/types'
import type { Counts } from '@/types/assessments'

// The page's signature: the whole view as one bar, split by status. It is a picture
// of what the chips below already say in words (and the chips are the controls), so
// it is hidden from assistive technology.
export default function StatusSpectrum({ counts, statusOptions }: { counts: Counts; statusOptions: StatusOption[] }) {
  const empty = counts.all === 0

  return (
    <div aria-hidden="true" className="flex h-2.5 w-full gap-[3px] overflow-hidden rounded-full bg-ink/5">
      {!empty &&
        statusOptions.map((option) => {
          const count = counts[option.value]
          if (count === 0) return null
          return (
            <div
              key={option.value}
              title={`${option.label}: ${count}`}
              className={cx('h-full rounded-full transition-[flex-grow] duration-500', STATUS_STYLES[option.value].dot)}
              style={{ flexGrow: count, flexBasis: 6 }}
            />
          )
        })}
    </div>
  )
}
