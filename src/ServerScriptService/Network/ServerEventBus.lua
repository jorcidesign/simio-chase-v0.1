-- =============================================================================
-- ServerEventBus.lua
-- Ubicación: src/ServerScriptService/Network/ServerEventBus.lua
--
-- SPRINT 2 — Adiciones:
--   + OvertimeStarted  : Avisa que la fase de escape (overtime) comenzó.
--   + EscapeCountdown  : Tick del timer de escape (cada segundo).
-- =============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

local ServerEventBus = {

    -- =========================================================================
    -- 🎮 MATCH FLOW
    -- =========================================================================

    MatchStateChanged = Signal.new(),
    TimeUpdated       = Signal.new(),
    TimeExpired       = Signal.new(),

    --- Disparado al entrar en LAST_MAN con el último survivor vivo.
    --- Args: (lastSurvivorChar: Model, killerChar: Model?)
    LastManStanding = Signal.new(),

    LMSMusicEnded = Signal.new(),

    --- Disparado cuando empieza la fase de escape/overtime.
    --- Args: ninguno
    OvertimeStarted = Signal.new(),

    --- Tick del timer de overtime/escape (cada segundo).
    --- Args: (remainingSeconds: number)
    EscapeCountdown = Signal.new(),

    -- =========================================================================
    -- ⚔️ COMBATE
    -- =========================================================================

    PlayerDamaged       = Signal.new(),
    SurvivorKilled      = Signal.new(),
    KillerKilled        = Signal.new(),
    StatusEffectApplied = Signal.new(),
    StatusEffectExpired = Signal.new(),

    -- =========================================================================
    -- 🎯 HABILIDADES
    -- =========================================================================

    SkillCasted  = Signal.new(),
    SkillRejected = Signal.new(),

    -- =========================================================================
    -- 🏃 ESCAPE
    -- =========================================================================

    --- Disparado cuando un survivor toca la puerta y escapa.
    --- Args: (player: Player)
    PlayerEscaped = Signal.new(),

    --- Disparado cuando la puerta de escape se abre.
    ExitOpened = Signal.new(),

    -- =========================================================================
    -- 🎵 MÚSICA (hooks para futuro AudioSystem)
    -- =========================================================================

    ChaseStarted     = Signal.new(),
    ChaseEnded       = Signal.new(),
    LMSMusicStarted  = Signal.new(),
}

return ServerEventBus