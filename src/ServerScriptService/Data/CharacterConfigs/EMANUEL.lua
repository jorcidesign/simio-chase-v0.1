-- EMANUEL.lua
local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)
return CharacterModel.newKiller({
    Name = "Emanuel", Description = "Killer de marcas",
    BaseSpeed = 19, M1Damage = 20, M1Cooldown = 1.0,
    Passive = { Name = "Sin Pasiva", Description = "" },
    Skills  = {},
})