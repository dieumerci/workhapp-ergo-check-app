import { useEffect, useRef, useState } from 'react'
import { CloseIcon, SearchIcon } from '@/components/Icons'

const DEBOUNCE_MS = 280

type Props = { value: string; onSearch: (text: string) => void }

function typingElsewhere(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false
  return target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName)
}

// Searches the company's assessments by employee name, department or code
// ("A-10708"). It waits for a pause in typing, keeps what was typed even while a
// request is in flight, and is focused from anywhere with "/" or Cmd/Ctrl+K.
export default function SearchField({ value, onSearch }: Props) {
  const [text, setText] = useState(value)
  const input = useRef<HTMLInputElement>(null)
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const lastSent = useRef(value)

  // Follow the server only when the change did not come from this box (for
  // example "Clear filters"), so a slow response never overwrites newer typing.
  useEffect(() => {
    if (value !== lastSent.current) {
      lastSent.current = value
      setText(value)
    }
  }, [value])

  useEffect(() => () => clearTimeout(timer.current), [])

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      const palette = (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k'
      const slash = event.key === '/' && !event.metaKey && !event.ctrlKey && !event.altKey && !typingElsewhere(event.target)
      if (!palette && !slash) return
      event.preventDefault()
      input.current?.focus()
      input.current?.select()
    }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [])

  const send = (next: string) => {
    clearTimeout(timer.current)
    timer.current = setTimeout(() => {
      const clean = next.replace(/\s+/g, ' ').trim()
      if (clean === lastSent.current) return
      lastSent.current = clean
      onSearch(clean)
    }, DEBOUNCE_MS)
  }

  const change = (next: string) => {
    setText(next)
    send(next)
  }

  const clear = () => {
    setText('')
    clearTimeout(timer.current)
    if (lastSent.current !== '') {
      lastSent.current = ''
      onSearch('')
    }
    input.current?.focus()
  }

  const shortcut = typeof navigator !== 'undefined' && /mac|iphone|ipad/i.test(navigator.platform) ? '⌘K' : 'Ctrl K'

  return (
    <form role="search" onSubmit={(event) => event.preventDefault()} className="relative min-w-[240px] flex-1 basis-[280px]">
      <SearchIcon size={17} className="pointer-events-none absolute top-1/2 left-4 -translate-y-1/2 text-subtle" />
      <input
        ref={input}
        type="search"
        value={text}
        maxLength={64}
        autoComplete="off"
        spellCheck={false}
        aria-label="Search assessments by employee, department or code"
        placeholder="Search name, department or code"
        onChange={(event) => change(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === 'Escape' && text !== '') {
            event.preventDefault()
            event.stopPropagation()
            clear()
          }
        }}
        className="input !rounded-full !pr-24 !pl-11"
      />
      <div className="absolute top-1/2 right-3 flex -translate-y-1/2 items-center gap-1.5">
        {text !== '' ? (
          <button type="button" onClick={clear} aria-label="Clear search" className="grid size-7 place-items-center rounded-full bg-hover text-ink-2 hover:bg-line">
            <CloseIcon size={11} />
          </button>
        ) : (
          <kbd className="hidden rounded-md border border-line bg-canvas px-1.5 py-0.5 font-mono text-[11px] text-subtle sm:block">{shortcut}</kbd>
        )}
      </div>
    </form>
  )
}
