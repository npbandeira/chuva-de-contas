-- Feitiço que sai da varinha do mago e voa em arco até a conta acertada.
-- A conta só "estoura" quando ele chega (update devolve true).
local theme = require("src.theme")
local wizard = require("src.entities.wizard")

local Spell = {}
Spell.__index = Spell

local DEFAULT_COLOR = { 1, 0.85, 0.2 }

-- `text` (opcional) são os pontos que aparecem quando ele chega
function Spell.new(card, life, text)
    local x, y = wizard.wandTip()
    local tx, ty = card:center()
    return setmetatable({
        x = x, y = y, tx = tx, ty = ty,
        t = 0, life = life,
        color = theme.op[card.op] or DEFAULT_COLOR,
        text = text,
    }, Spell)
end

-- avança o voo; devolve true quando chegou no alvo
function Spell:update(dt)
    self.t = self.t + dt
    return self.t >= self.life
end

function Spell:draw()
    local progress = math.min(1, self.t / self.life)
    local x = self.x + (self.tx - self.x) * progress
    local y = self.y + (self.ty - self.y) * progress - math.sin(progress * math.pi) * 40

    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.4)
    love.graphics.circle("fill", x, y, 13)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", x, y, 6)
end

return Spell
