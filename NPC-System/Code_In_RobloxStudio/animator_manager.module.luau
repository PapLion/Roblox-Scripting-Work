--[[
================================================================================
  AnimationManager.lua  —  NPC Animation Module (v2)
================================================================================

  CAMBIOS vs v1
  -------------
  • Bug fix: el sistema de fallbackToken usaba comparación de tabla ({})
    lo que hacía que el fallback NUNCA se cancelara correctamente. Ahora
    usa un contador numérico incremental — cancelación garantizada.
  • Nueva función StopGunAnims() — detiene GunIdle y GunWalk limpiamente
    cuando el arma se holstera. NpcScript la llama desde holsterWeapon().
  • Fix en la cadena Ziptie→ZipTieIdle: si StopAll() se llama mientras
    la cadena está pendiente, ZipTieIdle ya no se inicia incorrectamente.
  • PlayMovement() ahora acepta forceRestart correctamente también cuando
    la animación anterior era de arma (GunIdle/GunWalk) y se cambia a Walk.

  OVERVIEW
  --------
  Gestiona dos capas independientes de animación:

    MOVEMENT layer  Locomoción: Idle, Walk, Run, GunWalk, GunIdle.
                    Solo una animación de movimiento activa a la vez.

    ACTION layer    Animaciones de combate/interacción: Shoot, Reload,
                    Melee, Ziptie, Death, Surrender, etc.
                    Solo una acción activa a la vez.

  Cuando una acción no-looping termina, el módulo reanuda automáticamente
  la última animación de movimiento activa.

  Acciones que bloquean movimiento (IsPlayingAction() = true):
    Draw, Reload, FlashbangReaction.

  DEPENDENCIAS
  ------------
  Debe ser hijo directo del modelo del NPC. El NPC debe tener un
  Humanoid con un hijo Animator.

  USO BÁSICO
  ----------
  AnimManager:PlayMovement("Run")      -- capa MOVEMENT
  AnimManager:PlayAction("Shoot")      -- capa ACTION
  AnimManager:Stop("Reload")           -- detiene una animación específica
  AnimManager:StopAll()                -- detiene todo y resetea estado
  AnimManager:StopGunAnims()           -- detiene GunIdle y GunWalk
  AnimManager:IsReloading()            -- true durante recarga
  AnimManager:IsPlayingAction()        -- true durante acción bloqueante

================================================================================
]]

local AnimationManager = {}

local NPC      = script.Parent
local Humanoid = NPC:WaitForChild("Humanoid")
local Animator = Humanoid:WaitForChild("Animator")

-- ── IDs DE ANIMACIÓN ─────────────────────────────────────────────────────────
--[[
  Reemplaza cualquier rbxassetid para cambiar una animación.
  ID vacío o "rbxassetid://0" → se omite silenciosamente al cargar.
]]
local ANIMATION_IDS = {
	Idle              = "rbxassetid://81158304881872",
	Walk              = "rbxassetid://75776647586406",
	Run               = "rbxassetid://75776647586406",
	GunWalk           = "rbxassetid://103841735486088",
	GunIdle           = "rbxassetid://116210740732157",
	Shoot             = "rbxassetid://129613891861629",
	Reload            = "rbxassetid://107720948953875",
	Melee             = "rbxassetid://88201724919969",
	Ziptie            = "rbxassetid://71761178391758",
	ZipTieIdle        = "rbxassetid://103540064208050",
	Death             = "rbxassetid://81158304881872",
	FlashbangReaction = "rbxassetid://87811202976976",
	Draw              = "rbxassetid://91239808642157",
	Surrender         = "rbxassetid://104913955721035",
}

-- ── PRIORIDADES ───────────────────────────────────────────────────────────────
local PRIORITY = {
	Idle              = Enum.AnimationPriority.Idle,
	Walk              = Enum.AnimationPriority.Movement,
	Run               = Enum.AnimationPriority.Movement,
	GunWalk           = Enum.AnimationPriority.Action,
	GunIdle           = Enum.AnimationPriority.Action,
	Shoot             = Enum.AnimationPriority.Action,
	Reload            = Enum.AnimationPriority.Action,
	Melee             = Enum.AnimationPriority.Action2,
	Ziptie            = Enum.AnimationPriority.Action2,
	ZipTieIdle        = Enum.AnimationPriority.Action2,
	Death             = Enum.AnimationPriority.Action4,
	FlashbangReaction = Enum.AnimationPriority.Action3,
	Draw              = Enum.AnimationPriority.Action3,
	Surrender         = Enum.AnimationPriority.Action,
}

-- ── FLAGS DE LOOPING ──────────────────────────────────────────────────────────
local LOOPING = {
	Idle              = true,
	Walk              = true,
	Run               = true,
	GunWalk           = true,
	GunIdle           = true,
	Shoot             = false,
	Reload            = false,
	Melee             = false,
	Ziptie            = false,
	ZipTieIdle        = true,
	Death             = false,
	FlashbangReaction = true,
	Draw              = false,
	Surrender         = false,
}

-- ── DURACIONES DE ACCIÓN (timers de seguridad) ────────────────────────────────
--[[
  Fallback: si el evento Stopped nunca se dispara, el estado se limpia
  después de este tiempo. Usar valores ligeramente mayores a la duración real.
  999 = persistente hasta :Stop() o :StopAll() explícito.
]]
local ACTION_DURATION = {
	Shoot             = 0.6,
	Reload            = 2.0,
	Melee             = 0.8,
	Ziptie            = 4.83,
	Death             = 999,
	FlashbangReaction = 999,
	Draw              = 0.8,
	Surrender         = 999,
}

-- ── ACCIONES QUE BLOQUEAN MOVIMIENTO ─────────────────────────────────────────
--[[
  Mientras estas están activas, IsPlayingAction() = true y NpcScript
  no cambia la animación de locomoción.
]]
local BLOCKS_MOVEMENT = {
	Draw              = true,
	Reload            = true,
	FlashbangReaction = true,
}

-- ── ASIGNACIÓN DE CAPA ────────────────────────────────────────────────────────
local LAYER = {
	Idle              = "MOVEMENT",
	Walk              = "MOVEMENT",
	Run               = "MOVEMENT",
	GunWalk           = "MOVEMENT",
	GunIdle           = "MOVEMENT",
	Shoot             = "ACTION",
	Reload            = "ACTION",
	Melee             = "ACTION",
	Ziptie            = "ACTION",
	ZipTieIdle        = "ACTION",
	Death             = "ACTION",
	FlashbangReaction = "ACTION",
	Draw              = "ACTION",
	Surrender         = "ACTION",
}

-- ── CARGAR TODOS LOS TRACKS ───────────────────────────────────────────────────
local tracks = {}
for name, id in pairs(ANIMATION_IDS) do
	if id ~= "" and id ~= "rbxassetid://0" then
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local track = Animator:LoadAnimation(anim)
		track.Priority = PRIORITY[name]
		track.Looped   = LOOPING[name]
		tracks[name]   = track
		anim:Destroy()
	end
end

-- ── ESTADO INTERNO ────────────────────────────────────────────────────────────
local currentMovement   = ""
local currentAction     = ""
local isReloading       = false
local isActionBlocking  = false

--[[
  FIX CRÍTICO: contador de fallback numérico.
  La v1 usaba `local fallbackToken = {}` (tabla vacía) lo que causaba que
  `activeFallback = nil` nunca cancelara el fallback porque la comparación
  `activeFallback ~= fallbackToken` siempre era true (diferentes referencias).
  Ahora usamos un número incremental por acción — cancelación garantizada.
]]
local fallbackCounter = 0

-- ── HELPERS PRIVADOS ──────────────────────────────────────────────────────────

local function stopTrack(name, fadeTime)
	if tracks[name] and tracks[name].IsPlaying then
		tracks[name]:Stop(fadeTime or 0.15)
	end
end

local function playTrack(name, fadeTime)
	local t = tracks[name]
	if not t then
		warn("AnimationManager: no hay track cargado para '" .. name .. "'")
		return
	end
	if t.IsPlaying then return end
	t:Play(fadeTime or 0.15)
end

-- ── API PÚBLICA ───────────────────────────────────────────────────────────────

--[[
  PlayMovement(name, fadeTime, forceRestart)
  ------------------------------------------
  Reproduce una animación en la capa MOVEMENT.
  Si la misma animación ya está activa y forceRestart no es true, no hace nada.
  Si hay una animación diferente activa, hace crossfade.

  Parámetros:
    name         string   Nombre de la animación (debe estar en LAYER como "MOVEMENT").
    fadeTime     number   Duración del crossfade. Default: 0.15.
    forceRestart bool     Si true, reinicia el track aunque ya esté activo.
]]
function AnimationManager:PlayMovement(name, fadeTime, forceRestart)
	fadeTime = fadeTime or 0.15
	if not forceRestart and currentMovement == name and tracks[name] and tracks[name].IsPlaying then return end

	if currentMovement ~= "" and currentMovement ~= name then
		stopTrack(currentMovement, fadeTime)
	end

	if tracks[name] and tracks[name].IsPlaying and forceRestart then
		tracks[name]:Stop(0.05)
	end

	playTrack(name, fadeTime)
	currentMovement = name
end

--[[
  PlayAction(name, fadeTime)
  --------------------------
  Reproduce una animación en la capa ACTION.
  Cuando una acción no-looping termina, reanuda la última animación de movimiento.

  Comportamientos especiales:
    Reload   → ignorado si ya hay un reload en progreso.
    Ziptie   → encadena automáticamente a ZipTieIdle al terminar,
               solo si StopAll() no fue llamado mientras tanto.

  FIX: el fallback usa contador numérico para cancelación confiable.
]]
function AnimationManager:PlayAction(name, fadeTime)
	fadeTime = fadeTime or 0.10

	if name == "Reload" then
		if isReloading then return end
		isReloading = true
	end

	if currentAction ~= "" and currentAction ~= name then
		stopTrack(currentAction, fadeTime)
	end

	playTrack(name, fadeTime)
	currentAction = name

	if BLOCKS_MOVEMENT[name] then
		isActionBlocking = true
	end

	if not LOOPING[name] then
		local playedName = name
		local duration   = ACTION_DURATION[name] or 2.0

		-- Caso especial: Ziptie encadena a ZipTieIdle al completarse.
		-- FIX: guardamos currentAction al momento de la conexión para verificar
		-- que StopAll() no fue llamado antes de que Stopped se dispare.
		if playedName == "Ziptie" then
			tracks["Ziptie"].Stopped:Once(function()
				-- Solo encadenar si el estado no fue reseteado externamente
				if currentAction == "Ziptie" then
					currentAction = ""
					playTrack("ZipTieIdle", 0.15)
					currentAction = "ZipTieIdle"
				end
			end)
			return
		end

		-- FIX: usar contador numérico en lugar de referencia de tabla.
		fallbackCounter += 1
		local myFallbackId = fallbackCounter
		local cancelled    = false

		-- Fallback de seguridad: limpia estado si Stopped nunca se dispara.
		task.delay(duration + 0.2, function()
			if cancelled then return end
			if fallbackCounter ~= myFallbackId then return end  -- fue cancelado
			if currentAction == playedName then
				currentAction = ""
				if playedName == "Reload" then isReloading = false end
				if BLOCKS_MOVEMENT[playedName] then isActionBlocking = false end
				if currentMovement ~= "" then
					self:PlayMovement(currentMovement, 0.15, true)
				end
			end
		end)

		-- Camino principal de limpieza: cuando el track para naturalmente.
		tracks[name].Stopped:Once(function()
			cancelled = true  -- cancelar el fallback de seguridad

			if playedName == "Reload" then isReloading = false end
			if BLOCKS_MOVEMENT[playedName] then isActionBlocking = false end
			if currentAction == playedName then
				currentAction = ""
				if currentMovement ~= "" then
					self:PlayMovement(currentMovement, 0.15, true)
				end
			end
		end)
	end
end

--[[
  Play(name, fadeTime)
  --------------------
  Conveniencia: enruta automáticamente a PlayMovement o PlayAction
  según la tabla LAYER. Preferir para llamadas genéricas.
]]
function AnimationManager:Play(name, fadeTime)
	local layer = LAYER[name]
	if layer == "MOVEMENT" then
		self:PlayMovement(name, fadeTime)
	elseif layer == "ACTION" then
		self:PlayAction(name, fadeTime)
	else
		warn("AnimationManager: capa desconocida para '" .. name .. "'")
	end
end

--[[
  Stop(name, fadeTime)
  --------------------
  Detiene una animación específica y limpia su estado asociado.
]]
function AnimationManager:Stop(name, fadeTime)
	fadeTime = fadeTime or 0.15
	stopTrack(name, fadeTime)
	if name == currentMovement then currentMovement = "" end
	if name == currentAction then
		currentAction = ""
		if name == "Reload" then isReloading = false end
		if BLOCKS_MOVEMENT[name] then isActionBlocking = false end
	end
end

--[[
  StopGunAnims(fadeTime)
  ----------------------
  NUEVO: Detiene GunIdle y GunWalk específicamente.
  Llamar desde holsterWeapon() en NpcScript para que las animaciones
  de arma no queden reproduciendo cuando el arma se oculta.
  Si currentMovement era GunIdle o GunWalk, lo resetea a "".
]]
function AnimationManager:StopGunAnims(fadeTime)
	fadeTime = fadeTime or 0.15
	stopTrack("GunIdle", fadeTime)
	stopTrack("GunWalk", fadeTime)
	if currentMovement == "GunIdle" or currentMovement == "GunWalk" then
		currentMovement = ""
	end
end

--[[
  StopAll(fadeTime)
  -----------------
  Detiene todas las animaciones y resetea todo el estado interno.
  Llamar antes de transiciones mayores (muerte, stun, arresto).
]]
function AnimationManager:StopAll(fadeTime)
	fadeTime = fadeTime or 0.15
	for _, t in pairs(tracks) do
		if t.IsPlaying then t:Stop(fadeTime) end
	end
	currentMovement  = ""
	currentAction    = ""
	isReloading      = false
	isActionBlocking = false
	-- Invalidar cualquier fallback pendiente incrementando el contador
	fallbackCounter += 1
end

--[[
  IsReloading() → bool
  Verdadero mientras hay un reload en progreso.
]]
function AnimationManager:IsReloading()
	return isReloading
end

--[[
  IsPlayingAction() → bool
  Verdadero mientras Draw, Reload, o FlashbangReaction están activos.
  NpcScript lo usa para no interrumpir estas animaciones con locomoción.
]]
function AnimationManager:IsPlayingAction()
	return isActionBlocking
end

return AnimationManager
