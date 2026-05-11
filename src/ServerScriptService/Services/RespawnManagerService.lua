-- src/ServerScriptService/Services/RespawnManagerService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local RespawnManagerService = {}

-- Estado interno: Rastrea los hilos (timers) de los jugadores muertos
local deathTimers = {}

function RespawnManagerService.Start()
    print("💀 [RespawnManager] Asumiendo el control de vida y muerte.")
    
    -- 1. Apagamos el sistema automático de Roblox
    Players.CharacterAutoLoads = false

    -- 2. Cuando un jugador entra, lo spawneamos y le inyectamos el detector de muerte
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(char)
            local hum = char:WaitForChild("Humanoid")
            
            -- OCP: Nos colgamos del evento nativo de muerte sin tocar el DamageSystem
            hum.Died:Connect(function()
                RespawnManagerService._handlePlayerDeath(player)
            end)
        end)
        
        -- Primer spawn al entrar al servidor
        player:LoadCharacter()
    end)

    -- 3. Escuchar peticiones de revivir
    RemoteRegistry.RequestRespawn.OnServerEvent:Connect(function(player)
        RespawnManagerService._handleRespawnRequest(player)
    end)
    
    -- 4. Limpieza si se desconecta
    Players.PlayerRemoving:Connect(function(player)
        if deathTimers[player] then
            task.cancel(deathTimers[player])
            deathTimers[player] = nil
        end
    end)
end

function RespawnManagerService._handlePlayerDeath(player: Player)
    if deathTimers[player] then return end -- Ya está muerto
    
    local timeLimit = 10 -- 10 segundos para darle a revivir
    
    -- Le decimos al cliente que muestre la UI
    RemoteRegistry.ShowRespawnMenu:FireClient(player, timeLimit)
    
    -- Iniciamos la bomba de tiempo en el servidor
    deathTimers[player] = task.delay(timeLimit, function()
        if player.Parent then
            player:Kick("Desconectado por inactividad. ¡El simio te alcanzó!")
        end
        deathTimers[player] = nil
    end)
end

function RespawnManagerService._handleRespawnRequest(player: Player)
    -- Solo puede revivir si estaba muerto (tiene un timer activo)
    if deathTimers[player] then
        task.cancel(deathTimers[player]) -- Desactivamos la bomba
        deathTimers[player] = nil
        
        print("👼 [RespawnManager] Reviviendo a " .. player.Name)
        player:LoadCharacter() -- Magia de Roblox: Crea un nuevo cuerpo intacto
    end
end

return RespawnManagerService