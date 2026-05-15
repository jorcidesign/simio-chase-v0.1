-- =============================================================================
-- PORO_Handler.lua
-- Ubicación: src/ServerScriptService/SkillHandlers/PORO_Handler.lua
--
-- CAMBIOS:
--   ✅ FIX TYPE ERROR: Se movió _activateRageMode hacia arriba para evitar el
--      error Luau1032 (Type could be nil).
--   ✅ RAGE MODE REWORK: Ahora otorga Visión Global (ESP/Wallhack) de los
--      supervivientes en lugar de alterar velocidades o físicas.
--   ✅ ANIMACIONES DESACTIVADAS: Se eliminaron las llamadas a SkillAnimStop
--      para evitar bugs de físicas/teletransporte temporales.
-- =============================================================================

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local Debris              = game:GetService("Debris")
local TweenService        = game:GetService("TweenService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local DamageSystem       = require(ServerScriptService.Systems.DamageSystem)
local StatusEffectType   = require(ReplicatedStorage.Enums.StatusEffectType)
local RemoteRegistry     = require(ReplicatedStorage.Network.RemoteRegistry)

-- =============================================================================
-- Constantes de diseño
-- =============================================================================

local RAGE_MODE_DURATION  = 40    -- segundos
local PORO_BASE_SPEED     = 20    -- fallback

-- Valor centinela de reset en StaminaController
local RAGE_RESET_SENTINEL = -999

-- Mapeo: ServerName → tecla para SkillCastConfirmed
local SERVER_NAME_TO_KEY: { [string]: string } = {
    MARCHA      = "Q",
    ESTRANGULAR = "E",
    ["RAGE MODE"] = "R",
    ["PISOTÓN"]   = "F",
}

local SERVER_NAME_TO_COOLDOWN: { [string]: number } = {
    MARCHA        = 15,
    ESTRANGULAR   = 22,
    ["RAGE MODE"] = 0,
    ["PISOTÓN"]   = 30,
}

-- =============================================================================
-- Helpers
-- =============================================================================

local function confirmCast(player: Player, serverName: string)
    local keyName  = SERVER_NAME_TO_KEY[serverName]
    local cooldown = SERVER_NAME_TO_COOLDOWN[serverName] or 0
    if keyName then
        RemoteRegistry.SkillCastConfirmed:FireClient(player, keyName, cooldown)
    end
end

local function getPoroBassSpeed(): number
    local ok, reg = pcall(function()
        return require(ServerScriptService.Data.CharacterRegistry)
    end)
    if not ok or not reg then return PORO_BASE_SPEED end
    local config = reg.getKiller("PORO")
    return config and config.BaseSpeed or PORO_BASE_SPEED
end

-- =============================================================================
-- RAGE MODE LOGIC (Definido primero para evitar el TypeError Luau1032)
-- =============================================================================

local function _activateRageMode(killer: Model, player: Player)
    -- ✅ Confirmar cast al HUD
    if player and player.Parent then
        RemoteRegistry.SkillCastConfirmed:FireClient(player, "R", RAGE_MODE_DURATION)
    end

    local root = killer:FindFirstChild("HumanoidRootPart")
    if root then
        local sfx = Instance.new("Sound", root)
        sfx.SoundId = "rbxassetid://5869221703"
        sfx.Volume  = 1.0
        sfx:Play()
        Debris:AddItem(sfx, 3)
    end

    local rageTag  = Instance.new("BoolValue", killer)
    rageTag.Name   = "InRageMode"

    -- ✅ VISIÓN GLOBAL (ESP/Wallhack)
    -- Ponemos los Highlights en el PlayerGui del asesino para que SOLO ÉL los vea
    local activeHighlights = {}
    local playerGui = player:FindFirstChild("PlayerGui")
    
    if playerGui then
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("SurvivorID") then
                local hl = Instance.new("Highlight")
                hl.Name = "VisionRage_" .. otherPlayer.Name
                hl.Adornee = otherPlayer.Character
                hl.FillColor = Color3.fromRGB(255, 30, 0)
                hl.FillTransparency = 0.5
                hl.OutlineColor = Color3.fromRGB(255, 100, 0)
                hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Permite ver a través de las paredes
                hl.Parent = playerGui 
                table.insert(activeHighlights, hl)
            end
        end
    end

    print(string.format("🔥 [PORO] RAGE MODE (Visión Global) activado para %s (%ds).", player.Name, RAGE_MODE_DURATION))

    -- Limpieza al terminar
    task.delay(RAGE_MODE_DURATION, function()
        if rageTag.Parent then rageTag:Destroy() end

        -- Limpiar la visión global (destruir Highlights)
        for _, hl in ipairs(activeHighlights) do
            if hl and hl.Parent then
                hl:Destroy()
            end
        end

        -- Reset de rage en cliente usando centinela
        if player and player.Parent then
            RemoteRegistry.RageUpdated:FireClient(player, RAGE_RESET_SENTINEL)
        end

        -- Reset de rage en servidor si el Poro sigue vivo
        if killer and killer.Parent then
            local rm = killer:FindFirstChild("RageMeter")
            if rm then rm.Value = 0 end
        end

        print("🔥 [PORO] RAGE MODE terminado.")
    end)
end

-- =============================================================================
-- Notificar rage delta (Definido después para usar _activateRageMode sin bugs)
-- =============================================================================

local function giveRage(killer: Model, amount: number)
    local player = Players:GetPlayerFromCharacter(killer)
    if not player then return end

    local rageMeter = killer:FindFirstChild("RageMeter")
    if not rageMeter then return end

    local oldValue   = rageMeter.Value
    rageMeter.Value  = math.min(rageMeter.Value + amount, 100)
    local gained     = rageMeter.Value - oldValue

    if gained > 0 then
        RemoteRegistry.RageUpdated:FireClient(player, gained)
    end

    -- Activar automáticamente si llega a 100
    if rageMeter.Value >= 100 and not killer:FindFirstChild("RAGE MODE_Used") then
        local usedTag  = Instance.new("BoolValue")
        usedTag.Name   = "RAGE MODE_Used"
        usedTag.Parent = killer
        _activateRageMode(killer, player)
    end
end

-- =============================================================================
-- Q — MARCHA: Dash lineal
-- =============================================================================

local function handleMARCHA(ctx)
    local char  = ctx.char
    local root  = ctx.root
    local hum   = ctx.hum
    local skill = ctx.skillDef
    local player = ctx.player

    local speed    = skill.Speed          or 55
    local duration = skill.Duration       or 0.6
    local damage   = skill.Damage         or 15
    local selfStun = skill.SelfStunOnWall or 2.0

    confirmCast(player, "MARCHA")

    local sfx = Instance.new("Sound", root)
    sfx.SoundId = "rbxassetid://4119578167"
    sfx.Volume  = 0.7
    sfx:Play()
    Debris:AddItem(sfx, 2)

    local originalSpeed = hum.WalkSpeed
    hum.WalkSpeed = speed

    local hitSomething = false
    local elapsed = 0

    local function endDash(wasWallHit: boolean)
        local baseSpeed = getPoroBassSpeed()
        if hum and hum.Parent then
            hum.WalkSpeed = baseSpeed
        end

        -- [!] Animación comentada intencionalmente por ahora
        -- if player and player.Parent then
        --     RemoteRegistry.SkillAnimStop:FireClient(player, "SkillQ")
        -- end

        if not wasWallHit then
            local params = OverlapParams.new()
            params.FilterDescendantsInstances = { char }
            params.FilterType = Enum.RaycastFilterType.Exclude
            local parts = workspace:GetPartBoundsInBox(
                root.CFrame,
                Vector3.new(8, 7, 8),
                params
            )
            for _, part in ipairs(parts) do
                local victimChar = part.Parent
                if victimChar:FindFirstChild("SurvivorID") then
                    DamageSystem.applyDamage(victimChar, damage, char)
                    giveRage(char, 10)
                end
            end
        end
    end

    local dashConn
    dashConn = RunService.Heartbeat:Connect(function(dt: number)
        elapsed += dt

        if elapsed >= duration or not root.Parent then
            dashConn:Disconnect()
            endDash(false)
            return
        end

        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = { char }
        rayParams.FilterType = Enum.RaycastFilterType.Exclude

        local lookDir   = root.CFrame.LookVector
        local rayResult = workspace:Raycast(root.Position, lookDir * 4, rayParams)

        if rayResult then
            hitSomething = true
            dashConn:Disconnect()

            endDash(true)
            StatusEffectSystem.apply(char, StatusEffectType.STUN, 0, selfStun)

            local impact = Instance.new("Part", workspace)
            impact.Size        = Vector3.new(5, 5, 0.5)
            impact.CFrame      = root.CFrame
            impact.Color       = Color3.fromRGB(255, 120, 30)
            impact.Material    = Enum.Material.Neon
            impact.Transparency = 0.2
            impact.Anchored    = true
            impact.CanCollide  = false
            TweenService:Create(impact, TweenInfo.new(0.4), {
                Transparency = 1,
                Size = Vector3.new(8, 8, 0.5),
            }):Play()
            Debris:AddItem(impact, 0.4)

            giveRage(char, 5)
        end
    end)
end

-- =============================================================================
-- E — ESTRANGULAR: Proyectil de cadena
-- =============================================================================

local function handleESTRANGULAR(ctx)
    local char   = ctx.char
    local root   = ctx.root
    local hum    = ctx.hum
    local skill  = ctx.skillDef
    local player = ctx.player

    local range     = skill.Range     or 45
    local pullForce = skill.PullForce or 100
    local whiffSlow = skill.WhiffSlow or 0.5

    confirmCast(player, "ESTRANGULAR")

    local sfx = Instance.new("Sound", root)
    sfx.SoundId = "rbxassetid://5222668290"
    sfx.Volume  = 0.6
    sfx:Play()
    Debris:AddItem(sfx, 2)

    local projectile = Instance.new("Part", workspace)
    projectile.Size        = Vector3.new(0.8, 0.8, 2)
    projectile.Color       = Color3.fromRGB(80, 80, 80)
    projectile.Material    = Enum.Material.Metal
    projectile.CanCollide  = false
    projectile.Anchored    = true
    projectile.CFrame      = root.CFrame * CFrame.new(0, 0, -2)

    local direction = root.CFrame.LookVector
    local traveled  = 0
    local projSpeed = 60
    local hit       = false

    local projConn
    projConn = RunService.Heartbeat:Connect(function(dt: number)
        traveled += projSpeed * dt
        projectile.CFrame = projectile.CFrame + direction * projSpeed * dt

        local params = OverlapParams.new()
        params.FilterDescendantsInstances = { char }
        params.FilterType = Enum.RaycastFilterType.Exclude

        local parts = workspace:GetPartBoundsInBox(
            projectile.CFrame,
            Vector3.new(3, 3, 3),
            params
        )

        for _, part in ipairs(parts) do
            local victimChar = part.Parent
            if victimChar:FindFirstChild("SurvivorID") then
                hit = true

                local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")
                if victimRoot then
                    local toKiller = (root.Position - victimRoot.Position).Unit
                    local bv = Instance.new("BodyVelocity", victimRoot)
                    bv.Velocity  = toKiller * pullForce
                    bv.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
                    bv.P         = 1e4
                    Debris:AddItem(bv, 0.35)
                end

                DamageSystem.applyDamage(victimChar, 10, char)
                giveRage(char, 15)
                break
            end
        end

        if hit or traveled >= range or not root.Parent then
            projConn:Disconnect()
            if projectile.Parent then projectile:Destroy() end

            if not hit then
                local slowSpeed = hum.WalkSpeed * whiffSlow
                StatusEffectSystem.apply(char, StatusEffectType.SLOW, slowSpeed, 2)
            end
        end
    end)
end

-- =============================================================================
-- R — RAGE MODE: Disparador Manual
-- =============================================================================

local function handleRAGE_MODE(ctx)
    local killer  = ctx.char
    local player  = ctx.player

    local rageMeter = killer:FindFirstChild("RageMeter")
    if rageMeter and rageMeter.Value < 100 then
        local usedTag = killer:FindFirstChild("RAGE MODE_Used")
        if usedTag then usedTag:Destroy() end
        warn(string.format("[PORO] %s intentó RAGE MODE con solo %d/100 de ira.", player.Name, rageMeter.Value))
        return
    end

    _activateRageMode(killer, player)
end

-- =============================================================================
-- F — PISOTÓN: AoE de slow
-- =============================================================================

local function handlePISOTON(ctx)
    local char   = ctx.char
    local root   = ctx.root
    local skill  = ctx.skillDef
    local player = ctx.player

    local radius     = skill.Radius       or 25
    local slowFactor = skill.Slow         or 0.6
    local slowDur    = skill.SlowDuration or 3

    confirmCast(player, "PISOTÓN")

    local sfx = Instance.new("Sound", root)
    sfx.SoundId = "rbxassetid://5221820261"
    sfx.Volume  = 1.0
    sfx:Play()
    Debris:AddItem(sfx, 2)

    local wave = Instance.new("Part", workspace)
    wave.Shape        = Enum.PartType.Cylinder
    wave.Size         = Vector3.new(0.3, radius * 2, radius * 2)
    wave.CFrame       = root.CFrame * CFrame.Angles(0, 0, math.pi / 2)
    wave.Color        = Color3.fromRGB(80, 40, 10)
    wave.Material     = Enum.Material.Neon
    wave.Transparency = 0.3
    wave.Anchored     = true
    wave.CanCollide   = false

    TweenService:Create(wave, TweenInfo.new(0.5), {
        Size         = Vector3.new(0.1, radius * 2.5, radius * 2.5),
        Transparency = 1,
    }):Play()
    Debris:AddItem(wave, 0.5)

    local params = OverlapParams.new()
    params.FilterDescendantsInstances = { char }
    params.FilterType = Enum.RaycastFilterType.Exclude

    local parts = workspace:GetPartBoundsInBox(
        root.CFrame,
        Vector3.new(radius * 2, 10, radius * 2),
        params
    )

    local hitCount = 0
    local alreadyHit: { [Model]: boolean } = {}

    for _, part in ipairs(parts) do
        local victimChar = part.Parent
        if victimChar:FindFirstChild("SurvivorID") and not alreadyHit[victimChar] then
            alreadyHit[victimChar] = true
            hitCount += 1

            local victimHum = victimChar:FindFirstChildOfClass("Humanoid")
            if victimHum then
                local slowSpeed = victimHum.WalkSpeed * slowFactor
                StatusEffectSystem.apply(victimChar, StatusEffectType.SLOW, slowSpeed, slowDur)
            end
        end
    end

    giveRage(char, 10)
end

-- =============================================================================
-- Registro en SkillManagerService
-- =============================================================================

return function(register: (id: string, fn: (ctx: any) -> ()) -> ())
    register("MARCHA",      handleMARCHA)
    register("ESTRANGULAR", handleESTRANGULAR)
    register("RAGE_MODE",   handleRAGE_MODE)
    register("PISOTON",     handlePISOTON)
end