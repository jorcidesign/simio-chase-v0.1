local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)
return CharacterModel.newSurvivor({
    Name        = "Siu",
    Description = "Superviviente ágil",
    WalkSpeed   = 16, RunSpeed = 26, BaseStamina = 50,
    Passive  = { Name = "Sin Pasiva", Description = "" },
    Abilities = {},
})