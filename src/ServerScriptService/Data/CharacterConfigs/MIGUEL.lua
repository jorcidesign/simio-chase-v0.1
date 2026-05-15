-- MIGUEL.lua
local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)
return CharacterModel.newKiller({
    Name = "Miguel", Description = "El único killer con HP",
    BaseSpeed = 22, M1Damage = 30, M1Cooldown = 1.2,
    MaxHealth = 300, HasHealth = true,
    Passive = { Name = "Sin Pasiva", Description = "" },
    Skills  = {},
})