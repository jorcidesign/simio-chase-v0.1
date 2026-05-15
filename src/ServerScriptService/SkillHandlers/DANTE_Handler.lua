-- =============================================================================
-- DANTE_Handler.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local DamageSystem = require(ServerScriptService.Systems.DamageSystem)
local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local function handleLASER_HACK(ctx)
    local root = ctx.root; local char = ctx.char; local player = ctx.player
    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "Q", 25)

    local rayOrigin = root.Position
    local rayDirection = root.CFrame.LookVector * 70
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(rayOrigin, rayDirection, params)
    local endPos = result and result.Position or (rayOrigin + rayDirection)

    -- VFX del Láser (Sin animaciones ni sonido)
    local laser = Instance.new("Part")
    local dist = (endPos - rayOrigin).Magnitude
    laser.Size = Vector3.new(0.5, 0.5, dist)
    laser.CFrame = CFrame.lookAt(rayOrigin, endPos) * CFrame.new(0, 0, -dist/2)
    laser.Anchored = true; laser.CanCollide = false
    laser.Material = Enum.Material.Neon; laser.Color = Color3.fromRGB(255, 0, 0)
    laser.Parent = workspace
    
    game:GetService("TweenService"):Create(laser, TweenInfo.new(0.3), {Size = Vector3.new(0,0,dist), Transparency = 1}):Play()
    Debris:AddItem(laser, 0.3)

    if result and result.Instance then
        local hitChar = result.Instance.Parent
        if hitChar and hitChar:FindFirstChild("SurvivorID") then
            DamageSystem.applyDamage(hitChar, 10, char)
        end
    end
end

local function handleTELEPORT_DANTE(ctx)
    local root = ctx.root; local player = ctx.player; local char = ctx.char
    local targetPos = ctx.targetPos or (root.Position + root.CFrame.LookVector * 50)
    
    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "E", 20)

    if (targetPos - root.Position).Magnitude > 50 then
        targetPos = root.Position + (targetPos - root.Position).Unit * 50
    end

    -- VFX Origen
    local fx1 = Instance.new("Part"); fx1.Shape = Enum.PartType.Ball; fx1.Size = Vector3.new(5,5,5)
    fx1.Position = root.Position; fx1.Color = Color3.fromRGB(150, 0, 255); fx1.Material = Enum.Material.Neon
    fx1.Anchored = true; fx1.CanCollide = false; fx1.Parent = workspace
    game:GetService("TweenService"):Create(fx1, TweenInfo.new(0.5), {Size = Vector3.new(0,0,0)}):Play()
    Debris:AddItem(fx1, 0.5)

    -- Teleport + I-Frames
    root.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0), root.Position + root.CFrame.LookVector * 10)
    StatusEffectSystem.apply(char, StatusEffectType.INVINCIBLE, 0, 0.5)

    -- VFX Destino
    local fx2 = fx1:Clone(); fx2.Position = root.Position; fx2.Parent = workspace
    game:GetService("TweenService"):Create(fx2, TweenInfo.new(0.5), {Size = Vector3.new(0,0,0)}):Play()
    Debris:AddItem(fx2, 0.5)
end

local function handleSPEED_HACK(ctx)
    local char = ctx.char; local player = ctx.player
    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "R", 30)

    StatusEffectSystem.apply(char, StatusEffectType.SPEED_BOOST, 1.25, 8)
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("SurvivorID") then
            local hl = Instance.new("Highlight")
            hl.FillColor = Color3.fromRGB(0, 255, 255); hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.Parent = p.Character
            Debris:AddItem(hl, 8)
        end
    end
end

local function handlePOPUP_HACK(ctx)
    local root = ctx.root; local player = ctx.player
    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "F", 40)

    local closestSurv, minDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("SurvivorID") then
            local otherRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if otherRoot then
                local dist = (otherRoot.Position - root.Position).Magnitude
                if dist < minDist then
                    minDist = dist; closestSurv = p
                end
            end
        end
    end

    if closestSurv then
        RemoteRegistry.PopupHack:FireClient(closestSurv, 6)
        print("💻 [Dante] Popup hack enviado a " .. closestSurv.Name)
    end
end

return function(register)
    register("LASER_HACK", handleLASER_HACK)
    register("TELEPORT_DANTE", handleTELEPORT_DANTE)
    register("SPEED_HACK", handleSPEED_HACK)
    register("POPUP_HACK", handlePOPUP_HACK)
end