-- src/client/Combat/CombatController.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local CombatState   = require(ReplicatedStorage.Shared.Combat.CombatState)
local CombatConfig  = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local VFXController = require(script.Parent.VFXController)

local CombatController = {}

local currentFSM    = nil
local requestAction = nil
local currentChar   = nil

local comboIndex = 0
local lastHitTime = 0
local comboLockedUntil = 0
local COMBO_WINDOW = 1.2
local MAX_COMBO = 3

-- ─── Helpers ──────────────────────────────────────────────────────

local function getRemote()
	if requestAction then return requestAction end
	local remotes = ReplicatedStorage.Shared:WaitForChild("Remotes", 10)
	if not remotes then warn("[CombatController] No se encontró Remotes"); return nil end
	local combatEvents = remotes:WaitForChild("CombatEvents", 10)
	if not combatEvents then warn("[CombatController] No se encontró CombatEvents"); return nil end
	requestAction = combatEvents:WaitForChild("RequestAction", 10)
	return requestAction
end

local function getLocalStamina()
	return Players.LocalPlayer:GetAttribute("Stamina") or CombatConfig.Stamina.MaxStamina
end

-- Verifica si el jugador tiene un item de curación equipado
local function tieneItemCuracion()
	if not currentChar then return false end
	local valor = currentChar:GetAttribute("ItemEquipado")
	return valor == "Curacion"
end

-- ─── Inicialización ───────────────────────────────────────────────

function CombatController:Initialize(character)
	currentChar   = character
	currentFSM    = CombatState.createMachine(character)
	requestAction = nil

	task.spawn(getRemote)

	currentFSM:Connect(function(newState, _oldState)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		if newState == CombatState.States.Attacking
		or newState == CombatState.States.Stunned then
			humanoid.WalkSpeed = 0

		elseif newState == CombatState.States.Dodging then
			humanoid.WalkSpeed = CombatConfig.Player.BaseWalkSpeed

		elseif newState == CombatState.States.Idle then
			humanoid.WalkSpeed = CombatConfig.Player.BaseWalkSpeed
		end
	end)

	print("[CLIENT] CombatController inicializado para", character.Name)
end

-- ─── Acciones ─────────────────────────────────────────────────────

function CombatController:RequestLightAttack()
	if not currentFSM then return end

	local now = tick()
	if now < comboLockedUntil then
		return
	end

	-- Bloqueado si tiene item de curación en mano
	if tieneItemCuracion() then
		print("[CLIENTE] No puedes atacar con un item de curación equipado.")
		return
	end

	if getLocalStamina() < CombatConfig.LightAttack.StaminaCost then
		print("[CLIENTE] Sin estamina para atacar.")
		return
	end

	if now - lastHitTime > COMBO_WINDOW then
		comboIndex = 0
	end

	comboIndex = math.min(comboIndex + 1, MAX_COMBO)
	lastHitTime = now

	if currentFSM:TransitionTo(CombatState.States.Attacking, CombatConfig.LightAttack.Cooldown + 0.3) then
		VFXController:PlayComboAnimation(comboIndex)
		local remote = getRemote()
		if remote then remote:FireServer("LightAttack", comboIndex) end
	end

	if comboIndex == MAX_COMBO then
		comboLockedUntil = now + CombatConfig.LightAttack.ComboFinishDelay
		comboIndex = 0
		lastHitTime = 0
	end
end

function CombatController:RequestDash()
	if not currentFSM then return end

	-- Bloqueado si tiene item de curación en mano
	if tieneItemCuracion() then
		print("[CLIENTE] No puedes esquivar con un item de curación equipado.")
		return
	end

	if getLocalStamina() < CombatConfig.Dash.StaminaCost then
		print("[CLIENTE] Sin estamina para esquivar.")
		return
	end

	if currentFSM:TransitionTo(CombatState.States.Dodging, CombatConfig.Dash.Duration) then
		VFXController:StartDashGhosts()

		local char    = Players.LocalPlayer.Character
		local hrp     = char and char:FindFirstChild("HumanoidRootPart")
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")

		if hrp and humanoid then
			local dir = humanoid.MoveDirection
			if dir.Magnitude == 0 then
				dir = hrp.CFrame.LookVector
			end
			dir = Vector3.new(dir.X, 0, dir.Z)
			if dir.Magnitude == 0 then
				dir = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
			end
			if dir.Magnitude > 0 then
				dir = dir.Unit
				local isAirborne = humanoid.FloorMaterial == Enum.Material.Air
				local dashForce = isAirborne and CombatConfig.Dash.AirForce or CombatConfig.Dash.GroundForce
				local currentVelocity = hrp.AssemblyLinearVelocity
				hrp.AssemblyLinearVelocity = Vector3.new(dir.X, 0, dir.Z) * dashForce + Vector3.new(0, currentVelocity.Y, 0)

				local impulseDuration = isAirborne and CombatConfig.Dash.AirImpulseDuration or CombatConfig.Dash.GroundImpulseDuration
				local bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
				bodyVelocity.Velocity = Vector3.new(dir.X, 0, dir.Z) * dashForce
				bodyVelocity.P = 1250
				bodyVelocity.Parent = hrp
				game:GetService("Debris"):AddItem(bodyVelocity, impulseDuration)
			end
		end

		local remote = getRemote()
		if remote then remote:FireServer("Dash") end
	end
end

return CombatController
