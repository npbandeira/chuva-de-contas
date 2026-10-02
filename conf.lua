-- Configuração do LÖVE: roda antes do main.lua e define janela e módulos.
local config = require("src.config")

function love.conf(t)
    t.identity = "chuva_de_contas" -- pasta do save (recorde)
    t.version = "11.5"
    t.window.title = "Chuva de Contas"
    t.window.vsync = 1

    if config.mobile then
        -- retrato; no celular a janela não redimensionável trava a orientação
        t.window.width = 405
        t.window.height = 720
        t.window.highdpi = true
        t.window.fullscreen = config.nativeMobile
        t.window.resizable = not config.nativeMobile
    else
        t.window.width = 800
        t.window.height = 600
        t.window.resizable = true
    end

    -- módulos que o jogo não usa: desligados para abrir mais rápido
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false
end
