import { useEffect, useRef, useState } from 'react'
import { Link, usePage } from '@inertiajs/react'
import { CookieIcon, LockIcon, LogOutIcon } from '@/components/Icons'

// The signed-in admin's menu: who you are, which company you are looking at, cookie
// settings and sign out. Closes on Escape, on an outside click and on selection.
export default function UserMenu({ onCookieSettings }: { onCookieSettings: () => void }) {
  const { auth } = usePage().props
  const [open, setOpen] = useState(false)
  const root = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const onPointer = (event: PointerEvent) => {
      if (!root.current?.contains(event.target as Node)) setOpen(false)
    }
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false)
    }
    document.addEventListener('pointerdown', onPointer)
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('pointerdown', onPointer)
      document.removeEventListener('keydown', onKey)
    }
  }, [open])

  const itemClass = 'flex w-full items-center gap-2.5 rounded-xl px-3 py-2.5 text-left text-[13.5px] font-semibold text-ink-2 hover:bg-hover'

  return (
    <div ref={root} className="relative">
      <button
        type="button"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={`Account menu for ${auth.admin?.name ?? 'you'}`}
        onClick={() => setOpen((current) => !current)}
        className="grid size-10 place-items-center rounded-full bg-brand-tint text-[13px] font-bold text-brand-ink ring-1 ring-brand/15 transition hover:ring-brand/40"
      >
        {auth.admin?.initials}
      </button>

      {open && (
        <div role="menu" className="paper absolute top-[calc(100%+10px)] right-0 z-50 w-[272px] animate-pop-in rounded-[20px] p-2">
          <div className="px-3 pt-2 pb-3">
            <div className="truncate text-[15px] font-semibold">{auth.admin?.name}</div>
            <div className="text-[13px] text-muted">Company admin · {auth.company?.name}</div>
            <div className="mt-2 inline-flex items-center gap-1.5 rounded-full bg-brand-tint px-2.5 py-1 text-xs font-semibold text-brand-ink">
              <LockIcon size={11} strokeWidth={2} />
              Your company only
            </div>
          </div>
          <div className="border-t border-line-soft pt-1.5">
            <button
              type="button"
              role="menuitem"
              onClick={() => {
                setOpen(false)
                onCookieSettings()
              }}
              className={itemClass}
            >
              <CookieIcon size={16} className="text-muted" />
              Cookie settings
            </button>
            <Link href="/session" method="delete" as="button" role="menuitem" className={itemClass}>
              <LogOutIcon size={16} className="text-muted" />
              Sign out
            </Link>
          </div>
        </div>
      )}
    </div>
  )
}
