import { Plus, Save, Thermometer, Trash2 } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Slider } from '@/components/ui/slider'
import { Switch } from '@/components/ui/switch'
import { Field, PageHeader, Pill } from '@/components/kit'
import { WeatherIcon } from '@/lib/weather'
import { fetchNui } from '@/lib/nui'
import { cn, rgb } from '@/lib/utils'
import { useStore } from '@/store'
import type { Climate } from '@/types'

/** Bright on purpose: they are drawn over a dark map. */
const COLOURS = [
  [102, 187, 106], [255, 138, 76], [38, 198, 180], [120, 190, 255], [240, 98, 146],
  [255, 213, 79], [179, 136, 255], [255, 112, 112], [144, 164, 174], [174, 213, 129]
]

const shares = (climate: Climate) => {
  const total = Object.values(climate.weathers).reduce((sum, weight) => sum + weight, 0)
  return (weight = 0) => (total > 0 ? Math.round((weight / total) * 100) : 0)
}

function ClimateCard({ climate }: { climate: Climate }) {
  const regions = useStore((state) => state.data.regions)
  const weathers = useStore((state) => state.data.weathers)
  const selected = useStore((state) => state.climate?.id === climate.id)
  const selectClimate = useStore((state) => state.selectClimate)

  const used = regions.filter((region) => region.climate === climate.id).length
  const share = shares(climate)
  const top = Object.entries(climate.weathers).sort((a, b) => b[1] - a[1]).slice(0, 3)
  const label = (name: string) => weathers.find((weather) => weather.name === name)?.label ?? name

  return (
    <button
      onClick={() => selectClimate(climate.id)}
      className={cn(
        'flex flex-col gap-3 rounded-md border bg-card p-4 text-left transition-colors',
        selected ? 'border-primary' : 'border-border hover:border-faint'
      )}
    >
      <div className="flex w-full items-center justify-between gap-3">
        <span className="flex items-center gap-2.5 text-lg font-semibold">
          <span className="size-3 rounded-full" style={{ background: rgb(climate.colour) }} />
          {climate.label}
        </span>
        <Pill tone={used > 0 ? 'success' : 'neutral'}>{used === 0 ? 'Unused' : `${used} region${used === 1 ? '' : 's'}`}</Pill>
      </div>

      <div className="flex w-full items-center justify-between text-sm font-semibold">
        <span>{climate.temperature.day}° / {climate.temperature.night}°</span>
        <span className="text-muted-foreground">{climate.humidity}% humidity</span>
      </div>

      <div className="flex w-full flex-wrap gap-1.5">
        {top.map(([name, weight]) => (
          <Pill key={name}>
            <WeatherIcon weather={name} className="size-3" />
            {label(name)} {share(weight)}%
          </Pill>
        ))}
      </div>
    </button>
  )
}

function ClimateEditor() {
  const climate = useStore((state) => state.climate)
  const { weathers, regions } = useStore((state) => state.data)
  const patch = useStore((state) => state.patchClimate)
  const clear = useStore((state) => state.clearClimate)

  if (!climate) {
    return (
      <div className="flex w-[380px] shrink-0 flex-col items-center justify-center gap-2 rounded-md border border-border bg-card p-8 text-center">
        <Thermometer className="size-5 text-muted-foreground" />
        <p className="text-base font-semibold">Nothing selected</p>
        <p className="text-xs font-medium text-muted-foreground">Pick a climate to edit it, or make a new one.</p>
      </div>
    )
  }

  const share = shares(climate)
  const used = regions.filter((region) => region.climate === climate.id).length
  const total = Object.values(climate.weathers).reduce((sum, weight) => sum + weight, 0)

  return (
    <div className="flex w-[380px] shrink-0 flex-col overflow-hidden rounded-md border border-border bg-card">
      <ScrollArea className="min-h-0 flex-1">
        <div className="flex flex-col gap-5 p-4">
          <Field label="Name">
            <Input value={climate.label} maxLength={20} onChange={(event) => patch({ label: event.target.value })} />
          </Field>

          <Field label="Colour">
            <div className="flex flex-wrap gap-2">
              {COLOURS.map((colour) => (
                <button
                  key={colour.join()}
                  onClick={() => patch({ colour })}
                  className={cn('size-7 rounded-full border-2', colour.join() === climate.colour.join() ? 'border-foreground' : 'border-transparent')}
                  style={{ background: rgb(colour) }}
                />
              ))}
            </div>
          </Field>

          <Field label={`Day · ${climate.temperature.day}°C`}>
            <Slider value={[climate.temperature.day]} min={-30} max={50} step={1}
              onValueChange={([day]) => patch({ temperature: { ...climate.temperature, day } })} />
          </Field>

          <Field label={`Night · ${climate.temperature.night}°C`}>
            <Slider value={[climate.temperature.night]} min={-30} max={50} step={1}
              onValueChange={([night]) => patch({ temperature: { ...climate.temperature, night } })} />
          </Field>

          <Field label={`Humidity · ${climate.humidity}%`}>
            <Slider value={[climate.humidity]} min={0} max={100} step={1} onValueChange={([humidity]) => patch({ humidity })} />
          </Field>

          <Field label={`Weather lasts · ${climate.duration[0]}–${climate.duration[1]} min`}>
            <Slider value={climate.duration} min={5} max={120} step={5} minStepsBetweenThumbs={0}
              onValueChange={([low, high]) => patch({ duration: [low, high] })} />
          </Field>

          <Field label={`Wind · ${climate.wind.toFixed(1)}×`}>
            <Slider value={[climate.wind]} min={0} max={3} step={0.1} onValueChange={([wind]) => patch({ wind })} />
          </Field>

          <div className="flex items-center justify-between gap-3">
            <span className="text-sm font-semibold">Holiday weather</span>
            <Switch checked={climate.seasons} onCheckedChange={(seasons) => patch({ seasons })} />
          </div>

          <div className="flex flex-col gap-3 rounded-md bg-surface p-3">
            <span className="text-sm font-semibold">Weather odds</span>

            {weathers.map(({ name, label }) => {
              const weight = climate.weathers[name] ?? 0

              return (
                <div key={name} className="flex items-center gap-3">
                  <WeatherIcon weather={name} className="size-4 text-muted-foreground" />
                  <span className="w-24 shrink-0 truncate text-xs font-semibold">{label}</span>
                  <Slider value={[weight]} min={0} max={100} step={1}
                    onValueChange={([value]) => patch({ weathers: { ...climate.weathers, [name]: value } })} />
                  <span className={cn('w-9 shrink-0 text-right text-xs font-semibold', weight ? '' : 'text-faint')}>
                    {share(weight)}%
                  </span>
                </div>
              )
            })}
          </div>
        </div>
      </ScrollArea>

      <div className="flex items-center gap-2 border-t border-border p-3">
        <Button className="flex-1" disabled={total === 0 || climate.label.trim() === ''} onClick={() => void fetchNui('saveClimate', climate)}>
          <Save />
          Save climate
        </Button>

        {climate.id && (
          <Button
            variant="destructive"
            size="icon"
            disabled={used > 0}
            title={used > 0 ? `Used by ${used} region${used === 1 ? '' : 's'}` : 'Delete this climate'}
            onClick={() => {
              void fetchNui('deleteClimate', { id: climate.id })
              clear()
            }}
          >
            <Trash2 />
          </Button>
        )}
      </div>
    </div>
  )
}

export function Climates() {
  const climates = useStore((state) => state.data.climates)
  const newClimate = useStore((state) => state.newClimate)

  return (
    <div className="flex min-h-0 flex-1 flex-col gap-4 p-5">
      <PageHeader title="Climates">
        <Button onClick={newClimate}>
          <Plus />
          New climate
        </Button>
      </PageHeader>

      <div className="flex min-h-0 flex-1 gap-3">
        <ScrollArea className="min-h-0 flex-1">
          <div className="grid grid-cols-2 gap-3 pr-2">
            {climates.map((climate) => <ClimateCard key={climate.id} climate={climate} />)}
          </div>
        </ScrollArea>

        <ClimateEditor />
      </div>
    </div>
  )
}
