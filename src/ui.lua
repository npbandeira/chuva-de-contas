-- Peças de desenho usadas por várias telas: texto centralizado com sombra,
-- véu escuro, fundo, scanlines, botão do rodapé, hover do mouse e o "pop"
-- das animações de entrada. Tudo em coordenadas virtuais (ver layout.lua).
local assets = require("src.assets")
local config = require("src.config")
local layout = require("src.layout")
local theme = require("src.theme")

local ui = {}

function ui.printCentered(text, font, y, color)
    local W = layout.W
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.35 * (color and color[4] or 1))
    love.graphics.printf(text, 3, y + 3, W, "center")
    love.graphics.setColor(color or { 1, 1, 1 })
    love.graphics.printf(text, 0, y, W, "center")
end

function ui.overlay(alpha)
    love.graphics.setColor(0, 0, 0, alpha or 0.45)
    love.graphics.rectangle("fill", 0, 0, layout.W, layout.H)
end

-- sobe passando um pouco do ponto e volta: dá o "pop" das animações de entrada
function ui.easeOutBack(x)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-- (x, y) dentro do retângulo r, com uma folga opcional em volta
function ui.inside(r, x, y, pad)
    pad = pad or 0
    return x >= r.x - pad and x <= r.x + r.w + pad and y >= r.y - pad and y <= r.y + r.h + pad
end

-- posição do mouse em coordenadas virtuais; nil no celular (lá não há hover)
function ui.mouse()
    if config.mobile or not love.mouse then return nil end
    return layout.toVirtual(love.mouse.getPosition())
end

function ui.hovered(r)
    local mx, my = ui.mouse()
    return mx ~= nil and ui.inside(r, mx, my)
end

function ui.drawBackground()
    local W, H, GROUND_Y = layout.W, layout.H, layout.GROUND_Y
    love.graphics.setColor(theme.sky)
    love.graphics.rectangle("fill", 0, 0, W, H)
    if assets.background then
        -- escala pela largura e alinha o chão da imagem com GROUND_Y
        local s = W / assets.background:getWidth()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(assets.background, 0, GROUND_Y - 625 * s, 0, s, s)
        -- no celular a tela é mais alta que a imagem: completa o chão
        love.graphics.setColor(theme.ground)
        love.graphics.rectangle("fill", 0, GROUND_Y + 80 * s, W, H)
    else
        love.graphics.setColor(theme.ground)
        love.graphics.rectangle("fill", 0, GROUND_Y, W, H - GROUND_Y)
    end
end

-- linhas escuras finas por cima de tudo, para dar a sensação de tela de
-- fósforo/CRT de fliperama
function ui.drawScanlines()
    local W, H = layout.W, layout.H
    love.graphics.setColor(0, 0, 0, 0.08)
    for y = 0, H, 4 do
        love.graphics.rectangle("fill", 0, y, W, 2)
    end
end

-- botão secundário do rodapé (contorno, sem preenchimento forte) para não
-- competir com o JOGAR; `k` controla a entrada animada
function ui.drawFooterButton(label, key, k)
    if k <= 0 then return end
    local b = layout.footerButton()
    local hover = ui.hovered(b)
    local y = b.y + (1 - k) * 20

    love.graphics.setColor(1, 1, 1, (hover and 0.25 or 0.1) * k)
    love.graphics.rectangle("fill", b.x, y, b.w, b.h, b.h / 2, b.h / 2)
    love.graphics.setColor(1, 1, 1, (hover and 1 or 0.7) * k)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", b.x, y, b.w, b.h, b.h / 2, b.h / 2)
    local font = assets.fonts.hud
    love.graphics.setFont(font)
    love.graphics.printf(label, b.x, y + (b.h - font:getHeight()) / 2, b.w, "center")

    if key and not config.mobile then
        love.graphics.setFont(assets.fonts.small)
        love.graphics.setColor(1, 1, 1, 0.5 * k)
        love.graphics.print(key, b.x + b.w + 12, y + b.h / 2 - 5)
    end
end

return ui
