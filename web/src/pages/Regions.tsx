import { Eye, Plus } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuTrigger
} from '@/components/ui/dropdown-menu'
import { PageHeader } from '@/components/kit'
import { RegionList } from '@/components/RegionList'
import { RegionMap } from '@/components/RegionMap'
import { Inspector } from '@/components/Inspector'
import { fetchNui } from '@/lib/nui'
import { rgb } from '@/lib/utils'
import { useStore } from '@/store'

export function Regions() {
  const climates = useStore((state) => state.data.climates)
  const create = useStore((state) => state.create)
  const startDrawing = useStore((state) => state.startDrawing)

  const startNew = (climateId: string) => {
    const region = create(climateId, 'poly')
    startDrawing(climateId, region.id)
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col gap-4 p-5">
      <PageHeader title="Regions">
        <div className="flex gap-2">
          <Button variant="secondary" onClick={() => void fetchNui('preview')} title="Draw every border in the world for 20 seconds">
            <Eye />
            Preview in game
          </Button>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button>
                <Plus />
                New region
              </Button>
            </DropdownMenuTrigger>

            <DropdownMenuContent align="end" className="w-72">
              <DropdownMenuLabel>Climate</DropdownMenuLabel>

              {climates.map((climate) => (
                <DropdownMenuItem key={climate.id} onSelect={() => startNew(climate.id)}>
                  <span className="size-2.5 shrink-0 rounded-full" style={{ background: rgb(climate.colour) }} />
                  <span className="font-semibold">{climate.label}</span>
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </PageHeader>

      <div className="flex min-h-0 flex-1 gap-3">
        <RegionList />
        <RegionMap />
        <Inspector />
      </div>
    </div>
  )
}
