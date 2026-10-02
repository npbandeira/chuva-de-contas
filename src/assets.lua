-- Carregamento de imagens, sons e fontes (com fallback gerado por código se
-- algum arquivo faltar) e o "beep"/arpejo sintetizados usados quando falta
-- um arquivo de som ou para o efeito de combo.
local assets = {}

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

-- arpejo curto e ascendente usado para comemorar um combo
local function arpeggio(freqs, noteDur)
    local rate = 44100
    local total = math.floor(rate * noteDur * #freqs)
    local data = love.sound.newSoundData(total, rate, 16, 1)
    for i = 0, total - 1 do
        local t = i / rate
        local idx = math.min(#freqs, math.floor(t / noteDur) + 1)
        local tt = t % noteDur
        local env = math.min(1, tt / 0.005) * math.min(1, (noteDur - tt) / 0.02)
        local wave = (math.sin(2 * math.pi * freqs[idx] * t) >= 0) and 1 or -1
        data:setSample(i, wave * 0.35 * env)
    end
    return love.audio.newSource(data, "static")
end

-- estalo metálico curto, usado quando um inimigo blindado/chefe leva um golpe
-- e ainda não é destruído
local function metalHit()
    local rate = 44100
    local dur = 0.12
    local data = love.sound.newSoundData(math.floor(rate * dur), rate, 16, 1)
    for i = 0, data:getSampleCount() - 1 do
        local t = i / rate
        local env = math.exp(-t * 30)
        local tone = math.sin(2 * math.pi * 900 * t) * 0.4
        local noise = (math.random() * 2 - 1) * 0.3
        data:setSample(i, (tone + noise) * env)
    end
    return love.audio.newSource(data, "static")
end

-- explosão curta usada quando um poder estoura todas as contas na tela
local function boom()
    local rate = 44100
    local dur = 0.35
    local data = love.sound.newSoundData(math.floor(rate * dur), rate, 16, 1)
    for i = 0, data:getSampleCount() - 1 do
        local t = i / rate
        local env = math.exp(-t * 6)
        local freq = math.max(30, 90 - t * 40)
        local tone = math.sin(2 * math.pi * freq * t) * 0.5
        local noise = (math.random() * 2 - 1) * 0.35 * math.exp(-t * 10)
        data:setSample(i, math.max(-1, math.min(1, (tone + noise) * env)))
    end
    return love.audio.newSource(data, "static")
end

local function loadFont(size)
    local ok, font = pcall(love.graphics.newFont, "assets/fonts/PressStart2P.ttf", size)
    font = ok and font or love.graphics.newFont(size)
    font:setFilter("linear", "nearest") -- fonte pixelada continua nítida ao ampliar
    return font
end

function assets.load()
    assets.background = loadImage("assets/images/background.png")
    assets.heart = loadImage("assets/images/heart.png")
    assets.heartBroken = loadImage("assets/images/heart_broken.png")

    assets.fonts = {
        counter = loadFont(120),
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
        combo = arpeggio({ 523.25, 659.25, 783.99, 1046.50 }, 0.07), -- C5 E5 G5 C6
        hit = metalHit(),
        boom = boom(),
    }
end

function assets.play(name)
    local s = assets.sounds[name]
    if s then
        s:stop()
        s:play()
    end
end

return assets
