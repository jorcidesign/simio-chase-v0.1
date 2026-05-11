-- =============================================================================
-- ValidationUtils.lua
-- Ubicación: src/shared/utils/ValidationUtils.lua
--
-- Funciones puras de validación. Usadas principalmente en el servidor
-- para sanear todos los datos recibidos por RemoteEvents.
--
-- Principio SOLID: Single Responsibility
-- Sin dependencias externas — completamente portátil.
-- =============================================================================

local ValidationUtils = {}

-- Tolerancia de cooldown: ms que se permiten de diferencia entre cliente y servidor
local COOLDOWN_TOLERANCE_MS = 100

--- Verifica si un valor es una string no vacía.
function ValidationUtils.isValidString(value: any): boolean
	return type(value) == "string" and #value > 0
end

--- Verifica si un Vector3 tiene componentes finitas y dentro de los límites del mapa.
--- @param mapRadius  Radio máximo permitido desde el origen (por defecto 5000 studs)
function ValidationUtils.isValidPosition(pos: any, mapRadius: number?): boolean
	if typeof(pos) ~= "Vector3" then return false end
	local r = mapRadius or 5000
	if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then return false end -- NaN check
	return math.abs(pos.X) <= r and math.abs(pos.Y) <= 1000 and math.abs(pos.Z) <= r
end

--- Verifica que un characterId sea conocido en un diccionario de configs.
function ValidationUtils.isValidCharacterId(id: any, registry: table): boolean
	return ValidationUtils.isValidString(id) and registry[id] ~= nil
end

--- Verifica que un jugador tenga suficiente estamina para una acción.
function ValidationUtils.hasEnoughStamina(current: number, cost: number): boolean
	return current >= cost
end

--- Verifica que un cooldown haya expirado (con tolerancia de red).
--- @param lastUsed   os.clock() cuando se usó la habilidad por última vez
--- @param cooldown   cooldown en segundos definido en el config
function ValidationUtils.isCooldownReady(lastUsed: number, cooldown: number): boolean
	local elapsed    = os.clock() - lastUsed
	local tolerance  = COOLDOWN_TOLERANCE_MS / 1000
	return elapsed >= (cooldown - tolerance)
end

--- Verifica que un player tenga su personaje vivo en el servidor.
function ValidationUtils.isCharacterAlive(player: Player): boolean
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChild("Humanoid")
	return hum ~= nil and hum.Health > 0
end

--- Verifica que dos posiciones estén dentro de un rango máximo.
--- Útil para evitar teleports de trampa donde el cliente manda una posición lejana.
function ValidationUtils.isInRange(origin: Vector3, target: Vector3, maxRange: number): boolean
	return (target - origin).Magnitude <= maxRange * 1.15  -- 15% de tolerancia de lag
end

--- Verifica que un tag (StringValue / BoolValue) exista en un personaje.
function ValidationUtils.characterHasTag(char: Model, tagName: string): boolean
	return char:FindFirstChild(tagName) ~= nil
end

--- Verifica que un player no esté stunned.
function ValidationUtils.isNotStunned(char: Model): boolean
	return char:FindFirstChild("IsStunned") == nil
end

return ValidationUtils