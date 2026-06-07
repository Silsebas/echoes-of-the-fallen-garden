-- src/client/Controllers/Combat/VFXController.lua
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local VFXController = {}

-- Variables para guardar las animaciones cargadas
local loadedAnimations = {
	Attack = nil,
	Stun = nil
}

-- Función auxiliar para inicializar las animaciones cuando el personaje aparece
function VFXController:Initialize(character)
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	
	-- IDs de prueba (puedes cambiarlos luego por los de tus rigs definitivos)
	local attackAnim = Instance.new("Animation")
	attackAnim.AnimationId = "rbxassetid://522635514"
	
	local stunAnim = Instance.new("Animation")
	stunAnim.AnimationId = "rbxassetid://180436148"
	
	loadedAnimations.Attack = animator:LoadAnimation(attackAnim)
	loadedAnimations.Stun = animator:LoadAnimation(stunAnim)
end

function VFXController:PlayAttackAnimation()
	if loadedAnimations.Attack then
		loadedAnimations.Attack:Play()
	end
	
	-- Aquí puedes agregar el destello naranja de tu código original
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		-- Ejemplo del trail o destello
		local slash = Instance.new("Part")
		slash.Size = Vector3.new(4, 0.2, 4)
		slash.Color = Color3.fromRGB(255, 120, 0)
		slash.Material = Enum.Material.Neon
		slash.CanCollide = false
		slash.Anchored = true
		slash.CFrame = hrp.CFrame * CFrame.new(0, 0, -2.5) * CFrame.Angles(math.rad(15), 0, math.rad(45))
		slash.Parent = workspace
		
		TweenService:Create(slash, TweenInfo.new(0.25), {
			Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1
		}):Play()
		
		task.delay(0.25, function() slash:Destroy() end)
	end
end

function VFXController:StartDashGhosts()
	local char = Players.LocalPlayer.Character
	if not char then return end
	
	local active = true
	task.delay(0.3, function() active = false end)
	
	task.spawn(function()
		while active do
			for _, child in ipairs(char:GetChildren()) do
				if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
					local ghost = Instance.new("Part")
					ghost.Size = child.Size
					ghost.CFrame = child.CFrame
					ghost.Color = Color3.fromRGB(0, 180, 255)
					ghost.Material = Enum.Material.Neon
					ghost.Transparency = 0.6
					ghost.CanCollide = false
					ghost.Anchored = true
					ghost.Parent = workspace
					
					local tween = TweenService:Create(ghost, TweenInfo.new(0.25), {
						Transparency = 1, Size = child.Size * 0.8
					})
					tween:Play()
					tween.Completed:Connect(function() ghost:Destroy() end)
				end
			end
			task.wait(0.05)
		end
	end)
end

return VFXController