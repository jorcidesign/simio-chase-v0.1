-- src/StarterPlayer/StarterPlayerScripts/Controllers/GameHUDController.lua

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientEventBus = require(script.Parent.Parent.Network.ClientEventBus)
local GameState      = require(ReplicatedStorage.Enums.GameState)

local GameHUDController = {}

local activeUI: ScreenGui? = nil

-- ✅ Guardamos todas las conexiones internas de la UI activa aquí.
-- Al destruir la UI, las desconectamos todas para no tener memory leaks.
local _uiConnections: {RBXScriptConnection} = {}

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
	-- ✅ Desconectar todos los listeners ligados a esta UI
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
	-- Siempre partir de cero limpio para evitar duplicados
	destroyUI()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	activeUI = Instance.new("ScreenGui")
	activeUI.Name = "GameHUD"
	activeUI.IgnoreGuiInset = true
	activeUI.ResetOnSpawn = false  -- ✅ Sobrevive al respawn del personaje
	activeUI.Parent = playerGui

	-- Barra superior
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 56)
	topBar.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	topBar.BackgroundTransparency = 0.25
	topBar.BorderSizePixel = 0
	topBar.Parent = activeUI

	-- Label de estado (izquierda)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(0.65, -8, 1, 0)
	statusLabel.Position = UDim2.new(0, 16, 0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 22
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.Parent = topBar

	-- Label del timer (derecha)
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(0.35, -16, 1, 0)
	timerLabel.Position = UDim2.new(0.65, 8, 0, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.TextSize = 26
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right
	timerLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
	timerLabel.Text = "--:--"
	timerLabel.Parent = topBar

	-- Configurar texto y colores según el estado
	if state == GameState.LOBBY then
		statusLabel.Text = "⏳  ESPERANDO EN LOBBY..."
		statusLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
		timerLabel.TextColor3  = Color3.fromRGB(100, 255, 120)

	elseif state == GameState.PLAYING then
		statusLabel.Text = "⚔️  ¡SOBREVIVE!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		timerLabel.TextColor3  = Color3.fromRGB(255, 220, 80)

	elseif state == GameState.LAST_MAN then
		statusLabel.Text = "🔥  ÚLTIMO EN PIE"
		statusLabel.TextColor3 = Color3.fromRGB(255, 160, 30)
		timerLabel.TextColor3  = Color3.fromRGB(255, 160, 30)
	end

	-- ✅ Conectar el timer y guardar la conexión para poder limpiarla luego
	local timerConn = ClientEventBus.TimeUpdated:Connect(function(remaining: number)
		-- Verificar que la UI sigue viva antes de tocarla
		if timerLabel and timerLabel.Parent then
			timerLabel.Text = formatTime(remaining)

			-- Urgencia visual: rojo cuando quedan ≤ 30 segundos
			if remaining <= 30 then
				timerLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
			end
		end
	end)
	table.insert(_uiConnections, timerConn)
end

-- =============================================================================
-- Start
-- =============================================================================

function GameHUDController.Start()
	print("🖥️ [GameHUDController] Iniciado.")

	-- Esta conexión vive para siempre (es el listener maestro del controlador).
	-- No va en _uiConnections porque no debe destruirse entre fases.
	ClientEventBus.MatchStateChanged:Connect(function(newState: string)
		if newState == GameState.LOBBY
		or newState == GameState.PLAYING
		or newState == GameState.LAST_MAN then
			buildUI(newState)
		else
			-- SELECTING, ENDING, INTERMISSION, WAITING → limpiar HUD
			destroyUI()
		end
	end)
end

return GameHUDController