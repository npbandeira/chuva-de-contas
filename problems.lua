-- Gerador de contas das 4 operações básicas.
-- Separado do main.lua para poder ser testado com Lua puro.
local problems = {}

local function rand(a, b)
    return math.random(a, b)
end

-- Retorna { text = "7 + 5", answer = 12 }
function problems.new(level)
    local max = 10 + (level - 1) * 5 -- limite para + e -
    local maxMul = math.min(10, 5 + level) -- limite para x e ÷

    -- Nível 1: só + e -; nível 2 libera x; nível 3+ libera ÷
    local ops = { "+", "-" }
    if level >= 2 then ops[#ops + 1] = "x" end
    if level >= 3 then ops[#ops + 1] = "/" end
    local op = ops[rand(1, #ops)]

    local a, b, answer
    if op == "+" then
        a, b = rand(1, max), rand(1, max)
        answer = a + b
    elseif op == "-" then
        a, b = rand(1, max), rand(1, max)
        if b > a then a, b = b, a end -- nunca negativo
        answer = a - b
    elseif op == "x" then
        a, b = rand(1, maxMul), rand(1, maxMul)
        answer = a * b
    else
        b, answer = rand(1, maxMul), rand(1, maxMul)
        a = b * answer -- divisão sempre exata
    end

    local symbol = ({ ["+"] = "+", ["-"] = "-", ["x"] = "x", ["/"] = ":" })[op]
    return { text = a .. " " .. symbol .. " " .. b, answer = answer, op = op, a = a, b = b }
end

return problems
