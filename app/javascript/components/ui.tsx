import type { ReactNode } from 'react'
import { usePage } from '@inertiajs/react'
import { CloseIcon, LockIcon } from '@/components/Icons'
import { cx } from '@/lib/cx'

// Pieces every dialog and sheet shares, so they look and read the same.

// Serif title, one line of context, and the close button. +id+ labels the dialog.
export function SheetHeader({ id, title, subtitle, onClose }: { id: string; title: string; subtitle?: ReactNode; onClose: () => void }) {
  return (
    <div className="flex items-start justify-between gap-4">
      <div className="min-w-0">
        <h2 id={id} className="display text-[32px]">
          {title}
        </h2>
        {subtitle && <div className="mt-2 text-[14px] text-muted">{subtitle}</div>}
      </div>
      <button type="button" onClick={onClose} aria-label="Close" className="icon-btn -mt-1 -mr-2 flex-none">
        <CloseIcon size={15} />
      </button>
    </div>
  )
}

const TONES = {
  brand: 'bg-brand-tint text-brand-ink',
  ok: 'bg-ok-tint text-ok',
  danger: 'bg-danger-tint text-danger',
  neutral: 'bg-ink/5 text-muted',
} as const

// A short status message. +role+ "alert" for problems, "status" for results.
export function Notice({ tone, role, children }: { tone: keyof typeof TONES; role?: 'alert' | 'status'; children: ReactNode }) {
  return (
    <div role={role} className={cx('rounded-2xl px-4 py-3 text-[13.5px] font-medium', TONES[tone])}>
      {children}
    </div>
  )
}

// "Northwind Logistics only — set by your account, not editable."
export function CompanyLock({ prefix }: { prefix?: string }) {
  const { auth } = usePage().props
  return (
    <div className="flex items-center gap-3 rounded-2xl bg-brand-tint px-4 py-3 text-[13.5px] text-brand-ink">
      <LockIcon size={16} className="flex-none" />
      <div>
        {prefix} <strong>{auth.company?.name}</strong> only — set by your account, not editable.
      </div>
    </div>
  )
}

// The top of every page: a serif title, one line of context, and optional actions.
export function PageHeader({ title, lead, tag, actions }: { title: string; lead?: ReactNode; tag?: string; actions?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-x-8 gap-y-5">
      <div>
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="display text-[44px] md:text-[60px]">{title}</h1>
          {tag && <span className="rounded-full bg-warn-tint px-3 py-1 text-[11px] font-bold tracking-[0.1em] text-warn uppercase">{tag}</span>}
        </div>
        {lead && <p className="mt-3 max-w-[56ch] text-[15px] text-muted">{lead}</p>}
      </div>
      {actions && <div className="flex flex-wrap gap-2.5">{actions}</div>}
    </div>
  )
}

// An open section: an eyebrow title over a hairline, no box around the content.
export function Section({ title, aside, children }: { title: string; aside?: ReactNode; children: ReactNode }) {
  return (
    <section className="flex flex-col gap-4">
      <div className="flex items-baseline justify-between gap-4 border-b border-line pb-3">
        <h2 className="eyebrow !text-ink-2">{title}</h2>
        {aside && <div className="text-[13px] text-muted tabular-nums">{aside}</div>}
      </div>
      {children}
    </section>
  )
}
