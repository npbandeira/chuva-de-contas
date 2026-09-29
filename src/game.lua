-- Estado e regras da partida: pontuação, nível, vidas, contas em queda,
-- combo e as partículas que aparecem ao acertar.
local problems = require("problems")
local assets = require("src.assets")
local layout = require("src.layout")
local theme = require("src.theme")
local music = require("src.music")
local transition = require("src.transition")

local game = {}

game.MAX_LIVES = 3
local HITS_PER_LEVEL = 10
local COMBO_STEP = 5     -- a cada N acertos em sequência, comemoração extra
local PROJECTILE_TIME = 0.18 -- tempo de voo do feitiço até a conta
local RESUME_TIME = 3        -- contagem regressiva ao sair da pausa

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

local function spawnParticles(x, y, color, count)
    local round = game.round
    for _ = 1, count or 16 do
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
        projectiles = {},
        wizardCast = 0,    -- tempo restante da pose de lançar feitiço
        bossPending = false, -- true logo após subir pra um nível múltiplo de 3
        bossBanner = 0,    -- mostra o aviso de chefe chegando
        tip = nil,         -- dica curta na 1ª vez que aparece uma blindada
        seenArmored = false,
        input = "",
        spawnTimer = 0,
        shake = 0,       -- tremida da caixa de resposta ao errar
        screenShake = 0, -- tremida da tela toda ao subir de nível / combo
        flash = 0,       -- tela vermelha ao perder vida
        hitPulse = 0,    -- "pulo" do contador de acertos ao fundo
        overDelay = 0,   -- evita reiniciar sem querer logo após perder
        pauseT = 0,      -- tempo desde que pausou (anima a tela de pausa)
        resumeTimer = 0, -- contagem "3, 2, 1" antes de voltar a jogar
        newRecord = false,
    }
    game.state = "playing"
    music.duck(false)
end

-- "resuming" congela o jogo durante a contagem, para o jogador se situar
function game.pause()
    if game.state ~= "playing" and game.state ~= "resuming" then return end
    if transition.active() then return end
    game.state = "paused"
    game.round.pauseT = 0
    music.duck(true)
    assets.play("click")
end

function game.resume()
    if game.state ~= "paused" then return end
    game.state = "resuming"
    game.round.resumeTimer = RESUME_TIME
    music.duck(false)
    assets.play("click")
end

-- trocas de tela passam pela transição: a mudança acontece com a tela coberta
function game.restart()
    transition.to(game.start)
end

function game.quitToMenu()
    transition.to(function()
        game.state = "menu"
        music.duck(false)
    end)
end

function game.tryStart()
    if game.state == "menu" or (game.state == "gameover" and game.round.overDelay <= 0) then
        game.restart()
    end
end

local function spawnInterval()
    local round = game.round
    return math.max(0.9, 2.6 - (round.level - 1) * 0.2)
end

-- decide se a próxima conta é normal, blindada (2 acertos), um poder (bônus)
-- ou o chefe do nível (só quando round.bossPending estiver ligado)
local function rollKind(round)
    if round.bossPending then
        return "boss", 3
    end
    local roll = math.random()
    if roll < 0.07 then
        return "power", 1
    elseif round.level >= 2 and roll < 0.07 + 0.15 then
        return "armored", 2
    end
    return "normal", 1
end

local function spawnProblem()
    local round = game.round
    local kind, hp = rollKind(round)

    local p = problems.new(round.level)
    p.kind, p.hp, p.maxHp, p.hitFlash = kind, hp, hp, 0

    local font = assets.fonts.problem
    local sizeMul = (kind == "boss") and 1.35 or 1
    p.w = (font:getWidth(p.text) + 28) * sizeMul
    p.h = (font:getHeight() + 22) * sizeMul

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
    local speedMul = (kind == "boss") and 0.65 or 1
    p.x = x
    p.y = -p.h
    p.speed = (28 + round.level * 7 + math.random(0, 12)) * fallScale * speedMul
    table.insert(round.falling, p)

    if kind == "armored" and not round.seenArmored then
        round.seenArmored = true
        round.tip = { text = "BLINDADA: ACERTE " .. hp .. " VEZES", t = 3 }
    end

    if kind == "boss" then
        round.bossPending = false
        round.bossBanner = 2.5
        assets.play("levelUp")
    end
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

-- poder coletado: estoura todas as outras contas na tela em cadeia
local function triggerNuke()
    local round = game.round
    for _, other in ipairs(round.falling) do
        local bonus = 5 * round.level
        round.score = round.score + bonus
        addEffect(other.x + other.w / 2, other.y + other.h / 2, "+" .. bonus, { 1, 0.85, 0.2 })
        spawnParticles(other.x + other.w / 2, other.y + other.h / 2, theme.op[other.op] or { 1, 1, 1 }, 10)
    end
    round.falling = {}
    round.screenShake = 0.5
    assets.play("boom")
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
        local p = round.falling[best]
        round.combo = round.combo + 1
        local bonus = 10 * round.level + (round.combo - 1) * 2 -- combo dá pontos extras
        if p.kind == "boss" then
            bonus = bonus * 3
        elseif p.kind == "armored" then
            bonus = math.floor(bonus * 1.4)
        end
        round.score = round.score + bonus
        round.hits = round.hits + 1
        round.hitPulse = 1
        p.hp = p.hp - 1
        local destroyed = p.hp <= 0

        if destroyed then
            table.remove(round.falling, best)

            -- o mago lança um feitiço até a conta; ela só estoura quando o feitiço chega
            local wx, wy = layout.wizardFeet()
            table.insert(round.projectiles, {
                x = wx + 14, y = wy - 74,
                tx = p.x + p.w / 2, ty = p.y + p.h / 2,
                t = 0, life = PROJECTILE_TIME,
                color = theme.op[p.op] or { 1, 0.85, 0.2 },
                text = "+" .. bonus,
            })
            round.wizardCast = 0.25

            if p.kind == "power" then
                triggerNuke()
            elseif p.kind == "boss" then
                round.screenShake = 0.4
            end
        else
            -- ainda não destruiu: a conta "racha" e vira outra pergunta, na mesma posição
            local np = problems.new(round.level)
            p.text, p.answer, p.op, p.a, p.b = np.text, np.answer, np.op, np.a, np.b
            local font = assets.fonts.problem
            local sizeMul = (p.kind == "boss") and 1.35 or 1
            p.w = (font:getWidth(p.text) + 28) * sizeMul
            p.hitFlash = 0.2
            -- estilhaços: de aço quando o escudo quebra, vermelhos no chefe
            local cx, cy = p.x + p.w / 2, p.y + p.h / 2
            if p.kind == "armored" then
                spawnParticles(cx, cy, { 0.74, 0.79, 0.86 }, 22)
            else
                spawnParticles(cx, cy, { 0.9, 0.15, 0.2 }, 14)
                round.screenShake = 0.15
            end
            addEffect(p.x + p.w / 2, p.y, "+" .. bonus, { 0.2, 0.75, 0.3 })
            assets.play("hit")
        end

        local leveledUp = false
        if round.hits % HITS_PER_LEVEL == 0 then
            leveledUp = true
            round.level = round.level + 1
            round.screenShake = 0.3
            if round.level % 3 == 0 then round.bossPending = true end
            assets.play("levelUp")
        end

        if round.combo % COMBO_STEP == 0 then
            local tier = theme.combo[math.min(#theme.combo, math.floor(round.combo / COMBO_STEP))]
            addEffect(layout.W / 2, layout.H * 0.3, "COMBO x" .. round.combo, tier, true)
            round.screenShake = 0.25
            assets.play("combo")
        elseif destroyed and not leveledUp then
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
        -- segura a tela um instante na conta que caiu, depois cobre e mostra o fim de jogo
        transition.to(function()
            round.overDelay = 1
            game.state = "gameover"
        end, 0.6)
    else
        assets.play("loseLife")
    end
end

local function updateProjectiles(dt)
    local round = game.round
    for i = #round.projectiles, 1, -1 do
        local proj = round.projectiles[i]
        proj.t = proj.t + dt
        if proj.t >= proj.life then
            addEffect(proj.tx, proj.ty, proj.text, { 0.2, 0.75, 0.3 })
            spawnParticles(proj.tx, proj.ty, proj.color)
            table.remove(round.projectiles, i)
        end
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
    if game.state == "paused" then
        game.round.pauseT = game.round.pauseT + dt
        return
    end
    if game.state == "resuming" then
        local round = game.round
        local before = math.ceil(round.resumeTimer)
        round.resumeTimer = round.resumeTimer - dt
        if round.resumeTimer <= 0 then
            game.state = "playing"
            assets.play("correct")
        elseif math.ceil(round.resumeTimer) ~= before then
            assets.play("click")
        end
        return
    end
    if game.state ~= "playing" or transition.active() then return end
    local round = game.round

    round.spawnTimer = round.spawnTimer - dt
    if round.spawnTimer <= 0 then
        round.spawnTimer = spawnProblem() and spawnInterval() or 0.2
    end

    for i = #round.falling, 1, -1 do
        local p = round.falling[i]
        p.y = p.y + p.speed * dt
        if p.hitFlash > 0 then p.hitFlash = math.max(0, p.hitFlash - dt) end
        if p.y + p.h >= layout.GROUND_Y then
            table.remove(round.falling, i)
            loseLife(p)
            if round.lives <= 0 then return end
        end
    end

    for i = #round.effects, 1, -1 do
        local e = round.effects[i]
        e.t = e.t + dt
        e.y = e.y - 40 * dt
        if e.t >= e.life then table.remove(round.effects, i) end
    end

    updateProjectiles(dt)
    updateParticles(dt)

    round.shake = math.max(0, round.shake - dt)
    round.screenShake = math.max(0, round.screenShake - dt)
    round.flash = math.max(0, round.flash - dt)
    round.hitPulse = math.max(0, round.hitPulse - dt * 4)
    round.bossBanner = math.max(0, round.bossBanner - dt)
    if round.tip then
        round.tip.t = round.tip.t - dt
        if round.tip.t <= 0 then round.tip = nil end
    end
    round.wizardCast = math.max(0, round.wizardCast - dt)
end

return game
