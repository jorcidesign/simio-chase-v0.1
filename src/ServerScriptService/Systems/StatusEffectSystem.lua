-- =============================================================================
-- StatusEffectSystem.lua
-- Ubicación: src/server/systems/StatusEffectSystem.lua
--
-- Sistema UNIFICADO de efectos de estado. Reemplaza la lógica dispersa de
-- stun, slow, i-frames y speed boost que existía en GameManager.lua.
--
-- Patrón: ECS System (procesa componentes de efecto en entidades-Model)
-- Principio SOLID:
--   - Single Responsibility: solo gestiona efectos de estado.
--   - Open/Closed: agregar un efecto nuevo = agregar un entry en HANDLERS.
-- =============================================================================

local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")
local Players      = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)
local GameConstants    = require(ReplicatedStorage.GameConstants)
local RemoteRegistry   = require(ReplicatedStorage.Network.RemoteRegistry)
local ServerEventBus   = require(ServerScriptService.Network.ServerEventBus)

-- ---------------------------------------------------------------------------
-- Estado interno: efectos activos por personaje
-- { [Model] = { [StatusEffectType] = { level, endTime, cleanup } } }
-- ---------------------------------------------------------------------------
local activeEffects: {[Model]: {[string]: {level: number, endTime: number, cleanup: (() -> ())?}}} = {}

-- ---------------------------------------------------------------------------
-- Helpers internos
-- ---------------------------------------------------------------------------

local function getBaseSpeed(char: Model): number
	local killerTag   = char:FindFirstChild("KillerID")
	local survivorTag = char:FindFirstChild("SurvivorID")

	if killerTag then
		-- Importar dinámicamente para evitar ciclos
		local CharacterRegistry = require(script.Parent.Parent.data.CharacterRegistry)
		local config = CharacterRegistry.getKiller(killerTag.Value)
		return config and config.BaseSpeed or 20
	elseif survivorTag then
		local CharacterRegistry = require(script.Parent.Parent.data.CharacterRegistry)
		local config = CharacterRegistry.getSurvivor(survivorTag.Value)
		return config and config.WalkSpeed or GameConstants.Movement.DEFAULT_WALK_SPEED
	end

	return GameConstants.Movement.DEFAULT_WALK_SPEED
end

local function ensureEntry(char: Model)
	if not activeEffects[char] then
		activeEffects[char] = {}

		-- Auto-limpiar cuando el personaje es destruido
		char.AncestryChanged:Connect(function()
			if not char.Parent then
				activeEffects[char] = nil
			end
		end)

		local hum = char:FindFirstChild("Humanoid")
		if hum then
			hum.Died:Once(function()
				-- Limpiar efectos al morir
				if activeEffects[char] then
					for _, effectData in pairs(activeEffects[char]) do
						if effectData.cleanup then effectData.cleanup() end
					end
				end
				activeEffects[char] = nil
			end)
		end
	end
end

local function recalculateMovement(char: Model)
	local hum = char:FindFirstChild("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local effects = activeEffects[char]
	if not effects then
		hum.WalkSpeed = getBaseSpeed(char)
		hum.JumpPower = GameConstants.Movement.DEFAULT_JUMP_POWER
		return
	end

	local baseSpeed = getBaseSpeed(char)

	-- Prioridad: STUN > SLOW > SPEED_BOOST > normal
	if effects[StatusEffectType.STUN] then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then root.Anchored = true end
		return
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = false end
	hum.JumpPower = GameConstants.Movement.DEFAULT_JUMP_POWER

	if effects[StatusEffectType.SLOW] then
		hum.WalkSpeed = effects[StatusEffectType.SLOW].level
		return
	end

	if effects[StatusEffectType.SPEED_BOOST] then
		hum.WalkSpeed = baseSpeed * effects[StatusEffectType.SPEED_BOOST].level
		return
	end

	hum.WalkSpeed = baseSpeed
end

-- =============================================================================
-- API Pública
-- =============================================================================
local StatusEffectSystem = {}

--- Aplica un efecto de estado a un personaje.
--- Si el efecto ya existe, actualiza nivel y duración según reglas de prioridad.
---
--- @param char      Model        Personaje objetivo.
--- @param effectType string      Una constante de StatusEffectType.
--- @param level     number       Valor del efecto (velocidad, transparencia, etc.)
--- @param duration  number       Duración en segundos.
--- @param source    Player?      Quién aplicó el efecto (para stats y eventos).
function StatusEffectSystem.apply(char: Model, effectType: string, level: number, duration: number, source: Player?)
	local hum = char:FindFirstChild("Humanoid")
	if not hum or hum.Health <= 0 then return end

	ensureEntry(char)

	local effects  = activeEffects[char]
	local current  = effects[effectType]
	local endTime  = os.clock() + duration

	-- Si ya existe un efecto del mismo tipo, solo actualizar si el nuevo es
	-- más fuerte o dura más (evita que una poción débil cancele una fuerte)
	if current then
		local isStronger = level >= current.level
		local lastsLonger = endTime > current.endTime
		if not isStronger and not lastsLonger then return end
		if current.cleanup then current.cleanup() end
	end

	-- Crear el registro del efecto
	local effectRecord = {
		level   = level,
		endTime = endTime,
		cleanup = nil :: (() -> ())?,
	}
	effects[effectType] = effectRecord

	-- ---------------------------------------------------------------------------
	-- Efectos visuales específicos por tipo
	-- ---------------------------------------------------------------------------
	if effectType == StatusEffectType.STUN then
		StatusEffectSystem._applyStunVFX(char, duration, effectRecord)

	elseif effectType == StatusEffectType.INVINCIBLE then
		StatusEffectSystem._applyIFrameVFX(char, duration, effectRecord)

	elseif effectType == StatusEffectType.INVISIBLE then
		StatusEffectSystem._applyInvisVFX(char, level, duration, effectRecord)

	elseif effectType == StatusEffectType.BLIND then
		local player = Players:GetPlayerFromCharacter(char)
		if player then
			RemoteRegistry.BlindKiller:FireClient(player, duration)
		end
	end

	-- Notificar al bus
	ServerEventBus.StatusEffectApplied:Fire(char, effectType, duration)

	-- Recalcular stats de movimiento inmediatamente
	recalculateMovement(char)

	-- Programar limpieza automática
	task.delay(duration, function()
		if not activeEffects[char] then return end
		if activeEffects[char][effectType] ~= effectRecord then return end -- fue sobreescrito

		if effectRecord.cleanup then effectRecord.cleanup() end
		activeEffects[char][effectType] = nil
		recalculateMovement(char)

		ServerEventBus.StatusEffectExpired:Fire(char, effectType)
	end)
end

--- Elimina un efecto de estado inmediatamente.
function StatusEffectSystem.remove(char: Model, effectType: string)
	if not activeEffects[char] then return end
	local record = activeEffects[char][effectType]
	if record then
		if record.cleanup then record.cleanup() end
		activeEffects[char][effectType] = nil
		recalculateMovement(char)
	end
end

--- Verifica si un personaje tiene un efecto activo.
function StatusEffectSystem.has(char: Model, effectType: string): boolean
	if not activeEffects[char] then return false end
	return activeEffects[char][effectType] ~= nil
end

--- Limpia TODOS los efectos de un personaje.
function StatusEffectSystem.clearAll(char: Model)
	if not activeEffects[char] then return end
	for _, record in pairs(activeEffects[char]) do
		if record.cleanup then record.cleanup() end
	end
	activeEffects[char] = nil
	recalculateMovement(char)
end

-- =============================================================================
-- Aplicadores de VFX privados
-- =============================================================================

function StatusEffectSystem._applyStunVFX(char: Model, duration: number, record: table)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Billboard "STUNNED!"
	local billboard = Instance.new("BillboardGui", root)
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	local label = Instance.new("TextLabel", billboard)
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "STUNNED!"
	label.TextColor3 = Color3.fromRGB(255, 255, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 30
	label.TextStrokeTransparency = 0

	-- Efecto visual cilíndrico amarillo
	local stunFX = Instance.new("Part", workspace)
	stunFX.Shape = Enum.PartType.Cylinder
	stunFX.Size = Vector3.new(0.5, 7, 7)
	stunFX.Position = root.Position
	stunFX.Orientation = Vector3.new(0, 0, 90)
	stunFX.Color = Color3.fromRGB(255, 255, 100)
	stunFX.Material = Enum.Material.Neon
	stunFX.Transparency = 0.3
	stunFX.Anchored = true
	stunFX.CanCollide = false

	-- Sonido de stun
	local sound = Instance.new("Sound", root)
	sound.SoundId = "rbxassetid://3398620867"
	sound.Volume = 0.8
	sound:Play()
	Debris:AddItem(sound, 2)

	-- Notificar a la UI del jugador stunned
	local player = Players:GetPlayerFromCharacter(char)
	if player then
		RemoteRegistry.StunEffect:FireClient(player, duration)
	end

	record.cleanup = function()
		if billboard.Parent then billboard:Destroy() end
		if stunFX.Parent then stunFX:Destroy() end
		-- Desanclar root después del stun
		local r = char:FindFirstChild("HumanoidRootPart")
		if r then r.Anchored = false end
		local h = char:FindFirstChild("Humanoid")
		if h then h.AutoRotate = true end
	end

	Debris:AddItem(stunFX, duration)
	Debris:AddItem(billboard, duration)
end

function StatusEffectSystem._applyIFrameVFX(char: Model, duration: number, record: table)
	local C = GameConstants.VFX
	local origTransparencies = {}

	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			origTransparencies[part] = part.Transparency
			part.Transparency = math.min(part.Transparency + C.IFRAMES_TRANSPARENCY, 0.9)
		end
	end

	local highlight = Instance.new("Highlight", char)
	highlight.Name = "IFrameHighlight"
	highlight.FillColor = Color3.fromRGB(255, 255, 100)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0.5

	record.cleanup = function()
		if highlight.Parent then highlight:Destroy() end
		for part, origTrans in pairs(origTransparencies) do
			if part.Parent then part.Transparency = origTrans end
		end
	end

	-- Parpadeo
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration and highlight.Parent do
			highlight.Enabled = not highlight.Enabled
			task.wait(0.1)
			elapsed += 0.1
		end
	end)
end

function StatusEffectSystem._applyInvisVFX(char: Model, transparency: number, duration: number, record: table)
	local origTransparencies = {}

	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			origTransparencies[part] = part.Transparency
			TweenService:Create(part, TweenInfo.new(0.5), { Transparency = transparency }):Play()
		end
	end

	record.cleanup = function()
		for part, origTrans in pairs(origTransparencies) do
			if part.Parent then
				TweenService:Create(part, TweenInfo.new(0.5), { Transparency = origTrans }):Play()
			end
		end
	end
end

-- =============================================================================
-- Tick: limpiar efectos expirados (doble seguridad, la principal es task.delay)
-- =============================================================================
task.spawn(function()
	while true do
		local now = os.clock()
		for char, effects in pairs(activeEffects) do
			if not char.Parent then
				activeEffects[char] = nil
				continue
			end
			for effectType, record in pairs(effects) do
				if now >= record.endTime then
					if record.cleanup then record.cleanup() end
					effects[effectType] = nil
					recalculateMovement(char)
					ServerEventBus.StatusEffectExpired:Fire(char, effectType)
				end
			end
		end
		task.wait(0.1)
	end
end)

return StatusEffectSystem