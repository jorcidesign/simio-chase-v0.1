-- =============================================================================
-- WorldService.lua
-- =============================================================================

local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConstants     = require(ReplicatedStorage.GameConstants)

local WorldService = {}

-- =============================================================================
-- Estado interno
-- =============================================================================

local _activeMapInstance: Model? = nil
local _activeMapName: string?    = nil

local _debugBillboard: BillboardGui? = nil
local _activeDummies: {Model} = {}

-- =============================================================================
-- Privado: Billboard de debug
-- =============================================================================

local function _spawnDebugBillboard(mapName: string, mapInstance: Model)
    local pivot = mapInstance:GetPivot()
    local centerPos = pivot.Position + Vector3.new(0, 20, 0)

    local anchor = Instance.new("Part")
    anchor.Name      = "DebugMapBillboard"
    anchor.Size      = Vector3.new(1, 1, 1)
    anchor.Position  = centerPos
    anchor.Anchored  = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Parent = workspace

    local billboard = Instance.new("BillboardGui", anchor)
    billboard.Size          = UDim2.new(0, 380, 0, 80)
    billboard.StudsOffset   = Vector3.new(0, 0, 0)
    billboard.AlwaysOnTop   = true
    billboard.LightInfluence = 0

    local bg = Instance.new("Frame", billboard)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    bg.BackgroundTransparency = 0.25
    bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel", bg)
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 22
    label.TextColor3 = Color3.fromRGB(80, 255, 160)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Text = "🗺️  Renderizado: " .. mapName

    _debugBillboard = billboard
    print(string.format("🗺️ [WorldService] Billboard de debug activo: '%s'", mapName))
end

-- =============================================================================
-- API Pública — Spawns del Lobby
-- =============================================================================

function WorldService.getLobbySpawnCFrame(): CFrame
    local lobby = workspace:FindFirstChild("Lobby_Prueba_1")
    if not lobby then
        return CFrame.new(0, 5, 0)
    end
    local spawnPart = lobby:FindFirstChild("LobbySpawn")
    if not spawnPart or not spawnPart:IsA("BasePart") then
        return CFrame.new(0, 5, 0)
    end
    return spawnPart.CFrame
end

-- =============================================================================
-- API Pública — Spawns del Mapa Dinámico
-- =============================================================================

function WorldService.getKillerSpawnCFrame(): CFrame
    local map = _activeMapInstance
    if not map or not map.Parent then
        return CFrame.new(0, 10, 0)
    end
    -- Casting explícito (:: Model) para callar el error Luau1032
    local spawnPart = (map :: Model):FindFirstChild("KillerSpawn")
    if not spawnPart or not spawnPart:IsA("BasePart") then
        return CFrame.new(0, 10, 0)
    end
    return spawnPart.CFrame
end

function WorldService.getSurvivorSpawnParts(): {BasePart}
    local map = _activeMapInstance
    if not map or not map.Parent then
        return {}
    end
    
    local folder = (map :: Model):FindFirstChild("SurvivorSpawns")
    if not folder then
        return {}
    end
    
    local result: {BasePart} = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("BasePart") then
            table.insert(result, child)
        end
    end
    return result
end

-- =============================================================================
-- API Pública — Gestión de Mapas
-- =============================================================================

function WorldService.loadRandomMap()
    local pool = GameConstants.Maps.Pool
    if not pool or #pool == 0 then return end

    local mapsFolder = ReplicatedStorage:FindFirstChild("Assets")
        and ReplicatedStorage.Assets:FindFirstChild("Maps")

    if not mapsFolder then return end

    local shuffled = table.clone(pool)
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    local chosenName: string? = nil
    for _, candidate in ipairs(shuffled) do
        if mapsFolder:FindFirstChild(candidate) then
            chosenName = candidate
            break
        end
    end

    if not chosenName then return end

    print(string.format("🎲 [WorldService] Pool=%s → Elegido: '%s'", table.concat(shuffled, ", "), chosenName))
    WorldService.loadMap(chosenName)
end

function WorldService.loadMap(mapName: string)
    WorldService.unloadMap()

    local mapsFolder = ReplicatedStorage:FindFirstChild("Assets")
        and ReplicatedStorage.Assets:FindFirstChild("Maps")
    if not mapsFolder then return end

    local template = mapsFolder:FindFirstChild(mapName)
    if not template then return end

    -- Asignación local segura para evitar el error de tipado nulo
    local newMap = template:Clone() :: Model
    newMap.Parent = workspace
    
    _activeMapInstance = newMap
    _activeMapName = mapName

    _spawnDebugBillboard(mapName, newMap)
    print("🗺️ [WorldService] Mapa cargado: " .. mapName)
end

function WorldService.unloadMap()
    WorldService.destroyTestDummies()

    if _debugBillboard and _debugBillboard.Parent then
        (_debugBillboard.Parent :: Instance):Destroy()
    end
    _debugBillboard = nil

    if _activeMapInstance then
        (_activeMapInstance :: Model):Destroy()
        _activeMapInstance = nil
        _activeMapName = nil
        print("🗺️ [WorldService] Mapa descargado.")
    end
end

function WorldService.getActiveMap(): Model?
    return _activeMapInstance
end

function WorldService.getActiveMapName(): string?
    return _activeMapName
end

-- =============================================================================
-- API Pública — Test Dummies
-- =============================================================================

function WorldService.spawnTestDummies()
    local count = GameConstants.Maps.DEBUG_DUMMY_COUNT
    if count <= 0 then return end

    local killerCF = WorldService.getKillerSpawnCFrame()

    for i = 1, count do
        local dummy = Instance.new("Model")
        dummy.Name  = "TestDummy_" .. i

        local root = Instance.new("Part")
        root.Name     = "HumanoidRootPart"
        root.Size     = Vector3.new(2, 2, 1)
        root.Position = killerCF.Position + Vector3.new(math.random(-6, 6), 3, math.random(4, 10))
        root.BrickColor = BrickColor.new("Bright red")
        root.Parent = dummy

        local head = Instance.new("Part")
        head.Name   = "Head"
        head.Size   = Vector3.new(2, 1, 1)
        head.Position = root.Position + Vector3.new(0, 1.5, 0)
        head.BrickColor = BrickColor.new("Nougat")
        head.Parent = dummy

        local torso = Instance.new("Part")
        torso.Name   = "Torso"
        torso.Size   = Vector3.new(2, 2, 1)
        torso.Position = root.Position
        torso.BrickColor = BrickColor.new("Bright red")
        torso.Parent = dummy

        local hum = Instance.new("Humanoid")
        hum.MaxHealth  = GameConstants.Match.BOT_HEALTH
        hum.Health     = GameConstants.Match.BOT_HEALTH
        hum.WalkSpeed  = 0
        hum.JumpPower  = 0
        hum.Parent = dummy

        local tag = Instance.new("StringValue")
        tag.Name   = "SurvivorID"
        tag.Value  = "GONZACARBON"
        tag.Parent = dummy

        local bbGui = Instance.new("BillboardGui", head)
        bbGui.Size        = UDim2.new(0, 140, 0, 30)
        bbGui.StudsOffset = Vector3.new(0, 2, 0)
        bbGui.AlwaysOnTop = false

        local hpLabel = Instance.new("TextLabel", bbGui)
        hpLabel.Size = UDim2.new(1, 0, 1, 0)
        hpLabel.BackgroundTransparency = 1
        hpLabel.Font = Enum.Font.GothamBold
        hpLabel.TextSize = 16
        hpLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        hpLabel.Text = "Dummy " .. i .. " | HP: " .. GameConstants.Match.BOT_HEALTH

        hum.HealthChanged:Connect(function(newHp)
            if hpLabel.Parent then
                hpLabel.Text = string.format("Dummy %d | HP: %.0f", i, newHp)
                if newHp <= 0 then
                    hpLabel.Text = "Dummy " .. i .. " | MUERTO"
                    hpLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
                end
            end
        end)

        dummy.PrimaryPart = root
        dummy.Parent = workspace
        table.insert(_activeDummies, dummy)
    end
end

function WorldService.destroyTestDummies()
    for _, dummy in ipairs(_activeDummies) do
        if dummy and dummy.Parent then
            dummy:Destroy()
        end
    end
    table.clear(_activeDummies)
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
    if not preset then return end
    
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
    local lobby = workspace:FindFirstChild("Lobby_Prueba_1")
    if lobby then
        print("🌍 [WorldService] Lobby_Prueba_1 encontrado. Listo.")
    else
        warn("[WorldService] ⚠️ 'Lobby_Prueba_1' no está en Workspace.")
    end
end

return WorldService