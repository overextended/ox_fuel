--[[ FX Information ]]--
fx_version   'cerulean'
use_experimental_fxv2_oal 'yes'
lua54        'yes'
game         'gta5'

--[[ Resource Information ]]--
name         'ox_fuel'
author       'Overextended'
version      '1.4.0'
repository   'https://github.com/overextended/ox_fuel'
description  'Fuel management system with ox_inventory support'

--[[ Manifest ]]--
dependencies {
	'ox_lib',
	'ox_inventory',
}

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua'
}

server_scripts {
	'server.lua'
}

client_scripts {
	'data/stations.lua',
	'client.lua'
}

files {
	'locales/*.json'
}
