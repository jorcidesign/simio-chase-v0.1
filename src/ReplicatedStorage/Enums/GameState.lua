-- =============================================================================
-- GameState.lua
-- Ubicación: src/ReplicatedStorage/Enums/GameState.lua
--
-- SPRINT 2 — Sin cambios de estados. El flujo ESCAPE ya cubría el overtime.
-- Se documenta aquí el mapping real según el GDD:
--
--   PLAYING   → LAST_MAN (1 survivor vivo, sin escapados)
--   PLAYING   → ESCAPE   (timer <= EXIT_OPEN_THRESHOLD)
--   LAST_MAN  → ESCAPE   (timer <= EXIT_OPEN_THRESHOLD)
--   ESCAPE    → ENDING   (todos muertos/escapados o timer = 0)
--
-- El estado ESCAPE ES el "overtime" descrito en el GDD.
-- No se añade un estado OVERTIME separado para no romper las transiciones
-- válidas ya establecidas.
-- =============================================================================

local GameState = {
    WAITING      = "WAITING",
    LOBBY        = "LOBBY",
    SELECTING    = "SELECTING",
    LOADING      = "LOADING",

    PLAYING      = "PLAYING",
    CHASE        = "CHASE",

    -- Último survivor vivo, sin haber escapado. Recibe buff de +60 HP.
    LAST_MAN     = "LAST_MAN",

    -- Puerta abierta. Fase de escape (overtime 20s).
    -- Entra desde PLAYING o LAST_MAN cuando timer <= EXIT_OPEN_THRESHOLD.
    ESCAPE       = "ESCAPE",

    ENDING       = "ENDING",
    STATS        = "STATS",       -- ✅ NUEVO: Fase de estadísticas
    INTERMISSION = "INTERMISSION",
}

return table.freeze(GameState)