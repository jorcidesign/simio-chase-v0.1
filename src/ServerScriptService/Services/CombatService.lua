-- =============================================================================
-- CombatService.lua
-- =============================================================================

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local ServerEventBus = require(ServerScriptService.Network.ServerEventBus)
local GameState      = require(ReplicatedStorage.Enums.GameState)
local DamageSystem   = require(ServerScriptService.Systems.DamageSystem)

local function getRegistry()
    return require(ServerScriptService.Data.CharacterRegistry)
end

local _m1Cooldowns: { [Player]: number } = {}
local SERVER_M1_WINDOW = 0.5

local function getAliveKiller(player: Player): (boolean, Model?, Humanoid?)
    local char = player.Character
    if not char then return false, nil, nil end
    if not char:FindFirstChild("KillerID") then return false, nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false, nil, nil end
    return true, char, hum
end

local function onM1Attack(player: Player)
    local ok, char = getAliveKiller(player)
    if not ok or not char then return end

    local m1Window = SERVER_M1_WINDOW

    -- GAP-23: Cooldown dinámico de M1 con FrenzyActive (JALY)
    if char.KillerID.Value == "JALY" then
        local frenzy = char:FindFirstChild("FrenzyActive")
        if frenzy and frenzy.Value then
            m1Window = 0.4
        end
    end

    local now  = os.clock()
    local last = _m1Cooldowns[player] or 0
    if (now - last) < m1Window then return end
    _m1Cooldowns[player] = now

    DamageSystem.executeM1(char, player)
end

local function onSetSprintState(player: Player, active: any)
    if type(active) ~= "boolean" then return end

    local char = player.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local survivorTag = char:FindFirstChild("SurvivorID")
    if not survivorTag then return end

    local config = getRegistry().getSurvivor(survivorTag.Value)
    if not config then return end

    hum.WalkSpeed = active and config.RunSpeed or config.WalkSpeed
end

local function initRageMeters()
    task.wait(0.6)
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char and char:FindFirstChild("KillerID") and char.KillerID.Value == "PORO" and not char:FindFirstChild("RageMeter") then
            local rm = Instance.new("IntValue")
            rm.Name   = "RageMeter"
            rm.Value  = 0
            rm.Parent = char
        end
    end
end

local CombatService = {}

function CombatService.Start()
    print("⚔️  [CombatService] Iniciado.")

    RemoteRegistry.M1Attack.OnServerEvent:Connect(onM1Attack)
    RemoteRegistry.SetSprintState.OnServerEvent:Connect(onSetSprintState)

    ServerEventBus.MatchStateChanged:Connect(function(newState: string)
        if newState == GameState.PLAYING then
            initRageMeters()
        end
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        _m1Cooldowns[player] = nil
    end)
end

return CombatService