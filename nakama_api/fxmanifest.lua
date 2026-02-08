fx_version 'cerulean'
game 'common'
use_experimental_fxv2_oal 'yes'
lua54 'yes'

name 'Nakama API'
author 'wesleyy.'
description 'Nakama API for FiveM'
version '1.0.0'

repository 'https://github.com/Welseyy/nakama_api'

server_scripts {
    'config.lua',
    'nakama_api.lua',

    -- uncomment only for testing
    -- 'examples/test_commands.lua'
}