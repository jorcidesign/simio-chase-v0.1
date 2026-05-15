-- =============================================================================
-- CharacterSelectionService.lua
-- =============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)
local CharacterRegistry = require(ServerScriptService.Data.CharacterRegistry)

local CharacterSelectionService = {}

-- Estado de la selección
-- _roles[Player] = "Killer" | "Survivor"
local _roles = {}
-- _picks[Player] = "ID_PERSONAJE"
local _picks = {}

local _lastKillerName: string? = nil -- ✅ NUEVO: Guardar el último asesino

function CharacterSelectionService.StartPhase()
    table.clear(_roles)
    table.clear(_picks)

    local currentPlayers = Players:GetPlayers()
    if #currentPlayers == 0 then return end

    -- ✅ 1. Filtrar al último killer para que no le toque de nuevo
    local availableCandidates = {}
    for _, p in ipairs(currentPlayers) do
        if p.Name ~= _lastKillerName then
            table.insert(availableCandidates, p)
        end
    end

    -- Si el único jugador es el anterior (o no hay nadie más), fallback a todos
    if #availableCandidates == 0 then
        availableCandidates = currentPlayers
    end

    local killerPlayer = availableCandidates[math.random(1, #availableCandidates)]
    _lastKillerName = killerPlayer.Name -- Guardamos para la próxima ronda

    for _, p in ipairs(currentPlayers) do
        local role = (p == killerPlayer) and "Killer" or "Survivor"
        _roles[p] = role
        RemoteRegistry.StartSelectionPhase:FireClient(p, role)
    end
    print(string.format("🎲 [SelectionService] Fase iniciada. Killer asignado a: %s", killerPlayer.Name))
    
    CharacterSelectionService._broadcastSync()
end

function CharacterSelectionService._broadcastSync()
    -- Formatear data para enviar al cliente
    local syncData = {}
    for p, role in pairs(_roles) do
        if _picks[p] then
            table.insert(syncData, {
                playerName = p.Name,
                role = role,
                characterId = _picks[p]
            })
        end
    end
    RemoteRegistry.SyncSelectionList:FireAllClients(syncData)
end

function CharacterSelectionService.FinalizePhase()
    -- Si alguien no eligió, asignarle aleatorio respetando que no se repitan
    local takenSurvivors = {}
    for p, role in pairs(_roles) do
        if role == "Survivor" and _picks[p] then
            takenSurvivors[_picks[p]] = true
        end
    end

    local allSurvivors = CharacterRegistry.getDefaultSurvivorIds()
    local allKillers = CharacterRegistry.getDefaultKillerIds()

    for p, role in pairs(_roles) do
        if not _picks[p] then
            if role == "Killer" then
                _picks[p] = allKillers[math.random(1, #allKillers)]
            else
                -- Buscar un survivor libre
                local available = {}
                for _, id in ipairs(allSurvivors) do
                    if not takenSurvivors[id] then table.insert(available, id) end
                end
                
                -- Si por algún milagro se acaban los survivors, repetir uno
                if #available == 0 then available = allSurvivors end
                
                local randomSurv = available[math.random(1, #available)]
                _picks[p] = randomSurv
                takenSurvivors[randomSurv] = true
            end
        end
    end

    print("✅ [SelectionService] Selecciones finalizadas y auto-completadas.")
    return _roles, _picks
end

function CharacterSelectionService.GetFinalData()
    return _roles, _picks
end

function CharacterSelectionService.Start()
    print("📋 [SelectionService] Iniciado.")
    
    RemoteRegistry.SelectCharacter.OnServerEvent:Connect(function(player, role, charId)
        local expectedRole = _roles[player]
        if expectedRole ~= role then return end -- Hack check

        if role == "Survivor" then
            -- Validar que nadie más lo tenga
            for otherPlayer, pickedId in pairs(_picks) do
                if otherPlayer ~= player and pickedId == charId then
                    return -- Rechazado, ya está tomado
                end
            end
        end

        _picks[player] = charId
        CharacterSelectionService._broadcastSync()
    end)
end

return CharacterSelectionService