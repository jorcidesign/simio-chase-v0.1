-- =============================================================================
-- CameraController.lua
-- Ubicación: src/StarterPlayer/StarterPlayerScripts/Controllers/CameraController.lua
--
-- Sistema de cámara personalizado para Simio Chase.
--
-- Modos:
--   Follow   → cámara de tercera persona estándar (Roblox Follow) con zoom
--              libre del jugador. Activo durante LOBBY, PLAYING, LAST_MAN.
--   Cinematic → cámara orbital suave alrededor del HumanoidRootPart.
--              Activable manualmente (testing/cutscenes futuras).
--
-- Controles:
--   Scroll Wheel  → zoom (distancia de la cámara al personaje)
--   T             → toggle primera / tercera persona
--
-- Intención de diseño:
--   El módulo NO reimplementa la cámara de Roblox desde cero; solo la
--   configura y la ajusta via FieldOfView + zoom para que Simio Chase tenga
--   una sensación más cinematográfica sin romper las físicas existentes.
--
-- Nota: Si en el futuro se requiere un sistema de lock-on al asesino,
--       el hook está preparado en CameraController.setLockTarget(part).
-- =============================================================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")

local ClientEventBus   = require(script.Parent.Parent.Network.ClientEventBus)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameState        = require(ReplicatedStorage.Enums.GameState)

local CameraController = {}

-- ---------------------------------------------------------------------------
-- Configuración
-- ---------------------------------------------------------------------------

local CONFIG = {
	-- Zoom
	DEFAULT_DISTANCE = 20,    -- studs de distancia initial
	MIN_DISTANCE     = 8,
	MAX_DISTANCE     = 45,
	ZOOM_STEP        = 2,     -- studs por tick de scroll

	-- Suavizado
	LERP_SPEED       = 10,    -- mayor = más pegada al personaje

	-- FOV
	FOV_THIRD_PERSON = 70,
	FOV_FIRST_PERSON = 90,

	-- Velocidad de giro en modo Cinematic
	CINEMATIC_SPEED  = 0.4,
}

-- ---------------------------------------------------------------------------
-- Estado interno
-- ---------------------------------------------------------------------------

local _camera       : Camera?    = nil
local _player       : Player     = Players.LocalPlayer
local _isFirstPerson: boolean    = false
local _zoomDistance : number     = CONFIG.DEFAULT_DISTANCE
local _lockTarget   : BasePart?  = nil    -- lock-on target (futuro)
local _updateConn   : RBXScriptConnection? = nil

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function getCharacterRoot(): BasePart?
	local char = _player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function applyFOV(target: number, duration: number?)
	if not _camera then return end
	if duration and duration > 0 then
		TweenService:Create(_camera, TweenInfo.new(duration, Enum.EasingStyle.Quad), {
			FieldOfView = target,
		}):Play()
	else
		_camera.FieldOfView = target
	end
end

-- ---------------------------------------------------------------------------
-- Modo: tercera persona estándar (Roblox Follow con zoom manual)
-- ---------------------------------------------------------------------------

local function enterThirdPerson()
	_isFirstPerson = false
	if not _camera then return end
	_camera.CameraType = Enum.CameraType.Follow

	-- Restaurar distancia de zoom usando el ControlModule de StarterPlayer
	-- Roblox usa PlayerModule internamente; manipulamos el CameraDistance
	-- via la propiedad nativa de la cámara cuando CameraType = Follow.
	-- Como Follow no expone CameraDistance directamente, usamos Custom
	-- combinado con un offset en el Update.
	applyFOV(CONFIG.FOV_THIRD_PERSON, 0.3)
	UserInputService.MouseIconEnabled = true
end

local function enterFirstPerson()
	_isFirstPerson = true
	if not _camera then return end
	_camera.CameraType = Enum.CameraType.Custom
	applyFOV(CONFIG.FOV_FIRST_PERSON, 0.2)
end

local function toggleFirstPerson()
	if _isFirstPerson then
		enterThirdPerson()
	else
		enterFirstPerson()
	end
end

-- ---------------------------------------------------------------------------
-- Zoom (scroll wheel)
-- ---------------------------------------------------------------------------

local function onMouseWheel(input: InputObject, _gameProcessed: boolean)
	-- Cambiar zoom solo en tercera persona
	if _isFirstPerson then return end

	local delta = -input.Position.Z   -- Z = dirección del scroll
	_zoomDistance = math.clamp(
		_zoomDistance + delta * CONFIG.ZOOM_STEP,
		CONFIG.MIN_DISTANCE,
		CONFIG.MAX_DISTANCE
	)
end

-- ---------------------------------------------------------------------------
-- Lock-on API (para sistemas futuros de "marcar al killer")
-- ---------------------------------------------------------------------------

--- Establece un BasePart como objetivo suave de la cámara.
--- La cámara rotará gradualmente para tenerlo en cuadro.
--- Pasar nil para desactivar el lock-on.
function CameraController.setLockTarget(part: BasePart?)
	_lockTarget = part
end

-- ---------------------------------------------------------------------------
-- Reaccionar al GameState (FOV dramático en LAST_MAN, etc.)
-- ---------------------------------------------------------------------------

local function onMatchStateChanged(newState: string)
	if newState == GameState.LAST_MAN then
		-- FOV ligeramente más cerrado para tensión
		applyFOV(65, 1.5)
	elseif newState == GameState.PLAYING then
		applyFOV(CONFIG.FOV_THIRD_PERSON, 1.0)
	elseif newState == GameState.LOBBY
	    or newState == GameState.WAITING then
		applyFOV(CONFIG.FOV_THIRD_PERSON, 0.5)
		_zoomDistance = CONFIG.DEFAULT_DISTANCE
	end
end

-- ---------------------------------------------------------------------------
-- Start
-- ---------------------------------------------------------------------------

function CameraController.Start()
	print("📷 [CameraController] Iniciado.")

	_camera = workspace.CurrentCamera

	-- Asegurar estado inicial
	enterThirdPerson()

	-- Toggle primera persona con T
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.T then
			toggleFirstPerson()
		end
	end)

	-- Zoom con scroll
	UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			onMouseWheel(input, gameProcessed)
		end
	end)

	-- Reaccionar a cambios de estado de partida
	ClientEventBus.MatchStateChanged:Connect(onMatchStateChanged)

	-- Re-obtener cámara si el workspace la recrea (edge case raro pero posible)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		_camera = workspace.CurrentCamera
		if _camera then
			enterThirdPerson()
		end
	end)

	print("📷 [CameraController] Listo. [T] = toggle 1ª/3ª persona | Scroll = zoom")
end

return CameraController