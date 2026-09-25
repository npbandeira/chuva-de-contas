-- Estado e regras da partida: pontuação, nível, vidas, contas em queda,
-- combo e as partículas que aparecem ao acertar.
local problems = require("problems")
local assets = require("src.assets")
local layout = require("src.layout")
local theme = require("src.theme")

local game = {}

game.MAX_LIVES = 3
local HITS_PER_LEVEL = 10
local COMBO_STEP = 5 -- a cada N acertos em sequência, comemoração extra

game.state = "menu"
game.highscore = 0
game.round = nil

local function addEffect(x, y, text, color, big)
    local round = game.round
    table.insert(round.effects, {
        x = x, y = y, text = text, color = color,
        t = 0, life = big and 1.1 or 0.8, big = big,
    })
end

local function spawnParticles(x, y, color)
    local round = game.round
    for _ = 1, 16 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(60, 240)
        table.insert(round.particles, {
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

function game.loadHighscore()
    local content = love.filesystem.read("highscore.txt")
    game.highscore = tonumber(content) or 0
end

local function saveHighscore()
    local round = game.round
    if round.score > game.highscore then
        game.highscore = round.score
        love.filesystem.write("highscore.txt", tostring(game.highscore))
        round.newRecord = true
    end
end

function game.start()
    game.round = {
        score = 0,
        level = 1,
        hits = 0,
        combo = 0,
        lives = game.MAX_LIVES,
        falling = {},
        effects = {},
        particles = {},
        input = "",
        spawnTimer = 0,
        shake = 0,       -- tremida da caixa de resposta ao errar
        screenShake = 0, -- tremida da tela toda ao subir de nível / combo
        flash = 0,       -- tela vermelha ao perder vida
        levelBanner = 2, -- mostra "NÍVEL 1" no começo
        overDelay = 0,   -- evita reiniciar sem querer logo após perder
        newRecord = false,
    }
    game.state = "playing"
end

function game.tryStart()
    if game.state == "menu" or (game.state == "gameover" and game.round.overDelay <= 0) then
        game.start()
    end
end

local function spawnInterval()
    local round = game.round
    return math.max(0.9, 2.6 - (round.level - 1) * 0.2)
end

local function spawnProblem()
    local round = game.round
    local p = problems.new(round.level)
    local font = assets.fonts.problem
    p.w = font:getWidth(p.text) + 28
    p.h = font:getHeight() + 22

    -- procura um X que não sobreponha contas que acabaram de nascer
    local x
    for _ = 1, 20 do
        local tryX = math.random(20, layout.W - p.w - 20)
        local clear = true
        for _, o in ipairs(round.falling) do
            if o.y < p.h * 1.5 and tryX < o.x + o.w + 10 and o.x < tryX + p.w + 10 then
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
    p.x = x
    p.y = -p.h
    p.speed = (28 + round.level * 7 + math.random(0, 12)) * fallScale
    table.insert(round.falling, p)
    return true
end

function game.typeDigit(d)
    local round = game.round
    if #round.input < 4 then
        round.input = round.input .. d
        assets.play("click")
    end
end

function game.backspace()
    local round = game.round
    round.input = round.input:sub(1, -2)
end

local function breakCombo()
    game.round.combo = 0
end

function game.submitAnswer()
    local round = game.round
    if round.input == "" then return end
    local value = tonumber(round.input)
    round.input = ""

    -- procura a conta mais baixa (mais perigosa) com essa resposta
    local best
    for i, p in ipairs(round.falling) do
        if p.answer == value and (not best or p.y > round.falling[best].y) then
            best = i
        end
    end

    if best then
        local p = table.remove(round.falling, best)
        round.combo = round.combo + 1
        local bonus = 10 * round.level + (round.combo - 1) * 2 -- combo dá pontos extras
        round.score = round.score + bonus
        round.hits = round.hits + 1
        addEffect(p.x + p.w / 2, p.y + p.h / 2, "+" .. bonus, { 0.2, 0.75, 0.3 })
        spawnParticles(p.x + p.w / 2, p.y + p.h / 2, theme.op[p.op])

        if round.combo % COMBO_STEP == 0 then
            local tier = theme.combo[math.min(#theme.combo, math.floor(round.combo / COMBO_STEP))]
            addEffect(layout.W / 2, layout.H * 0.3, "COMBO x" .. round.combo, tier, true)
            round.screenShake = 0.25
            assets.play("combo")
        end

        if round.hits % HITS_PER_LEVEL == 0 then
            round.level = round.level + 1
            round.levelBanner = 2
            round.screenShake = 0.3
            assets.play("levelUp")
        else
            assets.play("correct")
        end
    else
        round.shake = 0.35
        breakCombo()
        assets.play("wrong")
    end
end

local function loseLife(p)
    local round = game.round
    round.lives = round.lives - 1
    round.flash = 0.3
    breakCombo()
    addEffect(p.x + p.w / 2, layout.GROUND_Y - 20, p.text .. " = " .. p.answer, { 0.85, 0.2, 0.2 })

    if round.lives <= 0 then
        saveHighscore()
        assets.play("gameOver")
        round.overDelay = 1
        game.state = "gameover"
    else
        assets.play("loseLife")
    end
end

local function updateParticles(dt)
    local round = game.round
    for i = #round.particles, 1, -1 do
        local particle = round.particles[i]
        particle.t = particle.t + dt
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.vy = particle.vy + 320 * dt -- gravidade leve
        if particle.t >= particle.life then
            table.remove(round.particles, i)
        end
    end
end

function game.update(dt)
    if game.state == "gameover" then game.round.overDelay = game.round.overDelay - dt end
    if game.state ~= "playing" then return end
    local round = game.round

    round.spawnTimer = round.spawnTimer - dt
    if round.spawnTimer <= 0 then
        round.spawnTimer = spawnProblem() and spawnInterval() or 0.2
    end

    for i = #round.falling, 1, -1 do
        local p = round.falling[i]
        p.y = p.y + p.speed * dt
        if p.y + p.h >= layout.GROUND_Y then
            table.remove(round.falling, i)
            loseLife(p)
            if game.state ~= "playing" then return end
        end
    end

    for i = #round.effects, 1, -1 do
        local e = round.effects[i]
        e.t = e.t + dt
        e.y = e.y - 40 * dt
        if e.t >= e.life then table.remove(round.effects, i) end
    end

    updateParticles(dt)

    round.shake = math.max(0, round.shake - dt)
    round.screenShake = math.max(0, round.screenShake - dt)
    round.flash = math.max(0, round.flash - dt)
    round.levelBanner = math.max(0, round.levelBanner - dt)
end

return game
