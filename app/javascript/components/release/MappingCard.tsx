import StatusBadge from '@/components/StatusBadge'
import type { MappingRow } from '@/types/release'

export default function MappingCard({ mapping }: { mapping: MappingRow[] }) {
  return (
    <section className="rounded-[14px] border border-line bg-white px-5 py-[18px]">
      <h2 className="mb-3 text-[15px] font-bold">Mapping</h2>
      {mapping.map((row) => (
        <div
          key={`${row.to}-${row.from.join()}`}
          className="grid grid-cols-1 items-center gap-3 border-t border-line-soft py-2.5 md:grid-cols-[minmax(0,1.3fr)_24px_150px_minmax(0,1.5fr)]"
        >
          <div className="flex flex-wrap gap-1.5">
            {row.from.map((value) => (
              <span key={value} className="rounded-[5px] bg-canvas px-[7px] py-0.5 font-mono text-xs text-ink-2">
                {value}
              </span>
            ))}
          </div>
          <div className="hidden text-subtle md:block" aria-hidden="true">
            →
          </div>
          <div>
            <StatusBadge status={row.to} label={row.label} />
          </div>
          <div className="text-[13px] text-muted">{row.rule}</div>
        </div>
      ))}
    </section>
  )
}
