-- =============================================================================
-- SelectionWorldController.lua
-- =============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local ClientEventBus = require(script.Parent.Parent.Network.ClientEventBus)
local GameState = require(ReplicatedStorage.Enums.GameState)

local SelectionWorldController = {}

local _stageFolder = nil
local _camera = nil
local _models = {}

local STAGE_ORIGIN = CFrame.new(0, 5000, 0) -- Lejos del mapa real en el cielo

local function clearStage()
    if _stageFolder then
        _stageFolder:Destroy()
        _stageFolder = nil
    end
    table.clear(_models)
end

local function setupStage()
    clearStage()
    _stageFolder = Instance.new("Folder")
    _stageFolder.Name = "SelectionStage"
    _stageFolder.Parent = Workspace

    _camera = Workspace.CurrentCamera
    _camera.CameraType = Enum.CameraType.Scriptable
    _camera.CFrame = STAGE_ORIGIN
end

function SelectionWorldController.Start()
    print("🌍 [SelectionWorldController] Iniciado.")

    RemoteRegistry.StartSelectionPhase.OnClientEvent:Connect(function()
        setupStage()
    end)

    RemoteRegistry.SyncSelectionList.OnClientEvent:Connect(function(syncData)
        if not _stageFolder then return end

        -- Destruir modelos viejos para re-posicionar
        for _, model in pairs(_models) do
            if model then model:Destroy() end
        end
        table.clear(_models)

        local survivorCount = 0

        for _, data in ipairs(syncData) do
            local folderName = (data.role == "Killer") and "Killers" or "Survivors"
            local charAsset = ReplicatedStorage.Assets.Characters[folderName]:FindFirstChild(data.characterId)
            
            if charAsset then
                local clone = charAsset:Clone()
                clone.Parent = _stageFolder
                _models[data.playerName] = clone

                -- Remover scripts innecesarios del clon visual
                for _, child in ipairs(clone:GetDescendants()) do
                    if child:IsA("Script") or child:IsA("LocalScript") then
                        child:Destroy()
                    end
                end

                if data.role == "Killer" then
                    -- Killer en primer plano, a la derecha, acechando
                    clone:PivotTo(STAGE_ORIGIN * CFrame.new(4, -3, -12) * CFrame.Angles(0, math.pi + 0.3, 0))
                else
                    -- Survivors atrás, distribuidos en línea horizontal
                    survivorCount += 1
                    local xOffset = (survivorCount - 2) * 5 -- Separación de 5 studs
                    clone:PivotTo(STAGE_ORIGIN * CFrame.new(xOffset, -2, -30) * CFrame.Angles(0, math.pi, 0))
                end
            end
        end
    end)

    -- Al pasar a jugar, devolvemos la cámara al jugador y limpiamos
    ClientEventBus.MatchStateChanged:Connect(function(state)
        if state == GameState.PLAYING then
            clearStage()
            if _camera then
                _camera.CameraType = Enum.CameraType.Custom
            end
        end
    end)
end

return SelectionWorldController