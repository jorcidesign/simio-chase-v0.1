-- =============================================================================
-- CharacterType.lua
-- Ubicación: src/shared/enums/CharacterType.lua
-- =============================================================================

--- @enum CharacterType
local CharacterType = {
	SURVIVOR = "Survivor",
	KILLER   = "Killer",
}

return table.freeze(CharacterType)