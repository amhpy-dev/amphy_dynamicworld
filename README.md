# amphy_dynamicworld

Regional weather, a synced clock and a weather-driven sickness system for Qbox. Every part of the map runs its own weather at the same time: rain in Los Santos while it snows on Mount Chiliad.

## Features

- **Regional weather.** Draw regions on the map in game. Each one rolls its own weather from its climate, and players see the sky of the region they stand in, blending as they cross a border.
- **Climate creator.** Make climates in the panel with sliders for temperature, humidity, wind, how long weather lasts and the odds of each weather. Changes go live for everyone as you save.
- **Realistic defaults.** Five climates based on real places: coastal Los Angeles, the Mojave, the Northern California coast, the High Sierra and the Caribbean.
- **Temperature and feels-like** per region, from the climate, the weather and the time of day.
- **Sickness.** Cold, rain, heat, humidity, grime and contagious players build exposure. Five illnesses, each worsening in stages with coughs, walk styles, sprint limits and screen effects.
- **Cures.** ox_inventory items with progress bars, cooldowns and immunity.
- **Interiors and shells** can hold a player on their own weather and time.
- **Blackouts** city-wide, per region or per player.
- **Drop-in compatibility** with qb-weathersync, Renewed-Weathersync and vSync consumers.
- **Everything in SQL**, in plain columns. Sickness is saved per character.
- **Translatable.** Every message is in `locales/`.

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- [qbx_core](https://github.com/Qbox-project/qbx_core)
- [ox_inventory](https://github.com/overextended/ox_inventory) (optional, for cures)

## Installation

1. Download the latest release from [Releases](https://github.com/amhpy-dev/amphy_dynamicworld/releases). The source on `main` doesn't include the built panel.
2. Remove any other weather sync resource (qb-weathersync, Renewed-Weathersync, vSync).
3. Add it to your `server.cfg` after its dependencies:

```cfg
ensure ox_lib
ensure oxmysql
ensure qbx_core
ensure ox_inventory
ensure amphy_dynamicworld
```

4. Start the server. Every table is created on the first start. Open the editor with `/weatherregions`.

## ox_inventory items

```lua
['cold_medicine']   = { label = 'Cold Medicine',     weight = 50,  client = { export = 'amphy_dynamicworld.useCure' } },
['antibiotics']     = { label = 'Antibiotics',       weight = 50,  client = { export = 'amphy_dynamicworld.useCure' } },
['flu_shot']        = { label = 'Flu Shot',          weight = 50,  client = { export = 'amphy_dynamicworld.useCure' } },
['water_bottle']    = { label = 'Bottle of Water',   weight = 500, client = { export = 'amphy_dynamicworld.useCure' } },
['electrolytes']    = { label = 'Electrolyte Drink', weight = 500, client = { export = 'amphy_dynamicworld.useCure' } },
['hot_coffee']      = { label = 'Hot Coffee',        weight = 300, client = { export = 'amphy_dynamicworld.useCure' } },
['thermal_blanket'] = { label = 'Thermal Blanket',   weight = 800, client = { export = 'amphy_dynamicworld.useCure' } },
```

Leave out ox_inventory's own `usetime` and `anim`; each cure plays its own progress bar.

## Documentation

Open `docs/index.html` in a browser for configuration, commands, exports, events and the database layout.

## Building the panel

```sh
cd web
bun install
bun run build
```

`bun dev` previews the panel in a browser with sample data.
