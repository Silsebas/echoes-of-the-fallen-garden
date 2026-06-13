-- src/server/Services/Combat/CombatService.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatState  = require(ReplicatedStorage.Shared.Combat.CombatState)
local StaminaService = require(script.Parent.StaminaService)
local HitboxService  = require(script.Parent.HitboxService)

local CombatService = {}

local sfxFolder = ReplicatedStorage.Shared:WaitForChild("Combat"):WaitForChild("SFX")
local DAMAGE_PER_HIT = {15, 20, 30}
local COMBO_WINDOW = 1.2
local MAX_COMBO = 3

local playerData = {}
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	playerData[player] = {combo = 0, lastHit = 0, debounce = false}
end)
Players.PlayerRemoving:Connect(function(player)
	playerData[player] = nil
end)

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

	LightAttack = function(player, character, requestedComboIndex)
		local currentState = getState(character)

		-- Validar transición usando la tabla compartida
		if not CombatState.canTransition(currentState, CombatState.States.Attacking) then
			return
		end

		local data = playerData[player]
		if not data then
			data = {combo = 0, lastHit = 0, debounce = false}
			playerData[player] = data
		end
		if data.debounce then return end

		if not StaminaService:TryConsumeStamina(player, CombatConfig.LightAttack.StaminaCost) then
			print("[SERVER] Ataque denegado (sin estamina):", player.Name)
			return
		end

		local now = tick()
		if (now - data.lastHit) > COMBO_WINDOW then
			data.combo = 0
		end

		data.combo = math.min(data.combo + 1, MAX_COMBO)
		data.lastHit = now
		data.debounce = true

		local actualCombo = data.combo
		local damage = DAMAGE_PER_HIT[actualCombo] or 15

		print("[SERVER] Ataque aprobado:", player.Name, "Combo:", actualCombo)
		applyTemporaryState(character, CombatState.States.Attacking, 0.5)

		task.delay(0.2, function()
			HitboxService.create(character, damage, function(targetModel, hitPos)
				local sfxName = "m1_" .. actualCombo
				local sfx = sfxFolder:FindFirstChild(sfxName)
				if sfx then
					local clone = sfx:Clone()
					clone.Parent = workspace
					clone:Play()
					game:GetService("Debris"):AddItem(clone, 2)
				end
			end)
		end)

		task.delay(0.5, function()
			if data then data.debounce = false end
		end)
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

function CombatService:HandleActionRequest(player, actionType, extraData)
	local character = player.Character
	if not character then return end

	local handler = actionHandlers[actionType]
	if not handler then
		warn("[SERVER] Acción desconocida recibida:", actionType, "de", player.Name)
		return
	end

	handler(player, character, extraData)
end

function CombatService:Start(requestEvent)
	requestEvent.OnServerEvent:Connect(function(player, actionType, extraData)
		-- Validación básica del tipo antes de procesar
		if type(actionType) ~= "string" then return end
		self:HandleActionRequest(player, actionType, extraData)
	end)
	print("[SERVER] CombatService activo.")
end

return CombatService
