-- src/ServerScriptService/Network/ServerEventBus.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

local ServerEventBus = {
    -- Creamos un evento de prueba
    TestPing = Signal.new()
}

return ServerEventBus