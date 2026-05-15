-- =============================================================================
-- MatchManagerService.lua
-- Ubicación: src/ServerScriptService/Services/MatchManagerService.lua
--
-- SPRINT 2 — Lógica de Overtime / Escape / Last Man Standing:
--
-- FLUJO CORRECTO según GDD §3.5 – §3.7:
--
--   PLAYING
--     ├── aliveCount == 0                     → ENDING  (killer gana)
--     ├── aliveCount == 1, escapedCount == 0  → LAST_MAN
--     └── timer <= EXIT_OPEN_THRESHOLD        → ESCAPE  (puerta se abre, overtime)
--
--   LAST_MAN
--     ├── survivor muere                      → ENDING
--     ├── timer <= EXIT_OPEN_THRESHOLD        → ESCAPE  (puerta se abre)
--     └── LMSMusicEnded                       → ENDING
--
--   ESCAPE  (overtime de 20 segundos según GDD)
--     ├── todos muertos o escapados           → ENDING
--     └── overtime timer llega a 0           → ENDING
--
-- REGLA KILL_BONUS_TIME:
--   Cada muerte de Survivor suma KILL_BONUS_TIME al timer principal.
--   Esto solo aplica en PLAYING y LAST_MAN, no durante ESCAPE.
--
-- REGLA LMS BUFF:
--   Al entrar en LAST_MAN el último survivor recibe +LMS_BONUS_HP HP.
--
-- ARQUITECTURA:
--   - Solo MatchManagerService llama a transition(). GDD §2.2.
--   - checkWinConditions() es la función centralizada que evalúa victoria.
--     Se llama desde los listeners de SurvivorKilled y PlayerEscaped.
--   - El overtime tiene su PROPIO timer separado del timer principal.
--     Esto evita confundir los 20s del escape con el countdown de partida.
-- =============================================================================

local Players             = game:GetService("Players")
local TweenService        = game:GetService("TweenService")
local Debris              = game:GetService("Debris")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameState          = require(ReplicatedStorage.Enums.GameState)
local GameConstants      = require(ReplicatedStorage.GameConstants)
local ServerEventBus     = require(ServerScriptService.Network.ServerEventBus)
local TimeManagerService = require(script.Parent.TimeManagerService)
local RemoteRegistry     = require(ReplicatedStorage.Network.RemoteRegistry)

local MatchManagerService = {}
MatchManagerService._state = GameState.WAITING

-- =============================================================================
-- Estado interno
-- =============================================================================

local _waitingForPlayersConn:   RBXScriptConnection? = nil
local _lobbyPlayerRemovingConn: RBXScriptConnection? = nil
local _exitDoorConns: { RBXScriptConnection } = {}

-- Timer de overtime (independiente del timer principal de partida)
local _overtimeThread: thread? = nil

-- Forward declaration para que los estados puedan referenciarlo
local States

-- =============================================================================
-- Helpers de conteo — la única fuente de verdad sobre el estado de los survivors
-- =============================================================================

--- Cuenta survivors vivos (sin tag HasEscaped) y escapados.
--- Returns: aliveCount, escapedCount, totalSurvivors
local function countSurvivors(): (number, number, number)
    local alive   = 0
    local escaped = 0
    local total   = 0

    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if char and char:FindFirstChild("SurvivorID") then
            total += 1
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                if char:FindFirstChild("HasEscaped") then
                    escaped += 1
                else
                    alive += 1
                end
            end
        end
    end

    return alive, escaped, total
end

--- Busca el personaje del último survivor vivo (sin escapar).
local function findLastSurvivorChar(): Model?
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if char and char:FindFirstChild("SurvivorID") and not char:FindFirstChild("HasEscaped") then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                return char
            end
        end
    end
    return nil
end

-- =============================================================================
-- Overtime timer (fase ESCAPE)
--
-- Es un timer completamente separado del timer principal.
-- Dura OVERTIME_DURATION segundos (20s según GDD).
-- Cada tick emite EscapeTimerTick a los clientes.
-- Al expirar → ENDING.
-- =============================================================================

local function cancelOvertime()
    if _overtimeThread then
        task.cancel(_overtimeThread)
        _overtimeThread = nil
    end
end

local function startOvertimeTimer()
    cancelOvertime()

    local remaining = GameConstants.Match.OVERTIME_DURATION
    print(string.format("⏳ [Overtime] Timer iniciado: %ds", remaining))

    _overtimeThread = task.spawn(function()
        while remaining > 0 do
            task.wait(1)
            remaining -= 1

            -- Notificar al cliente el tiempo de escape restante
            RemoteRegistry.EscapeTimerTick:FireAllClients(remaining)
            ServerEventBus.EscapeCountdown:Fire(remaining)

            print(string.format("⏳ [Overtime] %ds restantes", remaining))
        end

        -- Timer de escape agotado → todos pierden
        print("⏰ [Overtime] Tiempo de escape agotado. Killer gana.")
        _overtimeThread = nil

        if MatchManagerService._state == GameState.ESCAPE then
            MatchManagerService.transition(GameState.ENDING)
        end
    end)
end

-- =============================================================================
-- Aplicar el buff de Last Man Standing al último survivor
-- GDD §3.6: +60 HP inmediatos (no supera MaxHealth) + VFX dorado
-- =============================================================================

local function applyLMSBuff(survivorChar: Model)
    local hum = survivorChar:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local bonus = GameConstants.Match.LMS_BONUS_HP
    hum.Health = math.min(hum.MaxHealth, hum.Health + bonus)

    local root = survivorChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    -- VFX: esfera dorada expansiva
    local fx = Instance.new("Part")
    fx.Shape        = Enum.PartType.Ball
    fx.Size         = Vector3.new(4, 4, 4)
    fx.Position     = root.Position
    fx.Color        = Color3.fromRGB(255, 220, 50)
    fx.Material     = Enum.Material.Neon
    fx.Transparency = 0.2
    fx.Anchored     = true
    fx.CanCollide   = false
    fx.Parent       = workspace

    TweenService:Create(fx, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size        = Vector3.new(20, 20, 20),
        Transparency = 1,
    }):Play()
    Debris:AddItem(fx, 1.2)

    print(string.format("⭐ [LMS] Buff de +%dHP aplicado a '%s'. HP ahora: %.0f / %.0f",
        bonus, survivorChar.Name, hum.Health, hum.MaxHealth))
end

-- =============================================================================
-- Abrir la puerta de escape
-- GDD §3.7: ExitOpen a todos los clientes + preset de iluminación.
-- =============================================================================

local function openEscapeDoor()
    ServerEventBus.ExitOpened:Fire()
    RemoteRegistry.ExitOpen:FireAllClients()
    RemoteRegistry.OvertimeStarted:FireAllClients()

    local WorldService = require(script.Parent.WorldService)
    WorldService.applyLightingPreset("Escape", 3)

    print("🚪 [ESCAPE] Puerta de escape abierta. ¡Overtime iniciado!")
end

-- =============================================================================
-- Registrar listeners en la ExitDoor del mapa activo
-- =============================================================================

local function registerExitDoorListeners()
    local WorldService = require(script.Parent.WorldService)
    local activeMap    = WorldService.getActiveMap()
    if not activeMap then return end

    local exitDoor = activeMap:FindFirstChild("ExitDoor", true)
    if not exitDoor then
        warn("[MatchManager] No se encontró 'ExitDoor' en el mapa activo.")
        return
    end

    local function onDoorTouched(hit: BasePart)
        -- Solo procesar durante la fase de escape
        if MatchManagerService._state ~= GameState.ESCAPE then return end

        local char = hit.Parent :: Model?
        if not char then return end
        if not char:FindFirstChild("SurvivorID") then return end
        if char:FindFirstChild("HasEscaped") then return end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end

        local player = Players:GetPlayerFromCharacter(char)
        if not player then return end

        -- Marcar como escapado
        local tag = Instance.new("BoolValue")
        tag.Name   = "HasEscaped"
        tag.Parent = char

        -- Teletransportar al lobby
        local lobbyCF = WorldService.getLobbySpawnCFrame()
        local ok, err = pcall(function()
            char:PivotTo(lobbyCF + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
        end)
        if not ok then
            warn("[MatchManager] Error al teletransportar a " .. player.Name .. ": " .. tostring(err))
        end

        RemoteRegistry.EscapeSuccess:FireClient(player)
        print(string.format("🏃 [ESCAPE] %s escapó con éxito.", player.Name))

        ServerEventBus.PlayerEscaped:Fire(player)
        -- checkWinConditions() se llama desde el listener de PlayerEscaped
    end

    -- Conectar a BaseParts dentro de ExitDoor
    if exitDoor:IsA("BasePart") then
        table.insert(_exitDoorConns, exitDoor.Touched:Connect(onDoorTouched))
    else
        for _, part in ipairs(exitDoor:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(_exitDoorConns, part.Touched:Connect(onDoorTouched))
            end
        end
    end

    print(string.format("🚪 [MatchManager] Listeners de ExitDoor registrados (%d partes).", #_exitDoorConns))
end

local function cleanupExitDoorListeners()
    for _, conn in ipairs(_exitDoorConns) do
        conn:Disconnect()
    end
    table.clear(_exitDoorConns)
end

-- =============================================================================
-- checkWinConditions — evaluación centralizada de victoria
-- GDD §2.2: Solo MatchManagerService decide transiciones.
-- =============================================================================

local function checkWinConditions()
    local state = MatchManagerService._state

    -- No evaluar en estados donde no hay partida activa
    if state == GameState.WAITING
    or state == GameState.LOBBY
    or state == GameState.SELECTING
    or state == GameState.LOADING
    or state == GameState.ENDING then
        return
    end

    local alive, escaped, total = countSurvivors()

    print(string.format("🔍 [WinCheck] Estado=%s | Vivos=%d | Escapados=%d | Total=%d",
        state, alive, escaped, total))

    -- Todos los survivors muertos → Killer gana
    if alive == 0 and escaped == 0 then
        print("💀 [WinCheck] Todos los survivors muertos → Killer gana.")
        MatchManagerService.transition(GameState.ENDING)
        return
    end

    -- Todos los survivors que quedan escaparon → Survivors ganan
    if alive == 0 and escaped > 0 then
        print("🏃 [WinCheck] Todos los survivors escaparon → Survivors ganan.")
        MatchManagerService.transition(GameState.ENDING)
        return
    end

    -- En PLAYING con 1 survivor vivo y ninguno escapado → LAST_MAN
    if state == GameState.PLAYING and alive == 1 and escaped == 0 then
        MatchManagerService.transition(GameState.LAST_MAN)
        return
    end
end

-- =============================================================================
-- Motor de transiciones
-- GDD §2.2: única función que cambia _state.
-- =============================================================================

function MatchManagerService.transition(newState: string)
    local currentStateDef = States[MatchManagerService._state]
    if not currentStateDef then
        warn("[MatchManager] Estado actual sin definición: " .. tostring(MatchManagerService._state))
        return
    end

    if not table.find(currentStateDef.validTransitions, newState) then
        warn(string.format("❌ [MatchManager] Transición ilegal: %s → %s",
            MatchManagerService._state, newState))
        return
    end

    local oldState = MatchManagerService._state

    -- onExit antes del cambio de estado (GDD §2.2)
    local ok, err = pcall(function()
        if currentStateDef.onExit then currentStateDef.onExit() end
    end)
    if not ok then
        warn("[MatchManager] Error en onExit de " .. oldState .. ": " .. tostring(err))
    end

    MatchManagerService._state = newState
    print(string.format("🔄 [MatchManager] %s → %s", oldState, newState))

    -- onEnter después del cambio de estado (GDD §2.2)
    local nextStateDef = States[newState]
    if nextStateDef and nextStateDef.onEnter then
        ok, err = pcall(nextStateDef.onEnter)
        if not ok then
            warn("[MatchManager] Error en onEnter de " .. newState .. ": " .. tostring(err))
        end
    end

    -- Notificar al bus interno y a los clientes (GDD §2.2)
    ServerEventBus.MatchStateChanged:Fire(newState, oldState)
    RemoteRegistry.UpdateGameState:FireAllClients(newState)
end

-- =============================================================================
-- FSM — Definición de estados
-- =============================================================================

States = {

    -- -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------
    [GameState.WAITING] = {
        onEnter = function()
            print("🛑 [MATCH] WAITING: Esperando jugadores...")

            local function tryTransitionToLobby()
                if #Players:GetPlayers() >= GameConstants.Match.MIN_PLAYERS then
                    -- ✅ FIX: Usar task.defer evita colisiones de estado en el cliente
                    -- cuando venimos de STATS -> WAITING y pasamos directo a LOBBY
                    task.defer(function()
                        if MatchManagerService._state == GameState.WAITING then
                            MatchManagerService.transition(GameState.LOBBY)
                        end
                    end)
                end
            end

            _waitingForPlayersConn = Players.PlayerAdded:Connect(tryTransitionToLobby)
            tryTransitionToLobby()
        end,
        onExit = function()
            if _waitingForPlayersConn then
                _waitingForPlayersConn:Disconnect()
                _waitingForPlayersConn = nil
            end
        end,
        validTransitions = { GameState.LOBBY },
    },

    -- -------------------------------------------------------------------------
    [GameState.LOBBY] = {
        onEnter = function()
            print(string.format("🟢 [MATCH] LOBBY: Countdown de %ds...", GameConstants.Match.LOBBY_COUNTDOWN))

            _lobbyPlayerRemovingConn = Players.PlayerRemoving:Connect(function()
                task.defer(function()
                    if (#Players:GetPlayers()) < GameConstants.Match.MIN_PLAYERS then
                        print("🛑 [MATCH] Jugadores insuficientes. Cancelando inicio.")
                        MatchManagerService.transition(GameState.WAITING)
                    end
                end)
            end)

            TimeManagerService.start(GameConstants.Match.LOBBY_COUNTDOWN, nil, function()
                MatchManagerService.transition(GameState.SELECTING)
            end)
        end,
        onExit = function()
            TimeManagerService.cancel()
            if _lobbyPlayerRemovingConn then
                _lobbyPlayerRemovingConn:Disconnect()
                _lobbyPlayerRemovingConn = nil
            end
        end,
        validTransitions = { GameState.SELECTING, GameState.WAITING },
    },

    -- -------------------------------------------------------------------------
    [GameState.SELECTING] = {
        onEnter = function()
            print("⚡ [MATCH] SELECTING: Eligiendo personajes...")
            local WorldService              = require(script.Parent.WorldService)
            local CharacterSelectionService = require(script.Parent.CharacterSelectionService)

            WorldService.loadRandomMap()
            CharacterSelectionService.StartPhase()

            TimeManagerService.start(GameConstants.Match.SELECTION_TIME, nil, function()
                CharacterSelectionService.FinalizePhase()
                MatchManagerService.transition(GameState.LOADING)
            end)
        end,
        validTransitions = { GameState.LOADING, GameState.ENDING },
    },

    -- -------------------------------------------------------------------------
    [GameState.LOADING] = {
        onEnter = function()
            print("⏳ [MATCH] LOADING: Presentando partida...")
            local WorldService              = require(script.Parent.WorldService)
            local CharacterSelectionService = require(script.Parent.CharacterSelectionService)

            local mapName    = WorldService.getActiveMapName() or "Desconocido"
            local roles, picks = CharacterSelectionService.GetFinalData()

            local introData = { map = mapName, killer = nil, survivors = {} }
            for p, role in pairs(roles) do
                if role == "Killer" then
                    introData.killer = { name = p.Name, charId = picks[p] }
                else
                    table.insert(introData.survivors, { name = p.Name, charId = picks[p] })
                end
            end

            RemoteRegistry.ShowMatchIntro:FireAllClients(introData)

            TimeManagerService.start(GameConstants.Match.LOADING_TIME, nil, function()
                MatchManagerService.transition(GameState.PLAYING)
            end)
        end,
        validTransitions = { GameState.PLAYING, GameState.ENDING },
    },

    -- -------------------------------------------------------------------------
    -- PLAYING: partida activa.
    -- La puerta de escape se activa vía el checkpoint de TimeUpdated.
    -- La condición de victoria se evalúa en checkWinConditions().
    -- -------------------------------------------------------------------------
    [GameState.PLAYING] = {
        onEnter = function()
            local matchDuration = GameConstants.Match.BASE_TIME_PER_PLAYER
                * math.max(#Players:GetPlayers(), 1)

            print(string.format("⚔️  [MATCH] PLAYING: Partida iniciada. Duración: %ds", matchDuration))

            local WorldService = require(script.Parent.WorldService)
            WorldService.spawnTestDummies()

            -- Registrar listeners de la puerta de escape ahora que el mapa está cargado
            registerExitDoorListeners()

            TimeManagerService.start(matchDuration, nil, function()
                print("⏰ [MATCH] Tiempo principal agotado.")
                -- Si la partida sigue activa (no se entró en ESCAPE todavía), terminar
                if MatchManagerService._state == GameState.PLAYING then
                    print("✅ [MATCH] Survivors ganan por tiempo.")
                    MatchManagerService.transition(GameState.ENDING)
                end
            end)
        end,
        onExit = function()
            -- NO cancelamos el timer aquí para que LAST_MAN siga usando el mismo timer
        end,
        validTransitions = { GameState.LAST_MAN, GameState.ESCAPE, GameState.ENDING },
    },

    -- -------------------------------------------------------------------------
    -- LAST_MAN: solo 1 survivor vivo.
    -- El timer principal SIGUE corriendo. No se cancela.
    -- Si el timer llega al checkpoint EXIT_OPEN_THRESHOLD → se abre la puerta.
    -- Si el survivor muere → ENDING.
    -- -------------------------------------------------------------------------
    [GameState.LAST_MAN] = {
        onEnter = function()
            print("🔥 [MATCH] LAST_MAN: Solo un survivor en pie.")

            local lastChar = findLastSurvivorChar()
            if lastChar then
                applyLMSBuff(lastChar)
                ServerEventBus.LastManStanding:Fire(lastChar, nil)
            end
        end,
        onExit = function()
            -- El timer principal se cancela cuando se entre en ESCAPE o ENDING
        end,
        validTransitions = { GameState.ESCAPE, GameState.ENDING },
    },

    -- -------------------------------------------------------------------------
    -- ESCAPE: overtime de 20 segundos.
    -- El timer principal SE CANCELA al entrar aquí.
    -- Se inicia un timer separado de OVERTIME_DURATION (20s).
    -- Si todos escapan o mueren → ENDING.
    -- Si el overtime llega a 0 → ENDING (killer gana).
    -- -------------------------------------------------------------------------
    [GameState.ESCAPE] = {
        onEnter = function()
            print("🏃 [MATCH] ESCAPE: ¡La puerta está abierta! Overtime de " 
                .. GameConstants.Match.OVERTIME_DURATION .. "s.")

            -- Cancelar el timer principal (ya no sirve en overtime)
            TimeManagerService.cancel()

            -- Abrir la puerta (VFX + notificar clientes)
            openEscapeDoor()

            -- Iniciar el timer de overtime (20s)
            startOvertimeTimer()
        end,
        onExit = function()
            cancelOvertime()
            cleanupExitDoorListeners()
        end,
        validTransitions = { GameState.ENDING },
    },

    -- -------------------------------------------------------------------------
    -- ENDING: pantalla de resultados, freeze, cleanup.
    -- GDD §3.8.
    -- -------------------------------------------------------------------------
   -- -------------------------------------------------------------------------
    [GameState.ENDING] = {
        onEnter = function()
            print("🏁 [MATCH] ENDING: Mostrando resultados de victoria/derrota...")
            TimeManagerService.cancel()
            cancelOvertime()
            cleanupExitDoorListeners()

            -- Freeze de todos los jugadores
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.WalkSpeed = 0
                    hum.JumpPower = 0
                end
            end

            -- ✅ Transicionar a STATS en lugar de volver a WAITING
            task.delay(GameConstants.Match.INTERMISSION_TIME, function()
                if MatchManagerService._state == GameState.ENDING then
                    MatchManagerService.transition(GameState.STATS)
                end
            end)
        end,
        validTransitions = { GameState.STATS }, -- ✅ Cambiado
    },

    -- -------------------------------------------------------------------------
    -- ✅ NUEVO ESTADO: STATS
    -- -------------------------------------------------------------------------
    [GameState.STATS] = {
        onEnter = function()
            print("📊 [MATCH] STATS: Mostrando estadísticas finales...")
            
            -- Descargar el mapa aquí para alivianar el servidor mientras ven las stats
            local WorldService = require(script.Parent.WorldService)
            WorldService.unloadMap()

            -- Aquí puedes construir tu tabla de stats real (daño hecho, tiempo, etc.)
            local mockStatsData = { winner = "TBD" }
            RemoteRegistry.DisplayStats:FireAllClients(mockStatsData)

            -- Mostrar la UI de stats durante 10 segundos, luego reiniciar
            TimeManagerService.start(10, nil, function()
                MatchManagerService.transition(GameState.WAITING)
            end)
        end,
        validTransitions = { GameState.WAITING },
    },
}

-- =============================================================================
-- Listeners de eventos del juego
-- =============================================================================

local function setupEventListeners()

    -- ─── Kill → +KILL_BONUS_TIME al timer + checkWin ─────────────────────────
    -- GDD §3.5: "Cada muerte de Survivor suma KILL_BONUS_TIME segundos."
    -- Solo en PLAYING y LAST_MAN (no en ESCAPE/overtime).
    ServerEventBus.SurvivorKilled:Connect(function()
        local state = MatchManagerService._state
        if state == GameState.PLAYING or state == GameState.LAST_MAN then
            TimeManagerService.addTime(GameConstants.Match.KILL_BONUS_TIME)
            print(string.format("💀 [MATCH] Kill bonus: +%ds al timer.", GameConstants.Match.KILL_BONUS_TIME))
        end
        checkWinConditions()
    end)

    -- ─── Escape → checkWin ────────────────────────────────────────────────────
    ServerEventBus.PlayerEscaped:Connect(function(player)
        print(string.format("🏃 [Bus] PlayerEscaped recibido: %s", player.Name))
        checkWinConditions()
    end)

    -- ─── Killer muerto → ENDING (solo MIGUEL tiene HP) ────────────────────────
    ServerEventBus.KillerKilled:Connect(function()
        local state = MatchManagerService._state
        if state == GameState.PLAYING
        or state == GameState.LAST_MAN
        or state == GameState.ESCAPE then
            print("☠️  [MATCH] El killer murió. Survivors ganan.")
            MatchManagerService.transition(GameState.ENDING)
        end
    end)

    -- ─── Killer abandona → ENDING ─────────────────────────────────────────────
    Players.PlayerRemoving:Connect(function(player)
        local state = MatchManagerService._state
        if state == GameState.PLAYING
        or state == GameState.LAST_MAN
        or state == GameState.ESCAPE then
            local char = player.Character
            if char and char:FindFirstChild("KillerID") then
                print("[MATCH] El killer abandonó. Survivors ganan.")
                MatchManagerService.transition(GameState.ENDING)
            end
        end
    end)

    -- ─── LMS Music termina → ENDING (hook para futuro AudioSystem) ────────────
    ServerEventBus.LMSMusicEnded:Connect(function()
        if MatchManagerService._state == GameState.LAST_MAN then
            print("[MATCH] Música LMS terminó → ENDING.")
            MatchManagerService.transition(GameState.ENDING)
        end
    end)

    -- ─── Checkpoint de tiempo → abrir puerta de escape ────────────────────────
    -- GDD §5.2: "== EXIT_OPEN_THRESHOLD → ExitOpened + → ESCAPE"
    -- Se escucha TimeUpdated para detectar el momento exacto.
    ServerEventBus.TimeUpdated:Connect(function(remaining: number)
        local state = MatchManagerService._state
        if state ~= GameState.PLAYING and state ~= GameState.LAST_MAN then return end

        -- Exactamente en el umbral: abrir la puerta y transicionar a ESCAPE
        if remaining == GameConstants.Match.EXIT_OPEN_THRESHOLD then
            print(string.format("🚪 [MATCH] Timer llegó a %ds → Abriendo puerta de escape.",
                GameConstants.Match.EXIT_OPEN_THRESHOLD))
            MatchManagerService.transition(GameState.ESCAPE)
        end
    end)
end

-- =============================================================================
-- Start
-- =============================================================================

function MatchManagerService.Start()
    print("🎮 [MatchManagerService] FSM iniciada.")
    setupEventListeners()

    -- Disparar onEnter del estado inicial
    local initialDef = States[MatchManagerService._state]
    if initialDef and initialDef.onEnter then
        initialDef.onEnter()
    end
end

return MatchManagerService