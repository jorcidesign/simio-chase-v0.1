-- =============================================================================
-- VACUMING_Handler.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local function handleIMPULSO_VELOZ(ctx)
    local char = ctx.char
    local root = ctx.root
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "Q", 30)

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = root.CFrame.LookVector * 100
    bv.MaxForce = Vector3.new(1e5, 0, 1e5)
    bv.Parent = root
    Debris:AddItem(bv, 1)

    task.delay(1, function()
        if char and char.Parent then
            StatusEffectSystem.apply(char, StatusEffectType.SPEED_BOOST, 1.4, 8)
        end
    end)
end

local function handleVINCULO_VITAL(ctx)
    local char = ctx.char
    local root = ctx.root
    local hum = ctx.hum
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "E", 25)

    local closestAlly = nil
    local minDistance = 20

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("SurvivorID") then
            local otherRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if otherRoot then
                local dist = (otherRoot.Position - root.Position).Magnitude
                if dist <= minDistance then
                    minDistance = dist
                    closestAlly = p.Character
                end
            end
        end
    end

    if closestAlly then
        local targetHum = closestAlly:FindFirstChild("Humanoid")
        if targetHum then
            targetHum.Health = math.min(targetHum.MaxHealth, targetHum.Health + 30)
            hum:TakeDamage(5)

            local beamPart = Instance.new("Part")
            beamPart.Size = Vector3.new(0.5, 0.5, minDistance)
            beamPart.CFrame = CFrame.lookAt(root.Position, closestAlly.PrimaryPart.Position) * CFrame.new(0, 0, -minDistance/2)
            beamPart.Color = Color3.fromRGB(50, 255, 50)
            beamPart.Material = Enum.Material.Neon
            beamPart.Anchored = true
            beamPart.CanCollide = false
            beamPart.Parent = workspace

            game:GetService("TweenService"):Create(beamPart, TweenInfo.new(0.5), {Transparency = 1}):Play()
            Debris:AddItem(beamPart, 0.5)
            print("💖 [Vacuming] Curó a un aliado.")
        end
    else
        print("💖 [Vacuming] No hay aliados cerca.")
    end
end

return function(register)
    register("IMPULSO_VELOZ", handleIMPULSO_VELOZ)
    register("VINCULO_VITAL", handleVINCULO_VITAL)
end