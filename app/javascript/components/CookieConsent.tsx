import { useState } from 'react'
import { router, usePage } from '@inertiajs/react'
import Dialog from '@/components/Dialog'
import { SheetHeader } from '@/components/ui'
import { clearPreferenceStorage } from '@/lib/preferenceStorage'

type Choice = { preferences: boolean }

function saveChoice({ preferences }: Choice, onDone?: () => void) {
  // Withdrawing consent must also remove what was already remembered in this browser.
  if (!preferences) clearPreferenceStorage()
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
      className="glass fixed inset-x-4 bottom-[88px] z-25 animate-pop-in rounded-[24px] p-5 md:right-auto md:bottom-5 md:left-5 md:w-[420px]"
    >
      <h2 className="display text-[24px]">Cookies on ErgoCheck</h2>
      <p className="mt-2 text-[13.5px] text-ink-2">
        We always use essential cookies to keep you signed in and your account secure. With your OK we also remember
        your dashboard filters. We never use advertising or tracking cookies.
      </p>
      <div className="mt-4 flex flex-wrap items-center gap-2">
        <button type="button" onClick={() => saveChoice({ preferences: true })} className="btn btn-primary btn-sm">
          Accept all
        </button>
        <button type="button" onClick={() => saveChoice({ preferences: false })} className="btn btn-quiet btn-sm">
          Essential only
        </button>
        <button type="button" onClick={onCustomize} className="btn btn-text btn-sm">
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
    <div className="flex flex-col gap-6">
      <SheetHeader id="cookie-dialog-title" title="Cookie settings" subtitle="Choose which optional cookies ErgoCheck may use." onClose={onClose} />

      <section className="flex flex-col gap-3 border-l-[3px] border-brand/50 pl-4">
        <div className="flex items-center justify-between gap-3">
          <div className="eyebrow !text-brand-ink">Essential</div>
          <span className="rounded-full bg-brand-tint px-2.5 py-0.5 text-[11px] font-bold tracking-wide text-brand-ink uppercase">Always on</span>
        </div>
        <ul className="flex flex-col gap-2.5">
          {ESSENTIAL.map((cookie) => (
            <li key={cookie.name} className="text-[13px] text-muted">
              <span className="font-mono text-xs text-ink-2">{cookie.name}</span> — {cookie.purpose} <span className="text-subtle">({cookie.lifetime})</span>
            </li>
          ))}
        </ul>
      </section>

      <label className="flex cursor-pointer items-start gap-4 rounded-2xl border border-line bg-paper/60 p-4 transition-colors hover:border-control">
        <input
          type="checkbox"
          checked={preferences}
          onChange={(event) => setPreferences(event.target.checked)}
          className="mt-0.5 size-5 rounded-md border-control text-brand focus:ring-brand"
        />
        <span>
          <span className="block text-[14px] font-semibold">Preferences</span>
          <span className="mt-1 block text-[13px] text-muted">
            <span className="font-mono text-xs text-ink-2">ergocheck_prefs</span> — remembers your assessment status
            filter and date range so the dashboard opens the way you left it. <span className="text-subtle">(90 days)</span>
          </span>
        </span>
      </label>

      <div className="flex justify-end gap-2.5">
        <button type="button" onClick={onClose} className="btn btn-quiet">
          Cancel
        </button>
        <button type="button" onClick={() => saveChoice({ preferences }, onClose)} className="btn btn-primary">
          Save choices
        </button>
      </div>
    </div>
  )
}
