-- src/server/Services/Combat/CombatService.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatState = require(ReplicatedStorage.Shared.Combat.CombatState)
local StaminaService = require(script.Parent.StaminaService)

local CombatService = {}

-- Esta función la llamaremos desde el Inicializador cuando se cree el RemoteEvent
function CombatService:Start(requestEvent)
	requestEvent.OnServerEvent:Connect(function(player, actionType)
		self:HandleActionRequest(player, actionType)
	end)
end

function CombatService:HandleActionRequest(player, actionType)
	local character = player.Character
	if not character then return end
	
	-- Leemos el estado actual del jugador (el servidor es la autoridad)
	local currentState = character:GetAttribute("CombatState") or CombatState.States.Idle
	
	if actionType == "LightAttack" then
		-- Validar si está en un estado válido para atacar
		if currentState == CombatState.States.Idle or currentState == CombatState.States.Dodging then
			-- Cobrar estamina
			if StaminaService:TryConsumeStamina(player, CombatConfig.LightAttack.StaminaCost) then
				-- Cambiar estado autoritativo
				character:SetAttribute("CombatState", CombatState.States.Attacking)
				print("[SERVER] Ataque aprobado para", player.Name)
				
				-- Aquí calcularemos la Hitbox (GetPartBoundsInBox) en el próximo Sprint
				
				-- Liberar el estado después del ataque
				task.delay(0.5, function()
					if character:GetAttribute("CombatState") == CombatState.States.Attacking then
						character:SetAttribute("CombatState", CombatState.States.Idle)
					end
				end)
			else
				print("[SERVER] Ataque denegado: Sin estamina -", player.Name)
			end
		end
		
	elseif actionType == "Dash" then
		if currentState == CombatState.States.Idle or currentState == CombatState.States.Attacking then
			if StaminaService:TryConsumeStamina(player, CombatConfig.Dash.StaminaCost) then
				character:SetAttribute("CombatState", CombatState.States.Dodging)
				print("[SERVER] Dash aprobado para", player.Name)
				
				task.delay(0.3, function()
					if character:GetAttribute("CombatState") == CombatState.States.Dodging then
						character:SetAttribute("CombatState", CombatState.States.Idle)
					end
				end)
			else
				print("[SERVER] Dash denegado: Sin estamina -", player.Name)
			end
		end
	end
end

return CombatService