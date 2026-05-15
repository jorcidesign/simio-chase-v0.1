local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)
return CharacterModel.newSurvivor({
    Name        = "Vacuming",
    Description = "Superviviente de apoyo",
    WalkSpeed   = 16, RunSpeed = 24, BaseStamina = 50,
    Passive  = { Name = "Sin Pasiva", Description = "" },
    Abilities = {},
})