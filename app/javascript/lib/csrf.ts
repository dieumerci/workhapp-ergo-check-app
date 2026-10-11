// Inertia's own requests send the CSRF token for us. A plain fetch() must send it
// itself: Rails sets it in the XSRF-TOKEN cookie and checks the X-XSRF-TOKEN header.
export function csrfHeaders(): Record<string, string> {
  const match = document.cookie.match(/(?:^|; )XSRF-TOKEN=([^;]*)/)
  return match ? { 'X-XSRF-TOKEN': decodeURIComponent(match[1]) } : {}
}
