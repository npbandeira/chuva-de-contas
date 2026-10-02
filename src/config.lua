-- Versão do jogo e plataforma em que ele está rodando. Lido pelo conf.lua
-- (antes da janela abrir) e pelo resto do jogo, no lugar de variáveis globais.
local config = {}

-- versão mostrada no menu; os scripts de build leem esta linha
config.VERSION = "1.0.1"

local function hasArg(name)
    for _, a in pairs(arg or {}) do
        if a == name then return true end
    end
    return false
end

-- celular de verdade (tela cheia e orientação travada)
config.nativeMobile = love._os == "Android" or love._os == "iOS"

-- modo celular: automático no Android/iOS, ou forçado no PC com "love . --mobile"
config.mobile = config.nativeMobile or hasArg("--mobile")

-- versão para navegador (love.js); lá não existe "sair do jogo"
config.web = love._os == "Web"

return config
