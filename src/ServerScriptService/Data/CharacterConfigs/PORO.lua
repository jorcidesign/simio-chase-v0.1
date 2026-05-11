-- =============================================================================
-- PORO.lua
-- Ubicación: src/server/data/CharacterConfigs/PORO.lua
-- =============================================================================

local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)

return CharacterModel.newKiller({
	Name        = "Poro Player",
	Description = "Berserker imparable de corto alcance",
	Icon        = "rbxassetid://110065651459046",
	BaseSpeed   = 20,
	M1Damage    = 25,
	M1Cooldown  = 1.1,

	Passive = {
		Name        = "Sed de Sangre",
		Description = "Genera IRA al golpear (+25) o ser aturdido (+20). Al llegar a 100 activa R.",
		RagePerHit  = 25,
		RagePerStun = 20,
	},

	Skills = {
		{
			Key             = "Q",
			Name            = "Carga de Colisión",
			ServerName      = "MARCHA",
			Description     = "Embestida lineal. Si choca con pared, self-stun 2s.",
			Icon            = "rbxassetid://4966601445",
			Cooldown        = 15,
			Duration        = 2,
			customHandlerId = "MARCHA",
			effects = {
				{ type = "Dash",   value = 55, duration = 2 },
				{ type = "Damage", value = 15, radius = 5, targetFilter = "Survivors" },
			},
			-- Parámetros específicos del handler
			Speed         = 55,
			Damage        = 15,
			SelfStunOnWall = 2.0,
		},
		{
			Key             = "E",
			Name            = "Agarre Brutal",
			ServerName      = "ESTRANGULAR",
			Description     = "Lanza cadena. Si fallas, lentitud 50% por 2s.",
			Icon            = "rbxassetid://4966601445",
			Cooldown        = 22,
			customHandlerId = "ESTRANGULAR",
			Range      = 45,
			PullForce  = 100,
			WhiffSlow  = 0.5,
		},
		{
			Key             = "R",
			Name            = "RAGE MODE",
			ServerName      = "RAGE MODE",
			Description     = "Ganas Velocidad (32), M1 instantáneo y ESP total por 20s. 1 USO POR PARTIDA.",
			Icon            = "rbxassetid://4966601445",
			Cooldown        = 0,  -- controlado por RageMeter, no por tiempo
			Duration        = 40,
			oneTimeUse      = true,
			customHandlerId = "RAGE_MODE",
			RageRequired = 100,
			BuffSpeed    = 32,
		},
		{
			Key             = "F",
			Name            = "Rugido Aterrador",
			ServerName      = "PISOTÓN",
			Description     = "Ralentiza a todos en un radio de 25 studs.",
			Icon            = "rbxassetid://4966601445",
			Cooldown        = 30,
			customHandlerId = "PISOTON",
			effects = {
				{ type = "Slow", value = 0.6, duration = 3, radius = 25, targetFilter = "Survivors" },
			},
			Radius      = 25,
			Slow        = 0.6,
			SlowDuration= 3,
		},
	},
})