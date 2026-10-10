import { Head } from '@inertiajs/react'
import MappingCard from '@/components/release/MappingCard'
import NormalizerCard from '@/components/release/NormalizerCard'
import StepsCard from '@/components/release/StepsCard'
import type { ReleasePlanProps } from '@/types/release'

export default function Index({ mapping, steps, rollback, samples }: ReleasePlanProps) {
  return (
    <>
      <Head title="Status normalization" />
      <section className="flex max-w-[980px] flex-col gap-5">
        <div>
          <div className="flex items-center gap-2.5">
            <h1 className="text-[28px] font-bold tracking-tight">Status normalization</h1>
            <span className="rounded bg-warn-tint px-[7px] py-0.5 text-[11px] font-semibold tracking-wide text-warn uppercase">
              Plan only
            </span>
          </div>
          <div className="mt-0.5 text-muted">
            Internal release plan. New writes are restricted to five values; history is backfilled safely in the background.
          </div>
        </div>

        <MappingCard mapping={mapping} />
        <NormalizerCard samples={samples} />
        <StepsCard steps={steps} />

        <section className="rounded-[14px] border border-line bg-white px-5 py-[18px]">
          <h2 className="mb-3 text-[15px] font-bold">Rollback</h2>
          {rollback.map((rung) => (
            <div key={rung.when} className="grid grid-cols-1 gap-1 border-t border-line-soft py-2.5 md:grid-cols-[150px_minmax(0,1fr)] md:gap-3">
              <div className="font-semibold">{rung.when}</div>
              <div className="text-ink-2">{rung.what}</div>
            </div>
          ))}
        </section>
      </section>
    </>
  )
}
