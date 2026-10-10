import { useEffect, useState } from 'react'
import { cx } from '@/lib/cx'
import type { NormalizeResult } from '@/types/release'

const sampleLabel = (value: string) => (value === '' ? '(empty)' : value)

// Sends what is typed to the server, which runs it through the same Status
// rules the save path and the backfill use, so this can never disagree with them.
export default function NormalizerCard({ samples }: { samples: string[] }) {
  const [value, setValue] = useState(samples[0] ?? '')
  const [result, setResult] = useState<NormalizeResult | null>(null)
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    const controller = new AbortController()
    const timer = setTimeout(async () => {
      try {
        const response = await fetch(`/release_plan/normalize?${new URLSearchParams({ value })}`, {
          headers: { Accept: 'application/json' },
          credentials: 'same-origin',
          signal: controller.signal,
        })
        setResult((await response.json()) as NormalizeResult)
        setFailed(false)
      } catch (error) {
        if ((error as Error).name !== 'AbortError') setFailed(true)
      }
    }, 150)
    return () => {
      clearTimeout(timer)
      controller.abort()
    }
  }, [value])

  return (
    <section className="flex flex-col gap-3 rounded-[14px] border border-line bg-white px-5 py-[18px]">
      <h2 className="text-[15px] font-bold">Try the normalizer</h2>
      <p className="text-[13px] text-muted">
        Type a legacy status to see what history backfill would do, and whether a new save would be accepted.
      </p>
      <div className="flex flex-wrap items-center gap-2">
        <input
          value={value}
          onChange={(event) => setValue(event.target.value)}
          aria-label="Legacy status to test"
          placeholder="e.g. comp, done, n/a, ARCHIVED"
          className="min-w-[200px] flex-1 rounded-[9px] border border-control bg-white px-2.5 py-[9px] font-mono text-sm"
        />
        {samples.map((sample) => (
          <button
            key={sample || 'empty'}
            type="button"
            onClick={() => setValue(sample)}
            className="rounded-full border border-control bg-white px-[11px] py-[5px] font-mono text-xs hover:bg-canvas"
          >
            {sampleLabel(sample)}
          </button>
        ))}
      </div>

      {failed && <p className="text-[13px] text-danger">Could not reach the server to check that value.</p>}

      {result && (
        <div aria-live="polite" className="grid grid-cols-[repeat(auto-fit,minmax(220px,1fr))] gap-2.5">
          <div className="rounded-[10px] bg-canvas px-3.5 py-3">
            <div className="text-xs font-semibold tracking-wider text-muted uppercase">Historical backfill</div>
            <div className="mt-1.5 font-semibold">{result.backfill.label}</div>
            <div className="mt-0.5 text-[13px] text-muted">{result.backfill.why}</div>
          </div>
          <div className={cx('rounded-[10px] px-3.5 py-3', result.save.accepted ? 'bg-ok-tint text-ok' : 'bg-danger-tint text-danger')}>
            <div className="text-xs font-semibold tracking-wider uppercase">New or updated record</div>
            <div className="mt-1.5 font-semibold">{result.save.title}</div>
            <div className="mt-0.5 text-[13px]">{result.save.why}</div>
          </div>
        </div>
      )}
    </section>
  )
}
