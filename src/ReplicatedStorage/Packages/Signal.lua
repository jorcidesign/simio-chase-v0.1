-- src/ReplicatedStorage/Packages/Signal.lua
-- Implementación robusta y tipada de Signals para Asto Studio
local Signal = {}
Signal.__index = Signal

-- Constructor
function Signal.new()
    local self = setmetatable({
        _bindable = Instance.new("BindableEvent"),
        _connections = {}
    }, Signal)
    return self
end

-- Conectar una función al evento
function Signal:Connect(handler: (...any) -> ())
    local connection = self._bindable.Event:Connect(function(...)
        handler(...)
    end)
    table.insert(self._connections, connection)
    return connection
end

-- Disparar el evento con cualquier cantidad de argumentos
function Signal:Fire(...)
    self._bindable:Fire(...)
end

-- Destruir el evento y limpiar memoria (¡Súper importante para evitar Memory Leaks!)
function Signal:Destroy()
    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
    self._bindable:Destroy()
end

return Signal