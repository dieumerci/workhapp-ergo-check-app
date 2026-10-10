import { useEffect, useRef, type ReactNode } from 'react'
import { cx } from '@/lib/cx'

const FOCUSABLE =
  'a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),textarea:not([disabled]),[tabindex]:not([tabindex="-1"])'

type DialogProps = {
  open: boolean
  onClose: () => void
  labelledBy: string
  variant?: 'modal' | 'drawer'
  children: ReactNode
}

// Modal / drawer shell: backdrop click and Escape close it, Tab stays inside,
// page scroll is locked and focus returns to whatever opened it.
export default function Dialog({ open, onClose, labelledBy, variant = 'modal', children }: DialogProps) {
  const panel = useRef<HTMLDivElement>(null)
  const closeRef = useRef(onClose)

  useEffect(() => {
    closeRef.current = onClose
  })

  useEffect(() => {
    if (!open) return

    const previouslyFocused = document.activeElement as HTMLElement | null
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    panel.current?.focus()

    const onKeyDown = (event: KeyboardEvent) => {
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
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault()
        first.focus()
      }
    }

    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.removeEventListener('keydown', onKeyDown)
      document.body.style.overflow = previousOverflow
      previouslyFocused?.focus?.()
    }
  }, [open])

  if (!open) return null

  const isModal = variant === 'modal'

  return (
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
    </>
  )
}
