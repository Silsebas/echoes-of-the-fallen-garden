-- src/server/ServerMain.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- 1. Crear los RemoteEvents automáticamente si no existen
local remotesFolder = ReplicatedStorage.Shared:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage.Shared
end

local combatEventsFolder = remotesFolder:FindFirstChild("CombatEvents")
if not combatEventsFolder then
	combatEventsFolder = Instance.new("Folder")
	combatEventsFolder.Name = "CombatEvents"
	combatEventsFolder.Parent = remotesFolder
end

local requestActionRemote = combatEventsFolder:FindFirstChild("RequestAction")
if not requestActionRemote then
	requestActionRemote = Instance.new("RemoteEvent")
	requestActionRemote.Name = "RequestAction"
	requestActionRemote.Parent = combatEventsFolder
end

print("[SERVER] Remotes configurados correctamente.")

-- 2. Requerir Servicios
local StaminaService = require(script.Parent.Services.Combat.StaminaService)
local CombatService = require(script.Parent.Services.Combat.CombatService)

-- 3. Iniciar Servicios
CombatService:Start(requestActionRemote)

-- 4. Helper para inicializar un jugador completo
local function initializePlayer(player)
	StaminaService:InitializePlayer(player)

	player.CharacterAdded:Connect(function(character)
		character:SetAttribute("CombatState", "Idle")
	end)

	-- Si el personaje ya existe (ej. "Play Here" en Studio)
	if player.Character then
		player.Character:SetAttribute("CombatState", "Idle")
	end
end

-- 5. Escuchar nuevos jugadores
Players.PlayerAdded:Connect(initializePlayer)

-- 6. Bootstrap: jugadores que ya estaban al correr el script (modo "Play Here")
for _, player in ipairs(Players:GetPlayers()) do
	initializePlayer(player)
end

print("[SERVER] Arquitectura del Servidor Iniciada.")
