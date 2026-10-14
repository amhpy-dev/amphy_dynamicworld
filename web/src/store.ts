import { create } from 'zustand'
import type { Climate, Drawing, EditorData, Page, Point, Region, RegionShape } from './types'

export const DEFAULT_ID = 'default'

const emptyData: EditorData = {
  regions: [],
  climates: [],
  weathers: [],
  live: {},
  current: DEFAULT_ID,
  blackout: false,
  season: false,
  frozen: false,
  map: {
    tiles: '',
    minZoom: 0,
    maxZoom: 5,
    zoom: 2,
    background: '#0fa8d2',
    centreX: 117.3,
    centreY: 172.8,
    scaleX: 0.02072,
    scaleY: 0.0205
  },
  limits: { minRadius: 25, maxRadius: 4000 },
  player: { x: 0, y: 0, z: 0 }
}

/** An empty Lua table arrives as {} rather than [], so never trust the shape. */
const asArray = <T,>(value: unknown): T[] => (Array.isArray(value) ? (value as T[]) : [])

const asRecord = <T,>(value: unknown): Record<string, T> =>
  value && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, T>) : {}

export const findClimate = (climates: Climate[], id: string | undefined) =>
  climates.find((climate) => climate.id === id) ?? climates[0]

export const centroid = (points: Point[]) => {
  const sum = points.reduce((acc, p) => ({ x: acc.x + p.x, y: acc.y + p.y }), { x: 0, y: 0 })

  return { x: sum.x / points.length, y: sum.y / points.length }
}

type State = {
  page: Page
  setPage: (page: Page) => void
  edit: (id: string) => void

  open: boolean
  hidden: boolean
  data: EditorData
  draft: Region | null
  drawing: Drawing | null
  search: string

  setData: (data: EditorData) => void
  setOpen: (open: boolean) => void
  setHidden: (hidden: boolean) => void
  setSearch: (search: string) => void

  select: (id: string) => void
  create: (climateId: string, shape: Exclude<RegionShape, 'global'>, coords?: Region['coords']) => Region
  patch: (patch: Partial<Region>) => void
  clearDraft: () => void

  climate: Climate | null
  selectClimate: (id: string) => void
  newClimate: () => void
  patchClimate: (patch: Partial<Climate>) => void
  clearClimate: () => void

  startDrawing: (climateId: string, regionId?: string) => void
  addVertex: (x: number, y: number) => void
  undoVertex: () => void
  cancelDrawing: () => void
  finishDrawing: () => Region | null
}

export const useStore = create<State>((set, get) => ({
  page: 'overview',
  setPage: (page) => set({ page, drawing: null }),
  edit: (id) => {
    set({ page: 'regions' })
    get().select(id)
  },

  open: false,
  hidden: false,
  data: emptyData,
  draft: null,
  drawing: null,
  search: '',

  setData: (data) =>
    set({
      data: {
        ...data,
        regions: asArray<Region>(data.regions),
        climates: asArray<Climate>(data.climates),
        weathers: asArray(data.weathers),
        live: asRecord(data.live)
      }
    }),

  setOpen: (open) => set({ open, ...(open ? {} : { draft: null, climate: null, drawing: null, search: '', page: 'overview' }) }),
  setHidden: (hidden) => set({ hidden }),
  setSearch: (search) => set({ search }),

  climate: null,

  selectClimate: (id) => {
    const climate = get().data.climates.find((entry) => entry.id === id)
    if (climate) set({ climate: structuredClone(climate) })
  },

  newClimate: () =>
    set({
      climate: {
        id: '',
        label: 'New climate',
        colour: [120, 190, 255],
        weathers: { CLEAR: 40, CLOUDS: 30, OVERCAST: 15, RAIN: 15 },
        temperature: { day: 22, night: 12 },
        humidity: 55,
        duration: [20, 40],
        wind: 1,
        seasons: true
      }
    }),

  patchClimate: (patch) => set((state) => (state.climate ? { climate: { ...state.climate, ...patch } } : state)),
  clearClimate: () => set({ climate: null }),

  select: (id) => {
    const region = get().data.regions.find((entry) => entry.id === id)
    if (region) set({ draft: { ...region }, drawing: null })
  },

  create: (climateId, shape, coords) => {
    const { data } = get()
    const climate = findClimate(data.climates, climateId)

    const region: Region = {
      id: `${climate?.id ?? 'region'}_${Date.now().toString(36)}`,
      label: climate?.label ?? 'New region',
      climate: climate?.id ?? climateId,
      shape,
      coords: coords ?? { x: data.player.x, y: data.player.y },
      radius: 500,
      priority: 10,
      enabled: true
    }

    set({ draft: region })
    return region
  },

  patch: (patch) => set((state) => (state.draft ? { draft: { ...state.draft, ...patch } } : state)),
  clearDraft: () => set({ draft: null }),

  startDrawing: (climateId, regionId) => {
    const climate = findClimate(get().data.climates, climateId)
    set({
      drawing: { climate: climate?.id ?? climateId, colour: climate?.colour ?? [255, 255, 255], points: [], regionId }
    })
  },

  addVertex: (x, y) =>
    set((state) => {
      if (!state.drawing) return state

      // A double-click to finish lands two clicks on the same spot first.
      const last = state.drawing.points[state.drawing.points.length - 1]
      if (last && Math.hypot(last.x - x, last.y - y) < 5) return state

      return { drawing: { ...state.drawing, points: [...state.drawing.points, { x, y }] } }
    }),

  undoVertex: () =>
    set((state) =>
      state.drawing
        ? { drawing: { ...state.drawing, points: state.drawing.points.slice(0, -1) } }
        : state
    ),

  cancelDrawing: () => set({ drawing: null }),

  finishDrawing: () => {
    const { drawing, draft } = get()
    if (!drawing || drawing.points.length < 3) return null

    const coords = centroid(drawing.points)

    // Redrawing an existing region keeps everything but its shape.
    const base =
      drawing.regionId && draft?.id === drawing.regionId
        ? draft
        : get().create(drawing.climate, 'poly', coords)

    const region: Region = { ...base, shape: 'poly', points: drawing.points, coords }

    set({ draft: region, drawing: null })
    return region
  }
}))
