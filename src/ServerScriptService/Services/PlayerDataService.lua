-- =============================================================================
-- PlayerDataService.lua
-- =============================================================================
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local PlayerDataService = {}

local SelectionStore = nil
local _mockStore = {} -- Memoria temporal para cuando se prueba en Studio sin publicar

-- Intentar obtener el DataStore de forma segura para que no crashee en Studio
local success, store = pcall(function()
    return DataStoreService:GetDataStore("SimioChase_Selections_v1")
end)

if success and store then
    SelectionStore = store
else
    warn("⚠️ [PlayerDataService] DataStore no disponible (Juego no publicado). Usando guardado temporal.")
end

function PlayerDataService.Start()
    print("💾 [PlayerDataService] Iniciado.")

    Players.PlayerAdded:Connect(function(player)
        local data = nil
        local userIdStr = tostring(player.UserId)

        if SelectionStore then
            local ok, res = pcall(function()
                return SelectionStore:GetAsync(userIdStr)
            end)
            if ok then data = res end
        else
            data = _mockStore[userIdStr]
        end
        
        if data then
            local RespawnManager = require(game:GetService("ServerScriptService").Services.RespawnManagerService)
            -- Como el manager no expone la tabla interna, disparamos el remote hacia él mismo
            RemoteRegistry.SelectCharacter:FireServer(player, data.role, data.id)
            print("💾 Cargada selección de " .. player.Name .. ": " .. data.id)
        end
    end)

    RemoteRegistry.SelectCharacter.OnServerEvent:Connect(function(player, role, id)
        local userIdStr = tostring(player.UserId)
        local saveData = {role = role, id = id}

        if SelectionStore then
            local ok, err = pcall(function()
                SelectionStore:SetAsync(userIdStr, saveData)
            end)
            if not ok then
                warn("❌ Error guardando selección de " .. player.Name)
            end
        else
            _mockStore[userIdStr] = saveData
        end
    end)
end

return PlayerDataService