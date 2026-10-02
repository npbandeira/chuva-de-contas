-- Tela de pausa por cima da partida congelada: continuar, reiniciar ou
-- voltar ao menu. A música fica baixinha enquanto ela está aberta.
local assets = require("src.assets")
local config = require("src.config")
local layout = require("src.layout")
local music = require("src.music")
local statemanager = require("src.statemanager")
local transition = require("src.transition")
local ui = require("src.ui")

local pause = {}

local BUTTON_COLORS = {
    resume = { 0.3, 0.8, 0.4 },
    restart = { 0.25, 0.55, 0.95 },
    menu = { 0.95, 0.55, 0.2 },
}

local round
local t = 0 -- tempo desde que pausou (anima a entrada)

function pause.enter(_, pausedRound)
    round = pausedRound
    t = 0
    music.duck(true)
    assets.play("click")
end

function pause.exit()
    music.duck(false)
end

function pause.update(dt)
    t = t + dt
end

-- trocas de tela passam pela transição: a mudança acontece com a tela coberta
local ACTIONS = {
    resume = function() statemanager.switch("play", { resume = true }) end,
    restart = function() transition.to(function() statemanager.switch("play") end) end,
    menu = function() transition.to(function() statemanager.switch("menu") end) end,
}

function pause.keypressed(key)
    if key == "escape" or key == "p" or key == "return" or key == "kpenter" or key == "space" then
        ACTIONS.resume()
    elseif key == "r" then
        ACTIONS.restart()
    elseif key == "m" then
        ACTIONS.menu()
    end
end

function pause.pointerpressed(x, y)
    for _, b in ipairs(layout.pauseButtons()) do
        if ui.inside(b, x, y) then
            ACTIONS[b.id]()
            return
        end
    end
end

function pause.draw()
    round:draw({ hitCounter = true, pauseIcon = false, input = true })

    local H = layout.H
    local k = math.min(1, t / 0.35)
    ui.overlay(0.6 * k)

    -- título desce de cima com quique e fica flutuando de leve
    local now = love.timer.getTime()
    local ty = H * 0.2 + (1 - ui.easeOutBack(k)) * -80 + math.sin(now * 2) * 3
    ui.printCentered("PAUSADO", assets.fonts.title, ty, { 1, 0.85, 0.2, k })
    ui.printCentered("Acertos: " .. round.hits, assets.fonts.hud, ty + 56, { 1, 1, 1, 0.8 * k })

    local font = assets.fonts.big
    for i, b in ipairs(layout.pauseButtons()) do
        local bk = math.max(0, math.min(1, (t - 0.1 - i * 0.07) / 0.3))
        if bk > 0 then
            local hover = ui.hovered(b)
            local c = BUTTON_COLORS[b.id]
            local bright = hover and 1.12 or 1
            local sc = ui.easeOutBack(bk) * (hover and 1.05 or 1)

            love.graphics.push()
            love.graphics.translate(b.x + b.w / 2, b.y + b.h / 2)
            love.graphics.scale(sc)
            local x, y = -b.w / 2, -b.h / 2
            love.graphics.setColor(c[1] * 0.4, c[2] * 0.4, c[3] * 0.4)
            love.graphics.rectangle("fill", x, y + 5, b.w, b.h, 12, 12)
            love.graphics.setColor(c[1] * bright, c[2] * bright, c[3] * bright)
            love.graphics.rectangle("fill", x, y, b.w, b.h, 12, 12)
            love.graphics.setColor(1, 1, 1, 0.2)
            love.graphics.rectangle("fill", x + 8, y + 5, b.w - 16, b.h * 0.3, 8, 8)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x, y, b.w, b.h, 12, 12)
            love.graphics.setFont(font)
            love.graphics.printf(b.label, x, -font:getHeight() / 2, b.w, "center")
            love.graphics.pop()

            if not config.mobile then
                love.graphics.setFont(assets.fonts.small)
                love.graphics.setColor(1, 1, 1, 0.6 * bk)
                love.graphics.print(b.key, b.x + b.w + 14, b.y + b.h / 2 - 5)
            end
        end
    end
end

return pause
