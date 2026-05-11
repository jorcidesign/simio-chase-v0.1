-- =============================================================================
-- GameConstants.lua
-- Ubicación: src/ReplicatedStorage/GameConstants.lua
--
-- ÚNICA fuente de verdad para todas las constantes del juego.
--
-- FIX BUG 2: DEBUG_MODE era una variable global inexistente en Roblox.
-- Se define aquí como local ANTES de usarse. Para activar el modo debug
-- en Studio, cambiar DEBUG_MODE = true. Para producción, false.
-- =============================================================================

-- ⚠️  CAMBIAR ESTO PARA PRODUCCIÓN
local DEBUG_MODE = true

local GameConstants = {

    -- =========================================================================
    -- ⏱️ MATCH TIMING
    -- =========================================================================
    Match = {
        -- FIX: antes era DEBUG_MODE and 1 or 2, donde DEBUG_MODE = nil global
        -- Ahora DEBUG_MODE es una variable local real con valor explícito.
        MIN_PLAYERS          = DEBUG_MODE and 1 or 2,
        LOBBY_COUNTDOWN      = DEBUG_MODE and 3 or 40,
        BASE_TIME_PER_PLAYER = 120,
        KILL_BONUS_TIME      = 30,
        EXIT_OPEN_THRESHOLD  = 60,
        INTERMISSION_TIME    = DEBUG_MODE and 2 or 8,
        BOT_HEALTH           = 100,
    },

    -- =========================================================================
    -- 🎵 MÚSICA LMS
    -- =========================================================================
    LMS = {
        DEFAULT_DURATION = 160,
        Combinations = {
            GONZACARBON_DANTE     = 240,
            DANTE_NARIZTOTELES    = 266,
            GONZACARBON_PORO      = 235,
            NARIZTOTELES_PORO     = 280,
            VACUMING_DANTE        = 180,
            SURI_PORO             = 220,
            EMANUEL_NARIZTOTELES  = 175,
            SIU_DANTE             = 175,
            RICALY_PORO           = 175,
        },
    },

    -- =========================================================================
    -- 🎵 IDs DE MÚSICA
    -- =========================================================================
    Music = {
        Lobby = "rbxassetid://83197620419872",
        Chase = {
            PORO    = "rbxassetid://140027648193529",
            DANTE   = "rbxassetid://1839246711",
            JALY    = "rbxassetid://1842987785",
            AUGUSTO = "rbxassetid://1848354536",
            MIGUEL  = "rbxassetid://1848354536",
            EMANUEL = "rbxassetid://1848354536",
        },
        LMS = {
            GONZACARBON_DANTE    = "rbxassetid://88734539401740",
            DANTE_NARIZTOTELES   = "rbxassetid://136280306824349",
            GONZACARBON_PORO     = "rbxassetid://118507138936517",
            NARIZTOTELES_PORO    = "rbxassetid://115650577425932",
            VACUMING_DANTE       = "rbxassetid://110590716157779",
            SURI_PORO            = "rbxassetid://139041776771213",
            EMANUEL_NARIZTOTELES = "rbxassetid://1839889424",
            SIU_DANTE            = "rbxassetid://1839889424",
            RICALY_PORO          = "rbxassetid://1839889424",
            Default              = "rbxassetid://72530471129415",
        },
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
    -- 🎤 AUDIO
    -- =========================================================================
    Audio = {
        LOBBY_VOLUME  = 0.4,
        CHASE_VOLUME  = 0.6,
        LMS_VOLUME    = 0.7,
        VOICE_VOLUME  = 0.8,
        TICK_VOLUME   = 0.3,
    },

    -- =========================================================================
    -- 🔧 ANIMACIONES
    -- =========================================================================
    Animations = {
        Shared = {
-- ⚠️ IDs temporales para pruebas en Studio sin publicar.
        -- Reemplazar por los IDs propios después de publicar el juego.
        Idle        = "rbxassetid://180435571",
        Walk        = "rbxassetid://180426354",
        Run         = "rbxassetid://161006061",
        Jump        = "rbxassetid://125750702",
        WalkInjured = "rbxassetid://180436148",  -- usando Fall como placeholder
        RunInjured  = "rbxassetid://161006061",  -- mismo que Run por ahora
        },
    },
}

return table.freeze(GameConstants)