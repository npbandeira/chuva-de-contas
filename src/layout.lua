-- Resolução virtual e escala para a tela real, além do layout do teclado
-- numérico. PC: 800x600 fixo. Celular: largura 540 e altura segue a
-- proporção da tela.
local layout = {}

layout.HUD_H = 44
layout.W, layout.H = 800, 600
layout.GROUND_Y = 520 -- onde as contas "batem no chão"
layout.view = { scale = 1, ox = 0, oy = 0 }
layout.box = {}  -- caixa de resposta
layout.keys = {} -- teclado numérico na tela (só no celular)

function layout.update()
    local view, box, keys = layout.view, layout.box, layout.keys

    local sx, sy = 0, 0
    local sw, sh = love.graphics.getDimensions()
    if love.window.getSafeArea then
        sx, sy, sw, sh = love.window.getSafeArea() -- evita notch e barra do sistema
    end

    local W, H
    if MOBILE then
        W = 540
        H = math.max(860, math.floor(W * sh / sw))
    else
        W, H = 800, 600
    end

    view.scale = math.min(sw / W, sh / H)
    view.ox = sx + (sw - W * view.scale) / 2
    view.oy = sy + (sh - H * view.scale) / 2

    for i = #keys, 1, -1 do keys[i] = nil end

    local GROUND_Y
    if MOBILE then
        local margin, gap, keyH = 16, 10, 70
        local keyW = (W - margin * 2 - gap * 2) / 3
        local top = H - margin - (keyH * 4 + gap * 3)
        local labels = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK" }
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
        GROUND_Y = 520
        box.w, box.h = 240, 50
        box.x, box.y = (W - box.w) / 2, GROUND_Y + (H - GROUND_Y - box.h) / 2
    end

    layout.W, layout.H, layout.GROUND_Y = W, H, GROUND_Y
end

function layout.toVirtual(x, y)
    local view = layout.view
    return (x - view.ox) / view.scale, (y - view.oy) / view.scale
end

-- pé do mago: um pouco à esquerda da caixa de resposta, na mesma "linha do chão"
function layout.wizardFeet()
    local box = layout.box
    return box.x - 50, box.y + box.h
end

return layout
