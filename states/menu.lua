-- Tela inicial: título animado, botão JOGAR, recorde e acesso aos créditos,
-- com a demonstração (src/demo.lua) rodando ao fundo.
local assets = require("src.assets")
local config = require("src.config")
local demo = require("src.demo")
local layout = require("src.layout")
local save = require("src.save")
local statemanager = require("src.statemanager")
local theme = require("src.theme")
local transition = require("src.transition")
local ui = require("src.ui")

local menu = {}

local START_HINT = config.mobile and "toque na tela" or "ENTER ou ESPACO"

-- voltando dos créditos a cena continua de onde estava, sem repetir a entrada
function menu.enter(previous)
    if previous ~= "credits" then demo.reset() end
end

function menu.update(dt)
    demo.update(dt)
end

local function startGame()
    transition.to(function() statemanager.switch("play") end)
end

local function openCredits()
    transition.to(function() statemanager.switch("credits") end)
    assets.play("click")
end

function menu.keypressed(key)
    if key == "return" or key == "kpenter" or key == "space" then
        startGame()
    elseif key == "c" then
        openCredits()
    elseif key == "escape" and not config.web then
        -- "escape" também é o botão Voltar do Android
        love.event.quit()
    end
end

function menu.pointerpressed(x, y)
    if ui.inside(layout.footerButton(), x, y) then
        openCredits()
    else
        startGame()
    end
end

-- progresso 0..1 de uma animação de entrada que começa em `delay` e dura `dur`
local function intro(delay, dur)
    return math.max(0, math.min(1, (demo.t - delay) / dur))
end

-- título letra por letra: cada uma cai do alto com um quique e depois
-- fica ondulando, com a cor neon girando ao longo da palavra
local function drawTitleLine(text, y, firstIndex)
    local font = assets.fonts.title
    local now = love.timer.getTime()
    love.graphics.setFont(font)
    local x = (layout.W - font:getWidth(text)) / 2
    for i = 1, #text do
        local ch = text:sub(i, i)
        local n = firstIndex + i
        local k = intro(n * 0.05, 0.55)
        if k > 0 and ch ~= " " then
            local drop = (1 - ui.easeOutBack(k)) * -120
            local wave = math.sin(now * 3 + n * 0.45) * 4 * k
            local ly = y + drop + wave
            local r, g, b = theme.hue(now * 0.15 + n * 0.035, 0.55, 1)
            love.graphics.setColor(0.1, 0.05, 0.25, 0.6 * k)
            love.graphics.print(ch, x + 4, ly + 4)
            love.graphics.setColor(r, g, b, k)
            love.graphics.print(ch, x, ly)
        end
        x = x + font:getWidth(ch)
    end
end

-- os quatro sinais em "fichas" coloridas que entram pulando e flutuam
local function drawOperatorChips(cy)
    local ops = { { "+", "+" }, { "-", "-" }, { "x", "x" }, { ":", "/" } }
    local size, gap = 46, 18
    local total = #ops * size + (#ops - 1) * gap
    local font = assets.fonts.big
    local now = love.timer.getTime()
    love.graphics.setFont(font)
    for i, op in ipairs(ops) do
        local k = intro(0.9 + i * 0.1, 0.45)
        if k > 0 then
            local s = ui.easeOutBack(k)
            local cx = (layout.W - total) / 2 + (i - 1) * (size + gap) + size / 2
            local y = cy + math.sin(now * 2.5 + i) * 5
            local c = theme.op[op[2]]
            love.graphics.push()
            love.graphics.translate(cx, y)
            love.graphics.scale(s)
            love.graphics.rotate(math.sin(now * 1.8 + i * 1.3) * 0.12)
            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.rectangle("fill", -size / 2 + 3, -size / 2 + 4, size, size, 10, 10)
            love.graphics.setColor(c)
            love.graphics.rectangle("fill", -size / 2, -size / 2, size, size, 10, 10)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", -size / 2, -size / 2, size, size, 10, 10)
            love.graphics.printf(op[1], -size / 2, -font:getHeight() / 2 + 2, size, "center")
            love.graphics.pop()
        end
    end
end

-- botão principal: entra com um "pop", respira devagar e cresce com o mouse
local function drawPlayButton(cy)
    local k = intro(1.4, 0.5)
    if k <= 0 then return end
    local W = layout.W
    local w, h = 260, 64
    local now = love.timer.getTime()

    local hover = ui.hovered({ x = (W - w) / 2, y = cy - h / 2, w = w, h = h })
    local s = ui.easeOutBack(k) * (hover and 1.08 or 1 + math.sin(now * 4) * 0.035)

    love.graphics.push()
    love.graphics.translate(W / 2, cy)
    love.graphics.scale(s)

    -- brilho pulsando em volta
    local glow = 0.25 + (math.sin(now * 4) + 1) * 0.1
    love.graphics.setColor(0.4, 1, 0.5, glow)
    love.graphics.rectangle("fill", -w / 2 - 8, -h / 2 - 8, w + 16, h + 16, 20, 20)

    love.graphics.setColor(0.1, 0.35, 0.15)
    love.graphics.rectangle("fill", -w / 2, -h / 2 + 6, w, h, 14, 14)
    local bright = hover and 1.12 or 1
    love.graphics.setColor(0.3 * bright, 0.8 * bright, 0.4 * bright)
    love.graphics.rectangle("fill", -w / 2, -h / 2, w, h, 14, 14)
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.rectangle("fill", -w / 2 + 8, -h / 2 + 6, w - 16, h * 0.3, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", -w / 2, -h / 2, w, h, 14, 14)

    local font = assets.fonts.big
    love.graphics.setFont(font)
    love.graphics.setColor(0.1, 0.3, 0.15)
    love.graphics.printf("JOGAR", -w / 2 + 2, -font:getHeight() / 2 + 2, w, "center")
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("JOGAR", -w / 2, -font:getHeight() / 2, w, "center")
    love.graphics.pop()

    love.graphics.setFont(assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 0.75 * k)
    love.graphics.printf(START_HINT, 0, cy + h / 2 + 18, W, "center")
end

-- plaquinha do recorde com uma estrela girando ao lado
local function drawRecord(cy)
    local k = intro(1.8, 0.5)
    if k <= 0 then return end
    local W = layout.W
    local font = assets.fonts.hud
    local text = save.highscore > 0 and ("RECORDE  " .. save.highscore) or "SEM RECORDE AINDA"
    local w = font:getWidth(text) + 64
    local h = 36
    local y = cy + (1 - k) * 20

    love.graphics.setColor(0, 0, 0, 0.45 * k)
    love.graphics.rectangle("fill", (W - w) / 2, y - h / 2, w, h, h / 2, h / 2)
    love.graphics.setColor(1, 0.85, 0.2, 0.8 * k)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", (W - w) / 2, y - h / 2, w, h, h / 2, h / 2)

    love.graphics.push()
    love.graphics.translate((W - w) / 2 + 22, y)
    love.graphics.rotate(love.timer.getTime() * 1.5)
    love.graphics.setColor(1, 0.85, 0.2, k)
    local star = {}
    for i = 0, 9 do
        local a = math.pi * i / 5 - math.pi / 2
        local r = (i % 2 == 0) and 9 or 4
        table.insert(star, math.cos(a) * r)
        table.insert(star, math.sin(a) * r)
    end
    love.graphics.polygon("fill", star)
    love.graphics.pop()

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, k)
    love.graphics.print(text, (W - w) / 2 + 42, y - font:getHeight() / 2)
end

function menu.draw()
    local W, H = layout.W, layout.H

    demo.draw()
    ui.overlay(0.25 + intro(0, 0.6) * 0.2)

    drawTitleLine("CHUVA DE", H * 0.13, 0)
    drawTitleLine("CONTAS", H * 0.13 + 52, 8)

    local sub = intro(0.8, 0.5)
    local subColor = { 1, 1, 1, sub }
    ui.printCentered("Resolva as contas antes", assets.fonts.hud, H * 0.33 + (1 - sub) * 10, subColor)
    ui.printCentered("que elas caiam no chão!", assets.fonts.hud, H * 0.33 + 25 + (1 - sub) * 10, subColor)

    drawOperatorChips(H * 0.49)
    drawPlayButton(H * 0.65)
    drawRecord(H * 0.81)

    ui.drawFooterButton("CREDITOS", "C", intro(2.1, 0.5))

    love.graphics.setFont(assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.printf("v" .. config.VERSION, 0, H - 20, W - 12, "right")
    if not config.mobile and not config.web then
        love.graphics.printf("ESC para sair", 12, H - 20, W, "left")
    end
end

return menu
