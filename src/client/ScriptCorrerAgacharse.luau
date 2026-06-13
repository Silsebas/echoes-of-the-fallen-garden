-- src/client/ScriptCorrerAgacharse.luau
-- Ubicación en Studio: StarterPlayer > StarterCharacterScripts

local Jugadores        = game:GetService("Players")
local JugadorLocal     = Jugadores.LocalPlayer
local ServicioEjecucion = game:GetService("RunService")
local ServicioTween    = game:GetService("TweenService")
local ServicioEntrada  = game:GetService("UserInputService")
local AlmacenReplicado = game:GetService("ReplicatedStorage")
local Iluminacion      = game:GetService("Lighting")
local GuiJugador       = JugadorLocal:WaitForChild("PlayerGui")

local CarpetaSprintCrouch = AlmacenReplicado:WaitForChild("Sprint&Chrouch")
local EventoSprint        = CarpetaSprintCrouch:WaitForChild("Sprinting")
local EventoCrouch        = CarpetaSprintCrouch:WaitForChild("Chrouching")

local personaje = JugadorLocal.Character or JugadorLocal.CharacterAdded:Wait()
local cuerpo    = personaje:WaitForChild("Humanoid")
local camara    = workspace.CurrentCamera

local InterfazSprint    = GuiJugador:WaitForChild("SprintUI")
local FondoBarra        = InterfazSprint:WaitForChild("BarraSprintFondo")
local Barra             = FondoBarra:WaitForChild("BarraSprint")
local ValorStamina      = InterfazSprint:WaitForChild("Stamina")
local SFXError          = InterfazSprint:WaitForChild("Sonidos"):WaitForChild("Error")
local SFXAgitado        = InterfazSprint:WaitForChild("Sonidos"):WaitForChild("Agitado")
local CorreccionAgitado = Iluminacion:WaitForChild("SprintAgitado")
local TextoError        = InterfazSprint:WaitForChild("Error")
local BotonSprint       = InterfazSprint:WaitForChild("UICelulares"):WaitForChild("SprintMobil")

local InterfazCrouch = GuiJugador:WaitForChild("AgacharseUI")
local BotonCrouch    = InterfazCrouch:WaitForChild("UICelulares"):WaitForChild("AgacharseMobil")

local AnimacionSprint     = script:WaitForChild("CorrerAnim")
local AnimacionCrouchIdle = script:WaitForChild("AgacharseIdle")
local AnimacionCrouchMove = script:WaitForChild("AgacharseMover")

----------------------------------------------------------------------
-- CONFIGURACION
----------------------------------------------------------------------
local Velocidad_Normal   = 16
local Velocidad_Sprint   = 22
local Velocidad_Agachado = 9

local Fov_Normal    = 70
local Fov_Correr    = 90
local Fov_Agacharse = 55

local STAMINA_MAXIMA          = 100
local Tasa_Disminucion_Stamina = 10
local Tasa_Recuperacion_Stamina = 5

local TECLA_SPRINT = Enum.KeyCode.LeftShift
local TECLA_CROUCH = Enum.KeyCode.LeftControl

local Tiempo_Cooldown_Sprint = 0.5
local Tiempo_Cooldown_Crouch = 0.5
local Puede_Alternar_Sprint  = true
local Puede_Alternar_Crouch  = true

local VidaBajaSprint = 15
local TextoVidaBaja  = "No puedes correr con poca salud."
local TiempoMensaje  = 2
local Volumen_Agitado = 0.25

local Brillo     = -0.1
local Contraste  = 0.09
local Saturacion = -0.65

----------------------------------------------------------------------
-- ESTADO
----------------------------------------------------------------------
local esSprintMovil   = false
local estado          = "normal"
local trackSprint     = nil
local trackCrouchIdle = nil
local trackCrouchMove = nil

-- Stamina local — es la fuente de verdad en el cliente.
-- Se sincroniza con el Attribute del Player para que el CombatController
-- y el servidor lean siempre el mismo valor.
local stamina = JugadorLocal:GetAttribute("Stamina") or STAMINA_MAXIMA
ValorStamina.Value = stamina

local function sincronizarStamina()
	JugadorLocal:SetAttribute("Stamina", stamina)
	ValorStamina.Value = math.floor(stamina)
end

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function getAnimador()
	local humanoid = personaje:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local anim = humanoid:FindFirstChildOfClass("Animator")
	if anim then return anim end
	anim = Instance.new("Animator")
	anim.Parent = humanoid
	return anim
end

local function cargarAnimacion(animObj)
	local anim = getAnimador()
	if not anim then return nil end
	return anim:LoadAnimation(animObj)
end

local function detenerTracks()
	if trackSprint     then trackSprint:Stop();     trackSprint     = nil end
	if trackCrouchIdle then trackCrouchIdle:Stop(); trackCrouchIdle = nil end
	if trackCrouchMove then trackCrouchMove:Stop(); trackCrouchMove = nil end
end

local function actualizarBarraStamina()
	local proporcion = stamina / STAMINA_MAXIMA
	ServicioTween:Create(Barra, TweenInfo.new(0.1), {Size = UDim2.new(proporcion, 0, 1, 0)}):Play()
end

local function actualizarEfectosAgitado()
	local factor = stamina < 25 and (1 - stamina / 25) or 0
	ServicioTween:Create(CorreccionAgitado, TweenInfo.new(0.5), {
		Brightness = factor * Brillo,
		Contrast   = factor * Contraste,
		Saturation = factor * Saturacion,
	}):Play()
	ServicioTween:Create(SFXAgitado, TweenInfo.new(0.5), {Volume = factor * Volumen_Agitado}):Play()
	if factor > 0 then
		if not SFXAgitado.IsPlaying then SFXAgitado:Play() end
	else
		SFXAgitado:Stop()
	end
end

local function moverBarraStamina(arriba)
	local pos = arriba and UDim2.new(0, 0, 0.99, 0) or UDim2.new(0, 0, 1, 0)
	ServicioTween:Create(FondoBarra, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = pos}):Play()
end

----------------------------------------------------------------------
-- Sincronizar cuando el SERVIDOR cambia la stamina (ataque/dash)
-- El servidor descuenta via SetAttribute — el cliente lo refleja aquí
----------------------------------------------------------------------
JugadorLocal:GetAttributeChangedSignal("Stamina"):Connect(function()
	local serverValue = JugadorLocal:GetAttribute("Stamina")
	-- Sincronizar siempre que el servidor tenga un valor diferente al local
	-- Esto cubre descuentos por ataque y dash además del sprint
	if serverValue ~= stamina then
		stamina = serverValue
		actualizarBarraStamina()
		actualizarEfectosAgitado()
		-- Si sprint y se quedó sin stamina, parar
		if estado == "sprint" and stamina <= 0 then
			setEstado("normal")
		end
	end
end)

----------------------------------------------------------------------
-- MÁQUINA DE ESTADOS
----------------------------------------------------------------------
local function setEstado(nuevoEstado)
	if estado == nuevoEstado then return end

	if estado == "sprint" then
		detenerTracks()
		ServicioTween:Create(cuerpo, TweenInfo.new(0.3), {WalkSpeed = Velocidad_Normal}):Play()
		ServicioTween:Create(camara, TweenInfo.new(0.3), {FieldOfView = Fov_Normal}):Play()
		EventoSprint:FireServer(false)
	elseif estado == "crouch" then
		detenerTracks()
		ServicioTween:Create(cuerpo, TweenInfo.new(0.3), {WalkSpeed = Velocidad_Normal}):Play()
		ServicioTween:Create(camara, TweenInfo.new(0.3), {FieldOfView = Fov_Normal}):Play()
		EventoCrouch:FireServer(false)
	end

	estado = nuevoEstado

	if nuevoEstado == "normal" then
		moverBarraStamina(false)

	elseif nuevoEstado == "sprint" then
		-- Bloquear si vida muy baja o en estado de agonía
		local enAgonia = personaje:GetAttribute("VidaBaja") == true
		if cuerpo.Health <= VidaBajaSprint or enAgonia then
			TextoError.Visible = true
			TextoError.Text    = TextoVidaBaja
			SFXError:Play()
			task.delay(TiempoMensaje, function()
				TextoError.Text    = ""
				TextoError.Visible = false
			end)
			estado = "normal"
			return
		end

		if not esSprintMovil and cuerpo.MoveDirection.Magnitude == 0 then
			task.wait(0.15)
			if cuerpo.MoveDirection.Magnitude == 0 then
				estado = "normal"
				return
			end
		end

		moverBarraStamina(true)
		ServicioTween:Create(cuerpo, TweenInfo.new(0.3), {WalkSpeed = Velocidad_Sprint}):Play()
		ServicioTween:Create(camara, TweenInfo.new(0.3), {FieldOfView = Fov_Correr}):Play()

		trackSprint = cargarAnimacion(AnimacionSprint)
		if trackSprint then
			trackSprint.Priority = Enum.AnimationPriority.Action
			trackSprint:Play()
		end

		EventoSprint:FireServer(true)

		task.spawn(function()
			while estado == "sprint" and stamina > 0 do
				task.wait(0.1)
				stamina = math.max(stamina - Tasa_Disminucion_Stamina * 0.1, 0)
				sincronizarStamina()   -- <-- actualiza Attribute para CombatController
				actualizarBarraStamina()
				actualizarEfectosAgitado()
			end
			if stamina <= 0 and estado == "sprint" then
				setEstado("normal")
			end
		end)

	elseif nuevoEstado == "crouch" then
		ServicioTween:Create(cuerpo, TweenInfo.new(0.3), {WalkSpeed = Velocidad_Agachado}):Play()
		ServicioTween:Create(camara, TweenInfo.new(0.3), {FieldOfView = Fov_Agacharse}):Play()

		trackCrouchIdle = cargarAnimacion(AnimacionCrouchIdle)
		if trackCrouchIdle then
			trackCrouchIdle.Priority = Enum.AnimationPriority.Action
			trackCrouchIdle:Play()
		end

		EventoCrouch:FireServer(true)
	end
end

-- Regen de stamina
task.spawn(function()
	while true do
		task.wait(0.1)
		if estado ~= "sprint" and stamina < STAMINA_MAXIMA then
			stamina = math.min(stamina + Tasa_Recuperacion_Stamina * 0.1, STAMINA_MAXIMA)
			sincronizarStamina()   -- <-- mantiene Attribute sincronizado durante regen
			actualizarBarraStamina()
			actualizarEfectosAgitado()
		end
	end
end)

----------------------------------------------------------------------
-- SWITCH ANIMACION CROUCH
----------------------------------------------------------------------
ServicioEjecucion.RenderStepped:Connect(function()
	if estado == "sprint" then
		if not esSprintMovil and cuerpo.MoveDirection.Magnitude == 0 then
			setEstado("normal")
		end

	elseif estado == "crouch" then
		local moviendose = cuerpo.MoveDirection.Magnitude > 0
		if moviendose then
			if not trackCrouchMove or not trackCrouchMove.IsPlaying then
				if trackCrouchIdle then trackCrouchIdle:Stop(); trackCrouchIdle = nil end
				trackCrouchMove = cargarAnimacion(AnimacionCrouchMove)
				if trackCrouchMove then
					trackCrouchMove.Priority = Enum.AnimationPriority.Action
					trackCrouchMove:Play()
				end
			end
		else
			if not trackCrouchIdle or not trackCrouchIdle.IsPlaying then
				if trackCrouchMove then trackCrouchMove:Stop(); trackCrouchMove = nil end
				trackCrouchIdle = cargarAnimacion(AnimacionCrouchIdle)
				if trackCrouchIdle then
					trackCrouchIdle.Priority = Enum.AnimationPriority.Action
					trackCrouchIdle:Play()
				end
			end
		end
	end
end)

----------------------------------------------------------------------
-- INPUT TECLADO
----------------------------------------------------------------------
ServicioEntrada.InputBegan:Connect(function(entrada, procesado)
	if procesado then return end
	if cuerpo.Health <= 0 then return end

	if entrada.KeyCode == TECLA_SPRINT then
		if Puede_Alternar_Sprint and estado ~= "crouch" then
			Puede_Alternar_Sprint = false
			setEstado("sprint")
			task.delay(Tiempo_Cooldown_Sprint, function() Puede_Alternar_Sprint = true end)
		end
	elseif entrada.KeyCode == TECLA_CROUCH then
		if Puede_Alternar_Crouch then
			Puede_Alternar_Crouch = false
			setEstado(estado == "crouch" and "normal" or "crouch")
			task.delay(Tiempo_Cooldown_Crouch, function() Puede_Alternar_Crouch = true end)
		end
	end
end)

ServicioEntrada.InputEnded:Connect(function(entrada, procesado)
	if procesado then return end
	if entrada.KeyCode == TECLA_SPRINT and estado == "sprint" then
		setEstado("normal")
	end
end)

----------------------------------------------------------------------
-- BOTONES MÓVIL
----------------------------------------------------------------------
BotonSprint.Activated:Connect(function()
	if cuerpo.Health <= 0 then return end
	if Puede_Alternar_Sprint and estado ~= "crouch" then
		if estado == "sprint" then
			setEstado("normal")
			esSprintMovil = false
		else
			Puede_Alternar_Sprint = false
			esSprintMovil = true
			setEstado("sprint")
			task.delay(Tiempo_Cooldown_Sprint, function() Puede_Alternar_Sprint = true end)
		end
	end
end)

BotonCrouch.Activated:Connect(function()
	if cuerpo.Health <= 0 then return end
	if Puede_Alternar_Crouch then
		Puede_Alternar_Crouch = false
		setEstado(estado == "crouch" and "normal" or "crouch")
		task.delay(Tiempo_Cooldown_Crouch, function() Puede_Alternar_Crouch = true end)
	end
end)

----------------------------------------------------------------------
-- MUERTE Y RESPAWN
----------------------------------------------------------------------
cuerpo.Died:Connect(function()
	detenerTracks()
	setEstado("normal")
	Puede_Alternar_Sprint = false
	Puede_Alternar_Crouch = false
end)

JugadorLocal.CharacterAdded:Connect(function(nuevoPersonaje)
	personaje = nuevoPersonaje
	cuerpo    = nuevoPersonaje:WaitForChild("Humanoid")
	camara.FieldOfView = Fov_Normal
	cuerpo.WalkSpeed   = Velocidad_Normal
	estado             = "normal"
	trackSprint        = nil
	trackCrouchIdle    = nil
	trackCrouchMove    = nil
	stamina            = JugadorLocal:GetAttribute("Stamina") or STAMINA_MAXIMA
	sincronizarStamina()
end)
