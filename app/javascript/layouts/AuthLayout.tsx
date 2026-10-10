import { useState, type ReactNode } from 'react'
import { CookieBanner, CookieDialog } from '@/components/CookieConsent'
import { ToastProvider } from '@/components/Toast'
import { BrandMark } from '@/layouts/AppLayout'

export default function AuthLayout({ children }: { children: ReactNode }) {
  const [cookieDialogOpen, setCookieDialogOpen] = useState(false)

  return (
    <ToastProvider>
      <div className="flex min-h-screen flex-col items-center justify-center gap-6 px-4 py-10">
        <BrandMark />
        <main className="w-full max-w-[400px]">{children}</main>
        <button
          type="button"
          onClick={() => setCookieDialogOpen(true)}
          className="text-xs font-semibold text-muted hover:text-ink"
        >
          Cookie settings
        </button>
      </div>
      <CookieBanner onCustomize={() => setCookieDialogOpen(true)} />
      <CookieDialog open={cookieDialogOpen} onClose={() => setCookieDialogOpen(false)} />
    </ToastProvider>
  )
}
