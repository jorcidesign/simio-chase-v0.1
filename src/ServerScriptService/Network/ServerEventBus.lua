-- =============================================================================
-- ServerEventBus.lua
-- Ubicación: src/server/network/ServerEventBus.lua
--
-- Bus de eventos interno del servidor. Permite que los servicios se
-- comuniquen entre sí SIN imports directos (Dependency Inversion).
--
-- Patrón: Event Bus / Mediator
-- Principio SOLID: Dependency Inversion + Open/Closed
--   - Los servicios dependen del Bus, no entre sí.
--   - Agregar un nuevo evento = agregar una línea aquí.
-- =============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

--- @class ServerEventBus
--- Todos los eventos internos del servidor con sus signaturas tipadas.
local ServerEventBus = {

	-- =========================================================================
	-- 🎮 MATCH FLOW
	-- =========================================================================

	--- Disparado cuando el estado de la partida cambia.
	--- Args: (newState: GameState, oldState: GameState)
	MatchStateChanged = Signal.new(),

	--- Disparado cuando el timer se actualiza (cada segundo).
	--- Args: (remainingSeconds: number)
	TimeUpdated = Signal.new(),

	--- Disparado cuando el timer llega a 0.
	TimeExpired = Signal.new(),

	--- Disparado cuando queda solo 1 superviviente.
	--- Args: (lastSurvivor: Model, killer: Model)
	LastManStanding = Signal.new(),

	--- Disparado cuando la música LMS termina su duración.
	LMSMusicEnded = Signal.new(),

	-- =========================================================================
	-- ⚔️ COMBATE
	-- =========================================================================

	--- Disparado cuando un jugador recibe daño.
	--- Args: (victim: Player, attacker: Player, amount: number, source: string)
	PlayerDamaged = Signal.new(),

	--- Disparado cuando un superviviente muere.
	--- Args: (victim: Player, killer: Player?)
	SurvivorKilled = Signal.new(),

	--- Disparado cuando el killer muere (solo MIGUEL).
	--- Args: (killer: Player)
	KillerKilled = Signal.new(),

	--- Disparado cuando se aplica un status effect.
	--- Args: (target: Model, effectType: StatusEffectType, duration: number)
	StatusEffectApplied = Signal.new(),

	--- Disparado cuando un status effect expira.
	--- Args: (target: Model, effectType: StatusEffectType)
	StatusEffectExpired = Signal.new(),

	-- =========================================================================
	-- 🎯 HABILIDADES
	-- =========================================================================

	--- Disparado cuando un personaje usa una habilidad exitosamente.
	--- Args: (player: Player, skillId: string)
	SkillCasted = Signal.new(),

	--- Disparado cuando una habilidad es rechazada (cooldown, stun, etc.)
	--- Args: (player: Player, skillId: string, reason: string)
	SkillRejected = Signal.new(),

	-- =========================================================================
	-- 🏃 ESCAPE
	-- =========================================================================

	--- Disparado cuando un superviviente toca la puerta de salida.
	--- Args: (player: Player)
	PlayerEscaped = Signal.new(),

	--- Disparado cuando se abre la puerta de salida.
	ExitOpened = Signal.new(),

	-- =========================================================================
	-- 🎵 MÚSICA
	-- =========================================================================

	--- Disparado cuando el killer entra en rango de chase.
	--- Args: (killerId: string)
	ChaseStarted = Signal.new(),

	--- Disparado cuando el killer sale del rango de chase.
	ChaseEnded = Signal.new(),

	--- Disparado cuando se activa la música LMS.
	--- Args: (killerId: string, survivorId: string, duration: number)
	LMSMusicStarted = Signal.new(),

}

return ServerEventBus