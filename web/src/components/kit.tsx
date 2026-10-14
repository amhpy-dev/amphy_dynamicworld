import type * as React from 'react'
import { cn } from '@/lib/utils'

export type Tone = 'success' | 'warning' | 'primary' | 'destructive' | 'neutral'

const TONES: Record<Tone, string> = {
  success: 'bg-raised text-success',
  warning: 'bg-raised text-warning',
  primary: 'bg-primary-tint text-primary',
  destructive: 'bg-destructive-tint text-destructive',
  neutral: 'bg-raised text-muted-foreground'
}

export function Pill({ tone = 'neutral', children }: { tone?: Tone; children: React.ReactNode }) {
  return (
    <span className={cn('inline-flex shrink-0 items-center gap-1 rounded-sm px-2 py-1 text-xs font-semibold', TONES[tone])}>
      {children}
    </span>
  )
}

export function Detail({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-3 text-sm">
      <span className="font-medium text-muted-foreground">{label}</span>
      <span className="font-semibold">{children}</span>
    </div>
  )
}

export function PageHeader({ title, children }: { title: string; children?: React.ReactNode }) {
  return (
    <header className="flex h-10 shrink-0 items-center justify-between gap-4">
      <h1 className="text-[27px] font-semibold leading-tight">{title}</h1>
      {children}
    </header>
  )
}

export function Field({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1.5">
      <span className="text-sm font-semibold">{label}</span>
      {hint && <p className="text-xs font-medium leading-snug text-muted-foreground">{hint}</p>}
      {children}
    </div>
  )
}
