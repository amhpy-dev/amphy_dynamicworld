import {
  Cloud,
  CloudFog,
  CloudLightning,
  CloudRain,
  CloudSnow,
  CloudSun,
  Cloudy,
  Factory,
  Ghost,
  Snowflake,
  Sun,
  type LucideIcon
} from 'lucide-react'
import { cn } from '@/lib/utils'
import type { Tone } from '@/components/kit'

const ICONS: Record<string, LucideIcon> = {
  EXTRASUNNY: Sun,
  CLEAR: Sun,
  NEUTRAL: CloudSun,
  SMOG: Factory,
  FOGGY: CloudFog,
  OVERCAST: Cloudy,
  CLOUDS: Cloud,
  CLEARING: CloudSun,
  RAIN: CloudRain,
  THUNDER: CloudLightning,
  SNOWLIGHT: CloudSnow,
  SNOW: CloudSnow,
  BLIZZARD: Snowflake,
  XMAS: Snowflake,
  HALLOWEEN: Ghost
}

export function WeatherIcon({ weather, className }: { weather?: string; className?: string }) {
  const Icon = (weather && ICONS[weather]) || Cloud
  return <Icon className={cn('size-4 shrink-0', className)} />
}

const TONES: Record<string, Tone> = {
  EXTRASUNNY: 'success',
  CLEAR: 'success',
  CLEARING: 'success',
  RAIN: 'primary',
  THUNDER: 'primary',
  SNOWLIGHT: 'primary',
  SNOW: 'primary',
  BLIZZARD: 'primary',
  XMAS: 'primary'
}

/** Fair weather reads green, falling weather blue, everything grey in between amber. */
export const weatherTone = (weather?: string): Tone => (weather && TONES[weather]) || 'warning'

/**
 * "in 12 min" from the os.time() the server published, or null when held.
 * Both ends are unix seconds, so the client's own clock is close enough.
 */
export function untilChange(ends: number | undefined) {
  if (!ends || ends >= 9_000_000_000) return null

  const minutes = Math.max(0, Math.round((ends - Date.now() / 1000) / 60))
  return minutes <= 0 ? 'any moment' : `in ${minutes} min`
}
