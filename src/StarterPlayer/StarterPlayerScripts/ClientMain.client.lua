-- =============================================================================
-- ClientMain.client.lua
-- Ubicación: src/StarterPlayer/StarterPlayerScripts/ClientMain.client.lua
--
-- SPRINT 2 — Adiciones:
--   + OvertimeHUDController: muestra el timer de escape de 20s.
-- =============================================================================

local Controllers = script.Parent:WaitForChild("Controllers")

local CharacterSelectionController  = require(Controllers:WaitForChild("CharacterSelectionController"))
local SelectionWorldController      = require(Controllers:WaitForChild("SelectionWorldController"))
local MatchIntroController          = require(Controllers:WaitForChild("MatchIntroController"))
local MatchUIController             = require(Controllers:WaitForChild("MatchUIController"))
local RespawnUIController           = require(Controllers:WaitForChild("RespawnUIController"))
local GameHUDController             = require(Controllers:WaitForChild("GameHUDController"))
local CharacterAnimationController  = require(Controllers:WaitForChild("CharacterAnimationController"))
local InputController               = require(Controllers:WaitForChild("InputController"))
local StaminaController             = require(Controllers:WaitForChild("StaminaController"))
local CameraController              = require(Controllers:WaitForChild("CameraController"))
local SkillHUDController            = require(Controllers:WaitForChild("SkillHUDController"))
local OvertimeHUDController         = require(Controllers:WaitForChild("OvertimeHUDController")) -- ✅ NUEVO

print("🚀 [ClientMain] Arrancando Cliente de Simio Chase...")

-- Orden de arranque: cámara primero para evitar flash de posición incorrecta
CameraController.Start()

CharacterSelectionController.Start()
SelectionWorldController.Start()
MatchIntroController.Start()
MatchUIController.Start()
GameHUDController.Start()
RespawnUIController.Start()
OvertimeHUDController.Start()   -- ✅ NUEVO: antes que InputController y Skill HUD

-- AnimController antes que InputController: Tracks ya definidos
CharacterAnimationController.Start()
InputController.Start()
StaminaController.Start()
SkillHUDController.Start()

-- ── Puentes de señal (evitan import circular entre controladores) ─────────────

-- Sprint: InputController → StaminaController
InputController.OnSprintChanged = function(active: boolean)
    StaminaController.setSprint(active)
end

-- Habilidades: InputController → SkillHUDController (feedback optimista)
InputController.OnSkillCasted = function(keyName: string, cooldown: number)
    SkillHUDController.onSkillCastedLocally(keyName, cooldown)
end

print("✅ [ClientMain] Cliente inicializado con éxito.")