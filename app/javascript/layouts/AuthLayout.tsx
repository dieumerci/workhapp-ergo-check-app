import { useState, type ReactNode } from 'react'
import { CookieBanner, CookieDialog } from '@/components/CookieConsent'
import { CookieIcon, LockIcon } from '@/components/Icons'
import ErrorBoundary from '@/components/ErrorBoundary'
import { ToastProvider } from '@/components/Toast'
import { BrandMark } from '@/layouts/AppLayout'

const ASSURANCES = [
  { title: 'Your company only', text: 'The company comes from your sign-in, never from a link or a form field.' },
  { title: 'Exports without names', text: 'Six columns. No e-mail addresses, no free-text answers, ever.' },
  { title: 'Nothing you type is logged', text: 'Passwords, codes and search terms are filtered out of the application log.' },
]

export default function AuthLayout({ children }: { children: ReactNode }) {
  const [cookieDialogOpen, setCookieDialogOpen] = useState(false)

  return (
    <ToastProvider>
      <div className="grid min-h-screen lg:grid-cols-[1.05fr_1fr]">
        {/* The editorial half: deep pine, a serif statement, three promises. */}
        <aside className="relative hidden flex-col justify-between overflow-hidden bg-pine p-12 text-white lg:flex">
          <div aria-hidden="true" className="pointer-events-none absolute -top-40 -right-32 size-[520px] rounded-full bg-pine-glow/35 blur-3xl" />
          <div aria-hidden="true" className="pointer-events-none absolute -bottom-48 -left-24 size-[560px] rounded-full bg-sand/18 blur-3xl" />
          <div aria-hidden="true" className="pointer-events-none absolute top-1/2 -right-20 size-[340px] -translate-y-1/2 rounded-full border border-white/10" />
          <div aria-hidden="true" className="pointer-events-none absolute top-1/2 -right-8 size-[220px] -translate-y-1/2 rounded-full border border-white/10" />

          <div className="relative flex items-center gap-2.5 text-[17px] font-bold tracking-tight">
            <div className="grid size-9 place-items-center rounded-[11px] bg-white font-display text-[22px] leading-none text-pine">E</div>
            ErgoCheck
          </div>

          <div className="relative max-w-[520px]">
            <h2 className="display text-[64px] leading-[1.02]">
              Ergonomic data, <em className="text-pine-mint">handled with care.</em>
            </h2>
            <ul className="mt-12 flex flex-col gap-6">
              {ASSURANCES.map((item) => (
                <li key={item.title} className="flex gap-4">
                  <span className="mt-0.5 grid size-8 flex-none place-items-center rounded-full bg-white/10 text-pine-mint">
                    <LockIcon size={14} />
                  </span>
                  <div>
                    <div className="text-[15px] font-semibold">{item.title}</div>
                    <div className="mt-0.5 text-[13.5px] text-white/70">{item.text}</div>
                  </div>
                </li>
              ))}
            </ul>
          </div>

          <div className="relative text-[12.5px] text-white/60">Assessments console for company admins.</div>
        </aside>

        <div className="flex min-h-screen flex-col items-center justify-center gap-8 px-4 py-10 sm:px-8">
          <div className="lg:hidden">
            <BrandMark />
          </div>
          <main className="w-full max-w-[440px]">
            <ErrorBoundary>{children}</ErrorBoundary>
          </main>
          <button type="button" onClick={() => setCookieDialogOpen(true)} className="btn btn-text btn-sm !text-muted">
            <CookieIcon size={14} />
            Cookie settings
          </button>
        </div>
      </div>
      <CookieBanner onCustomize={() => setCookieDialogOpen(true)} />
      <CookieDialog open={cookieDialogOpen} onClose={() => setCookieDialogOpen(false)} />
    </ToastProvider>
  )
}
