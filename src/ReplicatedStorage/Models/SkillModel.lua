--!strict

-- =============================================================================
-- SkillModel.lua
-- Ubicación: src/shared/models/SkillModel.lua
--
-- Define el contrato de una habilidad ejecutable en el servidor.
-- Desacopla la definición de datos de la lógica de ejecución.
--
-- Patrón: Strategy + Data-Driven Design
-- Principio SOLID: Open/Closed — agregar una habilidad nueva NO requiere
--                  modificar SkillManagerService, solo crear un nuevo config.
-- =============================================================================

local SkillModel = {}

-- ---------------------------------------------------------------------------
-- Tipos de efectos que puede producir una habilidad
-- ---------------------------------------------------------------------------

export type EffectType =
	"Dash"
	| "Damage"
	| "Heal"
	| "Stun"
	| "Slow"
	| "SpeedBoost"
	| "Teleport"
	| "Projectile"
	| "AoE"
	| "Stealth"
	| "Blind"
	| "Invincible"
	| "Spawn"
	| "Mark"
	| "DoubleJump"
	| "Custom"

-- =============================================================================
-- EFFECT TYPES
-- =============================================================================

export type SkillEffect = {
	type: EffectType,

	value: number?,
	duration: number?,
	radius: number?,
	range: number?,

	targetFilter: string?, -- "Survivors" | "Killers" | "All" | "Self"

	[string]: any,
}

-- =============================================================================
-- SKILL DEFINITION
-- =============================================================================

export type SkillDefinition = {
	-- Identificadores
	id: string,
	characterId: string,
	key: string, -- "Q" | "E" | "R" | "F"

	name: string,
	description: string,
	icon: string,

	-- Timing
	cooldown: number,
	castTime: number?,
	duration: number?,

	-- Costos
	staminaCost: number?,

	-- Uso único por partida
	oneTimeUse: boolean?,

	-- Efectos encadenados
	effects: { SkillEffect }?,

	-- Validadores
	validatorIds: { string }?,

	-- Handler custom
	customHandlerId: string?,
}

-- =============================================================================
-- INPUT TYPE
-- =============================================================================

type SkillInput = {
	id: string,
	characterId: string,
	key: string,

	name: string,
	description: string?,
	icon: string?,

	cooldown: number,
	castTime: number?,
	duration: number?,

	staminaCost: number?,

	oneTimeUse: boolean?,

	effects: { SkillEffect }?,

	validatorIds: { string }?,

	customHandlerId: string?,
}

-- =============================================================================
-- FACTORY
-- =============================================================================

--- Construye una SkillDefinition con defaults y validación.
--- @param data SkillInput
--- @return SkillDefinition
function SkillModel.new(data: SkillInput): SkillDefinition
	assert(data.id, "[SkillModel] Requiere 'id'")
	assert(data.characterId, "[SkillModel] Requiere 'characterId'")
	assert(data.key, "[SkillModel] Requiere 'key'")
	assert(data.name, "[SkillModel] Requiere 'name'")
	assert(data.cooldown, "[SkillModel] Requiere 'cooldown'")

	return {
		id = data.id,
		characterId = data.characterId,
		key = data.key,

		name = data.name,
		description = data.description or "",
		icon = data.icon or "rbxassetid://4966601445",

		cooldown = data.cooldown,
		castTime = data.castTime or 0,
		duration = data.duration,

		staminaCost = data.staminaCost or 0,

		oneTimeUse = data.oneTimeUse or false,

		effects = data.effects or {},

		validatorIds = data.validatorIds or {},

		customHandlerId = data.customHandlerId,
	}
end

return SkillModel