-- src/StarterPlayer/StarterPlayerScripts/Controllers/MatchUIController.lua
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Importamos el puente de red
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local MatchUIController = {}

function MatchUIController.Start()
    print("🖥️ [MatchUIController] Iniciado en el Cliente.")
    
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- 1. Creamos la UI de daño programáticamente
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DamageUI"
    screenGui.IgnoreGuiInset = true -- Ignora el menú de Roblox para cubrir toda la pantalla
    screenGui.Parent = playerGui
    
    local damageFrame = Instance.new("Frame")
    damageFrame.Size = UDim2.new(1, 0, 1, 0)
    damageFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Rojo sangre
    damageFrame.BackgroundTransparency = 1 -- 100% invisible por defecto
    damageFrame.Parent = screenGui
    
    -- 2. Escuchamos el grito del Servidor
    RemoteRegistry.DamageEffect.OnClientEvent:Connect(function()
        -- Animación fluida (Tween) para que parpadee
        local tweenIn = TweenService:Create(damageFrame, TweenInfo.new(0.1), {BackgroundTransparency = 0.5})
        local tweenOut = TweenService:Create(damageFrame, TweenInfo.new(0.4), {BackgroundTransparency = 1})
        
        tweenIn:Play()
        tweenIn.Completed:Wait() -- Esperamos que termine de ponerse rojo
        tweenOut:Play() -- Lo volvemos invisible
    end)
end

return MatchUIController