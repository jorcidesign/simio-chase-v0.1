-- =============================================================================
-- GameConstants.lua
-- Ubicación: src/ReplicatedStorage/GameConstants.lua
--
-- SPRINT 2 — Cambios:
--   + OVERTIME_DURATION    = 20s (duración de la fase de overtime/escape)
--   + LMS_BONUS_HP         = 60  (HP que recibe el último survivor en LAST_MAN)
--   + KILL_BONUS_TIME      = 15  (segundos sumados al timer por kill, según GDD conversado)
--   + EXIT_OPEN_THRESHOLD  = 60  (sin cambio, documentado explícitamente aquí)
-- =============================================================================

local GameConstants = {

    -- =========================================================================
    -- ⏱️ MATCH TIMING
    -- =========================================================================
    Match = {
        MIN_PLAYERS          = 2,
        MAX_PLAYERS          = 8,
        LOBBY_COUNTDOWN      = 15,
        BASE_TIME_PER_PLAYER = 120,

        -- Segundos que se suman al timer por cada kill del Killer.
        -- GDD §3.5: "Cada muerte de Survivor suma KILL_BONUS_TIME segundos."
        KILL_BONUS_TIME      = 15,

        -- Segundos restantes en que se abre la puerta de escape.
        -- GDD §5.2 checkpoint: "== EXIT_OPEN_THRESHOLD → ExitOpened + → ESCAPE"
        EXIT_OPEN_THRESHOLD  = 60,

        -- Duración de la fase ESCAPE (overtime).
        -- GDD §3.7: "Esta fase dura 20 segundos."
        OVERTIME_DURATION    = 20,

        -- HP extra que recibe el último survivor al entrar en LAST_MAN.
        -- GDD §3.6: "Se le aplica un buff de salud: +60 HP inmediatos."
        LMS_BONUS_HP         = 60,

        INTERMISSION_TIME    = 5,
        SELECTION_TIME       = 30,
        LOADING_TIME         = 6,
        BOT_HEALTH           = 100,
    },

    -- =========================================================================
    -- 🎮 HITBOX / COMBAT
    -- =========================================================================
    Combat = {
        DEFAULT_HITBOX_SIZE   = Vector3.new(6, 7, 7),
        DEFAULT_HITBOX_OFFSET = Vector3.new(0, 0, -3.5),
        HITBOX_DURATION       = 0.3,
        EXECUTE_HP_THRESHOLD  = 0.3,
        IFRAMES_FADE_TIME     = 0.1,
        IFRAMES_TRANSPARENCY  = 0.4,
        STUN_DAMAGE_TO_MIGUEL = 25,
    },

    -- =========================================================================
    -- 🏃 MOVEMENT
    -- =========================================================================
    Movement = {
        DEFAULT_WALK_SPEED  = 16,
        DEFAULT_RUN_SPEED   = 24,
        DEFAULT_JUMP_POWER  = 50,
        CROUCH_SPEED        = 8,
        DOUBLE_JUMP_IMPULSE = 60,
    },

    -- =========================================================================
    -- ⚡ STAMINA
    -- =========================================================================
    Stamina = {
        DRAIN_RATE        = 25,
        REGEN_RATE        = 15,
        DEPLETED_COOLDOWN = 3,
        LOW_THRESHOLD     = 0.3,
    },

    -- =========================================================================
    -- 🌍 SPAWN / LOBBY
    -- =========================================================================
    Spawn = {
        LOBBY_RADIUS    = 50,
        SURVIVOR_SPREAD = 5,
        LOBBY_Y_OFFSET  = 5,
    },

    -- =========================================================================
    -- 🎭 EFECTOS VISUALES
    -- =========================================================================
    VFX = {
        CHASE_FOG_END        = 150,
        NORMAL_FOG_END       = 100000,
        ESCAPE_TINT          = Color3.fromRGB(255, 240, 150),
        CHASE_AMBIENT        = Color3.fromRGB(5, 5, 5),
        NORMAL_AMBIENT       = Color3.fromRGB(0, 0, 0),
        RAGE_BALL_DURATION   = 0.5,
        HIGHLIGHT_FILL_TRANS = 0.5,
    },

    -- =========================================================================
    -- 📡 NETWORKING
    -- =========================================================================
    Network = {
        MAX_REMOTE_RATE     = 10,
        ABILITY_VALIDATE_MS = 100,
    },

    -- =========================================================================
    -- 🗺️ MAPAS
    -- =========================================================================
    Maps = {
        Pool = {
            "Mapa_Prueba_1",
            "Mapa_Prueba_1",
            "Mapa_Prueba_1",
        },
        DEBUG_DUMMY_COUNT = 2,
    },
}

return table.freeze(GameConstants)