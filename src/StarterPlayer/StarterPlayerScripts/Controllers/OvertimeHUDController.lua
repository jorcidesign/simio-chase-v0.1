-- =============================================================================
-- OvertimeHUDController.lua
-- Ubicación: src/StarterPlayer/StarterPlayerScripts/Controllers/OvertimeHUDController.lua
--
-- NUEVO — Sprint 2.
--
-- Responsabilidades (SRP):
--   1. Escuchar OvertimeStarted → mostrar UI de overtime con timer de 20s.
--   2. Escuchar EscapeTimerTick → actualizar el countdown en pantalla.
--   3. Escuchar EscapeSuccess    → mostrar mensaje de éxito al propio jugador.
--   4. Destruir la UI al entrar en ENDING o WAITING.
--
-- Diseño visual:
--   - Barra horizontal centrada en la parte inferior superior de la pantalla.
--   - Color de acento: dorado/naranja para transmitir urgencia de escape.
--   - Texto principal: "// ESCAPA AHORA" con timer regresivo.
--   - Si el jugador escapa: overlay de "¡ESCAPASTE!" con fade out.
--
-- Sin dependencias de animaciones ni sonidos.
-- =============================================================================

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local ClientEventBus = require(script.Parent.Parent.Network.ClientEventBus)
local GameState      = require(ReplicatedStorage.Enums.GameState)

local OvertimeHUDController = {}

-- =============================================================================
-- Estado interno
-- =============================================================================

local _screenGui: ScreenGui? = nil
local _timerLabel: TextLabel? = nil
local _connections: { RBXScriptConnection } = {}

-- =============================================================================
-- Helpers
-- =============================================================================

local function destroyUI()
    for _, conn in ipairs(_connections) do
        conn:Disconnect()
    end
    table.clear(_connections)

    if _screenGui then
        _screenGui:Destroy()
        _screenGui = nil
    end
    _timerLabel = nil
end

local function buildOvertimeUI()
    destroyUI()

    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    local newGui = Instance.new("ScreenGui")
    newGui.Name          = "OvertimeHUD"
    newGui.IgnoreGuiInset = true
    newGui.ResetOnSpawn  = false
    newGui.DisplayOrder  = 10
    newGui.Parent        = playerGui
    _screenGui = newGui

    -- ── Banner superior de overtime ──────────────────────────────────────────
    local banner = Instance.new("Frame")
    banner.Name             = "OvertimeBanner"
    banner.AnchorPoint      = Vector2.new(0.5, 0)
    banner.Position         = UDim2.new(0.5, 0, 0, 70)   -- debajo del HUD normal
    banner.Size             = UDim2.new(0, 420, 0, 44)
    banner.BackgroundColor3 = Color3.fromRGB(12, 10, 5)
    banner.BackgroundTransparency = 0.25
    banner.BorderSizePixel  = 0
    banner.Parent           = newGui

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(255, 200, 30)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.1
    stroke.Parent    = banner

    -- Acento lateral dorado
    local accent = Instance.new("Frame")
    accent.Size             = UDim2.new(0, 4, 1, 0)
    accent.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
    accent.BorderSizePixel  = 0
    accent.Parent           = banner

    -- Texto de estado
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size             = UDim2.new(0.62, -16, 1, 0)
    statusLabel.Position         = UDim2.new(0, 16, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font             = Enum.Font.GothamBold
    statusLabel.TextSize         = 14
    statusLabel.TextXAlignment   = Enum.TextXAlignment.Left
    statusLabel.TextColor3       = Color3.fromRGB(255, 200, 30)
    statusLabel.Text             = "// ¡ESCAPA POR LA PUERTA!"
    statusLabel.Parent           = banner

    -- Timer de escape
    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name              = "OvertimeTimer"
    timerLabel.Size              = UDim2.new(0.38, -12, 1, 0)
    timerLabel.Position          = UDim2.new(0.62, 4, 0, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font              = Enum.Font.GothamBlack
    timerLabel.TextSize          = 22
    timerLabel.TextXAlignment    = Enum.TextXAlignment.Right
    timerLabel.TextColor3        = Color3.fromRGB(255, 220, 80)
    timerLabel.Text              = "20s"
    timerLabel.Parent            = banner
    _timerLabel = timerLabel

    -- Fade-in del banner
    banner.BackgroundTransparency = 1
    stroke.Transparency           = 1
    TweenService:Create(banner, TweenInfo.new(0.4), { BackgroundTransparency = 0.25 }):Play()
    TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 0.1 }):Play()

    -- ── Parpadeo de urgencia en los últimos 5 segundos (activado por EscapeTimerTick) ──
    -- Se maneja en el listener de EscapeTimerTick
end

--- Muestra el overlay de éxito de escape ("¡ESCAPASTE!")
local function showEscapeSuccessOverlay()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    local overlay = Instance.new("ScreenGui")
    overlay.Name          = "EscapeSuccessOverlay"
    overlay.IgnoreGuiInset = true
    overlay.DisplayOrder  = 20
    overlay.Parent        = playerGui

    local label = Instance.new("TextLabel")
    label.Size             = UDim2.new(1, 0, 0.3, 0)
    label.AnchorPoint      = Vector2.new(0.5, 0.5)
    label.Position         = UDim2.new(0.5, 0, 0.5, 0)
    label.BackgroundTransparency = 1
    label.Font             = Enum.Font.GothamBlack
    label.TextSize         = 72
    label.TextColor3       = Color3.fromRGB(100, 255, 120)
    label.Text             = "¡ESCAPASTE!"
    label.TextStrokeColor3 = Color3.fromRGB(0, 80, 0)
    label.TextStrokeTransparency = 0.4
    label.Parent           = overlay

    -- Aparecer y desvanecerse en 3 segundos
    label.TextTransparency = 1
    TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()

    task.delay(2, function()
        if label.Parent then
            TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
            task.delay(0.8, function()
                if overlay.Parent then overlay:Destroy() end
            end)
        end
    end)
end

-- =============================================================================
-- Start
-- =============================================================================

function OvertimeHUDController.Start()
    print("⏳ [OvertimeHUDController] Iniciado.")

    -- ── Mostrar UI cuando empieza el overtime ─────────────────────────────────
    RemoteRegistry.OvertimeStarted.OnClientEvent:Connect(function()
        buildOvertimeUI()
        print("⏳ [OvertimeHUDController] UI de overtime mostrada.")
    end)

    -- ── Actualizar timer de escape cada segundo ───────────────────────────────
    RemoteRegistry.EscapeTimerTick.OnClientEvent:Connect(function(remaining: number)
        if not _timerLabel or not _timerLabel.Parent then return end

        _timerLabel.Text = tostring(remaining) .. "s"

        -- Urgencia visual: rojo parpadeante en los últimos 5s
        if remaining <= 5 then
            _timerLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            -- Parpadeo simple con tween
            TweenService:Create(_timerLabel, TweenInfo.new(0.15), {
                TextTransparency = 0.5
            }):Play()
            task.delay(0.15, function()
                if _timerLabel and _timerLabel.Parent then
                    TweenService:Create(_timerLabel, TweenInfo.new(0.15), {
                        TextTransparency = 0
                    }):Play()
                end
            end)
        end
    end)

    -- ── Este jugador escapó con éxito ─────────────────────────────────────────
    RemoteRegistry.EscapeSuccess.OnClientEvent:Connect(function()
        showEscapeSuccessOverlay()
        destroyUI()   -- El survivor que escapó ya no necesita ver el timer
        print("⏳ [OvertimeHUDController] Escape exitoso. UI removida.")
    end)

    -- ── Limpiar al terminar la partida ────────────────────────────────────────
    ClientEventBus.MatchStateChanged:Connect(function(newState: string)
        if newState == GameState.ENDING
        or newState == GameState.WAITING
        or newState == GameState.LOBBY then
            destroyUI()
        end
    end)
end

return OvertimeHUDController