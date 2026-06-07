-- src/client/ClientMain.client.luau
local Players = game:GetService("Players")

print("[CLIENT] Buscando la carpeta Combat...")

-- AUTO-DETECTAR RUTA: Busca la carpeta 'Combat' directamente
local CombatFolder = script:FindFirstChild("Combat") or script.Parent:WaitForChild("Combat", 5)

if not CombatFolder then
	error("[CLIENTE ERROR] No se encontró la carpeta 'Combat'. Verifica la estructura en VS Code.")
end

-- Requerimos los módulos directamente desde la carpeta Combat
local InputController = require(CombatFolder:WaitForChild("InputController"))
local CombatController = require(CombatFolder:WaitForChild("CombatController"))
local VFXController = require(CombatFolder:WaitForChild("VFXController"))

local player = Players.LocalPlayer

-- Iniciamos el Input
InputController.Start()

local function onCharacterAdded(character)
	VFXController:Initialize(character)
	CombatController:Initialize(character)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

print("[CLIENT] Arquitectura Base Cargada Correctamente")