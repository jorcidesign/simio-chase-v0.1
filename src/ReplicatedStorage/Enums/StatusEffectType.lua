-- =============================================================================
-- StatusEffectType.lua
-- Ubicación: src/shared/enums/StatusEffectType.lua
-- =============================================================================

--- @enum StatusEffectType
local StatusEffectType = {
	STUN        = "STUN",        -- WalkSpeed = 0, JumpPower = 0
	SLOW        = "SLOW",        -- WalkSpeed reducida a valor fijo
	SPEED_BOOST = "SPEED_BOOST", -- WalkSpeed multiplicada
	INVINCIBLE  = "INVINCIBLE",  -- I-Frames: ignora daño entrante
	INVISIBLE   = "INVISIBLE",   -- Transparencia alta
	BLIND       = "BLIND",       -- Vignette en pantalla del afectado
	MARKED      = "MARKED",      -- Highlight permanente (Emanuel)
	RAGE        = "RAGE",        -- Buff compuesto de Poro
}

return table.freeze(StatusEffectType)