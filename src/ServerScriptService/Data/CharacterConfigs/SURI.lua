local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)
return CharacterModel.newSurvivor({
    Name        = "Suri",
    Description = "Superviviente sigilosa",
    WalkSpeed   = 16, RunSpeed = 25, BaseStamina = 50,
    Passive  = { Name = "Sin Pasiva", Description = "" },
    Abilities = {},
})