local CombatState = {}

CombatState.States = {
    Idle = "Idle",
    Attacking = "Attacking",
    Dodging = "Dodging",
    Stunned = "Stunned",
}

-- Minimal finite-state-machine implementation to allow client code to run
function CombatState.createMachine(_character)
    local state = CombatState.States.Idle
    local listeners = {}

    local machine = {}

    function machine:GetState()
        return state
    end

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
            end
        }
    end

    function machine:TransitionTo(newState, duration)
        if newState == state then
            return false
        end

        local oldState = state
        state = newState

        for _, fn in ipairs(listeners) do
            pcall(fn, newState, oldState)
        end

        if type(duration) == "number" and duration > 0 then
            task.delay(duration, function()
                if state == newState then
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
