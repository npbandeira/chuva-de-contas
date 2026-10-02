-- Partida em andamento: repassa a entrada para a rodada (src/round.lua),
-- pausa, faz a contagem "3, 2, 1" ao voltar da pausa e termina o jogo.
local assets = require("src.assets")
local layout = require("src.layout")
local save = require("src.save")
local statemanager = require("src.statemanager")
local transition = require("src.transition")
local ui = require("src.ui")
local Round = require("src.round")

local play = {}

local RESUME_TIME = 3    -- contagem regressiva ao sair da pausa
local GAMEOVER_HOLD = 0.6 -- segura a tela na conta que caiu antes de cobrir
local KEY_PRESS_TIME = 0.12

local round
local resumeTimer = 0 -- > 0: contagem rolando, jogo congelado para o jogador se situar

-- opts.resume: voltando da pausa (mantém a rodada); senão começa uma nova
function play.enter(_, opts)
    if opts and opts.resume then
        resumeTimer = RESUME_TIME
        assets.play("click")
    else
        round = Round.new()
        resumeTimer = 0
    end
end

local function pause()
    if transition.active() then return end
    statemanager.switch("pause", round)
end

local function resuming()
    return resumeTimer > 0
end

local function updateResume(dt)
    local before = math.ceil(resumeTimer)
    resumeTimer = resumeTimer - dt
    if resumeTimer <= 0 then
        resumeTimer = 0
        assets.play("correct")
    elseif math.ceil(resumeTimer) ~= before then
        assets.play("click")
    end
end

function play.update(dt)
    for _, k in ipairs(layout.keys) do
        k.pressed = math.max(0, k.pressed - dt)
    end

    if resuming() then
        updateResume(dt)
        return
    end
    if transition.active() then return end

    round:update(dt)
    if round:isOver() then
        local newRecord = save.submitScore(round.score)
        transition.to(function()
            statemanager.switch("gameover", round, newRecord)
        end, GAMEOVER_HOLD)
    end
end

-- trocou de janela / app foi para segundo plano: pausa sozinho
function play.focus(focused)
    if not focused then pause() end
end

function play.textinput(t)
    if not resuming() and t:match("^%d$") then
        round:typeDigit(t)
    end
end

function play.keypressed(key)
    -- "escape" também é o botão Voltar do Android
    if key == "escape" or key == "p" then
        pause()
        return
    end
    if resuming() then return end
    if key == "return" or key == "kpenter" then
        round:submitAnswer()
    elseif key == "backspace" then
        round:backspace()
    end
end

local function pressKey(key)
    key.pressed = KEY_PRESS_TIME
    if key.label == "<" then
        round:backspace()
        assets.play("click")
    elseif key.label == "OK" then
        round:submitAnswer()
    else
        round:typeDigit(key.label)
    end
end

function play.pointerpressed(x, y)
    -- área de toque um pouco maior que o ícone, para o dedo acertar fácil
    if ui.inside(layout.pauseIcon, x, y, 10) then
        pause()
        return
    end
    if resuming() then return end
    for _, k in ipairs(layout.keys) do
        if ui.inside(k, x, y) then
            pressKey(k)
            return
        end
    end
end

-- tremida de tela ao subir de nível / fechar um combo
-- (sem tremida na transição: o jogo fica congelado e a tela ia tremer parada)
function play.cameraShake()
    local s = round.screenShake
    if s <= 0 or resuming() or transition.active() then return 0, 0 end
    return (math.random() * 2 - 1) * s * 14, (math.random() * 2 - 1) * s * 14
end

-- "3, 2, 1" gigante ao voltar da pausa: cada número surge grande e encolhe
local function drawResumeCountdown()
    local n = math.ceil(resumeTimer)
    local frac = resumeTimer - (n - 1) -- 1 -> 0 dentro de cada segundo
    ui.overlay(0.25)

    local font = assets.fonts.counter
    local W = layout.W
    local s = 1 + frac * 0.6
    love.graphics.push()
    love.graphics.translate(W / 2, layout.GROUND_Y * 0.45)
    love.graphics.scale(s)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.35 * (1 - frac * 0.5))
    love.graphics.printf(tostring(n), -W / 2 + 5, -font:getHeight() / 2 + 5, W, "center")
    love.graphics.setColor(1, 0.85, 0.2, 1 - frac * 0.5)
    love.graphics.printf(tostring(n), -W / 2, -font:getHeight() / 2, W, "center")
    love.graphics.pop()
end

function play.draw()
    round:draw({ hitCounter = not resuming(), pauseIcon = true, input = true })
    if resuming() then drawResumeCountdown() end
end

return play
