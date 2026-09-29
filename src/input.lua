-- Entrada do jogador: teclado físico (PC) e teclado numérico na tela
-- (celular), além do toque/clique fora do jogo para começar/reiniciar.
local assets = require("src.assets")
local game = require("src.game")
local layout = require("src.layout")
local transition = require("src.transition")
local menu = require("src.menu")

local input = {}

function input.update(dt)
    for _, k in ipairs(layout.keys) do
        k.pressed = math.max(0, k.pressed - dt)
    end
end

local function pressKey(key)
    key.pressed = 0.12
    if key.label == "<" then
        game.backspace()
        assets.play("click")
    elseif key.label == "OK" then
        game.submitAnswer()
    else
        game.typeDigit(key.label)
    end
end

local function inside(r, vx, vy, pad)
    pad = pad or 0
    return vx >= r.x - pad and vx <= r.x + r.w + pad and vy >= r.y - pad and vy <= r.y + r.h + pad
end

local function pauseAction(id)
    if id == "resume" then
        game.resume()
    elseif id == "restart" then
        game.restart()
    elseif id == "menu" then
        game.quitToMenu()
    end
end

-- toque ou clique em (x, y) na tela real
function input.pointerPressed(x, y)
    if transition.active() then return end
    local vx, vy = layout.toVirtual(x, y)
    if game.state == "paused" then
        for _, b in ipairs(layout.pauseButtons()) do
            if inside(b, vx, vy) then
                pauseAction(b.id)
                return
            end
        end
        return
    end
    if game.state == "credits" then
        menu.closeCredits()
        return
    end
    if game.state == "menu" and inside(layout.footerButton(), vx, vy) then
        menu.openCredits()
        return
    end
    if game.state ~= "playing" and game.state ~= "resuming" then
        game.tryStart()
        return
    end
    -- área de toque um pouco maior que o ícone, para o dedo acertar fácil
    if inside(layout.pauseIcon, vx, vy, 10) then
        game.pause()
        return
    end
    if game.state ~= "playing" then return end
    for _, k in ipairs(layout.keys) do
        if inside(k, vx, vy) then
            pressKey(k)
            return
        end
    end
end

function input.textinput(t)
    if transition.active() then return end
    if game.state == "playing" and t:match("^%d$") then
        game.typeDigit(t)
    end
end

function input.keypressed(key)
    if transition.active() then return end
    if game.state == "credits" then
        if key == "escape" or key == "return" or key == "kpenter" or key == "space" or key == "backspace" then
            menu.closeCredits()
        end
        return
    end
    if game.state == "menu" and key == "c" then
        menu.openCredits()
        return
    end

    -- "escape" também é o botão Voltar do Android
    if key == "escape" or key == "p" then
        if game.state == "playing" or game.state == "resuming" then
            game.pause()
        elseif game.state == "paused" then
            game.resume()
        elseif key == "escape" and not WEB then
            love.event.quit()
        end
        return
    end

    if game.state == "paused" then
        if key == "return" or key == "kpenter" or key == "space" then
            pauseAction("resume")
        elseif key == "r" then
            pauseAction("restart")
        elseif key == "m" then
            pauseAction("menu")
        end
        return
    end
    if game.state == "resuming" then return end

    if game.state ~= "playing" then
        if key == "return" or key == "kpenter" or key == "space" then
            game.tryStart()
        end
    elseif key == "return" or key == "kpenter" then
        game.submitAnswer()
    elseif key == "backspace" then
        game.backspace()
    end
end

function input.wheelmoved(dy)
    if game.state == "credits" then menu.scrollCredits(-dy * 40) end
end

return input
