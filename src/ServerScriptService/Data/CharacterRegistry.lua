-- =============================================================================
-- CharacterRegistry.lua
-- Ubicación: src/server/data/CharacterRegistry.lua
--
-- Registro central de todos los personajes del juego.
-- Reemplaza el módulo "CharacterData" monolítico (~600 líneas).
--
-- Patrón: Registry + Factory
-- Principio SOLID:
--   - Single Responsibility: solo almacena y provee configs.
--   - Open/Closed: agregar personaje = agregar un archivo en CharacterConfigs/
--     SIN modificar este registro.
-- =============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScript      = game:GetService("ServerScriptService")

local CharacterModel = require(ReplicatedStorage.Models.CharacterModel)

-- ---------------------------------------------------------------------------
-- Configuraciones de Supervivientes (importadas de archivos individuales)
-- Cada archivo retorna una SurvivorCharacter validada.
-- ---------------------------------------------------------------------------
local SurvivorConfigs = ServerScript.Data.CharacterConfigs

local SURVIVORS = {
	GONZACARBON  = require(SurvivorConfigs.GONZACARBON),
	SIU          = require(SurvivorConfigs.SIU),
	NARIZTOTELES = require(SurvivorConfigs.NARIZTOTELES),
	SURI         = require(SurvivorConfigs.SURI),
	VACUMING     = require(SurvivorConfigs.VACUMING),
	RICALY       = require(SurvivorConfigs.RICALY),
	CACHETES     = require(SurvivorConfigs.CACHETES),
}

local KILLERS = {
	PORO    = require(SurvivorConfigs.PORO),
	DANTE   = require(SurvivorConfigs.DANTE),
	JALY    = require(SurvivorConfigs.JALY),
	AUGUSTO = require(SurvivorConfigs.AUGUSTO),
	MIGUEL  = require(SurvivorConfigs.MIGUEL),
	EMANUEL = require(SurvivorConfigs.EMANUEL),
}

-- Alias de compatibilidad hacia atrás
SURVIVORS.ISMAIL = SURVIVORS.SIU

-- ---------------------------------------------------------------------------
-- Listas de desbloqueados por defecto (podrían venir de PlayerDataService)
-- ---------------------------------------------------------------------------
local DEFAULT_UNLOCKED_SURVIVORS = {
	"GONZACARBON", "SIU", "NARIZTOTELES", "SURI", "VACUMING", "RICALY", "CACHETES"
}
local DEFAULT_UNLOCKED_KILLERS = {
	"PORO", "DANTE", "JALY", "AUGUSTO", "MIGUEL", "EMANUEL"
}

-- =============================================================================
-- API Pública
-- =============================================================================
local CharacterRegistry = {}

--- Retorna la config de un superviviente. Nil si no existe.
function CharacterRegistry.getSurvivor(id: string): CharacterModel.SurvivorCharacter?
	return SURVIVORS[id]
end

--- Retorna la config de un killer. Nil si no existe.
function CharacterRegistry.getKiller(id: string): CharacterModel.KillerCharacter?
	return KILLERS[id]
end

--- Verifica si un ID de superviviente es válido.
function CharacterRegistry.isSurvivor(id: string): boolean
	return SURVIVORS[id] ~= nil
end

--- Verifica si un ID de killer es válido.
function CharacterRegistry.isKiller(id: string): boolean
	return KILLERS[id] ~= nil
end

--- Retorna todos los IDs de supervivientes desbloqueados por defecto.
function CharacterRegistry.getDefaultSurvivorIds(): {string}
	return table.clone(DEFAULT_UNLOCKED_SURVIVORS)
end

--- Retorna todos los IDs de killers desbloqueados por defecto.
function CharacterRegistry.getDefaultKillerIds(): {string}
	return table.clone(DEFAULT_UNLOCKED_KILLERS)
end

--- Retorna la config de un personaje según rol y ID.
--- Conveniente para código que recibe el rol dinámicamente.
function CharacterRegistry.get(role: string, id: string): (CharacterModel.SurvivorCharacter | CharacterModel.KillerCharacter)?
	if role == "Survivor" then
		return CharacterRegistry.getSurvivor(id)
	elseif role == "Killer" then
		return CharacterRegistry.getKiller(id)
	end
	return nil
end

--- Retorna la tabla completa de supervivientes (lectura only).
function CharacterRegistry.getAllSurvivors(): {[string]: CharacterModel.SurvivorCharacter}
	return SURVIVORS
end

--- Retorna la tabla completa de killers (lectura only).
function CharacterRegistry.getAllKillers(): {[string]: CharacterModel.KillerCharacter}
	return KILLERS
end

return CharacterRegistry