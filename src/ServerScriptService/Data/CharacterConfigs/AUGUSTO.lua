-- AUGUSTO.lua
local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)
return CharacterModel.newKiller({
    Name = "Augusto", Description = "Killer de barro",
    BaseSpeed = 19, M1Damage = 22, M1Cooldown = 1.1,
    Passive = { Name = "Sin Pasiva", Description = "" },
    Skills  = {},
})