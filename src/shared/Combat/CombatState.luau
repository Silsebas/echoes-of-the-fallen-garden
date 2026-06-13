-- src/shared/Combat/CombatState.luau
local CombatState = {}

-- Estados sincronizados con CombatConfig.States
CombatState.States = {
	Idle      = "Idle",
	Attacking = "Attacking",
	Dodging   = "Dodging",
	Stunned   = "Stunned",
	Parrying  = "Parrying",
	Dead      = "Dead",
}

-- Transiciones válidas: qué estados puede originar cada acción.
-- El servidor y el cliente usan esta misma tabla para validar.
CombatState.ValidTransitions = {
	Attacking = { Idle = true, Dodging = true, Attacking = true },
	Dodging   = { Idle = true, Attacking = true },
	Stunned   = { Idle = true, Attacking = true, Dodging = true },
	Parrying  = { Idle = true },
	Idle      = { Attacking = true, Dodging = true, Stunned = true, Parrying = true },
	Dead      = { Idle = true, Attacking = true, Dodging = true, Stunned = true },
}

-- Retorna true si la transición de `fromState` a `toState` es válida.
function CombatState.canTransition(fromState, toState)
	local allowed = CombatState.ValidTransitions[toState]
	return allowed ~= nil and allowed[fromState] == true
end

-- ─── Máquina de estados por personaje (cliente) ──────────────────────────────

function CombatState.createMachine(_character)
	local state     = CombatState.States.Idle
	local listeners = {}
	local transitionId = 0

	local machine = {}

	function machine:GetState()
		return state
	end

	-- Suscribe un listener fn(newState, oldState). Retorna { Disconnect() }.
	function machine:Connect(fn)
		table.insert(listeners, fn)
		return {
			Disconnect = function()
				for i, v in ipairs(listeners) do
					if v == fn then
						table.remove(listeners, i)
						break
					end
				end
			end,
		}
	end

	-- Intenta transicionar al nuevo estado.
	-- Si duration > 0, regresa automáticamente a Idle después de ese tiempo.
	-- Retorna true si la transición fue aceptada.
	function machine:TransitionTo(newState, duration)
		-- Permitir volver a entrar en el mismo estado si la transición está permitida.
		if newState == state and not CombatState.canTransition(state, newState) then
			return false
		end

		local oldState = state
		state = newState
		transitionId += 1
		local currentTransition = transitionId

		for _, fn in ipairs(listeners) do
			pcall(fn, newState, oldState)
		end

		if type(duration) == "number" and duration > 0 then
			task.delay(duration, function()
				if currentTransition == transitionId and state == newState then
					local prev = state
					state = CombatState.States.Idle
					for _, fn in ipairs(listeners) do
						pcall(fn, state, prev)
					end
				end
			end)
		end

		return true
	end

	return machine
end

return CombatState
