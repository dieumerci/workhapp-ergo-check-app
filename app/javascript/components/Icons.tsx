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
