-- src/ServerScriptService/ServerMain.server.lua
local Services = script.Parent.Services

local TimeManagerService = require(Services.TimeManagerService)
local MatchManagerService = require(Services.MatchManagerService)

print("🚀 Arrancando Servidor de Simio Chase v0.1...")

-- Iniciamos los servicios (el orden importa si uno depende del otro)
TimeManagerService.Start()
MatchManagerService.Start()

print("✅ Servidor inicializado con éxito.")