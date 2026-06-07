-- src/client/Combat/CombatController.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatState = require(ReplicatedStorage.Shared.Combat.CombatState)
local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local VFXController = require(script.Parent.VFXController)

local CombatController = {}
local currentFSM = nil

-- INICIALIZADOR
function CombatController:Initialize(character)
	currentFSM = CombatState.createMachine(character)
	
	-- ESCUCHAMOS LOS CAMBIOS DE ESTADO PARA MODIFICAR FÍSICAS
	currentFSM:Connect(function(newState, oldState)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		if newState == CombatState.States.Attacking or newState == CombatState.States.Stunned then
			-- Congelamos al jugador para darle peso al golpe
			humanoid.WalkSpeed = 0 
		elseif newState == CombatState.States.Idle then
			-- Devolvemos la velocidad a la normalidad usando el config corregido
			humanoid.WalkSpeed = CombatConfig.Player.BaseWalkSpeed
		end
	end)
	
	print("[CLIENT] CombatController conectado y escuchando físicas")
end

function CombatController:RequestLightAttack()
	if not currentFSM then return end 
	
	-- 1. EL CLIENTE REVISA SU PROPIA ESTAMINA ANTES DE ACTUAR
	local currentStamina = Players.LocalPlayer:GetAttribute("Stamina") or CombatConfig.Stamina.MaxStamina
	if currentStamina < CombatConfig.LightAttack.StaminaCost then
		print("[CLIENTE] No puedo atacar. Faltan fuerzas.")
		return -- Cortamos la ejecución aquí, no hay animación ni envío al servidor
	end
	
	if currentFSM:TransitionTo(CombatState.States.Attacking, 0.5) then
		VFXController:PlayAttackAnimation()
		
		local remotes = ReplicatedStorage.Shared:WaitForChild("Remotes")
		local requestAction = remotes:WaitForChild("CombatEvents"):WaitForChild("RequestAction")
		requestAction:FireServer("LightAttack")
	end
end

function CombatController:RequestDash()
	if not currentFSM then return end 
	
	-- 1. EL CLIENTE REVISA SU PROPIA ESTAMINA ANTES DE ACTUAR
	local currentStamina = Players.LocalPlayer:GetAttribute("Stamina") or CombatConfig.Stamina.MaxStamina
	if currentStamina < CombatConfig.Dash.StaminaCost then
		print("[CLIENTE] No puedo esquivar. Estamina agotada.")
		return -- Cortamos la ejecución aquí
	end
	
	if currentFSM:TransitionTo(CombatState.States.Dodging, CombatConfig.Dash.Duration) then
		VFXController:StartDashGhosts()
		
		local char = Players.LocalPlayer.Character
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		
		if hrp and humanoid then
			local moveDirection = humanoid.MoveDirection
			if moveDirection.Magnitude == 0 then
				moveDirection = -hrp.CFrame.LookVector
			end
			hrp.AssemblyLinearVelocity = moveDirection * CombatConfig.Dash.DashForce
		end
		
		local remotes = ReplicatedStorage.Shared:WaitForChild("Remotes")
		local requestAction = remotes:WaitForChild("CombatEvents"):WaitForChild("RequestAction")
		requestAction:FireServer("Dash")
	end
end

return CombatController