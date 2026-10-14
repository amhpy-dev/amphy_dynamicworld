import { useEffect, useRef, useState } from 'react'
import L from 'leaflet'
import { AlertTriangle } from 'lucide-react'
import { DrawingBar } from '@/components/DrawingBar'
import { useStore } from '@/store'
import { fetchNui } from '@/lib/nui'
import { createMap, drawPlayer, drawRegions, toLatLngs } from '@/lib/map'
import { rgb } from '@/lib/utils'

/** The editing map: click a region to select it, draw corners, shift-click to move. */
export function RegionMap() {
  const holder = useRef<HTMLDivElement>(null)
  const mapRef = useRef<L.Map | null>(null)
  const layers = useRef<{ regions?: L.LayerGroup; draft?: L.LayerGroup; player?: L.LayerGroup }>({})

  const [cursor, setCursor] = useState<[number, number] | null>(null)
  const [noTiles, setNoTiles] = useState(false)

  const data = useStore((state) => state.data)
  const draft = useStore((state) => state.draft)
  const drawing = useStore((state) => state.drawing)

  // Leaflet listeners outlive renders, so they read the latest state from here.
  const live = useRef({ drawing, draft })
  live.current = { drawing, draft }

  const { map: config, regions, climates, player, live: weather } = data

  useEffect(() => {
    if (!holder.current || mapRef.current || !config.tiles) return

    const { map, tiles } = createMap(holder.current, config, player)
    let loaded = false

    tiles.on('tileload', () => {
      loaded = true
      setNoTiles(false)
    })
    tiles.on('tileerror', () => !loaded && setNoTiles(true))

    layers.current = {
      regions: L.layerGroup().addTo(map),
      draft: L.layerGroup().addTo(map),
      player: L.layerGroup().addTo(map)
    }

    map.on('mousemove', (event: L.LeafletMouseEvent) =>
      setCursor([Math.round(event.latlng.lng), Math.round(event.latlng.lat)])
    )

    map.on('click', (event: L.LeafletMouseEvent) => {
      const store = useStore.getState()
      const { lng: x, lat: y } = event.latlng

      if (live.current.drawing) return store.addVertex(x, y)

      const current = live.current.draft
      if (!current || current.shape === 'global') return

      if (!event.originalEvent.shiftKey) return store.clearDraft()

      const centre = current.coords ?? { x, y }
      store.patch({
        coords: { x, y },
        points: current.points?.map((point) => ({ x: point.x + x - centre.x, y: point.y + y - centre.y }))
      })
    })

    map.on('dblclick', () => {
      if (!live.current.drawing) return

      const region = useStore.getState().finishDrawing()
      if (region) void fetchNui('saveRegion', region)
    })

    mapRef.current = map

    return () => {
      map.remove()
      mapRef.current = null
    }
  }, [config.tiles])

  // The selected region is drawn from the draft, so edits show as you make them.
  const shown = draft
    ? regions.some((region) => region.id === draft.id)
      ? regions.map((region) => (region.id === draft.id ? draft : region))
      : [...regions, draft]
    : regions

  const regionKey = JSON.stringify([shown, weather])

  useEffect(() => {
    if (!layers.current.regions) return

    drawRegions(layers.current.regions, shown, climates, weather, {
      selected: draft?.id,
      onClick: (id) => !live.current.drawing && useStore.getState().select(id)
    })
  }, [regionKey, climates])

  useEffect(() => {
    const group = layers.current.draft
    if (!group) return

    group.clearLayers()
    if (!drawing) return

    const colour = rgb(drawing.colour)
    const points = drawing.points

    if (points.length >= 2) {
      L.polyline(toLatLngs(points.length >= 3 ? [...points, points[0]] : points), {
        color: colour,
        weight: 2,
        dashArray: '6 4',
        fill: points.length >= 3,
        fillColor: colour,
        fillOpacity: 0.15
      }).addTo(group)
    }

    points.forEach((point, index) => {
      L.circleMarker([point.y, point.x], {
        radius: index === 0 ? 6 : 4,
        color: colour,
        weight: 2,
        fillColor: '#f4f4f4',
        fillOpacity: 1
      }).addTo(group)
    })
  }, [drawing])

  useEffect(() => {
    if (layers.current.player) drawPlayer(layers.current.player, player)
  }, [player.x, player.y])

  const hint = drawing
    ? 'Click each corner · double-click to finish'
    : draft && draft.shape !== 'global'
      ? 'Shift-click to move the selected region'
      : 'Scroll to zoom · drag to pan · click a region'

  return (
    <div
      className="relative min-w-0 flex-1 overflow-hidden rounded-md border border-border"
      style={{ background: config.background }}
    >
      <div ref={holder} className="size-full" />

      <div className="absolute inset-x-3 top-3 z-500">
        <DrawingBar />
      </div>

      <div className="pointer-events-none absolute bottom-3 left-3 z-500 rounded-sm bg-surface px-2.5 py-1 text-xs font-medium">
        {cursor ? `X ${cursor[0]}  Y ${cursor[1]} · ${hint}` : hint}
      </div>

      {noTiles && (
        <div className="absolute inset-x-3 top-3 z-500 flex items-start gap-2 rounded-md border border-border bg-surface p-3 text-xs">
          <AlertTriangle className="mt-0.5 size-4 shrink-0 text-destructive" />
          <span>
            No map tiles found at <code>{config.tiles}</code>. Regions still place correctly; set{' '}
            <code>Config.Editor.map.tiles</code> to see the map.
          </span>
        </div>
      )}
    </div>
  )
}
