-- src/StarterPlayer/StarterPlayerScripts/ClientMain.client.lua
local Controllers = script.Parent:WaitForChild("Controllers")
local MatchUIController = require(Controllers:WaitForChild("MatchUIController"))
local RespawnUIController = require(Controllers:WaitForChild("RespawnUIController"))


print("🚀 Arrancando Cliente de Simio Chase v0.1...")

-- Iniciamos los controladores
MatchUIController.Start()
RespawnUIController.Start()
print("✅ Cliente inicializado con éxito.")