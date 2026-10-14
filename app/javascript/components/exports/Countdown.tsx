import { useEffect, useState } from 'react'
import { formatCountdown } from '@/lib/format'

// Counts down once a second from the server's figure ("seconds left when this page was sent"), measured with the
// browser's own monotonic timer, so a wrong clock or time zone on this computer cannot shift it. At zero it asks for
// the list again (after a beat, so the server has also seen the link run out), which then shows the export as expired.
export default function Countdown({ seconds, onExpire }: { seconds: number; onExpire: () => void }) {
  const [left, setLeft] = useState(seconds)

  useEffect(() => {
    const started = performance.now()
    setLeft(seconds)
    const tick = setInterval(() => setLeft(Math.max(0, Math.ceil(seconds - (performance.now() - started) / 1000))), 1000)
    return () => clearInterval(tick)
  }, [seconds])

  useEffect(() => {
    if (left > 0) return
    const wait = setTimeout(onExpire, 1200)
    return () => clearTimeout(wait)
  }, [left, onExpire])

  return (
    <span role="timer" className="font-semibold tabular-nums text-ink-2">
      {formatCountdown(left)}
    </span>
  )
}
