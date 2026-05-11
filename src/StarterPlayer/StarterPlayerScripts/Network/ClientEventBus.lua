-- src/StarterPlayer/StarterPlayerScripts/Network/ClientEventBus.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal         = require(ReplicatedStorage.Packages.Signal)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local ClientEventBus = {
	-- Traduce el RemoteEvent de estado a una señal local
	MatchStateChanged = Signal.new(),

	-- ✅ Traduce el tick de tiempo del servidor a una señal local
	TimeUpdated = Signal.new(),
}

-- Puente: servidor → cliente para estado de partida
RemoteRegistry.UpdateGameState.OnClientEvent:Connect(function(newState)
	ClientEventBus.MatchStateChanged:Fire(newState)
end)

-- ✅ Puente: servidor → cliente para el timer
RemoteRegistry.TimeUpdated.OnClientEvent:Connect(function(remaining)
	ClientEventBus.TimeUpdated:Fire(remaining)
end)

return ClientEventBus