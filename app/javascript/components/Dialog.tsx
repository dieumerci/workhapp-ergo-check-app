import { useEffect, useRef, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { cx } from '@/lib/cx'

const FOCUSABLE =
  'a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),textarea:not([disabled]),[tabindex]:not([tabindex="-1"])'

// Open dialogs, topmost last. Only the topmost one reacts to Escape and Tab, so
// stacked dialogs close one at a time and focus cannot wander into a lower one.
const openDialogs: symbol[] = []

type DialogProps = {
  open: boolean
  onClose: () => void
  labelledBy: string
  variant?: 'modal' | 'drawer'
  children: ReactNode
}

// Modal / drawer shell. Rendered in a portal outside the app root, which is made
// inert while any dialog is open (so nothing behind it can be reached with Tab or a
// screen reader). Backdrop click and Escape close it, Tab stays inside it, page scroll
// is locked, and focus returns to whatever opened it.
export default function Dialog({ open, onClose, labelledBy, variant = 'modal', children }: DialogProps) {
  const panel = useRef<HTMLDivElement>(null)
  const closeRef = useRef(onClose)

  useEffect(() => {
    closeRef.current = onClose
  })

  useEffect(() => {
    if (!open) return

    const id = Symbol('dialog')
    openDialogs.push(id)
    const appRoot = document.getElementById('app')
    appRoot?.setAttribute('inert', '')

    const previouslyFocused = document.activeElement as HTMLElement | null
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    panel.current?.focus()

    const onKeyDown = (event: KeyboardEvent) => {
      if (openDialogs[openDialogs.length - 1] !== id) return

      if (event.key === 'Escape') {
        event.stopPropagation()
        closeRef.current()
        return
      }
      if (event.key !== 'Tab' || !panel.current) return

      const items = Array.from(panel.current.querySelectorAll<HTMLElement>(FOCUSABLE))
      if (items.length === 0) {
        event.preventDefault()
        return
      }
      const first = items[0]
      const last = items[items.length - 1]
      const active = document.activeElement
      // Focus on the panel itself (where it starts) or outside it: bring it inside.
      const inside = active !== panel.current && panel.current.contains(active)
      if (!inside) {
        event.preventDefault()
        ;(event.shiftKey ? last : first).focus()
      } else if (event.shiftKey && active === first) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && active === last) {
        event.preventDefault()
        first.focus()
      }
    }

    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.removeEventListener('keydown', onKeyDown)
      openDialogs.splice(openDialogs.indexOf(id), 1)
      if (openDialogs.length === 0) appRoot?.removeAttribute('inert')
      document.body.style.overflow = previousOverflow
      previouslyFocused?.focus?.()
    }
  }, [open])

  if (!open) return null

  const isModal = variant === 'modal'

  return createPortal(
    <>
      <div
        onClick={onClose}
        aria-hidden="true"
        className={cx('fixed inset-0', isModal ? 'z-30 bg-ink/45' : 'z-20 bg-ink/35')}
      />
      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        aria-labelledby={labelledBy}
        tabIndex={-1}
        className={cx(
          'fixed bg-white outline-none',
          isModal
            ? 'top-1/2 left-1/2 z-31 max-h-[calc(100vh-32px)] w-[min(520px,calc(100vw-32px))] -translate-x-1/2 -translate-y-1/2 animate-pop-in overflow-y-auto rounded-2xl p-6 shadow-[0_24px_60px_rgba(0,0,0,0.25)]'
            : 'top-0 right-0 bottom-0 z-21 w-[min(420px,100vw)] animate-slide-in overflow-y-auto p-6 shadow-[-12px_0_40px_rgba(0,0,0,0.12)]',
        )}
      >
        {children}
      </div>
    </>,
    document.body,
  )
}
