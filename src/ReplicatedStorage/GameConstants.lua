-- =============================================================================
-- GameConstants.lua
-- Ubicación: src/shared/GameConstants.lua
--
-- ÚNICA fuente de verdad para todas las constantes del juego.
-- Ningún número mágico debe existir fuera de este archivo.
--
-- Principio SOLID: Single Responsibility + Open/Closed
--   - Para cambiar balance: editar SOLO este archivo.
--   - Los servicios leen constantes, no las definen.
-- =============================================================================

local GameConstants = {

	-- =========================================================================
	-- ⏱️ MATCH TIMING
	-- =========================================================================
	Match = {
		MIN_PLAYERS          = 2,
		LOBBY_COUNTDOWN      = 40,    -- segundos en lobby antes de iniciar
		BASE_TIME_PER_PLAYER = 120,   -- segundos por jugador al calcular duración
		KILL_BONUS_TIME      = 30,    -- +seg al timer por cada kill del killer
		EXIT_OPEN_THRESHOLD  = 60,    -- seg restantes para abrir salida
		INTERMISSION_TIME    = 8,     -- seg mostrando stats entre partidas
		BOT_HEALTH           = 100,
	},

	-- =========================================================================
	-- 🎵 MÚSICA LMS (Last Man Standing)
	-- =========================================================================
	LMS = {
		DEFAULT_DURATION = 160, -- segundos si no hay combinación específica
		-- Combinaciones específicas: survivorID_killerID = duración en segundos
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
		HITBOX_DURATION       = 0.3,   -- segundos que el hitbox está activo
		EXECUTE_HP_THRESHOLD  = 0.3,   -- % de HP para triggear ejecuciones
		IFRAMES_FADE_TIME     = 0.1,   -- seg de fade al aplicar i-frames
		IFRAMES_TRANSPARENCY  = 0.4,   -- transparencia adicional durante i-frames
		STUN_DAMAGE_TO_MIGUEL = 25,    -- daño que recibe Miguel por cada stun
	},

	-- =========================================================================
	-- 🏃 MOVEMENT (valores por defecto si CharacterConfig no los define)
	-- =========================================================================
	Movement = {
		DEFAULT_WALK_SPEED  = 16,
		DEFAULT_RUN_SPEED   = 24,
		DEFAULT_JUMP_POWER  = 50,
		CROUCH_SPEED        = 8,
		DOUBLE_JUMP_IMPULSE = 60,   -- fuerza vertical del segundo salto
	},

	-- =========================================================================
	-- ⚡ STAMINA (Supervivientes)
	-- =========================================================================
	Stamina = {
		DRAIN_RATE   = 25,  -- por segundo al correr
		REGEN_RATE   = 15,  -- por segundo base
		DEPLETED_COOLDOWN = 3, -- seg de penalización al agotarse
		LOW_THRESHOLD     = 0.3, -- % para mostrar advertencia
	},

	-- =========================================================================
	-- 🌍 SPAWN / LOBBY
	-- =========================================================================
	Spawn = {
		LOBBY_RADIUS    = 50,   -- studs: radio para considerar "en lobby"
		SURVIVOR_SPREAD = 5,    -- studs de variación random en spawn
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
		MAX_REMOTE_RATE      = 10,  -- llamadas por segundo por jugador
		ABILITY_VALIDATE_MS  = 100, -- ms de tolerancia para validar cooldowns
	},

	-- =========================================================================
	-- 🎤 AUDIO
	-- =========================================================================
	Audio = {
		LOBBY_VOLUME   = 0.4,
		CHASE_VOLUME   = 0.6,
		LMS_VOLUME     = 0.7,
		VOICE_VOLUME   = 0.8,
		TICK_VOLUME    = 0.3,
	},

	-- =========================================================================
	-- 🔧 ANIMACIONES (IDs compartidos)
	-- =========================================================================
	Animations = {
		Shared = {
			Walk        = "rbxassetid://122094571449285",
			Run         = "rbxassetid://130164504170103",
			Jump        = "rbxassetid://120055029966875",
			Idle        = "rbxassetid://104001703669553",
			WalkInjured = "rbxassetid://96764569355490",
			RunInjured  = "rbxassetid://93129478933187",
		},
	},
}

return table.freeze(GameConstants)