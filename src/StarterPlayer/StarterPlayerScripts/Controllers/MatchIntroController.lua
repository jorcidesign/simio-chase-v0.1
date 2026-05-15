-- =============================================================================
-- MatchIntroController.lua
-- =============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local ClientEventBus = require(script.Parent.Parent.Network.ClientEventBus)
local GameState = require(ReplicatedStorage.Enums.GameState)

local MatchIntroController = {}
local activeUI = nil

local function destroyUI()
    if activeUI then
        -- Fade Out suave
        local bg = activeUI:FindFirstChild("Background")
        if bg then
            local tween = TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1})
            tween:Play()
            tween.Completed:Wait()
        end
        activeUI:Destroy()
        activeUI = nil
    end
end

local function buildUI(data)
    if activeUI then activeUI:Destroy() end

    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    activeUI = Instance.new("ScreenGui", playerGui)
    activeUI.Name = "MatchIntro"
    activeUI.IgnoreGuiInset = true
    activeUI.DisplayOrder = 100 -- Superpone TODO, incluyendo el HUD y el menú

    local bg = Instance.new("Frame", activeUI)
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(10, 10, 12) -- Negro mate japonés
    bg.BackgroundTransparency = 1 -- Empieza invisible para el Fade In
    bg.BorderSizePixel = 0

    TweenService:Create(bg, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()

    -- TEXTO DE SISTEMA ARRIBA
    local systemLabel = Instance.new("TextLabel", bg)
    systemLabel.Size = UDim2.new(1, -60, 0, 30)
    systemLabel.Position = UDim2.new(0, 30, 0, 30)
    systemLabel.BackgroundTransparency = 1
    systemLabel.Text = "// CARGANDO DATOS DEL SISTEMA..."
    systemLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    systemLabel.Font = Enum.Font.GothamMedium
    systemLabel.TextSize = 14
    systemLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- CONTENEDOR PRINCIPAL
    local content = Instance.new("Frame", bg)
    content.Size = UDim2.new(0, 600, 0, 400)
    content.AnchorPoint = Vector2.new(0.5, 0.5)
    content.Position = UDim2.new(0.5, 0, 0.5, 0)
    content.BackgroundTransparency = 1

    -- KILLER (CAZADOR)
    local killerTitle = Instance.new("TextLabel", content)
    killerTitle.Size = UDim2.new(1, 0, 0, 20)
    killerTitle.Position = UDim2.new(0, 0, 0, 0)
    killerTitle.BackgroundTransparency = 1
    killerTitle.Text = "[ CAZADOR ]"
    killerTitle.TextColor3 = Color3.fromRGB(255, 60, 60)
    killerTitle.Font = Enum.Font.GothamBold
    killerTitle.TextSize = 16
    killerTitle.TextXAlignment = Enum.TextXAlignment.Left

    if data.killer then
        local kName = Instance.new("TextLabel", content)
        kName.Size = UDim2.new(1, 0, 0, 40)
        kName.Position = UDim2.new(0, 0, 0, 25)
        kName.BackgroundTransparency = 1
        kName.Text = string.format("%s   //   %s", string.upper(data.killer.name), data.killer.charId)
        kName.TextColor3 = Color3.fromRGB(255, 255, 255)
        kName.Font = Enum.Font.GothamBlack
        kName.TextSize = 28
        kName.TextXAlignment = Enum.TextXAlignment.Left
    end

    -- SEPARADOR
    local sep = Instance.new("Frame", content)
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.Position = UDim2.new(0, 0, 0, 90)
    sep.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    sep.BorderSizePixel = 0

    -- SUPERVIVIENTES (PRESAS)
    local survTitle = Instance.new("TextLabel", content)
    survTitle.Size = UDim2.new(1, 0, 0, 20)
    survTitle.Position = UDim2.new(0, 0, 0, 120)
    survTitle.BackgroundTransparency = 1
    survTitle.Text = "[ PRESAS ]"
    survTitle.TextColor3 = Color3.fromRGB(150, 150, 150)
    survTitle.Font = Enum.Font.GothamBold
    survTitle.TextSize = 16
    survTitle.TextXAlignment = Enum.TextXAlignment.Left

    local yOffset = 150
    for _, surv in ipairs(data.survivors) do
        local sName = Instance.new("TextLabel", content)
        sName.Size = UDim2.new(1, 0, 0, 25)
        sName.Position = UDim2.new(0, 0, 0, yOffset)
        sName.BackgroundTransparency = 1
        sName.Text = string.format("%s   //   %s", string.upper(surv.name), surv.charId)
        sName.TextColor3 = Color3.fromRGB(200, 200, 200)
        sName.Font = Enum.Font.Gotham
        sName.TextSize = 18
        sName.TextXAlignment = Enum.TextXAlignment.Left
        yOffset += 30
    end

    -- MAPA (Esquina inferior derecha)
    local mapLabel = Instance.new("TextLabel", bg)
    mapLabel.Size = UDim2.new(1, -30, 0, 30)
    mapLabel.AnchorPoint = Vector2.new(1, 1)
    mapLabel.Position = UDim2.new(1, 0, 1, -30)
    mapLabel.BackgroundTransparency = 1
    mapLabel.Text = string.format("// ZONA: %s", string.upper(data.map))
    mapLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
    mapLabel.Font = Enum.Font.GothamBold
    mapLabel.TextSize = 18
    mapLabel.TextXAlignment = Enum.TextXAlignment.Right
end

function MatchIntroController.Start()
    print("🖥️ [MatchIntroController] Iniciado.")

    RemoteRegistry.ShowMatchIntro.OnClientEvent:Connect(function(data)
        buildUI(data)
    end)

    ClientEventBus.MatchStateChanged:Connect(function(newState)
        if newState == GameState.PLAYING then
            -- Para evitar que se quede pegado si un error ocurre, usamos task.spawn
            task.spawn(destroyUI)
        end
    end)
end

return MatchIntroController