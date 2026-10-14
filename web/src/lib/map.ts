import L from 'leaflet'
import { findClimate } from '@/store'
import { rgb } from '@/lib/utils'
import type { Climate, LiveWeather, MapConfig, Point, Region } from '@/types'

/** Leaflet in world coordinates: lat is world Y, lng is world X. */
export function makeCrs(map: MapConfig) {
  return L.Util.extend({}, L.CRS.Simple, {
    projection: L.Projection.LonLat,
    scale: (zoom: number) => Math.pow(2, zoom),
    zoom: (scale: number) => Math.log(scale) / Math.LN2,
    distance: (a: L.LatLng, b: L.LatLng) => Math.hypot(b.lng - a.lng, b.lat - a.lat),
    transformation: new L.Transformation(map.scaleX, map.centreX, -map.scaleY, map.centreY),
    infinite: true
  }) as L.CRS
}

export const toLatLngs = (points: Point[]) => points.map((point) => [point.y, point.x] as L.LatLngTuple)

export function createMap(holder: HTMLElement, config: MapConfig, centre: Point, options: L.MapOptions = {}) {
  const map = L.map(holder, {
    crs: makeCrs(config),
    minZoom: config.minZoom,
    maxZoom: config.maxZoom,
    zoom: config.zoom,
    center: [centre.y, centre.x],
    zoomControl: false,
    attributionControl: false,
    doubleClickZoom: false,
    ...options
  })

  const tiles = L.tileLayer(config.tiles, {
    minZoom: config.minZoom,
    maxZoom: config.maxZoom,
    noWrap: true,
    errorTileUrl: config.emptyTile ?? ''
  }).addTo(map)

  setTimeout(() => map.invalidateSize(), 60)

  return { map, tiles }
}

export const escape = (text: string) => text.replace(/[&<>"']/g, (char) => `&#${char.charCodeAt(0)};`)

/** Bigger regions first, so a small one on top stays clickable. */
export function drawRegions(
  group: L.LayerGroup,
  regions: Region[],
  climates: Climate[],
  live: Record<string, LiveWeather>,
  options: { selected?: string; highlight?: string; onClick?: (id: string) => void } = {}
) {
  group.clearLayers()

  regions
    .filter((region) => region.shape !== 'global')
    .sort((a, b) => (a.priority ?? 0) - (b.priority ?? 0))
    .forEach((region) => {
      const climate = findClimate(climates, region.climate)
      const colour = rgb(climate?.colour)
      const strong = region.id === options.selected || region.id === options.highlight
      const off = region.enabled === false
      const sky = live[region.id]

      const style: L.PathOptions = {
        color: colour,
        weight: strong ? 3 : 2,
        opacity: off ? 0.45 : 1,
        dashArray: off || region.floor !== undefined ? '6 5' : undefined,
        fillColor: colour,
        fillOpacity: off ? 0.04 : strong ? 0.34 : 0.16
      }

      let shape: L.Path | null = null

      if (region.shape === 'poly' && region.points && region.points.length >= 3) {
        shape = L.polygon(toLatLngs(region.points), style)
      } else if (region.shape === 'circle' && region.coords) {
        shape = L.circle([region.coords.y, region.coords.x], { ...style, radius: region.radius ?? 0 })
      }

      if (!shape) return

      const details = [
        climate?.label,
        sky && `${sky.label}, ${Math.round(sky.temperature)}°C`,
        region.floor !== undefined && `above ${Math.round(region.floor)}m`
      ].filter(Boolean)

      shape.bindTooltip(
        `<strong>${escape(region.label)}</strong><br/><span style="color:#a0a0a0">${escape(details.join(' · '))}</span>`,
        { direction: 'top', opacity: 1, className: 'dw-tooltip', sticky: true }
      )

      if (options.onClick) {
        const onClick = options.onClick
        shape.on('click', (event) => {
          L.DomEvent.stopPropagation(event)
          onClick(region.id)
        })
      }

      shape.addTo(group)
    })
}

export function drawPlayer(group: L.LayerGroup, player: Point) {
  group.clearLayers()

  L.circleMarker([player.y, player.x], {
    radius: 6,
    color: '#f4f4f4',
    weight: 3,
    fillColor: '#268bff',
    fillOpacity: 1,
    interactive: false
  }).addTo(group)
}
