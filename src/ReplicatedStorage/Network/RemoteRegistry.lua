-- =============================================================================
-- RemoteRegistry.lua
-- Ubicación: src/shared/network/RemoteRegistry.lua
--
-- Registro centralizado de TODOS los RemoteEvents y RemoteFunctions del juego.
-- Crea los remotes si no existen, y los retorna listos para usar.
--
-- Principio SOLID: Single Responsibility
-- Elimina la proliferación de getOrCreateEvent() por todo el código.
-- Un solo lugar para ver TODOS los canales de comunicación cliente-servidor.
-- =============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ---------------------------------------------------------------------------
-- Helpers privados
-- ---------------------------------------------------------------------------

local function getFolder(name: string): Folder
	local f = ReplicatedStorage:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = ReplicatedStorage
	end
	return f
end

local function getOrCreateRemote(parent: Instance, name: string): RemoteEvent
	local ev = parent:FindFirstChild(name)
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = parent
	end
	return ev
end

local function getOrCreateBindable(name: string): BindableEvent
	local ev = ReplicatedStorage:FindFirstChild(name)
	if not ev then
		ev = Instance.new("BindableEvent")
		ev.Name = name
		ev.Parent = ReplicatedStorage
	end
	return ev
end

-- ---------------------------------------------------------------------------
-- Construcción del registro
-- ---------------------------------------------------------------------------

local eventsFolder = getFolder("GameEvents")

--- @class RemoteRegistry
--- Todos los canales de comunicación tipados.
local RemoteRegistry = {

	-- =========================================================================
	-- 🎮 ESTADO DEL JUEGO (Server → Client)
	-- =========================================================================

	--- Enviado cada segundo. Args: (state: string, timer: number, message: string)
	UpdateGameState = getOrCreateRemote(eventsFolder, "UpdateGameState"),

	--- Enviado al inicio. Args: (role: "Survivor"|"Killer", characterId: string)
	AssignRole = getOrCreateRemote(eventsFolder, "AssignRole"),

	--- Avisar a todos que la salida está abierta.
	ExitOpen = getOrCreateRemote(eventsFolder, "ExitOpen"),

	--- Avisar inicio de LMS. Args: (killerId: string, survivorId: string)
	LMSStart = getOrCreateRemote(eventsFolder, "LMSStart"),

	--- Server → Client: Mostrar menú de respawn. Args: (timeLimit: number)
	ShowRespawnMenu = getOrCreateRemote(eventsFolder, "ShowRespawnMenu"),

	--- Client → Server: El jugador pide revivir.
	RequestRespawn = getOrCreateRemote(eventsFolder, "RequestRespawn"),

	-- =========================================================================
	-- ⚔️ COMBATE (Client → Server y Server → Client)
	-- =========================================================================

	--- Client → Server: El killer intenta un M1.
	M1Attack = getOrCreateRemote(eventsFolder, "M1Attack"),

	--- Client → Server: Usar habilidad de killer. Args: (abilityServerName: string, target: Vector3?)
	UseKillerAbility = getOrCreateRemote(eventsFolder, "UseAbility"),

	--- Client → Server: Usar habilidad de survivor. Args: (abilityServerName: string, targetPos: Vector3?)
	UseSurvivorAbility = getOrCreateRemote(eventsFolder, "UseSurvivorAbility"),

	--- Server → Client: Confirmar daño recibido (flash de pantalla roja).
	DamageEffect = getOrCreateRemote(eventsFolder, "DamageEffect"),

	--- Server → Client: Aplicar efecto de stun en UI. Args: (duration: number)
	StunEffect = getOrCreateRemote(eventsFolder, "StunEffect"),

	--- Server → Client: Cegar al killer. Args: (duration: number)
	BlindKiller = getOrCreateRemote(eventsFolder, "eventBlindKiller"),

	--- Server → Client: Pantalla de barro para Augusto. Args: (duration: number)
	MudScreen = getOrCreateRemote(eventsFolder, "MudScreen"),

	--- Server → Client: Popup hack de Dante. Args: (duration: number, intensity: number)
	PopupHack = getOrCreateRemote(eventsFolder, "PopupHack"),

	--- Server → Client: Activar doble salto en el cliente. Args: (duration: number)
	ActivateDoubleJump = getOrCreateRemote(eventsFolder, "ActivateDoubleJump"),

	-- =========================================================================
	-- 🏃 ESCAPE (Client → Server y Server → Client)
	-- =========================================================================

	--- Server → Client: Notificar al jugador que escapó.
	PlayerEscaped = getOrCreateRemote(eventsFolder, "PlayerEscaped"),

	-- =========================================================================
	-- 💀 EJECUCIÓN (Server → Client)
	-- =========================================================================

	--- Server → Client: Iniciar animación de kill execution.
	--- Args: (role: "Killer"|"Survivor", killerId: string, victimName: string?, duration: number)
	KillExecution = getOrCreateRemote(eventsFolder, "KillExecution"),

	-- =========================================================================
	-- 📦 INVENTARIO (Client ↔ Server)
	-- =========================================================================

	--- Client → Server: Cambiar personaje seleccionado. Args: (role: string, characterId: string)
	SelectCharacter = getOrCreateRemote(eventsFolder, "SelectCharacter"),

	--- Server → Client: Enviar selección guardada al conectarse.
	LoadSelection = getOrCreateRemote(eventsFolder, "LoadSelection"),

	-- =========================================================================
	-- 📊 ESTADÍSTICAS (Server → Client)
	-- =========================================================================

	--- Server → Client: Enviar stats al fin de partida.
	DisplayStats = getOrCreateRemote(eventsFolder, "DisplayStats"),

	-- =========================================================================
	-- 🔗 BINDABLE EVENTS (Server → Server, sin cruzar la red)
	-- =========================================================================

	--- Disparado por MusicManagerService cuando termina la música LMS.
	LMSTimeout = getOrCreateBindable("LMSTimeout"),
}

return RemoteRegistry