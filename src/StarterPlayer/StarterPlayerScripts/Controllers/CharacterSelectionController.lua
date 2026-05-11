-- src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterSelectionController.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local ClientEventBus = require(script.Parent.Parent.Network.ClientEventBus)
local GameState = require(ReplicatedStorage.Enums.GameState)

local CharacterSelectionController = {}

-- Hardcodeamos el catálogo para la UI rápida (puedes leerlo dinámicamente luego)
local CATALOG = {
    { role = "Killer", id = "AUGUSTO" },
    { role = "Killer", id = "DANTE" },
    { role = "Killer", id = "EMANUEL" },
    { role = "Killer", id = "JALY" },
    { role = "Killer", id = "MIGUEL" },
    { role = "Killer", id = "PORO" },
    { role = "Survivor", id = "CACHETES" },
    { role = "Survivor", id = "GONZACARBON" },
    { role = "Survivor", id = "NARIZTOTELES" },
    { role = "Survivor", id = "RICALY" },
    { role = "Survivor", id = "SIU" },
    { role = "Survivor", id = "SURI" },
    { role = "Survivor", id = "VACUMING" },
}

local currentIndex = 1
local activeUI = nil

function CharacterSelectionController.Start()
    print("🖥️ [SelectionController] Listo para la fase de selección.")
    
    -- Escuchamos al servidor para saber cuándo abrir la UI
    ClientEventBus.MatchStateChanged:Connect(function(state)
        if state == GameState.SELECTING then
            CharacterSelectionController._showUI()
        elseif state == GameState.PLAYING then
            CharacterSelectionController._hideUI()
        end
    end)
end

function CharacterSelectionController._showUI()
    if activeUI then return end
    
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Fondo principal
    activeUI = Instance.new("ScreenGui", playerGui)
    activeUI.Name = "SelectionScreen"
    activeUI.IgnoreGuiInset = true
    
    local bg = Instance.new("Frame", activeUI)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    
    -- Nombre del Personaje
    local nameLabel = Instance.new("TextLabel", bg)
    nameLabel.Size = UDim2.new(1, 0, 0.2, 0)
    nameLabel.Position = UDim2.new(0, 0, 0.3, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextSize = 80
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    
    -- Rol del Personaje
    local roleLabel = Instance.new("TextLabel", bg)
    roleLabel.Size = UDim2.new(1, 0, 0.1, 0)
    roleLabel.Position = UDim2.new(0, 0, 0.5, 0)
    roleLabel.BackgroundTransparency = 1
    roleLabel.Font = Enum.Font.GothamMedium
    roleLabel.TextSize = 40
    roleLabel.TextColor3 = Color3.fromRGB(200, 50, 50)
    
    -- Función para actualizar los textos
    local function updateDisplay()
        local currentData = CATALOG[currentIndex]
        nameLabel.Text = currentData.id
        roleLabel.Text = currentData.role
        roleLabel.TextColor3 = (currentData.role == "Killer") and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 200, 255)
    end
    updateDisplay()
    
    -- Botón Izquierda (<)
    local leftBtn = Instance.new("TextButton", bg)
    leftBtn.Size = UDim2.new(0, 100, 0, 100)
    leftBtn.Position = UDim2.new(0.2, 0, 0.4, 0)
    leftBtn.Text = "<"
    leftBtn.TextSize = 80
    leftBtn.BackgroundTransparency = 1
    leftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    
    leftBtn.MouseButton1Click:Connect(function()
        currentIndex = (currentIndex - 2) % #CATALOG + 1
        updateDisplay()
    end)
    
    -- Botón Derecha (>)
    local rightBtn = Instance.new("TextButton", bg)
    rightBtn.Size = UDim2.new(0, 100, 0, 100)
    rightBtn.Position = UDim2.new(0.8, -100, 0.4, 0)
    rightBtn.Text = ">"
    rightBtn.TextSize = 80
    rightBtn.BackgroundTransparency = 1
    rightBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    
    rightBtn.MouseButton1Click:Connect(function()
        currentIndex = currentIndex % #CATALOG + 1
        updateDisplay()
    end)
    
    -- Botón Confirmar
    local confirmBtn = Instance.new("TextButton", bg)
    confirmBtn.Size = UDim2.new(0, 300, 0, 80)
    confirmBtn.Position = UDim2.new(0.5, -150, 0.7, 0)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    confirmBtn.Text = "CONFIRMAR SELECCIÓN"
    confirmBtn.Font = Enum.Font.GothamBold
    confirmBtn.TextSize = 25
    confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    
    confirmBtn.MouseButton1Click:Connect(function()
        local selected = CATALOG[currentIndex]
        RemoteRegistry.SelectCharacter:FireServer(selected.role, selected.id)
        confirmBtn.Text = "¡SELECCIONADO!"
        confirmBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    end)
end

function CharacterSelectionController._hideUI()
    if activeUI then
        activeUI:Destroy()
        activeUI = nil
    end
end

return CharacterSelectionController