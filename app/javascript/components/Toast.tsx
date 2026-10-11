import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { usePage } from '@inertiajs/react'
import { CheckIcon } from '@/components/Icons'

type ToastContextValue = { say: (message: string) => void }

const ToastContext = createContext<ToastContextValue>({ say: () => {} })

export function useToast(): ToastContextValue {
  return useContext(ToastContext)
}

// Shows one toast at a time for ~3.2s. Rails flash messages (notice / alert)
// from any response are surfaced automatically. It floats above the mobile tab bar.
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
          <div className="glass fixed bottom-[88px] left-1/2 z-50 flex max-w-[calc(100vw-32px)] -translate-x-1/2 animate-pop-in items-center gap-2.5 rounded-full py-2.5 pr-5 pl-3 text-[13.5px] font-semibold text-ink md:bottom-8">
            <span className="grid size-6 flex-none place-items-center rounded-full bg-brand text-white">
              <CheckIcon size={13} />
            </span>
            {message}
          </div>
        )}
      </div>
    </ToastContext.Provider>
  )
}
