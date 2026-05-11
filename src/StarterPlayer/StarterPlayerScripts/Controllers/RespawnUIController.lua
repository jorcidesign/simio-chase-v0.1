-- src/StarterPlayer/StarterPlayerScripts/Controllers/RespawnUIController.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local RespawnUIController = {}
local activeUI = nil
local countdownConnection = nil

function RespawnUIController.Start()
    print("🖥️ [RespawnUIController] Listo para mostrar menú de muerte.")
    
    RemoteRegistry.ShowRespawnMenu.OnClientEvent:Connect(function(timeLimit)
        RespawnUIController._showUI(timeLimit)
    end)
end

function RespawnUIController._showUI(timeLimit: number)
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Destruimos la anterior si por algún bug se duplicó
    if activeUI then activeUI:Destroy() end
    
    -- 1. Crear el GUI (Fondo negro semi-transparente)
    activeUI = Instance.new("ScreenGui")
    activeUI.Name = "RespawnMenu"
    activeUI.IgnoreGuiInset = true
    activeUI.Parent = playerGui
    
    local background = Instance.new("Frame", activeUI)
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    background.BackgroundTransparency = 0.5
    
    -- 2. Título de Muerte
    local title = Instance.new("TextLabel", background)
    title.Size = UDim2.new(1, 0, 0.3, 0)
    title.Position = UDim2.new(0, 0, 0.2, 0)
    title.BackgroundTransparency = 1
    title.Text = "HAS MUERTO"
    title.TextColor3 = Color3.fromRGB(255, 50, 50)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 60
    
    -- 3. Botón de Revivir
    local respawnBtn = Instance.new("TextButton", background)
    respawnBtn.Size = UDim2.new(0, 300, 0, 60)
    respawnBtn.Position = UDim2.new(0.5, -150, 0.6, 0)
    respawnBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    respawnBtn.Text = "VOLVER A JUGAR"
    respawnBtn.Font = Enum.Font.GothamBold
    respawnBtn.TextSize = 25
    
    -- 4. Texto del Contador
    local timerText = Instance.new("TextLabel", background)
    timerText.Size = UDim2.new(1, 0, 0.1, 0)
    timerText.Position = UDim2.new(0, 0, 0.75, 0)
    timerText.BackgroundTransparency = 1
    timerText.TextColor3 = Color3.fromRGB(200, 200, 200)
    timerText.Font = Enum.Font.GothamMedium
    timerText.TextSize = 20
    
    -- 5. Lógica del Botón
    respawnBtn.MouseButton1Click:Connect(function()
        RemoteRegistry.RequestRespawn:FireServer()
        RespawnUIController._cleanup()
    end)
    
    -- 6. Bucle del Contador (Usando Heartbeat para mejor rendimiento que un while wait)
    local startTime = os.clock()
    countdownConnection = RunService.Heartbeat:Connect(function()
        local elapsed = os.clock() - startTime
        local remaining = math.max(0, math.ceil(timeLimit - elapsed))
        timerText.Text = "Serás expulsado en: " .. remaining .. "s"
        
        if remaining <= 0 then
            RespawnUIController._cleanup()
        end
    end)
end

function RespawnUIController._cleanup()
    if countdownConnection then
        countdownConnection:Disconnect()
        countdownConnection = nil
    end
    if activeUI then
        activeUI:Destroy()
        activeUI = nil
    end
end

return RespawnUIController