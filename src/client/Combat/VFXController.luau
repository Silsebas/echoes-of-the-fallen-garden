-- src/client/Controllers/Combat/VFXController.lua
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local VFXController = {}

local loadedAnimations = {
	Combo1 = nil,
	Combo2 = nil,
	Combo3 = nil,
	Stun = nil
}

function VFXController:Initialize(character)
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Animaciones R6 Combo
	local animsIds = {
		Combo1 = "rbxassetid://94084345389206",
		Combo2 = "rbxassetid://93984961486267",
		Combo3 = "rbxassetid://115888566299429"
	}
	
	for key, id in pairs(animsIds) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		loadedAnimations[key] = animator:LoadAnimation(anim)
		loadedAnimations[key].Priority = Enum.AnimationPriority.Action
		loadedAnimations[key].Looped = false
	end

	local stunAnim = Instance.new("Animation")
	stunAnim.AnimationId = "rbxassetid://180436148" -- Stun R6

	loadedAnimations.Stun = animator:LoadAnimation(stunAnim)
	loadedAnimations.Stun.Priority = Enum.AnimationPriority.Action
end

function VFXController:PlayComboAnimation(comboIndex)
	local animKey = "Combo" .. tostring(comboIndex)
	local anim = loadedAnimations[animKey]
	
	if anim then
		anim:Stop()
		anim:Play()
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
