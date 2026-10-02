-- Interface por cima da partida: contador de acertos ao fundo, vidas, botão
-- de pausa, caixa de resposta, teclado na tela, avisos e o clarão vermelho.
local assets = require("src.assets")
local config = require("src.config")
local layout = require("src.layout")
local theme = require("src.theme")
local ui = require("src.ui")

local hud = {}

-- contador de acertos gigante e translúcido no céu, atrás das contas:
-- dá pra ver de relance sem disputar atenção com o que está caindo
function hud.drawHitCounter(round)
    local W = layout.W
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

local function drawLives(round)
    local W = layout.W
    for i = 1, round.maxLives do
        local img = i <= round.lives and assets.heart or assets.heartBroken
        local x = W - 16 - (round.maxLives - i + 1) * 36
        if img then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(img, x, 3)
        else
            love.graphics.setColor(i <= round.lives and { 0.9, 0.2, 0.3 } or { 0.4, 0.4, 0.4 })
            love.graphics.circle("fill", x + 16, 22, 12)
        end
    end
end

local function drawInputBox(round)
    local box = layout.box
    local offset = round.shake > 0 and math.sin(round.shake * 60) * 8 or 0
    local x, y = box.x + offset, box.y

    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", x + 4, y + 4, box.w, box.h, 8, 8)
    -- vermelha ao errar, verde ao acertar
    if round.shake > 0 then
        love.graphics.setColor(1, 0.8, 0.8)
    elseif round.okFlash > 0 then
        love.graphics.setColor(0.8, 1, 0.82)
    else
        love.graphics.setColor(1, 1, 1)
    end
    love.graphics.rectangle("fill", x, y, box.w, box.h, 8, 8)
    if round.okFlash > 0 then
        love.graphics.setColor(0.2, 0.7, 0.3)
    else
        love.graphics.setColor(0.2, 0.2, 0.3)
    end
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, box.w, box.h, 8, 8)

    -- barra que esvazia enquanto espera um possível dígito a mais ("1" ou "12"?)
    if round.submitTimer > 0 then
        local k = round.submitTimer / round.submitDelay
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.rectangle("fill", x + 8, y + box.h - 7, (box.w - 16) * k, 4, 2, 2)
    end

    local font = assets.fonts.big
    local cursor = (love.timer.getTime() % 1 < 0.5) and "_" or " "
    love.graphics.setFont(font)
    love.graphics.setColor(0.2, 0.2, 0.3)
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
    elseif not config.mobile and round.hits == 0 then
        -- dica só até o primeiro acerto: depois o jogador já entendeu
        love.graphics.setFont(assets.fonts.small)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("digite a resposta", sideX, y + 12)
        love.graphics.print("ela vai sozinha", sideX, y + 28)
    end
end

local function drawKeypad()
    local font = assets.fonts.big
    love.graphics.setFont(font)
    for _, k in ipairs(layout.keys) do
        local down = k.pressed > 0 and 3 or 0

        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", k.x, k.y + 5, k.w, k.h, 12, 12)
        local dim = down > 0 and 0.8 or 1
        love.graphics.setColor(dim, dim, dim)
        love.graphics.rectangle("fill", k.x, k.y + down, k.w, k.h, 12, 12)
        love.graphics.setColor(0.2, 0.2, 0.3)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", k.x, k.y + down, k.w, k.h, 12, 12)
        love.graphics.printf(k.label, k.x, k.y + down + (k.h - font:getHeight()) / 2, k.w, "center")
    end
end

-- aviso de chefe chegando ou a dica da 1ª conta blindada
local function drawNotice(round)
    if round.bossBanner > 0 then
        local a = math.min(1, round.bossBanner)
        local wobble = math.sin(love.timer.getTime() * 20) * 4
        ui.printCentered("CUIDADO! CHEFE", assets.fonts.title, layout.GROUND_Y * 0.38 + wobble, { 1, 0.2, 0.25, a })
        ui.printCentered("ACERTE 3 VEZES", assets.fonts.hud, layout.GROUND_Y * 0.38 + 50, { 1, 0.85, 0.2, a })
    elseif round.tip then
        -- plaquinha escura por trás para a dica não sumir sobre as contas
        local a = math.min(1, round.tip.t)
        local font = assets.fonts.hud
        local w, h = font:getWidth(round.tip.text) + 40, 34
        local y = layout.GROUND_Y * 0.3
        local steel = theme.steel
        love.graphics.setColor(0.1, 0.12, 0.2, 0.75 * a)
        love.graphics.rectangle("fill", (layout.W - w) / 2, y - (h - font:getHeight()) / 2, w, h, h / 2, h / 2)
        love.graphics.setColor(steel[1], steel[2], steel[3], a)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", (layout.W - w) / 2, y - (h - font:getHeight()) / 2, w, h, h / 2, h / 2)
        ui.printCentered(round.tip.text, font, y, { 1, 1, 1, a })
    end
end

-- opts.pauseIcon: mostra o botão de pausa; opts.input: caixa e teclado
function hud.draw(round, opts)
    if opts.pauseIcon then drawPauseIcon() end
    drawLives(round)
    if opts.input then
        drawInputBox(round)
        drawKeypad()
    end
    drawNotice(round)

    -- tela vermelha ao perder vida
    if round.flash > 0 then
        love.graphics.setColor(1, 0, 0, round.flash)
        love.graphics.rectangle("fill", 0, 0, layout.W, layout.H)
    end
end

return hud
