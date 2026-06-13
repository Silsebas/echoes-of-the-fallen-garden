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

-- Remotes
local CarpetaSprintCrouch = AlmacenReplicado:WaitForChild("Sprint&Chrouch")
local EventoSprint        = CarpetaSprintCrouch:WaitForChild("Sprinting")
local EventoCrouch        = CarpetaSprintCrouch:WaitForChild("Chrouching")

-- SprintTick: notifica al servidor cada tick para descontar stamina compartida
local SprintTickRemote = AlmacenReplicado.Shared.Remotes.CombatEvents:WaitForChild("SprintTick", 10)

-- Personaje
local personaje = JugadorLocal.Character or JugadorLocal.CharacterAdded:Wait()
local cuerpo    = personaje:WaitForChild("Humanoid")
local camara    = workspace.CurrentCamera

-- UI Sprint
local InterfazSprint = GuiJugador:WaitForChild("SprintUI")
local FondoBarra     = InterfazSprint:WaitForChild("BarraSprintFondo")
local Barra          = FondoBarra:WaitForChild("BarraSprint")
local ValorStamina   = InterfazSprint:WaitForChild("Stamina")
local SFXError       = InterfazSprint:WaitForChild("Sonidos"):WaitForChild("Error")
local SFXAgitado     = InterfazSprint:WaitForChild("Sonidos"):WaitForChild("Agitado")
local CorreccionAgitado = Iluminacion:WaitForChild("SprintAgitado")
local TextoError     = InterfazSprint:WaitForChild("Error")
local BotonSprint    = InterfazSprint:WaitForChild("UICelulares"):WaitForChild("SprintMobil")

-- UI Crouch
local InterfazCrouch = GuiJugador:WaitForChild("AgacharseUI")
local BotonCrouch    = InterfazCrouch:WaitForChild("UICelulares"):WaitForChild("AgacharseMobil")

-- Animaciones
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

local STAMINA_MAXIMA         = 100
local MinStaminaParaSprint   = 15   -- debe tener al menos esto para arrancar
local Tasa_Disminucion       = 10   -- debe coincidir con CombatConfig.Sprint.StaminaCostPerSecond

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

-- Lee la stamina desde el Attribute del servidor (stamina compartida)
local function getStamina()
	return JugadorLocal:GetAttribute("Stamina") or STAMINA_MAXIMA
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
	local proporcion = getStamina() / STAMINA_MAXIMA
	ServicioTween:Create(Barra, TweenInfo.new(0.1), {Size = UDim2.new(proporcion, 0, 1, 0)}):Play()
	ValorStamina.Value = math.floor(getStamina())
end

local function actualizarEfectosAgitado()
	local stamina = getStamina()
	local factor  = stamina < 25 and (1 - stamina / 25) or 0
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
		if cuerpo.Health <= VidaBajaSprint then
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

		-- Verificar stamina mínima para arrancar
		if getStamina() < MinStaminaParaSprint then
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

		-- Loop que notifica al servidor para descontar stamina compartida
		task.spawn(function()
			local ultimoTick = os.clock()
			while estado == "sprint" do
				task.wait(0.1)
				local ahora = os.clock()
				local delta = ahora - ultimoTick
				ultimoTick  = ahora

				-- Notificar al servidor
				if SprintTickRemote then
					SprintTickRemote:FireServer(delta)
				end

				actualizarBarraStamina()
				actualizarEfectosAgitado()

				-- Parar si la stamina compartida llegó a 0
				if getStamina() <= 0 then
					setEstado("normal")
					return
				end
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

-- Escuchar cambios del Attribute de Stamina (sincronización del servidor)
JugadorLocal:GetAttributeChangedSignal("Stamina"):Connect(function()
	actualizarBarraStamina()
	actualizarEfectosAgitado()
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
	camara.FieldOfView   = Fov_Normal
	cuerpo.WalkSpeed     = Velocidad_Normal
	estado               = "normal"
	trackSprint          = nil
	trackCrouchIdle      = nil
	trackCrouchMove      = nil
end)
