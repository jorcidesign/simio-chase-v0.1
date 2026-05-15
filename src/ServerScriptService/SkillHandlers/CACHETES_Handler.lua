-- =============================================================================
-- CACHETES_Handler.lua
-- =============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StatusEffectSystem = require(ServerScriptService.Systems.StatusEffectSystem)
local StatusEffectType = require(ReplicatedStorage.Enums.StatusEffectType)
local RemoteRegistry = require(ReplicatedStorage.Network.RemoteRegistry)

local function handleESCUDO_CACHETES(ctx)
    local char = ctx.char
    local hum = ctx.hum
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "Q", 50)

    StatusEffectSystem.apply(char, StatusEffectType.INVINCIBLE, 0, 8)
    hum.JumpPower = 0

    task.delay(8, function()
        if hum and hum.Parent then
            hum.JumpPower = 50
        end
    end)
end

local function handleRENACER(ctx)
    local char = ctx.char
    local root = ctx.root
    local player = ctx.player

    ctx._castConfirmed = true
    RemoteRegistry.SkillCastConfirmed:FireClient(player, "E", 999) -- One time use

    local spawnPoint = char:FindFirstChild("SpawnPoint")
    if spawnPoint then
        spawnPoint.Value = root.CFrame
        
        local secondLife = char:FindFirstChild("SecondLifeAvailable")
        if secondLife then
            secondLife.Value = true
        end
        print("🛡️ [Cachetes] Punto de renacimiento guardado.")
    end
end

return function(register)
    register("ESCUDO_CACHETES", handleESCUDO_CACHETES)
    register("RENACER", handleRENACER)
end