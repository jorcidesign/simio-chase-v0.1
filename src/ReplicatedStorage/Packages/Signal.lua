-- =============================================================================
-- Signal.lua
-- Ubicación: src/shared/packages/Signal.lua
--
-- Implementación del patrón Observer. Reemplaza el uso directo de
-- BindableEvents y desacopla completamente emisores de receptores.
--
-- Patrón: Observer / Event Emitter
-- Principio SOLID: Dependency Inversion (módulos dependen de esta abstracción)
-- =============================================================================

-- Tipos Luau para autocompletado y seguridad de tipos
export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	Destroy: (self: Signal<T...>) -> (),
}

-- ---------------------------------------------------------------------------
-- Implementación interna de Connection
-- ---------------------------------------------------------------------------
local Connection = {}
Connection.__index = Connection

function Connection.new(signal: any, handler: (...any) -> ()): Connection
	return setmetatable({
		_signal  = signal,
		_handler = handler,
		Connected = true,
	}, Connection)
end

function Connection:Disconnect()
	if not self.Connected then return end
	self.Connected = false

	local connections = self._signal._connections
	for i, conn in ipairs(connections) do
		if conn == self then
			table.remove(connections, i)
			break
		end
	end
end

-- ---------------------------------------------------------------------------
-- Implementación de Signal
-- ---------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

--- Constructor. Crea un nuevo Signal vacío.
function Signal.new(): Signal<...any>
	return setmetatable({
		_connections = {} :: {Connection},
		_thread      = nil :: thread?,
	}, Signal)
end

--- Conecta un handler que se ejecuta cada vez que se dispara el Signal.
--- @return Connection  Guarda la conexión para desconectarla posteriormente.
function Signal:Connect(handler: (...any) -> ()): Connection
	assert(type(handler) == "function", "[Signal] Connect espera una función")

	local conn = Connection.new(self, handler)
	table.insert(self._connections, conn)
	return conn
end

--- Conecta un handler que se ejecuta UNA SOLA VEZ y se desconecta solo.
function Signal:Once(handler: (...any) -> ()): Connection
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		handler(...)
	end)
	return conn
end

--- Dispara el Signal, ejecutando todos los handlers conectados.
--- SEGURO: los errores en handlers individuales no rompen los demás.
function Signal:Fire(...: any)
	-- Snapshot para evitar mutaciones durante la iteración
	local snapshot = table.clone(self._connections)

	for _, conn in ipairs(snapshot) do
		if conn.Connected then
			local ok, err = pcall(conn._handler, ...)
			if not ok then
				warn(string.format("[Signal] Error en handler: %s", tostring(err)))
			end
		end
	end

	-- Despertar cualquier corrutina esperando con :Wait()
	if self._thread then
		local thread = self._thread
		self._thread = nil
		task.spawn(thread, ...)
	end
end

--- Suspende la corrutina actual hasta que el Signal sea disparado.
--- @return ... Los argumentos con que fue disparado el Signal.
function Signal:Wait(): ...any
	self._thread = coroutine.running()
	return coroutine.yield()
end

--- Destruye el Signal y limpia todas las conexiones. Llamar al hacer cleanup.
function Signal:Destroy()
	for _, conn in ipairs(self._connections) do
		conn.Connected = false
	end
	table.clear(self._connections)
	self._thread = nil
end

return Signal