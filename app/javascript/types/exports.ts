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
  error: string | null
  can_retry: boolean
  download_path: string | null
}

export type ExportFilters = { from: string; to: string; status: StatusValue | 'all' }
