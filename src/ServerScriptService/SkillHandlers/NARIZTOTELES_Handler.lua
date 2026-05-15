-- =============================================================================
-- NARIZTOTELES_Handler.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local function handleCOUNTER_ACTIVATE(ctx)
    local char = ctx.char
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "Q", 40)

    local counterActive = Instance.new("BoolValue")
    counterActive.Name = "CounterActive"
    counterActive.Value = true
    counterActive.Parent = char

    local counterSuccess = char:FindFirstChild("CounterSuccess")

    task.delay(1.2, function()
        if counterActive.Parent then counterActive:Destroy() end
        
        -- Si no hubo éxito (no le pegaron), self-stun 0.5s
        if counterSuccess and not counterSuccess.Value then
            StatusEffectSystem.apply(char, StatusEffectType.STUN, 0, 0.5)
        end
        
        if counterSuccess then counterSuccess.Value = false end
    end)
end

local function handleEMBESTIDA(ctx)
    local char = ctx.char
    local root = ctx.root
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "E", 25)

    local duration = 0.5
    local speed = 100
    local elapsed = 0

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = root.CFrame.LookVector * speed
    bv.MaxForce = Vector3.new(1e5, 0, 1e5)
    bv.Parent = root
    Debris:AddItem(bv, duration)

    local hitSomething = false
    local dashConn
    dashConn = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= duration or not root.Parent then
            dashConn:Disconnect()
            if bv.Parent then bv:Destroy() end
            RemoteRegistry.SkillAnimStop:FireClient(player, "SkillE")
            return
        end

        local params = OverlapParams.new()
        params.FilterDescendantsInstances = {char}
        params.FilterType = Enum.RaycastFilterType.Exclude

        local parts = workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(5,5,5), params)
        for _, p in ipairs(parts) do
            local hitChar = p.Parent
            if hitChar:FindFirstChild("KillerID") then
                hitSomething = true
                dashConn:Disconnect()
                if bv.Parent then bv:Destroy() end
                StatusEffectSystem.apply(hitChar, StatusEffectType.STUN, 0, 1.2)
                RemoteRegistry.SkillAnimStop:FireClient(player, "SkillE")
                break
            end
        end
    end)
end

local function handleTELEPORT_HACK_SAVE(ctx)
    local char = ctx.char
    local root = ctx.root
    local player = ctx.player

    ctx._castConfirmed = true

    local saved = char:FindFirstChild("SavedPosition")
    if not saved then
        -- Primera pulsación: Guarda posición
        saved = Instance.new("CFrameValue")
        saved.Name = "SavedPosition"
        saved.Value = root.CFrame
        saved.Parent = char
        RemoteRegistry.SkillCastConfirmed:FireClient(player, "R", 1) -- Cooldown corto para colocar
        print("👃 [Nariztoteles] Posición guardada.")
    else
        -- Segunda pulsación: Teletransporte a posición
        root.CFrame = saved.Value
        saved:Destroy()
        StatusEffectSystem.apply(char, StatusEffectType.INVINCIBLE, 0, 0.5)
        RemoteRegistry.SkillCastConfirmed:FireClient(player, "R", 25) -- Cooldown real
        print("👃 [Nariztoteles] Teletransportado a posición guardada.")
    end
end

return function(register)
    register("COUNTER_ACTIVATE", handleCOUNTER_ACTIVATE)
    register("EMBESTIDA", handleEMBESTIDA)
    register("TELEPORT_HACK_SAVE", handleTELEPORT_HACK_SAVE)
end