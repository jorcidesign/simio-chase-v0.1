-- =============================================================================
-- GONZACARBON.lua
-- Ubicación: src/server/data/CharacterConfigs/GONZACARBON.lua
--
-- Config data-driven de Gonzacarbon. Este archivo es TODO lo que necesitas
-- editar para cambiar su balance o habilidades.
--
-- NO contiene lógica de ejecución. La lógica está en SkillManagerService
-- y los handlers registrados via customHandlerId.
-- =============================================================================

local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)

return CharacterModel.newSurvivor({
	Name        = "Gonzacarbon",
	Description = "Maestro del sigilo con ceguera de carbón",
	Icon        = "rbxassetid://107204421092035",
	WalkSpeed   = 16,
	RunSpeed    = 26,
	BaseStamina = 50,
	RegenRate   = 1.2,

	Passive = {
		Name            = "Corcho Protector",
		Description     = "Reduces el 20% del daño recibido",
		DamageReduction = 0.20,
		LastStandSpeed  = 1.3,  -- multiplicador de velocidad al tener <30% HP
	},

	Abilities = {
		{
			Key         = "Q",
			Name        = "Ceguera de Carbón",
			ServerName  = "CEGUERA",
			Description = "Ciega al asesino en un rango de 30 studs",
			Icon        = "rbxassetid://4966601445",
			Cooldown    = 50,
			Duration    = 5,
			Range       = 30,
			VignetteSize = 0.85,

			-- El SkillManagerService buscará y ejecutará el handler "CEGUERA"
			customHandlerId = "CEGUERA",
		},
		{
			Key         = "E",
			Name        = "Camuflaje Carbón",
			ServerName  = "CAMUFLAJE",
			Description = "Te vuelves casi invisible por 6 segundos",
			Icon        = "rbxassetid://4966601445",
			Cooldown    = 45,
			Duration    = 6,
			Transparency = 0.95,

			customHandlerId = "CAMUFLAJE",

			-- Efectos declarativos (pueden ser procesados por EffectsSystem
			-- además del handler custom)
			effects = {
				{
					type     = "Stealth",
					duration = 6,
					value    = 0.95,  -- nivel de transparencia
				},
			},
		},
	},
})