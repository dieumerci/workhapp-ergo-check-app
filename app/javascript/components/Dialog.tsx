import { useEffect, useRef, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { cx } from '@/lib/cx'

const FOCUSABLE =
  'a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),textarea:not([disabled]),[tabindex]:not([tabindex="-1"])'

// Open dialogs, topmost last. Only the topmost one reacts to Escape and Tab, so
// stacked dialogs close one at a time and focus cannot wander into a lower one.
const openDialogs: symbol[] = []

// Page scroll is locked while any dialog is open. The lock belongs to the stack, not to each dialog:
// two can overlap and close in either order (a "created" redirect opens the detail sheet before the
// form dialog finishes closing), and saving and restoring the value per dialog would then leave the
// page locked for good. So the original value is saved when the first one opens and put back when
// the last one closes.
let bodyOverflowBeforeLock = ''

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
    if (openDialogs.length === 0) bodyOverflowBeforeLock = document.body.style.overflow
    openDialogs.push(id)
    const appRoot = document.getElementById('app')
    appRoot?.setAttribute('inert', '')

    const previouslyFocused = document.activeElement as HTMLElement | null
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
      if (openDialogs.length === 0) {
        appRoot?.removeAttribute('inert')
        document.body.style.overflow = bodyOverflowBeforeLock
      }
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
        className={cx('fixed inset-0 animate-fade-in backdrop-blur-[3px]', isModal ? 'z-[45] bg-ink/40' : 'z-[44] bg-ink/30')}
      />
      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        aria-labelledby={labelledBy}
        tabIndex={-1}
        className={cx(
          'paper fixed overflow-y-auto outline-none',
          isModal
            ? // A centred sheet on large screens; a bottom sheet within thumb reach on phones.
              'z-[46] max-h-[calc(100dvh-32px)] animate-pop-in rounded-[28px] p-7 max-sm:inset-x-0 max-sm:bottom-0 max-sm:max-h-[92dvh] max-sm:w-full max-sm:rounded-b-none max-sm:p-5 sm:top-1/2 sm:left-1/2 sm:w-[min(540px,calc(100vw-32px))] sm:-translate-x-1/2 sm:-translate-y-1/2'
            : // The detail drawer floats, inset from the edges, instead of being bolted to the window.
              'top-3 right-3 bottom-3 z-[45] w-[min(456px,calc(100vw-24px))] animate-slide-in rounded-[28px] p-7',
        )}
      >
        {children}
      </div>
    </>,
    document.body,
  )
}
