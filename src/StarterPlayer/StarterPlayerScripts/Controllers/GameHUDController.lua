-- =============================================================================
-- GameHUDController.lua
-- Ubicación: src/StarterPlayer/StarterPlayerScripts/Controllers/GameHUDController.lua
--
-- SPRINT 2 — Adiciones:
--   + buildUI acepta GameState.ESCAPE y muestra "// ESCAPA AHORA" con acento dorado.
--   + Urgencia visual a ≤ 30s también aplica en LAST_MAN.
--   + Destruye la UI al entrar en LOADING (durante la intro de partida).
-- =============================================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientEventBus = require(script.Parent.Parent.Network.ClientEventBus)
local GameState      = require(ReplicatedStorage.Enums.GameState)
local GameConstants  = require(ReplicatedStorage.GameConstants)

local GameHUDController = {}

local activeUI: ScreenGui? = nil
local _uiConnections: { RBXScriptConnection } = {}

-- =============================================================================
-- Helper: formato MM:SS
-- =============================================================================
local function formatTime(seconds: number): string
    seconds = math.max(0, math.floor(seconds))
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%02d:%02d", m, s)
end

-- =============================================================================
-- Destruir UI y limpiar conexiones
-- =============================================================================
local function destroyUI()
    for _, conn in ipairs(_uiConnections) do
        conn:Disconnect()
    end
    table.clear(_uiConnections)

    if activeUI then
        activeUI:Destroy()
        activeUI = nil
    end
end

-- =============================================================================
-- Construir UI para un estado dado
-- =============================================================================
local function buildUI(state: string)
    destroyUI()

    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    local newGui = Instance.new("ScreenGui")
    newGui.Name          = "GameHUD"
    newGui.IgnoreGuiInset = true
    newGui.ResetOnSpawn  = false
    newGui.Parent        = playerGui
    activeUI = newGui

    -- ── Contenedor central superior ──────────────────────────────────────────
    local container = Instance.new("Frame")
    container.Name          = "HUDContainer"
    container.AnchorPoint   = Vector2.new(0.5, 0)
    container.Position      = UDim2.new(0.5, 0, 0, 24)
    container.Size          = UDim2.new(0, 340, 0, 36)
    container.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    container.BackgroundTransparency = 0.4
    container.BorderSizePixel = 0
    container.Parent        = newGui

    local stroke = Instance.new("UIStroke")
    stroke.Color       = Color3.fromRGB(255, 255, 255)
    stroke.Thickness   = 1
    stroke.Transparency = 0.8
    stroke.Parent      = container

    local accent = Instance.new("Frame")
    accent.Name           = "AccentLine"
    accent.Size           = UDim2.new(0, 3, 1, 0)
    accent.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    accent.BorderSizePixel = 0
    accent.Parent         = container

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name            = "StatusLabel"
    statusLabel.Size            = UDim2.new(0.7, -20, 1, 0)
    statusLabel.Position        = UDim2.new(0, 16, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font            = Enum.Font.GothamMedium
    statusLabel.TextSize        = 13
    statusLabel.TextXAlignment  = Enum.TextXAlignment.Left
    statusLabel.TextColor3      = Color3.fromRGB(240, 240, 240)
    statusLabel.Parent          = container

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name             = "TimerLabel"
    timerLabel.Size             = UDim2.new(0.3, -12, 1, 0)
    timerLabel.Position         = UDim2.new(0.7, 0, 0, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font             = Enum.Font.GothamBlack
    timerLabel.TextSize         = 18
    timerLabel.TextXAlignment   = Enum.TextXAlignment.Right
    timerLabel.TextColor3       = Color3.fromRGB(255, 255, 255)
    timerLabel.Text             = "--:--"
    timerLabel.Parent           = container

    -- ── Estados visuales ─────────────────────────────────────────────────────
    if state == GameState.WAITING then
        accent.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
        timerLabel.TextColor3   = Color3.fromRGB(100, 100, 100)

        local function updateWaitingText()
            if not statusLabel.Parent then return end
            local curr = #Players:GetPlayers()
            local need = GameConstants.Match.MIN_PLAYERS
            local max_ = GameConstants.Match.MAX_PLAYERS
            if curr < need then
                accent.BackgroundColor3 = Color3.fromRGB(255, 120, 50)
                statusLabel.Text = string.format("// ESPERANDO JUGADORES  %d / %d", curr, max_)
            else
                accent.BackgroundColor3 = Color3.fromRGB(100, 255, 120)
                statusLabel.Text = string.format("// JUGADORES LISTOS  %d / %d", curr, max_)
            end
        end

        updateWaitingText()
        table.insert(_uiConnections, Players.PlayerAdded:Connect(updateWaitingText))
        table.insert(_uiConnections, Players.PlayerRemoving:Connect(function()
            task.defer(updateWaitingText)
        end))

    elseif state == GameState.LOBBY then
        accent.BackgroundColor3 = Color3.fromRGB(100, 255, 120)
        statusLabel.Text        = "// LA PARTIDA INICIA EN"
        timerLabel.TextColor3   = Color3.fromRGB(100, 255, 120)

    elseif state == GameState.PLAYING then
        accent.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        statusLabel.Text        = "// SOBREVIVE"
        timerLabel.TextColor3   = Color3.fromRGB(255, 220, 80)

    elseif state == GameState.LAST_MAN then
        accent.BackgroundColor3 = Color3.fromRGB(255, 160, 30)
        statusLabel.Text        = "// ÚLTIMO EN PIE"
        timerLabel.TextColor3   = Color3.fromRGB(255, 160, 30)

    elseif state == GameState.ESCAPE then
        -- Durante ESCAPE el timer del HUD principal ya no actualiza
        -- (el OvertimeHUDController tiene su propio timer).
        -- Mostramos un estado fijo de "escape abierto".
        accent.BackgroundColor3 = Color3.fromRGB(255, 220, 0)
        statusLabel.Text        = "// ESCAPA AHORA"
        timerLabel.Text         = "---"
        timerLabel.TextColor3   = Color3.fromRGB(255, 220, 0)
    end

    -- ── Timer del servidor → actualizar timerLabel ────────────────────────────
    -- Solo aplica en PLAYING y LAST_MAN (en ESCAPE el overtime HUD toma el control)
    if state == GameState.PLAYING or state == GameState.LAST_MAN or state == GameState.LOBBY then
        local timerConn = ClientEventBus.TimeUpdated:Connect(function(remaining: number)
            if not timerLabel.Parent then return end
            timerLabel.Text = formatTime(remaining)

            -- Urgencia: rojo en ≤30s
            if remaining <= 30 then
                timerLabel.TextColor3   = Color3.fromRGB(255, 60, 60)
                accent.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
            end
        end)
        table.insert(_uiConnections, timerConn)
    end
end

-- =============================================================================
-- Start
-- =============================================================================
function GameHUDController.Start()
    print("🖥️ [GameHUDController] Iniciado.")

    ClientEventBus.MatchStateChanged:Connect(function(newState: string)
        if newState == GameState.WAITING
        or newState == GameState.LOBBY
        or newState == GameState.PLAYING
        or newState == GameState.LAST_MAN
        or newState == GameState.ESCAPE then
            buildUI(newState)
        else
            -- LOADING, SELECTING, ENDING, INTERMISSION → limpiar HUD
            destroyUI()
        end
    end)

    -- Mostrar HUD de WAITING al arrancar
    buildUI(GameState.WAITING)
end

return GameHUDController