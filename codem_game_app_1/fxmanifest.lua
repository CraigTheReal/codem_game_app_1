fx_version 'cerulean'
game 'gta5'

author 'Craig'
description 'Rock Paper Scissors Game App mPhone V2'
version '0.5.0'

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@es_extended/locale.lua',
    'server/main.lua'
}

files {
    'ui/**/*'
}

dependencies {
    'codem-phone',
    'es_extended'
}
