-- =============================================================================
-- ExecutionSystem.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local ExecutionSystem = {}

function ExecutionSystem.start(killerChar: Model, victimChar: Model)
    local killerHum = killerChar:FindFirstChild("Humanoid")
    local victimHum = victimChar:FindFirstChild("Humanoid")
    local killerRoot = killerChar:FindFirstChild("HumanoidRootPart")
    local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")

    if not killerHum or not victimHum or not killerRoot or not victimRoot then return end
    
    -- Evitar dobles ejecuciones
    if victimChar:FindFirstChild("BeingExecuted") then return end
    local tag = Instance.new("BoolValue")
    tag.Name = "BeingExecuted"
    tag.Parent = victimChar

    -- Congelar a ambos
    killerHum.WalkSpeed = 0
    killerHum.JumpPower = 0
    killerRoot.Anchored = true

    victimHum.WalkSpeed = 0
    victimHum.JumpPower = 0
    victimRoot.Anchored = true

    -- Posicionar a la víctima frente al asesino mirando hacia él
    victimRoot.CFrame = CFrame.lookAt(
        killerRoot.Position + killerRoot.CFrame.LookVector * 4, 
        killerRoot.Position
    )

    -- VFX Sangriento
    local fx = Instance.new("Part")
    fx.Shape = Enum.PartType.Ball
    fx.Size = Vector3.new(1, 1, 1)
    fx.Position = victimRoot.Position
    fx.Color = Color3.fromRGB(150, 0, 0)
    fx.Material = Enum.Material.Neon
    fx.Anchored = true
    fx.CanCollide = false
    fx.Parent = workspace

    TweenService:Create(fx, TweenInfo.new(4), {Size = Vector3.new(20, 20, 20), Transparency = 1}):Play()
    game:GetService("Debris"):AddItem(fx, 4)

    local killerPlayer = game.Players:GetPlayerFromCharacter(killerChar)
    if killerPlayer then
        RemoteRegistry.KillExecution:FireClient(killerPlayer, "Killer", killerChar.KillerID.Value, victimChar.Name, 4)
    end

    -- Matar tras 4 segundos
    task.delay(4, function()
        if victimHum and victimHum.Parent then
            victimHum.Health = 0
        end
        if killerHum and killerHum.Parent then
            killerRoot.Anchored = false
            -- La velocidad la restaurará el StatusEffectSystem si tiene buffs, o ponemos un default
            killerHum.WalkSpeed = 20 
            killerHum.JumpPower = 50
        end
    end)
    print("💀 [ExecutionSystem] Ejecución iniciada: " .. killerChar.Name .. " a " .. victimChar.Name)
end

return ExecutionSystem