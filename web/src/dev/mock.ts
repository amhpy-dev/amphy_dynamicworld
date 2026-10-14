// Browser-only stand-in for the game, so `bun dev` shows the panel. Never bundled
// into a build: main.tsx only imports it when Vite is serving in dev mode.
import type { EditorData, LiveWeather, Region } from '@/types'

const now = Date.now() / 1000

const poly = (pairs: number[][]) => pairs.map(([x, y]) => ({ x, y }))

const regions: Region[] = [
  { id: 'default', label: 'San Andreas', climate: 'temperate', shape: 'global' },
  {
    id: 'los_santos', label: 'Los Santos', climate: 'temperate', priority: 10, shape: 'poly', enabled: true,
    coords: { x: -300, y: -1100 },
    points: poly([[-3400, 1500], [1200, 1500], [2500, 700], [2900, -1300], [1800, -3000], [800, -3900], [-1600, -3900], [-2700, -1800], [-3400, -300]])
  },
  {
    id: 'grand_senora', label: 'Grand Senora Desert', climate: 'desert', priority: 10, shape: 'poly', enabled: true,
    coords: { x: 1700, y: 3000 },
    points: poly([[0, 2300], [1300, 1700], [2700, 1500], [3700, 2300], [3800, 3700], [2600, 4100], [1500, 4300], [400, 3600], [-300, 3000]])
  },
  {
    id: 'blaine_north', label: 'North Blaine', climate: 'coastal', priority: 10, shape: 'poly', enabled: true,
    coords: { x: 700, y: 5700 },
    points: poly([[-3200, 4200], [-200, 3700], [1500, 4300], [2600, 4100], [3900, 4300], [4100, 6800], [1800, 7600], [-600, 7800], [-2400, 6200]])
  },
  { id: 'mount_chiliad', label: 'Mount Chiliad', climate: 'alpine', priority: 20, shape: 'circle', coords: { x: 500, y: 5600 }, radius: 900, floor: 300, enabled: true },
  { id: 'cayo_perico', label: 'Cayo Perico', climate: 'tropical', priority: 10, shape: 'circle', coords: { x: 4900, y: -5100 }, radius: 1600, enabled: true }
]

const labels: Record<string, string> = {
  EXTRASUNNY: 'Extra sunny', CLEAR: 'Clear', NEUTRAL: 'Neutral', SMOG: 'Smog', FOGGY: 'Foggy',
  OVERCAST: 'Overcast', CLOUDS: 'Cloudy', CLEARING: 'Clearing', RAIN: 'Rain', THUNDER: 'Thunderstorm',
  SNOWLIGHT: 'Light snow', SNOW: 'Snow', BLIZZARD: 'Blizzard', XMAS: 'Deep snow', HALLOWEEN: 'Halloween'
}

const sky = (weather: string, temperature: number, extra: Partial<LiveWeather> = {}): LiveWeather => ({
  weather, label: labels[weather], temperature, forced: false, blackout: false, ends: now + 60 * 18, ...extra
})

const data: EditorData = {
  regions,
  climates: [
    { id: 'alpine', label: 'Alpine', colour: [120, 190, 255],
      weathers: { SNOWLIGHT: 24, SNOW: 16, BLIZZARD: 4, OVERCAST: 18, CLOUDS: 12, FOGGY: 6, CLEAR: 14, CLEARING: 6 },
      temperature: { day: 2, night: -9 }, humidity: 60, duration: [15, 35], wind: 1.5, seasons: true },
    { id: 'coastal', label: 'Coastal forest', colour: [38, 198, 180],
      weathers: { CLEAR: 14, CLOUDS: 22, OVERCAST: 22, FOGGY: 16, RAIN: 16, THUNDER: 2, CLEARING: 8 },
      temperature: { day: 17, night: 9 }, humidity: 80, duration: [20, 40], wind: 1.3, seasons: true },
    { id: 'desert', label: 'Desert', colour: [255, 138, 76],
      weathers: { EXTRASUNNY: 50, CLEAR: 32, CLOUDS: 7, SMOG: 4, CLEARING: 3, OVERCAST: 2, THUNDER: 2 },
      temperature: { day: 36, night: 19 }, humidity: 22, duration: [30, 60], wind: 1.2, seasons: true },
    { id: 'temperate', label: 'Temperate', colour: [102, 187, 106],
      weathers: { EXTRASUNNY: 22, CLEAR: 30, CLOUDS: 16, OVERCAST: 9, CLEARING: 6, SMOG: 7, FOGGY: 4, RAIN: 5, THUNDER: 1 },
      temperature: { day: 24, night: 14 }, humidity: 62, duration: [20, 40], wind: 1, seasons: true },
    { id: 'tropical', label: 'Tropical', colour: [240, 98, 146],
      weathers: { EXTRASUNNY: 30, CLEAR: 26, CLOUDS: 18, OVERCAST: 6, RAIN: 12, THUNDER: 6, CLEARING: 2 },
      temperature: { day: 31, night: 24 }, humidity: 76, duration: [15, 30], wind: 0.9, seasons: false }
  ],
  weathers: Object.entries(labels).map(([name, label]) => ({ name, label })),
  live: {
    default: sky('CLOUDS', 22.6),
    los_santos: sky('CLEAR', 23.8, { forced: true, ends: 9999999999 }),
    grand_senora: sky('EXTRASUNNY', 37.9),
    blaine_north: sky('FOGGY', 14.1, { blackout: true }),
    mount_chiliad: sky('SNOWLIGHT', 0.4),
    cayo_perico: sky('RAIN', 26.8)
  },
  current: 'grand_senora',
  here: {
    region: 'grand_senora', label: 'Grand Senora Desert', climate: 'desert', weather: 'EXTRASUNNY',
    weatherLabel: 'Extra sunny', temperature: 37.9, feelsLike: 37.9, humidity: 12, band: 'hot', windSpeed: 0.3,
    time: { hour: 14, minute: 37 }, isNight: false, forced: false, ends: now + 60 * 18, blackout: false, synced: true
  },
  blackout: false,
  season: false,
  frozen: false,
  map: {
    tiles: '/mapStyles/dark/{z}/{x}/{y}.jpg', emptyTile: '/mapStyles/dark/empty.jpg', minZoom: 0, maxZoom: 5, zoom: 2,
    background: '#132b43', centreX: 117.3, centreY: 172.8, scaleX: 0.02072, scaleY: 0.0205
  },
  limits: { minRadius: 25, maxRadius: 4000 },
  player: { x: 1850, y: 3700, z: 33 }
}

const open = () => window.postMessage({ action: 'open', data }, '*')

/** Open the panel, and open it again a moment after it is closed. */
export function start() {
  document.body.style.background = '#5a5f66'
  open()

  window.addEventListener('dev:nui', ((event: CustomEvent<{ name: string; data: unknown }>) => {
    console.info('[nui]', event.detail.name, event.detail.data)
    if (event.detail.name === 'close') setTimeout(open, 1000)
  }) as EventListener)
}
