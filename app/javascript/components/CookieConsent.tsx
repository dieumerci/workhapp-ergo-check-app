import { useState } from 'react'
import { router, usePage } from '@inertiajs/react'
import Dialog from '@/components/Dialog'
import { CloseIcon } from '@/components/Icons'

type Choice = { preferences: boolean }

function saveChoice({ preferences }: Choice, onDone?: () => void) {
  router.post(
    '/cookie_consent',
    { preferences },
    { preserveScroll: true, preserveState: true, onSuccess: onDone },
  )
}

const ESSENTIAL = [
  { name: '_ergocheck_session', purpose: 'Keeps you signed in.', lifetime: 'Until you close the browser' },
  { name: 'XSRF-TOKEN', purpose: 'Protects forms and actions from forgery.', lifetime: 'Session' },
  { name: 'ergocheck_consent', purpose: 'Remembers the choice you make here.', lifetime: '12 months' },
]

export function CookieBanner({ onCustomize }: { onCustomize: () => void }) {
  const { cookie_consent } = usePage().props
  if (cookie_consent.decided) return null

  return (
    <section
      aria-label="Cookie notice"
      className="fixed bottom-4 left-4 z-25 w-[min(420px,calc(100vw-32px))] animate-pop-in rounded-2xl border border-line bg-white p-5 shadow-[0_12px_40px_rgba(0,0,0,0.16)]"
    >
      <h2 className="text-[15px] font-bold">Cookies on ErgoCheck</h2>
      <p className="mt-1.5 text-[13px] text-ink-2">
        We always use essential cookies to keep you signed in and your account secure. With your OK we also remember
        your dashboard filters. We never use advertising or tracking cookies.
      </p>
      <div className="mt-4 flex flex-wrap items-center gap-2">
        <button
          type="button"
          onClick={() => saveChoice({ preferences: true })}
          className="rounded-[9px] bg-brand px-3.5 py-2 text-[13px] font-semibold text-white hover:bg-brand-dark"
        >
          Accept all
        </button>
        <button
          type="button"
          onClick={() => saveChoice({ preferences: false })}
          className="rounded-[9px] border border-control bg-white px-3.5 py-2 text-[13px] font-semibold hover:bg-hover"
        >
          Essential only
        </button>
        <button
          type="button"
          onClick={onCustomize}
          className="px-1.5 py-2 text-[13px] font-semibold text-brand hover:text-brand-dark"
        >
          Customize
        </button>
      </div>
    </section>
  )
}

export function CookieDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { cookie_consent } = usePage().props
  // Re-mounted each time it opens so the switch always reflects the saved choice.
  return (
    <Dialog open={open} onClose={onClose} labelledBy="cookie-dialog-title">
      <CookieForm key={String(open)} initial={cookie_consent.preferences} onClose={onClose} />
    </Dialog>
  )
}

function CookieForm({ initial, onClose }: { initial: boolean; onClose: () => void }) {
  const [preferences, setPreferences] = useState(initial)

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-start justify-between">
        <div>
          <h2 id="cookie-dialog-title" className="text-xl font-bold tracking-tight">
            Cookie settings
          </h2>
          <p className="mt-0.5 text-muted">Choose which optional cookies ErgoCheck may use.</p>
        </div>
        <button
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="grid size-8 place-items-center rounded-lg bg-canvas hover:bg-hover"
        >
          <CloseIcon size={14} />
        </button>
      </div>

      <div className="rounded-xl border border-line p-3.5">
        <div className="flex items-center justify-between gap-3">
          <div className="text-[13px] font-semibold">Essential</div>
          <span className="rounded bg-brand-tint px-2 py-0.5 text-[11px] font-semibold tracking-wide text-brand-dark uppercase">
            Always on
          </span>
        </div>
        <ul className="mt-2.5 flex flex-col gap-2">
          {ESSENTIAL.map((cookie) => (
            <li key={cookie.name} className="text-[13px] text-muted">
              <span className="font-mono text-xs text-ink-2">{cookie.name}</span> — {cookie.purpose}{' '}
              <span className="text-subtle">({cookie.lifetime})</span>
            </li>
          ))}
        </ul>
      </div>

      <label className="flex cursor-pointer items-start gap-3 rounded-xl border border-line p-3.5">
        <input
          type="checkbox"
          checked={preferences}
          onChange={(event) => setPreferences(event.target.checked)}
          className="mt-0.5 size-4 rounded border-control text-brand focus:ring-brand"
        />
        <span>
          <span className="block text-[13px] font-semibold">Preferences</span>
          <span className="mt-0.5 block text-[13px] text-muted">
            <span className="font-mono text-xs text-ink-2">ergocheck_prefs</span> — remembers your assessment status
            filter and date range so the dashboard opens the way you left it.{' '}
            <span className="text-subtle">(90 days)</span>
          </span>
        </span>
      </label>

      <div className="flex justify-end gap-2">
        <button
          type="button"
          onClick={onClose}
          className="rounded-[9px] border border-control bg-white px-3.5 py-2 font-semibold hover:bg-hover"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={() => saveChoice({ preferences }, onClose)}
          className="rounded-[9px] bg-brand px-4 py-2 font-semibold text-white hover:bg-brand-dark"
        >
          Save choices
        </button>
      </div>
    </div>
  )
}
