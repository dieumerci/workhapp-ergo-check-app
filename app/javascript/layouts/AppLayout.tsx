import { useState, type ComponentType, type ReactNode } from 'react'
import { Link, usePage } from '@inertiajs/react'
import { CookieBanner, CookieDialog } from '@/components/CookieConsent'
import ErrorBoundary from '@/components/ErrorBoundary'
import { ExportProvider, isActive } from '@/components/exports/ExportProvider'
import { FileDownIcon, ListIcon, LockIcon, RouteIcon, ShieldIcon } from '@/components/Icons'
import { ToastProvider } from '@/components/Toast'
import UserMenu from '@/components/UserMenu'
import { cx } from '@/lib/cx'

type NavItem = {
  href: string
  label: string
  tag?: string
  ops?: boolean
  match: string[]
  Icon: ComponentType<{ size?: number; className?: string }>
}

const NAV: NavItem[] = [
  { href: '/assessments', label: 'Assessments', match: ['/', '/assessments'], Icon: ListIcon },
  { href: '/exports', label: 'Exports', match: ['/exports'], Icon: FileDownIcon },
  { href: '/release_plan', label: 'Release plan', tag: 'Ops', ops: true, match: ['/release_plan'], Icon: RouteIcon },
  { href: '/safeguards', label: 'Safeguards', tag: 'Notes', ops: true, match: ['/safeguards'], Icon: ShieldIcon },
]

function isCurrent(item: NavItem, path: string): boolean {
  return item.match.some((prefix) => (prefix === '/' ? path === '/' : path === prefix || path.startsWith(`${prefix}/`)))
}

export function BrandMark({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex items-center gap-2.5">
      <div className="grid size-9 place-items-center rounded-[11px] bg-brand font-display text-[22px] leading-none text-white shadow-[inset_0_1px_0_rgb(255_255_255/0.18)]">
        E
      </div>
      {!compact && (
        <div className="text-[17px] font-bold tracking-tight">
          Ergo<span className="text-brand">Check</span>
        </div>
      )}
    </div>
  )
}

export default function AppLayout({ children }: { children: ReactNode }) {
  const page = usePage()
  const { auth, exports, ops_pages } = page.props
  const activeExports = exports.filter(isActive).length
  const path = page.url.split('?')[0]
  // "/" and "/assessments" are the same page; keying the content on the raw path would
  // remount it (and drop its local state) the first time a filter moves it from one to the other.
  const routeKey = path === '/' ? '/assessments' : path
  const [cookieDialogOpen, setCookieDialogOpen] = useState(false)
  const items = NAV.filter((item) => ops_pages || !item.ops)

  return (
    <ToastProvider>
      <ExportProvider>
        {/* Floating navigation: a glass pill over the content, so the page keeps its whole width. */}
        <header className="fixed inset-x-0 top-3 z-40 mx-auto flex h-14 w-[min(1180px,calc(100%-24px))] items-center gap-3 rounded-full glass px-2.5 pl-3 md:top-4 md:h-[60px] md:px-3.5">
          <Link href="/assessments" aria-label="ErgoCheck home" className="rounded-xl">
            <BrandMark />
          </Link>

          <nav aria-label="Main" className="mx-auto hidden items-center gap-1 md:flex">
            {items.map((item) => {
              const active = isCurrent(item, path)
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  aria-current={active ? 'page' : undefined}
                  className={cx(
                    'relative inline-flex h-10 items-center gap-2 rounded-full px-4 text-sm font-semibold whitespace-nowrap transition-colors',
                    active ? 'bg-ink text-white shadow-[0_2px_8px_rgb(24_32_28/0.25)]' : 'text-ink-2 hover:bg-ink/6',
                  )}
                >
                  {item.label}
                  {item.href === '/exports' && activeExports > 0 && (
                    <span
                      className="animate-pulse-badge grid min-w-5 place-items-center rounded-full bg-brand px-1.5 text-[11px] font-bold text-white"
                      aria-label={`${activeExports} exports in progress`}
                    >
                      {activeExports}
                    </span>
                  )}
                  {item.tag && (
                    <span
                      className={cx(
                        'rounded-md px-1.5 py-px text-[10px] font-bold tracking-wide uppercase',
                        active ? 'bg-white/20 text-white' : 'bg-warn-tint text-warn',
                      )}
                    >
                      {item.tag}
                    </span>
                  )}
                </Link>
              )
            })}
          </nav>

          <div className="ml-auto flex items-center gap-3 md:ml-0">
            <div className="hidden items-center gap-2 text-[13px] lg:flex">
              <span className="max-w-[180px] truncate font-semibold text-ink-2">{auth.company?.name}</span>
            </div>
            <UserMenu onCookieSettings={() => setCookieDialogOpen(true)} />
          </div>
        </header>

        <main className="mx-auto w-full max-w-[1180px] px-4 pt-[92px] pb-[120px] md:px-8 md:pt-[112px] md:pb-20">
          <div className="mb-6 flex flex-wrap items-center gap-x-3 gap-y-1.5 text-[13px]">
            <span className="font-semibold text-ink">{auth.company?.name}</span>
            <span className="inline-flex items-center gap-1.5 rounded-full bg-brand-tint px-2.5 py-[3px] text-xs font-semibold text-brand-ink">
              <LockIcon size={11} strokeWidth={2} />
              Showing your company only
            </span>
          </div>
          <div key={routeKey} className="animate-rise">
            <ErrorBoundary>{children}</ErrorBoundary>
          </div>
        </main>

        {/* Mobile: a floating tab bar within thumb reach, nothing touching its edges. */}
        <nav
          aria-label="Main"
          className="fixed inset-x-4 bottom-[max(12px,env(safe-area-inset-bottom))] z-40 flex h-[60px] items-stretch rounded-[22px] glass p-1.5 md:hidden"
        >
          {items.map((item) => {
            const active = isCurrent(item, path)
            return (
              <Link
                key={item.href}
                href={item.href}
                aria-current={active ? 'page' : undefined}
                className={cx(
                  'relative flex flex-1 flex-col items-center justify-center gap-0.5 rounded-2xl text-[10.5px] font-semibold transition-colors',
                  active ? 'bg-ink text-white' : 'text-ink-2',
                )}
              >
                <item.Icon size={20} />
                {item.label}
                {item.href === '/exports' && activeExports > 0 && (
                  <span
                    className="animate-pulse-badge absolute top-1 right-[22%] grid size-4 place-items-center rounded-full bg-brand text-[10px] font-bold text-white"
                    aria-label={`${activeExports} exports in progress`}
                  >
                    {activeExports}
                  </span>
                )}
              </Link>
            )
          })}
        </nav>

        <CookieBanner onCustomize={() => setCookieDialogOpen(true)} />
        <CookieDialog open={cookieDialogOpen} onClose={() => setCookieDialogOpen(false)} />
      </ExportProvider>
    </ToastProvider>
  )
}
