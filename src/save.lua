-- Recorde, salvo na pasta do jogo (t.identity no conf.lua).
local save = {}

local FILE = "highscore.txt"

save.highscore = 0

function save.load()
    -- confere antes de ler: na versão web (love.js) ler um arquivo que ainda
    -- não existe trava o jogo, e na 1ª vez que alguém joga ele nunca existe
    if not love.filesystem.getInfo(FILE) then
        save.highscore = 0
        return
    end
    save.highscore = tonumber(love.filesystem.read(FILE)) or 0
end

-- grava a pontuação se ela bateu o recorde; devolve true quando é recorde novo
function save.submitScore(score)
    if score <= save.highscore then return false end
    save.highscore = score
    love.filesystem.write(FILE, tostring(score))
    return true
end

return save
