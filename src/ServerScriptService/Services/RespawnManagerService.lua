-- =============================================================================
-- RespawnManagerService.lua
-- =============================================================================

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerEventBus = require(ServerScriptService.Network.ServerEventBus)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local GameState      = require(ReplicatedStorage.Enums.GameState)
local WorldService   = require(script.Parent.WorldService)
local PassiveSystem  = require(ServerScriptService.Systems.PassiveSystem)

local RespawnManagerService = {}

local _currentMatchState: string = GameState.WAITING
local _usedSpawnIndices: {[number]: boolean} = {}

local function getNextSurvivorSpawnCFrame(): CFrame
    local parts = WorldService.getSurvivorSpawnParts()
    if #parts == 0 then
        return CFrame.new(math.random(-8, 8), 10, math.random(-8, 8))
    end

    local available: {number} = {}
    for i = 1, #parts do
        if not _usedSpawnIndices[i] then table.insert(available, i) end
    end

    if #available == 0 then
        table.clear(_usedSpawnIndices)
        for i = 1, #parts do table.insert(available, i) end
    end

    local pick = available[math.random(1, #available)]
    _usedSpawnIndices[pick] = true
    local spread = 2
    return parts[pick].CFrame + Vector3.new(math.random(-spread, spread), 0, math.random(-spread, spread))
end

local function ensureAnimator(character: Model)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        local a = Instance.new("Animator")
        a.Parent = humanoid
    end
end

local function spawnPlayer(player: Player, role: string, characterId: string)
    local folderName  = (role == "Killer") and "Killers" or "Survivors"
    local assetsRoot  = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsRoot then return end

    local categoryFolder = assetsRoot:FindFirstChild("Characters") and assetsRoot.Characters:FindFirstChild(folderName)
    local characterModel = categoryFolder and categoryFolder:FindFirstChild(characterId)

    if not characterModel then return end

    if player.Character then player.Character:Destroy() end

    local clone = characterModel:Clone()
    clone.Name  = player.Name

    local idTag  = Instance.new("StringValue")
    idTag.Name   = (role == "Killer") and "KillerID" or "SurvivorID"
    idTag.Value  = characterId
    idTag.Parent = clone

    ensureAnimator(clone)

    local spawnCF: CFrame
    if role == "Killer" then
        spawnCF = WorldService.getKillerSpawnCFrame()
    else
        spawnCF = getNextSurvivorSpawnCFrame()
    end

    clone.Parent = workspace
    clone:PivotTo(spawnCF)

    task.delay(0.3, function()
        PassiveSystem.initialize(clone, role, characterId)
    end)

    player.Character = clone

    task.delay(0.15, function()
        if player and player.Parent then
            RemoteRegistry.SetupCharacter:FireClient(player)
        end
    end)

    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Once(function()
            if role == "Survivor" then
                local victim = Players:GetPlayerFromCharacter(clone)
                if victim then ServerEventBus.SurvivorKilled:Fire(victim, nil) end
            elseif role == "Killer" then
                ServerEventBus.KillerKilled:Fire(player)
            end
            RemoteRegistry.ShowRespawnMenu:FireClient(player, 30)
        end)
    end
end

-- ✅ NUEVO SISTEMA LEYENDO DE CHARACTER SELECTION
local function spawnAllPlayers()
    table.clear(_usedSpawnIndices)
    local CharacterSelectionService = require(game:GetService("ServerScriptService").Services.CharacterSelectionService)
    
    local roles, picks = CharacterSelectionService.GetFinalData()
    
    for _, player in ipairs(Players:GetPlayers()) do
        local role = roles[player]
        local charId = picks[player]
        if role and charId then
            spawnPlayer(player, role, charId)
        end
    end
end

local function returnAllToLobby()
    local lobbyCF = WorldService.getLobbySpawnCFrame()

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then player.Character:Destroy() end
        player:LoadCharacter()
        task.spawn(function()
            local char = player.Character or player.CharacterAdded:Wait()
            local root = char:WaitForChild("HumanoidRootPart", 5)
            if root then
                char:PivotTo(lobbyCF + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
            end
        end)
    end
end

function RespawnManagerService.spawnPlayer(player: Player, role: string, characterId: string)
    spawnPlayer(player, role, characterId)
end

function RespawnManagerService.Start()
    Players.CharacterAutoLoads = false

    Players.PlayerAdded:Connect(function(player)
        player:LoadCharacter()
        task.spawn(function()
            local char = player.Character or player.CharacterAdded:Wait()
            local root = char:WaitForChild("HumanoidRootPart", 5)
            if root then
                local lobbyCF = WorldService.getLobbySpawnCFrame()
                char:PivotTo(lobbyCF + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
            end
        end)
    end)

    RemoteRegistry.RequestRespawn.OnServerEvent:Connect(function(player)
        if _currentMatchState ~= GameState.PLAYING and _currentMatchState ~= GameState.LAST_MAN then return end
        
        local CharacterSelectionService = require(game:GetService("ServerScriptService").Services.CharacterSelectionService)
        local roles, picks = CharacterSelectionService.GetFinalData()
        
        local role = roles[player]
        local charId = picks[player]
        if role and charId then
            spawnPlayer(player, role, charId)
        end
    end)

    ServerEventBus.MatchStateChanged:Connect(function(newState: string)
        _currentMatchState = newState

        if newState == GameState.PLAYING then
            spawnAllPlayers()
        elseif newState == GameState.ENDING then
            task.delay(3, function()
                if _currentMatchState == GameState.ENDING then
                    returnAllToLobby()
                end
            end)
        elseif newState == GameState.WAITING then
            table.clear(_usedSpawnIndices)
        end
    end)
end

return RespawnManagerService