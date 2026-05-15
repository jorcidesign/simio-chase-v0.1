-- =============================================================================
-- DebugService.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local MatchManagerService = require(ServerScriptService.Services.MatchManagerService)
local TimeManagerService = require(ServerScriptService.Services.TimeManagerService)
local GameState = require(ReplicatedStorage.Enums.GameState)

local DebugService = {}

function DebugService.Start()
    print("🛠️ [DebugService] Iniciado.")

    -- Adelantar/Terminar Fase Actual
    RemoteRegistry.DebugSkipPhase.OnServerEvent:Connect(function(player)
        -- TODO: En producción, verifica si 'player' es admin (ej. table.find(Admins, player.UserId))
        print(string.format("🛠️ [Debug] %s solicitó SkipPhase", player.Name))
        
        local state = MatchManagerService._state
        
        if state == GameState.PLAYING or state == GameState.LAST_MAN then
            TimeManagerService.setTime(1) -- Expira naturalmente al siguiente tick
        elseif state == GameState.ESCAPE then
            MatchManagerService.transition(GameState.ENDING) -- Overtime usa su propio thread, lo saltamos directo
        elseif state == GameState.LOBBY or state == GameState.SELECTING or state == GameState.LOADING or state == GameState.STATS then
            TimeManagerService.setTime(1)
        end
    end)

    -- Alterar tiempo a un valor específico
    RemoteRegistry.DebugSetTime.OnServerEvent:Connect(function(player, seconds: number)
        if type(seconds) ~= "number" then return end
        
        -- Si estamos en un estado basado en TimeManagerService, lo alteramos
        if MatchManagerService._state ~= GameState.ESCAPE then
            TimeManagerService.setTime(seconds)
        end
    end)
end

return DebugService