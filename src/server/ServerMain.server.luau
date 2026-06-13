-- src/server/ServerMain.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- 0. Forzar R6 para todos los jugadores
local StarterPlayer = game:GetService("StarterPlayer")
StarterPlayer.LoadCharacterAppearance = false

-- 1. Crear RemoteEvents
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

-- RemoteEvent para que el cliente notifique el sprint al servidor
local sprintTickRemote = combatEventsFolder:FindFirstChild("SprintTick")
if not sprintTickRemote then
	sprintTickRemote = Instance.new("RemoteEvent")
	sprintTickRemote.Name = "SprintTick"
	sprintTickRemote.Parent = combatEventsFolder
end

print("[SERVER] Remotes configurados correctamente.")

-- 2. Requerir Servicios
local StaminaService = require(script.Parent.Services.Combat.StaminaService)
local CombatService  = require(script.Parent.Services.Combat.CombatService)

-- 3. Iniciar CombatService
CombatService:Start(requestActionRemote)

-- 4. Escuchar ticks de sprint desde el cliente
-- El cliente envía cada ~0.1s cuánto tiempo lleva corriendo
sprintTickRemote.OnServerEvent:Connect(function(player, deltaTime)
	if type(deltaTime) ~= "number" then return end
	deltaTime = math.clamp(deltaTime, 0, 0.5) -- sanidad: máx 0.5s por tick
	StaminaService:ConsumeSprint(player, deltaTime)
end)

-- 5. Helper de inicialización
local function initializePlayer(player)
	StaminaService:InitializePlayer(player)

	player.CharacterAdded:Connect(function(character)
		character:SetAttribute("CombatState", "Idle")
		-- Forzar R6 en el humanoid
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid.RigType = Enum.HumanoidRigType.R6
		end
	end)

	if player.Character then
		player.Character:SetAttribute("CombatState", "Idle")
	end
end

-- 6. Conectar y bootstrap
Players.PlayerAdded:Connect(initializePlayer)

for _, player in ipairs(Players:GetPlayers()) do
	initializePlayer(player)
end

print("[SERVER] Arquitectura del Servidor Iniciada.")
