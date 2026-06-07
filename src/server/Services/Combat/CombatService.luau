-- src/server/Services/Combat/CombatService.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatState  = require(ReplicatedStorage.Shared.Combat.CombatState)
local StaminaService = require(script.Parent.StaminaService)

local CombatService = {}

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function getState(character)
	return character:GetAttribute("CombatState") or CombatState.States.Idle
end

local function setState(character, newState)
	character:SetAttribute("CombatState", newState)
end

-- Aplica un estado temporal y lo revierte a Idle después de `duration` segundos.
local function applyTemporaryState(character, newState, duration)
	setState(character, newState)
	task.delay(duration, function()
		if getState(character) == newState then
			setState(character, CombatState.States.Idle)
		end
	end)
end

-- ─── Handlers por acción ─────────────────────────────────────────────────────

local actionHandlers = {

	LightAttack = function(player, character)
		local currentState = getState(character)

		-- Validar transición usando la tabla compartida
		if not CombatState.canTransition(currentState, CombatState.States.Attacking) then
			return
		end

		if not StaminaService:TryConsumeStamina(player, CombatConfig.LightAttack.StaminaCost) then
			print("[SERVER] Ataque denegado (sin estamina):", player.Name)
			return
		end

		print("[SERVER] Ataque aprobado:", player.Name)
		applyTemporaryState(character, CombatState.States.Attacking, 0.5)
	end,

	Dash = function(player, character)
		local currentState = getState(character)

		if not CombatState.canTransition(currentState, CombatState.States.Dodging) then
			return
		end

		if not StaminaService:TryConsumeStamina(player, CombatConfig.Dash.StaminaCost) then
			print("[SERVER] Dash denegado (sin estamina):", player.Name)
			return
		end

		print("[SERVER] Dash aprobado:", player.Name)
		applyTemporaryState(character, CombatState.States.Dodging, CombatConfig.Dash.Duration)
	end,
}

-- ─── Entrada principal ───────────────────────────────────────────────────────

function CombatService:HandleActionRequest(player, actionType)
	local character = player.Character
	if not character then return end

	local handler = actionHandlers[actionType]
	if not handler then
		warn("[SERVER] Acción desconocida recibida:", actionType, "de", player.Name)
		return
	end

	handler(player, character)
end

function CombatService:Start(requestEvent)
	requestEvent.OnServerEvent:Connect(function(player, actionType)
		-- Validación básica del tipo antes de procesar
		if type(actionType) ~= "string" then return end
		self:HandleActionRequest(player, actionType)
	end)
	print("[SERVER] CombatService activo.")
end

return CombatService
