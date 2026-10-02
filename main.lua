-- Chuva de Contas: resolva as contas antes que elas caiam no chão!
-- Ponto de entrada: carrega tudo e repassa os callbacks do LÖVE para a tela
-- atual (states/), que o src/statemanager.lua controla.
local assets = require("src.assets")
local layout = require("src.layout")
local music = require("src.music")
local save = require("src.save")
local statemanager = require("src.statemanager")
local theme = require("src.theme")
local transition = require("src.transition")
local ui = require("src.ui")

local STATES = { "menu", "credits", "play", "pause", "gameover" }

function love.load()
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("linear", "linear")
    assets.load()
    save.load()
    layout.update()
    music.play()

    for _, name in ipairs(STATES) do
        statemanager.register(name, require("states." .. name))
    end
    statemanager.switch("menu")
end

function love.resize()
    layout.update()
end

function love.update(dt)
    transition.update(dt)
    statemanager.call("update", dt)
end

function love.focus(focused)
    statemanager.call("focus", focused)
end

-- durante a transição a entrada é ignorada: a tela está trocando
function love.textinput(t)
    if transition.active() then return end
    statemanager.call("textinput", t)
end

function love.keypressed(key)
    if transition.active() then return end
    statemanager.call("keypressed", key)
end

function love.wheelmoved(_, dy)
    statemanager.call("wheelmoved", dy)
end

-- toque ou clique em (x, y) na tela real; as telas recebem em coordenadas virtuais
local function pointerPressed(x, y)
    if transition.active() then return end
    statemanager.call("pointerpressed", layout.toVirtual(x, y))
end

function love.touchpressed(_, x, y)
    pointerPressed(x, y)
end

function love.mousepressed(x, y, button, istouch)
    -- toques já chegam pelo touchpressed
    if not istouch and button == 1 then
        pointerPressed(x, y)
    end
end

function love.draw()
    local bg = theme.letterbox
    love.graphics.clear(bg[1], bg[2], bg[3])

    local view = layout.view
    local shakeX, shakeY = statemanager.call("cameraShake")
    love.graphics.push()
    love.graphics.translate(view.ox + (shakeX or 0), view.oy + (shakeY or 0))
    love.graphics.scale(view.scale)
    love.graphics.setScissor(view.ox, view.oy, layout.W * view.scale, layout.H * view.scale)

    ui.drawBackground()
    statemanager.call("draw")
    transition.draw(layout.W, layout.H)
    ui.drawScanlines()

    love.graphics.setScissor()
    love.graphics.pop()
end
