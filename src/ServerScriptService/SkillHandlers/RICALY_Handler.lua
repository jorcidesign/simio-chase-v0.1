-- =============================================================================
-- RICALY_Handler.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local function handleALIENTO_CURADOR(ctx)
    local char = ctx.char
    local root = ctx.root
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "Q", 40)

    StatusEffectSystem.apply(char, StatusEffectType.STUN, 0, 5)

    task.spawn(function()
        for i = 1, 5 do
            if not root.Parent then break end
            
            local sphere = Instance.new("Part")
            sphere.Shape = Enum.PartType.Ball
            sphere.Size = Vector3.new(20, 20, 20)
            sphere.Position = root.Position
            sphere.Color = Color3.fromRGB(0, 255, 100)
            sphere.Material = Enum.Material.Neon
            sphere.Transparency = 0.5
            sphere.Anchored = true
            sphere.CanCollide = false
            sphere.Parent = workspace
            
            game:GetService("TweenService"):Create(sphere, TweenInfo.new(0.8), {Transparency = 1, Size = Vector3.new(25,25,25)}):Play()
            game:GetService("Debris"):AddItem(sphere, 1)

            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and p.Character:FindFirstChild("SurvivorID") then
                    local otherRoot = p.Character:FindFirstChild("HumanoidRootPart")
                    if otherRoot and (otherRoot.Position - root.Position).Magnitude <= 10 then
                        local hum = p.Character:FindFirstChild("Humanoid")
                        if hum then
                            hum.Health = math.min(hum.MaxHealth, hum.Health + 10)
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
end

local function handleDOBLE_SALTO(ctx)
    local player = ctx.player
    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "E", 25)
    RemoteRegistry.ActivateDoubleJump:FireClient(player, 10)
end

return function(register)
    register("ALIENTO_CURADOR", handleALIENTO_CURADOR)
    register("DOBLE_SALTO_RICALY", handleDOBLE_SALTO)
end