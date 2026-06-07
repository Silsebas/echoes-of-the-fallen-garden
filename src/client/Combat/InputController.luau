-- src/client/Controllers/Combat/InputController.lua
local UserInputService = game:GetService("UserInputService")
local CombatController = require(script.Parent.CombatController)

local InputController = {}

function InputController.Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			CombatController:RequestLightAttack()
		elseif input.KeyCode == Enum.KeyCode.Q then
			CombatController:RequestDash()
		end
	end)
end

return InputController