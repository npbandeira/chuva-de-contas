-- Chuva de Contas: resolva as contas antes que elas caiam no chão!
local assets = require("src.assets")
local layout = require("src.layout")
local game = require("src.game")
local input = require("src.input")
local draw = require("src.draw")
local music = require("src.music")
local menu = require("src.menu")
local transition = require("src.transition")

function love.load()
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("linear", "linear")
    assets.load()
    game.loadHighscore()
    layout.update()
    music.play()
end

function love.resize()
    layout.update()
end

function love.update(dt)
    input.update(dt)
    transition.update(dt)
    game.update(dt)
    menu.update(dt)
end

-- trocou de janela / app foi para segundo plano: pausa sozinho
function love.focus(focused)
    if not focused then game.pause() end
end

function love.textinput(t)
    input.textinput(t)
end

function love.keypressed(key)
    input.keypressed(key)
end

function love.wheelmoved(_, dy)
    input.wheelmoved(dy)
end

function love.touchpressed(_, x, y)
    input.pointerPressed(x, y)
end

function love.mousepressed(x, y, button, istouch)
    -- toques já chegam pelo touchpressed
    if not istouch and button == 1 then
        input.pointerPressed(x, y)
    end
end

function love.draw()
    draw.frame()
end
