-- Fim de jogo: pontuação, recorde e "jogar de novo", por cima da partida
-- congelada no momento em que a última vida caiu.
local assets = require("src.assets")
local config = require("src.config")
local layout = require("src.layout")
local save = require("src.save")
local statemanager = require("src.statemanager")
local transition = require("src.transition")
local ui = require("src.ui")

local gameover = {}

local RESTART_DELAY = 1 -- evita reiniciar sem querer logo após perder
local RESTART_HINT = config.mobile and "TOQUE para jogar de novo" or "ENTER para jogar de novo"

local round, newRecord
local delay = 0

function gameover.enter(_, finishedRound, isNewRecord)
    round, newRecord = finishedRound, isNewRecord
    delay = RESTART_DELAY
end

function gameover.update(dt)
    delay = delay - dt
end

local function restart()
    if delay > 0 then return end
    transition.to(function() statemanager.switch("play") end)
end

function gameover.keypressed(key)
    if key == "return" or key == "kpenter" or key == "space" then
        restart()
    elseif key == "escape" and not config.web then
        love.event.quit()
    end
end

function gameover.pointerpressed()
    restart()
end

function gameover.draw()
    round:draw({ hitCounter = true, pauseIcon = false, input = false })

    local H = layout.H
    ui.overlay(0.7)
    ui.printCentered("FIM DE JOGO", assets.fonts.title, H * 0.25, { 1, 0.35, 0.35 })
    ui.printCentered("Pontos: " .. round.score, assets.fonts.big, H * 0.4)
    ui.printCentered("Acertos: " .. round.hits, assets.fonts.hud, H * 0.48)
    if newRecord then
        ui.printCentered("NOVO RECORDE!", assets.fonts.big, H * 0.565, { 1, 0.85, 0.2 })
    else
        ui.printCentered("Recorde: " .. save.highscore, assets.fonts.hud, H * 0.575)
    end
    if delay <= 0 and love.timer.getTime() % 1 < 0.7 then
        ui.printCentered(RESTART_HINT, assets.fonts.hud, H * 0.717)
    end
    if not config.mobile and not config.web then
        ui.printCentered("ESC para sair", assets.fonts.small, H * 0.933)
    end
end

return gameover
