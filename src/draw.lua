-- Desenho de tudo em coordenadas virtuais W x H: fundo, contas, HUD, telas
-- de menu/fim de jogo e os toques "arcade" (brilho neon, partículas,
-- tremida de tela, scanlines).
local assets = require("src.assets")
local layout = require("src.layout")
local game = require("src.game")
local theme = require("src.theme")

local draw = {}

local function printCentered(text, font, y, color)
    local W = layout.W
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.printf(text, 3, y + 3, W, "center")
    love.graphics.setColor(color or { 1, 1, 1 })
    love.graphics.printf(text, 0, y, W, "center")
end

local function drawBackground()
    local W, H, GROUND_Y = layout.W, layout.H, layout.GROUND_Y
    love.graphics.setColor(theme.sky)
    love.graphics.rectangle("fill", 0, 0, W, H)
    if assets.background then
        -- escala pela largura e alinha o chão da imagem com GROUND_Y
        local s = W / assets.background:getWidth()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(assets.background, 0, GROUND_Y - 625 * s, 0, s, s)
        -- no celular a tela é mais alta que a imagem: completa o chão
        love.graphics.setColor(theme.ground)
        love.graphics.rectangle("fill", 0, GROUND_Y + 80 * s, W, H)
    else
        love.graphics.setColor(theme.ground)
        love.graphics.rectangle("fill", 0, GROUND_Y, W, H - GROUND_Y)
    end
end

local function drawProblem(p)
    local GROUND_Y = layout.GROUND_Y
    local c = theme.op[p.op]
    -- fica mais vermelha conforme se aproxima do chão
    local danger = math.max(0, (p.y + p.h - GROUND_Y * 0.55) / (GROUND_Y * 0.45))
    local r = c[1] + (0.9 - c[1]) * danger
    local g = c[2] * (1 - danger * 0.8)
    local b = c[3] * (1 - danger * 0.8)

    -- brilho neon por trás do bloco
    love.graphics.setColor(r, g, b, 0.35)
    love.graphics.rectangle("fill", p.x - 5, p.y - 5, p.w + 10, p.h + 10, 14, 14)

    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.rectangle("fill", p.x + 4, p.y + 4, p.w, p.h, 10, 10)
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", p.x, p.y, p.w, p.h, 10, 10)

    love.graphics.setFont(assets.fonts.problem)
    love.graphics.print(p.text, p.x + 14, p.y + 13)
end

local function drawWizard()
    local x, feetY = layout.wizardFeet()
    local castT = math.min(1, game.round.wizardCast / 0.25) -- 1 = acabou de lançar, 0 = parado
    local hop = math.sin(castT * math.pi) * 10             -- pequeno salto ao lançar o feitiço

    love.graphics.push()
    love.graphics.translate(x, feetY - hop)

    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.ellipse("fill", 0, 4, 16, 5)

    -- robe
    love.graphics.setColor(0.35, 0.25, 0.7)
    love.graphics.polygon("fill", -16, 0, 16, 0, 10, -46, -10, -46)
    love.graphics.setColor(0.9, 0.75, 0.2)
    love.graphics.rectangle("fill", -12, -18, 24, 5)

    -- cabeça e chapéu
    love.graphics.setColor(0.95, 0.8, 0.65)
    love.graphics.circle("fill", 0, -56, 11)
    love.graphics.setColor(0.3, 0.2, 0.6)
    love.graphics.polygon("fill", -13, -62, 13, -62, 0, -95)
    love.graphics.setColor(0.9, 0.75, 0.2)
    love.graphics.circle("fill", 0, -95, 3.5)

    -- varinha: gira de "descansando" para "apontada pro alto" ao acertar
    local angle = -0.5 - castT * 1.7
    love.graphics.push()
    love.graphics.translate(14, -40)
    love.graphics.rotate(angle)
    love.graphics.setColor(0.5, 0.35, 0.2)
    love.graphics.setLineWidth(4)
    love.graphics.line(0, 0, 0, -34)
    love.graphics.setColor(1, 0.9, 0.4, 0.6 + castT * 0.4)
    love.graphics.circle("fill", 0, -34, 5 + castT * 3)
    love.graphics.pop()

    love.graphics.pop()
end

local function drawProjectiles()
    for _, proj in ipairs(game.round.projectiles) do
        local progress = math.min(1, proj.t / proj.life)
        local x = proj.x + (proj.tx - proj.x) * progress
        local y = proj.y + (proj.ty - proj.y) * progress - math.sin(progress * math.pi) * 40

        love.graphics.setColor(proj.color[1], proj.color[2], proj.color[3], 0.4)
        love.graphics.circle("fill", x, y, 13)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", x, y, 6)
    end
end

local function drawParticles()
    for _, particle in ipairs(game.round.particles) do
        local alpha = 1 - particle.t / particle.life
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        love.graphics.rectangle("fill", particle.x, particle.y, particle.size, particle.size)
    end
end

local function drawHud()
    local W = layout.W
    local round = game.round
    local font = assets.fonts.hud
    love.graphics.setFont(font)

    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, W, layout.HUD_H)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("PONTOS " .. round.score, 16, 15)
    love.graphics.printf("NIVEL " .. round.level, 0, 15, W, "center")

    if round.combo >= 2 then
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.printf("COMBO x" .. round.combo, 0, 15, W - 150, "right")
    end

    for i = 1, game.MAX_LIVES do
        local img = i <= round.lives and assets.heart or assets.heartBroken
        local x = W - 16 - (game.MAX_LIVES - i + 1) * 36
        if img then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(img, x, 3)
        else
            love.graphics.setColor(i <= round.lives and { 0.9, 0.2, 0.3 } or { 0.4, 0.4, 0.4 })
            love.graphics.circle("fill", x + 16, 22, 12)
        end
    end
end

local function drawInputBox()
    local box = layout.box
    local round = game.round
    local offset = round.shake > 0 and math.sin(round.shake * 60) * 8 or 0
    local x, y = box.x + offset, box.y

    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", x + 4, y + 4, box.w, box.h, 8, 8)
    if round.shake > 0 then
        love.graphics.setColor(1, 0.8, 0.8)
    else
        love.graphics.setColor(1, 1, 1)
    end
    love.graphics.rectangle("fill", x, y, box.w, box.h, 8, 8)
    love.graphics.setColor(0.2, 0.2, 0.3)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, box.w, box.h, 8, 8)

    local font = assets.fonts.big
    local cursor = (love.timer.getTime() % 1 < 0.5) and "_" or " "
    love.graphics.setFont(font)
    love.graphics.printf(round.input .. cursor, x, y + (box.h - font:getHeight()) / 2, box.w, "center")

    if not MOBILE then
        love.graphics.setFont(assets.fonts.small)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("digite a resposta", x + box.w + 16, y + 12)
        love.graphics.print("e aperte ENTER", x + box.w + 16, y + 28)
    end
end

local function drawKeypad()
    local font = assets.fonts.big
    love.graphics.setFont(font)
    for _, k in ipairs(layout.keys) do
        local down = k.pressed > 0 and 3 or 0
        local color = { 1, 1, 1 }
        if k.label == "OK" then
            color = { 0.3, 0.8, 0.4 }
        elseif k.label == "<" then
            color = { 0.95, 0.6, 0.3 }
        end

        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", k.x, k.y + 5, k.w, k.h, 12, 12)
        love.graphics.setColor(color[1] * (down > 0 and 0.8 or 1), color[2] * (down > 0 and 0.8 or 1),
            color[3] * (down > 0 and 0.8 or 1))
        love.graphics.rectangle("fill", k.x, k.y + down, k.w, k.h, 12, 12)
        love.graphics.setColor(0.2, 0.2, 0.3)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", k.x, k.y + down, k.w, k.h, 12, 12)
        love.graphics.printf(k.label, k.x, k.y + down + (k.h - font:getHeight()) / 2, k.w, "center")
    end
end

local function drawEffects()
    local round = game.round
    for _, e in ipairs(round.effects) do
        local alpha = 1 - e.t / e.life
        local font = e.big and assets.fonts.title or assets.fonts.hud
        local scale = e.big and (1 + (1 - alpha) * 0.15) or 1

        love.graphics.setFont(font)
        love.graphics.push()
        love.graphics.translate(e.x, e.y)
        love.graphics.scale(scale)
        love.graphics.setColor(0, 0, 0, alpha * 0.4)
        love.graphics.printf(e.text, -150 + 2, 2, 300, "center")
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], alpha)
        love.graphics.printf(e.text, -150, 0, 300, "center")
        love.graphics.pop()
    end
end

-- linhas escuras finas por cima de tudo, para dar a sensação de tela de
-- fósforo/CRT de fliperama
local function drawScanlines()
    local W, H = layout.W, layout.H
    love.graphics.setColor(0, 0, 0, 0.08)
    for y = 0, H, 4 do
        love.graphics.rectangle("fill", 0, y, W, 2)
    end
end

function draw.playing(showInput)
    local round = game.round
    for _, p in ipairs(round.falling) do drawProblem(p) end
    drawWizard()
    drawProjectiles()
    drawParticles()
    drawEffects()
    drawHud()
    if showInput then
        drawInputBox()
        drawKeypad()
    end

    if round.levelBanner > 0 then
        local a = math.min(1, round.levelBanner)
        printCentered("NIVEL " .. round.level, assets.fonts.title, layout.GROUND_Y * 0.38, { 1, 0.85, 0.2, a })
    end

    if round.flash > 0 then
        love.graphics.setColor(1, 0, 0, round.flash)
        love.graphics.rectangle("fill", 0, 0, layout.W, layout.H)
    end
end

local function drawOverlay(alpha)
    love.graphics.setColor(0, 0, 0, alpha or 0.45)
    love.graphics.rectangle("fill", 0, 0, layout.W, layout.H)
end

local startHint = MOBILE and "TOQUE para jogar" or "ENTER para jogar"
local restartHint = MOBILE and "TOQUE para jogar de novo" or "ENTER para jogar de novo"

local function drawMenu()
    local W, H = layout.W, layout.H
    drawOverlay()

    -- título com brilho neon que gira lentamente de cor
    local r, g, b = theme.hue(love.timer.getTime() * 0.15, 0.55, 1)
    printCentered("CHUVA DE", assets.fonts.title, H * 0.2, { r, g, b })
    printCentered("CONTAS", assets.fonts.title, H * 0.2 + 50, { r, g, b })
    printCentered("Resolva as contas antes", assets.fonts.hud, H * 0.45)
    printCentered("que elas caiam no chao!", assets.fonts.hud, H * 0.45 + 25)
    printCentered("+   -   x   :", assets.fonts.big, H * 0.575, { 0.6, 0.9, 1 })
    if love.timer.getTime() % 1 < 0.7 then
        printCentered(startHint, assets.fonts.big, H * 0.7)
    end
    printCentered("Recorde: " .. game.highscore, assets.fonts.hud, H * 0.82)
    love.graphics.setFont(assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf("v" .. (GAME_VERSION or "?"), 0, H - 20, W - 12, "right")
    if not MOBILE then
        printCentered("ESC para sair", assets.fonts.small, H * 0.933)
    end
end

local function drawGameOver()
    local H = layout.H
    local round = game.round
    drawOverlay(0.7)
    printCentered("FIM DE JOGO", assets.fonts.title, H * 0.25, { 1, 0.35, 0.35 })
    printCentered("Pontos: " .. round.score, assets.fonts.big, H * 0.4)
    printCentered("Nivel: " .. round.level .. "   Acertos: " .. round.hits, assets.fonts.hud, H * 0.48)
    if round.newRecord then
        printCentered("NOVO RECORDE!", assets.fonts.big, H * 0.565, { 1, 0.85, 0.2 })
    else
        printCentered("Recorde: " .. game.highscore, assets.fonts.hud, H * 0.575)
    end
    if round.overDelay <= 0 and love.timer.getTime() % 1 < 0.7 then
        printCentered(restartHint, assets.fonts.hud, H * 0.717)
    end
    if not MOBILE then
        printCentered("ESC para sair", assets.fonts.small, H * 0.933)
    end
end

function draw.frame()
    love.graphics.clear(0.1, 0.12, 0.16) -- faixas fora da área do jogo

    -- tremida de tela ao subir de nível / fechar um combo
    local shakeX, shakeY = 0, 0
    if game.state == "playing" and game.round and game.round.screenShake > 0 then
        local s = game.round.screenShake
        shakeX = (math.random() * 2 - 1) * s * 14
        shakeY = (math.random() * 2 - 1) * s * 14
    end

    love.graphics.push()
    love.graphics.translate(layout.view.ox + shakeX, layout.view.oy + shakeY)
    love.graphics.scale(layout.view.scale)
    love.graphics.setScissor(layout.view.ox, layout.view.oy, layout.W * layout.view.scale, layout.H * layout.view.scale)

    drawBackground()
    if game.state == "playing" then
        draw.playing(true)
    elseif game.state == "menu" then
        drawMenu()
    else
        draw.playing(false)
        drawGameOver()
    end
    drawScanlines()

    love.graphics.setScissor()
    love.graphics.pop()
end

return draw
