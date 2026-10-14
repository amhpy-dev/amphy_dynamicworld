import { Circle, Crosshair, Globe, MapPin, Navigation, Pentagon, Save, Trash2 } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Slider } from '@/components/ui/slider'
import { Switch } from '@/components/ui/switch'
import { Separator } from '@/components/ui/separator'
import { ScrollArea } from '@/components/ui/scroll-area'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from '@/components/ui/select'
import { WeatherSelect } from '@/components/WeatherSelect'
import { Field, Pill } from '@/components/kit'
import { useStore } from '@/store'
import { fetchNui } from '@/lib/nui'
import { WeatherIcon, untilChange, weatherTone } from '@/lib/weather'
import { rgb, round } from '@/lib/utils'
import type { LiveWeather } from '@/types'

/** What the region is doing right now, and the controls to change it. */
function LiveSky({ regionId, sky }: { regionId: string; sky: LiveWeather }) {
  const change = untilChange(sky.ends)

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-surface p-3">
      <div className="flex items-center gap-3">
        <span className="grid size-10 shrink-0 place-items-center rounded-md bg-raised">
          <WeatherIcon weather={sky.weather} className="size-5" />
        </span>
        <div className="min-w-0 flex-1">
          <p className="flex items-center gap-2 text-base font-semibold">
            {Math.round(sky.temperature)}°C <Pill tone={weatherTone(sky.weather)}>{sky.label}</Pill>
          </p>
          <p className="text-xs font-medium text-muted-foreground">
            {sky.forced ? 'Held until set back to auto' : change ? `Changes ${change}` : 'Holding'}
          </p>
        </div>
      </div>

      <WeatherSelect regionId={regionId} placeholder="Change the weather" />

      <div className="flex items-center justify-between gap-3">
        <div className="flex flex-col gap-0.5">
          <p className="text-sm font-semibold">Power cut</p>
          <p className="text-xs font-medium leading-snug text-muted-foreground">
            Lights out in this region.
          </p>
        </div>
        <Switch
          checked={sky.blackout}
          onCheckedChange={(state) => void fetchNui('setRegionBlackout', { id: regionId, state })}
        />
      </div>
    </div>
  )
}

export function Inspector() {
  const draft = useStore((state) => state.draft)
  const { climates, limits, player, live } = useStore((state) => state.data)
  const patch = useStore((state) => state.patch)
  const clearDraft = useStore((state) => state.clearDraft)
  const startDrawing = useStore((state) => state.startDrawing)

  if (!draft) {
    return (
      <div className="flex w-[320px] shrink-0 flex-col items-center justify-center gap-2 rounded-md border border-border bg-card p-8 text-center">
        <MapPin className="size-5 text-muted-foreground" />
        <p className="text-base font-semibold">Nothing selected</p>
        <p className="text-xs font-medium leading-relaxed text-muted-foreground">
          Pick a region from the list or the map to edit it, or add a new one.
        </p>
      </div>
    )
  }

  const global = draft.shape === 'global'
  const poly = draft.shape === 'poly'
  const sky = live[draft.id]
  const priority = draft.priority ?? 10
  const radius = draft.radius ?? 500
  const hasFloor = draft.floor !== undefined

  const climateField = (
    <Field label="Climate">
      <Select value={draft.climate} onValueChange={(value) => patch({ climate: value })}>
        <SelectTrigger>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {climates.map((entry) => (
            <SelectItem key={entry.id} value={entry.id}>
              <span className="flex items-center gap-2">
                <span className="size-2.5 rounded-full" style={{ background: rgb(entry.colour) }} />
                {entry.label}
              </span>
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </Field>
  )

  return (
    <div className="flex w-[320px] shrink-0 flex-col overflow-hidden rounded-md border border-border bg-card">
      <ScrollArea className="flex-1">
        <div className="flex flex-col gap-5 p-4">
          {global && (
            <div className="flex items-start gap-2.5 rounded-md bg-surface p-3">
              <Globe className="mt-0.5 size-4 shrink-0 text-muted-foreground" />
              <p className="text-xs font-medium leading-relaxed text-muted-foreground">
                The default region: the open sea and any gap between your borders. It has no
                shape, so it can be renamed and given a climate but not moved or deleted.
              </p>
            </div>
          )}

          <Field label="Name">
            <Input
              value={draft.label}
              onChange={(event) => patch({ label: event.target.value })}
              placeholder="Grand Senora Desert"
              maxLength={20}
            />
          </Field>

          {climateField}

          {sky && <LiveSky regionId={draft.id} sky={sky} />}

          {!global && (
            <>
              <Separator />

              <Field label="Shape">
                <div className="grid grid-cols-2 gap-2">
                  <Button
                    variant={poly ? 'secondary' : 'default'}
                    onClick={() => patch({ shape: 'circle', radius })}
                  >
                    <Circle />
                    Circle
                  </Button>
                  <Button
                    variant={poly ? 'default' : 'secondary'}
                    onClick={() => {
                      patch({ shape: 'poly' })
                      if (!draft.points || draft.points.length < 3) startDrawing(draft.climate, draft.id)
                    }}
                  >
                    <Pentagon />
                    Polygon
                  </Button>
                </div>
              </Field>

              {!poly && (
                <Field label={`Radius · ${Math.round(radius)}m`}>
                  <Slider
                    value={[radius]}
                    min={limits.minRadius}
                    max={limits.maxRadius}
                    step={10}
                    onValueChange={([value]) => patch({ radius: value })}
                  />
                </Field>
              )}

              <Field
                label={`Priority · ${Math.round(priority)}`}
                hint="Higher wins where regions overlap."
              >
                <Slider
                  value={[priority]}
                  min={0}
                  max={100}
                  step={1}
                  onValueChange={([value]) => patch({ priority: value })}
                />
              </Field>

              <div className="flex flex-col gap-3 rounded-md bg-surface p-3">
                <div className="flex items-start justify-between gap-3">
                  <div className="flex flex-col gap-0.5">
                    <p className="text-sm font-semibold">Altitude floor</p>
                    <p className="text-xs font-medium leading-snug text-muted-foreground">
                      Only applies above this height.
                    </p>
                  </div>
                  <Switch
                    checked={hasFloor}
                    onCheckedChange={(checked) =>
                      patch({ floor: checked ? Math.round(player.z) : undefined })
                    }
                  />
                </div>

                {hasFloor && (
                  <>
                    <Slider
                      value={[draft.floor ?? 0]}
                      min={-50}
                      max={1500}
                      step={5}
                      onValueChange={([value]) => patch({ floor: value })}
                    />
                    <div className="flex justify-between text-[11px] font-medium text-muted-foreground">
                      <span>above {Math.round(draft.floor ?? 0)}m</span>
                      <span>you are at {Math.round(player.z)}m</span>
                    </div>
                  </>
                )}
              </div>

              <Separator />

              {!poly && (
                <Field label="Centre">
                  <div className="grid grid-cols-2 gap-2">
                    {(['x', 'y'] as const).map((axis) => (
                      <Input
                        key={axis}
                        type="number"
                        value={round(draft.coords?.[axis])}
                        onChange={(event) =>
                          patch({
                            coords: {
                              x: draft.coords?.x ?? 0,
                              y: draft.coords?.y ?? 0,
                              [axis]: Number(event.target.value)
                            }
                          })
                        }
                      />
                    ))}
                  </div>
                  <Button
                    variant="secondary"
                    size="sm"
                    className="w-full"
                    onClick={() => patch({ coords: { x: player.x, y: player.y } })}
                  >
                    <Navigation />
                    Use my position
                  </Button>
                </Field>
              )}

              <Field label="Placement">
                <div className="grid gap-2">
                  {poly ? (
                    <>
                      <Button variant="secondary" onClick={() => startDrawing(draft.climate, draft.id)}>
                        <Pentagon />
                        Redraw on the map
                      </Button>
                      <Button
                        variant="secondary"
                        onClick={() =>
                          void fetchNui('placeRegion', { climate: draft.climate, polygon: true })
                        }
                      >
                        <Crosshair />
                        Walk the corners in game
                      </Button>
                    </>
                  ) : (
                    <Button
                      variant="secondary"
                      onClick={() =>
                        void fetchNui('placeRegion', { climate: draft.climate, radius })
                      }
                    >
                      <Crosshair />
                      Aim and place in game
                    </Button>
                  )}

                  {draft.coords && (
                    <Button variant="secondary" onClick={() => void fetchNui('teleport', draft.coords)}>
                      <MapPin />
                      Teleport to the middle
                    </Button>
                  )}
                </div>
              </Field>
            </>
          )}
        </div>
      </ScrollArea>

      <div className="flex items-center gap-2 border-t border-border p-3">
        <Button
          className="flex-1"
          disabled={poly && (!draft.points || draft.points.length < 3)}
          onClick={() => void fetchNui('saveRegion', draft)}
        >
          <Save />
          Save region
        </Button>
        {!global && (
          <Button
            variant="destructive"
            size="icon"
            title="Delete this region"
            onClick={() => {
              void fetchNui('deleteRegion', { id: draft.id })
              clearDraft()
            }}
          >
            <Trash2 />
          </Button>
        )}
      </div>
    </div>
  )
}
