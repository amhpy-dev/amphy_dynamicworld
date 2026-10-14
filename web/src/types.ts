export type Point = { x: number; y: number; z?: number }

/** `global` is the one default region: everywhere no other region covers. */
export type RegionShape = 'circle' | 'poly' | 'global'

export type Region = {
  id: string
  label: string
  climate: string
  shape: RegionShape
  coords?: { x: number; y: number; z?: number }
  radius?: number
  points?: Point[]
  priority?: number
  floor?: number
  enabled?: boolean
}

export type Climate = {
  id: string
  label: string
  colour: number[]
  weathers: Record<string, number>
  temperature: { day: number; night: number }
  humidity: number
  duration: [number, number]
  wind: number
  seasons: boolean
}

export type WeatherOption = { name: string; label: string }

export type LiveWeather = {
  weather: string
  label: string
  temperature: number
  forced: boolean
  blackout: boolean
  ends?: number
}

/** What DW.getConditions() returns for where the player is standing. */
export type Conditions = {
  region: string
  label?: string
  climate: string
  weather: string
  weatherLabel: string
  temperature: number
  feelsLike: number
  humidity: number
  band: string
  windSpeed: number
  time: { hour: number; minute: number }
  isNight: boolean
  forced: boolean
  ends?: number
  blackout: boolean
  synced: boolean
}

export type MapConfig = {
  tiles: string
  emptyTile?: string
  minZoom: number
  maxZoom: number
  zoom: number
  background: string
  centreX: number
  centreY: number
  scaleX: number
  scaleY: number
}

export type EditorData = {
  regions: Region[]
  climates: Climate[]
  weathers: WeatherOption[]
  live: Record<string, LiveWeather>
  current: string
  here?: Conditions
  blackout: boolean
  season: string | false
  frozen: boolean
  map: MapConfig
  limits: { minRadius: number; maxRadius: number }
  player: { x: number; y: number; z: number }
}

export type PlacementResult = {
  coords: { x: number; y: number; z: number }
  radius?: number
  points?: Point[]
}

/** A shape being drawn on the map, corner by corner. */
export type Drawing = {
  climate: string
  colour: number[]
  points: Point[]
  regionId?: string
}

export type Page = 'overview' | 'regions' | 'climates'
