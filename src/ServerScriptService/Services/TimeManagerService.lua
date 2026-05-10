-- src/ServerScriptService/Services/TimeManagerService.lua
local ServerScriptService = game:GetService("ServerScriptService")
local ServerEventBus = require(ServerScriptService.Network.ServerEventBus)

local TimeManagerService = {}

function TimeManagerService.Start()
    print("⏳ [TimeManager] Iniciado. Esperando pings...")
    
    -- Nos conectamos al evento
    ServerEventBus.TestPing:Connect(function(mensaje, contador)
        print("🏓 [TimeManager] ¡Pong! Recibí el mensaje: '" .. mensaje .. "' | Número: " .. contador)
    end)
end

return TimeManagerService