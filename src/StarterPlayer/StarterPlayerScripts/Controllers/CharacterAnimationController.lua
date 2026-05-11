-- =============================================================================
-- CharacterAnimationController.lua
-- Ubicación: src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterAnimationController.lua
--
-- Maneja animaciones y cámara de personajes custom.
--
-- Estrategia de animaciones:
--   Si el modelo tiene HumanoidDescription → usamos ApplyDescription().
--   Roblox carga automáticamente todas las animaciones del Description
--   (Idle, Walk, Run, Jump, Fall, Climb, Swim) sin que tengamos que
--   gestionar los tracks manualmente.
--
--   Si NO tiene HumanoidDescription → fallback manual con GameConstants.
-- =============================================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local GameConstants  = require(ReplicatedStorage.GameConstants)

local CharacterAnimationController = {}

-- Conexiones y tracks del sistema de animación manual (fallback).
-- Solo se usan si el modelo no tiene HumanoidDescription.
local _activeConnections: {RBXScriptConnection} = {}
local _activeAnimations:  {AnimationTrack}      = {}

-- =============================================================================
-- Limpieza del sistema manual
-- =============================================================================

local function cleanupManual()
    for _, track in ipairs(_activeAnimations) do
        if track.IsPlaying then track:Stop(0) end
    end
    table.clear(_activeAnimations)

    for _, conn in ipairs(_activeConnections) do
        conn:Disconnect()
    end
    table.clear(_activeConnections)
end

-- =============================================================================
-- Estrategia A: HumanoidDescription (preferida)
--
-- El modelo PORO ya incluye un HumanoidDescription con sus propios IDs
-- de animación. Humanoid:ApplyDescription() los aplica todos de golpe
-- y Roblox gestiona la máquina de estados de animación por nosotros.
-- Los IDs del Description pertenecen al creador del modelo, por eso cargan.
-- =============================================================================

local function applyDescriptionAnimations(humanoid: Humanoid, description: HumanoidDescription): boolean
    local ok, err = pcall(function()
        humanoid:ApplyDescription(description)
    end)

    if ok then
        print("🎬 [AnimController] HumanoidDescription aplicado correctamente.")
    else
        warn("[AnimController] ApplyDescription falló: " .. tostring(err))
    end

    return ok
end

-- =============================================================================
-- Estrategia B: Animación manual con Animator (fallback)
--
-- Se usa cuando el modelo no tiene HumanoidDescription.
-- Lee los IDs de GameConstants y maneja la máquina de estados con Heartbeat.
-- =============================================================================

local function setupManualAnimations(humanoid: Humanoid, animator: Animator)
    cleanupManual()

    local anims = GameConstants.Animations.Shared

    local function loadTrack(animId: string): AnimationTrack?
        if not animId or animId == "" then return nil end
        local anim     = Instance.new("Animation")
        anim.AnimationId = animId
        local ok, track = pcall(function()
            return animator:LoadAnimation(anim)
        end)
        anim:Destroy()
        if ok and track then
            table.insert(_activeAnimations, track)
            return track
        end
        return nil
    end

    local trackIdle = loadTrack(anims.Idle)
    local trackWalk = loadTrack(anims.Walk)
    local trackRun  = loadTrack(anims.Run)
    local trackJump = loadTrack(anims.Jump)

    if trackIdle then trackIdle.Priority = Enum.AnimationPriority.Idle     end
    if trackWalk then trackWalk.Priority = Enum.AnimationPriority.Movement end
    if trackRun  then trackRun.Priority  = Enum.AnimationPriority.Movement end
    if trackJump then trackJump.Priority = Enum.AnimationPriority.Action   end

    if trackIdle then trackIdle:Play() end

    local heartbeatConn = game:GetService("RunService").Heartbeat:Connect(function()
        if not humanoid.Parent then
            cleanupManual()
            return
        end

        local speed    = humanoid.MoveDirection.Magnitude
        local state    = humanoid:GetState()
        local walkSpd  = humanoid.WalkSpeed

        local isJumping = (state == Enum.HumanoidStateType.Jumping
                        or state == Enum.HumanoidStateType.Freefall)
        local isMoving  = speed > 0.1
        local isRunning = isMoving and walkSpd > (GameConstants.Movement.DEFAULT_WALK_SPEED + 2)

        if isJumping then
            if trackJump and not trackJump.IsPlaying then
                if trackIdle then trackIdle:Stop(0.1) end
                if trackWalk then trackWalk:Stop(0.1) end
                if trackRun  then trackRun:Stop(0.1)  end
                trackJump:Play(0.1)
            end
            return
        end

        if trackJump and trackJump.IsPlaying then
            trackJump:Stop(0.2)
        end

        if isRunning then
            if trackRun and not trackRun.IsPlaying then
                if trackIdle then trackIdle:Stop(0.1) end
                if trackWalk then trackWalk:Stop(0.1) end
                trackRun:Play(0.1)
            end
        elseif isMoving then
            if trackWalk and not trackWalk.IsPlaying then
                if trackIdle then trackIdle:Stop(0.1) end
                if trackRun  then trackRun:Stop(0.1)  end
                trackWalk:Play(0.1)
            end
        else
            if trackIdle and not trackIdle.IsPlaying then
                if trackWalk then trackWalk:Stop(0.1) end
                if trackRun  then trackRun:Stop(0.1)  end
                trackIdle:Play(0.1)
            end
        end
    end)

    table.insert(_activeConnections, heartbeatConn)
    print("🎬 [AnimController] Animaciones manuales (fallback) cargadas.")
end

-- =============================================================================
-- Setup principal: Configura la cámara y confía en el Animate nativo
-- =============================================================================
local function setupCharacter(character: Model)
    cleanupManual()

    local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
    if not humanoid then
        warn("[AnimController] Humanoid no encontrado en " .. character.Name)
        return
    end

    -- 1. Configurar la cámara para que siga al clon
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraSubject = humanoid
        camera.CameraType    = Enum.CameraType.Follow
    end

    -- 2. Ya NO intentamos cargar IDs manuales de GameConstants porque 
    -- Roblox bloquea animaciones ajenas. 
    -- Confiamos en el script "Animate" que inyectó el RespawnManagerService.
    print("🎬 [AnimController] Cámara lista. Animaciones delegadas al servidor.")
end

-- =============================================================================
-- Start
-- =============================================================================

function CharacterAnimationController.Start()
    print("🎬 [AnimController] Iniciado.")

    local player = Players.LocalPlayer

    -- Personajes custom de partida: el servidor dispara SetupCharacter
    RemoteRegistry.SetupCharacter.OnClientEvent:Connect(function()
        local character = player.Character
        if not character then
            character = player.CharacterAdded:Wait()
        end
        setupCharacter(character)
    end)

    -- Personajes de Lobby (LoadCharacter): Roblox inyecta Animate automáticamente,
    -- solo necesitamos asegurar que la cámara apunte al Humanoid correcto.
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", 5)
        local camera   = workspace.CurrentCamera
        if humanoid and camera then
            if camera.CameraSubject ~= humanoid then
                camera.CameraSubject = humanoid
                camera.CameraType    = Enum.CameraType.Follow
            end
        end
    end)
end

return CharacterAnimationController