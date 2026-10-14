import { useEffect, useState } from 'react'
import { Section } from '@/components/ui'
import { cx } from '@/lib/cx'
import type { NormalizeResult } from '@/types/release'

const sampleLabel = (value: string) => (value.trim() === '' ? '(empty)' : value)

// Sends what is typed to the server, which runs it through the same Status
// rules the save path and the backfill use, so this can never disagree with them.
export default function NormalizerCard({ samples }: { samples: string[] }) {
  const [value, setValue] = useState(samples[0] ?? '')
  // The answer is kept with the value it was computed for, so the page can say what it checked
  // (two different spellings often give the same tiles, which would otherwise look like nothing happened).
  const [result, setResult] = useState<(NormalizeResult & { checked: string }) | null>(null)
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
        setResult({ ...((await response.json()) as NormalizeResult), checked: value })
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
    <Section title="Try the normalizer">
      <p className="-mt-1 text-[13.5px] text-muted">
        Type a legacy status to see what history backfill would do, and whether a new save would be accepted.
      </p>
      <div className="flex flex-wrap items-center gap-2.5">
        <input
          value={value}
          onChange={(event) => setValue(event.target.value)}
          aria-label="Legacy status to test"
          placeholder="e.g. comp, done, n/a, ARCHIVED"
          className="input min-w-[220px] flex-1 font-mono"
        />
        {samples.map((sample) => (
          <button
            key={sample || 'empty'}
            type="button"
            onClick={() => setValue(sample)}
            className="rounded-full border border-line bg-paper/70 px-3.5 py-1.5 font-mono text-xs transition-colors hover:border-control hover:bg-paper"
          >
            {sampleLabel(sample)}
          </button>
        ))}
      </div>

      {failed && <p className="text-[13px] text-danger">Could not reach the server to check that value.</p>}

      {result && (
        <div aria-live="polite" className="flex flex-col gap-3">
          <p className="text-[13px] text-muted">
            {result.checked === value ? 'Result for' : 'Checking'}{' '}
            <code className="rounded-md bg-ink/5 px-1.5 py-0.5 font-mono text-xs text-ink">{sampleLabel(value)}</code>
            {result.checked === value ? '' : '…'}
          </p>
          <div className={cx('grid gap-3 transition-opacity duration-150 sm:grid-cols-2', result.checked !== value && 'opacity-50')}>
            <div className="rounded-[20px] bg-ink/5 px-5 py-4">
              <div className="eyebrow">Historical backfill</div>
              <div className="mt-2 text-[17px] font-semibold">{result.backfill.label}</div>
              <div className="mt-1 text-[13px] text-muted">{result.backfill.why}</div>
            </div>
            <div className={cx('rounded-[20px] px-5 py-4', result.save.accepted ? 'bg-ok-tint text-ok' : 'bg-danger-tint text-danger')}>
              <div className="eyebrow !text-current">New or updated record</div>
              <div className="mt-2 text-[17px] font-semibold">{result.save.title}</div>
              <div className="mt-1 text-[13px]">{result.save.why}</div>
            </div>
          </div>
        </div>
      )}
    </Section>
  )
}
