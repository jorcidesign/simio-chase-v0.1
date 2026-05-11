-- =============================================================================
-- ServerMain.server.lua
-- Ubicación: src/ServerScriptService/ServerMain.server.lua
--
-- Punto de entrada del servidor. Inicia todos los servicios en el orden
-- correcto según su grafo de dependencias.
--
-- Orden de arranque (de menor a mayor dependencia):
--   1. TimeManagerService    → solo depende de ServerEventBus
--   2. WorldService          → solo depende de GameConstants
--   3. RespawnManagerService → depende de ServerEventBus, WorldService, RemoteRegistry
--   4. SkillManagerService   → depende de DamageSystem, StatusEffectSystem, CharacterRegistry
--   5. MatchManagerService   → depende de todos los anteriores (vía bus)
--                              SE INICIA AL FINAL porque dispara el primer
--                              MatchStateChanged que los otros servicios deben
--                              estar listos para escuchar.
--
-- Regla: ningún servicio hace require() de otro servicio en top-level.
-- La comunicación entre servicios pasa por ServerEventBus.
-- =============================================================================

local Services = script.Parent.Services

local TimeManagerService    = require(Services.TimeManagerService)
local WorldService          = require(Services.WorldService)
local RespawnManagerService = require(Services.RespawnManagerService)
local SkillManagerService   = require(Services.SkillManagerService)
local MatchManagerService   = require(Services.MatchManagerService)

print("🚀 Arrancando Servidor de Simio Chase...")

-- 1. Servicios sin dependencias entre sí — orden no importa aquí
TimeManagerService.Start()
WorldService.Start()

-- 2. Servicios que escuchan el bus — deben estar listos ANTES de que
--    MatchManagerService dispare su primer evento.
RespawnManagerService.Start()
SkillManagerService.Start()

-- 3. MatchManagerService AL FINAL — su Start() dispara onEnter(WAITING)
--    que a su vez puede disparar MatchStateChanged si hay suficientes jugadores.
--    En ese momento, RespawnManagerService ya está suscrito y listo.
MatchManagerService.Start()

print("✅ Servidor inicializado. Simio Chase en espera de jugadores.")