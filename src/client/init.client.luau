local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local CombatState = require(ReplicatedStorage.Shared.CombatState)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local combatFSM = nil

-- Preloaded Animation Tracks
local attackTrack = nil
local stunTrack = nil

-- Visual Effects Helper Functions

local function createDodgeGhost(char)
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
				Transparency = 1,
				Size = child.Size * 0.8
			})
			tween:Play()
			tween.Completed:Connect(function()
				ghost:Destroy()
			end)
		end
	end
end

local function debugCharacterRig(char)
	print("[CLIENT] debugCharacterRig: begin")
	for _, desc in ipairs(char:GetDescendants()) do
		if desc:IsA("Motor6D") then
			print(string.format("[CLIENT] debugCharacterRig: Motor6D %s part0=%s part1=%s", desc.Name, desc.Part0 and desc.Part0.Name or "nil", desc.Part1 and desc.Part1.Name or "nil"))
		elseif desc:IsA("Weld") or desc:IsA("WeldConstraint") then
			print(string.format("[CLIENT] debugCharacterRig: %s %s part0=%s part1=%s", desc.ClassName, desc.Name, desc.Part0 and desc.Part0.Name or "nil", desc.Part1 and desc.Part1.Name or "nil"))
		elseif desc:IsA("BasePart") then
			if desc.Name:lower():find("right") or desc.Name:lower():find("upperarm") or desc.Name:lower():find("hand") then
				print(string.format("[CLIENT] debugCharacterRig: right part %s", desc.Name))
			end
		end
	end
	print("[CLIENT] debugCharacterRig: end")
end

local function findRightShoulder(char)
	local rightMotors = {}
	local anyMotors = {}
	for _, motor in ipairs(char:GetDescendants()) do
		if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 then
			local part0 = motor.Part0.Name
			local part1 = motor.Part1.Name
			local part0lower = part0:lower()
			local part1lower = part1:lower()
			local motorNameLower = motor.Name:lower()
			local isTorso = part0lower:find("torso") or part1lower:find("torso")
			local isRight = part0lower:find("right") or part1lower:find("right") or motorNameLower:find("right")
			local isArm = part0lower:find("arm") or part1lower:find("arm") or part0lower:find("hand") or part1lower:find("hand")
			if isTorso and isRight and isArm then
				table.insert(rightMotors, motor)
			end
			table.insert(anyMotors, {motor = motor, part0 = part0, part1 = part1})
		end
	end

	for _, entry in ipairs(anyMotors) do
		print(string.format("[CLIENT] findRightShoulder: motor=%s part0=%s part1=%s", entry.motor.Name, entry.part0, entry.part1))
	end

	for _, motor in ipairs(rightMotors) do
		print(string.format("[CLIENT] findRightShoulder: right motor candidate=%s", motor.Name))
	end

	for _, motor in ipairs(rightMotors) do
		local motorName = motor.Name:lower()
		if motorName:find("right") and motorName:find("shoulder") then
			print("[CLIENT] findRightShoulder: selected motor by name", motor.Name)
			return motor
		end
	end

	if #rightMotors > 0 then
		print("[CLIENT] findRightShoulder: selected first right motor fallback", rightMotors[1].Name)
		return rightMotors[1]
	end

	warn("[CLIENT] findRightShoulder: no right shoulder-like Motor6D found")
	return nil
end

local function playAttackPartFallback(char)
	local possibleNames = {"RightUpperArm", "RightHand", "Right Arm", "Right Wrist", "RightLowerArm"}
	local armPart
	for _, name in ipairs(possibleNames) do
		armPart = char:FindFirstChild(name)
		if armPart and armPart:IsA("BasePart") then
			print(string.format("[CLIENT] playAttackPartFallback: selected arm part %s", armPart.Name))
			break
		end
	end
	if not armPart then
		warn("[CLIENT] playAttackPartFallback: no right arm part found")
		return false
	end

	local originalCFrame = armPart.CFrame
	local punchCFrame = originalCFrame * CFrame.Angles(math.rad(-40), math.rad(20), math.rad(10)) * CFrame.new(0, 0, -0.5)
	local returnCFrame = originalCFrame

	local punchTween = TweenService:Create(armPart, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = punchCFrame})
	local returnTween = TweenService:Create(armPart, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = returnCFrame})

	punchTween:Play()
	punchTween.Completed:Connect(function()
		returnTween:Play()
	end)

	return true
end

local function playAttackPose(char)
	local rightShoulder = findRightShoulder(char)
	if not rightShoulder then
		warn("[CLIENT] playAttackPose: right shoulder motor not found")
		debugCharacterRig(char)
		if playAttackPartFallback(char) then
			print("[CLIENT] playAttackPose: fallback part movement applied")
		end
		return
	end

	print(string.format("[CLIENT] playAttackPose: found motor %s, Part0=%s, Part1=%s", rightShoulder.Name, rightShoulder.Part0.Name, rightShoulder.Part1.Name))

	local originalC0 = rightShoulder.C0
	local punchC0 = originalC0 * CFrame.Angles(math.rad(-60), math.rad(15), math.rad(25))

	local forwardTween = TweenService:Create(rightShoulder, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {C0 = punchC0})
	local backTween = TweenService:Create(rightShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {C0 = originalC0})

	forwardTween:Play()
	forwardTween.Completed:Connect(function()
		backTween:Play()
	end)
end

local function playAttackVisuals(char)
	-- Play the preloaded animation track if available (debug: show IsPlaying)
	if attackTrack then
		local ok, before = pcall(function() return attackTrack.IsPlaying end)
		print("[CLIENT] playAttackVisuals: before Play, IsPlaying=", ok and tostring(before) or "error")
		attackTrack:Play()
		task.delay(0.05, function()
			local ok2, after = pcall(function() return attackTrack.IsPlaying end)
			print("[CLIENT] playAttackVisuals: after Play, IsPlaying=", ok2 and tostring(after) or "error")
		end)
	else
		warn("[CLIENT] attackTrack no está cargada")
	end

	playAttackPose(char)
	
	-- Glowing Slash part in front of the character
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local slash = Instance.new("Part")
		slash.Size = Vector3.new(4, 0.2, 4)
		slash.Color = Color3.fromRGB(255, 120, 0)
		slash.Material = Enum.Material.Neon
		slash.CanCollide = false
		slash.Anchored = true
		slash.CFrame = hrp.CFrame * CFrame.new(0, 0, -2.5) * CFrame.Angles(math.rad(15), 0, math.rad(45))
		slash.Parent = workspace
		
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = slash
		
		local tween = TweenService:Create(slash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.1, 0.1, 0.1),
			Transparency = 1,
			CFrame = slash.CFrame * CFrame.new(2, 0, -1) * CFrame.Angles(0, math.rad(60), 0)
		})
		tween:Play()
		tween.Completed:Connect(function()
			slash:Destroy()
		end)
	end
end

local function playStunVisuals(char, duration)
	-- Play preloaded stun track
	if stunTrack then
		stunTrack:Play()
	end
	
	-- Dizzy Stars above head
	local head = char:FindFirstChild("Head")
	local starsAttachment = nil
	local particleEmitter = nil
	if head then
		starsAttachment = Instance.new("Attachment")
		starsAttachment.Position = Vector3.new(0, 1.5, 0)
		starsAttachment.Parent = head
		
		particleEmitter = Instance.new("ParticleEmitter")
		particleEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 230, 0))
		particleEmitter.Size = NumberSequence.new(0.4, 0.1)
		particleEmitter.Lifetime = NumberRange.new(0.4)
		particleEmitter.Rate = 25
		particleEmitter.Speed = NumberRange.new(1, 2)
		particleEmitter.SpreadAngle = Vector2.new(180, 180)
		particleEmitter.Parent = starsAttachment
	end
	
	-- Red color flash
	local originalColors = {}
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("BasePart") then
			originalColors[child] = child.Color
			child.Color = Color3.fromRGB(255, 60, 60)
		end
	end
	
	-- Camera shake
	local camera = workspace.CurrentCamera
	local shaking = true
	task.spawn(function()
		local count = 0
		while shaking and count < 15 do
			camera.CFrame = camera.CFrame * CFrame.new(math.random(-3, 3)/10, math.random(-3, 3)/10, 0)
			task.wait(0.04)
			count = count + 1
		end
	end)
	
	task.delay(duration, function()
		shaking = false
		if stunTrack then
			stunTrack:Stop()
		end
		if starsAttachment then
			starsAttachment:Destroy()
		end
		for part, color in pairs(originalColors) do
			if part and part.Parent then
				part.Color = color
			end
		end
	end)
end

local animationAssets = {
	attack = {
		[Enum.HumanoidRigType.R15] = "rbxassetid://180435571", -- Replace with your R15 attack animation asset
		[Enum.HumanoidRigType.R6] = "rbxassetid://180435571", -- Replace with your R6 attack animation asset if needed
	},
	stun = {
		[Enum.HumanoidRigType.R15] = "rbxassetid://180436148", -- Replace with your R15 stun animation asset
		[Enum.HumanoidRigType.R6] = "rbxassetid://180436148", -- Replace with your R6 stun animation asset if needed
	},
}

local function getRigTypeName(humanoid)
	if not humanoid then
		return "Unknown"
	end

	local rigType = humanoid.RigType
	if rigType == Enum.HumanoidRigType.R6 then
		return "R6"
	elseif rigType == Enum.HumanoidRigType.R15 then
		return "R15"
	end
	return "Unknown"
end

local function getAnimationIdForRig(kind, rigType)
	if animationAssets[kind] and animationAssets[kind][rigType] then
		return animationAssets[kind][rigType]
	end
	-- Fallback to a generic asset
	if kind == "attack" then
		return "rbxassetid://507724215"
	elseif kind == "stun" then
		return "rbxassetid://507724353"
	end
	return ""
end

-- Robust animation loader with fallback and debug
local function loadAnimationTrack(animator, animationId, fallbackId)
	if not animator then
		warn("[CLIENT] loadAnimationTrack: animator is nil")
		return nil
	end

	local function tryLoad(id)
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			pcall(function()
				track.Priority = Enum.AnimationPriority.Action
			end)
			print(string.format("[CLIENT] Loaded animation %s", id))
			return track
		else
			warn(string.format("[CLIENT] Failed to load animation %s", id))
			return nil
		end
	end

	local track = tryLoad(animationId)
	if not track and fallbackId then
		track = tryLoad(fallbackId)
	end
	return track
end

-- FSM Initialization

local function setupCombatFSM(char)
	character = char
	combatFSM = CombatState.createMachine(character)
	
	-- Load animations onto the character's Animator
	local humanoid = char:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	local rigName = getRigTypeName(humanoid)
	print(string.format("[CLIENT] Detected rig type: %s", rigName))

	if animator then
		local attackId = getAnimationIdForRig("attack", humanoid.RigType)
		local stunId = getAnimationIdForRig("stun", humanoid.RigType)
		local fallbackAttackId = (humanoid.RigType == Enum.HumanoidRigType.R6) and animationAssets.attack[Enum.HumanoidRigType.R15] or animationAssets.attack[Enum.HumanoidRigType.R6]
		local fallbackStunId = (humanoid.RigType == Enum.HumanoidRigType.R6) and animationAssets.stun[Enum.HumanoidRigType.R15] or animationAssets.stun[Enum.HumanoidRigType.R6]

		attackTrack = loadAnimationTrack(animator, attackId, fallbackAttackId)
		stunTrack = loadAnimationTrack(animator, stunId, fallbackStunId)
		if not attackTrack then
			warn("[CLIENT] attackTrack not available after attempts")
		end
		if not stunTrack then
			warn("[CLIENT] stunTrack not available after attempts")
		end
	else
		warn("[CLIENT] Animator not found on humanoid")
	end
	
	combatFSM:Connect(function(newState, oldState)
		print(string.format("[CLIENT] State changed: %s -> %s", oldState, newState))
		
		if newState == CombatState.States.Attacking then
			playAttackVisuals(char)
		elseif newState == CombatState.States.Dodging then
			-- Spawn ghost trail during dodge duration
			local active = true
			task.delay(0.3, function() active = false end)
			task.spawn(function()
				while active do
					createDodgeGhost(char)
					task.wait(0.05)
				end
			end)
		elseif newState == CombatState.States.Stunned then
			playStunVisuals(char, 1.5)
		end
	end)
	
	character.AttributeChanged:Connect(function(attributeName)
		if attributeName == "CombatState" then
			local serverState = character:GetAttribute("CombatState")
			if serverState == CombatState.States.Stunned and combatFSM:GetState() ~= CombatState.States.Stunned then
				print("[CLIENT] Server forced Stunned state!")
				combatFSM:TransitionTo(CombatState.States.Stunned, 1.5)
			end
		end
	end)
	
	print("[CLIENT] Combat State Machine initialized for " .. char.Name)
end

if character then
	setupCombatFSM(character)
end
player.CharacterAdded:Connect(setupCombatFSM)

-- Input Listening
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not combatFSM then return end
	
	local currentState = combatFSM:GetState()
	
	-- Left click to attack
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		print("[CLIENT] Attempting to attack...")
		local success = combatFSM:TransitionTo(CombatState.States.Attacking, 0.5) -- 0.5 seconds attack duration
		if success then
			print("[CLIENT] Attack started successfully!")
		else
			warn(string.format("[CLIENT] Cannot attack! Current state: %s", currentState))
		end
	
	-- Q key to dodge
	elseif input.KeyCode == Enum.KeyCode.Q then
		print("[CLIENT] Attempting to dodge...")
		local success = combatFSM:TransitionTo(CombatState.States.Dodging, 0.3) -- 0.3 seconds dodge duration
		if success then
			print("[CLIENT] Dodge started successfully!")
			
			-- Dash impulse (physics)
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoidRootPart and humanoid then
				local moveDirection = humanoid.MoveDirection
				if moveDirection.Magnitude == 0 then
					moveDirection = -humanoidRootPart.CFrame.LookVector
				end
				
				local bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.Velocity = (moveDirection * 40) + Vector3.new(0, 2, 0)
				bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
				bodyVelocity.Parent = humanoidRootPart
				
				task.delay(0.2, function()
					bodyVelocity:Destroy()
				end)
			end
		else
			warn(string.format("[CLIENT] Cannot dodge! Current state: %s", currentState))
		end
		
	-- H key to simulate getting Stunned
	elseif input.KeyCode == Enum.KeyCode.H then
		print("[CLIENT] Simulating stun (hit by enemy)...")
		local success = combatFSM:TransitionTo(CombatState.States.Stunned, 1.5) -- 1.5 seconds stun
		if success then
			print("[CLIENT] Stunned!")
		else
			warn(string.format("[CLIENT] Cannot be stunned! Current state: %s", currentState))
		end
	end
end)



