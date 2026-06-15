local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurarJugador = ReplicatedStorage:WaitForChild("CurarJugador")
local MedkitDisappear = ReplicatedStorage:WaitForChild("MedkitDisappear")

pcall(function()
	CurarJugador.Sandboxed = true
	MedkitDisappear.Sandboxed = true
end)

local HEAL_ITEMS = {
	PiedraRoja   = { heal = 25,  duration = 4.7 },
	PiedraRosa   = { heal = 50,  duration = 6.0 },
	PiedraMorada = { heal = 100, duration = 6.0 },
}

local EQUIP_GRACE_SECONDS = 0.35

local function getCharacter(player)
	local character = player.Character
	if not character or not character.Parent then
		return nil
	end

	return character
end

local function getHumanoid(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return humanoid
end

local function isPlayersTool(player, tool)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return false
	end

	local character = getCharacter(player)
	local backpack = player:FindFirstChildOfClass("Backpack")

	return tool.Parent == character or tool.Parent == backpack
end

local function getEquippedHealTool(player)
	local character = getCharacter(player)
	if not character then
		return nil, nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			local config = HEAL_ITEMS[child.Name]
			if config then
				return child, config
			end
		end
	end

	return nil, nil
end

local function markEquipTime(tool)
	if not tool:IsA("Tool") or not HEAL_ITEMS[tool.Name] then
		return
	end

	tool:SetAttribute("ServerEquippedAt", os.clock())
end

local function watchCharacter(character)
	for _, child in ipairs(character:GetChildren()) do
		markEquipTime(child)
	end

	character.ChildAdded:Connect(markEquipTime)
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

Players.PlayerAdded:Connect(watchPlayer)

-- Registro de curaciones en progreso: userId -> { startTime, toolName }
local healingSessions = {}

CurarJugador.OnServerEvent:Connect(function(player, requestedHeal, requestedTool)
	if type(requestedHeal) ~= "number" then return end

	local character = getCharacter(player)
	local humanoid = character and getHumanoid(character)
	if not character or not humanoid then return end

	-- Buscar el tool en el personaje primero, luego en backpack
	local tool, config = nil, nil
	if isPlayersTool(player, requestedTool) then
		local requestedConfig = HEAL_ITEMS[requestedTool.Name]
		if requestedConfig then
			tool = requestedTool
			config = requestedConfig
		end
	end

	if not tool then
		tool, config = getEquippedHealTool(player)
	end

	-- Si aun no encontramos el tool, buscar en el backpack (puede haberse movido justo antes)
	if not tool then
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			for _, child in ipairs(backpack:GetChildren()) do
				if child:IsA("Tool") and HEAL_ITEMS[child.Name] then
					local c = HEAL_ITEMS[child.Name]
					if c.heal == requestedHeal then
						tool = child
						config = c
						break
					end
				end
			end
		end
	end

	if not tool or not config then
		warn("[CURACION] Rechazada: herramienta no encontrada para", player.Name, "| tool recibido:", requestedTool and ("['" .. requestedTool.Name .. "']") or "NIL")
		return
	end

	if requestedHeal ~= config.heal then
		warn("[CURACION] Rechazada: healAmount invalido de", player.Name)
		return
	end

	-- Validar tiempo mínimo usando el atributo de curación del personaje
	local healStartTime = character:GetAttribute("HealStartTime")
	if type(healStartTime) == "number" then
		local elapsed = os.clock() - healStartTime
		if elapsed + EQUIP_GRACE_SECONDS < config.duration then
			warn("[CURACION] Rechazada: intento demasiado rapido de", player.Name)
			return
		end
	end

	if humanoid.Health >= humanoid.MaxHealth then return end

	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + config.heal)
	print("[CURACION] Aplicada:", config.heal, "vida a", player.Name)
	tool:Destroy()
end)

MedkitDisappear.OnServerEvent:Connect(function(player, medkit, hide)
	if not isPlayersTool(player, medkit) then
		warn("[CURACION] Rechazada: MedkitDisappear con herramienta ajena de", player.Name)
		return
	end

	if not HEAL_ITEMS[medkit.Name] then
		return
	end

	local handle = medkit:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.Transparency = hide and 1 or 0
	end
end)
