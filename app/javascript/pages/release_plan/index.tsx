import { Head } from '@inertiajs/react'
import MappingCard from '@/components/release/MappingCard'
import NormalizerCard from '@/components/release/NormalizerCard'
import StepsCard from '@/components/release/StepsCard'
import { PageHeader, Section } from '@/components/ui'
import type { ReleasePlanProps } from '@/types/release'

export default function Index({ mapping, steps, rollback, samples }: ReleasePlanProps) {
  return (
    <>
      <Head title="Status normalization" />
      <section className="flex max-w-[980px] flex-col gap-12">
        <PageHeader
          title="Status normalization"
          tag="Plan only"
          lead="Internal release plan. New writes are restricted to five values; history is backfilled safely in the background."
        />

        <MappingCard mapping={mapping} />
        <NormalizerCard samples={samples} />
        <StepsCard steps={steps} />

        <Section title="Rollback">
          <div className="grid gap-x-8 gap-y-6 md:grid-cols-3">
            {rollback.map((rung) => (
              <div key={rung.when} className="flex flex-col gap-1.5 border-l-[3px] border-line pl-4">
                <div className="font-semibold">{rung.when}</div>
                <div className="text-[13.5px] text-ink-2">{rung.what}</div>
              </div>
            ))}
          </div>
        </Section>
      </section>
    </>
  )
}
