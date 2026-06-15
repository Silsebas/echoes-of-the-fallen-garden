-- src/server/Services/Combat/StaminaService.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)

local StaminaService = {}

-- userId -> { stamina, regenCooldownUntil }
local playersStamina = {}

local function getOrCreateData(player)
	local data = playersStamina[player.UserId]
	if data then
		return data
	end

	data = {
		stamina            = CombatConfig.Stamina.MaxStamina,
		regenCooldownUntil = 0,
		lastSprintTickAt   = 0,
	}
	playersStamina[player.UserId] = data
	player:SetAttribute("Stamina", data.stamina)
	return data
end

local function setStamina(player, data, stamina)
	data.stamina = math.clamp(stamina, 0, CombatConfig.Stamina.MaxStamina)
	player:SetAttribute("Stamina", data.stamina)
	return data.stamina
end

local function syncFromAttribute(player, data)
	local attrStamina = player:GetAttribute("Stamina")
	if type(attrStamina) == "number" then
		data.stamina = math.clamp(attrStamina, 0, CombatConfig.Stamina.MaxStamina)
	end

	return data.stamina
end

-- ─── Inicialización / Limpieza ───────────────────────────────────────────────

function StaminaService:InitializePlayer(player)
	playersStamina[player.UserId] = {
		stamina            = CombatConfig.Stamina.MaxStamina,
		regenCooldownUntil = 0,
		lastSprintTickAt   = 0,
	}
	player:SetAttribute("Stamina", CombatConfig.Stamina.MaxStamina)
	print("[STAMINA] Inicializado para", player.Name)
end

function StaminaService:CleanupPlayer(player)
	playersStamina[player.UserId] = nil
	print("[STAMINA] Limpiado para", player.Name)
end

-- ─── Consumo puntual (ataque, dash) ─────────────────────────────────────────

function StaminaService:TryConsumeStamina(player, amount)
	local data = getOrCreateData(player)
	if not data then return false end

	if data.stamina >= amount then
		data.regenCooldownUntil = os.clock() + CombatConfig.Stamina.RegenDelay
		setStamina(player, data, data.stamina - amount)
		return true
	end

	return false
end

-- ─── Consumo continuo (sprint) ───────────────────────────────────────────────
-- El cliente notifica cuánto tiempo lleva corriendo; el servidor descuenta.
-- Retorna la stamina actual tras el descuento (para que el cliente sepa si debe parar).

function StaminaService:ConsumeSprint(player, deltaTime)
	local data = getOrCreateData(player)
	if not data then return 0 end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return data.stamina
	end

	deltaTime = math.clamp(deltaTime, 0, 0.5)
	if deltaTime <= 0 or data.stamina <= 0 then
		return data.stamina
	end

	local cost = CombatConfig.Sprint.StaminaCostPerSecond * deltaTime
	data.regenCooldownUntil = os.clock() + CombatConfig.Stamina.RegenDelay
	return setStamina(player, data, data.stamina - cost)
end

-- ─── Consulta ────────────────────────────────────────────────────────────────

function StaminaService:GetStamina(player)
	local data = getOrCreateData(player)
	return syncFromAttribute(player, data)
end

-- ─── Bucle de Regeneración ───────────────────────────────────────────────────

local REGEN_TICK = 1

task.spawn(function()
	while true do
		task.wait(REGEN_TICK)
		local now = os.clock()

		for userId, data in pairs(playersStamina) do
			if now < data.regenCooldownUntil then continue end
			if data.stamina >= CombatConfig.Stamina.MaxStamina then continue end

			local player = Players:GetPlayerByUserId(userId)
			local newStamina = math.min(
				data.stamina + CombatConfig.Stamina.RegenRate,
				CombatConfig.Stamina.MaxStamina
			)

			if player then
				setStamina(player, data, newStamina)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	StaminaService:CleanupPlayer(player)
end)

return StaminaService
