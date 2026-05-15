-- =============================================================================
-- MIGUEL_Handler.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local DamageSystem = require(ServerScriptService.Systems.DamageSystem)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local function handleHEAVY_SLAM(ctx)
    local char = ctx.char
    local root = ctx.root
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "Q", 15)

    local impact = Instance.new("Part")
    impact.Shape = Enum.PartType.Ball
    impact.Size = Vector3.new(20, 20, 20)
    impact.Position = root.Position
    impact.Color = Color3.fromRGB(200, 0, 0)
    impact.Material = Enum.Material.Neon
    impact.Transparency = 0.5
    impact.Anchored = true
    impact.CanCollide = false
    impact.Parent = workspace
    
    game:GetService("TweenService"):Create(impact, TweenInfo.new(0.5), {Transparency = 1, Size = Vector3.new(30,30,30)}):Play()
    Debris:AddItem(impact, 0.5)

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    local survivors = {}
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("SurvivorID") then
            table.insert(survivors, p.Character)
        end
    end
    params.FilterDescendantsInstances = survivors

    local parts = workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(25, 10, 25), params)
    local hitTargets = {}
    for _, p in ipairs(parts) do
        local hitChar = p.Parent
        if hitChar and not hitTargets[hitChar] then
            hitTargets[hitChar] = true
            DamageSystem.applyDamage(hitChar, 35, char)
        end
    end
end

local function handleTHROW(ctx)
    local char = ctx.char
    local root = ctx.root
    local player = ctx.player
    local targetPos = ctx.targetPos or (root.Position + root.CFrame.LookVector * 30)

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "E", 20)

    local rock = Instance.new("Part")
    rock.Size = Vector3.new(4, 4, 4)
    rock.Position = root.Position + Vector3.new(0, 5, 0)
    rock.Color = Color3.fromRGB(100, 100, 100)
    rock.Parent = workspace

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = (targetPos - rock.Position).Unit * 80
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = rock
    Debris:AddItem(rock, 2)

    rock.Touched:Connect(function(hit)
        local hitChar = hit.Parent
        if hitChar and hitChar:FindFirstChild("SurvivorID") then
            DamageSystem.applyDamage(hitChar, 25, char)
            rock:Destroy()
        end
    end)
end

return function(register)
    register("HEAVY_SLAM", handleHEAVY_SLAM)
    register("THROW", handleTHROW)
end