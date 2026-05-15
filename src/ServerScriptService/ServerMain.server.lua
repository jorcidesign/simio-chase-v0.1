-- =============================================================================
-- ServerMain.server.lua
-- =============================================================================
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.Services
local Systems  = ServerScriptService.Systems

local PlayerDataService         = require(Services.PlayerDataService)
local TimeManagerService        = require(Services.TimeManagerService)
local WorldService              = require(Services.WorldService)
local RespawnManagerService     = require(Services.RespawnManagerService)
local CombatService             = require(Services.CombatService)
local SkillManagerService       = require(Services.SkillManagerService)
local CharacterSelectionService = require(Services.CharacterSelectionService) -- ✅ NUEVO
local MatchManagerService       = require(Services.MatchManagerService)
local RagdollSystem             = require(Systems.RagdollSystem)

print("🚀 [ServerMain] Arrancando Servidor de Simio Chase...")

PlayerDataService.Start()
TimeManagerService.Start()
WorldService.Start()
RespawnManagerService.Start()
CombatService.Start()
SkillManagerService.Start()

CharacterSelectionService.Start() -- ✅ INICIAR ANTES DEL MATCH MANAGER

MatchManagerService.Start()

RagdollSystem.Start()

print("✅ [ServerMain] Servidor inicializado. Simio Chase en espera de jugadores.")