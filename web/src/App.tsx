import { useCallback, useEffect } from 'react'
import { Shell } from '@/components/Shell'
import { Overview } from '@/pages/Overview'
import { Regions } from '@/pages/Regions'
import { Climates } from '@/pages/Climates'
import { fetchNui, useNuiEvent } from '@/lib/nui'
import { useStore } from '@/store'
import type { EditorData, PlacementResult } from '@/types'

const PAGES = { overview: Overview, regions: Regions, climates: Climates }

export default function App() {
  const open = useStore((state) => state.open)
  const hidden = useStore((state) => state.hidden)
  const page = useStore((state) => state.page)
  const setOpen = useStore((state) => state.setOpen)
  const setHidden = useStore((state) => state.setHidden)
  const setData = useStore((state) => state.setData)

  const close = useCallback(() => {
    setOpen(false)
    void fetchNui('close')
  }, [setOpen])

  useNuiEvent<{ data: EditorData }>('open', ({ data }) => {
    setData(data)
    setOpen(true)
    setHidden(false)
  })

  useNuiEvent('close', () => setOpen(false))
  useNuiEvent<{ data: EditorData }>('data', ({ data }) => setData(data))

  // The panel steps aside while the player aims at something in the world.
  useNuiEvent('hide', () => setHidden(true))

  useNuiEvent<{ result?: PlacementResult }>('placed', ({ result }) => {
    setHidden(false)
    if (!result) return

    const { patch } = useStore.getState()
    const coords = { x: result.coords.x, y: result.coords.y }

    if (result.points && result.points.length >= 3) {
      patch({ shape: 'poly', coords, points: result.points.map((point) => ({ x: point.x, y: point.y })) })
    } else {
      patch({ shape: 'circle', coords, radius: result.radius })
    }
  })

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key !== 'Escape' || !open || hidden) return

      const { drawing, cancelDrawing } = useStore.getState()
      if (drawing) return cancelDrawing()

      close()
    }

    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, hidden, close])

  if (!open || hidden) return null

  const Page = PAGES[page]

  return (
    <Shell onClose={close}>
      <Page />
    </Shell>
  )
}
