-- Uma partida: pontuação, nível, vidas, contas em queda, combo, feitiços,
-- partículas e textos flutuantes. Só regras e desenho da cena; quem decide
-- pausar, terminar ou trocar de tela é o states/play.lua.
local assets = require("src.assets")
local hud = require("src.hud")
local layout = require("src.layout")
local particles = require("src.particles")
local theme = require("src.theme")
local Card = require("src.entities.card")
local Spell = require("src.entities.spell")
local wizard = require("src.entities.wizard")

local Round = {}
Round.__index = Round

local MAX_LIVES = 3
local HITS_PER_LEVEL = 10
local COMBO_STEP = 5         -- a cada N acertos em sequência, comemoração extra
local SPELL_TIME = 0.18      -- tempo de voo do feitiço até a conta
local MAX_DIGITS = 4
-- quando o que foi digitado já acerta uma conta mas ainda pode virar outra
-- resposta (ex.: "1" com um 12 na tela), espera um instante por mais um dígito
local AUTO_SUBMIT_DELAY = 0.45

local GREEN = { 0.2, 0.75, 0.3 }
local GOLD = { 1, 0.85, 0.2 }
local RED = { 0.85, 0.2, 0.2 }

function Round.new()
    return setmetatable({
        score = 0,
        level = 1,
        hits = 0,
        combo = 0,
        lives = MAX_LIVES,
        maxLives = MAX_LIVES,
        falling = {},
        effects = {},
        particles = {},
        spells = {},
        wizardCast = 0,      -- tempo restante da pose de lançar feitiço
        bossPending = false, -- true logo após subir pra um nível múltiplo de 3
        bossBanner = 0,      -- mostra o aviso de chefe chegando
        tip = nil,           -- dica curta na 1ª vez que aparece uma blindada
        seenArmored = false,
        input = "",
        submitTimer = 0, -- > 0: resposta certa digitada, esperando um possível dígito a mais
        submitDelay = AUTO_SUBMIT_DELAY,
        okFlash = 0,     -- caixa de resposta fica verde ao acertar
        spawnTimer = 0,
        shake = 0,       -- tremida da caixa de resposta ao errar
        screenShake = 0, -- tremida da tela toda ao subir de nível / combo
        flash = 0,       -- tela vermelha ao perder vida
        hitPulse = 0,    -- "pulo" do contador de acertos ao fundo
    }, Round)
end

function Round:isOver()
    return self.lives <= 0
end

-- texto que sobe e some (pontos, combo, resposta certa da conta perdida)
function Round:addEffect(x, y, text, color, big)
    table.insert(self.effects, {
        x = x, y = y, text = text, color = color,
        t = 0, life = big and 1.1 or 0.8, big = big,
    })
end

function Round:spawnInterval()
    return math.max(0.9, 2.6 - (self.level - 1) * 0.2)
end

-- decide se a próxima conta é normal, blindada (2 acertos), um poder (bônus)
-- ou o chefe do nível (só quando bossPending estiver ligado)
function Round:rollKind()
    if self.bossPending then
        return "boss", 3
    end
    local roll = math.random()
    if roll < 0.07 then
        return "power", 1
    elseif self.level >= 2 and roll < 0.07 + 0.15 then
        return "armored", 2
    end
    return "normal", 1
end

-- devolve false se não achou espaço livre no alto da tela
function Round:spawnCard()
    local kind, hp = self:rollKind()
    local card = Card.new(self.level, kind, hp)

    -- procura um X que não sobreponha contas que acabaram de nascer
    local x
    for _ = 1, 20 do
        local tryX = math.random(20, layout.W - card.w - 20)
        local clear = true
        for _, o in ipairs(self.falling) do
            if o.y < card.h * 1.5 and tryX < o.x + o.w + 10 and o.x < tryX + card.w + 10 then
                clear = false
                break
            end
        end
        if clear then
            x = tryX
            break
        end
    end
    if not x then return false end -- sem espaço agora, tenta de novo logo mais

    -- a velocidade acompanha a altura da área de queda (telas altas no celular)
    local fallScale = (layout.GROUND_Y - layout.HUD_H) / (520 - layout.HUD_H)
    local speedMul = (kind == "boss") and 0.65 or 1
    card.x = x
    card.y = -card.h
    card.speed = (28 + self.level * 7 + math.random(0, 12)) * fallScale * speedMul
    table.insert(self.falling, card)

    if kind == "armored" and not self.seenArmored then
        self.seenArmored = true
        self.tip = { text = "BLINDADA: ACERTE " .. hp .. " VEZES", t = 3 }
    end

    if kind == "boss" then
        self.bossPending = false
        self.bossBanner = 2.5
        assets.play("levelUp")
    end
    return true
end

-- compara o que foi digitado com as contas na tela: `exact` se alguma tem
-- essa resposta, `longer` se alguma resposta maior começa com esses dígitos
function Round:matchInput()
    local exact, longer = false, false
    for _, card in ipairs(self.falling) do
        local answer = tostring(card.answer)
        if answer == self.input then
            exact = true
        elseif answer:sub(1, #self.input) == self.input then
            longer = true
        end
    end
    return exact, longer
end

-- a resposta vai sozinha, sem precisar de ENTER/OK: na hora quando não há
-- dúvida, depois de um instante quando ainda pode crescer, e conta como erro
-- quando nenhuma conta na tela começa com esses dígitos
function Round:checkInput()
    self.submitTimer = 0
    if self.input == "" then return end
    local exact, longer = self:matchInput()
    if exact and longer then
        self.submitTimer = AUTO_SUBMIT_DELAY
    elseif exact or not longer then
        self:submitAnswer()
    end
end

function Round:typeDigit(d)
    if #self.input < MAX_DIGITS then
        self.input = self.input .. d
        assets.play("click")
        self:checkInput()
    end
end

-- apagar nunca conta como erro; se sobrar uma resposta certa, ela vai depois do instante de espera
function Round:backspace()
    self.input = self.input:sub(1, -2)
    self.submitTimer = 0
    if self.input ~= "" and self:matchInput() then
        self.submitTimer = AUTO_SUBMIT_DELAY
    end
end

-- poder coletado: estoura todas as outras contas na tela em cadeia
function Round:triggerNuke()
    for _, other in ipairs(self.falling) do
        local bonus = 5 * self.level
        local cx, cy = other:center()
        self.score = self.score + bonus
        self:addEffect(cx, cy, "+" .. bonus, GOLD)
        particles.burst(self.particles, cx, cy, theme.op[other.op] or { 1, 1, 1 }, 10)
    end
    self.falling = {}
    self.screenShake = 0.5
    assets.play("boom")
end

-- conta destruída: o mago lança um feitiço e ela só estoura quando ele chega
function Round:destroy(index, bonus)
    local card = table.remove(self.falling, index)
    table.insert(self.spells, Spell.new(card, SPELL_TIME, "+" .. bonus))
    self.wizardCast = wizard.CAST_TIME

    if card.kind == "power" then
        self:triggerNuke()
    elseif card.kind == "boss" then
        self.screenShake = 0.4
    end
end

-- golpe numa conta de várias vidas que ainda não quebrou
function Round:damage(card, bonus)
    card:reroll(self.level)
    -- estilhaços: de aço quando o escudo quebra, vermelhos no chefe
    local cx, cy = card:center()
    if card.kind == "armored" then
        particles.burst(self.particles, cx, cy, theme.steel, 22)
    else
        particles.burst(self.particles, cx, cy, { 0.9, 0.15, 0.2 }, 14)
        self.screenShake = 0.15
    end
    self:addEffect(cx, card.y, "+" .. bonus, GREEN)
    assets.play("hit")
end

function Round:submitAnswer()
    if self.input == "" then return end
    local value = tonumber(self.input)
    self.input = ""
    self.submitTimer = 0

    -- procura a conta mais baixa (mais perigosa) com essa resposta
    local best
    for i, card in ipairs(self.falling) do
        if card.answer == value and (not best or card.y > self.falling[best].y) then
            best = i
        end
    end

    if not best then
        self.shake = 0.35
        self.combo = 0
        assets.play("wrong")
        return
    end

    local card = self.falling[best]
    self.combo = self.combo + 1
    local bonus = 10 * self.level + (self.combo - 1) * 2 -- combo dá pontos extras
    if card.kind == "boss" then
        bonus = bonus * 3
    elseif card.kind == "armored" then
        bonus = math.floor(bonus * 1.4)
    end
    self.score = self.score + bonus
    self.hits = self.hits + 1
    self.hitPulse = 1
    self.okFlash = 0.25
    card.hp = card.hp - 1
    local destroyed = card.hp <= 0

    if destroyed then
        self:destroy(best, bonus)
    else
        self:damage(card, bonus)
    end

    local leveledUp = false
    if self.hits % HITS_PER_LEVEL == 0 then
        leveledUp = true
        self.level = self.level + 1
        self.screenShake = 0.3
        if self.level % 3 == 0 then self.bossPending = true end
        assets.play("levelUp")
    end

    if self.combo % COMBO_STEP == 0 then
        local tier = theme.combo[math.min(#theme.combo, math.floor(self.combo / COMBO_STEP))]
        self:addEffect(layout.W / 2, layout.H * 0.3, "COMBO x" .. self.combo, tier, true)
        self.screenShake = 0.25
        assets.play("combo")
    elseif destroyed and not leveledUp then
        assets.play("correct")
    end
end

function Round:loseLife(card)
    self.lives = self.lives - 1
    self.flash = 0.3
    self.combo = 0
    self:addEffect(card.x + card.w / 2, layout.GROUND_Y - 20, card.text .. " = " .. card.answer, RED)
    assets.play(self:isOver() and "gameOver" or "loseLife")
end

function Round:update(dt)
    if self:isOver() then return end

    self.spawnTimer = self.spawnTimer - dt
    if self.spawnTimer <= 0 then
        self.spawnTimer = self:spawnCard() and self:spawnInterval() or 0.2
    end

    for i = #self.falling, 1, -1 do
        local card = self.falling[i]
        card.y = card.y + card.speed * dt
        card.hitFlash = math.max(0, card.hitFlash - dt)
        if card.y + card.h >= layout.GROUND_Y then
            table.remove(self.falling, i)
            self:loseLife(card)
            if self:isOver() then return end
        end
    end

    if self.submitTimer > 0 then
        self.submitTimer = self.submitTimer - dt
        -- se a conta caiu enquanto esperava, a resposta fica na caixa
        if self.submitTimer <= 0 and self:matchInput() then
            self:submitAnswer()
        end
    end

    for i = #self.effects, 1, -1 do
        local e = self.effects[i]
        e.t = e.t + dt
        e.y = e.y - 40 * dt
        if e.t >= e.life then table.remove(self.effects, i) end
    end

    for i = #self.spells, 1, -1 do
        local spell = self.spells[i]
        if spell:update(dt) then
            self:addEffect(spell.tx, spell.ty, spell.text, GREEN)
            particles.burst(self.particles, spell.tx, spell.ty, spell.color)
            table.remove(self.spells, i)
        end
    end

    particles.update(self.particles, dt)

    self.shake = math.max(0, self.shake - dt)
    self.okFlash = math.max(0, self.okFlash - dt)
    self.screenShake = math.max(0, self.screenShake - dt)
    self.flash = math.max(0, self.flash - dt)
    self.hitPulse = math.max(0, self.hitPulse - dt * 4)
    self.bossBanner = math.max(0, self.bossBanner - dt)
    if self.tip then
        self.tip.t = self.tip.t - dt
        if self.tip.t <= 0 then self.tip = nil end
    end
    self.wizardCast = math.max(0, self.wizardCast - dt)
end

function Round:drawEffects()
    for _, e in ipairs(self.effects) do
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

-- opts.hitCounter: contador gigante ao fundo; o resto vai para o hud.draw
function Round:draw(opts)
    if opts.hitCounter then hud.drawHitCounter(self) end
    for _, card in ipairs(self.falling) do card:draw() end
    wizard.draw(self.wizardCast)
    for _, spell in ipairs(self.spells) do spell:draw() end
    particles.draw(self.particles)
    self:drawEffects()
    hud.draw(self, opts)
end

return Round
