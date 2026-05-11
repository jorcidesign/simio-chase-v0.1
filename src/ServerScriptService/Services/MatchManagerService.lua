-- =============================================================================
-- MatchManagerService.lua
-- Ubicación: src/ServerScriptService/Services/MatchManagerService.lua
--
-- FIX BUG 2 (derivado): El estado WAITING evaluaba MIN_PLAYERS en onEnter()
-- una sola vez. Si no había jugadores en ese momento, se quedaba bloqueado
-- porque no había nada que re-evaluara la condición después.
--
-- Solución: WAITING escucha PlayerAdded y re-evalúa. Si MIN_PLAYERS = 1
-- (debug), transiciona inmediatamente. Si MIN_PLAYERS = 2, espera al evento.
--
-- Principio: la FSM no bloquea hilos esperando condiciones externas.
-- Reacciona a eventos cuando las condiciones cambian.
-- =============================================================================

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameState      = require(ReplicatedStorage.Enums.GameState)
local GameConstants  = require(ReplicatedStorage.GameConstants)
local ServerEventBus = require(ServerScriptService.Network.ServerEventBus)
local TimeManagerService = require(script.Parent.TimeManagerService)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local MatchManagerService = {}
MatchManagerService._state = GameState.WAITING

-- Conexión a PlayerAdded que se desconecta una vez que se cumple la condición.
-- La guardamos para poder desconectarla en onExit del estado WAITING.
local _waitingForPlayersConn = nil

-- ---------------------------------------------------------------------------
-- 🧠 FSM: Definición de estados
-- ---------------------------------------------------------------------------
local States = {

    -- -----------------------------------------------------------------------
    [GameState.WAITING] = {
        onEnter = function()
            print("🛑 [MATCH] WAITING: Esperando jugadores...")

            local function tryTransitionToLobby()
                if #Players:GetPlayers() >= GameConstants.Match.MIN_PLAYERS then
                    MatchManagerService.transition(GameState.LOBBY)
                end
            end

            -- FIX: conectar al evento de jugadores ANTES de evaluar,
            -- para no perder el evento si el jugador ya está en el servidor.
            _waitingForPlayersConn = Players.PlayerAdded:Connect(tryTransitionToLobby)

            -- Evaluar inmediatamente (cubre el caso debug con MIN_PLAYERS = 1
            -- donde el jugador ya está en el servidor cuando la FSM arranca).
            tryTransitionToLobby()
        end,

        onExit = function()
            -- Limpiar la conexión para no acumular listeners entre partidas
            if _waitingForPlayersConn then
                _waitingForPlayersConn:Disconnect()
                _waitingForPlayersConn = nil
            end
        end,

        validTransitions = { GameState.LOBBY },
    },

    -- -----------------------------------------------------------------------
    [GameState.LOBBY] = {
        onEnter = function()
            print(string.format(
                "🟢 [MATCH] LOBBY: Cuenta regresiva de %ds...",
                GameConstants.Match.LOBBY_COUNTDOWN
            ))

            TimeManagerService.start(
                GameConstants.Match.LOBBY_COUNTDOWN,
                nil,
                function()
                    MatchManagerService.transition(GameState.SELECTING)
                end
            )
        end,

        onExit = function()
            TimeManagerService.cancel()
        end,

        validTransitions = { GameState.SELECTING, GameState.WAITING },
    },

    -- -----------------------------------------------------------------------
   [GameState.SELECTING] = {
        onEnter = function()
            print("⚡ [MATCH] SELECTING: Spawneando jugadores...")
            
            -- ¡NUEVO!: Clonamos el mapa ANTES de que el RespawnManager intente meter a la gente
            local WorldService = require(script.Parent.WorldService)
            WorldService.loadMap("Mapa_Prueba_1")
            
            -- Esta fase solo abre una ventana de tiempo de 5 segundos
            task.delay(5, function()
                if MatchManagerService._state == GameState.SELECTING then
                    MatchManagerService.transition(GameState.PLAYING)
                end
            end)
        end,
        validTransitions = { GameState.PLAYING, GameState.ENDING },
    },

    -- -----------------------------------------------------------------------
    [GameState.PLAYING] = {
        onEnter = function()
            local matchDuration = GameConstants.Match.BASE_TIME_PER_PLAYER
                * math.max(#Players:GetPlayers(), 1)

            print(string.format("⚔️ [MATCH] PLAYING: Partida iniciada. Duración: %ds", matchDuration))

            TimeManagerService.start(matchDuration, nil, function()
                print("⏰ [MATCH] Tiempo agotado.")
                MatchManagerService.transition(GameState.ENDING)
            end)
        end,

        onExit = function()
            TimeManagerService.cancel()
        end,

        validTransitions = { GameState.LAST_MAN, GameState.ENDING },
    },

    -- -----------------------------------------------------------------------
    [GameState.LAST_MAN] = {
        onEnter = function()
            print("🔥 [MATCH] LAST MAN STANDING")
            -- AudioService y el LMS timer se manejan via ServerEventBus listeners
        end,

        validTransitions = { GameState.ENDING },
    },

    -- -----------------------------------------------------------------------
   [GameState.ENDING] = {
        onEnter = function()
            print("🏁 [MATCH] ENDING: Mostrando resultados...")
            TimeManagerService.cancel()
            
            -- ¡NUEVO!: Borramos el mapa para volver a tener solo el Lobby
            local WorldService = require(script.Parent.WorldService)
            WorldService.unloadMap()

            task.delay(GameConstants.Match.INTERMISSION_TIME, function()
                if MatchManagerService._state == GameState.ENDING then
                    MatchManagerService.transition(GameState.WAITING)
                end
            end)
        end,
        validTransitions = { GameState.WAITING },
    },
}

-- ---------------------------------------------------------------------------
-- ⚙️ Motor de transiciones (única función que cambia _state)
-- ---------------------------------------------------------------------------
function MatchManagerService.transition(newState: string)
    local currentStateDef = States[MatchManagerService._state]

    if not currentStateDef then
        warn("[MATCH] Estado actual sin definición: " .. tostring(MatchManagerService._state))
        return
    end

    -- Validar que la transición sea legal según la FSM
    if not table.find(currentStateDef.validTransitions, newState) then
        warn(string.format(
            "❌ [MATCH] Transición ilegal: %s → %s",
            tostring(MatchManagerService._state),
            tostring(newState)
        ))
        return
    end

    local oldState = MatchManagerService._state

    -- 1. Salir del estado actual
    if currentStateDef.onExit then
        currentStateDef.onExit()
    end

    -- 2. Cambiar estado
    MatchManagerService._state = newState
    print(string.format("🔄 [MATCH] %s → %s", oldState, newState))

    -- 3. Entrar al nuevo estado
    local nextStateDef = States[newState]
    if nextStateDef and nextStateDef.onEnter then
        nextStateDef.onEnter()
    end

    -- 4. Notificar al servidor (bus interno)
    ServerEventBus.MatchStateChanged:Fire(newState, oldState)

    -- 5. Notificar a los clientes (red)
    RemoteRegistry.UpdateGameState:FireAllClients(newState)
end

-- ---------------------------------------------------------------------------
-- Reacciones a eventos del juego
-- ---------------------------------------------------------------------------
local function setupEventListeners()
    -- Cuando todos los survivors mueren → fin de partida
    ServerEventBus.SurvivorKilled:Connect(function()
        if MatchManagerService._state ~= GameState.PLAYING
            and MatchManagerService._state ~= GameState.LAST_MAN then
            return
        end

        -- Contar survivors vivos
        local aliveCount = 0
        for _, p in ipairs(Players:GetPlayers()) do
            local char = p.Character
            if char and char:FindFirstChild("SurvivorID") then
                local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    aliveCount += 1
                end
            end
        end

        if aliveCount == 0 then
            MatchManagerService.transition(GameState.ENDING)
        elseif aliveCount == 1 and MatchManagerService._state == GameState.PLAYING then
            MatchManagerService.transition(GameState.LAST_MAN)
        end
    end)

    -- Cuando el killer muere (solo MIGUEL) → survivors ganan
    ServerEventBus.KillerKilled:Connect(function()
        if MatchManagerService._state == GameState.PLAYING
            or MatchManagerService._state == GameState.LAST_MAN then
            MatchManagerService.transition(GameState.ENDING)
        end
    end)

    -- Cuando la música LMS termina → fin del overtime
    ServerEventBus.LMSMusicEnded:Connect(function()
        if MatchManagerService._state == GameState.LAST_MAN then
            MatchManagerService.transition(GameState.ENDING)
        end
    end)

    -- Si el killer se desconecta durante la partida → survivors ganan
    Players.PlayerRemoving:Connect(function(player)
        if MatchManagerService._state ~= GameState.PLAYING
            and MatchManagerService._state ~= GameState.LAST_MAN then
            return
        end

        local char = player.Character
        if char and char:FindFirstChild("KillerID") then
            print("[MATCH] El killer abandonó. Los supervivientes ganan.")
            MatchManagerService.transition(GameState.ENDING)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Arranque
-- ---------------------------------------------------------------------------
function MatchManagerService.Start()
    print("🎮 [MatchManager] FSM iniciada.")

    setupEventListeners()

    -- Disparar onEnter del estado inicial manualmente
    local initialDef = States[MatchManagerService._state]
    if initialDef and initialDef.onEnter then
        initialDef.onEnter()
    end
end

return MatchManagerService