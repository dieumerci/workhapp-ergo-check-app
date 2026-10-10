import { useState, type FormEvent } from 'react'
import { Head, useForm, usePage } from '@inertiajs/react'
import { LockIcon } from '@/components/Icons'

const labelClass = 'flex flex-col gap-1.5 text-xs font-semibold tracking-wider text-muted uppercase'
const inputClass =
  'rounded-[9px] border border-control bg-white px-2.5 py-[9px] text-sm font-normal tracking-normal text-ink normal-case'

export default function New() {
  const form = useForm({ email: '', password: '', captcha: '' })
  const { errors } = usePage().props
  // Bumped after every attempt so the browser fetches a brand-new challenge image.
  const [challenge, setChallenge] = useState(() => Date.now())
  // Accessible alternative to the image: a short sum a screen reader can read aloud.
  const [mode, setMode] = useState<'image' | 'text'>('image')
  const [question, setQuestion] = useState('')
  const [questionError, setQuestionError] = useState('')

  const loadQuestion = async () => {
    setQuestionError('')
    try {
      const response = await fetch('/captcha/question', { headers: { Accept: 'application/json' }, credentials: 'same-origin' })
      const body = (await response.json()) as { question?: string; error?: string }
      if (response.ok && body.question) setQuestion(body.question)
      else setQuestionError(body.error ?? 'Could not load a question. Please try again.')
    } catch {
      setQuestionError('Could not load a question. Please try again.')
    }
  }

  const refresh = () => {
    if (mode === 'text') void loadQuestion()
    else setChallenge(Date.now())
  }

  const switchMode = (next: 'image' | 'text') => {
    setMode(next)
    form.setData('captcha', '')
    if (next === 'text') void loadQuestion()
    else setChallenge(Date.now())
  }

  const submit = (event: FormEvent) => {
    event.preventDefault()
    form.post('/session', {
      onError: () => form.reset('password', 'captcha'),
      onFinish: refresh,
    })
  }

  // Not tied to one field (bad credentials, rate limit), so read from the page errors.
  const generalErrors = errors.base ?? []

  return (
    <>
      <Head title="Sign in" />
      <form onSubmit={submit} className="flex flex-col gap-5 rounded-2xl border border-line bg-white p-6 shadow-sm">
        <div>
          <h1 className="text-[22px] font-bold tracking-tight">Sign in</h1>
          <p className="mt-0.5 text-muted">Company admins only. You will only ever see your own company.</p>
        </div>

        {generalErrors.length > 0 && (
          <div role="alert" className="rounded-[10px] bg-danger-tint px-3 py-2.5 text-[13px] font-medium text-danger">
            {generalErrors.map((message) => (
              <div key={message}>{message}</div>
            ))}
          </div>
        )}

        <label className={labelClass}>
          Email
          <input
            type="email"
            name="email"
            autoComplete="username"
            required
            autoFocus
            value={form.data.email}
            onChange={(event) => form.setData('email', event.target.value)}
            className={inputClass}
          />
        </label>

        <label className={labelClass}>
          Password
          <input
            type="password"
            name="password"
            autoComplete="current-password"
            required
            value={form.data.password}
            onChange={(event) => form.setData('password', event.target.value)}
            className={inputClass}
          />
        </label>

        <div className="flex flex-col gap-2">
          <span className="text-xs font-semibold tracking-wider text-muted uppercase">Verification</span>

          {mode === 'image' ? (
            <div className="flex items-center gap-3">
              <img
                src={`/captcha?c=${challenge}`}
                width={200}
                height={64}
                alt="Verification code. Type the five digits you see. If you cannot see it, use the text question instead."
                className="rounded-lg border border-line"
              />
              <button type="button" onClick={refresh} className="text-[13px] font-semibold text-brand hover:text-brand-dark">
                New image
              </button>
            </div>
          ) : (
            <div className="flex items-center justify-between gap-3 rounded-lg border border-line bg-canvas px-3 py-2.5">
              <p id="captcha-question" aria-live="polite" className="text-sm font-medium">
                {question || 'Loading your question…'}
              </p>
              <button type="button" onClick={refresh} className="flex-none text-[13px] font-semibold text-brand hover:text-brand-dark">
                New question
              </button>
            </div>
          )}

          <input
            type="text"
            name="captcha"
            inputMode="numeric"
            autoComplete="off"
            pattern={mode === 'image' ? '[0-9]{5}' : '[0-9]{1,3}'}
            maxLength={mode === 'image' ? 5 : 3}
            required
            aria-label={mode === 'image' ? 'Verification code' : 'Answer to the verification question'}
            aria-describedby={mode === 'text' ? 'captcha-question' : undefined}
            placeholder={mode === 'image' ? 'Type the 5 digits' : 'Type the answer'}
            value={form.data.captcha}
            onChange={(event) => form.setData('captcha', event.target.value)}
            className={`${inputClass} font-mono ${mode === 'image' ? 'tracking-[0.3em]' : ''}`}
          />

          {questionError && (
            <p role="alert" className="text-[13px] font-medium text-danger">
              {questionError}
            </p>
          )}
          {form.errors.captcha?.map((message) => (
            <p key={message} role="alert" className="text-[13px] font-medium text-danger">
              {message}
            </p>
          ))}

          <button
            type="button"
            onClick={() => switchMode(mode === 'image' ? 'text' : 'image')}
            className="self-start text-[13px] font-semibold text-brand hover:text-brand-dark"
          >
            {mode === 'image' ? "Can't see the image? Use a text question instead" : 'Use the image instead'}
          </button>
        </div>

        <button
          type="submit"
          disabled={form.processing}
          className="rounded-[9px] bg-brand px-4 py-2.5 font-semibold text-white hover:bg-brand-dark disabled:opacity-60"
        >
          {form.processing ? 'Signing in…' : 'Sign in'}
        </button>

        <p className="flex items-start gap-2 text-xs text-muted">
          <LockIcon size={14} className="mt-px flex-none" />
          The verification image and your sign-in are protected: attempts are rate limited and nothing you type is
          written to logs.
        </p>
      </form>
    </>
  )
}
