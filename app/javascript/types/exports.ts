import type { StatusValue } from '@/types'

export type ExportState = 'queued' | 'processing' | 'ready' | 'failed' | 'expired'

export type ExportView = {
  id: number
  state: ExportState
  state_label: string
  progress: number
  row_count: number | null
  from: string
  to: string
  status: StatusValue | 'all'
  status_label: string
  requested_at: string
  requested_by: string
  download_count: number
  last_downloaded_at: string | null
  expires_at: string | null
  // Seconds the link still works, from the server's clock; null until the export is ready.
  expires_in: number | null
  error: string | null
  can_retry: boolean
  // The export's own address, on every row whatever its state. Only admins of the owning company can open it.
  link_path: string
  download_path: string | null
}

export type ExportFilters = { from: string; to: string; status: StatusValue | 'all' }
