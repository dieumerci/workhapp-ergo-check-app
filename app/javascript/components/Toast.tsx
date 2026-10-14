import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { usePage } from '@inertiajs/react'
import { AlertIcon, CheckIcon } from '@/components/Icons'

type Tone = 'ok' | 'warn'
type ToastContextValue = { say: (message: string, tone?: Tone) => void }

const ToastContext = createContext<ToastContextValue>({ say: () => {} })

export function useToast(): ToastContextValue {
  return useContext(ToastContext)
}

// Shows one toast at a time. Rails flash messages (notice / alert) from any response are surfaced
// automatically: a notice confirms (3.2s), an alert warns with its own icon and stays longer (6s) so a
// refusal, such as an expired download link, is not missed. It floats above the mobile tab bar.
export function ToastProvider({ children }: { children: ReactNode }) {
  const [toast, setToast] = useState<{ message: string; tone: Tone } | null>(null)
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const { flash } = usePage()

  const say = useCallback((text: string, tone: Tone = 'ok') => {
    setToast({ message: text, tone })
    clearTimeout(timer.current)
    timer.current = setTimeout(() => setToast(null), tone === 'warn' ? 6000 : 3200)
  }, [])

  useEffect(() => () => clearTimeout(timer.current), [])

  useEffect(() => {
    if (flash.notice) say(flash.notice)
    else if (flash.alert) say(flash.alert, 'warn')
  }, [flash, say])

  const value = useMemo(() => ({ say }), [say])

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div aria-live="polite" role="status">
        {toast && (
          <div className="glass fixed bottom-[88px] left-1/2 z-50 flex max-w-[calc(100vw-32px)] -translate-x-1/2 animate-pop-in items-center gap-2.5 rounded-full py-2.5 pr-5 pl-3 text-[13.5px] font-semibold text-ink md:bottom-8">
            <span
              className={`grid size-6 flex-none place-items-center rounded-full ${toast.tone === 'warn' ? 'bg-warn-tint text-warn' : 'bg-brand text-white'}`}
            >
              {toast.tone === 'warn' ? <AlertIcon size={14} /> : <CheckIcon size={13} />}
            </span>
            {toast.message}
          </div>
        )}
      </div>
    </ToastContext.Provider>
  )
}
