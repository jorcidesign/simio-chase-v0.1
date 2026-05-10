-- src/ServerScriptService/Services/MatchManagerService.lua
local ServerScriptService = game:GetService("ServerScriptService")
local ServerEventBus = require(ServerScriptService.Network.ServerEventBus)

local MatchManagerService = {}

function MatchManagerService.Start()
    print("🎮 [MatchManager] Iniciado. Empezando a enviar pings...")
    
    -- Creamos un hilo paralelo para no bloquear el juego
    task.spawn(function()
        local contador = 1
        while true do
            task.wait(2) -- Espera 2 segundos
            -- Disparamos el evento pasando argumentos
            ServerEventBus.TestPing:Fire("Hola desde MatchManager", contador)
            contador += 1
        end
    end)
end

return MatchManagerService