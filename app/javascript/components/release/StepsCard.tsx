import { usePage } from '@inertiajs/react'
import { usePersistedState } from '@/hooks/usePersistedState'
import { RELEASE_STEPS_KEY } from '@/lib/preferenceStorage'
import { cx } from '@/lib/cx'
import type { PlanStep } from '@/types/release'

export default function StepsCard({ steps }: { steps: PlanStep[] }) {
  const { cookie_consent } = usePage().props
  // Ticking steps is a convenience; remember it across reloads only with the Preferences cookie consent.
  const [done, setDone] = usePersistedState<number[]>(RELEASE_STEPS_KEY, [], cookie_consent.preferences)
  const percent = Math.round((done.length / steps.length) * 100)

  const toggle = (index: number) =>
    setDone((current) => (current.includes(index) ? current.filter((item) => item !== index) : [...current, index]))

  return (
    <section className="rounded-[14px] border border-line bg-white px-5 py-[18px]">
      <div className="mb-1.5 flex items-center justify-between">
        <h2 className="text-[15px] font-bold">Release steps</h2>
        <div className="text-[13px] whitespace-nowrap text-muted tabular-nums">
          {done.length} of {steps.length} done
        </div>
      </div>
      <div
        role="progressbar"
        aria-label="Release steps completed"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={percent}
        className="mb-1.5 h-[5px] rounded-[3px] bg-skeleton"
      >
        <div className="h-[5px] rounded-[3px] bg-brand transition-[width] duration-300" style={{ width: `${percent}%` }} />
      </div>

      {steps.map((step, index) => {
        const checked = done.includes(index)
        return (
          <div key={step.title} className="grid grid-cols-[28px_minmax(0,1fr)_auto] items-start gap-3 border-t border-line-soft py-3.5">
            <button
              type="button"
              role="checkbox"
              aria-checked={checked}
              aria-label={`Mark step ${index + 1} done`}
              onClick={() => toggle(index)}
              className={cx(
                'mt-px grid size-[22px] place-items-center rounded-md border-[1.5px] p-0 text-[13px] leading-none text-white',
                checked ? 'border-brand bg-brand' : 'border-[#b9b7ad] bg-white',
              )}
            >
              {checked ? '✓' : ''}
            </button>
            <div className="min-w-0">
              <div className={cx('font-semibold', checked && 'opacity-55')}>
                {index + 1}. {step.title}
              </div>
              <div className="mt-0.5 text-[13px] text-muted">{step.detail}</div>
              <div className="mt-2 overflow-x-auto rounded-md bg-canvas px-[9px] py-1.5 font-mono text-xs whitespace-nowrap text-ink-2">
                {step.command}
              </div>
            </div>
            <span
              className={cx(
                'rounded-md px-2 py-[3px] text-xs font-semibold whitespace-nowrap',
                step.window ? 'bg-warn-tint text-warn' : 'bg-brand-tint text-brand-dark',
              )}
            >
              {step.window ? 'Low-traffic window' : 'Safe while live'}
            </span>
          </div>
        )
      })}
    </section>
  )
}
