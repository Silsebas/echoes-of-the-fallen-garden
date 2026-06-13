-- src/server/Services/Combat/StaminaService.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)

local StaminaService = {}

-- userId -> { stamina, regenCooldownUntil }
local playersStamina = {}

-- ─── Inicialización / Limpieza ───────────────────────────────────────────────

function StaminaService:InitializePlayer(player)
	playersStamina[player.UserId] = {
		stamina            = CombatConfig.Stamina.MaxStamina,
		regenCooldownUntil = 0,
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
	local data = playersStamina[player.UserId]
	if not data then return false end

	if data.stamina >= amount then
		data.stamina = data.stamina - amount
		data.regenCooldownUntil = os.clock() + CombatConfig.Stamina.RegenDelay
		player:SetAttribute("Stamina", data.stamina)
		return true
	end

	return false
end

-- ─── Consumo continuo (sprint) ───────────────────────────────────────────────
-- El cliente notifica cuánto tiempo lleva corriendo; el servidor descuenta.
-- Retorna la stamina actual tras el descuento (para que el cliente sepa si debe parar).

function StaminaService:ConsumeSprint(player, deltaTime)
	local data = playersStamina[player.UserId]
	if not data then return 0 end

	local cost = CombatConfig.Sprint.StaminaCostPerSecond * deltaTime
	data.stamina = math.max(data.stamina - cost, 0)
	data.regenCooldownUntil = os.clock() + CombatConfig.Stamina.RegenDelay
	player:SetAttribute("Stamina", data.stamina)
	return data.stamina
end

-- ─── Consulta ────────────────────────────────────────────────────────────────

function StaminaService:GetStamina(player)
	local data = playersStamina[player.UserId]
	return data and data.stamina or 0
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

			local newStamina = math.min(
				data.stamina + CombatConfig.Stamina.RegenRate,
				CombatConfig.Stamina.MaxStamina
			)
			data.stamina = newStamina

			local player = Players:GetPlayerByUserId(userId)
			if player then
				player:SetAttribute("Stamina", newStamina)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	StaminaService:CleanupPlayer(player)
end)

return StaminaService
