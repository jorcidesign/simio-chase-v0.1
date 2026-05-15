-- =============================================================================
-- AUGUSTO_Handler.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local function handleDISPARO_BARRO(ctx)
    local root = ctx.root
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "Q", 18)

    local mud = Instance.new("Part")
    mud.Shape = Enum.PartType.Ball
    mud.Size = Vector3.new(2, 2, 2)
    mud.Position = root.Position + root.CFrame.LookVector * 2
    mud.Color = Color3.fromRGB(101, 67, 33)
    mud.Parent = workspace

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = root.CFrame.LookVector * 80
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = mud
    Debris:AddItem(mud, 3)

    mud.Touched:Connect(function(hit)
        local hitChar = hit.Parent
        if hitChar and hitChar:FindFirstChild("SurvivorID") then
            local hitPlayer = game.Players:GetPlayerFromCharacter(hitChar)
            if hitPlayer then
                RemoteRegistry.MudScreen:FireClient(hitPlayer, 5)
            end
            mud:Destroy()
        end
    end)
end

local function handleAREA_BARRO(ctx)
    local root = ctx.root
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "E", 35)

    local area = Instance.new("Part")
    area.Shape = Enum.PartType.Cylinder
    area.Size = Vector3.new(0.5, 40, 40)
    area.CFrame = root.CFrame * CFrame.Angles(0, 0, math.pi/2)
    area.Position = root.Position - Vector3.new(0, 2.5, 0)
    area.Color = Color3.fromRGB(101, 67, 33)
    area.Material = Enum.Material.Mud
    area.Anchored = true
    area.CanCollide = false
    area.Parent = workspace
    Debris:AddItem(area, 8)

    task.spawn(function()
        for i = 1, 16 do
            if not area.Parent then break end
            local params = OverlapParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            local survivors = {}
            for _, p in ipairs(game.Players:GetPlayers()) do
                if p.Character and p.Character:FindFirstChild("SurvivorID") then
                    table.insert(survivors, p.Character)
                end
            end
            params.FilterDescendantsInstances = survivors

            local parts = workspace:GetPartBoundsInBox(area.CFrame, Vector3.new(40, 10, 40), params)
            for _, p in ipairs(parts) do
                local hitChar = p.Parent
                local hum = hitChar:FindFirstChild("Humanoid")
                if hum then
                    StatusEffectSystem.apply(hitChar, StatusEffectType.SLOW, hum.WalkSpeed * 0.4, 1)
                end
            end
            task.wait(0.5)
        end
    end)
end

return function(register)
    register("DISPARO_BARRO", handleDISPARO_BARRO)
    register("AREA_BARRO", handleAREA_BARRO)
end