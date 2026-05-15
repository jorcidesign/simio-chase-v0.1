-- =============================================================================
-- MatchUIController.lua
-- =============================================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local MatchUIController = {}

local function createOverlay(name, color, zIndex)
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("EffectsUI") or Instance.new("ScreenGui")
    screenGui.Name = "EffectsUI"
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = color
    frame.BackgroundTransparency = 1
    frame.ZIndex = zIndex
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    return frame
end

function MatchUIController.Start()
    print("🖥️ [MatchUIController] Iniciado en el Cliente.")
    
    local damageFrame = createOverlay("DamageOverlay", Color3.fromRGB(255, 0, 0), 1)
    local blindFrame  = createOverlay("BlindOverlay", Color3.fromRGB(0, 0, 0), 5)
    local mudFrame    = createOverlay("MudOverlay", Color3.fromRGB(101, 67, 33), 4)
    local hackFrame   = createOverlay("HackOverlay", Color3.fromRGB(255, 255, 0), 6)

    -- 🩸 EFECTO DAÑO
    RemoteRegistry.DamageEffect.OnClientEvent:Connect(function()
        local tIn = TweenService:Create(damageFrame, TweenInfo.new(0.1), {BackgroundTransparency = 0.5})
        local tOut = TweenService:Create(damageFrame, TweenInfo.new(0.4), {BackgroundTransparency = 1})
        tIn:Play()
        tIn.Completed:Wait()
        tOut:Play()
    end)

    -- 🦇 CEGUERA (Gonzacarbon)
    RemoteRegistry.BlindKiller.OnClientEvent:Connect(function(duration)
        TweenService:Create(blindFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
        task.delay(duration, function()
            TweenService:Create(blindFrame, TweenInfo.new(1), {BackgroundTransparency = 1}):Play()
        end)
    end)

    -- 💩 PANTALLA DE BARRO (Augusto)
    RemoteRegistry.MudScreen.OnClientEvent:Connect(function(duration)
        TweenService:Create(mudFrame, TweenInfo.new(0.1), {BackgroundTransparency = 0.2}):Play()
        task.delay(duration, function()
            TweenService:Create(mudFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        end)
    end)

    -- 💻 POPUP HACK (Dante)
    RemoteRegistry.PopupHack.OnClientEvent:Connect(function(duration)
        local elapsed = 0
        local hackConn
        hackConn = game:GetService("RunService").RenderStepped:Connect(function(dt)
            elapsed += dt
            if elapsed >= duration then
                hackConn:Disconnect()
                hackFrame.BackgroundTransparency = 1
                return
            end
            -- Efecto estática/parpadeo rápido
            hackFrame.BackgroundTransparency = math.random(30, 90) / 100
        end)
    end)
end

return MatchUIController