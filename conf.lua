-- Modo celular: automático no Android/iOS, ou forçado no PC com "love . --mobile"
local NATIVE_MOBILE = love._os == "Android" or love._os == "iOS"

local function hasArg(name)
    for _, a in pairs(arg or {}) do
        if a == name then return true end
    end
    return false
end

-- global: lido também pelo main.lua
MOBILE = NATIVE_MOBILE or hasArg("--mobile")

-- global: versão do jogo, mostrada no menu e usada pelo android/build_apk.sh
GAME_VERSION = "1.0.0"

function love.conf(t)
    t.identity = "chuva_de_contas"
    t.window.title = "Chuva de Contas"
    t.window.vsync = 1

    if MOBILE then
        -- retrato; no celular a janela não redimensionável trava a orientação
        t.window.width = 405
        t.window.height = 720
        t.window.highdpi = true
        t.window.fullscreen = NATIVE_MOBILE
        t.window.resizable = not NATIVE_MOBILE
    else
        t.window.width = 800
        t.window.height = 600
        t.window.resizable = true
    end
end
