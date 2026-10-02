-- Créditos rolando como num filme, por cima da demonstração do menu.
local assets = require("src.assets")
local config = require("src.config")
local demo = require("src.demo")
local layout = require("src.layout")
local statemanager = require("src.statemanager")
local theme = require("src.theme")
local transition = require("src.transition")
local ui = require("src.ui")

local credits = {}

local SPEED = 38 -- px/s da rolagem automática

-- conteúdo, de cima para baixo. As linhas "small" cabem em ~48 caracteres
-- (largura do celular). Licenças completas em assets/licenses/.
-- A fonte desenha maiúsculas acentuadas (É, Ú, Ç) com o formato da minúscula,
-- então textos em CAIXA ALTA ficam sem acento; minúsculas acentuam normal.
local ITEMS = {
    { "logo" },
    { "small", "v" .. config.VERSION },
    { "gap", 40 },
    { "heading", "CRIADO POR" },
    { "text", "Nicolas Pantoja" },
    { "heading", "INSPIRADO EM" },
    { "text", "Magic Touch:" },
    { "text", "Wizard for Hire" },
    { "small", "de Nitrome" },
    { "small", "Jogo independente, sem afiliação" },
    { "small", "com a Nitrome." },
    { "heading", "FONTE" },
    { "text", "Press Start 2P" },
    { "small", "por Cody \"CodeMan38\" Boisclair" },
    { "small", "SIL Open Font License 1.1" },
    { "heading", "SONS E IMAGENS" },
    { "text", "Kenney" },
    { "small", "kenney.nl - licença CC0" },
    { "heading", "MUSICA" },
    { "text", "Chiptune gerado por código" },
    { "small", "nota por nota, direto no jogo" },
    { "heading", "FEITO COM" },
    { "text", "LOVE 11.5 + Lua" },
    { "small", "love2d.org - licença zlib" },
    { "gap", 10 },
    { "small", "Usa LuaJIT, SDL2, FreeType, OpenAL Soft" },
    { "small", "(LGPL), mpg123 (LGPL) e outras bibliotecas." },
    { "small", "Licenças e código-fonte:" },
    { "small", "github.com/love2d/love (license.txt)" },
    { "gap", 10 },
    { "small", "Portions of this software are copyright" },
    { "small", "© The FreeType Project" },
    { "small", "(www.freetype.org). All rights reserved." },
    { "gap", 50 },
    { "chips" },
    { "gap", 30 },
    { "thanks" },
}

local ITEM_HEIGHT = {
    logo = 110, small = 22, heading = 58, text = 26, chips = 60, thanks = 100,
}

local function itemHeight(item)
    return item[1] == "gap" and item[2] or ITEM_HEIGHT[item[1]]
end

local totalHeight = 0
for _, item in ipairs(ITEMS) do totalHeight = totalHeight + itemHeight(item) end

local scroll = 0

function credits.enter()
    scroll = 0
end

-- roda do mouse / setas adiantam ou voltam a rolagem
local function scrollBy(dy)
    scroll = math.max(0, scroll + dy)
end

function credits.update(dt)
    demo.update(dt)
    if transition.active() then return end
    local speed = SPEED
    if love.keyboard.isDown("down") then speed = speed + 260 end
    if love.keyboard.isDown("up") then speed = speed - 300 end
    scrollBy(speed * dt)
end

local function close()
    transition.to(function() statemanager.switch("menu") end)
    assets.play("click")
end

function credits.keypressed(key)
    if key == "escape" or key == "return" or key == "kpenter" or key == "space" or key == "backspace" then
        close()
    end
end

function credits.pointerpressed()
    close()
end

function credits.wheelmoved(dy)
    scrollBy(-dy * 40)
end

local function drawItem(i, item, y, a, now)
    local W = layout.W
    local kind = item[1]
    if kind == "logo" then
        local r, g, b = theme.hue(now * 0.15, 0.55, 1)
        ui.printCentered("CHUVA DE", assets.fonts.title, y + 10, { r, g, b, a })
        ui.printCentered("CONTAS", assets.fonts.title, y + 58, { r, g, b, a })
    elseif kind == "heading" then
        -- cada título ganha a cor de uma operação, em rodízio
        local ops = { "+", "-", "x", "/" }
        local c = theme.op[ops[(i % 4) + 1]]
        ui.printCentered(item[2], assets.fonts.small, y + 30, { c[1] * 0.5 + 0.5, c[2] * 0.5 + 0.5, c[3] * 0.5 + 0.5, a })
        love.graphics.setColor(c[1], c[2], c[3], a)
        love.graphics.rectangle("fill", W / 2 - 20, y + 46, 40, 3, 1, 1)
    elseif kind == "text" then
        ui.printCentered(item[2], assets.fonts.hud, y + 4, { 1, 1, 1, a })
    elseif kind == "small" then
        ui.printCentered(item[2], assets.fonts.small, y + 4, { 1, 1, 1, 0.6 * a })
    elseif kind == "chips" then
        local ops = { { "+", "+" }, { "-", "-" }, { "x", "x" }, { ":", "/" } }
        local size, gap = 40, 14
        local total = #ops * size + (#ops - 1) * gap
        local font = assets.fonts.hud
        love.graphics.setFont(font)
        for j, op in ipairs(ops) do
            local c = theme.op[op[2]]
            local cx = (W - total) / 2 + (j - 1) * (size + gap)
            local cy = y + 8 + math.sin(now * 3 + j) * 5
            love.graphics.setColor(c[1], c[2], c[3], a)
            love.graphics.rectangle("fill", cx, cy, size, size, 8, 8)
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cx, cy, size, size, 8, 8)
            love.graphics.printf(op[1], cx, cy + (size - font:getHeight()) / 2 + 1, size, "center")
        end
    elseif kind == "thanks" then
        local pulse = 1 + math.sin(now * 3) * 0.04
        love.graphics.push()
        love.graphics.translate(W / 2, y + 40)
        love.graphics.scale(pulse)
        love.graphics.translate(-W / 2, -(y + 40))
        ui.printCentered("OBRIGADO", assets.fonts.big, y + 14, { 1, 0.85, 0.2, a })
        ui.printCentered("POR JOGAR!", assets.fonts.big, y + 48, { 1, 0.85, 0.2, a })
        love.graphics.pop()
    end
end

function credits.draw()
    local W, H = layout.W, layout.H
    local now = love.timer.getTime()

    demo.draw()
    ui.overlay(0.72)

    -- área onde o texto rola; perto das bordas ele some suavemente
    local top, bottom = H * 0.07 + 52, layout.footerButton().y - 12
    local fade = 50
    -- recomeça quando tudo já passou, como num filme em loop
    local span = totalHeight + (bottom - top)
    local y = bottom - scroll % span

    for i, item in ipairs(ITEMS) do
        local h = itemHeight(item)
        -- o item inteiro precisa caber na área: some antes de tocar as bordas
        local a = math.max(0, math.min(1, (y - top) / fade, (bottom - (y + h)) / fade))
        if a > 0 then drawItem(i, item, y, a, now) end
        y = y + h
    end

    -- cabeçalho fixo
    local r, g, b = theme.hue(now * 0.1, 0.4, 1)
    ui.printCentered("CREDITOS", assets.fonts.big, H * 0.07, { r, g, b })
    love.graphics.setColor(r, g, b, 0.6)
    love.graphics.rectangle("fill", W / 2 - 60, H * 0.07 + 36, 120, 3, 1, 1)

    ui.drawFooterButton("VOLTAR", "ESC", 1)
    if not config.mobile then
        love.graphics.setFont(assets.fonts.small)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.printf("setas / roda do mouse para rolar", 0, H - 20, W, "center")
    end
end

return credits
