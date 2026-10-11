import { useEffect, useState } from 'react'
import SearchField from '@/components/assessments/SearchField'
import { STATUS_STYLES } from '@/lib/status'
import { cx } from '@/lib/cx'
import type { StatusOption } from '@/types'
import type { Counts, Filters } from '@/types/assessments'

const PRESETS: Array<{ value: Filters['preset']; label: string }> = [
  { value: '7', label: '7 days' },
  { value: '30', label: '30 days' },
  { value: '90', label: '90 days' },
  { value: 'all', label: 'All time' },
]

const dateInputClass = 'input !h-9 !w-[148px] !rounded-[10px] !px-2.5 !text-[13px]'

type Props = {
  filters: Filters
  counts: Counts
  statusOptions: StatusOption[]
  hasFilters: boolean
  onChange: (next: Partial<Filters>) => void
  onClear: () => void
}

export default function FilterBar({ filters, counts, statusOptions, hasFilters, onChange, onClear }: Props) {
  // Local copies so typing a date is never overwritten by the in-flight request.
  const [from, setFrom] = useState(filters.from)
  const [to, setTo] = useState(filters.to)

  useEffect(() => {
    setFrom(filters.from)
    setTo(filters.to)
  }, [filters.from, filters.to])

  const tabs: Array<{ value: Filters['status']; label: string }> = [{ value: 'all', label: 'All' }, ...statusOptions]

  return (
    <div className="flex flex-col gap-4">
      <div role="group" aria-label="Filter by status" className="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 [scrollbar-width:none] md:mx-0 md:flex-wrap md:overflow-visible md:px-0 [&::-webkit-scrollbar]:hidden">
        {tabs.map((tab) => {
          const active = filters.status === tab.value
          const style = tab.value === 'all' ? null : STATUS_STYLES[tab.value]
          return (
            <button
              key={tab.value}
              type="button"
              aria-pressed={active}
              onClick={() => onChange({ status: tab.value })}
              className={cx(
                'inline-flex h-10 flex-none items-center gap-2 rounded-full border px-4 text-[13.5px] font-semibold transition-all',
                active
                  ? 'border-ink bg-ink text-white shadow-[0_4px_14px_rgb(24_32_28/0.22)]'
                  : 'border-line bg-paper/70 text-ink-2 hover:border-control hover:bg-paper',
              )}
            >
              {style && <span className={cx('size-2 rounded-full', style.dot)} aria-hidden="true" />}
              <span>{tab.label}</span>
              <span className={cx('font-mono text-xs tabular-nums', active ? 'text-white/75' : 'text-subtle')}>{counts[tab.value]}</span>
            </button>
          )
        })}
      </div>

      <div className="flex flex-wrap items-center gap-3 rounded-[22px] border border-line bg-paper/60 p-2.5">
        <SearchField value={filters.q} onSearch={(q) => onChange({ q })} />

        <div role="group" aria-label="Date range preset" className="segmented">
          {PRESETS.map((preset) => (
            <button
              key={preset.value}
              type="button"
              aria-pressed={filters.preset === preset.value}
              onClick={() => onChange({ preset: preset.value })}
              className="segment"
            >
              {preset.label}
            </button>
          ))}
        </div>

        <div className="flex flex-wrap items-center gap-2 text-[13px] text-muted">
          <label className="flex items-center gap-2">
            From
            <input
              type="date"
              value={from}
              max={to || undefined}
              onChange={(event) => {
                setFrom(event.target.value)
                onChange({ preset: 'custom', from: event.target.value, to })
              }}
              className={dateInputClass}
            />
          </label>
          <label className="flex items-center gap-2">
            To
            <input
              type="date"
              value={to}
              min={from || undefined}
              onChange={(event) => {
                setTo(event.target.value)
                onChange({ preset: 'custom', from, to: event.target.value })
              }}
              className={dateInputClass}
            />
          </label>
        </div>

        {hasFilters && (
          <button type="button" onClick={onClear} className="btn btn-text btn-sm ml-auto">
            Clear filters
          </button>
        )}
      </div>
    </div>
  )
}
