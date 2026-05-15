-- =============================================================================
-- SURI_Handler.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local function handleBARRIL_EXPLOSIVO(ctx)
    local root = ctx.root
    local player = ctx.player
    local targetPos = ctx.targetPos or (root.Position + root.CFrame.LookVector * 15)

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "Q", 25)

    local barrel = Instance.new("Part")
    barrel.Shape = Enum.PartType.Cylinder
    barrel.Size = Vector3.new(3, 2, 2)
    barrel.Position = root.Position + Vector3.new(0, 2, 0)
    barrel.Color = Color3.fromRGB(150, 75, 0)
    barrel.Parent = workspace

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = (targetPos - barrel.Position).Unit * 40
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = barrel
    Debris:AddItem(bv, 0.5)

    task.delay(1, function()
        if not barrel.Parent then return end
        
        local explosion = Instance.new("Part")
        explosion.Shape = Enum.PartType.Ball
        explosion.Size = Vector3.new(30, 30, 30)
        explosion.Position = barrel.Position
        explosion.Color = Color3.fromRGB(255, 50, 0)
        explosion.Material = Enum.Material.Neon
        explosion.Transparency = 0.5
        explosion.Anchored = true
        explosion.CanCollide = false
        explosion.Parent = workspace
        
        game:GetService("TweenService"):Create(explosion, TweenInfo.new(0.5), {Transparency = 1, Size = Vector3.new(40,40,40)}):Play()
        Debris:AddItem(explosion, 0.5)

        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        local killers = {}
        for _, p in ipairs(game.Players:GetPlayers()) do
            if p.Character and p.Character:FindFirstChild("KillerID") then
                table.insert(killers, p.Character)
            end
        end
        params.FilterDescendantsInstances = killers

        local parts = workspace:GetPartBoundsInBox(barrel.CFrame, Vector3.new(30,30,30), params)
        for _, p in ipairs(parts) do
            local hitChar = p.Parent
            if hitChar:FindFirstChild("KillerID") then
                StatusEffectSystem.apply(hitChar, StatusEffectType.STUN, 0, 2)
                
                local hitRoot = hitChar:FindFirstChild("HumanoidRootPart")
                if hitRoot then
                    local pushDir = (hitRoot.Position - barrel.Position).Unit
                    hitRoot.AssemblyLinearVelocity = pushDir * 50
                end
            end
        end
        barrel:Destroy()
    end)
end

local function handlePLATANO_VELOCIDAD(ctx)
    local root = ctx.root
    local player = ctx.player
    local targetPos = ctx.targetPos or (root.Position + root.CFrame.LookVector * 5)

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "E", 20)

    local buffItem = Instance.new("Part")
    buffItem.Size = Vector3.new(2, 0.5, 2)
    buffItem.Position = Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)
    buffItem.Color = Color3.fromRGB(255, 255, 0)
    buffItem.Material = Enum.Material.Neon
    buffItem.Anchored = true
    buffItem.CanCollide = false
    buffItem.Parent = workspace

    buffItem.Touched:Connect(function(hit)
        local hitChar = hit.Parent
        if hitChar and hitChar:FindFirstChild("SurvivorID") then
            StatusEffectSystem.apply(hitChar, StatusEffectType.SPEED_BOOST, 1.3, 4)
            buffItem:Destroy()
        end
    end)

    Debris:AddItem(buffItem, 15)
end

return function(register)
    register("BARRIL_EXPLOSIVO", handleBARRIL_EXPLOSIVO)
    register("PLATANO_VELOCIDAD", handlePLATANO_VELOCIDAD)
end