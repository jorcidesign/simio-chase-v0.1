-- =============================================================================
-- RespawnManagerService.lua
-- Ubicación: src/ServerScriptService/Services/RespawnManagerService.lua
-- =============================================================================

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerEventBus = require(ServerScriptService.Network.ServerEventBus)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local GameState      = require(ReplicatedStorage.Enums.GameState)
local WorldService   = require(script.Parent.WorldService)

local RespawnManagerService = {}

-- =============================================================================
-- Estado interno
-- =============================================================================

-- Selección de personaje de cada jugador: { [Player] = { role, id } }
local _playerSelections: {[Player]: {role: string, id: string}} = {}

-- Estado de partida actual (actualizado vía bus, sin import circular)
local _currentMatchState: string = GameState.WAITING

-- Índices de SurvivorSpawns ya usados en esta ronda
local _usedSpawnIndices: {[number]: boolean} = {}

-- =============================================================================
-- Helpers: Spawns
-- =============================================================================

--- Devuelve un CFrame de Survivor único por ronda, rotando cuando se agotan.
local function getNextSurvivorSpawnCFrame(): CFrame
    local parts = WorldService.getSurvivorSpawnParts()

    if #parts == 0 then
        -- Fallback de emergencia distribuido
        return CFrame.new(
            math.random(-8, 8),
            10,
            math.random(-8, 8)
        )
    end

    -- Construir lista de índices disponibles
    local available: {number} = {}
    for i = 1, #parts do
        if not _usedSpawnIndices[i] then
            table.insert(available, i)
        end
    end

    -- Si todos usados, resetear (más jugadores que spawns)
    if #available == 0 then
        table.clear(_usedSpawnIndices)
        for i = 1, #parts do
            table.insert(available, i)
        end
    end

    local pick = available[math.random(1, #available)]
    _usedSpawnIndices[pick] = true

    -- Offset leve para que no se solapen exactamente
    local spread = 2
    return parts[pick].CFrame
        + Vector3.new(math.random(-spread, spread), 0, math.random(-spread, spread))
end

-- =============================================================================
-- Helpers: Inyección de Animator
--
-- La estrategia correcta para rigs custom es:
--   1. Asegurarnos de que el Model tiene un Humanoid.
--   2. Insertar un Animator dentro del Humanoid (si no existe).
--   3. NO intentar clonar el LocalScript "Animate" desde el servidor.
--      En su lugar, el cliente (CharacterAnimationController) lo maneja
--      vía SetupCharacter RemoteEvent, usando AnimationIds de GameConstants.
-- =============================================================================

--- Garantiza que el personaje tenga el componente Animator que necesita el cliente.
local function ensureAnimator(character: Model)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("[RespawnManager] El modelo no tiene Humanoid: " .. character.Name)
        return
    end

    -- Animator es el componente que expone :LoadAnimation() al cliente.
    -- Sin él, las animaciones no pueden reproducirse.
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        local a = Instance.new("Animator")
        a.Parent = humanoid
    end
end

-- =============================================================================
-- Core: spawn de un jugador
-- =============================================================================

local function spawnPlayer(player: Player, role: string, characterId: string)
    local folderName  = (role == "Killer") and "Killers" or "Survivors"
    local assetsRoot  = ReplicatedStorage:FindFirstChild("Assets")

    if not assetsRoot then
        warn("[RespawnManager] 'Assets' no encontrado en ReplicatedStorage.")
        return
    end

    local categoryFolder = assetsRoot:FindFirstChild("Characters")
        and assetsRoot.Characters:FindFirstChild(folderName)

    local characterModel = categoryFolder and categoryFolder:FindFirstChild(characterId)

    if not characterModel then
        warn(string.format(
            "[RespawnManager] Modelo '%s' no encontrado en Assets/Characters/%s.",
            characterId, folderName
        ))
        return
    end

    -- Destruir personaje anterior limpiamente
    if player.Character then
        player.Character:Destroy()
    end

    -- Clonar modelo
    local clone = characterModel:Clone()
    clone.Name  = player.Name

    -- Tags de identidad para DamageSystem y SkillManagerService
    local idTag  = Instance.new("StringValue")
    idTag.Name   = (role == "Killer") and "KillerID" or "SurvivorID"
    idTag.Value  = characterId
    idTag.Parent = clone

    -- ✅ Inyectar Animator antes de entrar al Workspace
    -- El cliente leerá este componente para cargar las animaciones.
    ensureAnimator(clone)

    -- Determinar posición de spawn
    local spawnCF: CFrame
    if role == "Killer" then
        spawnCF = WorldService.getKillerSpawnCFrame()
    else
        spawnCF = getNextSurvivorSpawnCFrame()
    end

    -- Llevar al Workspace y posicionar ANTES de asignar a player.Character
    -- para evitar que el cliente vea al personaje caer desde 0,0,0
    clone.Parent = workspace
    clone:PivotTo(spawnCF)

    -- Asignar Character (esto dispara CharacterAdded en el cliente)
    player.Character = clone

    -- ✅ Avisar al cliente que reconfigure cámara y arranque animaciones.
    -- El delay de 0.15s da tiempo a la replicación para que player.Character
    -- ya esté disponible en el cliente cuando llega el evento.
    task.delay(0.15, function()
        if player and player.Parent then
            RemoteRegistry.SetupCharacter:FireClient(player)
        end
    end)

    -- Wiring de muerte
    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Once(function()
            if role == "Survivor" then
                local victim = Players:GetPlayerFromCharacter(clone)
                if victim then
                    ServerEventBus.SurvivorKilled:Fire(victim, nil)
                end
            elseif role == "Killer" then
                ServerEventBus.KillerKilled:Fire(player)
            end
            RemoteRegistry.ShowRespawnMenu:FireClient(player, 30)
        end)
    end

    print(string.format(
        "✅ [RespawnManager] %s → %s (%s) en %s",
        player.Name, characterId, role,
        string.format("(%.1f, %.1f, %.1f)", spawnCF.X, spawnCF.Y, spawnCF.Z)
    ))
end

local function spawnAllPlayers()
    table.clear(_usedSpawnIndices)
    for _, player in ipairs(Players:GetPlayers()) do
        local sel = _playerSelections[player]
            or { role = "Survivor", id = "GONZACARBON" }
        spawnPlayer(player, sel.role, sel.id)
    end
end

--- Regresa a todos los jugadores al Lobby usando LoadCharacter() + teletransporte.
local function returnAllToLobby()
    local lobbyCF = WorldService.getLobbySpawnCFrame()

    for _, player in ipairs(Players:GetPlayers()) do
        -- Destruir el personaje custom si existe
        if player.Character then
            player.Character:Destroy()
        end

        -- LoadCharacter() da al jugador su avatar de Roblox para el Lobby.
        -- CharacterAdded se dispara, y cuando el personaje está listo
        -- lo teletransportamos al LobbySpawn.
        player:LoadCharacter()

        -- Esperamos a que el personaje de Lobby esté en el Workspace
        -- antes de moverlo, para evitar que aparezca en 0,0,0.
        task.spawn(function()
            local char = player.Character or player.CharacterAdded:Wait()
            -- WaitForChild con timeout por si el Humanoid tarda en replicarse
            local root = char:WaitForChild("HumanoidRootPart", 5)
            if root then
                char:PivotTo(lobbyCF + Vector3.new(
                    math.random(-3, 3), 0, math.random(-3, 3)
                ))
            end
        end)
    end
end

-- =============================================================================
-- API pública
-- =============================================================================

function RespawnManagerService.spawnPlayer(player: Player, role: string, characterId: string)
    spawnPlayer(player, role, characterId)
end

-- =============================================================================
-- Start
-- =============================================================================

function RespawnManagerService.Start()
    print("👼 [RespawnManager] Iniciado.")

    -- Roblox no debe respawnear automáticamente — nosotros lo controlamos
    Players.CharacterAutoLoads = false

    -- Dar personaje de Lobby a los jugadores que entren al servidor
    Players.PlayerAdded:Connect(function(player)
        player:LoadCharacter()

        -- Teletransportar al LobbySpawn cuando el personaje esté listo
        task.spawn(function()
            local char = player.Character or player.CharacterAdded:Wait()
            local root = char:WaitForChild("HumanoidRootPart", 5)
            if root then
                local lobbyCF = WorldService.getLobbySpawnCFrame()
                char:PivotTo(lobbyCF + Vector3.new(
                    math.random(-3, 3), 0, math.random(-3, 3)
                ))
            end
        end)
    end)

    -- Limpiar selección cuando un jugador se va
    Players.PlayerRemoving:Connect(function(player)
        _playerSelections[player] = nil
    end)

    -- Guardar selección de personaje enviada por el cliente
    RemoteRegistry.SelectCharacter.OnServerEvent:Connect(function(player, role, characterId)
        if type(role) ~= "string" or type(characterId) ~= "string" then
            warn("[RespawnManager] SelectCharacter: datos inválidos de " .. player.Name)
            return
        end
        _playerSelections[player] = { role = role, id = characterId }
        print(string.format(
            "📥 [RespawnManager] %s eligió: %s (%s)",
            player.Name, characterId, role
        ))
    end)

    -- El jugador pide revivir desde el menú de muerte
    RemoteRegistry.RequestRespawn.OnServerEvent:Connect(function(player)
        if _currentMatchState ~= GameState.PLAYING
            and _currentMatchState ~= GameState.LAST_MAN then
            return
        end
        local sel = _playerSelections[player]
        if sel then
            spawnPlayer(player, sel.role, sel.id)
        end
    end)

    -- Reaccionar a cambios de fase del MatchManager (vía bus, sin import circular)
    ServerEventBus.MatchStateChanged:Connect(function(newState: string)
        _currentMatchState = newState

        if newState == GameState.PLAYING then
            spawnAllPlayers()
        elseif newState == GameState.ENDING then
            returnAllToLobby()
        elseif newState == GameState.WAITING then
            table.clear(_playerSelections)
            table.clear(_usedSpawnIndices)
        end
    end)
end

return RespawnManagerService