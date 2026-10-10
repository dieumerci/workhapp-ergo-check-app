import { Head } from '@inertiajs/react'
import type { SafeguardsProps } from '@/types/safeguards'

const logBox = 'rounded-lg border px-[11px] py-[9px] font-mono text-xs break-words whitespace-pre-wrap text-ink-2'

export default function Index({ cards, log_example }: SafeguardsProps) {
  return (
    <>
      <Head title="Safeguards" />
      <section className="flex max-w-[980px] flex-col gap-5">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight">Safeguards</h1>
          <div className="mt-0.5 text-muted">How the app protects tenant data, keeps the dashboard fast, and keeps scores correct.</div>
        </div>

        <div className="grid grid-cols-[repeat(auto-fit,minmax(300px,1fr))] gap-4">
          {cards.map((card) => (
            <article key={card.title} className="flex flex-col gap-2.5 rounded-[14px] border border-line bg-white px-5 py-[18px]">
              <div className="self-start rounded bg-brand-tint px-[7px] py-0.5 text-[11px] font-semibold tracking-wider text-brand-dark uppercase">
                {card.task}
              </div>
              <h2 className="text-base font-bold">{card.title}</h2>
              <ul className="flex flex-col gap-2">
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

        <section className="flex flex-col gap-3 rounded-[14px] border border-line bg-white px-5 py-[18px]">
          <h2 className="text-[15px] font-bold">What a request log line looks like</h2>
          <div>
            <div className="mb-1 text-xs font-semibold tracking-wider text-danger uppercase">Before</div>
            <div className={`${logBox} border-[#f3c9c0] bg-danger-tint/20`}>{log_example.before}</div>
          </div>
          <div>
            <div className="mb-1 text-xs font-semibold tracking-wider text-ok uppercase">After</div>
            <div className={`${logBox} border-[#bfe3cc] bg-ok-tint/20`}>{log_example.after}</div>
            <div className="mt-1.5 text-[12.5px] text-muted">
              This line is produced by the application&apos;s real parameter filter, not typed in.
            </div>
          </div>
        </section>
      </section>
    </>
  )
}
