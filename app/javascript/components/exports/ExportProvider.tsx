import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { usePage, usePoll } from '@inertiajs/react'
import ExportModal from '@/components/exports/ExportModal'
import { useToast } from '@/components/Toast'
import type { ExportFilters, ExportView } from '@/types/exports'

type ExportContextValue = {
  openExport: (initial?: Partial<ExportFilters>) => void
  openJob: (id: number) => void
}

const BLANK: ExportFilters = { from: '', to: '', status: 'all' }
const POLL_INTERVAL_MS = 2000

const ExportContext = createContext<ExportContextValue>({ openExport: () => {}, openJob: () => {} })

export function useExports(): ExportContextValue {
  return useContext(ExportContext)
}

export const isActive = (job: ExportView) => job.state === 'queued' || job.state === 'processing'

// Polls only the `exports` prop, and only while something is queued or
// building, so an idle page makes no background requests. Announces the moment
// a job finishes, wherever the admin happens to be in the app.
function useExportProgress(exports: ExportView[]) {
  const { say } = useToast()
  // The header tells the server these requests are background polls, which must not
  // count as activity (a tab left open would otherwise keep the session alive for ever).
  const { start, stop } = usePoll(
    POLL_INTERVAL_MS,
    { only: ['exports'], headers: { 'X-Background-Poll': '1' } },
    { autoStart: false },
  )
  const previous = useRef(new Map<number, ExportView['state']>())
  const active = exports.some(isActive)

  useEffect(() => {
    if (active) start()
    else stop()
  }, [active, start, stop])

  useEffect(() => {
    for (const job of exports) {
      const was = previous.current.get(job.id)
      if (was === 'queued' || was === 'processing') {
        if (job.state === 'ready') say('Export ready to download')
        if (job.state === 'failed') say('Export failed. See the Exports page.', 'warn')
      }
    }
    previous.current = new Map(exports.map((job) => [job.id, job.state]))
  }, [exports, say])
}

export function ExportProvider({ children }: { children: ReactNode }) {
  const { exports } = usePage().props
  const [dialog, setDialog] = useState<{ open: boolean; jobId: number | null; initial: ExportFilters }>({
    open: false,
    jobId: null,
    initial: BLANK,
  })

  useExportProgress(exports)

  const openExport = useCallback(
    (initial: Partial<ExportFilters> = {}) => setDialog({ open: true, jobId: null, initial: { ...BLANK, ...initial } }),
    [],
  )
  const openJob = useCallback((id: number) => setDialog((current) => ({ ...current, open: true, jobId: id })), [])
  const close = useCallback(() => setDialog((current) => ({ ...current, open: false, jobId: null })), [])

  const value = useMemo(() => ({ openExport, openJob }), [openExport, openJob])

  return (
    <ExportContext.Provider value={value}>
      {children}
      <ExportModal open={dialog.open} jobId={dialog.jobId} initial={dialog.initial} onJob={openJob} onClose={close} />
    </ExportContext.Provider>
  )
}
