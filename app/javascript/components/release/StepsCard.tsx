import { usePage } from '@inertiajs/react'
import { usePersistedState } from '@/hooks/usePersistedState'
import { CheckIcon } from '@/components/Icons'
import ProgressBar from '@/components/exports/ProgressBar'
import { Section } from '@/components/ui'
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
    <Section title="Release steps" aside={`${done.length} of ${steps.length} done`}>
      <ProgressBar value={percent} label="Release steps completed" />

      <ol className="divide-y divide-line-soft">
        {steps.map((step, index) => {
          const checked = done.includes(index)
          return (
            <li key={step.title} className="grid grid-cols-[28px_minmax(0,1fr)] items-start gap-x-4 gap-y-2 py-5 md:grid-cols-[28px_minmax(0,1fr)_auto]">
              <button
                type="button"
                role="checkbox"
                aria-checked={checked}
                aria-label={`Mark step ${index + 1} done`}
                onClick={() => toggle(index)}
                className={cx(
                  'mt-0.5 grid size-7 place-items-center rounded-full border-[1.5px] text-white transition-colors',
                  checked ? 'border-brand bg-brand' : 'border-control bg-paper hover:border-brand',
                )}
              >
                {checked && <CheckIcon size={14} />}
              </button>
              <div className="min-w-0">
                <div className={cx('text-[15px] font-semibold transition-opacity', checked && 'opacity-55')}>
                  {index + 1}. {step.title}
                </div>
                <div className="mt-1 text-[13.5px] text-muted">{step.detail}</div>
                <div className="mt-3 overflow-x-auto rounded-xl bg-ink/5 px-3 py-2 font-mono text-xs whitespace-nowrap text-ink-2">{step.command}</div>
              </div>
              <span
                className={cx(
                  'col-start-2 justify-self-start rounded-full px-3 py-1 text-xs font-semibold whitespace-nowrap md:col-start-3',
                  step.window ? 'bg-warn-tint text-warn' : 'bg-brand-tint text-brand-ink',
                )}
              >
                {step.window ? 'Low-traffic window' : 'Safe while live'}
              </span>
            </li>
          )
        })}
      </ol>
    </Section>
  )
}
