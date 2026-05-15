-- =============================================================================
-- SkillHUDController.lua
-- Ubicación: src/StarterPlayer/StarterPlayerScripts/Controllers/SkillHUDController.lua
-- =============================================================================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local ClientEventBus = require(script.Parent.Parent.Network.ClientEventBus)
local GameState      = require(ReplicatedStorage.Enums.GameState)

local SkillHUDController = {}

-- =============================================================================
-- Constantes de diseño
-- =============================================================================

local SLOT_SIZE         = 72
local SLOT_PADDING      = 10
local COLOR_SLOT_BG     = Color3.fromRGB(20, 20, 28)
local COLOR_MASK        = Color3.fromRGB(0, 0, 0)
local MASK_TRANSPARENCY = 0.35
local COLOR_KEY_LABEL   = Color3.fromRGB(255, 255, 255)
local COLOR_COOLDOWN_BORDER = Color3.fromRGB(200, 60, 60)
local COLOR_READY_BORDER    = Color3.fromRGB(80, 200, 120)
local PLACEHOLDER_ICON  = "rbxassetid://4966601445"

local SKILL_KEYS: { string } = { "Q", "E", "R", "F" }

-- =============================================================================
-- Estado interno (Tipado Corregido)
-- =============================================================================

local _screenGui: ScreenGui? = nil

-- Definimos un tipo para las referencias de los slots para evitar errores de Luau
type SlotRefs = {
	mask: Frame,
	border: UIStroke,
	timer: TextLabel
}

local _slotRefs: { [string]: SlotRefs } = {}
local _activeTweens: { [string]: Tween } = {}
local _connections: { RBXScriptConnection } = {}

-- =============================================================================
-- Helpers
-- =============================================================================

local function destroyUI()
	for key, tween in pairs(_activeTweens) do
		if tween then tween:Cancel() end
		_activeTweens[key] = nil
	end

	for _, conn in ipairs(_connections) do
		conn:Disconnect()
	end
	table.clear(_connections)
	table.clear(_slotRefs)

	if _screenGui then
		_screenGui:Destroy()
		_screenGui = nil
	end
end

-- =============================================================================
-- Construcción del HUD
-- =============================================================================

-- Corregido: 'table' reemplazado por { [any]: any } para compatibilidad Luau
local function buildUI(skills: { { [any]: any } })
	destroyUI()

	local player = Players.LocalPlayer
	if not player then return end
	local playerGui = player:WaitForChild("PlayerGui")

	local newGui = Instance.new("ScreenGui")
	newGui.Name = "SkillHUD"
	newGui.IgnoreGuiInset = true
	newGui.ResetOnSpawn = false
	newGui.Parent = playerGui
	_screenGui = newGui

	local totalWidth = (#SKILL_KEYS * SLOT_SIZE) + ((#SKILL_KEYS - 1) * SLOT_PADDING)
	local container = Instance.new("Frame")
	container.Name = "SkillContainer"
	container.Size = UDim2.new(0, totalWidth, 0, SLOT_SIZE + 24)
	container.Position = UDim2.new(0.5, -totalWidth / 2, 1, -(SLOT_SIZE + 24 + 20))
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = _screenGui

	local skillByKey: { [string]: { [any]: any } } = {}
	for _, skillDef in ipairs(skills) do
		if skillDef.Key then
			skillByKey[skillDef.Key] = skillDef
		end
	end

	for i, keyName in ipairs(SKILL_KEYS) do
		local skillDef = skillByKey[keyName]
		local xOffset = (i - 1) * (SLOT_SIZE + SLOT_PADDING)

		local slot = Instance.new("Frame")
		slot.Name = "Slot_" .. keyName
		slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
		slot.Position = UDim2.new(0, xOffset, 0, 0)
		slot.BackgroundColor3 = COLOR_SLOT_BG
		slot.BorderSizePixel = 0
		slot.Parent = container
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = slot

		local border = Instance.new("UIStroke")
		border.Color = COLOR_READY_BORDER
		border.Thickness = 2
		border.Parent = slot

		local iconId = (skillDef and skillDef.Icon and skillDef.Icon ~= "") and skillDef.Icon or PLACEHOLDER_ICON

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(1, -8, 1, -24)
		icon.Position = UDim2.new(0, 4, 0, 4)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = slot

		if not skillDef then
			icon.ImageTransparency = 0.7
			slot.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
			border.Color = Color3.fromRGB(50, 50, 50)
		end

		slot.ClipsDescendants = true

		local mask = Instance.new("Frame")
		mask.Name = "CooldownMask"
		mask.Size = UDim2.new(1, 0, 0, 0)
		mask.Position = UDim2.new(0, 0, 0, 0)
		mask.BackgroundColor3 = COLOR_MASK
		mask.BackgroundTransparency = MASK_TRANSPARENCY
		mask.BorderSizePixel = 0
		mask.ZIndex = 5
		mask.Parent = slot

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Name = "KeyLabel"
		keyLabel.Size = UDim2.new(1, 0, 0, 20)
		keyLabel.Position = UDim2.new(0, 0, 1, -22)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.TextSize = 13
		keyLabel.TextColor3 = COLOR_KEY_LABEL
		keyLabel.Text = "[" .. keyName .. "]"
		keyLabel.ZIndex = 6
		keyLabel.Parent = slot

		local timerLabel = Instance.new("TextLabel")
		timerLabel.Name = "TimerLabel"
		timerLabel.Size = UDim2.new(1, 0, 0, 16)
		timerLabel.Position = UDim2.new(0, 0, 0, 4)
		timerLabel.BackgroundTransparency = 1
		timerLabel.Font = Enum.Font.GothamBold
		timerLabel.TextSize = 14
		timerLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
		timerLabel.Text = ""
		timerLabel.ZIndex = 7
		timerLabel.Parent = slot

		_slotRefs[keyName] = {
			mask = mask,
			border = border,
			timer = timerLabel,
		}
	end
end

-- =============================================================================
-- Animación de cooldown
-- =============================================================================

function SkillHUDController.startCooldownAnimation(keyName: string, cooldown: number)
	local refs = _slotRefs[keyName]
	if not refs then return end
	if cooldown <= 0 then return end

	local mask   = refs.mask
	local border = refs.border
	local timer  = refs.timer

	local prev = _activeTweens[keyName]
	if prev then prev:Cancel() end

	mask.Size = UDim2.new(1, 0, 1, 0)
	border.Color = COLOR_COOLDOWN_BORDER

	local tweenInfo = TweenInfo.new(cooldown, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tween = TweenService:Create(mask, tweenInfo, {
		Size = UDim2.new(1, 0, 0, 0),
	})
	
	_activeTweens[keyName] = tween
	tween:Play()

	task.spawn(function()
		local remaining = math.ceil(cooldown)
		while remaining > 0 do
			if not timer or not timer.Parent then return end
			timer.Text = tostring(remaining) .. "s"
			task.wait(1)
			remaining -= 1
		end

		if timer and timer.Parent then
			timer.Text = ""
			border.Color = COLOR_READY_BORDER
		end
	end)

	tween.Completed:Connect(function()
		_activeTweens[keyName] = nil
		if mask and mask.Parent then
			mask.Size = UDim2.new(1, 0, 0, 0)
		end
	end)
end

function SkillHUDController.onSkillCastedLocally(keyName: string, cooldown: number)
	if cooldown > 0 then
		SkillHUDController.startCooldownAnimation(keyName, cooldown)
	else
		local refs = _slotRefs[keyName]
		if refs then
			refs.border.Color = COLOR_COOLDOWN_BORDER
		end
	end
end

-- =============================================================================
-- Catálogo y Resolución
-- =============================================================================

local CLIENT_SKILL_CATALOG = {
	PORO = {
		Q = { Icon = "rbxassetid://4966601445", Cooldown = 15 },
		E = { Icon = "rbxassetid://4966601445", Cooldown = 22 },
		R = { Icon = "rbxassetid://4966601445", Cooldown = 0 },
		F = { Icon = "rbxassetid://4966601445", Cooldown = 30 },
	},
    -- ... (Dante, Jaly, etc. se mantienen igual)
}

local function resolveSkillsForCharacter(characterId: string): { { [any]: any } }
	local catalog = CLIENT_SKILL_CATALOG[characterId] or {}
	local result = {}

	for _, keyName in ipairs(SKILL_KEYS) do
		local entry = catalog[keyName]
		if entry then
			table.insert(result, {
				Key      = keyName,
				Icon     = entry.Icon,
				Cooldown = entry.Cooldown,
			})
		end
	end
	return result
end

-- =============================================================================
-- Start
-- =============================================================================

function SkillHUDController.Start()
	print("🎛️ [SkillHUDController] Iniciado.")

	RemoteRegistry.SetupCharacter.OnClientEvent:Connect(function()
		local player = Players.LocalPlayer
		if not player then return end
		local char = player.Character or player.CharacterAdded:Wait()

		local killerTag = char:FindFirstChild("KillerID")
		local survivorTag = char:FindFirstChild("SurvivorID")
		local tag = killerTag or survivorTag
		
		local characterId = if tag and tag:IsA("StringValue") then tag.Value else nil

		if not characterId then
			destroyUI()
			return
		end

		local skills = resolveSkillsForCharacter(characterId)
		buildUI(skills)
	end)

	RemoteRegistry.SkillCastConfirmed.OnClientEvent:Connect(function(keyName: string, cooldown: number)
		if type(keyName) ~= "string" or type(cooldown) ~= "number" then return end
		SkillHUDController.startCooldownAnimation(keyName, cooldown)
	end)

	ClientEventBus.MatchStateChanged:Connect(function(newState: string)
		if newState == GameState.ENDING or newState == GameState.WAITING or newState == GameState.LOBBY then
			destroyUI()
		end
	end)
end

return SkillHUDController