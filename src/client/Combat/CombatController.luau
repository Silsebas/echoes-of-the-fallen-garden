-- src/client/Combat/CombatController.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local CombatState  = require(ReplicatedStorage.Shared.Combat.CombatState)
local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local VFXController = require(script.Parent.VFXController)

local CombatController = {}

local currentFSM     = nil
local requestAction  = nil  -- Remote cacheado, se resuelve una sola vez

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function getRemote()
	if requestAction then return requestAction end

	local remotes = ReplicatedStorage.Shared:WaitForChild("Remotes", 10)
	if not remotes then
		warn("[CombatController] No se encontró la carpeta Remotes")
		return nil
	end

	local combatEvents = remotes:WaitForChild("CombatEvents", 10)
	if not combatEvents then
		warn("[CombatController] No se encontró CombatEvents")
		return nil
	end

	requestAction = combatEvents:WaitForChild("RequestAction", 10)
	return requestAction
end

local function getLocalStamina()
	return Players.LocalPlayer:GetAttribute("Stamina") or CombatConfig.Stamina.MaxStamina
end

-- ─── Inicialización ──────────────────────────────────────────────────────────

function CombatController:Initialize(character)
	currentFSM   = CombatState.createMachine(character)
	requestAction = nil  -- Resetear caché al respawnear

	-- Resolver el remote lo antes posible (en background)
	task.spawn(getRemote)

	-- Reaccionar a cambios de estado para ajustar físicas
	currentFSM:Connect(function(newState, _oldState)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		if newState == CombatState.States.Attacking
		or newState == CombatState.States.Stunned then
			humanoid.WalkSpeed = 0

		elseif newState == CombatState.States.Dodging then
			-- Durante el dash el jugador conserva velocidad (la impulsa el código más abajo)
			humanoid.WalkSpeed = CombatConfig.Player.BaseWalkSpeed

		elseif newState == CombatState.States.Idle then
			humanoid.WalkSpeed = CombatConfig.Player.BaseWalkSpeed
		end
	end)

	print("[CLIENT] CombatController inicializado para", character.Name)
end

-- ─── Acciones ────────────────────────────────────────────────────────────────

function CombatController:RequestLightAttack()
	if not currentFSM then return end

	-- Pre-check de estamina en cliente (evita round-trips inútiles)
	if getLocalStamina() < CombatConfig.LightAttack.StaminaCost then
		print("[CLIENTE] Sin estamina para atacar.")
		return
	end

	if currentFSM:TransitionTo(CombatState.States.Attacking, CombatConfig.LightAttack.Cooldown + 0.3) then
		VFXController:PlayAttackAnimation()

		local remote = getRemote()
		if remote then
			remote:FireServer("LightAttack")
		end
	end
end

function CombatController:RequestDash()
	if not currentFSM then return end

	if getLocalStamina() < CombatConfig.Dash.StaminaCost then
		print("[CLIENTE] Sin estamina para esquivar.")
		return
	end

	if currentFSM:TransitionTo(CombatState.States.Dodging, CombatConfig.Dash.Duration) then
		VFXController:StartDashGhosts()

		-- Aplicar impulso de dash
		local char = Players.LocalPlayer.Character
		local hrp      = char and char:FindFirstChild("HumanoidRootPart")
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")

		if hrp and humanoid then
			local dir = humanoid.MoveDirection
			if dir.Magnitude == 0 then
				dir = -hrp.CFrame.LookVector
			end
			hrp.AssemblyLinearVelocity = dir * CombatConfig.Dash.DashForce
		end

		local remote = getRemote()
		if remote then
			remote:FireServer("Dash")
		end
	end
end

return CombatController
