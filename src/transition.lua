-- Transição de tela: losangos crescem numa onda diagonal até cobrir tudo,
-- a troca de tela acontece escondida por baixo, e eles encolhem revelando
-- a tela nova. Enquanto roda, o jogo fica congelado e a entrada é ignorada.
local theme = require("src.theme")

local transition = {}

local COVER_TIME = 0.4
local REVEAL_TIME = 0.4
local TILE = 48      -- distância entre os centros dos losangos
local SPREAD = 0.55  -- fração do tempo que a onda leva pra cruzar a tela

transition.phase = nil -- nil | "wait" | "cover" | "reveal"
transition.t = 0
local pending, waitTime

-- inicia a transição; `onCovered` roda com a tela toda coberta.
-- `delay` segura a tela parada antes de cobrir (ex.: ver a conta que caiu)
function transition.to(onCovered, delay)
    if transition.phase then return false end
    pending = onCovered
    waitTime = delay or 0
    transition.phase = waitTime > 0 and "wait" or "cover"
    transition.t = 0
    return true
end

function transition.active()
    return transition.phase ~= nil
end

function transition.update(dt)
    if not transition.phase then return end
    transition.t = transition.t + dt
    if transition.phase == "wait" and transition.t >= waitTime then
        transition.phase, transition.t = "cover", 0
    elseif transition.phase == "cover" and transition.t >= COVER_TIME then
        local fn = pending
        pending = nil
        if fn then fn() end
        transition.phase, transition.t = "reveal", 0
    elseif transition.phase == "reveal" and transition.t >= REVEAL_TIME then
        transition.phase = nil
    end
end

local function clamp01(x)
    return math.max(0, math.min(1, x))
end

local function easeOutCubic(x)
    return 1 - (1 - x) ^ 3
end

function transition.draw(W, H)
    local phase = transition.phase
    if phase ~= "cover" and phase ~= "reveal" then return end
    local k = transition.t / (phase == "cover" and COVER_TIME or REVEAL_TIME)
    local cols, rows = math.ceil(W / TILE), math.ceil(H / TILE)
    local time = love.timer.getTime()

    love.graphics.setLineWidth(2)
    for row = 0, rows do
        for col = 0, cols do
            -- 0 no canto superior esquerdo, 1 no inferior direito
            local d = (col + row) / (cols + rows)
            local prog = clamp01((k - d * SPREAD) / (1 - SPREAD))
            local size = phase == "cover" and easeOutCubic(prog) or 1 - easeOutCubic(prog)
            if size > 0 then
                -- losango com meia-diagonal TILE cobre o quadrado inteiro do ladrilho
                local cx, cy, r = col * TILE + TILE / 2, row * TILE + TILE / 2, TILE * size
                local pts = { cx, cy - r, cx + r, cy, cx, cy + r, cx - r, cy }
                love.graphics.setColor(0.12, 0.1, 0.22)
                love.graphics.polygon("fill", pts)
                if size < 1 then
                    -- borda neon que gira de cor ao longo da onda
                    local cr, cg, cb = theme.hue(d + time * 0.5, 0.6, 1)
                    love.graphics.setColor(cr, cg, cb, 0.9)
                    love.graphics.polygon("line", pts)
                end
            end
        end
    end
end

return transition
