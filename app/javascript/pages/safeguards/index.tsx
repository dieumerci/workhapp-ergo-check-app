import { Head } from '@inertiajs/react'
import { PageHeader, Section } from '@/components/ui'
import { cx } from '@/lib/cx'
import type { SafeguardsProps } from '@/types/safeguards'

const logBox = 'rounded-2xl px-4 py-3.5 font-mono text-xs leading-relaxed break-words whitespace-pre-wrap'

export default function Index({ cards, log_example }: SafeguardsProps) {
  return (
    <>
      <Head title="Safeguards" />
      <section className="flex max-w-[1040px] flex-col gap-12">
        <PageHeader title="Safeguards" lead="How the app protects tenant data, keeps the dashboard fast, and keeps scores correct." />

        {/* A bento: the export card is the headline, the rest are single tiles. */}
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {cards.map((card, index) => (
            <article
              key={card.title}
              className={cx(
                'flex flex-col gap-3 rounded-[28px] border border-line p-6 md:p-7',
                index === 0 ? 'bg-brand-tint/70 lg:col-span-2' : 'bg-paper/70',
              )}
            >
              <div className="eyebrow !text-brand-ink">{card.task}</div>
              <h2 className="display text-[28px]">{card.title}</h2>
              <ul className="flex flex-col gap-2.5">
                {card.points.map((point) => (
                  <li key={point} className="grid grid-cols-[14px_1fr] gap-2 text-[13.5px] text-ink-2">
                    <span aria-hidden="true" className="font-bold text-brand">
                      ·
                    </span>
                    <span>{point}</span>
                  </li>
                ))}
              </ul>
            </article>
          ))}
        </div>

        <Section title="What a request log line looks like">
          <div className="grid gap-5 md:grid-cols-2">
            <div className="flex flex-col gap-2">
              <div className="eyebrow !text-danger">Before</div>
              <div className={cx(logBox, 'bg-danger-tint/60 text-ink-2')}>{log_example.before}</div>
            </div>
            <div className="flex flex-col gap-2">
              <div className="eyebrow !text-ok">After</div>
              <div className={cx(logBox, 'bg-ok-tint/70 text-ink-2')}>{log_example.after}</div>
            </div>
          </div>
          <div className="text-[12.5px] text-muted">This line is produced by the application&apos;s real parameter filter, not typed in.</div>
        </Section>
      </section>
    </>
  )
}
