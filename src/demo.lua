-- Cena animada atrás do menu e dos créditos: contas caindo e o mago
-- estourando algumas delas, como uma "demonstração" enquanto ninguém joga.
local layout = require("src.layout")
local particles = require("src.particles")
local Card = require("src.entities.card")
local Spell = require("src.entities.spell")
local wizard = require("src.entities.wizard")

local demo = {}

local SPAWN_EVERY = 1.1
local CAST_EVERY = 1.3
local SPELL_TIME = 0.25
local DUST = { 0.6, 0.6, 0.65 }

local spawnTimer, castTimer

function demo.reset()
    demo.t = 0 -- tempo desde que a cena começou (anima a entrada do menu)
    demo.cards = {}
    demo.spells = {}
    demo.particles = {}
    demo.wizardCast = 0
    spawnTimer = 0.3
    castTimer = CAST_EVERY
end
demo.reset()

local function burst(x, y, color, count)
    particles.burst(demo.particles, x, y, color, count, 50, 200)
end

local function spawnCard()
    local card = Card.new(math.random(1, 3))
    -- em telas largas, cai só nas laterais para não passar por cima do título
    local side = layout.W / 2 - 190 - card.w
    if side >= 20 then
        local x = math.random(20, side)
        card.x = math.random() < 0.5 and x or layout.W - card.w - x
    else
        card.x = math.random(20, layout.W - card.w - 20)
    end
    card.y = -card.h
    card.speed = math.random(40, 70)
    table.insert(demo.cards, card)
end

-- o mago mira na conta mais baixa que já desceu um pouco
local function cast()
    local best
    for i, card in ipairs(demo.cards) do
        if card.y > layout.GROUND_Y * 0.3 and (not best or card.y > demo.cards[best].y) then
            best = i
        end
    end
    if not best then return end

    local card = table.remove(demo.cards, best)
    table.insert(demo.spells, Spell.new(card, SPELL_TIME))
    demo.wizardCast = wizard.CAST_TIME
end

function demo.update(dt)
    demo.t = demo.t + dt
    demo.wizardCast = math.max(0, demo.wizardCast - dt)

    spawnTimer = spawnTimer - dt
    if spawnTimer <= 0 then
        spawnCard()
        spawnTimer = SPAWN_EVERY
    end

    castTimer = castTimer - dt
    if castTimer <= 0 then
        cast()
        castTimer = CAST_EVERY
    end

    for i = #demo.cards, 1, -1 do
        local card = demo.cards[i]
        card.y = card.y + card.speed * dt
        if card.y + card.h >= layout.GROUND_Y then
            table.remove(demo.cards, i)
            burst(card.x + card.w / 2, layout.GROUND_Y, DUST, 6)
        end
    end

    for i = #demo.spells, 1, -1 do
        local spell = demo.spells[i]
        if spell:update(dt) then
            burst(spell.tx, spell.ty, spell.color, 16)
            table.remove(demo.spells, i)
        end
    end

    particles.update(demo.particles, dt)
end

function demo.draw()
    for _, card in ipairs(demo.cards) do card:draw() end
    wizard.draw(demo.wizardCast)
    for _, spell in ipairs(demo.spells) do spell:draw() end
    particles.draw(demo.particles)
end

return demo
