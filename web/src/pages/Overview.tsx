import { useEffect, useRef } from 'react'
import L from 'leaflet'
import { WeatherSelect } from '@/components/WeatherSelect'
import { createMap, drawPlayer, drawRegions, escape } from '@/lib/map'
import { rgb } from '@/lib/utils'
import { findClimate, useStore } from '@/store'

/** Roughly how much room a label takes, in pixels. */
const LABEL = { width: 170, height: 52 }

/** The whole state at a glance: every region, its weather, and where you are. */
export function Overview() {
  const holder = useRef<HTMLDivElement>(null)
  const mapRef = useRef<L.Map | null>(null)
  const layers = useRef<{ regions?: L.FeatureGroup; labels?: L.LayerGroup; player?: L.LayerGroup }>({})
  const fitted = useRef(false)
  const placeLabels = useRef(() => {})

  const { map: config, regions, climates, live, current, player } = useStore((state) => state.data)
  const edit = useStore((state) => state.edit)

  useEffect(() => {
    if (!holder.current || mapRef.current || !config.tiles) return

    const { map } = createMap(holder.current, config, player, { zoomSnap: 0.25 })

    layers.current = {
      regions: L.featureGroup().addTo(map),
      labels: L.layerGroup().addTo(map),
      player: L.layerGroup().addTo(map)
    }
    mapRef.current = map
    map.on('zoomend', () => placeLabels.current())

    return () => {
      map.remove()
      mapRef.current = null
      fitted.current = false
    }
  }, [config.tiles])

  const regionKey = JSON.stringify([regions, live, current])

  useEffect(() => {
    const { regions: shapes, labels } = layers.current
    if (!shapes || !labels) return

    drawRegions(shapes, regions, climates, live, { highlight: current, onClick: edit })

    if (!fitted.current && shapes.getLayers().length > 0) {
      mapRef.current?.fitBounds(shapes.getBounds(), { padding: [40, 40] })
      fitted.current = true
    }

    placeLabels.current = () => {
      const map = mapRef.current
      if (!map) return

      labels.clearLayers()

      // Nested regions share a centre, so the winner is placed first and anything
      // that would sit on top of a placed label moves down until it is clear.
      const placed: L.Point[] = []

      regions
        .filter((region) => region.shape !== 'global' && region.coords && region.enabled !== false)
        .sort((a, b) => (b.priority ?? 0) - (a.priority ?? 0))
        .forEach((region) => {
          const origin = map.latLngToContainerPoint([region.coords!.y, region.coords!.x])
          const clear = (p: L.Point) =>
            !placed.some((other) => Math.abs(other.x - p.x) < LABEL.width && Math.abs(other.y - p.y) < LABEL.height)

          // Try just above, then just below, then further out, so it stays in its own region.
          let point = origin

          for (let step = 1; !clear(point) && step <= 12; step++) {
            const distance = Math.ceil(step / 2) * LABEL.height
            point = origin.add([0, step % 2 === 1 ? -distance : distance])
          }

          placed.push(point)

          const sky = live[region.id]
          const tone = rgb(findClimate(climates, region.climate)?.colour)
          const detail = sky ? `${Math.round(sky.temperature)}° · ${sky.label}` : ''

          L.marker(map.containerPointToLatLng(point), {
            icon: L.divIcon({
              className: '',
              iconSize: [0, 0],
              html: `<div class="dw-label${region.id === current ? ' is-here' : ''}" style="--tone:${tone}">
                <strong>${escape(region.label)}</strong><span>${escape(detail)}</span></div>`
            })
          })
            .on('click', () => edit(region.id))
            .addTo(labels)
        })
    }

    placeLabels.current()
  }, [regionKey, climates])

  useEffect(() => {
    if (layers.current.player) drawPlayer(layers.current.player, player)
  }, [player.x, player.y])

  return (
    <div className="relative min-h-0 flex-1" style={{ background: config.background }}>
      <div ref={holder} className="size-full" />

      <div className="absolute right-4 top-4 z-[600] w-60">
        <WeatherSelect regionId="*" placeholder="Weather everywhere" className="h-10 bg-surface" />
      </div>
    </div>
  )
}
