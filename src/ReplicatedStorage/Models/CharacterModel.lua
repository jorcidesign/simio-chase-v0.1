-- =============================================================================
-- CharacterModel.lua
-- Ubicación: src/shared/models/CharacterModel.lua
--
-- Data Transfer Object (DTO) que define la estructura de un personaje.
-- Actúa como contrato entre el servidor, cliente y los configs.
--
-- Patrón: DTO (Data Transfer Object)
-- Principio SOLID: Interface Segregation — define exactamente qué necesita
--                  cada consumidor de datos de personaje.
-- =============================================================================

--- @class CharacterModel
--- Tipos Luau para validación estática y autocompletado.

export type AbilityDefinition = {
	Key        : string,   -- "Q" | "E" | "R" | "F"
	Name       : string,
	ServerName : string,   -- Identificador usado en el servidor
	Description: string,
	Icon       : string,   -- rbxassetid://...
	Cooldown   : number,
	Duration   : number?,
	-- Parámetros variables según la habilidad (no tipados estrictamente aquí,
	-- cada SkillDefinition tiene su propio tipo)
	[string]   : any,
}

export type PassiveDefinition = {
	Name       : string,
	Description: string,
	[string]   : any,  -- parámetros específicos del passive
}

export type SurvivorCharacter = {
	Name         : string,
	Description  : string,
	Icon         : string,
	WalkSpeed    : number,
	RunSpeed     : number,
	BaseStamina  : number,
	RegenRate    : number?,
	HealthMultiplier: number?,
	Passive      : PassiveDefinition,
	Abilities    : {AbilityDefinition},
}

export type KillerCharacter = {
	Name        : string,
	Description : string,
	Icon        : string,
	BaseSpeed   : number,
	M1Damage    : number,
	M1Cooldown  : number,
	MaxHealth   : number?,  -- nil = infinito (solo MIGUEL tiene HP)
	HasHealth   : boolean?,
	Passive     : PassiveDefinition,
	Skills      : {AbilityDefinition},
}

-- =============================================================================
-- Factory: Constructores con valores por defecto y validación
-- =============================================================================
local CharacterModel = {}

--- Crea un Survivor con valores por defecto para campos opcionales.
--- @param data table  Datos parciales del superviviente.
--- @return SurvivorCharacter
function CharacterModel.newSurvivor(data: table): SurvivorCharacter
	assert(data.Name,      "[CharacterModel] Survivor requiere 'Name'")
	assert(data.Abilities, "[CharacterModel] Survivor requiere 'Abilities'")

	return {
		Name            = data.Name,
		Description     = data.Description     or "Sin descripción",
		Icon            = data.Icon            or "rbxassetid://4966601445",
		WalkSpeed       = data.WalkSpeed       or 16,
		RunSpeed        = data.RunSpeed        or 24,
		BaseStamina     = data.BaseStamina     or 50,
		RegenRate       = data.RegenRate       or 1.0,
		HealthMultiplier= data.HealthMultiplier or 1.0,
		Passive         = data.Passive         or { Name = "Sin Pasiva", Description = "" },
		Abilities       = data.Abilities,
	}
end

--- Crea un Killer con valores por defecto para campos opcionales.
--- @param data table  Datos parciales del asesino.
--- @return KillerCharacter
function CharacterModel.newKiller(data: table): KillerCharacter
	assert(data.Name,   "[CharacterModel] Killer requiere 'Name'")
	assert(data.Skills, "[CharacterModel] Killer requiere 'Skills'")

	return {
		Name       = data.Name,
		Description= data.Description or "Sin descripción",
		Icon       = data.Icon        or "rbxassetid://4966601445",
		BaseSpeed  = data.BaseSpeed   or 20,
		M1Damage   = data.M1Damage    or 20,
		M1Cooldown = data.M1Cooldown  or 1.0,
		MaxHealth  = data.MaxHealth,
		HasHealth  = data.HasHealth   or false,
		Passive    = data.Passive     or { Name = "Sin Pasiva", Description = "" },
		Skills     = data.Skills,
	}
end

return CharacterModel