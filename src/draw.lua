-- Desenho de tudo em coordenadas virtuais W x H: fundo, contas, HUD, telas
-- de menu/fim de jogo e os toques "arcade" (brilho neon, partículas,
-- tremida de tela, scanlines).
local assets = require("src.assets")
local layout = require("src.layout")
local game = require("src.game")
local theme = require("src.theme")
local menu = require("src.menu")
local transition = require("src.transition")

local draw = {}

local function printCentered(text, font, y, color)
    local W = layout.W
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.35 * (color and color[4] or 1))
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

-- octógono (cantos cortados): silhueta de "placa blindada"
local function octagonPoints(x, y, w, h)
    local cut = math.min(w, h) * 0.3
    return {
        x + cut, y, x + w - cut, y,
        x + w, y + cut, x + w, y + h - cut,
        x + w - cut, y + h, x + cut, y + h,
        x, y + h - cut, x, y + cut,
    }
end

-- estrela/explosão de pontas: silhueta "perigosa" do chefe, gira devagar
local function spikyPoints(cx, cy, rx, ry, spikes, rotation)
    local pts = {}
    for i = 0, spikes * 2 - 1 do
        local a = (math.pi * i) / spikes + rotation
        local mul = (i % 2 == 0) and 1 or 0.6
        table.insert(pts, cx + math.cos(a) * rx * mul)
        table.insert(pts, cy + math.sin(a) * ry * mul)
    end
    return pts
end

-- desenha a silhueta certa pra cada tipo de conta: retângulo arredondado
-- (normal/chefe), cápsula bem arredondada (poder) ou octógono (blindado)
local function drawShape(mode, kind, x, y, w, h)
    if kind == "armored" then
        love.graphics.polygon(mode, octagonPoints(x, y, w, h))
    else
        local rad = (kind == "power") and h / 2 or 10
        love.graphics.rectangle(mode, x, y, w, h, rad, rad)
    end
end

local STEEL = { 0.74, 0.79, 0.86 }
local STEEL_DARK = { 0.3, 0.35, 0.45 }
local BOSS_GOLD = { 1, 0.8, 0.25 }

-- escudinho (usado nos marcadores de vida acima das contas)
local function shieldPoints(cx, cy, s)
    return {
        cx - s, cy - s, cx + s, cy - s, cx + s, cy + s * 0.2,
        cx, cy + s * 1.2, cx - s, cy + s * 0.2,
    }
end

-- marcadores de "golpes que faltam" acima da conta: escudos cheios são
-- acertos que ainda precisa, vazios são os que já foram
local function drawHpPips(p)
    local boss = p.kind == "boss"
    local s = 8
    local gap = 22
    local total = (p.maxHp - 1) * gap
    local y = p.y - (boss and 26 or 22)
    for i = 1, p.maxHp do
        local cx = p.x + p.w / 2 - total / 2 + (i - 1) * gap
        local pts = shieldPoints(cx, y, s)
        if i <= p.hp then
            love.graphics.setColor(boss and { 0.9, 0.15, 0.2 } or STEEL)
            love.graphics.polygon("fill", pts)
            love.graphics.setColor(boss and BOSS_GOLD or STEEL_DARK)
        else
            love.graphics.setColor(0, 0, 0, 0.15)
            love.graphics.polygon("fill", pts)
            love.graphics.setColor(0.3, 0.3, 0.35, 0.5)
        end
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", pts)
    end
end

-- rachadura depois do primeiro golpe em quem tem mais de 1 de vida
local function drawCrack(p)
    if p.maxHp > 1 and p.hp < p.maxHp then
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.setLineWidth(2)
        love.graphics.line(p.x + 6, p.y + p.h * 0.25, p.x + p.w * 0.5, p.y + p.h * 0.75, p.x + p.w - 6,
            p.y + p.h * 0.2)
    end
end

-- chifres nos cantos de cima do chefe
local function drawHorns(p)
    local y = p.y + 2
    local left = { p.x + 10, y, p.x + 30, y, p.x + 2, y - 20 }
    local right = { p.x + p.w - 10, y, p.x + p.w - 30, y, p.x + p.w - 2, y - 20 }
    for _, pts in ipairs({ left, right }) do
        love.graphics.setColor(0.96, 0.92, 0.82)
        love.graphics.polygon("fill", pts)
        love.graphics.setColor(0.35, 0.1, 0.12)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", pts)
    end
end

local function drawProblem(p)
    local GROUND_Y = layout.GROUND_Y
    local now = love.timer.getTime()
    local c = theme.op[p.op]
    if p.kind == "boss" then
        c = { 0.55, 0.08, 0.15 }
    elseif p.kind == "power" then
        c = { 0.95, 0.8, 0.2 }
    end

    -- fica mais vermelha conforme se aproxima do chão
    local danger = math.max(0, (p.y + p.h - GROUND_Y * 0.55) / (GROUND_Y * 0.45))
    local r = c[1] + (0.9 - c[1]) * danger
    local g = c[2] * (1 - danger * 0.8)
    local b = c[3] * (1 - danger * 0.8)

    -- blindada com o escudo ainda inteiro ganha uma moldura de aço
    local shielded = p.kind == "armored" and p.hp == p.maxHp

    if p.kind == "boss" then
        -- aura de pontas girando atrás do chefe, pulsando
        local pulse = (math.sin(now * 5) + 1) * 0.5
        love.graphics.setColor(0.9, 0.1, 0.15, 0.3 + pulse * 0.2 + (p.hitFlash or 0) * 2)
        love.graphics.polygon("fill", spikyPoints(p.x + p.w / 2, p.y + p.h / 2, p.w / 2 + 22 + pulse * 4,
            p.h / 2 + 22 + pulse * 4, 12, now * 0.8))
    end

    -- brilho neon por trás do bloco (mais forte logo após levar um golpe;
    -- o poder também pulsa sozinho pra chamar atenção)
    local glow = 0.35 + (p.hitFlash or 0) * 1.5
    if p.kind == "power" then
        glow = glow + (math.sin(now * 6) + 1) * 0.12
    end
    local shape = p.kind == "boss" and "normal" or p.kind
    love.graphics.setColor(r, g, b, glow)
    drawShape("fill", shape, p.x - 6, p.y - 6, p.w + 12, p.h + 12)

    love.graphics.setColor(0, 0, 0, 0.25)
    drawShape("fill", shape, p.x + 4, p.y + 4, p.w, p.h)

    if shielded then
        local m = 6
        love.graphics.setColor(STEEL)
        drawShape("fill", "armored", p.x - m, p.y - m, p.w + m * 2, p.h + m * 2)
        love.graphics.setColor(STEEL_DARK)
        love.graphics.setLineWidth(2)
        drawShape("line", "armored", p.x - m, p.y - m, p.w + m * 2, p.h + m * 2)
        -- rebites nas laterais da moldura
        for _, rx in ipairs({ p.x - m / 2, p.x + p.w + m / 2 }) do
            love.graphics.setColor(STEEL_DARK)
            love.graphics.circle("fill", rx, p.y + p.h / 2, 2.5)
        end
    end

    love.graphics.setColor(r, g, b)
    drawShape("fill", shape, p.x, p.y, p.w, p.h)

    if p.kind == "boss" then
        love.graphics.setColor(BOSS_GOLD)
        love.graphics.setLineWidth(4)
    elseif shielded then
        love.graphics.setColor(STEEL_DARK)
        love.graphics.setLineWidth(2)
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(3)
    end
    drawShape("line", shape, p.x, p.y, p.w, p.h)

    drawCrack(p)
    if p.kind == "boss" then drawHorns(p) end
    if p.maxHp > 1 then drawHpPips(p) end

    -- estrela girando no poder
    if p.kind == "power" then
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.push()
        love.graphics.translate(p.x + p.w - 14, p.y - 2)
        love.graphics.rotate(now * 3)
        love.graphics.print("*", -5, -8)
        love.graphics.pop()
    end

    local font = assets.fonts.problem
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.printf(p.text, p.x + 2, p.y + (p.h - font:getHeight()) / 2 + 2, p.w, "center")
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(p.text, p.x, p.y + (p.h - font:getHeight()) / 2, p.w, "center")
end

local function drawWizard(cast)
    local x, feetY = layout.wizardFeet()
    local castT = math.min(1, cast / 0.25) -- 1 = acabou de lançar, 0 = parado
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

local function drawProjectiles(list)
    for _, proj in ipairs(list) do
        local progress = math.min(1, proj.t / proj.life)
        local x = proj.x + (proj.tx - proj.x) * progress
        local y = proj.y + (proj.ty - proj.y) * progress - math.sin(progress * math.pi) * 40

        love.graphics.setColor(proj.color[1], proj.color[2], proj.color[3], 0.4)
        love.graphics.circle("fill", x, y, 13)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", x, y, 6)
    end
end

local function drawParticles(list)
    for _, particle in ipairs(list) do
        local alpha = 1 - particle.t / particle.life
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        love.graphics.rectangle("fill", particle.x, particle.y, particle.size, particle.size)
    end
end

-- contador de acertos gigante e translúcido no céu, atrás das contas:
-- dá pra ver de relance sem disputar atenção com o que está caindo
local function drawHitCounter()
    local W = layout.W
    local round = game.round
    local font = assets.fonts.counter
    local cy = (layout.HUD_H + layout.GROUND_Y) / 2
    local scale = 1 + round.hitPulse * 0.12

    love.graphics.push()
    love.graphics.translate(W / 2, cy)
    love.graphics.scale(scale)
    love.graphics.setFont(font)
    love.graphics.setColor(0.15, 0.25, 0.4, 0.12 + round.hitPulse * 0.1)
    love.graphics.printf(tostring(round.hits), -W / 2, -font:getHeight() / 2, W, "center")
    love.graphics.pop()

    love.graphics.setFont(assets.fonts.small)
    love.graphics.setColor(0.15, 0.25, 0.4, 0.3)
    love.graphics.printf("ACERTOS", 0, cy + font:getHeight() / 2 + 14, W, "center")
end

-- ícone "||" no canto superior esquerdo (só durante a partida)
local function drawPauseIcon()
    local r = layout.pauseIcon
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.9)
    local bw, bh = 6, r.h * 0.5
    love.graphics.rectangle("fill", r.x + r.w / 2 - bw - 3, r.y + (r.h - bh) / 2, bw, bh, 2, 2)
    love.graphics.rectangle("fill", r.x + r.w / 2 + 3, r.y + (r.h - bh) / 2, bw, bh, 2, 2)
end

local function drawHud()
    local W = layout.W
    local round = game.round

    if game.state == "playing" or game.state == "resuming" then
        drawPauseIcon()
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

    -- combo fica ao lado da caixa, onde o olhar já está ao responder;
    -- enquanto não há combo, o PC mostra a dica de como jogar no lugar
    local sideX = box.x + box.w + 16
    if round.combo >= 2 then
        local tier = theme.combo[math.max(1, math.min(#theme.combo, math.floor(round.combo / 5)))]
        local pop = 1 + round.hitPulse * 0.25
        love.graphics.setFont(assets.fonts.small)
        love.graphics.setColor(tier[1], tier[2], tier[3])
        love.graphics.print("COMBO", sideX, y + 2)
        love.graphics.push()
        love.graphics.translate(sideX, y + box.h - 6)
        love.graphics.scale(pop)
        love.graphics.setFont(assets.fonts.big)
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.print("x" .. round.combo, 2, -assets.fonts.big:getHeight() + 2)
        love.graphics.setColor(tier[1], tier[2], tier[3])
        love.graphics.print("x" .. round.combo, 0, -assets.fonts.big:getHeight())
        love.graphics.pop()
    elseif not MOBILE then
        love.graphics.setFont(assets.fonts.small)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("digite a resposta", sideX, y + 12)
        love.graphics.print("e aperte ENTER", sideX, y + 28)
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
    if game.state ~= "resuming" then drawHitCounter() end
    for _, p in ipairs(round.falling) do drawProblem(p) end
    drawWizard(round.wizardCast)
    drawProjectiles(round.projectiles)
    drawParticles(round.particles)
    drawEffects()
    drawHud()
    if showInput then
        drawInputBox()
        drawKeypad()
    end

    if round.bossBanner > 0 then
        local a = math.min(1, round.bossBanner)
        local wobble = math.sin(love.timer.getTime() * 20) * 4
        printCentered("CUIDADO! CHEFE", assets.fonts.title, layout.GROUND_Y * 0.38 + wobble, { 1, 0.2, 0.25, a })
        printCentered("ACERTE 3 VEZES", assets.fonts.hud, layout.GROUND_Y * 0.38 + 50, { 1, 0.85, 0.2, a })
    elseif round.tip then
        -- plaquinha escura por trás para a dica não sumir sobre as contas
        local a = math.min(1, round.tip.t)
        local font = assets.fonts.hud
        local w, h = font:getWidth(round.tip.text) + 40, 34
        local y = layout.GROUND_Y * 0.3
        love.graphics.setColor(0.1, 0.12, 0.2, 0.75 * a)
        love.graphics.rectangle("fill", (layout.W - w) / 2, y - (h - font:getHeight()) / 2, w, h, h / 2, h / 2)
        love.graphics.setColor(STEEL[1], STEEL[2], STEEL[3], a)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", (layout.W - w) / 2, y - (h - font:getHeight()) / 2, w, h, h / 2, h / 2)
        printCentered(round.tip.text, font, y, { 1, 1, 1, a })
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

-- sobe passando um pouco do ponto e volta: dá o "pop" das animações de entrada
local function easeOutBack(x)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-- progresso 0..1 de uma animação que começa em `delay` e dura `dur`
local function intro(delay, dur)
    return math.max(0, math.min(1, (menu.t - delay) / dur))
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
            local drop = (1 - easeOutBack(k)) * -120
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
            local s = easeOutBack(k)
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

local startHint = MOBILE and "toque na tela" or "ENTER ou ESPACO"
local restartHint = MOBILE and "TOQUE para jogar de novo" or "ENTER para jogar de novo"

-- botão principal: entra com um "pop", respira devagar e cresce com o mouse
local function drawPlayButton(cy)
    local k = intro(1.4, 0.5)
    if k <= 0 then return end
    local W = layout.W
    local w, h = 260, 64
    local now = love.timer.getTime()

    local hover = false
    if not MOBILE and love.mouse then
        local vx, vy = layout.toVirtual(love.mouse.getPosition())
        hover = math.abs(vx - W / 2) <= w / 2 and math.abs(vy - cy) <= h / 2
    end
    local s = easeOutBack(k) * (hover and 1.08 or 1 + math.sin(now * 4) * 0.035)

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
    love.graphics.printf(startHint, 0, cy + h / 2 + 18, W, "center")
end

-- plaquinha do recorde com uma estrela girando ao lado
local function drawRecord(cy)
    local k = intro(1.8, 0.5)
    if k <= 0 then return end
    local W = layout.W
    local font = assets.fonts.hud
    local text = game.highscore > 0 and ("RECORDE  " .. game.highscore) or "SEM RECORDE AINDA"
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

-- botão secundário do rodapé (contorno, sem preenchimento forte) para não
-- competir com o JOGAR; `k` controla a entrada animada
local function drawFooterButton(label, key, k)
    if k <= 0 then return end
    local b = layout.footerButton()
    local hover = false
    if not MOBILE and love.mouse then
        local vx, vy = layout.toVirtual(love.mouse.getPosition())
        hover = vx >= b.x and vx <= b.x + b.w and vy >= b.y and vy <= b.y + b.h
    end
    local y = b.y + (1 - k) * 20

    love.graphics.setColor(1, 1, 1, (hover and 0.25 or 0.1) * k)
    love.graphics.rectangle("fill", b.x, y, b.w, b.h, b.h / 2, b.h / 2)
    love.graphics.setColor(1, 1, 1, (hover and 1 or 0.7) * k)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", b.x, y, b.w, b.h, b.h / 2, b.h / 2)
    local font = assets.fonts.hud
    love.graphics.setFont(font)
    love.graphics.printf(label, b.x, y + (b.h - font:getHeight()) / 2, b.w, "center")

    if key and not MOBILE then
        love.graphics.setFont(assets.fonts.small)
        love.graphics.setColor(1, 1, 1, 0.5 * k)
        love.graphics.print(key, b.x + b.w + 12, y + b.h / 2 - 5)
    end
end

-- "demonstração" ao fundo: contas caindo e o mago estourando algumas
local function drawMenuScene()
    for _, p in ipairs(menu.cards) do drawProblem(p) end
    drawWizard(menu.wizardCast)
    drawProjectiles(menu.projectiles)
    drawParticles(menu.particles)
end

local function drawMenu()
    local W, H = layout.W, layout.H

    drawMenuScene()

    drawOverlay(0.25 + intro(0, 0.6) * 0.2)

    drawTitleLine("CHUVA DE", H * 0.13, 0)
    drawTitleLine("CONTAS", H * 0.13 + 52, 8)

    local sub = intro(0.8, 0.5)
    local subColor = { 1, 1, 1, sub }
    printCentered("Resolva as contas antes", assets.fonts.hud, H * 0.33 + (1 - sub) * 10, subColor)
    printCentered("que elas caiam no chão!", assets.fonts.hud, H * 0.33 + 25 + (1 - sub) * 10, subColor)

    drawOperatorChips(H * 0.49)
    drawPlayButton(H * 0.65)
    drawRecord(H * 0.81)

    drawFooterButton("CREDITOS", "C", intro(2.1, 0.5))

    love.graphics.setFont(assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.printf("v" .. (GAME_VERSION or "?"), 0, H - 20, W - 12, "right")
    if not MOBILE and not WEB then
        love.graphics.printf("ESC para sair", 12, H - 20, W, "left")
    end
end

-- conteúdo dos créditos, de cima para baixo. As linhas "small" cabem em
-- ~48 caracteres (largura do celular). Licenças completas em assets/licenses/.
-- A fonte desenha maiúsculas acentuadas (É, Ú, Ç) com o formato da minúscula,
-- então textos em CAIXA ALTA ficam sem acento; minúsculas acentuam normal.
local CREDITS = {
    { "logo" },
    { "small", "v" .. (GAME_VERSION or "?") },
    { "gap", 40 },
    { "heading", "CRIADO POR" },
    { "text", "Nicolas Pantoja" },
    { "heading", "INSPIRADO EM" },
    { "text", "Magic Touch:" },
    { "text", "Wizard for Hire" },
    { "small", "de Nitrome" },
    { "small", "Jogo independente, sem afiliação" },
    { "small", "com a Nitrome." },
    { "heading", "FONTE" },
    { "text", "Press Start 2P" },
    { "small", "por Cody \"CodeMan38\" Boisclair" },
    { "small", "SIL Open Font License 1.1" },
    { "heading", "SONS E IMAGENS" },
    { "text", "Kenney" },
    { "small", "kenney.nl - licença CC0" },
    { "heading", "MUSICA" },
    { "text", "Chiptune gerado por código" },
    { "small", "nota por nota, direto no jogo" },
    { "heading", "FEITO COM" },
    { "text", "LOVE 11.5 + Lua" },
    { "small", "love2d.org - licença zlib" },
    { "gap", 10 },
    { "small", "Usa LuaJIT, SDL2, FreeType, OpenAL Soft" },
    { "small", "(LGPL), mpg123 (LGPL) e outras bibliotecas." },
    { "small", "Licenças e código-fonte:" },
    { "small", "github.com/love2d/love (license.txt)" },
    { "gap", 10 },
    { "small", "Portions of this software are copyright" },
    { "small", "© The FreeType Project" },
    { "small", "(www.freetype.org). All rights reserved." },
    { "gap", 50 },
    { "chips" },
    { "gap", 30 },
    { "thanks" },
}

local CREDITS_HEIGHT = {
    logo = 110, small = 22, heading = 58, text = 26, chips = 60, thanks = 100,
}

local function creditsItemHeight(item)
    return item[1] == "gap" and item[2] or CREDITS_HEIGHT[item[1]]
end

local creditsTotal = 0
for _, item in ipairs(CREDITS) do creditsTotal = creditsTotal + creditsItemHeight(item) end

local function drawCredits()
    local W, H = layout.W, layout.H
    local now = love.timer.getTime()

    drawMenuScene()
    drawOverlay(0.72)

    -- área onde o texto rola; perto das bordas ele some suavemente
    local top, bottom = H * 0.07 + 52, layout.footerButton().y - 12
    local fade = 50
    -- recomeça quando tudo já passou, como num filme em loop
    local span = creditsTotal + (bottom - top)
    local scroll = menu.creditsScroll % span
    local y = bottom - scroll

    for i, item in ipairs(CREDITS) do
        local kind, h = item[1], creditsItemHeight(item)
        -- o item inteiro precisa caber na área: some antes de tocar as bordas
        local a = math.max(0, math.min(1, (y - top) / fade, (bottom - (y + h)) / fade))
        if a > 0 then
            if kind == "logo" then
                local r, g, b = theme.hue(now * 0.15, 0.55, 1)
                printCentered("CHUVA DE", assets.fonts.title, y + 10, { r, g, b, a })
                printCentered("CONTAS", assets.fonts.title, y + 58, { r, g, b, a })
            elseif kind == "heading" then
                -- cada título ganha a cor de uma operação, em rodízio
                local ops = { "+", "-", "x", "/" }
                local c = theme.op[ops[(i % 4) + 1]]
                printCentered(item[2], assets.fonts.small, y + 30, { c[1] * 0.5 + 0.5, c[2] * 0.5 + 0.5, c[3] * 0.5 + 0.5, a })
                love.graphics.setColor(c[1], c[2], c[3], a)
                love.graphics.rectangle("fill", W / 2 - 20, y + 46, 40, 3, 1, 1)
            elseif kind == "text" then
                printCentered(item[2], assets.fonts.hud, y + 4, { 1, 1, 1, a })
            elseif kind == "small" then
                printCentered(item[2], assets.fonts.small, y + 4, { 1, 1, 1, 0.6 * a })
            elseif kind == "chips" then
                local ops = { { "+", "+" }, { "-", "-" }, { "x", "x" }, { ":", "/" } }
                local size, gap = 40, 14
                local total = #ops * size + (#ops - 1) * gap
                local font = assets.fonts.hud
                love.graphics.setFont(font)
                for j, op in ipairs(ops) do
                    local c = theme.op[op[2]]
                    local cx = (W - total) / 2 + (j - 1) * (size + gap)
                    local cy = y + 8 + math.sin(now * 3 + j) * 5
                    love.graphics.setColor(c[1], c[2], c[3], a)
                    love.graphics.rectangle("fill", cx, cy, size, size, 8, 8)
                    love.graphics.setColor(1, 1, 1, a)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", cx, cy, size, size, 8, 8)
                    love.graphics.printf(op[1], cx, cy + (size - font:getHeight()) / 2 + 1, size, "center")
                end
            elseif kind == "thanks" then
                local pulse = 1 + math.sin(now * 3) * 0.04
                love.graphics.push()
                love.graphics.translate(W / 2, y + 40)
                love.graphics.scale(pulse)
                love.graphics.translate(-W / 2, -(y + 40))
                printCentered("OBRIGADO", assets.fonts.big, y + 14, { 1, 0.85, 0.2, a })
                printCentered("POR JOGAR!", assets.fonts.big, y + 48, { 1, 0.85, 0.2, a })
                love.graphics.pop()
            end
        end
        y = y + h
    end

    -- cabeçalho fixo
    local r, g, b = theme.hue(now * 0.1, 0.4, 1)
    printCentered("CREDITOS", assets.fonts.big, H * 0.07, { r, g, b })
    love.graphics.setColor(r, g, b, 0.6)
    love.graphics.rectangle("fill", W / 2 - 60, H * 0.07 + 36, 120, 3, 1, 1)

    drawFooterButton("VOLTAR", "ESC", 1)
    if not MOBILE then
        love.graphics.setFont(assets.fonts.small)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.printf("setas / roda do mouse para rolar", 0, H - 20, W, "center")
    end
end

local PAUSE_COLORS = {
    resume = { 0.3, 0.8, 0.4 },
    restart = { 0.25, 0.55, 0.95 },
    menu = { 0.95, 0.55, 0.2 },
}

local function drawPause()
    local W, H = layout.W, layout.H
    local round = game.round
    local k = math.min(1, round.pauseT / 0.35)
    drawOverlay(0.6 * k)

    -- título desce de cima com quique e fica flutuando de leve
    local now = love.timer.getTime()
    local ty = H * 0.2 + (1 - easeOutBack(k)) * -80 + math.sin(now * 2) * 3
    printCentered("PAUSADO", assets.fonts.title, ty, { 1, 0.85, 0.2, k })
    printCentered("Acertos: " .. round.hits, assets.fonts.hud, ty + 56, { 1, 1, 1, 0.8 * k })

    local mx, my
    if not MOBILE and love.mouse then
        mx, my = layout.toVirtual(love.mouse.getPosition())
    end

    local font = assets.fonts.big
    for i, b in ipairs(layout.pauseButtons()) do
        local bk = math.max(0, math.min(1, (round.pauseT - 0.1 - i * 0.07) / 0.3))
        if bk > 0 then
            local hover = mx and mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
            local c = PAUSE_COLORS[b.id]
            local bright = hover and 1.12 or 1
            local sc = easeOutBack(bk) * (hover and 1.05 or 1)

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

            if not MOBILE then
                love.graphics.setFont(assets.fonts.small)
                love.graphics.setColor(1, 1, 1, 0.6 * bk)
                love.graphics.print(b.key, b.x + b.w + 14, b.y + b.h / 2 - 5)
            end
        end
    end
end

-- "3, 2, 1" gigante ao voltar da pausa: cada número surge grande e encolhe
local function drawResumeCountdown()
    local round = game.round
    local n = math.ceil(round.resumeTimer)
    local frac = round.resumeTimer - (n - 1) -- 1 -> 0 dentro de cada segundo
    drawOverlay(0.25)

    local font = assets.fonts.counter
    local s = 1 + frac * 0.6
    love.graphics.push()
    love.graphics.translate(layout.W / 2, layout.GROUND_Y * 0.45)
    love.graphics.scale(s)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.35 * (1 - frac * 0.5))
    love.graphics.printf(tostring(n), -layout.W / 2 + 5, -font:getHeight() / 2 + 5, layout.W, "center")
    love.graphics.setColor(1, 0.85, 0.2, 1 - frac * 0.5)
    love.graphics.printf(tostring(n), -layout.W / 2, -font:getHeight() / 2, layout.W, "center")
    love.graphics.pop()
end

local function drawGameOver()
    local H = layout.H
    local round = game.round
    drawOverlay(0.7)
    printCentered("FIM DE JOGO", assets.fonts.title, H * 0.25, { 1, 0.35, 0.35 })
    printCentered("Pontos: " .. round.score, assets.fonts.big, H * 0.4)
    printCentered("Acertos: " .. round.hits, assets.fonts.hud, H * 0.48)
    if round.newRecord then
        printCentered("NOVO RECORDE!", assets.fonts.big, H * 0.565, { 1, 0.85, 0.2 })
    else
        printCentered("Recorde: " .. game.highscore, assets.fonts.hud, H * 0.575)
    end
    if round.overDelay <= 0 and love.timer.getTime() % 1 < 0.7 then
        printCentered(restartHint, assets.fonts.hud, H * 0.717)
    end
    if not MOBILE and not WEB then
        printCentered("ESC para sair", assets.fonts.small, H * 0.933)
    end
end

function draw.frame()
    love.graphics.clear(0.1, 0.12, 0.16) -- faixas fora da área do jogo

    -- tremida de tela ao subir de nível / fechar um combo
    local shakeX, shakeY = 0, 0
    -- (sem tremida durante a transição: o jogo fica congelado e a tela ia tremer parada)
    if game.state == "playing" and game.round and game.round.screenShake > 0 and not transition.active() then
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
    elseif game.state == "paused" then
        draw.playing(true)
        drawPause()
    elseif game.state == "resuming" then
        draw.playing(true)
        drawResumeCountdown()
    elseif game.state == "menu" then
        drawMenu()
    elseif game.state == "credits" then
        drawCredits()
    else
        draw.playing(false)
        drawGameOver()
    end
    transition.draw(layout.W, layout.H)
    drawScanlines()

    love.graphics.setScissor()
    love.graphics.pop()
end

return draw
