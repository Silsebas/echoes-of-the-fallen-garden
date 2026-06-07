-- src/server/Services/Combat/StaminaService.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)

local StaminaService = {}
local playersStamina = {} -- Diccionario para guardar la estamina de cada jugador

-- Inicializa a un jugador cuando entra al servidor
function StaminaService:InitializePlayer(player)
	playersStamina[player.UserId] = CombatConfig.Stamina.MaxStamina
	player:SetAttribute("Stamina", CombatConfig.Stamina.MaxStamina)
	print("[SERVER] Estamina inicializada para", player.Name)
end

-- Intenta gastar estamina. Retorna true si tuvo éxito, false si no le alcanza.
function StaminaService:TryConsumeStamina(player, amount)
	local currentStamina = playersStamina[player.UserId] or 0
	
	if currentStamina >= amount then
		playersStamina[player.UserId] = currentStamina - amount
		player:SetAttribute("Stamina", playersStamina[player.UserId])
		return true
	end
	
	return false
end

-- src/server/Services/Combat/StaminaService.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatState = require(ReplicatedStorage.Shared.Combat.CombatState)

local StaminaService = {}
local playersStamina = {}

function StaminaService:InitializePlayer(player)
	playersStamina[player.UserId] = CombatConfig.Stamina.MaxStamina
	player:SetAttribute("Stamina", CombatConfig.Stamina.MaxStamina)
end

function StaminaService:TryConsumeStamina(player, amount)
	local currentStamina = playersStamina[player.UserId] or 0
	if currentStamina >= amount then
		playersStamina[player.UserId] = currentStamina - amount
		player:SetAttribute("Stamina", playersStamina[player.UserId])
		return true
	end
	return false
end

-- ESTO ES LO NUEVO: El ciclo de regeneración
task.spawn(function()
	while true do
		task.wait(2) -- Regeneramos cada 1 segundo
		
		for userId, stamina in pairs(playersStamina) do
			-- Solo regeneramos si no es igual al máximo
			if stamina < CombatConfig.Stamina.MaxStamina then
				-- Aquí podrías agregar lógica para saber si el jugador está atacando o corriendo
				-- Por ahora, regeneramos de forma constante
				local newStamina = math.min(stamina + CombatConfig.Stamina.RegenRate, CombatConfig.Stamina.MaxStamina)
				
				playersStamina[userId] = newStamina
				
				-- Actualizar el atributo para que el cliente lo lea
				local player = game.Players:GetPlayerByUserId(userId)
				if player then
					player:SetAttribute("Stamina", newStamina)
				end
			end
		end
	end
end)


return StaminaService