import { useEffect, useState } from 'react'
import { cx } from '@/lib/cx'
import type { Counts, Filters, StatusOption } from '@/types/assessments'

const PRESETS: Array<{ value: Filters['preset']; label: string }> = [
  { value: '7', label: '7 days' },
  { value: '30', label: '30 days' },
  { value: '90', label: '90 days' },
  { value: 'all', label: 'All time' },
]

const dateInputClass =
  'rounded-lg border border-control bg-white px-2 py-1.5 text-[13px] text-ink'

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

  const tabs: Array<{ value: Filters['status']; label: string }> = [
    { value: 'all', label: 'All' },
    ...statusOptions,
  ]

  return (
    <div className="flex flex-col gap-3 border-b border-line px-4 py-3.5">
      <div role="group" aria-label="Filter by status" className="flex flex-wrap gap-1.5">
        {tabs.map((tab) => {
          const active = filters.status === tab.value
          return (
            <button
              key={tab.value}
              type="button"
              aria-pressed={active}
              onClick={() => onChange({ status: tab.value })}
              className={cx(
                'inline-flex items-center gap-[7px] rounded-full border px-3 py-1.5 text-[13px] font-medium',
                active ? 'border-ink bg-ink text-white' : 'border-control bg-white text-ink-2 hover:bg-row-hover',
              )}
            >
              <span>{tab.label}</span>
              <span className="font-mono text-xs opacity-75">{counts[tab.value]}</span>
            </button>
          )
        })}
      </div>

      <div className="flex flex-wrap items-center gap-3.5">
        <div role="group" aria-label="Date range preset" className="flex gap-1 rounded-[9px] bg-canvas p-[3px]">
          {PRESETS.map((preset) => {
            const active = filters.preset === preset.value
            return (
              <button
                key={preset.value}
                type="button"
                aria-pressed={active}
                onClick={() => onChange({ preset: preset.value })}
                className={cx(
                  'rounded-[7px] px-[11px] py-[5px] text-[13px] font-medium',
                  active ? 'bg-white text-ink shadow-[0_1px_2px_rgba(0,0,0,0.12)]' : 'text-muted',
                )}
              >
                {preset.label}
              </button>
            )
          })}
        </div>

        <label className="flex items-center gap-2 text-[13px] text-muted">
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
        <label className="flex items-center gap-2 text-[13px] text-muted">
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

        {hasFilters && (
          <button type="button" onClick={onClear} className="p-1 text-[13px] font-semibold text-brand hover:text-brand-dark">
            Clear filters
          </button>
        )}
      </div>
    </div>
  )
}
