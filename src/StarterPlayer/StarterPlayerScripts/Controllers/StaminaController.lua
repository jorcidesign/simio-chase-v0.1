-- =============================================================================
-- StaminaController.lua
-- Ubicación: src/StarterPlayer/StarterPlayerScripts/Controllers/StaminaController.lua
-- =============================================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local GameConstants  = require(ReplicatedStorage.GameConstants)
local ClientEventBus = require(script.Parent.Parent.Network.ClientEventBus)

local StaminaController = {}

-- =============================================================================
-- Valor centinela para reset completo de rage
-- =============================================================================
local RAGE_RESET_SENTINEL = -999

-- =============================================================================
-- Estado local (Tipado Luau)
-- =============================================================================

local _stamina     = GameConstants.Stamina.DRAIN_RATE * 4
local _maxStamina  = 100
local _depleted    = false
local _isSprinting = false

local _rage    = 0
local _rageMax = 100

-- Variables de UI con posibilidad de ser nil (?)
local _staminaBar:   Frame?      = nil
local _staminaFill:  Frame?      = nil
local _staminaLabel: TextLabel?  = nil
local _rageBar:      Frame?      = nil
local _rageFill:     Frame?      = nil
local _rageLabel:    TextLabel?  = nil
local _screenGui:    ScreenGui?  = nil

-- =============================================================================
-- Detección de rol
-- =============================================================================

local function isLocalPoro(): boolean
	local player = Players.LocalPlayer
	local char = player.Character
	if not char then return false end
	local tag = char:FindFirstChild("KillerID")
	return tag ~= nil and tag:IsA("StringValue") and tag.Value == "PORO"
end

local function isLocalKiller(): boolean
	local player = Players.LocalPlayer
	local char = player.Character
	return char ~= nil and char:FindFirstChild("KillerID") ~= nil
end

-- =============================================================================
-- UI Builder
-- =============================================================================

local function destroyUI()
	-- Luau FIX: Comprobamos si existe antes de intentar destruir
	if _screenGui then
		_screenGui:Destroy()
		_screenGui = nil
	end
	_staminaBar   = nil
	_staminaFill  = nil
	_staminaLabel = nil
	_rageBar      = nil
	_rageFill     = nil
	_rageLabel    = nil
end

local function buildUI(showStamina: boolean, showRage: boolean)
	destroyUI()

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local newGui = Instance.new("ScreenGui")
	newGui.Name           = "StaminaHUD"
	newGui.IgnoreGuiInset = true
	newGui.ResetOnSpawn   = false
	newGui.Parent         = playerGui
	_screenGui = newGui

	-- Helper para crear barras (Tipado explícito en el retorno)
	local function makeBar(yPos: number, color: Color3, label: string): (Frame, Frame, TextLabel)
		local container = Instance.new("Frame")
		container.Size             = UDim2.new(0, 220, 0, 28)
		container.Position         = UDim2.new(0, 20, 1, yPos)
		container.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
		container.BackgroundTransparency = 0.4
		container.BorderSizePixel  = 0
		container.Parent           = _screenGui -- Aquí Luau confía porque acabamos de crear _screenGui

		Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)

		local fill = Instance.new("Frame")
		fill.Size             = UDim2.new(1, 0, 1, 0)
		fill.BackgroundColor3 = color
		fill.BorderSizePixel  = 0
		fill.Parent           = container
		Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 13
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextXAlignment = Enum.TextXAlignment.Center
		lbl.Text = label
		lbl.Parent = container

		return container, fill, lbl
	end

	if showStamina then
		local bar, fill, lbl = makeBar(-60, Color3.fromRGB(60, 200, 100), "STAMINA")
		_staminaBar   = bar
		_staminaFill  = fill
		_staminaLabel = lbl
	end

	if showRage then
		local bar, fill, lbl = makeBar(-96, Color3.fromRGB(220, 60, 40), "IRA: 0 / 100")
		_rageBar   = bar
		_rageFill  = fill
		_rageLabel = lbl
		if _rageFill then
			_rageFill.Size = UDim2.new(0, 0, 1, 0)
		end
	end
end

-- =============================================================================
-- Actualizar barras visuales
-- =============================================================================

local function updateStaminaVisual()
	-- Luau FIX: Si no existen, salimos de la función
	if not _staminaFill or not _staminaLabel then return end
	
	local ratio = math.clamp(_stamina / _maxStamina, 0, 1)
	TweenService:Create(_staminaFill, TweenInfo.new(0.1), {
		Size = UDim2.new(ratio, 0, 1, 0)
	}):Play()

	local color = _depleted
		and Color3.fromRGB(200, 50, 50)
		or (ratio < 0.3 and Color3.fromRGB(220, 180, 30) or Color3.fromRGB(60, 200, 100))
	
	_staminaFill.BackgroundColor3 = color
	_staminaLabel.Text = _depleted and "STAMINA AGOTADA" or "STAMINA"
end

local function updateRageVisual()
	-- Luau FIX: Salida temprana si la UI no está lista
	if not _rageFill or not _rageLabel then return end
	
	local ratio = math.clamp(_rage / _rageMax, 0, 1)
	TweenService:Create(_rageFill, TweenInfo.new(0.15), {
		Size = UDim2.new(ratio, 0, 1, 0)
	}):Play()
	
	_rageLabel.Text = string.format("IRA: %d / 100", math.floor(_rage))

	if _rage >= _rageMax then
		_rageFill.BackgroundColor3 = Color3.fromRGB(255, 140, 20)
		_rageLabel.Text = "¡RAGE LISTO!"
	else
		_rageFill.BackgroundColor3 = Color3.fromRGB(220, 60, 40)
	end
end

-- =============================================================================
-- Lógica de stamina (Survivors)
-- =============================================================================

local function tickStamina(dt: number)
	if _depleted then
		if _stamina >= _maxStamina * GameConstants.Stamina.LOW_THRESHOLD then
			_depleted = false
			RemoteRegistry.SetSprintState:FireServer(false)
		end
	end

	if _isSprinting and not _depleted then
		_stamina = math.max(0, _stamina - GameConstants.Stamina.DRAIN_RATE * dt)
		if _stamina <= 0 then
			_depleted    = true
			_isSprinting = false
			RemoteRegistry.SetSprintState:FireServer(false)
		end
	else
		_stamina = math.min(_maxStamina, _stamina + GameConstants.Stamina.REGEN_RATE * dt)
	end

	updateStaminaVisual()
end

-- =============================================================================
-- Rage API pública
-- =============================================================================

function StaminaController.addRage(amount: number)
	if amount <= RAGE_RESET_SENTINEL then
		StaminaController.resetRage()
		return
	end

	_rage = math.clamp(_rage + amount, 0, _rageMax)
	updateRageVisual()
end

function StaminaController.resetRage()
	_rage = 0
	updateRageVisual()
	print("🔥 [StaminaController] Rage reseteado a 0.")
end

function StaminaController.getRage(): number
	return _rage
end

-- =============================================================================
-- Sprint público
-- =============================================================================

function StaminaController.setSprint(active: boolean)
	if isLocalKiller() then return end
	if _depleted and active then return end

	_isSprinting = active
	RemoteRegistry.SetSprintState:FireServer(active)
end

-- =============================================================================
-- Start
-- =============================================================================

function StaminaController.Start()
	print("⚡ [StaminaController] Iniciado.")

	RemoteRegistry.SetupCharacter.OnClientEvent:Connect(function()
		local player = Players.LocalPlayer
		local char = player.Character or player.CharacterAdded:Wait()

		local isPoro     = isLocalPoro()
		local isKiller_  = isLocalKiller()

		buildUI(not isKiller_, isPoro)

		_stamina     = _maxStamina
		_rage        = 0
		_depleted    = false
		_isSprinting = false
	end)

	ClientEventBus.RageUpdated:Connect(function(amount: number)
		StaminaController.addRage(amount)
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		local player = Players.LocalPlayer
		local char = player.Character
		if not char then return end

		if char:FindFirstChild("SurvivorID") then
			tickStamina(dt)
		end
	end)

	ClientEventBus.MatchStateChanged:Connect(function(state)
		local GameState = require(ReplicatedStorage.Enums.GameState)
		if state == GameState.ENDING or state == GameState.LOBBY or state == GameState.WAITING then
			destroyUI()
		end
	end)
end

return StaminaController