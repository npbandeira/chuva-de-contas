-- Chuva de Contas: resolva as contas antes que elas caiam no chão!
local problems = require("problems")

local MOBILE = MOBILE -- definido no conf.lua
local MAX_LIVES = 3
local HITS_PER_LEVEL = 10
local HUD_H = 44
local GROUND_COLOR = { 0.65, 0.6, 0.57 }
local SKY_COLOR = { 0.84, 0.93, 0.96 }

-- Resolução virtual: o jogo é desenhado em W x H e escalado para a tela real.
-- PC: 800x600 fixo. Celular: largura 540 e altura segue a proporção da tela.
local W, H = 800, 600
local GROUND_Y = 520 -- onde as contas "batem no chão"
local view = { scale = 1, ox = 0, oy = 0 }
local box = {}  -- caixa de resposta
local keys = {} -- teclado numérico na tela (só no celular)

local assets = {}
local state = "menu"
local game = {}
local highscore = 0

---------------------------------------------------------------------------
-- Carregamento de assets (com fallback se algum arquivo faltar)
---------------------------------------------------------------------------
local function loadImage(path)
    local ok, img = pcall(love.graphics.newImage, path)
    return ok and img or nil
end

local function beep(freq, duration)
    local rate = 44100
    local data = love.sound.newSoundData(math.floor(rate * duration), rate, 16, 1)
    for i = 0, data:getSampleCount() - 1 do
        local t = i / rate
        data:setSample(i, math.sin(2 * math.pi * freq * t) * 0.3 * (1 - t / duration))
    end
    return love.audio.newSource(data, "static")
end

local function loadSound(path, freq)
    local ok, src = pcall(love.audio.newSource, path, "static")
    return ok and src or beep(freq, 0.2)
end

local function loadFont(size)
    local ok, font = pcall(love.graphics.newFont, "assets/PressStart2P.ttf", size)
    font = ok and font or love.graphics.newFont(size)
    font:setFilter("linear", "nearest") -- fonte pixelada continua nítida ao ampliar
    return font
end

local function play(name)
    local s = assets.sounds[name]
    if s then
        s:stop()
        s:play()
    end
end

---------------------------------------------------------------------------
-- Layout e escala
---------------------------------------------------------------------------
local function updateLayout()
    local sx, sy = 0, 0
    local sw, sh = love.graphics.getDimensions()
    if love.window.getSafeArea then
        sx, sy, sw, sh = love.window.getSafeArea() -- evita notch e barra do sistema
    end

    if MOBILE then
        W = 540
        H = math.max(860, math.floor(W * sh / sw))
    else
        W, H = 800, 600
    end

    view.scale = math.min(sw / W, sh / H)
    view.ox = sx + (sw - W * view.scale) / 2
    view.oy = sy + (sh - H * view.scale) / 2

    if MOBILE then
        local margin, gap, keyH = 16, 10, 70
        local keyW = (W - margin * 2 - gap * 2) / 3
        local top = H - margin - (keyH * 4 + gap * 3)
        local labels = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK" }
        keys = {}
        for i, label in ipairs(labels) do
            local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
            keys[i] = {
                label = label,
                x = margin + col * (keyW + gap),
                y = top + row * (keyH + gap),
                w = keyW,
                h = keyH,
                pressed = 0,
            }
        end
        box.w, box.h = 320, 56
        box.x, box.y = (W - box.w) / 2, top - 12 - box.h
        GROUND_Y = box.y - 14
    else
        keys = {}
        GROUND_Y = 520
        box.w, box.h = 240, 50
        box.x, box.y = (W - box.w) / 2, GROUND_Y + (H - GROUND_Y - box.h) / 2
    end
end

local function toVirtual(x, y)
    return (x - view.ox) / view.scale, (y - view.oy) / view.scale
end

---------------------------------------------------------------------------
-- Estado do jogo
---------------------------------------------------------------------------
local function loadHighscore()
    local content = love.filesystem.read("highscore.txt")
    highscore = tonumber(content) or 0
end

local function saveHighscore()
    if game.score > highscore then
        highscore = game.score
        love.filesystem.write("highscore.txt", tostring(highscore))
        game.newRecord = true
    end
end

local function startGame()
    game = {
        score = 0,
        level = 1,
        hits = 0,
        lives = MAX_LIVES,
        falling = {},
        effects = {},
        input = "",
        spawnTimer = 0,
        shake = 0,        -- tremida da caixa de resposta ao errar
        flash = 0,        -- tela vermelha ao perder vida
        levelBanner = 2,  -- mostra "NÍVEL 1" no começo
        overDelay = 0,    -- evita reiniciar sem querer logo após perder
        newRecord = false,
    }
    state = "playing"
end

local function spawnInterval()
    return math.max(0.9, 2.6 - (game.level - 1) * 0.2)
end

local function spawnProblem()
    local p = problems.new(game.level)
    local font = assets.fonts.problem
    p.w = font:getWidth(p.text) + 28
    p.h = font:getHeight() + 22

    -- procura um X que não sobreponha contas que acabaram de nascer
    local x
    for _ = 1, 20 do
        local tryX = math.random(20, W - p.w - 20)
        local clear = true
        for _, o in ipairs(game.falling) do
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
    local fallScale = (GROUND_Y - HUD_H) / (520 - HUD_H)
    p.x = x
    p.y = -p.h
    p.speed = (28 + game.level * 7 + math.random(0, 12)) * fallScale
    table.insert(game.falling, p)
    return true
end

local function addEffect(x, y, text, color)
    table.insert(game.effects, { x = x, y = y, text = text, color = color, t = 0, life = 0.8 })
end

local function typeDigit(d)
    if #game.input < 4 then
        game.input = game.input .. d
        play("click")
    end
end

local function submitAnswer()
    if game.input == "" then return end
    local value = tonumber(game.input)
    game.input = ""

    -- procura a conta mais baixa (mais perigosa) com essa resposta
    local best
    for i, p in ipairs(game.falling) do
        if p.answer == value and (not best or p.y > game.falling[best].y) then
            best = i
        end
    end

    if best then
        local p = table.remove(game.falling, best)
        game.score = game.score + 10 * game.level
        game.hits = game.hits + 1
        addEffect(p.x + p.w / 2, p.y + p.h / 2, "+" .. (10 * game.level), { 0.2, 0.75, 0.3 })

        if game.hits % HITS_PER_LEVEL == 0 then
            game.level = game.level + 1
            game.levelBanner = 2
            play("levelUp")
        else
            play("correct")
        end
    else
        game.shake = 0.35
        play("wrong")
    end
end

local function loseLife(p)
    game.lives = game.lives - 1
    game.flash = 0.3
    addEffect(p.x + p.w / 2, GROUND_Y - 20, p.text .. " = " .. p.answer, { 0.85, 0.2, 0.2 })

    if game.lives <= 0 then
        saveHighscore()
        play("gameOver")
        game.overDelay = 1
        state = "gameover"
    else
        play("loseLife")
    end
end

local function tryStart()
    if state == "menu" or (state == "gameover" and game.overDelay <= 0) then
        startGame()
    end
end

local function pressKey(key)
    key.pressed = 0.12
    if key.label == "<" then
        game.input = game.input:sub(1, -2)
        play("click")
    elseif key.label == "OK" then
        submitAnswer()
    else
        typeDigit(key.label)
    end
end

-- toque ou clique em (x, y) na tela real
local function pointerPressed(x, y)
    if state ~= "playing" then
        tryStart()
        return
    end
    local vx, vy = toVirtual(x, y)
    for _, k in ipairs(keys) do
        if vx >= k.x and vx <= k.x + k.w and vy >= k.y and vy <= k.y + k.h then
            pressKey(k)
            return
        end
    end
end

---------------------------------------------------------------------------
-- Callbacks do LÖVE
---------------------------------------------------------------------------
function love.load()
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("linear", "linear")

    assets.background = loadImage("assets/images/background.png")
    assets.heart = loadImage("assets/images/heart.png")
    assets.heartBroken = loadImage("assets/images/heart_broken.png")

    assets.fonts = {
        title = loadFont(36),
        big = loadFont(24),
        problem = loadFont(20),
        hud = loadFont(14),
        small = loadFont(10),
    }

    assets.sounds = {
        correct = loadSound("assets/sounds/correct.ogg", 880),
        wrong = loadSound("assets/sounds/wrong.ogg", 220),
        loseLife = loadSound("assets/sounds/lose_life.ogg", 150),
        levelUp = loadSound("assets/sounds/level_up.ogg", 1200),
        gameOver = loadSound("assets/sounds/game_over.ogg", 100),
        click = loadSound("assets/sounds/click.ogg", 600),
    }

    loadHighscore()
    updateLayout()
end

function love.resize()
    updateLayout()
end

function love.update(dt)
    for _, k in ipairs(keys) do k.pressed = math.max(0, k.pressed - dt) end
    if state == "gameover" then game.overDelay = game.overDelay - dt end
    if state ~= "playing" then return end

    game.spawnTimer = game.spawnTimer - dt
    if game.spawnTimer <= 0 then
        game.spawnTimer = spawnProblem() and spawnInterval() or 0.2
    end

    for i = #game.falling, 1, -1 do
        local p = game.falling[i]
        p.y = p.y + p.speed * dt
        if p.y + p.h >= GROUND_Y then
            table.remove(game.falling, i)
            loseLife(p)
            if state ~= "playing" then return end
        end
    end

    for i = #game.effects, 1, -1 do
        local e = game.effects[i]
        e.t = e.t + dt
        e.y = e.y - 40 * dt
        if e.t >= e.life then table.remove(game.effects, i) end
    end

    game.shake = math.max(0, game.shake - dt)
    game.flash = math.max(0, game.flash - dt)
    game.levelBanner = math.max(0, game.levelBanner - dt)
end

function love.textinput(t)
    if state == "playing" and t:match("^%d$") then
        typeDigit(t)
    end
end

function love.keypressed(key)
    -- "escape" também é o botão Voltar do Android
    if key == "escape" then
        if state == "playing" then
            state = "menu"
        else
            love.event.quit()
        end
        return
    end

    if state ~= "playing" then
        if key == "return" or key == "kpenter" or key == "space" then
            tryStart()
        end
    elseif key == "return" or key == "kpenter" then
        submitAnswer()
    elseif key == "backspace" then
        game.input = game.input:sub(1, -2)
    end
end

function love.touchpressed(_, x, y)
    pointerPressed(x, y)
end

function love.mousepressed(x, y, button, istouch)
    -- toques já chegam pelo touchpressed
    if not istouch and button == 1 then
        pointerPressed(x, y)
    end
end

---------------------------------------------------------------------------
-- Desenho (tudo em coordenadas virtuais W x H)
---------------------------------------------------------------------------
local function drawBackground()
    love.graphics.setColor(SKY_COLOR)
    love.graphics.rectangle("fill", 0, 0, W, H)
    if assets.background then
        -- escala pela largura e alinha o chão da imagem com GROUND_Y
        local s = W / assets.background:getWidth()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(assets.background, 0, GROUND_Y - 625 * s, 0, s, s)
        -- no celular a tela é mais alta que a imagem: completa o chão
        love.graphics.setColor(GROUND_COLOR)
        love.graphics.rectangle("fill", 0, GROUND_Y + 80 * s, W, H)
    else
        love.graphics.setColor(GROUND_COLOR)
        love.graphics.rectangle("fill", 0, GROUND_Y, W, H - GROUND_Y)
    end
end

local function printCentered(text, font, y, color)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.printf(text, 3, y + 3, W, "center")
    love.graphics.setColor(color or { 1, 1, 1 })
    love.graphics.printf(text, 0, y, W, "center")
end

local opColors = {
    ["+"] = { 0.25, 0.55, 0.95 },
    ["-"] = { 0.95, 0.55, 0.2 },
    ["x"] = { 0.6, 0.35, 0.85 },
    ["/"] = { 0.2, 0.7, 0.55 },
}

local function drawProblem(p)
    local c = opColors[p.op]
    -- fica mais vermelha conforme se aproxima do chão
    local danger = math.max(0, (p.y + p.h - GROUND_Y * 0.55) / (GROUND_Y * 0.45))
    local r = c[1] + (0.9 - c[1]) * danger
    local g = c[2] * (1 - danger * 0.8)
    local b = c[3] * (1 - danger * 0.8)

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

local function drawHud()
    local font = assets.fonts.hud
    love.graphics.setFont(font)

    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, W, HUD_H)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("PONTOS " .. game.score, 16, 15)
    love.graphics.printf("NIVEL " .. game.level, 0, 15, W, "center")

    for i = 1, MAX_LIVES do
        local img = i <= game.lives and assets.heart or assets.heartBroken
        local x = W - 16 - (MAX_LIVES - i + 1) * 36
        if img then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(img, x, 3)
        else
            love.graphics.setColor(i <= game.lives and { 0.9, 0.2, 0.3 } or { 0.4, 0.4, 0.4 })
            love.graphics.circle("fill", x + 16, 22, 12)
        end
    end
end

local function drawInputBox()
    local offset = game.shake > 0 and math.sin(game.shake * 60) * 8 or 0
    local x, y = box.x + offset, box.y

    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", x + 4, y + 4, box.w, box.h, 8, 8)
    if game.shake > 0 then
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
    love.graphics.printf(game.input .. cursor, x, y + (box.h - font:getHeight()) / 2, box.w, "center")

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
    for _, k in ipairs(keys) do
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
    love.graphics.setFont(assets.fonts.hud)
    for _, e in ipairs(game.effects) do
        local alpha = 1 - e.t / e.life
        love.graphics.setColor(0, 0, 0, alpha * 0.4)
        love.graphics.printf(e.text, e.x - 150 + 2, e.y + 2, 300, "center")
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], alpha)
        love.graphics.printf(e.text, e.x - 150, e.y, 300, "center")
    end
end

local function drawPlaying(showInput)
    for _, p in ipairs(game.falling) do drawProblem(p) end
    drawEffects()
    drawHud()
    if showInput then
        drawInputBox()
        drawKeypad()
    end

    if game.levelBanner > 0 then
        local a = math.min(1, game.levelBanner)
        printCentered("NIVEL " .. game.level, assets.fonts.title, GROUND_Y * 0.38, { 1, 0.85, 0.2, a })
    end

    if game.flash > 0 then
        love.graphics.setColor(1, 0, 0, game.flash)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end
end

local function drawOverlay(alpha)
    love.graphics.setColor(0, 0, 0, alpha or 0.45)
    love.graphics.rectangle("fill", 0, 0, W, H)
end

local startHint = MOBILE and "TOQUE para jogar" or "ENTER para jogar"
local restartHint = MOBILE and "TOQUE para jogar de novo" or "ENTER para jogar de novo"

local function drawMenu()
    drawOverlay()
    printCentered("CHUVA DE", assets.fonts.title, H * 0.2, { 1, 0.85, 0.2 })
    printCentered("CONTAS", assets.fonts.title, H * 0.2 + 50, { 1, 0.85, 0.2 })
    printCentered("Resolva as contas antes", assets.fonts.hud, H * 0.45)
    printCentered("que elas caiam no chao!", assets.fonts.hud, H * 0.45 + 25)
    printCentered("+   -   x   :", assets.fonts.big, H * 0.575, { 0.6, 0.9, 1 })
    if love.timer.getTime() % 1 < 0.7 then
        printCentered(startHint, assets.fonts.big, H * 0.7)
    end
    printCentered("Recorde: " .. highscore, assets.fonts.hud, H * 0.82)
    love.graphics.setFont(assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf("v" .. (GAME_VERSION or "?"), 0, H - 20, W - 12, "right")
    if not MOBILE then
        printCentered("ESC para sair", assets.fonts.small, H * 0.933)
    end
end

local function drawGameOver()
    drawOverlay(0.7)
    printCentered("FIM DE JOGO", assets.fonts.title, H * 0.25, { 1, 0.35, 0.35 })
    printCentered("Pontos: " .. game.score, assets.fonts.big, H * 0.4)
    printCentered("Nivel: " .. game.level .. "   Acertos: " .. game.hits, assets.fonts.hud, H * 0.48)
    if game.newRecord then
        printCentered("NOVO RECORDE!", assets.fonts.big, H * 0.565, { 1, 0.85, 0.2 })
    else
        printCentered("Recorde: " .. highscore, assets.fonts.hud, H * 0.575)
    end
    if game.overDelay <= 0 and love.timer.getTime() % 1 < 0.7 then
        printCentered(restartHint, assets.fonts.hud, H * 0.717)
    end
    if not MOBILE then
        printCentered("ESC para sair", assets.fonts.small, H * 0.933)
    end
end

function love.draw()
    love.graphics.clear(0.1, 0.12, 0.16) -- faixas fora da área do jogo
    love.graphics.push()
    love.graphics.translate(view.ox, view.oy)
    love.graphics.scale(view.scale)
    love.graphics.setScissor(view.ox, view.oy, W * view.scale, H * view.scale)

    drawBackground()
    if state == "playing" then
        drawPlaying(true)
    elseif state == "menu" then
        drawMenu()
    else
        drawPlaying(false)
        drawGameOver()
    end

    love.graphics.setScissor()
    love.graphics.pop()
end
