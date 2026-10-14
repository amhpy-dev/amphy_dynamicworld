import { Globe, Lock, Search, ZapOff } from 'lucide-react'
import { Input } from '@/components/ui/input'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Switch } from '@/components/ui/switch'
import { findClimate, useStore } from '@/store'
import { fetchNui } from '@/lib/nui'
import { WeatherIcon } from '@/lib/weather'
import { cn, rgb } from '@/lib/utils'
import type { Region } from '@/types'

export function RegionList() {
  const { regions, climates, live, current } = useStore((state) => state.data)
  const draft = useStore((state) => state.draft)
  const search = useStore((state) => state.search)
  const setSearch = useStore((state) => state.setSearch)
  const select = useStore((state) => state.select)

  const term = search.trim().toLowerCase()
  const listed = regions.filter(
    (region) => !term || region.label.toLowerCase().includes(term) || region.climate.includes(term)
  )

  const row = (region: Region) => {
    const climate = findClimate(climates, region.climate)
    const sky = live[region.id]
    const global = region.shape === 'global'
    const off = region.enabled === false

    return (
      <li key={region.id}>
        <div
          role="button"
          tabIndex={0}
          onClick={() => select(region.id)}
          onKeyDown={(event) => event.key === 'Enter' && select(region.id)}
          className={cn(
            'flex cursor-pointer items-center gap-3 rounded-md border px-3 py-2.5 transition-colors',
            region.id === draft?.id ? 'border-primary bg-primary-soft' : 'border-transparent hover:bg-raised'
          )}
        >
          {global ? (
            <Globe className="size-4 shrink-0 text-muted-foreground" />
          ) : (
            <span className="size-2.5 shrink-0 rounded-full" style={{ background: rgb(climate?.colour, off ? 0.35 : 1) }} />
          )}

          <span className="min-w-0 flex-1">
            <span className="flex items-center gap-1.5 text-sm font-semibold">
              <span className="truncate">{global ? 'Everywhere else' : region.label}</span>
              {region.id === current && <span className="text-[11px] font-semibold text-primary">YOU</span>}
            </span>
            <span className="flex items-center gap-1 text-xs font-medium text-muted-foreground">
              {sky && !off ? (
                <>
                  <WeatherIcon weather={sky.weather} className="size-3" />
                  <span className="truncate">{sky.label} · {Math.round(sky.temperature)}°C</span>
                  {sky.forced && <Lock className="size-3 shrink-0" />}
                  {sky.blackout && <ZapOff className="size-3 shrink-0" />}
                </>
              ) : (
                <span className="truncate">{off ? 'Disabled' : climate?.label}</span>
              )}
            </span>
          </span>

          {!global && (
            <Switch
              checked={!off}
              onClick={(event) => event.stopPropagation()}
              onCheckedChange={() => void fetchNui('toggleRegion', { id: region.id })}
            />
          )}
        </div>
      </li>
    )
  }

  return (
    <div className="flex w-[280px] shrink-0 flex-col gap-2 rounded-md border border-border bg-card p-2">
      <div className="relative">
        <Search className="absolute left-2.5 top-2.5 size-4 text-muted-foreground" />
        <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search regions" className="pl-8" />
      </div>

      <ScrollArea className="min-h-0 flex-1">
        {listed.length === 0 ? (
          <p className="p-3 text-xs font-medium text-muted-foreground">No region matches that search.</p>
        ) : (
          <ul className="flex flex-col gap-1">{listed.map(row)}</ul>
        )}
      </ScrollArea>
    </div>
  )
}
