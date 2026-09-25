-- Paleta de cores do tema arcade/neon, compartilhada entre a lógica do jogo
-- (cor das partículas) e o desenho (cor dos blocos e efeitos).
local theme = {}

theme.sky = { 0.84, 0.93, 0.96 }
theme.ground = { 0.65, 0.6, 0.57 }

theme.op = {
    ["+"] = { 0.25, 0.55, 0.95 },
    ["-"] = { 0.95, 0.55, 0.2 },
    ["x"] = { 0.6, 0.35, 0.85 },
    ["/"] = { 0.2, 0.7, 0.55 },
}

-- cores por faixa de combo (5, 10, 15, 20+ acertos em sequência)
theme.combo = {
    { 1, 0.85, 0.2 },
    { 1, 0.55, 0.15 },
    { 1, 0.3, 0.5 },
    { 0.7, 0.3, 1 },
}

-- HSV -> RGB, usado no título do menu para o brilho neon que gira de cor
function theme.hue(t, s, v)
    local h = (t % 1) * 6
    local i = math.floor(h)
    local f = h - i
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local u = v * (1 - s * (1 - f))
    if i == 0 then
        return v, u, p
    elseif i == 1 then
        return q, v, p
    elseif i == 2 then
        return p, v, u
    elseif i == 3 then
        return p, q, v
    elseif i == 4 then
        return u, p, v
    else
        return v, p, q
    end
end

return theme
