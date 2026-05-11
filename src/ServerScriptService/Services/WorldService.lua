-- =============================================================================
-- WorldService.lua
-- Ubicación: src/ServerScriptService/Services/WorldService.lua
-- =============================================================================

local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConstants     = require(ReplicatedStorage.GameConstants)

local WorldService = {}

-- =============================================================================
-- Estado interno
-- =============================================================================

-- Referencia al mapa instanciado actualmente. Solo existe durante PLAYING/LAST_MAN.
local _activeMapInstance: Model? = nil

-- Nombre del mapa activo (para buscarlo en Workspace si hace falta).
local _activeMapName: string? = nil

-- =============================================================================
-- API Pública — Spawns del Lobby (estático, siempre en Workspace)
-- =============================================================================

--- Retorna el CFrame del spawn del Lobby.
--- Ruta real: workspace.Lobby_Prueba_1.LobbySpawn
function WorldService.getLobbySpawnCFrame(): CFrame
    local lobby = workspace:FindFirstChild("Lobby_Prueba_1")
    if not lobby then
        warn("[WorldService] 'Lobby_Prueba_1' no encontrado en Workspace. Usando fallback.")
        return CFrame.new(0, 5, 0)
    end

    local spawnPart = lobby:FindFirstChild("LobbySpawn")
    if not spawnPart or not spawnPart:IsA("BasePart") then
        warn("[WorldService] 'LobbySpawn' no encontrado dentro de Lobby_Prueba_1. Usando fallback.")
        return CFrame.new(0, 5, 0)
    end

    return spawnPart.CFrame
end

-- =============================================================================
-- API Pública — Spawns del Mapa Dinámico
-- =============================================================================

--- Retorna el CFrame del spawn del Killer en el mapa activo.
--- Ruta real: workspace.<mapName>.KillerSpawn
function WorldService.getKillerSpawnCFrame(): CFrame
    local map = _activeMapInstance
    if not map or not map.Parent then
        warn("[WorldService] No hay mapa activo al buscar KillerSpawn.")
        return CFrame.new(0, 10, 0)
    end

    local spawnPart = map:FindFirstChild("KillerSpawn")
    if not spawnPart or not spawnPart:IsA("BasePart") then
        warn("[WorldService] 'KillerSpawn' no encontrado en el mapa activo. Usando fallback.")
        return CFrame.new(0, 10, 0)
    end

    return spawnPart.CFrame
end

--- Retorna todos los BaseParts de SurvivorSpawns del mapa activo.
--- Ruta real: workspace.<mapName>.SurvivorSpawns.Spawn1 ... SpawnN
function WorldService.getSurvivorSpawnParts(): {BasePart}
    local map = _activeMapInstance
    if not map or not map.Parent then
        warn("[WorldService] No hay mapa activo al buscar SurvivorSpawns.")
        return {}
    end

    local folder = map:FindFirstChild("SurvivorSpawns")
    if not folder then
        warn("[WorldService] 'SurvivorSpawns' no encontrado en el mapa activo.")
        return {}
    end

    local result: {BasePart} = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("BasePart") then
            table.insert(result, child)
        end
    end

    if #result == 0 then
        warn("[WorldService] SurvivorSpawns no contiene BaseParts.")
    end

    return result
end

-- =============================================================================
-- API Pública — Gestión de Mapas
-- =============================================================================

--- Clona el mapa desde ReplicatedStorage y lo instancia en Workspace.
--- Ruta fuente: ReplicatedStorage.Assets.Maps.<mapName>
function WorldService.loadMap(mapName: string)
    -- Descargar el mapa anterior si existe
    WorldService.unloadMap()

    local mapsFolder = ReplicatedStorage:FindFirstChild("Assets")
        and ReplicatedStorage.Assets:FindFirstChild("Maps")

    if not mapsFolder then
        warn("[WorldService] Carpeta 'ReplicatedStorage/Assets/Maps' no encontrada.")
        return
    end

    local template = mapsFolder:FindFirstChild(mapName)
    if not template then
        warn("[WorldService] Mapa '" .. mapName .. "' no encontrado en Assets/Maps.")
        return
    end

    _activeMapInstance = template:Clone()
    _activeMapInstance.Parent = workspace
    _activeMapName = mapName

    print("🗺️ [WorldService] Mapa cargado: " .. mapName)
end

--- Destruye el mapa activo y limpia la referencia.
function WorldService.unloadMap()
    if _activeMapInstance then
        _activeMapInstance:Destroy()
        _activeMapInstance = nil
        _activeMapName = nil
        print("🗺️ [WorldService] Mapa descargado.")
    end
end

--- Retorna la instancia del mapa activo (puede ser nil si no hay partida).
function WorldService.getActiveMap(): Model?
    return _activeMapInstance
end

-- =============================================================================
-- API Pública — Iluminación
-- =============================================================================

local LightingPresets = {
    Normal = {
        FogEnd         = GameConstants.VFX.NORMAL_FOG_END,
        Brightness     = 2,
        OutdoorAmbient = Color3.fromRGB(70, 70, 70),
        tint           = Color3.fromRGB(255, 255, 255),
    },
    Chase = {
        FogEnd         = GameConstants.VFX.CHASE_FOG_END,
        Brightness     = 0.3,
        OutdoorAmbient = GameConstants.VFX.CHASE_AMBIENT,
        tint           = Color3.fromRGB(180, 160, 160),
    },
    Escape = {
        FogEnd         = 500,
        Brightness     = 1.5,
        OutdoorAmbient = Color3.fromRGB(100, 90, 50),
        tint           = GameConstants.VFX.ESCAPE_TINT,
    },
}

function WorldService.applyLightingPreset(presetName: string, duration: number?)
    local preset = LightingPresets[presetName]
    if not preset then
        warn("[WorldService] Preset desconocido: '" .. presetName .. "'")
        return
    end

    local lighting  = game:GetService("Lighting")
    local tweenInfo = TweenInfo.new(duration or 3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    TweenService:Create(lighting, tweenInfo, {
        FogEnd         = preset.FogEnd,
        Brightness     = preset.Brightness,
        OutdoorAmbient = preset.OutdoorAmbient,
    }):Play()

    local cc = lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if cc then
        TweenService:Create(cc, tweenInfo, { TintColor = preset.tint }):Play()
    end
end

-- =============================================================================
-- Arranque
-- =============================================================================

function WorldService.Start()
    -- Validar que el Lobby estático existe al arrancar
    local lobby = workspace:FindFirstChild("Lobby_Prueba_1")
    if lobby then
        print("🌍 [WorldService] Lobby_Prueba_1 encontrado. Listo.")
    else
        warn("[WorldService] ⚠️ 'Lobby_Prueba_1' no está en Workspace. " ..
             "Los jugadores usarán posición de emergencia hasta que el artista lo coloque.")
    end
end

return WorldService