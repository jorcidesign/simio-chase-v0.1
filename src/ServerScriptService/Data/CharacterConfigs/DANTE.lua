-- DANTE.lua
local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)
return CharacterModel.newKiller({
    Name = "Dante", Description = "Killer de distancia",
    BaseSpeed = 18, M1Damage = 20, M1Cooldown = 1.0,
    Passive = { Name = "Sin Pasiva", Description = "" },
    Skills  = {},
})