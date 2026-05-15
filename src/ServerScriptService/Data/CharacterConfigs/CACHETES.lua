local CharacterModel = require(game.ReplicatedStorage.Models.CharacterModel)
return CharacterModel.newSurvivor({
    Name        = "Cachetes",
    Description = "Superviviente resistente",
    WalkSpeed   = 14, RunSpeed = 22, BaseStamina = 60,
    Passive  = { Name = "Sin Pasiva", Description = "" },
    Abilities = {},
})