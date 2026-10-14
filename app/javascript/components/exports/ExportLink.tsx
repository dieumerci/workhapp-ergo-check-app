import { useState } from 'react'
import { router } from '@inertiajs/react'
import Countdown from '@/components/exports/Countdown'
import { ClockIcon, LinkIcon } from '@/components/Icons'
import { useToast } from '@/components/Toast'
import { formatRequested } from '@/lib/format'
import type { ExportView } from '@/types/exports'

const refreshExports = () => router.reload({ only: ['exports'] })

// The Clipboard API where the browser allows it; otherwise select the text in a throwaway field and copy that,
// which also works where the API is blocked (an embedded preview, an older browser).
async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text)
    return true
  } catch {
    const field = document.createElement('textarea')
    field.value = text
    field.setAttribute('readonly', '')
    field.style.cssText = 'position:fixed;top:0;left:0;opacity:0'
    document.body.appendChild(field)
    field.select()
    try {
      return document.execCommand('copy')
    } catch {
      return false
    } finally {
      field.remove()
    }
  }
}

function Expiry({ job }: { job: ExportView }) {
  if (job.state === 'ready' && job.expires_in !== null) {
    return job.expires_in > 0 ? (
      <>
        Expires in <Countdown seconds={job.expires_in} onExpire={refreshExports} />
      </>
    ) : (
      <>Expired just now</>
    )
  }
  if (job.state === 'expired') {
    const when = job.expires_at ? formatRequested(job.expires_at) : ''
    return <>Expired {when === 'Just now' ? 'just now' : when}</>
  }
  if (job.state === 'failed') return <>No file: this export failed</>
  return <>A 24 hour countdown starts when the file is ready</>
}

// The export's own address, shown on every row whatever its state, with when it stops working. The address only ever
// opens for admins of the company that owns the export: anyone else, even holding this exact link, gets a 404.
export default function ExportLink({ job }: { job: ExportView }) {
  const { say } = useToast()
  const [copied, setCopied] = useState(false)

  const copy = async () => {
    if (await copyText(new URL(job.link_path, window.location.origin).href)) {
      setCopied(true)
      say('Link copied')
      setTimeout(() => setCopied(false), 2000)
    } else {
      say('Could not copy. Select the link and copy it by hand.', 'warn')
    }
  }

  return (
    <div className="mt-3 flex min-w-0 flex-col gap-1.5 text-[12.5px] text-muted">
      <div className="flex min-w-0 items-center gap-1.5">
        <LinkIcon size={13} className="flex-none text-brand-ink" />
        <a
          href={job.link_path}
          title="This export's link. It only opens for admins of your company."
          className="min-w-0 truncate font-mono text-[12px] text-ink-2 underline-offset-2 hover:text-brand-ink hover:underline"
        >
          {window.location.host}
          {job.link_path}
        </a>
        <button
          type="button"
          onClick={copy}
          aria-label={`Copy the link for the export requested ${formatRequested(job.requested_at)}`}
          className="flex-none rounded-full px-2.5 py-0.5 text-[12px] font-semibold text-brand-ink transition-colors hover:bg-brand-tint"
        >
          {copied ? 'Copied' : 'Copy'}
        </button>
      </div>
      <div className="flex items-center gap-1.5">
        <ClockIcon size={13} className="flex-none" />
        <span>
          <Expiry job={job} />
        </span>
      </div>
    </div>
  )
}
