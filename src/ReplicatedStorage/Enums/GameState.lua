-- =============================================================================
-- GameState.lua
-- Ubicación: src/shared/enums/GameState.lua
--
-- Enum que define todos los estados posibles del juego.
-- Elimina el uso de strings mágicos dispersos en el código.
--
-- Principio SOLID: Open/Closed — agregar un estado nuevo no modifica
--                  la lógica existente, solo extiende esta tabla.
-- =============================================================================

--- @enum GameState
local GameState = {
	-- Fase pre-partida
	WAITING      = "WAITING",       -- Esperando jugadores mínimos
	LOBBY        = "LOBBY",         -- Countdown de lobby
	SELECTING    = "SELECTING",     -- Asignando roles y spawneando

	-- Fases de partida activa
	PLAYING      = "PLAYING",       -- Juego en progreso normal
	CHASE        = "CHASE",         -- Persecución activa (música de chase)
	LAST_MAN     = "LAST_MAN",      -- Un solo superviviente (LMS)
	ESCAPE       = "ESCAPE",        -- Puerta abierta, fase de escape

	-- Fin de partida
	ENDING       = "ENDING",        -- Mostrando resultados
	INTERMISSION = "INTERMISSION",  -- Entre partidas
}

-- Hace la tabla inmutable para evitar mutaciones accidentales en runtime
return table.freeze(GameState)