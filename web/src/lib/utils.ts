import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/** `[r, g, b]` from the config to a CSS colour. */
export function rgb(colour: number[] | undefined, alpha = 1) {
  const [r, g, b] = colour ?? [120, 120, 120]
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}

export const round = (value: number | undefined, places = 1) =>
  Number((value ?? 0).toFixed(places))
