import {
  Select,
  SelectContent,
  SelectItem,
  SelectSeparator,
  SelectTrigger,
  SelectValue
} from '@/components/ui/select'
import { WeatherIcon } from '@/lib/weather'
import { fetchNui } from '@/lib/nui'
import { useStore } from '@/store'

/**
 * Force a weather on one region (or '*' for every one), hand it back to its
 * climate with Auto, or skip ahead with Next. Fires straight away: weather is
 * live state, not part of the region record that Save writes.
 */
export function WeatherSelect({
  regionId,
  value,
  placeholder = 'Set weather',
  className
}: {
  regionId: string
  value?: string
  placeholder?: string
  className?: string
}) {
  const weathers = useStore((state) => state.data.weathers)

  return (
    <Select
      value={value ?? ''}
      onValueChange={(weather) => void fetchNui('setRegionWeather', { id: regionId, weather })}
    >
      <SelectTrigger className={className}>
        <SelectValue placeholder={placeholder} />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="auto">Auto — let the climate decide</SelectItem>
        <SelectItem value="next">Next — move on now</SelectItem>
        <SelectSeparator />
        {weathers.map((weather) => (
          <SelectItem key={weather.name} value={weather.name}>
            <span className="flex items-center gap-2">
              <WeatherIcon weather={weather.name} className="text-muted-foreground" />
              {weather.label}
            </span>
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}
