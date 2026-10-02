-- O mago ao lado da caixa de resposta, que lança feitiços nas contas.
-- `cast` é o tempo restante da pose de lançar (0 = parado).
local layout = require("src.layout")

local wizard = {}

wizard.CAST_TIME = 0.25 -- duração da pose de lançar feitiço

-- ponta da varinha, de onde os feitiços saem
function wizard.wandTip()
    local x, feetY = layout.wizardFeet()
    return x + 14, feetY - 74
end

function wizard.draw(cast)
    local x, feetY = layout.wizardFeet()
    local castT = math.min(1, cast / wizard.CAST_TIME) -- 1 = acabou de lançar, 0 = parado
    local hop = math.sin(castT * math.pi) * 10         -- pequeno salto ao lançar o feitiço

    love.graphics.push()
    love.graphics.translate(x, feetY - hop)

    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.ellipse("fill", 0, 4, 16, 5)

    -- robe
    love.graphics.setColor(0.35, 0.25, 0.7)
    love.graphics.polygon("fill", -16, 0, 16, 0, 10, -46, -10, -46)
    love.graphics.setColor(0.9, 0.75, 0.2)
    love.graphics.rectangle("fill", -12, -18, 24, 5)

    -- cabeça e chapéu
    love.graphics.setColor(0.95, 0.8, 0.65)
    love.graphics.circle("fill", 0, -56, 11)
    love.graphics.setColor(0.3, 0.2, 0.6)
    love.graphics.polygon("fill", -13, -62, 13, -62, 0, -95)
    love.graphics.setColor(0.9, 0.75, 0.2)
    love.graphics.circle("fill", 0, -95, 3.5)

    -- varinha: gira de "descansando" para "apontada pro alto" ao acertar
    local angle = -0.5 - castT * 1.7
    love.graphics.push()
    love.graphics.translate(14, -40)
    love.graphics.rotate(angle)
    love.graphics.setColor(0.5, 0.35, 0.2)
    love.graphics.setLineWidth(4)
    love.graphics.line(0, 0, 0, -34)
    love.graphics.setColor(1, 0.9, 0.4, 0.6 + castT * 0.4)
    love.graphics.circle("fill", 0, -34, 5 + castT * 3)
    love.graphics.pop()

    love.graphics.pop()
end

return wizard
