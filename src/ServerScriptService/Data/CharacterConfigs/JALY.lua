-- JALY.lua
local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)
return CharacterModel.newKiller({
    Name = "Jaly", Description = "Killer de combo",
    BaseSpeed = 20, M1Damage = 18, M1Cooldown = 0.9,
    Passive = { Name = "Sin Pasiva", Description = "" },
    Skills  = {},
})