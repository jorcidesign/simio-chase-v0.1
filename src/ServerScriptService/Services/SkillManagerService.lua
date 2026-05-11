-- =============================================================================
-- SkillManagerService.lua
-- Ubicación: src/server/services/SkillManagerService.lua
--
-- Servicio que valida y ejecuta todas las habilidades del juego.
-- Reemplaza el bloque if/elseif de 900+ líneas en GameManager.lua.
--
-- Patrón: Service + Registry (handler map) + Chain of Responsibility (validators)
-- Principio SOLID:
--   - Open/Closed: agregar habilidad = registrar handler, NO modificar este servicio.
--   - Single Responsibility: solo se encarga de routing y validación de skills.
--   - Dependency Inversion: depende de abstracciones (RemoteRegistry, EventBus).
-- =============================================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteRegistry     = require(ReplicatedStorage.Network.RemoteRegistry)
local ServerEventBus     = require(ServerScriptService.Network.ServerEventBus)
local GameConstants      = require(ReplicatedStorage.GameConstants)
local ValidationUtils    = require(ReplicatedStorage.Utils.ValidationUtils)
local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local StatusEffectType   = require(ReplicatedStorage.Enums.StatusEffectType)

-- Importación lazy para evitar ciclos
local CharacterRegistry

local function getRegistry()
	if not CharacterRegistry then
		CharacterRegistry = require(ServerScriptService.Data.CharacterRegistry)
	end
	return CharacterRegistry
end

-- =============================================================================
-- Estado interno del servicio (Singleton)
-- =============================================================================

-- { [playerName] = { [skillServerName] = lastUsedTime } }
local cooldownTracker: {[string]: {[string]: number}} = {}

-- Registro de handlers: { [customHandlerId] = handlerFunction }
-- Patrón Registry: los handlers se registran en Start(), no están hardcodeados.
local skillHandlers: {[string]: (ctx: SkillContext) -> ()} = {}

-- Tipo del contexto pasado a cada handler
export type SkillContext = {
	player    : Player,
	char      : Model,
	root      : BasePart,
	hum       : Humanoid,
	skillDef  : table,   -- La AbilityDefinition / SkillDefinition del personaje
	targetPos : Vector3?,
	characterId: string,
}

-- =============================================================================
-- Servicio principal
-- =============================================================================
local SkillManagerService = {}

-- ---------------------------------------------------------------------------
-- Helpers privados
-- ---------------------------------------------------------------------------

local function getOrCreateCooldowns(player: Player): {[string]: number}
	local name = player.Name
	if not cooldownTracker[name] then
		cooldownTracker[name] = {}
	end
	return cooldownTracker[name]
end

local function findSkillDef(charConfig: table, serverName: string): table?
	local skills = charConfig.Skills or charConfig.Abilities
	if not skills then return nil end
	for _, skill in ipairs(skills) do
		if skill.ServerName == serverName then
			return skill
		end
	end
	return nil
end

local function validateCast(player: Player, char: Model, skillDef: table, cooldowns: {[string]: number}): (boolean, string)
	-- Verificar stun
	if not ValidationUtils.isNotStunned(char) then
		return false, "stunned"
	end

	-- Verificar que el personaje esté vivo
	if not ValidationUtils.isCharacterAlive(player) then
		return false, "dead"
	end

	-- Verificar AbilitiesDisabled (invisibilidad de Augusto, etc.)
	if char:FindFirstChild("AbilitiesDisabled") then
		return false, "abilities_disabled"
	end

	-- Verificar cooldown
	local lastUsed = cooldowns[skillDef.ServerName] or 0
	local cooldown  = skillDef.Cooldown or 0

	-- One-time-use: buscar si ya fue usado
	if skillDef.OneTimeUse then
		local usedTag = char:FindFirstChild(skillDef.ServerName .. "_Used")
		if usedTag then
			return false, "one_time_used"
		end
	elseif cooldown > 0 and not ValidationUtils.isCooldownReady(lastUsed, cooldown) then
		return false, "on_cooldown"
	end

	return true, ""
end

-- ---------------------------------------------------------------------------
-- Ejecución pública
-- ---------------------------------------------------------------------------

--- Intenta ejecutar una habilidad de killer o superviviente.
--- Llamado desde el OnServerEvent de UseKillerAbility / UseSurvivorAbility.
---
--- @param player      Player    Jugador que emitió el evento.
--- @param serverName  string    Nombre del servidor de la habilidad.
--- @param targetPos   Vector3?  Posición objetivo (si aplica).
--- @param role        string    "Killer" | "Survivor"
function SkillManagerService.cast(player: Player, serverName: string, targetPos: any, role: string)
	-- 1. Sanear inputs
	if not ValidationUtils.isValidString(serverName) then
		warn("[SkillManager] serverName inválido de " .. player.Name)
		return
	end

	local safeTarget: Vector3? = nil
	if typeof(targetPos) == "Vector3" and ValidationUtils.isValidPosition(targetPos) then
		safeTarget = targetPos
	end

	-- 2. Obtener personaje
	local char = player.Character
	if not char then return end

	local root = char:FindFirstChild("HumanoidRootPart")
	local hum  = char:FindFirstChild("Humanoid")
	if not root or not hum then return end

	-- 3. Obtener config del personaje
	local reg        = getRegistry()
	local tagName    = (role == "Killer") and "KillerID" or "SurvivorID"
	local charTag    = char:FindFirstChild(tagName)
	if not charTag then
		warn("[SkillManager] " .. player.Name .. " no tiene tag de " .. role)
		return
	end

	local characterId  = charTag.Value
	local charConfig   = (role == "Killer") and reg.getKiller(characterId) or reg.getSurvivor(characterId)
	if not charConfig then
		warn("[SkillManager] Config no encontrada para " .. characterId)
		return
	end

	-- 4. Encontrar la definición de la habilidad
	local skillDef = findSkillDef(charConfig, serverName)
	if not skillDef then
		warn("[SkillManager] Habilidad '" .. serverName .. "' no encontrada en " .. characterId)
		return
	end

	-- 5. Validar que se puede castear
	local cooldowns = getOrCreateCooldowns(player)
	local canCast, reason = validateCast(player, char, skillDef, cooldowns)
	if not canCast then
		ServerEventBus.SkillRejected:Fire(player, serverName, reason)
		return
	end

	-- 6. Registrar uso (cooldown)
	if not skillDef.OneTimeUse then
		cooldowns[skillDef.ServerName] = os.clock()
	else
		-- Marcar como usado (one-time-use)
		local usedTag = Instance.new("BoolValue", char)
		usedTag.Name  = skillDef.ServerName .. "_Used"
	end

	-- 7. Construir contexto y ejecutar handler
	local ctx: SkillContext = {
		player      = player,
		char        = char,
		root        = root,
		hum         = hum,
		skillDef    = skillDef,
		targetPos   = safeTarget,
		characterId = characterId,
	}

	local handlerId = skillDef.customHandlerId or serverName
	local handler   = skillHandlers[handlerId]

	if handler then
		local ok, err = pcall(handler, ctx)
		if not ok then
			warn("[SkillManager] Error ejecutando handler '" .. handlerId .. "': " .. tostring(err))
		end
	else
		warn("[SkillManager] No hay handler registrado para '" .. handlerId .. "'")
	end

	-- 8. Emitir evento al bus (para stats, voz, etc.)
	ServerEventBus.SkillCasted:Fire(player, serverName)
end

-- =============================================================================
-- API de registro de handlers (patrón Registry / Open-Closed)
-- =============================================================================

--- Registra un handler para una habilidad específica.
--- Los handlers se registran en los archivos de SkillHandlers/ al iniciar.
---
--- @param handlerId  string                   ID único del handler (customHandlerId del config).
--- @param handler    (ctx: SkillContext) -> () Función que ejecuta la lógica de la habilidad.
function SkillManagerService.registerHandler(handlerId: string, handler: (ctx: SkillContext) -> ())
	assert(type(handlerId) == "string" and #handlerId > 0, "[SkillManager] handlerId inválido")
	assert(type(handler) == "function", "[SkillManager] handler debe ser función")

	if skillHandlers[handlerId] then
		warn("[SkillManager] Handler '" .. handlerId .. "' sobreescrito. ¿Registro duplicado?")
	end

	skillHandlers[handlerId] = handler
end

--- Limpia los cooldowns de un jugador (llamado al reiniciar partida).
function SkillManagerService.resetCooldowns(player: Player)
	cooldownTracker[player.Name] = {}
end

-- =============================================================================
-- Inicialización del servicio
-- =============================================================================

function SkillManagerService.Start()
	-- Conectar RemoteEvents
	RemoteRegistry.UseKillerAbility.OnServerEvent:Connect(function(player, serverName, targetPos)
		SkillManagerService.cast(player, serverName, targetPos, "Killer")
	end)

	RemoteRegistry.UseSurvivorAbility.OnServerEvent:Connect(function(player, serverName, targetPos)
		SkillManagerService.cast(player, serverName, targetPos, "Survivor")
	end)

	-- Limpiar cooldowns cuando el jugador se vaya
	Players.PlayerRemoving:Connect(function(player)
		cooldownTracker[player.Name] = nil
	end)

	-- Cargar todos los handlers registrados
	-- Los handlers se importan aquí para mantener SkillManagerService limpio
	local handlersFolder = ServerScriptService:FindFirstChild("SkillHandlers")
	if handlersFolder then
		for _, module in ipairs(handlersFolder:GetChildren()) do
			if module:IsA("ModuleScript") then
				local ok, err = pcall(function()
					require(module)(SkillManagerService.registerHandler)
				end)
				if not ok then
					warn("[SkillManager] Error cargando handler module '" .. module.Name .. "': " .. tostring(err))
				end
			end
		end
	end

	print("[SkillManagerService] ✅ Iniciado con " .. #(function()
		local t = {}
		for k in pairs(skillHandlers) do table.insert(t, k) end
		return t
	end)() .. " handlers registrados")
end

return SkillManagerService