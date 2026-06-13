local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local HitboxService = {}

function HitboxService.create(character, damage, onHit)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local vfxFolder = Workspace:FindFirstChild("VFX")
    if not vfxFolder then
        vfxFolder = Instance.new("Folder")
        vfxFolder.Name = "VFX"
        vfxFolder.Parent = Workspace
    end

    local hb = Instance.new("Part")
    hb.Name = "Hitbox"
    hb.Size = Vector3.new(5, 5, 5)
    hb.Anchored = true
    hb.CanCollide = false
    hb.Transparency = 1
    hb.CastShadow = false
    hb.Parent = vfxFolder
    hb.CFrame = rootPart.CFrame * CFrame.new(0, 0, -3.5)

    local hit = {}
    local connection
    connection = hb.Touched:Connect(function(part)
        local model = part:FindFirstAncestorOfClass("Model")
        if not model or model == character then return end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end
        if hit[model] then return end
        hit[model] = true
        humanoid:TakeDamage(damage)
        if onHit then onHit(model, hb.Position) end
    end)

    Debris:AddItem(hb, 0.5)
    hb.Destroying:Connect(function() connection:Disconnect() end)
    return hb
end

return HitboxService
