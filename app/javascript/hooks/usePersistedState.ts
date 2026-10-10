import { useEffect, useState } from 'react'

// useState that survives a reload via localStorage, but only when `enabled`.
// The app ties that to the "Preferences" cookie choice, so nothing is stored
// in the browser without consent. Storage can be unavailable (private mode,
// blocked site data), so every access is guarded and the state still works
// in memory.
export function usePersistedState<T>(key: string, initial: T, enabled: boolean) {
  const [value, setValue] = useState<T>(() => {
    if (!enabled) return initial
    try {
      const stored = window.localStorage.getItem(key)
      return stored === null ? initial : (JSON.parse(stored) as T)
    } catch {
      return initial
    }
  })

  useEffect(() => {
    try {
      if (enabled) window.localStorage.setItem(key, JSON.stringify(value))
      else window.localStorage.removeItem(key)
    } catch {
      // Storage unavailable: keep working in memory.
    }
  }, [key, value, enabled])

  return [value, setValue] as const
}
