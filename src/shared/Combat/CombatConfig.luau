-- src/shared/Combat/CombatConfig.luau
local CombatConfig = {}

CombatConfig.Player = { MaxHealth = 100, BaseWalkSpeed = 16, StunDuration = 0.5 }
CombatConfig.Stamina = { MaxStamina = 100, RegenRate = 25, RegenDelay = 1.2 }
CombatConfig.Dash    = {
	StaminaCost = 15,
	Cooldown = 1.0,
	Duration = 0.62,
	GroundForce = 80,
	AirForce = 45,
	GroundImpulseDuration = 0.18,
	AirImpulseDuration = 0.12,
}
CombatConfig.LightAttack = { StaminaCost = 10, ComboResetTime = 1.5, Cooldown = 0.2, ComboFinishDelay = 0.4 }
CombatConfig.Sprint  = { StaminaCostPerSecond = 10, MinStaminaToStart = 15 }
CombatConfig.Crouch  = { StaminaCostPerSecond = 0 } -- agacharse no gasta stamina

CombatConfig.States = {
	Idle      = "Idle",
	Attacking = "Attacking",
	Dodging   = "Dodging",
	Stunned   = "Stunned",
	Parrying  = "Parrying",
	Dead      = "Dead",
}

table.freeze(CombatConfig)
table.freeze(CombatConfig.States)

return CombatConfig
