-- =============================================================================
-- EMANUEL_Handler.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local ExecutionSystem = require(ServerScriptService.Systems.ExecutionSystem)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local function handleMARCADOR(ctx)
    local char = ctx.char
    local root = ctx.root
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "Q", 30)

    local closestSurv = nil
    local minDistance = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("SurvivorID") then
            local otherRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if otherRoot then
                local dist = (otherRoot.Position - root.Position).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    closestSurv = p.Character
                end
            end
        end
    end

    if closestSurv then
        local markedVal = char:FindFirstChild("MarkedTarget")
        if markedVal then markedVal.Value = closestSurv end
        
        local hl = Instance.new("Highlight")
        hl.Name = "MarkedHighlight"
        hl.FillColor = Color3.fromRGB(255, 0, 0)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.Parent = closestSurv
        Debris:AddItem(hl, 15)
        print("👁️ [Emanuel] Objetivo marcado.")
    end
end

local function handleCAZADOR(ctx)
    local char = ctx.char
    local root = ctx.root
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "E", 25)

    local markedVal = char:FindFirstChild("MarkedTarget")
    if not markedVal or not markedVal.Value then return end

    local target = markedVal.Value
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = (targetRoot.Position - root.Position).Unit * 120
    bv.MaxForce = Vector3.new(1e5, 0, 1e5)
    bv.Parent = root
    Debris:AddItem(bv, 0.5)

    local conn
    conn = root.Touched:Connect(function(hit)
        if hit.Parent == target then
            conn:Disconnect()
            if bv.Parent then bv:Destroy() end
            ExecutionSystem.start(char, target)
        end
    end)
    task.delay(0.5, function() if conn then conn:Disconnect() end end)
end

local function handleEJECUCION_DIRECTA(ctx)
    local char = ctx.char
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "F", 60)

    local markedVal = char:FindFirstChild("MarkedTarget")
    if not markedVal or not markedVal.Value then return end

    local target = markedVal.Value
    local hum = target:FindFirstChild("Humanoid")
    
    if hum and (hum.Health / hum.MaxHealth) <= 0.3 then
        ExecutionSystem.start(char, target)
    end
end

return function(register)
    register("MARCADOR", handleMARCADOR)
    register("CAZADOR", handleCAZADOR)
    register("EJECUCION_DIRECTA", handleEJECUCION_DIRECTA)
end