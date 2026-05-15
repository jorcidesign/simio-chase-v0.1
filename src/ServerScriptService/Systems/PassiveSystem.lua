-- =============================================================================
-- PassiveSystem.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)

local PassiveSystem = {}

local _killerPassives = {
    PORO = function(char, hum)
        if not char:FindFirstChild("RageMeter") then
            local rm = Instance.new("IntValue")
            rm.Name = "RageMeter"
            rm.Value = 0
            rm.Parent = char
        end
        local rmUsed = Instance.new("BoolValue")
        rmUsed.Name = "RageModeUsed"
        rmUsed.Value = false
        rmUsed.Parent = char

        -- GAP-24: Trail Rojo Slow
        task.spawn(function()
            while char and char.Parent do
                local root = char:FindFirstChild("HumanoidRootPart")
                if root and hum.MoveDirection.Magnitude > 0 then
                    local trail = Instance.new("Part", workspace)
                    trail.Size = Vector3.new(4, 0.5, 4)
                    trail.Position = root.Position - Vector3.new(0, 2.5, 0)
                    trail.Color = Color3.fromRGB(255, 100, 100)
                    trail.Material = Enum.Material.Neon
                    trail.Transparency = 0.7
                    trail.Anchored = true
                    trail.CanCollide = false
                    
                    local conn = trail.Touched:Connect(function(hit)
                        local vc = hit.Parent
                        if vc and vc:FindFirstChild("SurvivorID") then
                            StatusEffectSystem.apply(vc, StatusEffectType.SLOW, 12, 3)
                        end
                    end)
                    
                    game:GetService("Debris"):AddItem(trail, 3)
                    task.delay(3, function() if conn then conn:Disconnect() end end)
                end
                task.wait(0.3)
            end
        end)
    end,
    JALY = function(char, hum)
        local frenzy = Instance.new("BoolValue")
        frenzy.Name = "FrenzyActive"
        frenzy.Value = false
        frenzy.Parent = char
        
        local combo = Instance.new("IntValue")
        combo.Name = "ComboHits"
        combo.Value = 0
        combo.Parent = char
    end,
    AUGUSTO = function(char, hum)
        local mudAura = Instance.new("BoolValue")
        mudAura.Name = "MudAuraActive"
        mudAura.Value = false
        mudAura.Parent = char
    end,
    MIGUEL = function(char, hum)
        hum.MaxHealth = 350
        hum.Health = 350
    end,
    EMANUEL = function(char, hum)
        local marked = Instance.new("ObjectValue")
        marked.Name = "MarkedTarget"
        marked.Parent = char

        local frenzy = Instance.new("BoolValue")
        frenzy.Name = "FrenzyActive"
        frenzy.Value = false
        frenzy.Parent = char
    end
}

local _survivorPassives = {
    SURI = function(char, hum)
        hum.MaxHealth = 140
        hum.Health = 140
    end,
    SIU = function(char, hum)
        local shield = Instance.new("BoolValue")
        shield.Name = "ShieldReady"
        shield.Value = true
        shield.Parent = char
    end,
    NARIZTOTELES = function(char, hum)
        local counterS = Instance.new("BoolValue")
        counterS.Name = "CounterSuccess"
        counterS.Value = false
        counterS.Parent = char
    end,
    VACUMING = function(char, hum)
        task.spawn(function()
            while char and char.Parent do
                local root = char:FindFirstChild("HumanoidRootPart")
                if root and root.AssemblyLinearVelocity.Magnitude < 0.5 then
                    hum.Health = math.min(hum.MaxHealth, hum.Health + 1)
                end
                task.wait(1)
            end
        end)
    end,
    RICALY = function(char, hum)
        task.spawn(function()
            while char and char.Parent do
                local root = char:FindFirstChild("HumanoidRootPart")
                if root and root.AssemblyLinearVelocity.Magnitude > 0.5 then
                    local part = Instance.new("Part")
                    part.Size = Vector3.new(1, 0.2, 1)
                    part.Position = root.Position - Vector3.new(0, 2.5, 0)
                    part.Color = Color3.fromRGB(0, 255, 0)
                    part.Material = Enum.Material.Neon
                    part.Anchored = true
                    part.CanCollide = false
                    
                    local tag = Instance.new("StringValue")
                    tag.Name = "OnlyKillerVisible"
                    tag.Parent = part
                    
                    part.Parent = workspace
                    game:GetService("Debris"):AddItem(part, 3)
                end
                task.wait(0.2)
            end
        end)
    end,
    CACHETES = function(char, hum)
        local secondLife = Instance.new("BoolValue")
        secondLife.Name = "SecondLifeAvailable"
        secondLife.Value = true
        secondLife.Parent = char

        local inSecondLife = Instance.new("BoolValue")
        inSecondLife.Name = "InSecondLife"
        inSecondLife.Value = false
        inSecondLife.Parent = char
        
        local spawnPoint = Instance.new("CFrameValue")
        spawnPoint.Name = "SpawnPoint"
        spawnPoint.Parent = char
    end
}

function PassiveSystem.initialize(char: Model, role: string, characterId: string)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if role == "Killer" then
        local initFn = _killerPassives[characterId]
        if initFn then initFn(char, hum) end
    elseif role == "Survivor" then
        local initFn = _survivorPassives[characterId]
        if initFn then initFn(char, hum) end
    end
    print(string.format("✨ [PassiveSystem] Pasivas inicializadas para %s (%s)", characterId, role))
end

return PassiveSystem