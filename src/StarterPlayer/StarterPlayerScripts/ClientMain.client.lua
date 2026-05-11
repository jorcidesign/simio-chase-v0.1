-- src/StarterPlayer/StarterPlayerScripts/ClientMain.client.lua

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controllers = script.Parent:WaitForChild("Controllers")

local CharacterSelectionController  = require(Controllers:WaitForChild("CharacterSelectionController"))
local MatchUIController             = require(Controllers:WaitForChild("MatchUIController"))
local RespawnUIController           = require(Controllers:WaitForChild("RespawnUIController"))
local GameHUDController             = require(Controllers:WaitForChild("GameHUDController"))
local CharacterAnimationController  = require(Controllers:WaitForChild("CharacterAnimationController"))

print("🚀 Arrancando Cliente de Simio Chase v0.1...")

CharacterSelectionController.Start()
MatchUIController.Start()
GameHUDController.Start()
RespawnUIController.Start()
CharacterAnimationController.Start()  -- ✅ maneja cámara + animaciones de custom chars

print("✅ Cliente inicializado con éxito.")