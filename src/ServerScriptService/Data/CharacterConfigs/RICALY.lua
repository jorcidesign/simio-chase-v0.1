local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)
return CharacterModel.newSurvivor({
    Name        = "Ricaly",
    Description = "Superviviente equilibrado",
    WalkSpeed   = 16, RunSpeed = 24, BaseStamina = 50,
    Passive  = { Name = "Sin Pasiva", Description = "" },
    Abilities = {},
})