import { Check, Undo2, X } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { findClimate, useStore } from '@/store'
import { fetchNui } from '@/lib/nui'
import { rgb } from '@/lib/utils'

/** Floats over the map while corners are being placed. */
export function DrawingBar() {
  const drawing = useStore((state) => state.drawing)
  const climates = useStore((state) => state.data.climates)
  const undoVertex = useStore((state) => state.undoVertex)
  const cancelDrawing = useStore((state) => state.cancelDrawing)
  const finishDrawing = useStore((state) => state.finishDrawing)

  if (!drawing) return null

  const climate = findClimate(climates, drawing.climate)
  const count = drawing.points.length
  const enough = count >= 3

  return (
    <div className="flex items-center gap-3 rounded-md border border-primary bg-surface px-4 py-2.5">
      <span className="size-2.5 shrink-0 rounded-full" style={{ background: rgb(climate?.colour) }} />

      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold">
          Drawing a {climate?.label.toLowerCase()} region · {count} corner{count === 1 ? '' : 's'}
        </p>
        <p className="truncate text-xs font-medium text-muted-foreground">
          {enough ? 'Keep clicking, or finish to close the shape and save it.' : `Click the map for corner ${count + 1}. Three is the minimum.`}
        </p>
      </div>

      <Button variant="ghost" size="sm" disabled={count === 0} onClick={undoVertex}>
        <Undo2 />
        Undo
      </Button>
      <Button variant="ghost" size="sm" onClick={cancelDrawing}>
        <X />
        Cancel
      </Button>
      <Button
        size="sm"
        disabled={!enough}
        onClick={() => {
          const region = finishDrawing()
          if (region) void fetchNui('saveRegion', region)
        }}
      >
        <Check />
        Finish
      </Button>
    </div>
  )
}
