fx_version  'cerulean'
game        'gta5'
lua54       'yes'

name        'amphy_dynamicworld'
description 'Regional weather, synced time and a weather-driven sickness system for Qbox.'
author      'Amphy'
version     '2.0.0'
repository  'https://github.com/amhpy-dev/amphy_dynamicworld'

ui_page 'web/dist/index.html'

files {
    'data/*.lua',
    'modules/*.lua',
    'locales/*.json',
    'web/dist/*',
    'web/dist/**/*',
    'web/mapStyles/*.jpg',
    'web/mapStyles/**/*.jpg',
}

shared_script '@ox_lib/init.lua'

client_scripts {
    'client/main.lua',
    'client/nui.lua',
    'client/exports.lua',
    'client/compat.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/time.lua',
    'server/climates.lua',
    'server/regions.lua',
    'server/weather.lua',
    'server/sickness.lua',
    'server/inventory.lua',
    'server/compat.lua',
    'server/commands.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

-- provide 'qb-weathersync'
