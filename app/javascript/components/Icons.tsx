import type { SVGProps } from 'react'

type IconProps = SVGProps<SVGSVGElement> & { size?: number }

function base({ size = 16, ...rest }: IconProps) {
  return {
    width: size,
    height: size,
    viewBox: '0 0 16 16',
    fill: 'none',
    stroke: 'currentColor',
    'aria-hidden': true,
    ...rest,
  }
}

export function LockIcon(props: IconProps) {
  return (
    <svg {...base(props)} strokeWidth={props.strokeWidth ?? 1.8}>
      <rect x="3" y="7" width="10" height="7" rx="1.5" />
      <path d="M5 7V5a3 3 0 0 1 6 0v2" />
    </svg>
  )
}

export function DownloadIcon(props: IconProps) {
  return (
    <svg {...base(props)} strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
      <path d="M8 2v8M4.5 7 8 10.5 11.5 7M2.5 13.5h11" />
    </svg>
  )
}

export function CloseIcon(props: IconProps) {
  return (
    <svg {...base(props)} strokeWidth={1.8} strokeLinecap="round">
      <path d="M3.5 3.5l9 9M12.5 3.5l-9 9" />
    </svg>
  )
}

export function SearchIcon(props: IconProps) {
  return (
    <svg {...base(props)} strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
      <circle cx="7" cy="7" r="4.5" />
      <path d="M10.5 10.5 14 14" />
    </svg>
  )
}

export function PlusIcon(props: IconProps) {
  return (
    <svg {...base(props)} strokeWidth={1.8} strokeLinecap="round">
      <path d="M8 3v10M3 8h10" />
    </svg>
  )
}

const line = { strokeWidth: 1.7, strokeLinecap: 'round', strokeLinejoin: 'round' } as const

export function ListIcon(props: IconProps) {
  return (
    <svg {...base(props)} {...line}>
      <path d="M5.5 4h8M5.5 8h8M5.5 12h8" />
      <circle cx="2.6" cy="4" r=".6" />
      <circle cx="2.6" cy="8" r=".6" />
      <circle cx="2.6" cy="12" r=".6" />
    </svg>
  )
}

export function FileDownIcon(props: IconProps) {
  return (
    <svg {...base(props)} {...line}>
      <path d="M9.5 1.8H4.6A1.6 1.6 0 0 0 3 3.4v9.2a1.6 1.6 0 0 0 1.6 1.6h6.8A1.6 1.6 0 0 0 13 12.6V5.3L9.5 1.8Z" />
      <path d="M9.3 1.8v3.6H13M8 7.4v4M6.2 9.8 8 11.6l1.8-1.8" />
    </svg>
  )
}

export function RouteIcon(props: IconProps) {
  return (
    <svg {...base(props)} {...line}>
      <circle cx="3.6" cy="12.2" r="1.6" />
      <circle cx="12.4" cy="3.8" r="1.6" />
      <path d="M5.2 12.2h4.3a2.3 2.3 0 0 0 0-4.6H6.5a2.3 2.3 0 0 1 0-4.6h4.3" />
    </svg>
  )
}

export function ShieldIcon(props: IconProps) {
  return (
    <svg {...base(props)} {...line}>
      <path d="M8 1.8 3 3.7v4c0 3 2.1 5.3 5 6.5 2.9-1.2 5-3.5 5-6.5v-4L8 1.8Z" />
      <path d="m5.9 8 1.5 1.5L10.2 6.6" />
    </svg>
  )
}

export function ChevronIcon({ direction = 'right', ...props }: IconProps & { direction?: 'left' | 'right' | 'down' }) {
  const path = { left: 'M10 3.5 5.5 8 10 12.5', right: 'M6 3.5 10.5 8 6 12.5', down: 'M3.5 6 8 10.5 12.5 6' }[direction]
  return (
    <svg {...base(props)} {...line}>
      <path d={path} />
    </svg>
  )
}

export function CheckIcon(props: IconProps) {
  return (
    <svg {...base(props)} {...line}>
      <path d="m3.2 8.4 3 3 6.6-7" />
    </svg>
  )
}

export function CookieIcon(props: IconProps) {
  return (
    <svg {...base(props)} {...line}>
      <path d="M8 1.8a6.2 6.2 0 1 0 6.2 6.2 2.6 2.6 0 0 1-3-3.1A2.6 2.6 0 0 1 8 1.8Z" />
      <path d="M5.6 7.2h.01M8.6 10.4h.01M5.4 10.2h.01" strokeWidth="2" />
    </svg>
  )
}

export function LogOutIcon(props: IconProps) {
  return (
    <svg {...base(props)} {...line}>
      <path d="M6.2 2.6H4.4A1.4 1.4 0 0 0 3 4v8a1.4 1.4 0 0 0 1.4 1.4h1.8M10.2 5 13 8l-2.8 3M13 8H6.4" />
    </svg>
  )
}
