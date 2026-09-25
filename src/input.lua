-- Entrada do jogador: teclado físico (PC) e teclado numérico na tela
-- (celular), além do toque/clique fora do jogo para começar/reiniciar.
local assets = require("src.assets")
local game = require("src.game")
local layout = require("src.layout")

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

-- toque ou clique em (x, y) na tela real
function input.pointerPressed(x, y)
    if game.state ~= "playing" then
        game.tryStart()
        return
    end
    local vx, vy = layout.toVirtual(x, y)
    for _, k in ipairs(layout.keys) do
        if vx >= k.x and vx <= k.x + k.w and vy >= k.y and vy <= k.y + k.h then
            pressKey(k)
            return
        end
    end
end

function input.textinput(t)
    if game.state == "playing" and t:match("^%d$") then
        game.typeDigit(t)
    end
end

function input.keypressed(key)
    -- "escape" também é o botão Voltar do Android
    if key == "escape" then
        if game.state == "playing" then
            game.state = "menu"
        else
            love.event.quit()
        end
        return
    end

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

return input
