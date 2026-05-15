-- =============================================================================
-- SkillManagerService.lua
-- Ubicación: src/ServerScriptService/Services/SkillManagerService.lua
--
-- CAMBIOS vs versión anterior:
--
--   ✅ SkillCastConfirmed como fallback de confirmación
--      Los handlers individuales (PORO_Handler, etc.) pueden marcar
--      ctx._castConfirmed = true si ya llamaron a SkillCastConfirmed.
--      Como fallback, SkillManagerService dispara SkillCastConfirmed justo
--      después del handler usando el cooldown del skillDef.
--      Esto garantiza que cualquier habilidad (incluso las sin handler custom)
--      notifique al HUD del cliente.
--
-- ✅ CORRECCIÓN DE TIPOS LUAU:
--      Se reemplazó la anotación inválida 'table' por '{ [any]: any }'
--      y se utilizó 'SkillContext' donde correspondía.
-- =============================================================================

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteRegistry  = require(ReplicatedStorage.Network.RemoteRegistry)
local ServerEventBus  = require(ServerScriptService.Network.ServerEventBus)
local ValidationUtils = require(ReplicatedStorage.Utils.ValidationUtils)

-- Importación lazy para evitar ciclos
local CharacterRegistry

local function getRegistry()
    if not CharacterRegistry then
        CharacterRegistry = require(ServerScriptService.Data.CharacterRegistry)
    end
    return CharacterRegistry
end

-- =============================================================================
-- Singleton
-- =============================================================================

local SkillManagerService = {}

-- =============================================================================
-- Estado interno
-- =============================================================================

-- { [playerName] = { [skillServerName] = lastUsedTime } }
local _cooldownTracker: {[string]: {[string]: number}} = {}

-- Registro de handlers: { [customHandlerId] = handlerFunction }
local _skillHandlers: {[string]: (ctx: any) -> ()} = {}

-- Tipo del contexto pasado a cada handler
export type SkillContext = {
    player         : Player,
    char           : Model,
    root           : BasePart,
    hum            : Humanoid,
    skillDef       : {[any]: any}, -- Corregido de 'table' a '{[any]: any}'
    targetPos      : Vector3?,
    characterId    : string,
    -- ✅ NUEVO: el handler lo pone en true si ya envió SkillCastConfirmed
    _castConfirmed : boolean?,
}

-- Mapeo: skill.Key → nombre display para SkillCastConfirmed
local KEY_TO_NAME: { [string]: string } = {
    Q = "Q", E = "E", R = "R", F = "F",
}

-- =============================================================================
-- Helpers privados
-- =============================================================================

local function getOrCreateCooldowns(player: Player): {[string]: number}
    local name = player.Name
    if not _cooldownTracker[name] then
        _cooldownTracker[name] = {}
    end
    return _cooldownTracker[name]
end

-- Corregido de 'table' a '{[any]: any}'
local function findSkillDef(charConfig: {[any]: any}, serverName: string): {[any]: any}?
    local skills = charConfig.Skills or charConfig.Abilities
    if not skills then return nil end
    for _, skill in ipairs(skills) do
        if skill.ServerName == serverName then
            return skill
        end
    end
    return nil
end

-- Corregido de 'table' a '{[any]: any}'
local function validateCast(
    player   : Player,
    char     : Model,
    skillDef : {[any]: any},
    cooldowns: {[string]: number}
): (boolean, string)

    if not ValidationUtils.isNotStunned(char) then
        return false, "stunned"
    end
    if not ValidationUtils.isCharacterAlive(player) then
        return false, "dead"
    end
    if char:FindFirstChild("AbilitiesDisabled") then
        return false, "abilities_disabled"
    end

    local lastUsed = cooldowns[skillDef.ServerName] or 0
    local cooldown = skillDef.Cooldown or 0

    if skillDef.OneTimeUse then
        if char:FindFirstChild(skillDef.ServerName .. "_Used") then
            return false, "one_time_used"
        end
    elseif cooldown > 0 and not ValidationUtils.isCooldownReady(lastUsed, cooldown) then
        return false, "on_cooldown"
    end

    return true, ""
end

-- =============================================================================
-- API pública: cast
-- =============================================================================

--- Valida y ejecuta una habilidad para un jugador.
--- Llamado desde los OnServerEvent de UseKillerAbility / UseSurvivorAbility.
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
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    -- 3. Obtener config del personaje
    local reg     = getRegistry()
    local tagName = (role == "Killer") and "KillerID" or "SurvivorID"
    local charTag = char:FindFirstChild(tagName)
    if not charTag then
        warn("[SkillManager] " .. player.Name .. " no tiene tag de " .. role)
        return
    end

    local characterId = charTag.Value
    local charConfig  = (role == "Killer")
        and reg.getKiller(characterId)
        or  reg.getSurvivor(characterId)

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

    -- 6. Registrar uso
    if not skillDef.OneTimeUse then
        cooldowns[skillDef.ServerName] = os.clock()
    else
        local usedTag = Instance.new("BoolValue", char)
        usedTag.Name  = skillDef.ServerName .. "_Used"
    end

    -- 7. Construir contexto y ejecutar handler
    local ctx: SkillContext = {
        player         = player,
        char           = char,
        root           = root,
        hum            = hum,
        skillDef       = skillDef,
        targetPos      = safeTarget,
        characterId    = characterId,
        _castConfirmed = false,
    }

    local handlerId = skillDef.customHandlerId or serverName
    local handler   = _skillHandlers[handlerId]

    if handler then
        local ok, err = pcall(handler, ctx)
        if not ok then
            warn("[SkillManager] Error ejecutando handler '" .. handlerId .. "': " .. tostring(err))
        end
    else
        warn("[SkillManager] No hay handler registrado para '" .. handlerId .. "'")
    end

    -- 8. ✅ Fallback de SkillCastConfirmed:
    --    Si el handler no marcó ctx._castConfirmed = true, el servicio dispara
    --    la confirmación aquí para que el HUD del cliente siempre se actualice.
    if not ctx._castConfirmed then
        local keyName  = skillDef.Key and KEY_TO_NAME[skillDef.Key]
        local cooldown = skillDef.Cooldown or 0
        if keyName then
            RemoteRegistry.SkillCastConfirmed:FireClient(player, keyName, cooldown)
        end
    end

    -- 9. Emitir al bus interno
    ServerEventBus.SkillCasted:Fire(player, serverName)
end

-- =============================================================================
-- API de registro de handlers (patrón Registry / Open-Closed)
-- =============================================================================

--- Registra un handler para una habilidad específica.
-- Corregido el tipo de 'ctx' a 'SkillContext'
function SkillManagerService.registerHandler(handlerId: string, handler: (ctx: SkillContext) -> ())
    assert(type(handlerId) == "string" and #handlerId > 0,
        "[SkillManager] handlerId inválido")
    assert(type(handler) == "function",
        "[SkillManager] handler debe ser función")

    if _skillHandlers[handlerId] then
        warn("[SkillManager] Handler '" .. handlerId .. "' sobreescrito.")
    end

    _skillHandlers[handlerId] = handler
end

--- Limpia los cooldowns de un jugador (llamado al reiniciar partida).
function SkillManagerService.resetCooldowns(player: Player)
    _cooldownTracker[player.Name] = {}
end

-- =============================================================================
-- Start
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
    Players.PlayerRemoving:Connect(function(player: Player)
        _cooldownTracker[player.Name] = nil
    end)

    -- Cargar todos los handlers registrados desde SkillHandlers/
    local handlersFolder = ServerScriptService:FindFirstChild("SkillHandlers")
    if handlersFolder then
        for _, module in ipairs(handlersFolder:GetChildren()) do
            if module:IsA("ModuleScript") then
                local ok, err = pcall(function()
                    require(module)(SkillManagerService.registerHandler)
                end)
                if not ok then
                    warn("[SkillManager] Error cargando handler '" .. module.Name .. "': " .. tostring(err))
                end
            end
        end
    end

    -- Contar handlers para el print de arranque
    local handlerCount = 0
    for _ in pairs(_skillHandlers) do handlerCount += 1 end
    print("[SkillManagerService] ✅ Iniciado con " .. handlerCount .. " handlers registrados.")
end

return SkillManagerService