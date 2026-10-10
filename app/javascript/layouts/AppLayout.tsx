import { useState, type ReactNode } from 'react'
import { Link, usePage } from '@inertiajs/react'
import { CookieBanner, CookieDialog } from '@/components/CookieConsent'
import ErrorBoundary from '@/components/ErrorBoundary'
import { ExportProvider, isActive } from '@/components/exports/ExportProvider'
import { LockIcon } from '@/components/Icons'
import { ToastProvider } from '@/components/Toast'
import { cx } from '@/lib/cx'

type NavItem = { href: string; label: string; tag?: string; ops?: boolean; match: string[] }

const NAV: NavItem[] = [
  { href: '/assessments', label: 'Assessments', match: ['/', '/assessments'] },
  { href: '/exports', label: 'Exports', match: ['/exports'] },
  { href: '/release_plan', label: 'Release plan', tag: 'Ops', ops: true, match: ['/release_plan'] },
  { href: '/safeguards', label: 'Safeguards', tag: 'Notes', ops: true, match: ['/safeguards'] },
]

function isCurrent(item: NavItem, path: string): boolean {
  return item.match.some((prefix) => (prefix === '/' ? path === '/' : path === prefix || path.startsWith(`${prefix}/`)))
}

export function BrandMark() {
  return (
    <div className="flex items-center gap-2.5 px-2">
      <div className="grid size-[30px] place-items-center rounded-lg bg-brand text-[15px] font-bold text-white">E</div>
      <div className="text-base font-bold tracking-tight">
        Ergo<span className="text-brand">Check</span>
      </div>
    </div>
  )
}

export default function AppLayout({ children }: { children: ReactNode }) {
  const page = usePage()
  const { auth, exports, ops_pages } = page.props
  const activeExports = exports.filter(isActive).length
  const path = page.url.split('?')[0]
  const [cookieDialogOpen, setCookieDialogOpen] = useState(false)

  return (
    <ToastProvider>
      <ExportProvider>
        <div className="flex min-h-screen flex-col md:flex-row">
          <aside className="flex flex-none flex-col gap-4 border-b border-line bg-white px-3.5 py-4 md:sticky md:top-0 md:h-screen md:w-[228px] md:gap-6 md:border-r md:border-b-0 md:py-5">
            <BrandMark />
            <nav aria-label="Main" className="flex gap-0.5 overflow-x-auto [scrollbar-width:none] md:flex-col [&::-webkit-scrollbar]:hidden">
              {NAV.filter((item) => ops_pages || !item.ops).map((item) => {
                const active = isCurrent(item, path)
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    aria-current={active ? 'page' : undefined}
                    className={cx(
                      'flex items-center justify-between gap-2 rounded-lg px-2.5 py-[9px] text-sm font-medium whitespace-nowrap',
                      active ? 'bg-brand-tint text-brand-dark' : 'text-ink-2 hover:bg-hover',
                    )}
                  >
                    <span>{item.label}</span>
                    {item.href === '/exports' && activeExports > 0 && (
                      <span
                        className="animate-pulse-badge rounded-full bg-brand px-[7px] py-px text-[11px] font-semibold text-white"
                        aria-label={`${activeExports} exports in progress`}
                      >
                        {activeExports}
                      </span>
                    )}
                    {item.tag && (
                      <span className="rounded bg-warn-tint px-[5px] py-px text-[10px] font-semibold tracking-wide text-warn uppercase">
                        {item.tag}
                      </span>
                    )}
                  </Link>
                )
              })}
            </nav>
            <div className="mt-auto hidden flex-col gap-3 border-t border-line pt-3.5 md:flex">
              <div className="flex items-center gap-2.5 pl-2">
                <div className="grid size-8 place-items-center rounded-full bg-brand-tint text-xs font-semibold text-brand">
                  {auth.admin?.initials}
                </div>
                <div className="min-w-0">
                  <div className="truncate text-[13px] font-semibold">{auth.admin?.name}</div>
                  <div className="text-xs text-muted">Company admin</div>
                </div>
              </div>
              <div className="flex gap-3 pl-2 text-xs">
                <Link href="/session" method="delete" as="button" className="font-semibold text-muted hover:text-ink">
                  Sign out
                </Link>
                <button
                  type="button"
                  onClick={() => setCookieDialogOpen(true)}
                  className="font-semibold text-muted hover:text-ink"
                >
                  Cookie settings
                </button>
              </div>
            </div>
          </aside>

          <main className="flex min-w-0 flex-1 flex-col gap-[22px] px-4 py-6 md:px-9 md:pt-7 md:pb-14">
            <header className="flex flex-wrap items-center justify-between gap-4">
              <div className="flex flex-wrap items-center gap-2.5 text-[13px] text-muted">
                <span className="font-semibold text-ink">{auth.company?.name}</span>
                <span className="inline-flex items-center gap-1.5 rounded-full bg-brand-tint px-2.5 py-[3px] text-xs font-medium text-brand-dark">
                  <LockIcon size={11} strokeWidth={2} />
                  Showing your company only
                </span>
              </div>
              <div className="flex gap-3 text-xs md:hidden">
                <Link href="/session" method="delete" as="button" className="font-semibold text-muted hover:text-ink">
                  Sign out
                </Link>
                <button
                  type="button"
                  onClick={() => setCookieDialogOpen(true)}
                  className="font-semibold text-muted hover:text-ink"
                >
                  Cookie settings
                </button>
              </div>
            </header>
            <ErrorBoundary>{children}</ErrorBoundary>
          </main>
        </div>
        <CookieBanner onCustomize={() => setCookieDialogOpen(true)} />
        <CookieDialog open={cookieDialogOpen} onClose={() => setCookieDialogOpen(false)} />
      </ExportProvider>
    </ToastProvider>
  )
}
