-- =============================================================================
-- CharacterSelectionController.lua
-- =============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local ClientEventBus = require(script.Parent.Parent.Network.ClientEventBus)
local GameState = require(ReplicatedStorage.Enums.GameState)

local CharacterSelectionController = {}

local CATALOG = {
    Killers = {"AUGUSTO", "DANTE", "EMANUEL", "JALY", "MIGUEL", "PORO"},
    Survivors = {"CACHETES", "GONZACARBON", "NARIZTOTELES", "RICALY", "SIU", "SURI", "VACUMING"}
}

local activeUI = nil
local _myRole = nil
local _currentIndex = 1
local _takenSurvivors = {}
local _timeConn = nil -- Para limpiar el timer cuando se cierre la UI

-- Helper para limpiar conexiones locales
local function cleanupUI()
    if _timeConn then
        _timeConn:Disconnect()
        _timeConn = nil
    end
    if activeUI then
        activeUI:Destroy()
        activeUI = nil
    end
end

-- Renderiza un bloque de "Jugador + Personaje"
local function createPlayerCard(playerName, charId, parent, isKiller)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 180, 0, 50)
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    card.BorderColor3 = isKiller and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 255)
    card.BorderSizePixel = 1
    
    local lblName = Instance.new("TextLabel", card)
    lblName.Size = UDim2.new(1, 0, 0.5, 0)
    lblName.BackgroundTransparency = 1
    lblName.Text = playerName
    lblName.TextColor3 = Color3.fromRGB(180, 180, 180)
    lblName.Font = Enum.Font.Gotham
    lblName.TextSize = 12

    local lblChar = Instance.new("TextLabel", card)
    lblChar.Size = UDim2.new(1, 0, 0.5, 0)
    lblChar.Position = UDim2.new(0, 0, 0.5, 0)
    lblChar.BackgroundTransparency = 1
    lblChar.Text = charId
    lblChar.TextColor3 = Color3.fromRGB(255, 255, 255)
    lblChar.Font = Enum.Font.GothamBold
    lblChar.TextSize = 16

    card.Parent = parent
    return card
end

-- Construye la UI base
local function buildUI()
    cleanupUI()
    
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    activeUI = Instance.new("ScreenGui", playerGui)
    activeUI.Name = "SelectionScreen"
    activeUI.IgnoreGuiInset = true
    
    -- Fondo sutil para oscurecer la cámara
    local bg = Instance.new("Frame", activeUI)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
    bg.BackgroundTransparency = 0.5
    bg.BorderSizePixel = 0

    -- =========================================================================
    -- TIMER (Arriba, centrado)
    -- =========================================================================
    local timerLabel = Instance.new("TextLabel", activeUI)
    timerLabel.Name = "SelectionTimer"
    timerLabel.AnchorPoint = Vector2.new(0.5, 0)
    timerLabel.Position = UDim2.new(0.5, 0, 0, 24)
    timerLabel.Size = UDim2.new(0, 200, 0, 36)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font = Enum.Font.GothamBlack
    timerLabel.TextSize = 24
    timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timerLabel.Text = "// TIEMPO: --"
    
    -- Conectar el timer del servidor a esta etiqueta
    _timeConn = ClientEventBus.TimeUpdated:Connect(function(remaining)
        if timerLabel and timerLabel.Parent then
            timerLabel.Text = string.format("// TIEMPO: %02d", math.max(0, remaining))
            if remaining <= 5 then
                timerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            end
        end
    end)

    -- =========================================================================
    -- LISTA DE SURVIVORS (Top, debajo del timer)
    -- =========================================================================
    local survContainer = Instance.new("Frame", activeUI)
    survContainer.Name = "SurvivorsList"
    survContainer.Size = UDim2.new(0.9, 0, 0, 60)
    survContainer.AnchorPoint = Vector2.new(0.5, 0)
    survContainer.Position = UDim2.new(0.5, 0, 0, 80)
    survContainer.BackgroundTransparency = 1
    
    local listLayout = Instance.new("UIListLayout", survContainer)
    listLayout.FillDirection = Enum.FillDirection.Horizontal
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Padding = UDim.new(0, 15)

    -- =========================================================================
    -- CONTENEDOR DEL KILLER (Centro-Abajo, encima del slider)
    -- =========================================================================
    local killerContainer = Instance.new("Frame", activeUI)
    killerContainer.Name = "KillerList"
    killerContainer.Size = UDim2.new(1, 0, 0, 60)
    killerContainer.AnchorPoint = Vector2.new(0.5, 1)
    killerContainer.Position = UDim2.new(0.5, 0, 1, -180)
    killerContainer.BackgroundTransparency = 1

    -- =========================================================================
    -- CONTROLES DEL CAROUSEL (Abajo, usando AnchorPoint para no hundirse)
    -- =========================================================================
    local controlContainer = Instance.new("Frame", activeUI)
    controlContainer.AnchorPoint = Vector2.new(0.5, 1)
    controlContainer.Size = UDim2.new(0, 400, 0, 80)
    controlContainer.Position = UDim2.new(0.5, 0, 1, -80)
    controlContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    controlContainer.BorderSizePixel = 1
    controlContainer.BorderColor3 = Color3.fromRGB(255, 255, 255)

    local roleTitle = Instance.new("TextLabel", controlContainer)
    roleTitle.Size = UDim2.new(1, 0, 0, 20)
    roleTitle.Position = UDim2.new(0, 0, 0, -25)
    roleTitle.BackgroundTransparency = 1
    roleTitle.Font = Enum.Font.GothamBold
    roleTitle.TextColor3 = (_myRole == "Killer") and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 200, 255)
    roleTitle.Text = "ERES: " .. string.upper(_myRole)
    roleTitle.TextSize = 16

    local charName = Instance.new("TextLabel", controlContainer)
    charName.Name = "CharName"
    charName.Size = UDim2.new(1, 0, 1, 0)
    charName.BackgroundTransparency = 1
    charName.Font = Enum.Font.GothamBlack
    charName.TextColor3 = Color3.fromRGB(255, 255, 255)
    charName.TextSize = 35

    local btnLeft = Instance.new("TextButton", controlContainer)
    btnLeft.Size = UDim2.new(0, 50, 1, 0); btnLeft.Position = UDim2.new(0, 0, 0, 0)
    btnLeft.BackgroundTransparency = 1; btnLeft.Text = "<"; btnLeft.TextColor3 = Color3.fromRGB(255,255,255); btnLeft.TextSize = 30
    
    local btnRight = Instance.new("TextButton", controlContainer)
    btnRight.Size = UDim2.new(0, 50, 1, 0); btnRight.Position = UDim2.new(1, -50, 0, 0)
    btnRight.BackgroundTransparency = 1; btnRight.Text = ">"; btnRight.TextColor3 = Color3.fromRGB(255,255,255); btnRight.TextSize = 30

    -- =========================================================================
    -- BOTÓN CONFIRMAR (Pegado abajo)
    -- =========================================================================
    local btnConfirm = Instance.new("TextButton", activeUI)
    btnConfirm.AnchorPoint = Vector2.new(0.5, 1)
    btnConfirm.Size = UDim2.new(0, 400, 0, 40)
    btnConfirm.Position = UDim2.new(0.5, 0, 1, -25)
    btnConfirm.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btnConfirm.Text = "CONFIRMAR"
    btnConfirm.Font = Enum.Font.GothamBold
    btnConfirm.TextColor3 = Color3.fromRGB(0, 0, 0)
    btnConfirm.TextSize = 18

    -- Lógica del carrusel
    local roster = (_myRole == "Killer") and CATALOG.Killers or CATALOG.Survivors
    
    local function updateSlider()
        local currentId = roster[_currentIndex]
        charName.Text = currentId
        
        if _myRole == "Survivor" and _takenSurvivors[currentId] then
            charName.TextColor3 = Color3.fromRGB(100, 100, 100)
            btnConfirm.Text = "// NO DISPONIBLE"
            btnConfirm.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            btnConfirm.AutoButtonColor = false
        else
            charName.TextColor3 = Color3.fromRGB(255, 255, 255)
            btnConfirm.Text = "CONFIRMAR"
            btnConfirm.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            btnConfirm.AutoButtonColor = true
        end
    end

    btnLeft.MouseButton1Click:Connect(function()
        _currentIndex = (_currentIndex - 2) % #roster + 1
        updateSlider()
    end)
    btnRight.MouseButton1Click:Connect(function()
        _currentIndex = _currentIndex % #roster + 1
        updateSlider()
    end)

    btnConfirm.MouseButton1Click:Connect(function()
        local currentId = roster[_currentIndex]
        if _myRole == "Survivor" and _takenSurvivors[currentId] then return end 
        
        RemoteRegistry.SelectCharacter:FireServer(_myRole, currentId)
    end)

    updateSlider()
end

function CharacterSelectionController.Start()
    print("🖥️ [SelectionController] Listo.")
    
    RemoteRegistry.StartSelectionPhase.OnClientEvent:Connect(function(role)
        _myRole = role
        _currentIndex = 1
        table.clear(_takenSurvivors)
        buildUI()
    end)

    RemoteRegistry.SyncSelectionList.OnClientEvent:Connect(function(syncData)
        if not activeUI then return end
        
        local survContainer = activeUI:FindFirstChild("SurvivorsList")
        local killerContainer = activeUI:FindFirstChild("KillerList")
        if not survContainer or not killerContainer then return end

        for _, child in ipairs(survContainer:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        for _, child in ipairs(killerContainer:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        table.clear(_takenSurvivors)

        for _, data in ipairs(syncData) do
            if data.role == "Survivor" then
                _takenSurvivors[data.characterId] = true
                createPlayerCard(data.playerName, data.characterId, survContainer, false)
            elseif data.role == "Killer" then
                local card = createPlayerCard(data.playerName, data.characterId, killerContainer, true)
                card.AnchorPoint = Vector2.new(0.5, 0)
                card.Position = UDim2.new(0.5, 0, 0, 0)
            end
        end

        local btnRight = activeUI:FindFirstChild("CharName", true)
        if btnRight then
            _currentIndex = _currentIndex % ((_myRole == "Killer") and #CATALOG.Killers or #CATALOG.Survivors) + 1
            _currentIndex = (_currentIndex - 2) % ((_myRole == "Killer") and #CATALOG.Killers or #CATALOG.Survivors) + 1
        end
    end)

    ClientEventBus.MatchStateChanged:Connect(function(state)
        if state == GameState.PLAYING then
            cleanupUI()
        end
    end)
end

return CharacterSelectionController