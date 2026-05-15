-- =============================================================================
-- CharacterAnimationController.lua
-- Ubicación: src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterAnimationController.lua
--
-- VERSIÓN DUMMY: Las animaciones han sido desactivadas intencionalmente.
-- Este controlador expone la API necesaria para que InputController y
-- el servidor no crasheen al intentar reproducir animaciones.
-- =============================================================================

local CharacterAnimationController = {}

-- Tracks públicos (vacíos para evitar errores de indexación en otros scripts)
CharacterAnimationController.Tracks = {}

--- Fake API para reproducir una animación de habilidad
function CharacterAnimationController.playSkillAnim(slotName: string, fadeIn: number?)
	-- print("🎬 [AnimController] Animaciones desactivadas. Ignorando play: " .. tostring(slotName))
end

--- Fake API para detener una animación de habilidad
function CharacterAnimationController.stopSkillAnim(slotName: string, fadeOut: number?)
	-- print("🎬 [AnimController] Animaciones desactivadas. Ignorando stop: " .. tostring(slotName))
end

-- =============================================================================
-- Start — punto de entrada
-- =============================================================================
function CharacterAnimationController.Start()
	print("🎬 [AnimController] Iniciado en modo DUMMY (Animaciones Desactivadas).")
	
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

	-- El servidor envía SetupCharacter cuando el personaje está listo.
	-- Lo escuchamos para que la red no de warnings de "unhandled remote", pero no hacemos nada.
	RemoteRegistry.SetupCharacter.OnClientEvent:Connect(function()
		local player = Players.LocalPlayer
		local character = player.Character or player.CharacterAdded:Wait()
		
		-- Solo asignamos la cámara al nuevo personaje (obligatorio para jugar)
		local humanoid = character:WaitForChild("Humanoid", 5)
		local camera = workspace.CurrentCamera
		if humanoid and camera then
			camera.CameraSubject = humanoid
			camera.CameraType = Enum.CameraType.Custom
		end
	end)

	-- El servidor ordena detener animaciones
	RemoteRegistry.SkillAnimStop.OnClientEvent:Connect(function(slotName: string)
		-- Ignorado
	end)
end

return CharacterAnimationController