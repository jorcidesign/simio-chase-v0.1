-- =============================================================================
-- RagdollSystem.lua
-- =============================================================================
local RagdollSystem = {}

local function createRagdoll(character)
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.BreakJointsOnDeath = false
    end

    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("Motor6D") and desc.Name ~= "Root" then
            local part0 = desc.Part0
            local part1 = desc.Part1
            if part0 and part1 then
                local a0 = Instance.new("Attachment")
                a0.CFrame = desc.C0
                a0.Parent = part0
                
                local a1 = Instance.new("Attachment")
                a1.CFrame = desc.C1
                a1.Parent = part1
                
                local socket = Instance.new("BallSocketConstraint")
                socket.Attachment0 = a0
                socket.Attachment1 = a1
                socket.Parent = part0
                
                -- Añadir colisión ligera para que no atraviesen el piso
                local collision = Instance.new("NoCollisionConstraint")
                collision.Part0 = part0
                collision.Part1 = part1
                collision.Parent = part0

                desc:Destroy()
            end
        end
    end
    print("💀 [Ragdoll] " .. character.Name .. " convertido en Ragdoll.")
end

function RagdollSystem.Start()
    local ServerEventBus = require(game:GetService("ServerScriptService").Network.ServerEventBus)
    
    -- Aplicar ragdoll a la víctima
    ServerEventBus.SurvivorKilled:Connect(function(victimPlayer)
        if victimPlayer.Character then
            createRagdoll(victimPlayer.Character)
        end
    end)

    ServerEventBus.KillerKilled:Connect(function(killerPlayer)
        if killerPlayer.Character then
            createRagdoll(killerPlayer.Character)
        end
    end)
end

return RagdollSystem