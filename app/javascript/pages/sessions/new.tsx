import { useState, type FormEvent } from 'react'
import { Head, useForm, usePage } from '@inertiajs/react'
import { LockIcon } from '@/components/Icons'
import { Notice } from '@/components/ui'

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
      <form onSubmit={submit} className="paper flex flex-col gap-6 rounded-[28px] p-7 sm:p-9">
        <div>
          <h1 className="display text-[38px]">Sign in</h1>
          <p className="mt-2 text-[14px] text-muted">Company admins only. You will only ever see your own company.</p>
        </div>

        {generalErrors.length > 0 && (
          <Notice tone="danger" role="alert">
            {generalErrors.map((message) => (
              <div key={message}>{message}</div>
            ))}
          </Notice>
        )}

        <label className="field">
          <span className="eyebrow">Email</span>
          <input
            type="email"
            name="email"
            autoComplete="username"
            required
            autoFocus
            value={form.data.email}
            onChange={(event) => form.setData('email', event.target.value)}
            className="input"
          />
        </label>

        <label className="field">
          <span className="eyebrow">Password</span>
          <input
            type="password"
            name="password"
            autoComplete="current-password"
            required
            value={form.data.password}
            onChange={(event) => form.setData('password', event.target.value)}
            className="input"
          />
        </label>

        <div className="flex flex-col gap-3">
          <span className="eyebrow">Verification</span>

          {mode === 'image' ? (
            <div className="flex items-center gap-4">
              <img
                src={`/captcha?c=${challenge}`}
                width={200}
                height={64}
                alt="Verification code. Type the five digits you see. If you cannot see it, use the text question instead."
                className="rounded-xl border border-line bg-white"
              />
              <button type="button" onClick={refresh} className="btn btn-text btn-sm">
                New image
              </button>
            </div>
          ) : (
            <div className="flex items-center justify-between gap-4 rounded-2xl bg-ink/5 px-4 py-3">
              <p id="captcha-question" aria-live="polite" className="text-[14px] font-medium">
                {question || 'Loading your question…'}
              </p>
              <button type="button" onClick={refresh} className="btn btn-text btn-sm flex-none">
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
            className={`input font-mono ${mode === 'image' ? 'tracking-[0.3em]' : ''}`}
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

          <button type="button" onClick={() => switchMode(mode === 'image' ? 'text' : 'image')} className="btn btn-text btn-sm self-start">
            {mode === 'image' ? "Can't see the image? Use a text question instead" : 'Use the image instead'}
          </button>
        </div>

        <button type="submit" disabled={form.processing} className="btn btn-primary !h-12 w-full !text-[15px]">
          {form.processing ? 'Signing in…' : 'Sign in'}
        </button>

        <p className="flex items-start gap-2.5 text-[12.5px] text-muted">
          <LockIcon size={14} className="mt-px flex-none" />
          The verification image and your sign-in are protected: attempts are rate limited and nothing you type is
          written to logs.
        </p>
      </form>
    </>
  )
}
