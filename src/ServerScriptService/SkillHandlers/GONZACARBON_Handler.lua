-- =============================================================================
-- GONZACARBON_Handler.lua
-- =============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local function handleCEGUERA(ctx)
    local root = ctx.root
    local player = ctx.player
    local range = 30

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "Q", 50)

    -- Buscar killer en rango de 30 studs
    for _, p in ipairs(Players:GetPlayers()) do
        local otherChar = p.Character
        if otherChar and otherChar:FindFirstChild("KillerID") then
            local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
            if otherRoot and (otherRoot.Position - root.Position).Magnitude <= range then
                RemoteRegistry.BlindKiller:FireClient(p, 5)
                print("🦇 [Gonzacarbon] Cegó a " .. p.Name)
            end
        end
    end
end

local function handleCAMUFLAJE(ctx)
    local char = ctx.char
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "E", 45)

    -- Transparencia 0.85 por 6 segundos
    StatusEffectSystem.apply(char, StatusEffectType.INVISIBLE, 0.85, 6)
    print("🦇 [Gonzacarbon] Camuflaje activado.")
end

return function(register)
    register("CEGUERA", handleCEGUERA)
    register("CAMUFLAJE", handleCAMUFLAJE)
end