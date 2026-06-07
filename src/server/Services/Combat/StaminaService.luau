-- src/server/Services/Combat/StaminaService.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)

local StaminaService = {}

-- Tabla principal: userId -> { stamina, regenCooldownUntil }
local playersStamina = {}

-- ─── Inicialización / Limpieza ───────────────────────────────────────────────

function StaminaService:InitializePlayer(player)
	playersStamina[player.UserId] = {
		stamina          = CombatConfig.Stamina.MaxStamina,
		regenCooldownUntil = 0, -- timestamp en segundos (os.clock)
	}
	player:SetAttribute("Stamina", CombatConfig.Stamina.MaxStamina)
	print("[STAMINA] Inicializado para", player.Name)
end

function StaminaService:CleanupPlayer(player)
	playersStamina[player.UserId] = nil
	print("[STAMINA] Limpiado para", player.Name)
end

-- ─── Consumo ─────────────────────────────────────────────────────────────────

-- Retorna true si había suficiente estamina y la descontó.
-- Tras consumir, aplica un cooldown de RegenDelay antes de que vuelva a regenerar.
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

-- ─── Bucle de Regeneración ───────────────────────────────────────────────────

local REGEN_TICK = 1 -- segundos entre cada tick de regen

task.spawn(function()
	while true do
		task.wait(REGEN_TICK)

		local now = os.clock()

		for userId, data in pairs(playersStamina) do
			-- No regenerar si estamos en cooldown post-acción
			if now < data.regenCooldownUntil then continue end
			-- No regenerar si ya está al máximo
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

-- Limpieza automática cuando el jugador sale
Players.PlayerRemoving:Connect(function(player)
	StaminaService:CleanupPlayer(player)
end)

return StaminaService
