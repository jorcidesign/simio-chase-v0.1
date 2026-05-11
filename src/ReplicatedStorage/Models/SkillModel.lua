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

-- ---------------------------------------------------------------------------
-- Tipos de efectos que puede producir una habilidad
-- ---------------------------------------------------------------------------
export type EffectType =
	"Dash"        |  -- Impulso de movimiento
	"Damage"      |  -- Daño directo
	"Heal"        |  -- Curación
	"Stun"        |  -- Aturdimiento
	"Slow"        |  -- Ralentización
	"SpeedBoost"  |  -- Boost de velocidad
	"Teleport"    |  -- Teletransporte
	"Projectile"  |  -- Proyectil que viaja
	"AoE"         |  -- Área de efecto
	"Stealth"     |  -- Invisibilidad / transparencia
	"Blind"       |  -- Cegar pantalla del objetivo
	"Invincible"  |  -- I-Frames
	"Spawn"       |  -- Colocar objeto en mundo
	"Mark"        |  -- Marcar objetivo
	"DoubleJump"  |  -- Habilitar doble salto
	"Custom"         -- Lógica custom referenciada por ID

export type SkillEffect = {
	type        : EffectType,
	value       : number?,        -- daño, curación, velocidad, etc.
	duration    : number?,        -- duración del efecto en segundos
	radius      : number?,        -- radio de AoE
	range       : number?,        -- rango máximo
	targetFilter: string?,        -- "Survivors" | "Killers" | "All" | "Self"
	[string]    : any,            -- parámetros específicos adicionales
}

--- Tipo completo de una definición de habilidad.
export type SkillDefinition = {
	-- Identificadores
	id          : string,          -- ej: "PORO_Q", "GONZACARBON_E"
	characterId : string,          -- "PORO", "GONZACARBON", etc.
	key         : string,          -- "Q" | "E" | "R" | "F"
	name        : string,
	description : string,
	icon        : string,

	-- Timing
	cooldown    : number,
	castTime    : number?,         -- segundos de animación antes de aplicar efecto
	duration    : number?,         -- duración total del skill activo

	-- Costos
	staminaCost : number?,

	-- Si es de un solo uso por partida
	oneTimeUse  : boolean?,

	-- Efectos encadenados que produce
	effects     : {SkillEffect}?,

	-- Validadores: funciones que retornan true si se puede castear
	-- (definidas en el servidor, no aquí para evitar exploits)
	validatorIds: {string}?,

	-- Handler custom (cuando la lógica es demasiado única)
	-- El SkillManagerService buscará un handler registrado con este id
	customHandlerId: string?,
}

-- =============================================================================
-- Factory de SkillDefinition con valores por defecto
-- =============================================================================
local SkillModel = {}

--- Construye una SkillDefinition con defaults y validación de campos requeridos.
function SkillModel.new(data: table): SkillDefinition
	assert(data.id,          "[SkillModel] Requiere 'id'")
	assert(data.characterId, "[SkillModel] Requiere 'characterId'")
	assert(data.key,         "[SkillModel] Requiere 'key'")
	assert(data.name,        "[SkillModel] Requiere 'name'")
	assert(data.cooldown,    "[SkillModel] Requiere 'cooldown'")

	return {
		id              = data.id,
		characterId     = data.characterId,
		key             = data.key,
		name            = data.name,
		description     = data.description     or "",
		icon            = data.icon            or "rbxassetid://4966601445",
		cooldown        = data.cooldown,
		castTime        = data.castTime        or 0,
		duration        = data.duration,
		staminaCost     = data.staminaCost     or 0,
		oneTimeUse      = data.oneTimeUse      or false,
		effects         = data.effects         or {},
		validatorIds    = data.validatorIds    or {},
		customHandlerId = data.customHandlerId,
	}
end

return SkillModel