local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)
return CharacterModel.newSurvivor({
    Name        = "Nariztoteles",
    Description = "Superviviente con counter",
    WalkSpeed   = 16, RunSpeed = 24, BaseStamina = 50,
    Passive  = { Name = "Sin Pasiva", Description = "" },
    Abilities = {},
})