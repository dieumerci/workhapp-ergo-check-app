import { Head } from '@inertiajs/react'

export default function Index() {
  return (
    <>
      <Head title="Assessments" />
      <section className="flex flex-col gap-[18px]">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight">Assessments</h1>
          <div className="mt-0.5 text-muted">Ergonomic and health assessments for your employees.</div>
        </div>
      </section>
    </>
  )
}
