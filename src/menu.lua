-- Animação da tela inicial: contas caindo ao fundo e o mago estourando
-- algumas delas, como uma "demonstração" do jogo enquanto ninguém joga.
local problems = require("problems")
local assets = require("src.assets")
local layout = require("src.layout")
local game = require("src.game")
local theme = require("src.theme")
local transition = require("src.transition")

local menu = {}

local SPAWN_EVERY = 1.1
local CAST_EVERY = 1.3
local PROJECTILE_TIME = 0.25
local CREDITS_SPEED = 38 -- px/s da rolagem automática dos créditos

local wasMenu = false

local function reset()
    menu.t = 0 -- tempo desde que a tela inicial abriu (anima a entrada)
    menu.cards = {}
    menu.projectiles = {}
    menu.particles = {}
    menu.spawnTimer = 0.3
    menu.castTimer = CAST_EVERY
    menu.wizardCast = 0
    menu.creditsScroll = 0
end
reset()

function menu.openCredits()
    transition.to(function()
        game.state = "credits"
        menu.creditsScroll = 0
    end)
    assets.play("click")
end

function menu.closeCredits()
    transition.to(function() game.state = "menu" end)
    assets.play("click")
end

-- roda do mouse / setas adiantam ou voltam a rolagem dos créditos
function menu.scrollCredits(dy)
    menu.creditsScroll = math.max(0, menu.creditsScroll + dy)
end

local function burst(x, y, color, count)
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = math.random(50, 200)
        table.insert(menu.particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            color = color,
            size = math.random(3, 6),
            t = 0,
            life = 0.4 + math.random() * 0.35,
        })
    end
end

local function spawnCard()
    local p = problems.new(math.random(1, 3))
    local font = assets.fonts.problem
    p.kind, p.hp, p.maxHp, p.hitFlash = "normal", 1, 1, 0
    p.w = font:getWidth(p.text) + 28
    p.h = font:getHeight() + 22
    -- em telas largas, cai só nas laterais para não passar por cima do título
    local side = layout.W / 2 - 190 - p.w
    if side >= 20 then
        local x = math.random(20, side)
        p.x = math.random() < 0.5 and x or layout.W - p.w - x
    else
        p.x = math.random(20, layout.W - p.w - 20)
    end
    p.y = -p.h
    p.speed = math.random(40, 70)
    table.insert(menu.cards, p)
end

-- o mago mira na conta mais baixa que já desceu um pouco
local function cast()
    local best
    for i, p in ipairs(menu.cards) do
        if p.y > layout.GROUND_Y * 0.3 and (not best or p.y > menu.cards[best].y) then
            best = i
        end
    end
    if not best then return end

    local p = table.remove(menu.cards, best)
    local wx, wy = layout.wizardFeet()
    table.insert(menu.projectiles, {
        x = wx + 14, y = wy - 74,
        tx = p.x + p.w / 2, ty = p.y + p.h / 2,
        t = 0, life = PROJECTILE_TIME,
        color = theme.op[p.op] or { 1, 0.85, 0.2 },
    })
    menu.wizardCast = 0.25
end

function menu.update(dt)
    -- a cena animada continua por trás dos créditos, sem reiniciar
    if game.state ~= "menu" and game.state ~= "credits" then
        wasMenu = false
        return
    end
    if game.state == "credits" and not transition.active() then
        local speed = CREDITS_SPEED
        if love.keyboard.isDown("down") then speed = speed + 260 end
        if love.keyboard.isDown("up") then speed = speed - 300 end
        menu.scrollCredits(speed * dt)
    end
    if not wasMenu then
        reset()
        wasMenu = true
    end

    menu.t = menu.t + dt
    menu.wizardCast = math.max(0, menu.wizardCast - dt)

    menu.spawnTimer = menu.spawnTimer - dt
    if menu.spawnTimer <= 0 then
        spawnCard()
        menu.spawnTimer = SPAWN_EVERY
    end

    menu.castTimer = menu.castTimer - dt
    if menu.castTimer <= 0 then
        cast()
        menu.castTimer = CAST_EVERY
    end

    for i = #menu.cards, 1, -1 do
        local p = menu.cards[i]
        p.y = p.y + p.speed * dt
        if p.y + p.h >= layout.GROUND_Y then
            table.remove(menu.cards, i)
            burst(p.x + p.w / 2, layout.GROUND_Y, { 0.6, 0.6, 0.65 }, 6)
        end
    end

    for i = #menu.projectiles, 1, -1 do
        local proj = menu.projectiles[i]
        proj.t = proj.t + dt
        if proj.t >= proj.life then
            burst(proj.tx, proj.ty, proj.color, 16)
            table.remove(menu.projectiles, i)
        end
    end

    for i = #menu.particles, 1, -1 do
        local particle = menu.particles[i]
        particle.t = particle.t + dt
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.vy = particle.vy + 320 * dt
        if particle.t >= particle.life then table.remove(menu.particles, i) end
    end
end

return menu
