-- =============================================================================
-- DamageSystem.lua
-- Ubicación: src/server/systems/DamageSystem.lua
--
-- Sistema server-authoritative de cálculo y aplicación de daño.
-- Toda lógica de daño pasa por aquí — NUNCA el cliente calcula daño.
--
-- Principio SOLID: Single Responsibility
-- Patrón: ECS System (sin estado propio, opera sobre entidades externas)
-- =============================================================================

local Players           = game:GetService("Players")
local Debris            = game:GetService("Debris")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConstants    = require(ReplicatedStorage.GameConstants)
local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)
local RemoteRegistry   = require(ReplicatedStorage.Network.RemoteRegistry)
local ServerEventBus   = require(ServerScriptService.Network.ServerEventBus)
local StatusEffectSystem = require(script.Parent.StatusEffectSystem)

-- Importación lazy para evitar ciclos
local CharacterRegistry

local function getCharacterRegistry()
	if not CharacterRegistry then
		CharacterRegistry = require(script.Parent.Parent.data.CharacterRegistry)
	end
	return CharacterRegistry
end

-- =============================================================================
-- Hitbox (extraído de GameManager, ahora encapsulado)
-- =============================================================================

local HitboxSystem = {}
HitboxSystem.__index = HitboxSystem

local C = GameConstants.Combat

function HitboxSystem.new(attacker: Model, size: Vector3?, offset: Vector3?, duration: number?)
	local self = setmetatable({}, HitboxSystem)
	self.attacker    = attacker
	self.root        = attacker:FindFirstChild("HumanoidRootPart")
	self.size        = size     or C.DEFAULT_HITBOX_SIZE
	self.offset      = offset   or C.DEFAULT_HITBOX_OFFSET
	self.duration    = duration or C.HITBOX_DURATION
	self.hitTargets  = {}
	self.active      = true
	self._connection = nil
	return self
end

function HitboxSystem:Start(onHit: (hitData: table) -> ())
	if not self.root then return end

	local startTime = os.clock()
	self._connection = RunService.Heartbeat:Connect(function()
		if not self.active or not self.root or not self.root.Parent then
			self:Destroy()
			return
		end

		if (os.clock() - startTime) >= self.duration then
			self:Destroy()
			return
		end

		local hitCFrame = self.root.CFrame * CFrame.new(
			self.offset.X, self.offset.Y, self.offset.Z
		)

		local params = OverlapParams.new()
		params.FilterDescendantsInstances = { self.attacker }
		params.FilterType = Enum.RaycastFilterType.Exclude

		local parts = workspace:GetPartBoundsInBox(hitCFrame, self.size, params)

		for _, part in ipairs(parts) do
			local char = part.Parent
			local hum  = char:FindFirstChild("Humanoid")
			if hum and hum.Health > 0 and not self.hitTargets[hum] then
				self.hitTargets[hum] = true
				onHit({ Character = char, Humanoid = hum, Part = part })
			end
		end
	end)
end

function HitboxSystem:Destroy()
	self.active = false
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

-- =============================================================================
-- DamageSystem API
-- =============================================================================
local DamageSystem = {}

--- Aplica daño a un personaje con toda la lógica de pasivos y mitigaciones.
---
--- @param victim    Model    Personaje que recibe el daño.
--- @param amount    number   Daño base a aplicar.
--- @param attacker  Model?   Personaje que atacó (para efectos especiales).
--- @return number   Daño final aplicado.
function DamageSystem.applyDamage(victim: Model, amount: number, attacker: Model?): number
	local hum = victim:FindFirstChild("Humanoid")
	if not hum or hum.Health <= 0 then return 0 end

	-- I-Frames: si el objetivo es invulnerable, ignorar
	if StatusEffectSystem.has(victim, StatusEffectType.INVINCIBLE) then
		DamageSystem._showBlockEffect(victim)
		return 0
	end

	-- Calcular mitigaciones del superviviente
	local finalDamage = DamageSystem._calculateMitigation(victim, amount)

	-- Aplicar daño
	hum:TakeDamage(finalDamage)

	-- Efectos especiales del atacante (Ej: Miguel recibe daño al stunear)
	if attacker then
		DamageSystem._handleAttackerSpecials(attacker, finalDamage)
	end

	-- Efectos visuales al dañado
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	if victimPlayer then
		RemoteRegistry.DamageEffect:FireClient(victimPlayer)
	end

	-- Emitir evento al bus
	local attackerPlayer = attacker and Players:GetPlayerFromCharacter(attacker)
	local victimPlayer2  = Players:GetPlayerFromCharacter(victim)
	if victimPlayer2 then
		ServerEventBus.PlayerDamaged:Fire(victimPlayer2, attackerPlayer, finalDamage, "M1")
	end

	return finalDamage
end

--- Ejecuta un hitbox de M1 para un killer, aplicando daño a supervivientes en rango.
---
--- @param killer        Model   Personaje killer.
--- @param killerPlayer  Player  Jugador killer.
function DamageSystem.executeM1(killer: Model, killerPlayer: Player)
	local reg = getCharacterRegistry()
	local killerTag = killer:FindFirstChild("KillerID")
	if not killerTag then return end

	local killerConfig = reg.getKiller(killerTag.Value)
	if not killerConfig then return end

	local damage    = killerConfig.M1Damage
	local root      = killer:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Efecto visual de slash
	DamageSystem._createSlashFX(root)

	-- Sonido
	local sfx = Instance.new("Sound", root)
	sfx.SoundId = "rbxassetid://131237241"
	sfx.Volume  = 0.5
	sfx:Play()
	Debris:AddItem(sfx, 1)

	-- Crear hitbox y procesar hits
	local hitbox = HitboxSystem.new(killer)
	hitbox:Start(function(hitData)
		local victimChar = hitData.Character
		local victimHum  = hitData.Humanoid

		-- Solo dañar supervivientes (no al mismo killer)
		local survivorTag = victimChar:FindFirstChild("SurvivorID")
		if not survivorTag then return end

		-- Verificar counter de Nariztoteles
		if DamageSystem._checkCounter(victimChar, killer, killerPlayer) then
			hitbox:Destroy()
			return
		end

		-- Calcular daño con pasivos del killer
		local adjustedDamage = DamageSystem._applyKillerPassives(killer, killerTag.Value, damage)

		-- Aplicar daño
		local finalDamage = DamageSystem.applyDamage(victimChar, adjustedDamage, killer)

		-- Verificar umbral de ejecución
		if finalDamage > 0 then
			DamageSystem._checkExecutionThreshold(victimChar, victimHum, killer, killerConfig)
		end
	end)
end

-- =============================================================================
-- Privados
-- =============================================================================

function DamageSystem._calculateMitigation(victim: Model, rawDamage: number): number
	local survivorTag = victim:FindFirstChild("SurvivorID")
	if not survivorTag then return rawDamage end

	local reg    = getCharacterRegistry()
	local config = reg.getSurvivor(survivorTag.Value)
	if not config then return rawDamage end

	local reduction = config.Passive and config.Passive.DamageReduction or 0
	return rawDamage * (1 - reduction)
end

function DamageSystem._applyKillerPassives(killer: Model, killerId: string, damage: number): number
	-- JALY: Combo hits aumentan el daño
	if killerId == "JALY" then
		local combo = killer:FindFirstChild("ComboHits")
		if combo then
			damage = damage + (combo.Value * 3)
			combo.Value = math.min(combo.Value + 1, 5)
			task.delay(3, function()
				if combo.Parent then combo.Value = 0 end
			end)
		end
	end
	return damage
end

function DamageSystem._handleAttackerSpecials(attacker: Model, damage: number)
	local killerTag = attacker:FindFirstChild("KillerID")
	if not killerTag then return end

	-- PORO: Ganar rage al golpear
	if killerTag.Value == "PORO" then
		local rage = attacker:FindFirstChild("RageMeter")
		if rage then
			rage.Value = math.min(rage.Value + 25, 100)
		end
	end
end

function DamageSystem._checkCounter(victimChar: Model, killer: Model, killerPlayer: Player): boolean
	if not victimChar:FindFirstChild("CounterActive") then return false end
	if not victimChar.CounterActive.Value then return false end

	-- Counter de Nariztoteles activado
	victimChar.CounterActive.Value = false
	if victimChar:FindFirstChild("CounterSuccess") then
		victimChar.CounterSuccess.Value = true
	end

	-- Stunear al killer
	StatusEffectSystem.apply(killer, StatusEffectType.STUN, 0, 3)

	-- Empujar al superviviente hacia atrás
	local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")
	if victimRoot then
		victimRoot.CFrame = victimRoot.CFrame + (-victimRoot.CFrame.LookVector * 15)
	end

	-- VFX de counter
	DamageSystem._createCounterFX(victimChar)

	return true
end

function DamageSystem._checkExecutionThreshold(victimChar: Model, victimHum: Humanoid, killer: Model, killerConfig: table)
	local healthPercent = victimHum.Health / victimHum.MaxHealth
	local C = GameConstants.Combat

	if healthPercent <= C.EXECUTE_HP_THRESHOLD and not victimChar:FindFirstChild("BeingExecuted") then
		-- Solo EMANUEL tiene ejecución directa, pero el sistema está abierto
		-- Los handlers de skills se encargan de triggerear esto
		print(string.format("[DamageSystem] %s en umbral de ejecución (%.0f%%)",
			victimChar.Name, healthPercent * 100))
	end
end

function DamageSystem._showBlockEffect(victim: Model)
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local fx = Instance.new("Part", workspace)
	fx.Shape = Enum.PartType.Ball
	fx.Size  = Vector3.new(3, 3, 3)
	fx.Position = root.Position
	fx.Color = Color3.fromRGB(255, 255, 100)
	fx.Material = Enum.Material.Neon
	fx.Transparency = 0
	fx.Anchored = true
	fx.CanCollide = false
	TweenService:Create(fx, TweenInfo.new(0.3), { Size = Vector3.new(6,6,6), Transparency = 1 }):Play()
	Debris:AddItem(fx, 0.3)
end

function DamageSystem._createSlashFX(root: BasePart)
	local slash = Instance.new("Part", workspace)
	slash.Size  = Vector3.new(0.3, 5, 5)
	slash.CFrame = root.CFrame * CFrame.new(0, 0, -3.5)
	slash.Color = Color3.fromRGB(200, 0, 0)
	slash.Material = Enum.Material.Neon
	slash.Transparency = 0.3
	slash.Anchored = true
	slash.CanCollide = false
	TweenService:Create(slash, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(0.1, 7, 7) }):Play()
	Debris:AddItem(slash, 0.3)
end

function DamageSystem._createCounterFX(victimChar: Model)
	local root = victimChar:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local fx = Instance.new("Part", workspace)
	fx.Shape = Enum.PartType.Ball
	fx.Size  = Vector3.new(10, 10, 10)
	fx.Position = root.Position
	fx.Color = Color3.fromRGB(0, 255, 255)
	fx.Material = Enum.Material.Neon
	fx.Transparency = 0
	fx.Anchored = true
	fx.CanCollide = false
	TweenService:Create(fx, TweenInfo.new(0.5), { Transparency = 1, Size = Vector3.new(20, 20, 20) }):Play()
	Debris:AddItem(fx, 0.5)

	local sound = Instance.new("Sound", root)
	sound.SoundId = "rbxassetid://5273899897"
	sound.Volume  = 1
	sound:Play()
	Debris:AddItem(sound, 2)
end

return DamageSystem