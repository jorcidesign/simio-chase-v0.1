-- =============================================================================
-- InputController.lua
-- Ubicación: src/StarterPlayer/StarterPlayerScripts/Controllers/InputController.lua
--
-- CAMBIOS vs versión anterior:
--
--   ✅ OnSkillCasted (señal pública)
--      Misma filosofía que OnSprintChanged: evita import circular entre
--      InputController y SkillHUDController. Se asigna en ClientMain:
--        InputController.OnSkillCasted = SkillHUDController.onSkillCastedLocally
--      Se dispara ANTES de enviar el RemoteEvent al servidor, dando feedback
--      inmediato en UI. Si el servidor rechaza el cast emitirá SkillCastConfirmed
--      solo cuando lo acepte; el HUD puede resetear en ese evento si necesita
--      sincronización perfecta (diseño actual: optimistic UI).
--
-- SIN CAMBIOS en lógica de juego: M1, Sprint, habilidades.
-- =============================================================================

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry               = require(ReplicatedStorage.Network.RemoteRegistry)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)

local InputController = {}

-- ---------------------------------------------------------------------------
-- Señales públicas
-- Asignadas en ClientMain para evitar imports circulares.
-- ---------------------------------------------------------------------------

--- Conectar a StaminaController.setSprint en ClientMain.
InputController.OnSprintChanged = nil :: ((active: boolean) -> ())?

--- ✅ NUEVO: Conectar a SkillHUDController.onSkillCastedLocally en ClientMain.
--- Args: (keyName: string, cooldown: number)
--- keyName = "Q" | "E" | "R" | "F"
--- cooldown = duración del cooldown en segundos (leída del catálogo del personaje)
InputController.OnSkillCasted = nil :: ((keyName: string, cooldown: number) -> ())?

-- ---------------------------------------------------------------------------
-- Cooldown local de M1
-- ---------------------------------------------------------------------------
local M1_LOCAL_CD = 0.35
local _lastM1Time = 0
local _attackFlip = false

-- ---------------------------------------------------------------------------
-- Keybinds de habilidades
-- ---------------------------------------------------------------------------
local KILLER_KEYBINDS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Q] = "MARCHA",
	[Enum.KeyCode.E] = "ESTRANGULAR",
	[Enum.KeyCode.R] = "RAGE MODE",
	[Enum.KeyCode.F] = "PISOTÓN",
}

local SURVIVOR_KEYBINDS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Q] = "CEGUERA",
	[Enum.KeyCode.E] = "CAMUFLAJE",
	[Enum.KeyCode.R] = "DOBLE SALTO",
	[Enum.KeyCode.F] = "TRAMPA",
}

-- Mapa tecla → slot de animación (independiente del rol)
local KEY_TO_ANIM_SLOT: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Q] = "SkillQ",
	[Enum.KeyCode.E] = "SkillE",
	[Enum.KeyCode.R] = "SkillR",
	[Enum.KeyCode.F] = "SkillF",
}

-- Mapa tecla → nombre de tecla para el HUD
local KEY_TO_NAME: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R",
	[Enum.KeyCode.F] = "F",
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function getCharacter(): Model?
	return Players.LocalPlayer.Character
end

local function isKiller(): boolean
	local char = getCharacter()
	return char ~= nil and char:FindFirstChild("KillerID") ~= nil
end

local function isSurvivor(): boolean
	local char = getCharacter()
	return char ~= nil and char:FindFirstChild("SurvivorID") ~= nil
end

local function isAlive(): boolean
	local char = getCharacter()
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

--- Busca la definición de una habilidad del personaje local para leer su cooldown.
--- Retorna el cooldown en segundos, o 0 si no encuentra la definición.
local function getSkillCooldown(keyCode: Enum.KeyCode): number
	local char = getCharacter()
	if not char then return 0 end

	-- Determinar el ServerName que corresponde a esta tecla
	local serverName: string? = nil
	if isKiller() then
		serverName = KILLER_KEYBINDS[keyCode]
	elseif isSurvivor() then
		serverName = SURVIVOR_KEYBINDS[keyCode]
	end
	if not serverName then return 0 end

	-- Intentar leer el cooldown desde el CharacterRegistry vía ReplicatedStorage.
	-- Como el CharacterRegistry es server-only, el cliente no tiene acceso directo.
	-- En su lugar, el cooldown authoritative llega vía SkillCastConfirmed del servidor.
	-- Para el feedback optimista inmediato, devolvemos 0 y dejamos que
	-- SkillCastConfirmed sobreescriba con el valor real.
	-- Si se quiere feedback inmediato con cooldown correcto, cargar una tabla
	-- de cooldowns espejada en ReplicatedStorage (fuera del scope de este sprint).
	return 0
end

-- ---------------------------------------------------------------------------
-- M1 Attack
-- ---------------------------------------------------------------------------

local function tryM1()
	if not isKiller() then return end
	if not isAlive()  then return end

	local now = os.clock()
	if (now - _lastM1Time) < M1_LOCAL_CD then return end
	_lastM1Time = now

	local tracks = CharacterAnimationController.Tracks
	_attackFlip  = not _attackFlip
	local attackTrack = _attackFlip and tracks.Attack1 or tracks.Attack2
	if attackTrack then
		if attackTrack.IsPlaying then attackTrack:Stop(0) end
		attackTrack:Play(0.05)
	end

	RemoteRegistry.M1Attack:FireServer()
end

-- ---------------------------------------------------------------------------
-- Habilidades (Q / E / R / F)
-- ---------------------------------------------------------------------------

local function trySkill(keyCode: Enum.KeyCode)
	if not isAlive() then return end

	local serverName: string? = nil
	local slotName   = KEY_TO_ANIM_SLOT[keyCode]
	local keyName    = KEY_TO_NAME[keyCode]

	if isKiller() then
		serverName = KILLER_KEYBINDS[keyCode]
		if serverName then
			if slotName then
				CharacterAnimationController.playSkillAnim(slotName)
			end
			RemoteRegistry.UseKillerAbility:FireServer(serverName, nil)

			-- ✅ Notificar al SkillHUDController del cast local (feedback optimista).
			-- El cooldown real llegará vía SkillCastConfirmed del servidor.
			if InputController.OnSkillCasted and keyName then
				InputController.OnSkillCasted(keyName, 0)
			end
		end

	elseif isSurvivor() then
		serverName = SURVIVOR_KEYBINDS[keyCode]
		if serverName then
			if slotName then
				CharacterAnimationController.playSkillAnim(slotName)
			end
			RemoteRegistry.UseSurvivorAbility:FireServer(serverName, nil)

			if InputController.OnSkillCasted and keyName then
				InputController.OnSkillCasted(keyName, 0)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Sprint
-- ---------------------------------------------------------------------------

local _isSprinting = false

local function setSprint(active: boolean)
	if _isSprinting == active then return end
	_isSprinting = active
	if InputController.OnSprintChanged then
		InputController.OnSprintChanged(active)
	end
end

-- ---------------------------------------------------------------------------
-- Listeners de input
-- ---------------------------------------------------------------------------

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	local inputType = input.UserInputType
	local keyCode   = input.KeyCode

	if inputType == Enum.UserInputType.MouseButton1
	or inputType == Enum.UserInputType.Touch then
		tryM1()
		return
	end

	if keyCode == Enum.KeyCode.LeftShift
	or keyCode == Enum.KeyCode.RightShift then
		setSprint(true)
		return
	end

	if keyCode == Enum.KeyCode.Q
	or keyCode == Enum.KeyCode.E
	or keyCode == Enum.KeyCode.R
	or keyCode == Enum.KeyCode.F then
		trySkill(keyCode)
	end
end

local function onInputEnded(input: InputObject, _gameProcessed: boolean)
	local keyCode = input.KeyCode
	if keyCode == Enum.KeyCode.LeftShift
	or keyCode == Enum.KeyCode.RightShift then
		setSprint(false)
	end
end

-- ---------------------------------------------------------------------------
-- Start
-- ---------------------------------------------------------------------------

function InputController.Start()
	print("🎮 [InputController] Iniciado.")
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
end

return InputController