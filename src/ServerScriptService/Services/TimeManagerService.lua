-- src/ServerScriptService/Services/TimeManagerService.lua

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerEventBus = require(ServerScriptService.Network.ServerEventBus)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local TimeManagerService = {}

local _timerThread: thread?  = nil
local _remaining:   number   = 0
local _isRunning:   boolean  = false

function TimeManagerService.start(
	seconds:   number,
	onTick:    ((number) -> ())?,
	onExpired: (() -> ())?
)
	TimeManagerService.cancel()

	_remaining = seconds
	_isRunning = true

	_timerThread = task.spawn(function()
		while _remaining > 0 do
			task.wait(1)

			if not _isRunning then return end

			_remaining -= 1

			if onTick then
				onTick(_remaining)
			end

			-- Notificar al bus interno del servidor
			ServerEventBus.TimeUpdated:Fire(_remaining)

			-- ✅ Notificar a todos los clientes para el HUD
			RemoteRegistry.TimeUpdated:FireAllClients(_remaining)
		end

		_isRunning   = false
		_timerThread = nil

		if onExpired then
			onExpired()
		end

		ServerEventBus.TimeExpired:Fire()
	end)
end

function TimeManagerService.addTime(seconds: number)
	if _isRunning then
		_remaining += seconds
		print(string.format("[TimeManager] +%ds añadidos. Nuevo total: %ds", seconds, _remaining))
	end
end

function TimeManagerService.cancel()
	if _timerThread then
		_isRunning   = false
		task.cancel(_timerThread)
		_timerThread = nil
		_remaining   = 0
	end
end

function TimeManagerService.getRemaining(): number
	return _remaining
end

function TimeManagerService.isRunning(): boolean
	return _isRunning
end

function TimeManagerService.Start()
	print("⏳ [TimeManager] Iniciado.")
end

return TimeManagerService