-- =============================================================================
-- JALY_Handler.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local DamageSystem = require(ServerScriptService.Systems.DamageSystem)
local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local function handleDASH_AXE(ctx)
    local char = ctx.char
    local root = ctx.root
    local player = ctx.player
    
    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "Q", 20)
    
    local speed = 100
    local duration = 0.35 
    local elapsed = 0
    local hitSomething = false

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = root.CFrame.LookVector * speed
    bv.MaxForce = Vector3.new(1e5, 0, 1e5)
    bv.Parent = root
    Debris:AddItem(bv, duration)

    local dashConn
    dashConn = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= duration or not root.Parent then
            dashConn:Disconnect()
            if bv.Parent then bv:Destroy() end
            
            if not hitSomething then
                -- Penalización si no golpea a nadie
                StatusEffectSystem.apply(char, StatusEffectType.SLOW, 5, 1.5)
            end
            return
        end

        local params = OverlapParams.new()
        params.FilterDescendantsInstances = {char}
        params.FilterType = Enum.RaycastFilterType.Exclude

        local parts = workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(6,6,6), params)
        for _, p in ipairs(parts) do
            local hitChar = p.Parent
            if hitChar:FindFirstChild("SurvivorID") then
                hitSomething = true
                dashConn:Disconnect()
                if bv.Parent then bv:Destroy() end
                DamageSystem.applyDamage(hitChar, 10, char)
                break
            end
        end
    end)
end

local function handleRAFAGA_TOXICA(ctx)
    local root = ctx.root
    local player = ctx.player
    
    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "E", 25)

    local sphere = Instance.new("Part")
    sphere.Shape = Enum.PartType.Ball
    sphere.Size = Vector3.new(30, 30, 30)
    sphere.Position = root.Position
    sphere.Color = Color3.fromRGB(0, 255, 100)
    sphere.Material = Enum.Material.Neon
    sphere.Transparency = 0.6
    sphere.Anchored = true
    sphere.CanCollide = false
    sphere.Parent = workspace
    
    local tickConn
    local elapsed = 0
    tickConn = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= 5 or not sphere.Parent then
            tickConn:Disconnect()
            if sphere.Parent then sphere:Destroy() end
            return
        end
        
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        local survivors = {}
        for _, p in ipairs(game.Players:GetPlayers()) do
            if p.Character and p.Character:FindFirstChild("SurvivorID") then
                table.insert(survivors, p.Character)
            end
        end
        params.FilterDescendantsInstances = survivors

        local parts = workspace:GetPartBoundsInBox(sphere.CFrame, sphere.Size, params)
        for _, p in ipairs(parts) do
            local hitChar = p.Parent
            local hum = hitChar:FindFirstChild("Humanoid")
            if hum then
                -- Slow muy breve pero constante mientras esté dentro de la esfera
                StatusEffectSystem.apply(hitChar, StatusEffectType.SLOW, hum.WalkSpeed * 0.5, 0.2)
            end
        end
    end)
end

local function handleFRENESI_SIMIO(ctx)
    local char = ctx.char
    local player = ctx.player
    
    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "F", 25)
    
    local frenzy = char:FindFirstChild("FrenzyActive")
    if frenzy then frenzy.Value = true end
    
    StatusEffectSystem.apply(char, StatusEffectType.SPEED_BOOST, 1.3, 10)
    
    task.delay(10, function()
        if frenzy and frenzy.Parent then
            frenzy.Value = false
        end
    end)
end

return function(register)
    register("DASH_AXE", handleDASH_AXE)
    register("RAFAGA_TOXICA", handleRAFAGA_TOXICA)
    register("FRENESI_SIMIO", handleFRENESI_SIMIO)
end