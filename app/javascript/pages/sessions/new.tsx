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

  const refresh = () => setChallenge(Date.now())

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
          <div className="flex items-center gap-3">
            <img
              src={`/captcha?c=${challenge}`}
              width={200}
              height={64}
              alt="Verification code. Type the five digits you see."
              className="rounded-lg border border-line"
            />
            <button
              type="button"
              onClick={refresh}
              className="text-[13px] font-semibold text-brand hover:text-brand-dark"
            >
              New image
            </button>
          </div>
          <input
            type="text"
            name="captcha"
            inputMode="numeric"
            autoComplete="off"
            pattern="[0-9]{5}"
            maxLength={5}
            required
            aria-label="Verification code"
            placeholder="Type the 5 digits"
            value={form.data.captcha}
            onChange={(event) => form.setData('captcha', event.target.value)}
            className={`${inputClass} font-mono tracking-[0.3em]`}
          />
          {form.errors.captcha?.map((message) => (
            <p key={message} role="alert" className="text-[13px] font-medium text-danger">
              {message}
            </p>
          ))}
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
