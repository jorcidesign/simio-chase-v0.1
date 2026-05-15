-- =============================================================================
-- MathUtils.lua
-- Ubicación: src/ReplicatedStorage/Utils/MathUtils.lua
--
-- Funciones matemáticas puras compartidas entre cliente y servidor.
-- Sin dependencias externas — completamente portátil.
--
-- Principio SOLID: Single Responsibility
-- =============================================================================

local MathUtils = {}

-- =============================================================================
-- Interpolación
-- =============================================================================

--- Interpolación lineal básica.
--- @param a       number  Valor inicial.
--- @param b       number  Valor final.
--- @param alpha   number  Factor [0, 1].
--- @return number
function MathUtils.lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * math.clamp(alpha, 0, 1)
end

--- Interpolación lineal de Vector3.
--- @param a     Vector3
--- @param b     Vector3
--- @param alpha number   Factor [0, 1].
--- @return Vector3
function MathUtils.lerpV3(a: Vector3, b: Vector3, alpha: number): Vector3
	local t = math.clamp(alpha, 0, 1)
	return Vector3.new(
		a.X + (b.X - a.X) * t,
		a.Y + (b.Y - a.Y) * t,
		a.Z + (b.Z - a.Z) * t
	)
end

--- Spring interpolation suave (aproximación exponencial).
--- Útil para cámaras y UIs que necesitan "masa" sin oscilar.
--- @param current  number  Valor actual.
--- @param target   number  Valor objetivo.
--- @param speed    number  Velocidad del resorte (mayor = más rápido).
--- @param dt       number  Delta time del frame.
--- @return number
function MathUtils.spring(current: number, target: number, speed: number, dt: number): number
	return MathUtils.lerp(current, target, 1 - math.exp(-speed * dt))
end

-- =============================================================================
-- Ángulos y direcciones
-- =============================================================================

--- Convierte radianes a grados.
function MathUtils.toDeg(rad: number): number
	return rad * (180 / math.pi)
end

--- Convierte grados a radianes.
function MathUtils.toRad(deg: number): number
	return deg * (math.pi / 180)
end

--- Retorna el ángulo en grados (0–360) entre dos Vector3 en el plano XZ.
--- Útil para determinar si el killer está en el cono de visión de un survivor.
--- @param from  Vector3  Posición origen.
--- @param to    Vector3  Posición destino.
--- @return number  Ángulo en grados [0, 360).
function MathUtils.horizontalAngleDeg(from: Vector3, to: Vector3): number
	local dir = (to - from) * Vector3.new(1, 0, 1)   -- ignorar Y
	if dir.Magnitude < 0.001 then return 0 end
	local rad = math.atan2(dir.Z, dir.X)
	local deg = MathUtils.toDeg(rad)
	return (deg + 360) % 360
end

--- Retorna true si `target` está dentro del cono de visión de `observer`.
--- @param observerLookV  Vector3  LookVector del observador (normalizado).
--- @param observerPos    Vector3  Posición del observador.
--- @param targetPos      Vector3  Posición del objetivo.
--- @param halfAngleDeg   number   Semángulo del cono en grados (ej. 60 = cono de 120°).
--- @return boolean
function MathUtils.isInFOV(
	observerLookV : Vector3,
	observerPos   : Vector3,
	targetPos     : Vector3,
	halfAngleDeg  : number
): boolean
	local toTarget = (targetPos - observerPos)
	if toTarget.Magnitude < 0.001 then return true end
	local toTargetNorm = toTarget.Unit
	local dot = observerLookV:Dot(toTargetNorm)
	local angleRad = math.acos(math.clamp(dot, -1, 1))
	return MathUtils.toDeg(angleRad) <= halfAngleDeg
end

-- =============================================================================
-- Distancias y geometría
-- =============================================================================

--- Distancia en el plano XZ (ignorando la altura Y).
--- Útil para rangos de habilidades y detección de chase.
--- @param a Vector3
--- @param b Vector3
--- @return number
function MathUtils.distanceXZ(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

--- Clamp con wrap (modulo normalizado). Útil para índices de listas cíclicas.
--- @param value    number
--- @param minVal   number
--- @param maxVal   number
--- @return number
function MathUtils.wrapClamp(value: number, minVal: number, maxVal: number): number
	local range = maxVal - minVal + 1
	return ((value - minVal) % range + range) % range + minVal
end

--- Redondea a N decimales.
--- @param n        number
--- @param decimals number
--- @return number
function MathUtils.round(n: number, decimals: number?): number
	local factor = 10 ^ (decimals or 0)
	return math.floor(n * factor + 0.5) / factor
end

-- =============================================================================
-- Aleatorio
-- =============================================================================

--- Elige un elemento aleatorio de una lista.
--- @param list {any}
--- @return any
function MathUtils.randomPick(list: { any }): any
	if #list == 0 then return nil end
	return list[math.random(1, #list)]
end

--- Baraja una lista in-place (Fisher-Yates).
--- @param list {any}
--- @return {any}  La misma lista barajada (in-place + retorno por conveniencia).
function MathUtils.shuffle(list: { any }): { any }
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- =============================================================================
-- Tiempo
-- =============================================================================

--- Formatea segundos como "MM:SS". Igual que el helper en GameHUDController
--- pero disponible en cualquier contexto (incluyendo servidor).
--- @param seconds number
--- @return string
function MathUtils.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%02d:%02d", m, s)
end

return MathUtils