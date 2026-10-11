import { useRef, useState, type FormEvent } from 'react'
import { usePage } from '@inertiajs/react'
import { ChatIcon, CloseIcon } from '@/components/Icons'
import { Notice } from '@/components/ui'
import { csrfHeaders } from '@/lib/csrf'
import { formatRange } from '@/lib/format'
import type { StatusOption } from '@/types'
import type { Filters } from '@/types/assessments'
import type { ExportFilters } from '@/types/exports'

type Answer = {
  reply: string
  filters: { status: Filters['status']; preset: Filters['preset']; from: string; to: string; q: string } | null
  export: ExportFilters | null
}

const EXAMPLES = ['Completed in the last 30 days', 'Needs follow-up this month', 'Export September']
const PRESET_LABELS: Record<string, string> = { '7': 'Last 7 days', '30': 'Last 30 days', '90': 'Last 90 days', all: 'All time' }

function describe(filters: NonNullable<Answer['filters']>, statusOptions: StatusOption[]): string {
  const status = filters.status === 'all' ? 'All statuses' : (statusOptions.find((option) => option.value === filters.status)?.label ?? filters.status)
  const period = filters.preset === 'custom' ? formatRange(filters.from, filters.to) : (PRESET_LABELS[filters.preset] ?? 'All time')
  return [status, period, filters.q].filter(Boolean).join(' · ')
}

type Props = {
  filters: Filters
  onApply: (next: Partial<Filters>) => void
  onExport: (initial: ExportFilters) => void
}

// "Ask in plain English": a sentence becomes the filters the page already has, or an
// export the person still reviews and confirms. It cannot read assessments or create
// anything. Shown only when the server has an assistant configured.
export default function AskAssistant({ filters, onApply, onExport }: Props) {
  const { assistant, status_options } = usePage().props
  const [open, setOpen] = useState(false)
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [answer, setAnswer] = useState<Answer | null>(null)
  const [error, setError] = useState('')
  const before = useRef<Filters | null>(null)

  if (!assistant.enabled) return null

  const ask = async (question: string) => {
    if (!question.trim() || busy) return
    setBusy(true)
    setError('')
    setAnswer(null)
    try {
      const response = await fetch('/assistant', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json', ...csrfHeaders() },
        credentials: 'same-origin',
        body: JSON.stringify({ message: question }),
      })
      const body = (await response.json()) as Answer & { error?: string }
      if (!response.ok) {
        setError(body.error ?? 'The assistant could not answer. Please try again.')
        return
      }
      setAnswer(body)
      if (body.filters) {
        before.current = filters
        onApply(body.filters)
      }
    } catch {
      setError('The assistant could not be reached. Please try again.')
    } finally {
      setBusy(false)
    }
  }

  const submit = (event: FormEvent) => {
    event.preventDefault()
    void ask(text)
  }

  const close = () => {
    setOpen(false)
    setAnswer(null)
    setError('')
  }

  if (!open) {
    return (
      <button type="button" onClick={() => setOpen(true)} className="btn btn-quiet btn-sm self-start">
        <ChatIcon size={15} />
        Ask in plain English
      </button>
    )
  }

  return (
    <section aria-label="Ask in plain English" className="flex flex-col gap-4 rounded-[24px] border border-line bg-paper p-5 shadow-lift">
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="eyebrow !text-brand-ink">Ask in plain English</div>
          <p className="mt-1 text-[13.5px] text-muted">
            Describe what you want to see. I set the filters, or prepare an export for you to confirm.
          </p>
        </div>
        <button type="button" onClick={close} aria-label="Close the assistant" className="icon-btn -mt-1 -mr-2 flex-none">
          <CloseIcon size={15} />
        </button>
      </div>

      <form onSubmit={submit} className="flex flex-wrap gap-2.5">
        <input
          autoFocus
          value={text}
          maxLength={300}
          autoComplete="off"
          onChange={(event) => setText(event.target.value)}
          aria-label="Your question"
          placeholder="e.g. completed in Warehouse, last 30 days"
          className="input min-w-[240px] flex-1"
        />
        <button type="submit" disabled={busy || text.trim() === ''} className="btn btn-primary">
          {busy ? 'Thinking…' : 'Ask'}
        </button>
      </form>

      <div className="flex flex-wrap gap-2">
        {EXAMPLES.map((example) => (
          <button
            key={example}
            type="button"
            onClick={() => {
              setText(example)
              void ask(example)
            }}
            className="rounded-full border border-line px-3.5 py-1.5 text-[12.5px] font-semibold text-ink-2 transition-colors hover:border-control hover:bg-hover"
          >
            {example}
          </button>
        ))}
      </div>

      <div aria-live="polite" className="flex flex-col gap-3">
        {error && (
          <Notice tone="danger" role="alert">
            {error}
          </Notice>
        )}
        {answer && (
          <div className="flex flex-col gap-3 border-l-[3px] border-brand/50 pl-4">
            <p className="text-[14px] text-ink-2">{answer.reply}</p>
            {answer.filters && (
              <div className="flex flex-wrap items-center gap-3">
                <span className="rounded-full bg-brand-tint px-3 py-1 text-[12.5px] font-semibold text-brand-ink">Applied: {describe(answer.filters, status_options)}</span>
                <button
                  type="button"
                  onClick={() => before.current && onApply(before.current)}
                  className="btn btn-text btn-sm"
                >
                  Undo
                </button>
              </div>
            )}
            {answer.export && (
              <div className="flex flex-wrap items-center gap-3">
                <span className="rounded-full bg-ok-tint px-3 py-1 text-[12.5px] font-semibold text-ok">
                  Export: {answer.export.status === 'all' ? 'All statuses' : (status_options.find((option) => option.value === answer.export?.status)?.label ?? answer.export.status)} · {formatRange(answer.export.from, answer.export.to)}
                </span>
                <button
                  type="button"
                  onClick={() => {
                    if (!answer.export) return
                    close()
                    onExport(answer.export)
                  }}
                  className="btn btn-quiet btn-sm"
                >
                  Review export
                </button>
              </div>
            )}
          </div>
        )}
      </div>

      <p className="text-[12px] text-muted">
        {assistant.offline
          ? 'Offline mode: runs on this server with simple rules. Nothing leaves it.'
          : `Your question is sent to ${assistant.provider} to work out the filters. Employee names, e-mail addresses, answers and scores are never sent by this app, so please don’t type them. Search a person with the search box.`}
      </p>
    </section>
  )
}
