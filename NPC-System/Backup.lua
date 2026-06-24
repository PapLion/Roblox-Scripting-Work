--[[ NpcScript.lua  —  NPC AI Controller (v4.0)
================================================================================

  CAMBIOS vs v3.2
  ---------------
  • NUEVO: Sistema de tipos de arma por atributo WeaponType ("Semi","Auto","Spread").
    shoot() ahora es un dispatcher → shootSemi / shootAuto / shootSpread.
    - Semi:   comportamiento original sin cambios.
    - Auto:   ráfagas de AUTO_BURST_SIZE balas con cadencia AUTO_FIRE_RATE,
              pausa entre ráfagas igual a SHOOT_COOLDOWN.
    - Spread: SPREAD_PELLETS raycasts en cono SPREAD_CONE_DEG, cooldown alto,
              daño reducido por pellet (daño total dividido entre pellets).

  • NUEVO: Pre-fire — mientras el NPC pierde LOS pero lastSeenPos != nil,
    dispara hacia esa posición con ruido aleatorio. Activado por característica:
    Bravery siempre, Obedient 50%, Fear nunca.

  • NUEVO: STATE.SEARCH — cuando loseSightTimer vence, el NPC no va directo
    a ALERT sino que entra en búsqueda activa: recorre lastSeenPos y 2 puntos
    satélite alrededor. Si redetecta → COMBAT. Si agota puntos → ALERT.

  • NUEVO: BehaviorRole = "Rusher" — el NPC corre al jugador sin disparar.
    Puede surrenderear a mitad del rush si Fear es alto y está cerca.
    willDrawWeapon se fuerza false para Rushers.

  CAMBIOS vs v3.1
  ---------------
  • FIX accesorios (Chest / Backpage) — eliminado el WeldConstraint manual al
    HRP que causaba que la mochila y el chaleco se "congelaran" en posición
    absoluta durante animaciones (Ziptie, Surrender, etc.).

  • Los accesorios ahora siguen al modelo a través de sus AccessoryWeld nativos
    de Roblox, sin ninguna intervención del script durante el gameplay normal.

  • En ragdoll, el sistema accessorySnapshot (PASO 3.5) sigue recreando los
    AccessoryWeld como WeldConstraint rígidos, porque Humanoid.Died los destruye.
    Esto aplica SOLO al momento de la muerte.

  • Eliminados también los bloques de applyRagdoll() que destruían Chest/Backpage
    y los marcaban como Massless, ya que ya no son necesarios.

================================================================================
]]

local NPC           = script.Parent
local Humanoid      = NPC:WaitForChild("Humanoid")
local HRP           = NPC:WaitForChild("HumanoidRootPart")
local Head          = NPC:WaitForChild("Head")
local PathService   = game:GetService("PathfindingService")
local Players       = game:GetService("Players")
local RS            = game:GetService("RunService")

NPC:SetAttribute("Flashbanged", false)

do
	local function ensureRE(name)
		if not game.ReplicatedStorage:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name, r.Parent = name, game.ReplicatedStorage
		end
	end
	ensureRE("IntimidateVoice")
	ensureRE("ArrestVoice")
	ensureRE("FlashbangVoice")
end

-- ── CONFIGURACIÓN ────────────────────────────────────────────────────────────
local CFG = {
	SIGHT_RANGE          = 50,
	SIGHT_FOV            = 110,
	ATTACK_RANGE         = 5,
	SHOOT_RANGE          = 30,
	SHOOT_COOLDOWN       = 1.2,
	MELEE_COOLDOWN       = 2.0,
	MELEE_DAMAGE         = 20,
	BULLET_DAMAGE        = 10,
	WALK_SPEED           = 16,
	RUN_SPEED            = 18,
	INTIMIDATE_RANGE     = 10,
	SURRENDER_HP_PCT     = 0.25,
	PATROL_WAIT          = 3,
	PATROL_BLOCKED_MAX   = 3,
	PATH_RECALC_INTERVAL = 0.6,
	WAYPOINT_TIMEOUT     = 1.5,
	ALERT_EVAL_TIME      = 0.7,
	IDLE_LOOK_INTERVAL   = 4,
	LOSE_SIGHT_BUFFER    = 1.5,
	OUT_OF_RANGE_BUFFER  = 4.0,
	ROTATION_SPEED_DEG   = 280,
	MELEE_CHASE_DIST     = 0,

	-- ── WEAPON TYPE ──────────────────────────────────────────────────────────
	-- Leído desde atributo NPC "WeaponType". Valores: "Semi", "Auto", "Spread".
	-- Si el atributo no existe, default "Semi" (comportamiento original).
	WEAPON_TYPE          = "Semi",

	-- Auto: cadencia de bala individual y tamaño de ráfaga.
	-- Entre ráfagas se usa SHOOT_COOLDOWN normal como pausa.
	AUTO_FIRE_RATE       = 0.09,   -- segundos entre balas dentro de una ráfaga
	AUTO_BURST_SIZE      = 5,      -- cuántas balas por ráfaga antes de pausa

	-- Spread: pellets simultáneos y ángulo del cono.
	-- El daño por pellet = BULLET_DAMAGE / SPREAD_PELLETS (daño total igual).
	SPREAD_PELLETS       = 6,
	SPREAD_CONE_DEG      = 14,     -- semiángulo del cono en grados
	SPREAD_COOLDOWN      = 1.8,    -- cooldown específico para escopeta

	-- ── SEARCH ───────────────────────────────────────────────────────────────
	SEARCH_RADIUS        = 15,     -- radio de puntos satélite alrededor de lastSeenPos
	SEARCH_POINTS        = 2,      -- puntos satélite a generar además de lastSeenPos
	SEARCH_TIMEOUT       = 12,     -- segundos antes de abandonar la búsqueda
	SEARCH_POINT_WAIT    = 1.5,    -- pausa en cada punto antes de continuar

	-- ── PRE-FIRE ─────────────────────────────────────────────────────────────
	PREFIRE_NOISE        = 4,      -- radio de dispersión aleatoria en studs
}
CFG.MELEE_CHASE_DIST = CFG.ATTACK_RANGE + 6

-- ── ESTADOS ──────────────────────────────────────────────────────────────────
local STATE = {
	PATROL    = "PATROL",
	ALERT     = "ALERT",
	COMBAT    = "COMBAT",
	MELEE     = "MELEE",
	SURRENDER = "SURRENDER",
	ARRESTED  = "ARRESTED",
	DEAD      = "DEAD",
	FLEE      = "FLEE",
	STUNNED   = "STUNNED",
	SEARCH    = "SEARCH",
}

-- ── VARIABLES DE ESTADO INTERNO ───────────────────────────────────────────────
local state          = STATE.PATROL
local target         = nil
local targetDiedConn = nil
local lastShot       = 0
local lastMelee      = 0
local surrendered    = false
local arrested       = false
local weaponDrawn    = false
local isBusy         = false

local moveToken   = 0
local spawnActive = false
local patrolToken = 0
local chaseActive = false

local lastPatrolArrival = -math.huge
local patrolWaitTimer   = 0

local stateDecision = {
	willFight      = false,
	willFlee       = false,
	willDrawWeapon = false,
}

local loseSightTimer      = 0
local lastSeenPos         = nil
local outOfRangeTimer     = 0
local fleeCycleCount      = 0
local fleeTargetDist      = 0
local fleeCooldown        = 0
local combatDecisionTimer = 0
local lastDetectedPlayer  = nil
local detectionCooldown   = 0
local lastDamageReaction  = 0
local alertEvalTimer      = 0
local alertEvalStarted    = false
local originPosition      = HRP.Position
local patrolRadius        = NPC:GetAttribute("PatrolRadius") or 40

local currentPatrolPoint    = nil
local patrolBlockedAttempts = 0
local lastIdleLook          = 0
local nextPath              = nil
local nextPathReady         = false
local nextPathTarget        = nil

local meleeChasing = false

-- ── VARIABLES DE ARMA AUTOMÁTICA ─────────────────────────────────────────────
local lastAutoBullet  = 0   -- tick() del último disparo individual en modo Auto
local autoBurstCount  = 0   -- balas disparadas en la ráfaga actual

-- ── VARIABLES DE BÚSQUEDA (SEARCH) ───────────────────────────────────────────
local searchPoints       = {}   -- lista de Vector3 a recorrer
local searchIndex        = 0    -- índice actual en searchPoints
local searchTimer        = 0    -- acumulador de tiempo en estado SEARCH
local searchPointActive  = false -- true mientras spawnMove hacia un punto está activo
local searchArrivalTime  = 0    -- tick() en que se llegó al punto actual

-- ── ROTACIÓN SUAVE ────────────────────────────────────────────────────────────
local bodyGyro = Instance.new("BodyGyro")
bodyGyro.MaxTorque = Vector3.new(0, 4e5, 0)
bodyGyro.D         = 100
bodyGyro.P         = 2e4
bodyGyro.CFrame    = HRP.CFrame
bodyGyro.Parent    = HRP

local rotEnabled   = false
local rotTargetPos = nil

local function setRotationTarget(lookPos)
	if not rotEnabled then return end
	rotTargetPos = lookPos
end

local function enableRotation(enabled)
	rotEnabled = enabled
	if not enabled then
		rotTargetPos = nil
		bodyGyro.MaxTorque = Vector3.new(0, 0, 0)
	else
		bodyGyro.MaxTorque = Vector3.new(0, 4e5, 0)
	end
end

RS.Heartbeat:Connect(function()
	if not rotEnabled or not rotTargetPos then return end
	local dir = Vector3.new(rotTargetPos.X, HRP.Position.Y, rotTargetPos.Z) - HRP.Position
	if dir.Magnitude < 0.5 then return end
	bodyGyro.CFrame = CFrame.lookAt(HRP.Position, HRP.Position + dir)
end)

enableRotation(false)

-- ── CARACTERÍSTICAS ───────────────────────────────────────────────────────────
local CHARACTERISTICS = { BRAVERY = "Bravery", FEAR = "Fear", OBEDIENT = "Obedient" }

local function assignRandomCharacteristic()
	local chars = { CHARACTERISTICS.BRAVERY, CHARACTERISTICS.FEAR, CHARACTERISTICS.OBEDIENT }
	local selected = chars[math.random(1, #chars)]
	NPC:SetAttribute("Characteristic", selected)
	return selected
end

local myCharacteristic = assignRandomCharacteristic()
print("[NPC] Characteristic:", myCharacteristic)

-- ── TIPO DE ARMA Y ROL DE COMPORTAMIENTO ─────────────────────────────────────
--[[
  Si el atributo ya existe en el NPC (puesto manualmente en Studio), se respeta.
  Si no existe, se asigna aleatoriamente con pesos según myCharacteristic,
  exactamente igual a como assignRandomCharacteristic() maneja Characteristic.

  WeaponType pesos por característica:
    Bravery  → Auto 50%, Semi 35%, Spread 15%  (agresivo, prefiere ráfagas)
    Fear     → Semi 60%, Spread 30%, Auto 10%  (conservador, dispara poco)
    Obedient → Semi 40%, Auto 30%, Spread 30%  (equilibrado)

  BehaviorRole pesos por característica:
    Bravery  → Normal 100%  (nunca huye corriendo, siempre pelea)
    Fear     → Rusher 40%, Normal 60%  (corre hacia ti por pánico, no por valentía)
    Obedient → Rusher 20%, Normal 80%
]]
local function assignWeaponType()
	local existing = NPC:GetAttribute("WeaponType")
	if existing and existing ~= "" then return existing end

	local weights
	if myCharacteristic == CHARACTERISTICS.BRAVERY then
		weights = { Auto = 50, Semi = 35, Spread = 15 }
	elseif myCharacteristic == CHARACTERISTICS.FEAR then
		weights = { Semi = 60, Spread = 30, Auto = 10 }
	else -- Obedient
		weights = { Semi = 40, Auto = 30, Spread = 30 }
	end

	local roll = math.random(1, 100)
	local cumulative = 0
	local selected = "Semi"
	for wtype, w in pairs(weights) do
		cumulative += w
		if roll <= cumulative then selected = wtype; break end
	end

	NPC:SetAttribute("WeaponType", selected)
	return selected
end

local function assignBehaviorRole()
	local existing = NPC:GetAttribute("BehaviorRole")
	if existing and existing ~= "" then return existing end

	local rusherChance
	if myCharacteristic == CHARACTERISTICS.BRAVERY then
		rusherChance = 0.0
	elseif myCharacteristic == CHARACTERISTICS.FEAR then
		rusherChance = 0.4
	else -- Obedient
		rusherChance = 0.2
	end

	local selected = (math.random() < rusherChance) and "Rusher" or "Normal"
	NPC:SetAttribute("BehaviorRole", selected)
	return selected
end

local myWeaponType   = assignWeaponType()
local myBehaviorRole = assignBehaviorRole()
CFG.WEAPON_TYPE      = myWeaponType

print("[NPC] WeaponType:", myWeaponType, "| BehaviorRole:", myBehaviorRole)

local AnimManager   = require(NPC:WaitForChild("AnimationManager"))
local AudioManager  = require(NPC:WaitForChild("AudioManager"))
local WeaponManager = require(NPC:WaitForChild("WeaponManager"))
WeaponManager:Holster()

-- ── FIX ACCESORIOS DE CHEST / BACKPAGE ───────────────────────────────────────
-- Chest y Backpage son Models que contienen un Accessory (con Handle adentro).
-- El Humanoid de Roblox detecta cualquier Accessory dentro del modelo y llama
-- AddAccessory() automáticamente al cargar, lo que mueve el Handle fuera y lo
-- suelda al UpperTorso. Si ese proceso tiene conflicto con la jerarquía anidada
-- (Accessory dentro de un Model dentro del NPC), el Handle cae al suelo.
--
-- Solución: mover el Accessory directo al NPC raíz SINCRÓNICAMENTE, antes de
-- que el Humanoid lo detecte. Así Roblox lo equipa como accesorio normal y el
-- Handle queda soldado correctamente al hueso sin caerse.
do
	for _, modelName in ipairs({ "Chest", "Backpage" }) do
		local model = NPC:FindFirstChild(modelName)
		if not model then continue end
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("Accessory") then
				child.Parent = NPC
			end
		end
	end
end

-- ── CFG POR CARACTERÍSTICA ────────────────────────────────────────────────────
local CHAR_CFG = {
	[CHARACTERISTICS.BRAVERY]  = {
		SURRENDER_CHANCE       = 0.10,
		INTIMIDATE_RESIST      = 0.90,
		FLEE_DISTANCE          = 0,
		SIGHT_BONUS            = 15,
		ALERT_TO_COMBAT        = 0.99,
		WEAPON_DRAW_CHANCE     = 1.0,
		NEVER_IGNORE_PLAYER    = true,
		FLEE_MAX_CYCLES        = 5,
		-- Pre-fire: 1.0 = siempre dispara hacia lastSeenPos al perder LOS
		PREFIRE_CHANCE         = 1.0,
		-- Rusher: distancia mínima al jugador para que el rush se rinda a mitad
		-- 0 = nunca se rinde a mitad del rush
		RUSHER_SURRENDER_DIST  = 0,
	},
	[CHARACTERISTICS.FEAR]     = {
		SURRENDER_CHANCE       = 0.50,
		INTIMIDATE_RESIST      = 0.20,
		FLEE_DISTANCE          = 40,
		SIGHT_BONUS            = -10,
		ALERT_TO_COMBAT        = 0.40,
		WEAPON_DRAW_CHANCE     = 0.40,
		NEVER_IGNORE_PLAYER    = false,
		FLEE_MAX_CYCLES        = 1,
		-- Fear nunca prefire — demasiado nervioso para desperdiciar balas
		PREFIRE_CHANCE         = 0.0,
		-- Si el rush llega a menos de 10 studs y el NPC es Fear, puede rendirse
		RUSHER_SURRENDER_DIST  = 10,
	},
	[CHARACTERISTICS.OBEDIENT] = {
		SURRENDER_CHANCE       = 0.60,
		INTIMIDATE_RESIST      = 0.40,
		FLEE_DISTANCE          = 0,
		SIGHT_BONUS            = 0,
		ALERT_TO_COMBAT        = 0.70,
		WEAPON_DRAW_CHANCE     = 0.60,
		NEVER_IGNORE_PLAYER    = false,
		FLEE_MAX_CYCLES        = 2,
		PREFIRE_CHANCE         = 0.5,
		RUSHER_SURRENDER_DIST  = 0,
	},
}

local function getCharConfig()          return CHAR_CFG[myCharacteristic] or CHAR_CFG[CHARACTERISTICS.BRAVERY] end
local function getEffectiveSightRange() return CFG.SIGHT_RANGE + getCharConfig().SIGHT_BONUS end
local function getSurrenderChance()     return getCharConfig().SURRENDER_CHANCE end
local function shouldFleeFromCombat(d)
	local c = getCharConfig()
	return c.FLEE_DISTANCE > 0 and d < c.FLEE_DISTANCE
end

-- ── HELPERS DE DETECCIÓN ──────────────────────────────────────────────────────
local function canSee(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local origin, dest = Head.Position, root.Position
	local dist = (dest - origin).Magnitude
	if dist > getEffectiveSightRange() then return false end
	local angle = math.deg(math.acos(math.clamp(Head.CFrame.LookVector:Dot((dest - origin).Unit), -1, 1)))
	if angle > CFG.SIGHT_FOV / 2 then return false end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { NPC, char }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(origin, dest - origin, params)
	if hit then
		local hitModel = hit.Instance:FindFirstAncestorOfClass("Model")
		if hitModel ~= char then return false end
	end
	return true
end

local function isTargetValid(char)
	if not char then return false end
	local ok, result = pcall(function()
		local h = char:FindFirstChildOfClass("Humanoid")
		local r = char:FindFirstChild("HumanoidRootPart")
		return h and h.Health > 0 and r ~= nil
	end)
	return ok and result
end

local function nearestVisiblePlayer()
	local best, bestD = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if not c then continue end
		local h = c:FindFirstChildOfClass("Humanoid")
		local r = c:FindFirstChild("HumanoidRootPart")
		if h and h.Health > 0 and r then
			local d = (r.Position - HRP.Position).Magnitude
			if d < bestD and canSee(c) then best, bestD = c, d end
		end
	end
	return best
end

-- ── HELPERS DE MOVIMIENTO ────────────────────────────────────────────────────
local function cancelMove()
	moveToken  += 1
	spawnActive = false
	Humanoid:MoveTo(HRP.Position)
end

local function enterState(newState)
	if state == newState then return end
	if state == STATE.PATROL then patrolToken += 1 end
	if newState == STATE.PATROL then
		patrolToken        += 1
		currentPatrolPoint  = nil
		patrolWaitTimer     = CFG.PATROL_WAIT
	end
	if state == STATE.MELEE then
		meleeChasing = false
	end
	-- Limpiar estado de búsqueda al salir de SEARCH
	if state == STATE.SEARCH then
		searchPoints      = {}
		searchIndex       = 0
		searchTimer       = 0
		searchPointActive = false
	end
	state = newState
	cancelMove()
end

local function stopCombatChase()
	moveToken   += 1
	chaseActive  = false
end

-- ── SISTEMA DE PATRULLA ───────────────────────────────────────────────────────
local manualPoints      = {}
local manualIndex       = 0
local usingManualPoints = false

do
	local folder = workspace:FindFirstChild("PatrolPoints")
	if folder then
		local npcFolder = folder:FindFirstChild(NPC.Name)
		if npcFolder then
			local children = npcFolder:GetChildren()
			table.sort(children, function(a, b)
				local na = tonumber(a.Name:match("%d+$")) or 0
				local nb = tonumber(b.Name:match("%d+$")) or 0
				if na ~= nb then return na < nb end
				return a.Name < b.Name
			end)
			for _, pt in ipairs(children) do
				if pt:IsA("BasePart") then
					table.insert(manualPoints, pt.Position)
				end
			end
			usingManualPoints = #manualPoints > 0
		end
	end
end

local function generatePatrolPoint()
	local attempts = 0
	while attempts < CFG.PATROL_BLOCKED_MAX * 2 do
		attempts += 1
		local angle     = math.random() * math.pi * 2
		local distance  = math.random() * patrolRadius * 0.8 + patrolRadius * 0.2
		local candidate = originPosition + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = { NPC }
		rayParams.FilterType                 = Enum.RaycastFilterType.Exclude
		rayParams.RespectCanCollide          = true
		local groundCheck = workspace:Raycast(candidate + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), rayParams)
		if groundCheck then
			local floorPos = groundCheck.Position
			local path     = PathService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
			local ok       = pcall(function() path:ComputeAsync(HRP.Position, floorPos) end)
			if ok and path.Status == Enum.PathStatus.Success then return floorPos end
		end
	end
	return nil
end

local function onPathBlocked()
	patrolBlockedAttempts += 1
	if patrolBlockedAttempts >= CFG.PATROL_BLOCKED_MAX then
		currentPatrolPoint    = nil
		patrolBlockedAttempts = 0
	end
end

local function getNextPatrolPoint()
	if usingManualPoints then
		if currentPatrolPoint and (currentPatrolPoint - HRP.Position).Magnitude > 3 then
			return currentPatrolPoint
		end
		manualIndex        = (manualIndex % #manualPoints) + 1
		currentPatrolPoint = manualPoints[manualIndex]
		return currentPatrolPoint
	end
	if currentPatrolPoint and (currentPatrolPoint - HRP.Position).Magnitude > 3 then
		return currentPatrolPoint
	end
	patrolBlockedAttempts = 0
	currentPatrolPoint    = generatePatrolPoint()
	return currentPatrolPoint
end

-- ── PATH LOOKAHEAD ────────────────────────────────────────────────────────────
local function precalcPath(targetPos)
	nextPathReady  = false
	nextPathTarget = targetPos
	task.spawn(function()
		local p  = PathService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(function() p:ComputeAsync(HRP.Position, targetPos) end)
		if ok and p.Status == Enum.PathStatus.Success then
			nextPath = p; nextPathReady = true
		else
			nextPath = nil; nextPathReady = false
		end
	end)
end

-- ── MOVETO PRINCIPAL ──────────────────────────────────────────────────────────
local function moveTo(pos, running, gunMode, myToken)
	local function stateOk()
		return state == STATE.PATROL or state == STATE.ALERT
			or state == STATE.FLEE   or state == STATE.COMBAT
			or state == STATE.SEARCH
	end

	if not stateOk() then return end
	if myToken ~= moveToken then return end

	Humanoid.WalkSpeed = running and CFG.RUN_SPEED or CFG.WALK_SPEED

	if gunMode and weaponDrawn then
		AnimManager:PlayMovement("Walk")
	elseif running then
		AnimManager:PlayMovement("Run")
	else
		AnimManager:PlayMovement("Walk")
	end

	local path
	if nextPathReady and nextPathTarget and (nextPathTarget - pos).Magnitude < 2 then
		path          = nextPath
		nextPathReady = false
	else
		path     = PathService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(function() path:ComputeAsync(HRP.Position, pos) end)
		if not ok or path.Status ~= Enum.PathStatus.Success then
			if myToken == moveToken then
				Humanoid:MoveTo(pos)
				onPathBlocked()
			end
			return
		end
	end

	local waypoints = path:GetWaypoints()
	for i, wp in ipairs(waypoints) do
		if myToken ~= moveToken then return end
		if not stateOk() or isBusy then return end

		if wp.Action == Enum.PathWaypointAction.Jump then Humanoid.Jump = true end
		Humanoid:MoveTo(wp.Position)

		local reached = false
		local conn
		conn = Humanoid.MoveToFinished:Connect(function(r)
			reached = r
			conn:Disconnect()
		end)
		local elapsed = 0
		while not reached and elapsed < CFG.WAYPOINT_TIMEOUT do
			elapsed += RS.Heartbeat:Wait()
			if myToken ~= moveToken or not stateOk() or isBusy then
				conn:Disconnect()
				return
			end
		end
		if not reached then conn:Disconnect() end

		if i < #waypoints then precalcPath(pos) end
	end

	if myToken == moveToken and state == STATE.PATROL then
		currentPatrolPoint  = nil
		lastPatrolArrival   = tick()
		AnimManager:PlayMovement("Idle")
	end
end

-- ── MOVIMIENTO DE HUIDA ───────────────────────────────────────────────────────
local function startFlee(myToken)
	if not target then return end
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr then return end
	local fleeDir  = (HRP.Position - tr.Position).Unit
	local fleeDist = math.random(30, 60)
	fleeTargetDist = fleeDist
	fleeCooldown   = tick() + 3
	local fleePos  = HRP.Position + fleeDir * fleeDist
	local path     = PathService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local ok       = pcall(function() path:ComputeAsync(HRP.Position, fleePos) end)
	if state ~= STATE.FLEE or myToken ~= moveToken then return end
	Humanoid.WalkSpeed = CFG.RUN_SPEED * 1.2
	AnimManager:PlayMovement("Run")
	if not ok or path.Status ~= Enum.PathStatus.Success then
		Humanoid:MoveTo(fleePos)
		return
	end
	for _, wp in ipairs(path:GetWaypoints()) do
		if state ~= STATE.FLEE or myToken ~= moveToken or isBusy then return end
		if wp.Action == Enum.PathWaypointAction.Jump then Humanoid.Jump = true end
		Humanoid:MoveTo(wp.Position)
		local reached = false
		local conn
		conn = Humanoid.MoveToFinished:Connect(function(r) reached = r; conn:Disconnect() end)
		local elapsed = 0
		while not reached and elapsed < CFG.WAYPOINT_TIMEOUT do
			elapsed += RS.Heartbeat:Wait()
			if state ~= STATE.FLEE or myToken ~= moveToken or isBusy then conn:Disconnect(); return end
		end
		if not reached then conn:Disconnect() end
	end
	if myToken == moveToken and state == STATE.FLEE then
		AnimManager:PlayMovement("Idle")
	end
end

-- ── TRACKING DEL TARGET ──────────────────────────────────────────────────────
local function onTargetDied()
	if targetDiedConn then
		targetDiedConn:Disconnect()
		targetDiedConn = nil
	end

	WeaponManager:ForceHolster()
	weaponDrawn = false
	AnimManager:StopGunAnims()

	isBusy       = false
	target       = nil
	chaseActive  = false
	spawnActive  = false
	meleeChasing = false
	stopCombatChase()
	cancelMove()
	enableRotation(false)

	if state == STATE.COMBAT or state == STATE.MELEE
		or state == STATE.ALERT or state == STATE.FLEE
		or state == STATE.SEARCH then
		enterState(STATE.PATROL)
	end
end

local function setTarget(char)
	if targetDiedConn then
		targetDiedConn:Disconnect()
		targetDiedConn = nil
	end

	target = char

	if char then
		local h = char:FindFirstChildOfClass("Humanoid")
		if h then
			targetDiedConn = h.Died:Connect(onTargetDied)
		end
	end
end

-- ── DRAW / HOLSTER ────────────────────────────────────────────────────────────
local function drawWeapon()
	if weaponDrawn then return end
	weaponDrawn = true
	WeaponManager:Equip()
	pcall(function()
		AnimManager:PlayAction("Draw")
		AudioManager:Play("Draw")
	end)
end

local function holsterWeapon()
	if not weaponDrawn then return end
	weaponDrawn = false
	WeaponManager:Holster()
	AnimManager:StopGunAnims()
end

-- ── DISPARO ───────────────────────────────────────────────────────────────────
local RELOAD_COOLDOWN  = 4
local lastReload       = 0
local shotCount        = 0
local SHOTS_PER_RELOAD = math.random(6, 12)

--[[
  getMuzzlePos()
  --------------
  Devuelve la posición del GunMuzzle attachment si existe,
  o Head.Position como fallback. Compartido por los tres modos de disparo.
]]
local function getMuzzlePos()
	for _, d in ipairs(NPC:GetDescendants()) do
		if d:IsA("Attachment") and d.Name == "GunMuzzle" then
			return d.WorldPosition
		end
	end
	return Head.Position
end

--[[
  fireBullet(muzzlePos, direction, damage)
  ----------------------------------------
  Lanza un raycast desde muzzlePos en direction*SHOOT_RANGE.
  Aplica daño si golpea un Humanoid. Dispara NPCBulletFX a los clientes.
  Usado por los tres modos de disparo para no duplicar lógica.
]]
local npcBulletFX = nil
local function ensureBulletFX()
	if npcBulletFX and npcBulletFX.Parent then return npcBulletFX end
	npcBulletFX = game.ReplicatedStorage:FindFirstChild("NPCBulletFX")
	if not npcBulletFX then
		npcBulletFX        = Instance.new("RemoteEvent")
		npcBulletFX.Name   = "NPCBulletFX"
		npcBulletFX.Parent = game.ReplicatedStorage
	end
	return npcBulletFX
end

local function fireBullet(muzzlePos, direction, damage)
	local dir    = direction.Unit * CFG.SHOOT_RANGE
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { NPC }
	params.FilterType                 = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(muzzlePos, dir, params)
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model then
			local h = model:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then h:TakeDamage(damage) end
		end
	end
	ensureBulletFX():FireAllClients(muzzlePos, hit and hit.Position or (muzzlePos + dir))
end

--[[
  tryReload()
  -----------
  Comprueba si toca recargar. Devuelve true si inició recarga (el caller
  debe hacer return). Compartido por Semi y Auto.
]]
local function tryReload()
	if shotCount >= SHOTS_PER_RELOAD and not AnimManager:IsReloading() then
		shotCount        = 0
		SHOTS_PER_RELOAD = math.random(6, 12)
		lastReload       = tick()
		isBusy           = true
		AnimManager:PlayAction("Reload")
		AudioManager:Play("Reload")
		task.delay(1.2, function() isBusy = false end)
		return true
	end
	return false
end

--[[
  shootSemi(aimPos)
  -----------------
  Comportamiento original: un raycast por llamada, cooldown SHOOT_COOLDOWN.
  aimPos: Vector3 destino (puede ser posición del target o lastSeenPos para prefire).
]]
local function shootSemi(aimPos)
	if tick() - lastShot < CFG.SHOOT_COOLDOWN then return end
	if isBusy then return end
	lastShot = tick()
	if tryReload() then return end
	shotCount += 1
	AnimManager:PlayAction("Shoot")
	AudioManager:Play("Shoot")
	local muzzle = getMuzzlePos()
	fireBullet(muzzle, aimPos - muzzle, CFG.BULLET_DAMAGE)
end

--[[
  shootAuto(aimPos)
  -----------------
  Dispara una ráfaga de AUTO_BURST_SIZE balas a cadencia AUTO_FIRE_RATE.
  Entre ráfagas hace una pausa de SHOOT_COOLDOWN (igual que Semi).
  Cada bala individual tiene animación Shoot + audio para feedback visual.
  aimPos: Vector3 destino.
]]
local function shootAuto(aimPos)
	-- Pausa entre ráfagas
	if tick() - lastShot < CFG.SHOOT_COOLDOWN then return end
	if isBusy then return end
	if tryReload() then return end

	-- Marcar inicio de ráfaga
	lastShot = tick()
	autoBurstCount = 0

	task.spawn(function()
		for i = 1, CFG.AUTO_BURST_SIZE do
			if state ~= STATE.COMBAT then break end
			if isBusy then break end

			-- Cadencia individual
			if i > 1 then
				local waited = 0
				repeat
					waited += RS.Heartbeat:Wait()
				until waited >= CFG.AUTO_FIRE_RATE or state ~= STATE.COMBAT
				if state ~= STATE.COMBAT then break end
			end

			shotCount      += 1
			autoBurstCount += 1
			lastAutoBullet  = tick()

			AnimManager:PlayAction("Shoot")
			AudioManager:Play("Shoot")
			local muzzle = getMuzzlePos()
			-- Pequeña dispersión por bala para que las ráfagas no sean láser
			local noise = Vector3.new(
				math.random(-1, 1) * 0.5,
				math.random(-1, 1) * 0.3,
				math.random(-1, 1) * 0.5
			)
			fireBullet(muzzle, (aimPos + noise) - muzzle, CFG.BULLET_DAMAGE)

			if tryReload() then break end
		end
		autoBurstCount = 0
	end)
end

--[[
  shootSpread(aimPos)
  -------------------
  Dispara SPREAD_PELLETS raycasts en cono de SPREAD_CONE_DEG grados.
  Daño por pellet = BULLET_DAMAGE / SPREAD_PELLETS (daño total idéntico a Semi).
  Cooldown propio (SPREAD_COOLDOWN) para simular recarga de escopeta.
  Un solo Shoot animation y audio por disparo completo.
  aimPos: Vector3 destino.
]]
local function shootSpread(aimPos)
	if tick() - lastShot < CFG.SPREAD_COOLDOWN then return end
	if isBusy then return end
	lastShot = tick()
	if tryReload() then return end
	shotCount += 1

	AnimManager:PlayAction("Shoot")
	AudioManager:Play("Shoot")

	local muzzle       = getMuzzlePos()
	local baseDir      = (aimPos - muzzle).Unit
	local pelletDamage = math.max(1, math.floor(CFG.BULLET_DAMAGE / CFG.SPREAD_PELLETS))
	local halfCone     = math.rad(CFG.SPREAD_CONE_DEG)

	-- Construir un frame de referencia perpendicular a baseDir
	local up      = Vector3.new(0, 1, 0)
	local right   = baseDir:Cross(up)
	if right.Magnitude < 0.01 then
		right = baseDir:Cross(Vector3.new(1, 0, 0))
	end
	right = right.Unit
	local actualUp = right:Cross(baseDir).Unit

	for _ = 1, CFG.SPREAD_PELLETS do
		-- Punto aleatorio dentro del cono usando método de disco uniforme
		local angle  = math.random() * math.pi * 2
		local radius = math.tan(halfCone) * math.sqrt(math.random())
		local offsetDir = baseDir
			+ right    * (math.cos(angle) * radius)
			+ actualUp * (math.sin(angle) * radius)
		fireBullet(muzzle, offsetDir, pelletDamage)
	end
end

--[[
  shoot(char, overridePos)
  ------------------------
  Dispatcher principal. Despacha al modo correcto según CFG.WEAPON_TYPE.
  overridePos: si se pasa, se usa como destino en vez del HRP del char.
               Usado por pre-fire para disparar hacia lastSeenPos.
  char puede ser nil cuando se llama desde pre-fire (solo se usa para HRP fallback).
]]
local function shoot(char, overridePos)
	local aimPos = overridePos
	if not aimPos then
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		aimPos = root.Position
	end

	local wt = CFG.WEAPON_TYPE
	if wt == "Auto" then
		shootAuto(aimPos)
	elseif wt == "Spread" then
		shootSpread(aimPos)
	else
		shootSemi(aimPos)
	end
end

-- ── MELEE ─────────────────────────────────────────────────────────────────────
local function melee(char)
	if tick() - lastMelee < CFG.MELEE_COOLDOWN then return end
	lastMelee = tick()
	AnimManager:PlayAction("Melee")
	AudioManager:Play("Melee")
	task.wait(0.35)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if (root.Position - HRP.Position).Magnitude <= CFG.ATTACK_RANGE + 2 then
		local h = char:FindFirstChildOfClass("Humanoid")
		if h then h:TakeDamage(CFG.MELEE_DAMAGE) end
	end
end

-- ── LOOP DE CHASE EN COMBATE ─────────────────────────────────────────────────
local function startCombatChase(myToken, wantsGun)
	if chaseActive then return end
	chaseActive = true
	task.spawn(function()
		while state == STATE.COMBAT and myToken == moveToken do
			local tr = target and target:FindFirstChild("HumanoidRootPart")
			if not tr then break end
			local dist = (tr.Position - HRP.Position).Magnitude

			local stopDist = wantsGun and (CFG.SHOOT_RANGE * 0.7) or CFG.ATTACK_RANGE
			if dist <= stopDist then break end

			local heightDiff = math.abs(tr.Position.Y - HRP.Position.Y)
			if heightDiff > 3 then
				local path = PathService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
				local ok   = pcall(function() path:ComputeAsync(HRP.Position, tr.Position) end)
				if ok and path.Status == Enum.PathStatus.Success then
					local wps = path:GetWaypoints()
					if wps[2] then
						Humanoid:MoveTo(wps[2].Position)
						if wps[2].Action == Enum.PathWaypointAction.Jump then
							Humanoid.Jump = true
						end
					end
				else
					Humanoid:MoveTo(tr.Position)
				end
			else
				Humanoid:MoveTo(tr.Position)
			end

			task.wait(0.1)
		end
		chaseActive = false
		if state == STATE.COMBAT then
			Humanoid:MoveTo(HRP.Position)
		end
	end)
end

-- ── SURRENDER Y ARRESTO ───────────────────────────────────────────────────────
local function doSurrender()
	if surrendered or arrested or state == STATE.DEAD then return end
	surrendered = true
	enableRotation(false)
	stopCombatChase()
	cancelMove()
	state = STATE.SURRENDER
	isBusy = true

	weaponDrawn = false
	AnimManager:StopGunAnims()
	WeaponManager:Drop()

	AnimManager:StopAll()
	Humanoid.WalkSpeed = 0
	Humanoid:MoveTo(HRP.Position)
	AnimManager:PlayAction("Surrender")
	AudioManager:Play("Surrender")
	NPC:SetAttribute("Surrendered", true)
end

local function startArrestFollow() end

local function doArrest()
	if not surrendered or arrested then return false end
	arrested = true
	state    = STATE.ARRESTED
	isBusy   = false
	AnimManager:StopAll()
	Humanoid.WalkSpeed = 0
	Humanoid:MoveTo(HRP.Position)
	AnimManager:PlayAction("Ziptie")
	AudioManager:Play("Ziptie")
	NPC:SetAttribute("Arrested", true)
	task.delay(5, function() if arrested then startArrestFollow() end end)
	local e = game.ReplicatedStorage:FindFirstChild("NPCArrested")
	if e then e:FireAllClients(NPC) end
	local arrestVoice = game.ReplicatedStorage:FindFirstChild("ArrestVoice")
	if arrestVoice then
		local closest, closestDist = nil, math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			if c and c:FindFirstChild("HumanoidRootPart") then
				local d = (c.HumanoidRootPart.Position - HRP.Position).Magnitude
				if d < closestDist then closest, closestDist = p, d end
			end
		end
		if closest then arrestVoice:FireClient(closest) end
	end
	return true
end

local arrestBind = Instance.new("BindableFunction")
arrestBind.Name, arrestBind.Parent, arrestBind.OnInvoke = "TryArrest", NPC, doArrest

-- ── PROXIMITY PROMPT ──────────────────────────────────────────────────────────
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText, prompt.ObjectText, prompt.MaxActivationDistance = "Arrest", NPC.Name, 4
prompt.HoldDuration, prompt.RequiresLineOfSight, prompt.Enabled, prompt.Parent = 1.5, false, false, HRP
NPC:GetAttributeChangedSignal("Surrendered"):Connect(function()
	prompt.Enabled = NPC:GetAttribute("Surrendered") == true and not arrested
end)
prompt.Triggered:Connect(function(_player)
	if surrendered then doArrest(); prompt.Enabled = false end
end)

-- ── INTIMIDACIÓN ──────────────────────────────────────────────────────────────
local intimidateEvt = game.ReplicatedStorage:FindFirstChild("IntimidateNPC")
	or (function() local r = Instance.new("RemoteEvent"); r.Name = "IntimidateNPC"; r.Parent = game.ReplicatedStorage; return r end)()
intimidateEvt.OnServerEvent:Connect(function(player, npcModel)
	if npcModel ~= NPC or state == STATE.DEAD or arrested then return end
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	if (char.HumanoidRootPart.Position - HRP.Position).Magnitude > CFG.INTIMIDATE_RANGE then return end
	local intimidateVoice = game.ReplicatedStorage:FindFirstChild("IntimidateVoice")
	if intimidateVoice then intimidateVoice:FireClient(player) end
	if math.random() < getCharConfig().INTIMIDATE_RESIST then
		setTarget(char); state = STATE.COMBAT
	else
		doSurrender()
	end
end)

-- ── FLASHBANG ─────────────────────────────────────────────────────────────────
local lastFlashbang = 0
local function onFlashbang()
	if tick() - lastFlashbang < 1.5 then return end
	if state == STATE.DEAD or state == STATE.SURRENDER or state == STATE.ARRESTED then return end
	lastFlashbang = tick()
	enableRotation(false)
	cancelMove()
	state  = STATE.STUNNED
	isBusy = true
	Humanoid.WalkSpeed = 0
	Humanoid:MoveTo(HRP.Position)
	AnimManager:StopAll()
	AnimManager:PlayAction("FlashbangReaction")
	AudioManager:Play("Flashbanged")
	task.delay(5, function()
		if state ~= STATE.STUNNED then return end
		NPC:SetAttribute("Flashbanged", false)
		isBusy             = false
		Humanoid.WalkSpeed = CFG.WALK_SPEED
		AnimManager:Stop("FlashbangReaction")
		local visible = nearestVisiblePlayer()
		if visible then
			setTarget(visible)
			local tr   = visible:FindFirstChild("HumanoidRootPart")
			local dist = tr and (tr.Position - HRP.Position).Magnitude or math.huge
			local cfg  = getCharConfig()
			stateDecision.willFlee       = cfg.FLEE_DISTANCE > 0 and dist < cfg.FLEE_DISTANCE
			stateDecision.willFight      = not stateDecision.willFlee and math.random() < cfg.ALERT_TO_COMBAT
			stateDecision.willDrawWeapon = math.random() < cfg.WEAPON_DRAW_CHANCE
			alertEvalTimer   = 0
			alertEvalStarted = false
			enableRotation(true)

			if not stateDecision.willDrawWeapon then
				holsterWeapon()
			end

			state = STATE.ALERT
		else
			setTarget(nil)
			holsterWeapon()
			state  = STATE.PATROL
			AnimManager:PlayMovement("Idle")
		end
	end)
end

NPC:GetAttributeChangedSignal("Flashbanged"):Connect(function()
	if NPC:GetAttribute("Flashbanged") then onFlashbang() end
end)
task.spawn(function()
	task.wait(0.5)
	if NPC:GetAttribute("Flashbanged") then onFlashbang() end
end)

-- ── MUERTE / DESCONEXIÓN DE JUGADOR ──────────────────────────────────────────
local function cleanTargetForPlayer(player)
	if not target then return end
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if targetPlayer ~= player then return end
	setTarget(nil)
	isBusy          = false
	spawnActive     = false
	chaseActive     = false
	meleeChasing    = false
	patrolWaitTimer = CFG.PATROL_WAIT
	stopCombatChase()
	cancelMove()
	if state == STATE.COMBAT or state == STATE.MELEE
		or state == STATE.ALERT or state == STATE.FLEE
		or state == STATE.SEARCH then
		enableRotation(false)
		holsterWeapon()
		enterState(STATE.PATROL)
	end
end

local function watchPlayer(player)
	player.CharacterRemoving:Connect(function(_oldCharacter)
		cleanTargetForPlayer(player)
	end)
	player.CharacterAdded:Connect(function(_newCharacter)
		cleanTargetForPlayer(player)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)

-- ── RAGDOLL ────────────────────────────────────────────────────────────────────
--[[
  Los accesorios (Chest, Backpage) siguen al modelo a través de sus
  AccessoryWeld nativos durante el gameplay normal — sin ningún weld manual.

  En el ragdoll (PASO 0) se destruyen instantáneamente antes de que el cuerpo
  se "derrita", así no vuelan sueltos como piezas de lego.
]]
local jointSnapshot     = {}
local rootJointSnapshot = nil

task.delay(1, function()
	for _, d in ipairs(NPC:GetDescendants()) do
		if d:IsA("Motor6D") then
			if d.Name == "RootJoint" then
				rootJointSnapshot = {
					motor = d,
					Part0 = d.Part0,
					Part1 = d.Part1,
					C0    = d.C0,
					C1    = d.C1,
				}
			else
				table.insert(jointSnapshot, {
					part0 = d.Part0,
					part1 = d.Part1,
					c0    = d.C0,
					c1    = d.C1,
					motor = d,
				})
			end
		end
	end
	print("[NPC Ragdoll] Joints:", #jointSnapshot, "| RootJoint:", rootJointSnapshot ~= nil)
end)

local function applyRagdoll()
	-- PASO 0: eliminar chaleco y mochila instantáneamente antes del ragdoll.
	-- Los Accessory fueron movidos al NPC raíz al inicio del script, así que
	-- destruimos tanto los Model originales como los Accessory sueltos del NPC.
	for _, modelName in ipairs({ "Chest", "Backpage" }) do
		local m = NPC:FindFirstChild(modelName)
		if m then m:Destroy() end
	end
	for _, child in ipairs(NPC:GetChildren()) do
		if child:IsA("Accessory") then
			child:Destroy()
		end
	end

	-- PASO 1: destruir WeaponGrip
	local weaponGrip = NPC:FindFirstChild("WeaponGrip", true)
	if weaponGrip then weaponGrip:Destroy() end

	-- PASO 2: convertir RootJoint → BallSocketConstraint
	if rootJointSnapshot then
		local rj = rootJointSnapshot
		local p0, p1, c0, c1 = rj.Part0, rj.Part1, rj.C0, rj.C1
		if rj.motor and rj.motor.Parent then rj.motor:Destroy() end
		if p0 and p1 and p0.Parent and p1.Parent then
			local att0  = Instance.new("Attachment")
			att0.CFrame = c0
			att0.Name   = "RagdollA0"
			att0.Parent = p0
			local att1  = Instance.new("Attachment")
			att1.CFrame = c1
			att1.Name   = "RagdollA1"
			att1.Parent = p1
			local bsc              = Instance.new("BallSocketConstraint")
			bsc.Attachment0        = att0
			bsc.Attachment1        = att1
			bsc.LimitsEnabled      = true
			bsc.UpperAngle         = 10
			bsc.TwistLimitsEnabled = false
			bsc.Parent             = p0
		end
	end

	-- PASO 3: bodyGyro off
	pcall(function() bodyGyro.MaxTorque = Vector3.new(0, 0, 0) end)

	-- PASO 3: convertir Motor6D → BallSocketConstraint usando snapshot
	if #jointSnapshot == 0 then
		warn("[NPC Ragdoll] Snapshot vacío — ragdoll no aplicado.")
	end

	for _, j in ipairs(jointSnapshot) do
		local part0 = j.part0
		local part1 = j.part1
		if not part0 or not part1 then continue end
		if not part0.Parent or not part1.Parent then continue end

		if j.motor and j.motor.Parent then
			j.motor:Destroy()
		end

		local att0  = Instance.new("Attachment")
		att0.CFrame = j.c0
		att0.Name   = "RagdollA0"
		att0.Parent = part0

		local att1  = Instance.new("Attachment")
		att1.CFrame = j.c1
		att1.Name   = "RagdollA1"
		att1.Parent = part1

		local bsc              = Instance.new("BallSocketConstraint")
		bsc.Attachment0        = att0
		bsc.Attachment1        = att1
		bsc.LimitsEnabled      = true
		bsc.UpperAngle         = 60
		bsc.TwistLimitsEnabled = false
		bsc.Parent             = part0
	end

	-- PASO 4: desanclar todas las partes
	for _, part in ipairs(NPC:GetDescendants()) do
		if not part:IsA("BasePart") then continue end
		part.Anchored   = false
		part.CanCollide = true
		part.Massless   = false
	end
	HRP.CanCollide = false

	-- PASO 5: impulso de muerte
	local kickVel    = Instance.new("BodyVelocity")
	kickVel.Velocity = Vector3.new(math.random(-8, 8), 1, math.random(-8, 8))
	kickVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	kickVel.P        = 1e5
	kickVel.Parent   = HRP
	game:GetService("Debris"):AddItem(kickVel, 0.15)
end

-- ── MUERTE DEL NPC ────────────────────────────────────────────────────────────
Humanoid.Died:Connect(function()
	state = STATE.DEAD
	enableRotation(false)
	stopCombatChase()
	cancelMove()
	prompt.Enabled = false
	AnimManager:StopAll()
	WeaponManager:Drop()
	applyRagdoll()
end)

-- ── REACCIÓN AL DAÑO ─────────────────────────────────────────────────────────
local prevHealth         = Humanoid.Health
local damageStaggerToken = 0

local function applyDamageStagger()
	damageStaggerToken += 1
	local token        = damageStaggerToken
	local restoreSpeed = Humanoid.WalkSpeed
	Humanoid.WalkSpeed = 0
	task.delay(0.2, function()
		if token ~= damageStaggerToken then return end
		if state == STATE.DEAD or state == STATE.SURRENDER or state == STATE.ARRESTED or state == STATE.STUNNED then return end
		Humanoid.WalkSpeed = 7
		task.delay(0.8, function()
			if token ~= damageStaggerToken then return end
			if state == STATE.DEAD or state == STATE.SURRENDER or state == STATE.ARRESTED or state == STATE.STUNNED then return end
			Humanoid.WalkSpeed = restoreSpeed
		end)
	end)
end

Humanoid.HealthChanged:Connect(function(hp)
	if (state == STATE.COMBAT or state == STATE.FLEE) and hp / Humanoid.MaxHealth < CFG.SURRENDER_HP_PCT then
		if math.random() < getSurrenderChance() then doSurrender() end
	end
	local damageTaken = prevHealth - hp
	if damageTaken > 0 and tick() - lastDamageReaction > 0.3 then
		lastDamageReaction = tick()
		AudioManager:Play("Shot")
		applyDamageStagger()
	end
	prevHealth = hp
end)

-- ═══════════════════════════════════════════════════════════════════════════════
--  LOOP PRINCIPAL DE IA
-- ═══════════════════════════════════════════════════════════════════════════════
local function spawnMove(pos, running, gunMode)
	if spawnActive then return end
	cancelMove()
	spawnActive = true
	local t = moveToken
	task.spawn(function()
		moveTo(pos, running, gunMode, t)
		spawnActive = false
	end)
end

local function spawnFlee()
	if spawnActive then return end
	spawnActive = true
	cancelMove()
	local t = moveToken
	task.spawn(function()
		startFlee(t)
		spawnActive = false
	end)
end

RS.Heartbeat:Connect(function(dt)
	if state == STATE.DEAD or state == STATE.SURRENDER
		or state == STATE.ARRESTED or state == STATE.STUNNED
		or isBusy then return end

	-- ── PATROL ───────────────────────────────────────────────────────────────
	if state == STATE.PATROL then
		enableRotation(false)
		local v = nearestVisiblePlayer()
		if v then
			if tick() < detectionCooldown and lastDetectedPlayer == v then return end
			local cfg = getCharConfig()
			if cfg.NEVER_IGNORE_PLAYER or math.random() < cfg.ALERT_TO_COMBAT then
				setTarget(v)
				cancelMove()
				patrolToken += 1
				local tr   = v:FindFirstChild("HumanoidRootPart")
				local dist = tr and (tr.Position - HRP.Position).Magnitude or math.huge
				stateDecision.willFlee       = cfg.FLEE_DISTANCE > 0 and dist < cfg.FLEE_DISTANCE
				stateDecision.willFight      = not stateDecision.willFlee and math.random() < cfg.ALERT_TO_COMBAT
				-- Rushers nunca sacan el arma: corren al jugador desarmados
				stateDecision.willDrawWeapon = (myBehaviorRole ~= "Rusher") and (math.random() < cfg.WEAPON_DRAW_CHANCE)
				alertEvalTimer     = 0
				alertEvalStarted   = false
				detectionCooldown  = 0
				lastDetectedPlayer = nil
				enableRotation(true)
				AudioManager:Play("Alert")
				state = STATE.ALERT
			else
				lastDetectedPlayer = v
				detectionCooldown  = tick() + 3
			end
			return
		end

		if spawnActive then return end

		if tick() - lastPatrolArrival < CFG.PATROL_WAIT then
			AnimManager:PlayMovement("Idle")
			return
		end

		if tick() - lastIdleLook > CFG.IDLE_LOOK_INTERVAL then
			lastIdleLook    = tick()
			patrolWaitTimer = 0
			local myPatrolToken = patrolToken
			task.spawn(function()
				local randomAngle = math.random() * math.pi * 2
				local lookTarget  = HRP.Position + Vector3.new(math.cos(randomAngle), 0, math.sin(randomAngle)) * 5
				local t           = 0
				local startCF     = HRP.CFrame
				local endCF       = CFrame.new(HRP.Position, lookTarget)
				while t < 1 and state == STATE.PATROL and not spawnActive and myPatrolToken == patrolToken do
					t += RS.Heartbeat:Wait() * 1.5
					HRP.CFrame = startCF:Lerp(endCF, math.min(t, 1))
				end
			end)
			return
		end

		if patrolWaitTimer < CFG.PATROL_WAIT then
			patrolWaitTimer += dt
			AnimManager:PlayMovement("Idle")
			return
		end

		local pt = getNextPatrolPoint()
		if pt then
			spawnMove(pt, false, false)
		else
			AnimManager:PlayMovement("Idle")
		end

		-- ── ALERT ────────────────────────────────────────────────────────────────
	elseif state == STATE.ALERT then
		local v = nearestVisiblePlayer()
		if not v then
			alertEvalStarted = false
			alertEvalTimer   = 0
			setTarget(nil)
			enableRotation(false)
			holsterWeapon()
			state = STATE.PATROL
			AnimManager:PlayMovement("Idle")
			return
		end
		setTarget(v)
		local tr = v:FindFirstChild("HumanoidRootPart")

		if not spawnActive then
			AnimManager:PlayMovement("Idle")
		end
		if tr then setRotationTarget(tr.Position) end

		if not alertEvalStarted then
			alertEvalStarted = true
			alertEvalTimer   = 0
			return
		end

		alertEvalTimer += dt
		if alertEvalTimer >= CFG.ALERT_EVAL_TIME then
			alertEvalStarted = false
			alertEvalTimer   = 0
			if stateDecision.willFlee then
				fleeCycleCount = 0
				enableRotation(false)
				holsterWeapon()
				enterState(STATE.FLEE)
			elseif stateDecision.willFight then
				enterState(STATE.COMBAT)
				AudioManager:Play("Aggro")
				outOfRangeTimer = 0
				loseSightTimer  = 0
				lastSeenPos     = tr and tr.Position or nil
			else
				enableRotation(false)
				holsterWeapon()
				enterState(STATE.PATROL)
			end
		end

		-- ── FLEE ─────────────────────────────────────────────────────────────────
	elseif state == STATE.FLEE then
		if not target or not target:FindFirstChild("HumanoidRootPart") then
			fleeTargetDist = 0
			holsterWeapon()
			fleeCycleCount = 0
			enterState(STATE.PATROL)
			return
		end
		local distFlee = (target.HumanoidRootPart.Position - HRP.Position).Magnitude
		if fleeCycleCount >= getCharConfig().FLEE_MAX_CYCLES then
			doSurrender()
			return
		end
		if fleeTargetDist > 0 then
			if distFlee > fleeTargetDist * 1.2 then
				fleeTargetDist = 0
				fleeCooldown   = tick() + 2
			end
			return
		end
		if tick() >= fleeCooldown then
			if math.random() < getSurrenderChance() then
				doSurrender()
			else
				fleeCycleCount += 1
				spawnFlee()
			end
		end

		-- ── COMBAT ───────────────────────────────────────────────────────────────
	elseif state == STATE.COMBAT then
		if not target then
			enableRotation(false)
			holsterWeapon()
			enterState(STATE.PATROL)
			return
		end

		if not isTargetValid(target) then
			setTarget(nil)
			enableRotation(false)
			holsterWeapon()
			enterState(STATE.PATROL)
			return
		end

		local th = target:FindFirstChildOfClass("Humanoid")
		local tr = target:FindFirstChild("HumanoidRootPart")
		if not th or th.Health <= 0 or not tr then
			setTarget(nil)
			enableRotation(false)
			holsterWeapon()
			enterState(STATE.PATROL)
			return
		end
		local dist = (tr.Position - HRP.Position).Magnitude

		if canSee(target) then
			loseSightTimer  = 0
			outOfRangeTimer = 0
			lastSeenPos     = tr.Position
		else
			loseSightTimer += dt

			-- ── PRE-FIRE ─────────────────────────────────────────────────────────
			-- Mientras perdemos LOS pero todavía sabemos dónde estaba el jugador,
			-- disparamos hacia esa posición con ruido. Solo si el arma está drawn
			-- y la característica lo permite. Rushers no disparan nunca.
			if lastSeenPos and weaponDrawn and myBehaviorRole ~= "Rusher" then
				local prefireChance = getCharConfig().PREFIRE_CHANCE or 0
				if prefireChance > 0 and math.random() < prefireChance then
					local noise = Vector3.new(
						(math.random() * 2 - 1) * CFG.PREFIRE_NOISE,
						(math.random() * 2 - 1) * CFG.PREFIRE_NOISE * 0.5,
						(math.random() * 2 - 1) * CFG.PREFIRE_NOISE
					)
					shoot(nil, lastSeenPos + noise)
				end
			end

			if loseSightTimer >= CFG.LOSE_SIGHT_BUFFER then
				loseSightTimer  = 0
				stopCombatChase()

				-- ── TRANSICIÓN A SEARCH ───────────────────────────────────────────
				-- En vez de ir directo a ALERT, el NPC busca activamente al jugador.
				-- Si no tiene lastSeenPos (nunca lo vio bien) salta a ALERT directo.
				if lastSeenPos then
					-- Generar puntos de búsqueda: lastSeenPos + satélites alrededor
					searchPoints      = { lastSeenPos }
					searchIndex       = 1
					searchTimer       = 0
					searchPointActive = false
					searchArrivalTime = 0
					for _ = 1, CFG.SEARCH_POINTS do
						local angle = math.random() * math.pi * 2
						local r     = math.random() * CFG.SEARCH_RADIUS
						table.insert(searchPoints, lastSeenPos + Vector3.new(
							math.cos(angle) * r, 0, math.sin(angle) * r
							))
					end
					enableRotation(true)
					enterState(STATE.SEARCH)
				else
					alertEvalStarted = false
					alertEvalTimer   = 0
					stateDecision.willFlee  = shouldFleeFromCombat(dist)
					stateDecision.willFight = not stateDecision.willFlee and math.random() < getCharConfig().ALERT_TO_COMBAT
					enableRotation(false)
					holsterWeapon()
					enterState(STATE.ALERT)
				end
				return
			end
			if lastSeenPos and not chaseActive then
				stopCombatChase()
				spawnMove(lastSeenPos, true, false)
			end
			return
		end

		if shouldFleeFromCombat(dist) then
			fleeCycleCount = 0
			enableRotation(false)
			stopCombatChase()
			holsterWeapon()
			enterState(STATE.FLEE)
			return
		end

		local extendedRange = CFG.SIGHT_RANGE * 1.5
		if dist > extendedRange then
			outOfRangeTimer += dt
			if outOfRangeTimer >= CFG.OUT_OF_RANGE_BUFFER then
				outOfRangeTimer = 0
				setTarget(nil)
				enableRotation(false)
				holsterWeapon()
				stopCombatChase()
				enterState(STATE.PATROL)
				return
			end
		else
			outOfRangeTimer = 0
		end

		combatDecisionTimer += 1
		if combatDecisionTimer >= 180 then
			combatDecisionTimer = 0
			local hpPct = Humanoid.Health / Humanoid.MaxHealth
			if hpPct < 0.4 and math.random() < getSurrenderChance() * 0.5 then
				doSurrender(); return
			end
		end

		enableRotation(true)
		setRotationTarget(tr.Position)

		-- ── RUSHER ───────────────────────────────────────────────────────────────
		-- El Rusher ignora todo el sistema de disparo. Solo persigue al jugador
		-- a máxima velocidad. Si la característica es Fear y está muy cerca,
		-- puede surrenderear a mitad del rush por los nervios.
		if myBehaviorRole == "Rusher" then
			local surrenderDist = getCharConfig().RUSHER_SURRENDER_DIST or 0
			if surrenderDist > 0 and dist < surrenderDist then
				if math.random() < getSurrenderChance() then
					doSurrender(); return
				end
			end

			if dist <= CFG.ATTACK_RANGE then
				stopCombatChase()
				enterState(STATE.MELEE)
			else
				Humanoid.WalkSpeed = CFG.RUN_SPEED * 1.3
				AnimManager:PlayMovement("Run")
				startCombatChase(moveToken, false)
			end
			return
		end

		-- ── COMBATE NORMAL (Semi / Auto / Spread) ────────────────────────────────
		if not weaponDrawn and stateDecision.willDrawWeapon then drawWeapon() end

		local actionBlocking = AnimManager:IsPlayingAction()

		if dist <= CFG.ATTACK_RANGE then
			stopCombatChase()
			enterState(STATE.MELEE)

		elseif dist <= CFG.SHOOT_RANGE and weaponDrawn then
			local innerThreshold = CFG.SHOOT_RANGE * 0.75
			local outerThreshold = CFG.SHOOT_RANGE * 0.90

			if dist < innerThreshold then
				if chaseActive then stopCombatChase() end
				if spawnActive then spawnActive = false; cancelMove() end
				if not actionBlocking then
					AnimManager:PlayMovement("GunIdle")
				end
			elseif dist > outerThreshold then
				Humanoid.WalkSpeed = CFG.RUN_SPEED * 0.85
				if not actionBlocking then
					AnimManager:PlayMovement("GunWalk")
				end
				startCombatChase(moveToken, true)
			end
			shoot(target)

		else
			if spawnActive then
				spawnActive = false
				cancelMove()
			end
			Humanoid.WalkSpeed = CFG.RUN_SPEED
			if not actionBlocking then
				AnimManager:PlayMovement(weaponDrawn and "GunWalk" or "Run")
			end
			startCombatChase(moveToken, weaponDrawn and stateDecision.willDrawWeapon)
		end

		-- ── SEARCH ───────────────────────────────────────────────────────────────
	elseif state == STATE.SEARCH then
		if not target then
			enterState(STATE.PATROL)
			return
		end

		-- Si redetecta al jugador en cualquier momento → vuelve a COMBAT
		if canSee(target) then
			local tr2 = target:FindFirstChild("HumanoidRootPart")
			lastSeenPos = tr2 and tr2.Position or lastSeenPos
			loseSightTimer  = 0
			outOfRangeTimer = 0
			stopCombatChase()
			enterState(STATE.COMBAT)
			AudioManager:Play("Aggro")
			return
		end

		searchTimer += dt

		-- Timeout de búsqueda → ALERT con willFight reducido
		if searchTimer >= CFG.SEARCH_TIMEOUT then
			searchTimer   = 0
			searchPoints  = {}
			alertEvalStarted = false
			alertEvalTimer   = 0
			stateDecision.willFlee  = false
			stateDecision.willFight = math.random() < getCharConfig().ALERT_TO_COMBAT * 0.5
			enableRotation(false)
			holsterWeapon()
			stopCombatChase()
			enterState(STATE.ALERT)
			return
		end

		-- Sin puntos que recorrer → pasar a ALERT
		if #searchPoints == 0 then
			enableRotation(false)
			holsterWeapon()
			stopCombatChase()
			alertEvalStarted = false
			alertEvalTimer   = 0
			enterState(STATE.ALERT)
			return
		end

		-- Avanzar al siguiente punto si terminamos de esperar en el actual
		if not searchPointActive then
			if tick() - searchArrivalTime >= CFG.SEARCH_POINT_WAIT then
				if searchIndex > #searchPoints then
					-- Agotamos todos los puntos → ALERT
					searchPoints  = {}
					enableRotation(false)
					holsterWeapon()
					stopCombatChase()
					alertEvalStarted = false
					alertEvalTimer   = 0
					enterState(STATE.ALERT)
					return
				end

				local dest = searchPoints[searchIndex]
				searchIndex       += 1
				searchPointActive  = true

				-- Mirar hacia el punto mientras nos movemos
				enableRotation(true)
				setRotationTarget(dest)
				AnimManager:PlayMovement(weaponDrawn and "GunWalk" or "Walk")
				Humanoid.WalkSpeed = CFG.WALK_SPEED

				local myMoveToken = moveToken
				task.spawn(function()
					local path = PathService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
					local ok   = pcall(function() path:ComputeAsync(HRP.Position, dest) end)
					if not ok or path.Status ~= Enum.PathStatus.Success then
						Humanoid:MoveTo(dest)
					else
						for _, wp in ipairs(path:GetWaypoints()) do
							if state ~= STATE.SEARCH or moveToken ~= myMoveToken then return end
							if wp.Action == Enum.PathWaypointAction.Jump then Humanoid.Jump = true end
							Humanoid:MoveTo(wp.Position)
							local reached, elapsed = false, 0
							local conn
							conn = Humanoid.MoveToFinished:Connect(function(r)
								reached = r; conn:Disconnect()
							end)
							while not reached and elapsed < CFG.WAYPOINT_TIMEOUT do
								elapsed += RS.Heartbeat:Wait()
								if state ~= STATE.SEARCH or moveToken ~= myMoveToken then
									conn:Disconnect(); return
								end
							end
							if not reached then conn:Disconnect() end
						end
					end
					if state == STATE.SEARCH and moveToken == myMoveToken then
						searchPointActive = false
						searchArrivalTime = tick()
						AnimManager:PlayMovement("Idle")
					end
				end)
			end
		end

		-- ── MELEE ─────────────────────────────────────────────────────────────────
	elseif state == STATE.MELEE then
		if not target then
			enableRotation(false)
			meleeChasing = false
			holsterWeapon()
			enterState(STATE.PATROL)
			return
		end

		local tr = target:FindFirstChild("HumanoidRootPart")

		if not tr or not isTargetValid(target) then
			enableRotation(false)
			meleeChasing = false
			setTarget(nil)
			holsterWeapon()
			enterState(STATE.PATROL)
			return
		end

		local dist = (tr.Position - HRP.Position).Magnitude
		enableRotation(true)
		setRotationTarget(tr.Position)

		if dist > CFG.MELEE_CHASE_DIST then
			meleeChasing = false
			enterState(STATE.COMBAT)
			return
		end

		local innerThreshold = CFG.ATTACK_RANGE
		local outerThreshold = CFG.ATTACK_RANGE + 2

		if dist <= innerThreshold then
			meleeChasing = false
			Humanoid:MoveTo(HRP.Position)
			AnimManager:PlayMovement("Idle")
		elseif dist > outerThreshold then
			meleeChasing = true
			Humanoid.WalkSpeed = CFG.RUN_SPEED
			Humanoid:MoveTo(tr.Position)
			AnimManager:PlayMovement("Run")
		end

		melee(target)
	end
end)