-- Uma conta caindo do céu: o bloco com a pergunta, do tipo normal, blindada
-- (precisa de 2 acertos), poder (estoura tudo) ou chefe (3 acertos).
-- Usada na partida e na demonstração do menu.
local problems = require("src.problems")
local assets = require("src.assets")
local layout = require("src.layout")
local theme = require("src.theme")

local Card = {}
Card.__index = Card

local BOSS_SCALE = 1.35
local POWER_COLOR = { 0.95, 0.8, 0.2 }
local BOSS_COLOR = { 0.55, 0.08, 0.15 }

-- tamanho do bloco segue o texto da conta (o chefe é maior)
local function fit(card)
    local font = assets.fonts.problem
    local mul = (card.kind == "boss") and BOSS_SCALE or 1
    card.w = (font:getWidth(card.text) + 28) * mul
    card.h = (font:getHeight() + 22) * mul
end

-- conta nova do nível `level`, ainda sem posição (x, y) e velocidade
function Card.new(level, kind, hp)
    local card = problems.new(level)
    card.kind = kind or "normal"
    card.hp = hp or 1
    card.maxHp = card.hp
    card.hitFlash = 0
    fit(card)
    return setmetatable(card, Card)
end

-- levou um golpe e não quebrou: "racha" e vira outra pergunta, na mesma posição
function Card:reroll(level)
    local np = problems.new(level)
    self.text, self.answer, self.op, self.a, self.b = np.text, np.answer, np.op, np.a, np.b
    fit(self)
    self.hitFlash = 0.2
end

function Card:center()
    return self.x + self.w / 2, self.y + self.h / 2
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

-- escudinho (usado nos marcadores de vida acima das contas)
local function shieldPoints(cx, cy, s)
    return {
        cx - s, cy - s, cx + s, cy - s, cx + s, cy + s * 0.2,
        cx, cy + s * 1.2, cx - s, cy + s * 0.2,
    }
end

-- marcadores de "golpes que faltam" acima da conta: escudos cheios são
-- acertos que ainda precisa, vazios são os que já foram
function Card:drawHpPips()
    local boss = self.kind == "boss"
    local s = 8
    local gap = 22
    local total = (self.maxHp - 1) * gap
    local y = self.y - (boss and 26 or 22)
    for i = 1, self.maxHp do
        local cx = self.x + self.w / 2 - total / 2 + (i - 1) * gap
        local pts = shieldPoints(cx, y, s)
        if i <= self.hp then
            love.graphics.setColor(boss and { 0.9, 0.15, 0.2 } or theme.steel)
            love.graphics.polygon("fill", pts)
            love.graphics.setColor(boss and theme.bossGold or theme.steelDark)
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
function Card:drawCrack()
    if self.maxHp > 1 and self.hp < self.maxHp then
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.setLineWidth(2)
        love.graphics.line(self.x + 6, self.y + self.h * 0.25, self.x + self.w * 0.5, self.y + self.h * 0.75,
            self.x + self.w - 6, self.y + self.h * 0.2)
    end
end

-- chifres nos cantos de cima do chefe
function Card:drawHorns()
    local y = self.y + 2
    local left = { self.x + 10, y, self.x + 30, y, self.x + 2, y - 20 }
    local right = { self.x + self.w - 10, y, self.x + self.w - 30, y, self.x + self.w - 2, y - 20 }
    for _, pts in ipairs({ left, right }) do
        love.graphics.setColor(0.96, 0.92, 0.82)
        love.graphics.polygon("fill", pts)
        love.graphics.setColor(0.35, 0.1, 0.12)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", pts)
    end
end

function Card:draw()
    local GROUND_Y = layout.GROUND_Y
    local now = love.timer.getTime()
    local c = theme.op[self.op]
    if self.kind == "boss" then
        c = BOSS_COLOR
    elseif self.kind == "power" then
        c = POWER_COLOR
    end

    -- fica mais vermelha conforme se aproxima do chão
    local danger = math.max(0, (self.y + self.h - GROUND_Y * 0.55) / (GROUND_Y * 0.45))
    local r = c[1] + (0.9 - c[1]) * danger
    local g = c[2] * (1 - danger * 0.8)
    local b = c[3] * (1 - danger * 0.8)

    -- blindada com o escudo ainda inteiro ganha uma moldura de aço
    local shielded = self.kind == "armored" and self.hp == self.maxHp

    if self.kind == "boss" then
        -- aura de pontas girando atrás do chefe, pulsando
        local pulse = (math.sin(now * 5) + 1) * 0.5
        love.graphics.setColor(0.9, 0.1, 0.15, 0.3 + pulse * 0.2 + self.hitFlash * 2)
        love.graphics.polygon("fill", spikyPoints(self.x + self.w / 2, self.y + self.h / 2,
            self.w / 2 + 22 + pulse * 4, self.h / 2 + 22 + pulse * 4, 12, now * 0.8))
    end

    -- brilho neon por trás do bloco (mais forte logo após levar um golpe;
    -- o poder também pulsa sozinho pra chamar atenção)
    local glow = 0.35 + self.hitFlash * 1.5
    if self.kind == "power" then
        glow = glow + (math.sin(now * 6) + 1) * 0.12
    end
    local shape = self.kind == "boss" and "normal" or self.kind
    love.graphics.setColor(r, g, b, glow)
    drawShape("fill", shape, self.x - 6, self.y - 6, self.w + 12, self.h + 12)

    love.graphics.setColor(0, 0, 0, 0.25)
    drawShape("fill", shape, self.x + 4, self.y + 4, self.w, self.h)

    if shielded then
        local m = 6
        love.graphics.setColor(theme.steel)
        drawShape("fill", "armored", self.x - m, self.y - m, self.w + m * 2, self.h + m * 2)
        love.graphics.setColor(theme.steelDark)
        love.graphics.setLineWidth(2)
        drawShape("line", "armored", self.x - m, self.y - m, self.w + m * 2, self.h + m * 2)
        -- rebites nas laterais da moldura
        for _, rx in ipairs({ self.x - m / 2, self.x + self.w + m / 2 }) do
            love.graphics.setColor(theme.steelDark)
            love.graphics.circle("fill", rx, self.y + self.h / 2, 2.5)
        end
    end

    love.graphics.setColor(r, g, b)
    drawShape("fill", shape, self.x, self.y, self.w, self.h)

    if self.kind == "boss" then
        love.graphics.setColor(theme.bossGold)
        love.graphics.setLineWidth(4)
    elseif shielded then
        love.graphics.setColor(theme.steelDark)
        love.graphics.setLineWidth(2)
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(3)
    end
    drawShape("line", shape, self.x, self.y, self.w, self.h)

    self:drawCrack()
    if self.kind == "boss" then self:drawHorns() end
    if self.maxHp > 1 then self:drawHpPips() end

    -- estrela girando no poder
    if self.kind == "power" then
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.push()
        love.graphics.translate(self.x + self.w - 14, self.y - 2)
        love.graphics.rotate(now * 3)
        love.graphics.print("*", -5, -8)
        love.graphics.pop()
    end

    local font = assets.fonts.problem
    local textY = self.y + (self.h - font:getHeight()) / 2
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.printf(self.text, self.x + 2, textY + 2, self.w, "center")
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(self.text, self.x, textY, self.w, "center")
end

return Card
