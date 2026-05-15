-- =============================================================================
-- SIU_Handler.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local function handleBARRERA(ctx)
    local root = ctx.root
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "Q", 45)

    local wall = Instance.new("Part")
    wall.Name = "SiuWall"
    wall.Size = Vector3.new(10, 7, 1)
    wall.CFrame = root.CFrame * CFrame.new(0, 0, -4)
    wall.Anchored = true
    wall.CanCollide = true
    wall.Material = Enum.Material.Ice
    wall.Color = Color3.fromRGB(100, 200, 255)
    wall.Transparency = 0.3
    wall.Parent = workspace
    
    Debris:AddItem(wall, 6)
end

local function handlePLATANO(ctx)
    local root = ctx.root
    local player = ctx.player
    local targetPos = ctx.targetPos or (root.Position + root.CFrame.LookVector * 5)

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "E", 30)

    local trap = Instance.new("Part")
    trap.Name = "SiuBanana"
    trap.Size = Vector3.new(2, 0.5, 2)
    trap.Position = Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)
    trap.Color = Color3.fromRGB(255, 255, 0)
    trap.Anchored = true
    trap.CanCollide = false
    trap.Parent = workspace
    
    trap.Touched:Connect(function(hit)
        local hitChar = hit.Parent
        if hitChar and hitChar:FindFirstChild("KillerID") then
            StatusEffectSystem.apply(hitChar, StatusEffectType.STUN, 0, 2)
            trap:Destroy()
            print("🍌 [Siu] Killer pisó el plátano.")
        end
    end)

    Debris:AddItem(trap, 30)
end

return function(register)
    register("BARRERA", handleBARRERA)
    register("PLATANO", handlePLATANO)
end