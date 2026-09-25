-- Chuva de Contas: resolva as contas antes que elas caiam no chão!
local assets = require("src.assets")
local layout = require("src.layout")
local game = require("src.game")
local input = require("src.input")
local draw = require("src.draw")
local music = require("src.music")

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
    game.update(dt)
end

function love.textinput(t)
    input.textinput(t)
end

function love.keypressed(key)
    input.keypressed(key)
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
