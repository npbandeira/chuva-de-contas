-- Troca de telas. Cada tela é um módulo em states/ com os callbacks que
-- precisar: enter(anterior, ...), exit, update, draw, keypressed,
-- textinput, pointerpressed, wheelmoved, focus e cameraShake.
-- O main.lua repassa os callbacks do LÖVE para a tela atual.
local statemanager = {}

local states = {}
local current, currentName

function statemanager.register(name, state)
    states[name] = state
end

-- sai da tela atual e entra em `name`; os argumentos extras vão para o enter
function statemanager.switch(name, ...)
    local nextState = assert(states[name], "tela desconhecida: " .. tostring(name))
    local previous = currentName
    if current and current.exit then current.exit() end
    current, currentName = nextState, name
    if current.enter then current.enter(previous, ...) end
end

function statemanager.is(name)
    return currentName == name
end

-- chama o callback na tela atual, se ela tiver; devolve o que ele devolver
function statemanager.call(callback, ...)
    local fn = current and current[callback]
    if fn then return fn(...) end
end

return statemanager
