-- src/ServerScriptService/TestInteraction.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("🧪 Buscando a PORO en el almacén del .rbxl...")

-- 1. Vamos al almacén y buscamos algo llamado "PORO"
local modeloPoro = ReplicatedStorage:FindFirstChild("PORO")

if modeloPoro then
    print("✅ ¡Encontré a PORO en el .rbxl!")
    
    -- 2. Le sacamos una copia (no usamos el original, el original se queda en la caja)
    local clonPoro = modeloPoro:Clone()
    
    -- 3. Lo ponemos en el mundo real (Workspace)
    clonPoro.Parent = workspace
    
    -- 4. Lo movemos un poco hacia arriba para que caiga
    clonPoro:PivotTo(CFrame.new(0, 10, -10))
    
    print("👾 ¡PORO ha sido invocado al mundo real!")
else
    warn("❌ No encontré ningún modelo llamado 'PORO' en ReplicatedStorage. ¿Gonzalo lo guardó en el .rbxl?")
end