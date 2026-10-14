import { useEffect, useState } from 'react'
import { Clock, LayoutDashboard, Map, Thermometer, X, Zap, type LucideIcon } from 'lucide-react'
import { WeatherIcon, untilChange } from '@/lib/weather'
import { fetchNui } from '@/lib/nui'
import { cn } from '@/lib/utils'
import { useStore } from '@/store'
import type { Page } from '@/types'

const WIDTH = 1550
const HEIGHT = 850

/** The tablet is drawn at a fixed size and scaled to fit smaller screens. */
function useFit() {
  const measure = () => Math.min(1, (window.innerWidth - 32) / WIDTH, (window.innerHeight - 32) / HEIGHT)
  const [scale, setScale] = useState(measure)

  useEffect(() => {
    const onResize = () => setScale(measure())
    window.addEventListener('resize', onResize)
    return () => window.removeEventListener('resize', onResize)
  }, [])

  return scale
}

const pad = (value: number) => String(value).padStart(2, '0')

function StatusRow({ onClose }: { onClose: () => void }) {
  const here = useStore((state) => state.data.here)

  return (
    <div className="flex h-7 shrink-0 items-center justify-between px-2 text-sm font-medium">
      <span>{here ? `${pad(here.time.hour)}:${pad(here.time.minute)}` : '--:--'}</span>

      <div className="flex items-center gap-3">
        {here && (
          <span className="flex items-center gap-1.5">
            <WeatherIcon weather={here.weather} />
            {here.weatherLabel}
          </span>
        )}
        <button onClick={onClose} title="Close (Esc)" className="grid size-6 place-items-center rounded-sm hover:bg-raised">
          <X className="size-4" />
        </button>
      </div>
    </div>
  )
}

const PAGES: { id: Page; label: string; icon: LucideIcon }[] = [
  { id: 'overview', label: 'Overview', icon: LayoutDashboard },
  { id: 'regions', label: 'Regions', icon: Map },
  { id: 'climates', label: 'Climates', icon: Thermometer }
]

function Navigation() {
  const page = useStore((state) => state.page)
  const setPage = useStore((state) => state.setPage)

  return (
    <nav className="flex min-h-0 flex-1 flex-col gap-2 rounded-md bg-surface p-2">
      {PAGES.map(({ id, label, icon: Icon }) => (
        <button
          key={id}
          onClick={() => setPage(id)}
          className={cn(
            'flex h-[70px] shrink-0 items-center gap-4 rounded-md border px-5 text-left text-2xl font-semibold transition-colors',
            page === id ? 'border-primary bg-primary-half' : 'border-transparent bg-background hover:border-border'
          )}
        >
          <Icon className="size-[26px] shrink-0" strokeWidth={1.75} />
          {label}
        </button>
      ))}
    </nav>
  )
}

function Row({ icon: Icon, label, children }: { icon: LucideIcon; label: string; children: React.ReactNode }) {
  return (
    <div className="flex h-14 shrink-0 items-center gap-4 rounded-md bg-background pl-5 pr-2.5">
      <Icon className="size-[22px] shrink-0 text-muted-foreground" strokeWidth={1.75} />
      <span className="flex-1 text-lg font-semibold">{label}</span>
      {children}
    </div>
  )
}

const chip = 'flex h-9 w-20 items-center justify-center rounded-sm bg-surface text-lg font-semibold'

function Summary() {
  const { here, blackout } = useStore((state) => state.data)
  if (!here) return null

  const change = here.forced ? 'Held' : untilChange(here.ends)?.replace('in ', '').replace(' min', 'm') ?? '-'

  return (
    <div className="flex shrink-0 flex-col gap-2 rounded-md bg-surface p-2">
      <Row icon={Thermometer} label="Temperature">
        <span className={chip}>{Math.round(here.temperature)}°</span>
      </Row>
      <Row icon={Clock} label="Next change">
        <span className={chip}>{change}</span>
      </Row>
      <Row icon={Zap} label="City power">
        <button
          title="Toggle the blackout everywhere"
          onClick={() => void fetchNui('setRegionBlackout', { id: '*', state: !blackout })}
          className={cn(chip, 'hover:bg-raised', blackout ? 'text-destructive' : 'text-success')}
        >
          {blackout ? 'Off' : 'On'}
        </button>
      </Row>
    </div>
  )
}

export function Shell({ onClose, children }: { onClose: () => void; children: React.ReactNode }) {
  const scale = useFit()

  return (
    <div className="fixed inset-0 grid place-items-center bg-overlay">
      {/* A transform does not shrink the layout box, so size the slot to the scaled tablet. */}
      <div style={{ width: WIDTH * scale, height: HEIGHT * scale }}>
        <div
          className="relative origin-top-left rounded-xl border px-[25px] py-8"
          style={{
            width: WIDTH,
            height: HEIGHT,
            transform: `scale(${scale})`,
            borderColor: '#202020',
            background: 'linear-gradient(180deg, rgba(0,0,0,0.2) 0%, rgba(45,45,45,0.18) 10%, rgba(45,45,45,0.03) 83%, rgba(13,13,13,0) 100%), #1f1f1f',
            boxShadow: '0 50px 100px rgba(0, 0, 0, 0.5)'
          }}
        >
          <div className="flex size-full bg-background">
            <aside className="flex w-[324px] shrink-0 flex-col gap-2.5 p-2.5">
              <StatusRow onClose={onClose} />
              <Navigation />
              <Summary />
            </aside>

            <main className="relative flex min-w-0 flex-1 flex-col gap-4 overflow-hidden bg-surface">{children}</main>
          </div>

          <span className="absolute bottom-[3px] left-1/2 -translate-x-1/2 text-xl font-bold tracking-[0.3em] text-faint">
            AMPHY
          </span>
        </div>
      </div>
    </div>
  )
}
