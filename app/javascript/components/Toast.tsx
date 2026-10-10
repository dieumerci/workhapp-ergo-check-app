import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { usePage } from '@inertiajs/react'

type ToastContextValue = { say: (message: string) => void }

const ToastContext = createContext<ToastContextValue>({ say: () => {} })

export function useToast(): ToastContextValue {
  return useContext(ToastContext)
}

// Shows one toast at a time for ~3.2s. Rails flash messages (notice / alert)
// from any response are surfaced automatically.
export function ToastProvider({ children }: { children: ReactNode }) {
  const [message, setMessage] = useState('')
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const { flash } = usePage()

  const say = useCallback((text: string) => {
    setMessage(text)
    clearTimeout(timer.current)
    timer.current = setTimeout(() => setMessage(''), 3200)
  }, [])

  useEffect(() => () => clearTimeout(timer.current), [])

  useEffect(() => {
    if (flash.notice) say(flash.notice)
    else if (flash.alert) say(flash.alert)
  }, [flash, say])

  const value = useMemo(() => ({ say }), [say])

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div aria-live="polite" role="status">
        {message && (
          <div className="fixed bottom-6 left-1/2 z-50 -translate-x-1/2 animate-pop-in rounded-[10px] bg-ink px-[18px] py-[11px] font-medium text-white shadow-[0_8px_24px_rgba(0,0,0,0.25)]">
            {message}
          </div>
        )}
      </div>
    </ToastContext.Provider>
  )
}
