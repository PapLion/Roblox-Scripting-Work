--[[
================================================================================
  NpcScript.lua  —  NPC AI Controller
================================================================================

  OVERVIEW
  --------
  This script drives the full AI behavior of an enemy NPC. It handles player
  detection, pathfinding navigation, ranged combat (shooting), melee combat,
  surrender, arrest, and flashbang reactions.

  The AI runs on a Heartbeat loop and is structured as a state machine.
  Each state has its own section in the loop (bottom of the file) and its own
  rules for transitioning to other states.

  REQUIRED CHILDREN  (direct children of the NPC model)
  -----------------------------------------------------
  • AnimationManager   ModuleScript  — handles all animations
  • AudioManager       ModuleScript  — handles all sounds and voice lines
  • HumanoidRootPart, Humanoid, Head — standard Roblox character parts

  NPC ATTRIBUTES  (read/written at runtime; visible in the Studio Properties panel)
  ---------------------------------------------------------------------------------
  • "Characteristic"  string   Assigned on spawn: "Bravery", "Fear", or "Obedient".
                               Controls aggression, flee behavior, and surrender chance.
  • "PatrolRadius"    number   Radius in studs for random patrol point generation.
                               Default: 40. Only relevant when no manual points exist.
  • "Flashbanged"     bool     Set to true from any external script to trigger the
                               stun reaction. Automatically resets after 5 seconds.
  • "Surrendered"     bool     Becomes true when the NPC surrenders. Automatically
                               enables the arrest ProximityPrompt.
  • "Arrested"        bool     Becomes true when the NPC is successfully arrested.

  REMOTE EVENTS in ReplicatedStorage  (auto-created if they don't already exist)
  -------------------------------------------------------------------------------
  • IntimidateNPC      Client → Server    Client fires this with the NPC model as
                                          argument to initiate an intimidation attempt.
  • IntimidateVoice    Server → Client    Server fires this back to play the player's
                                          intimidation voice line on their own character.
  • ArrestVoice        Server → Client    Plays the arrest voice line on the arresting player.
  • FlashbangVoice     Server → Client    Plays the flashbang voice line on the player.
  • NPCBulletFX        Server → AllClients  Tells all clients to render a bullet trail FX.
  • NPCArrested        Server → AllClients  Notifies all clients that this NPC was arrested.

  MANUAL PATROL POINTS  (optional workspace setup)
  -------------------------------------------------
  To define a fixed patrol route for a specific NPC:
    1. Create a folder named "PatrolPoints" directly inside workspace.
    2. Inside it, create a sub-folder with the exact same name as the NPC model.
    3. Place BasePart instances inside that sub-folder, named with a trailing
       number (e.g. "Point1", "Point2", "WP3"). They are visited in numeric order.
  If this setup is absent, the NPC generates random destinations within a circle
  of radius "PatrolRadius" studs around its spawn position.

  STATE MACHINE  (full flow)
  --------------------------
  PATROL    Walks between patrol points. Enters ALERT when a player is spotted.
  ALERT     Locks onto the player and waits ALERT_EVAL_TIME seconds to decide:
              → COMBAT  if willFight is true
              → FLEE    if willFlee is true
              → PATROL  if neither (NPC loses interest)
  COMBAT    Chases and shoots the target.
              → MELEE   if target enters ATTACK_RANGE
              → ALERT   if target is lost for LOSE_SIGHT_BUFFER seconds
              → PATROL  if target stays beyond range for OUT_OF_RANGE_BUFFER seconds
  MELEE     Closes in and attacks. Returns to COMBAT if the target escapes.
  FLEE      Runs away. After FLEE_MAX_CYCLES attempts, enters SURRENDER.
  SURRENDER NPC stops, raises hands, waits to be arrested.
  ARRESTED  NPC is restrained. Stays still indefinitely.
  STUNNED   Paralyzed for 5 seconds after a flashbang. Then re-evaluates.
  DEAD      Terminal state. Nothing runs after this.

  QUICK CUSTOMIZATION GUIDE
  -------------------------
  All values you'd commonly want to tweak live in two tables near the top:

    CFG       Core gameplay numbers: ranges, speeds, damage values, timers.
              Every field is documented inline below.

    CHAR_CFG  Per-characteristic behavior: aggression, flee distance,
              weapon draw chance, surrender probability, etc.
              Also documented inline.

  For audio IDs and cooldowns → AudioManager module.
  For animation IDs            → AnimationManager module.

================================================================================
]]

local NPC           = script.Parent
local Humanoid      = NPC:WaitForChild("Humanoid")
local HRP           = NPC:WaitForChild("HumanoidRootPart")
local Head          = NPC:WaitForChild("Head")
local PathService   = game:GetService("PathfindingService")
local Players       = game:GetService("Players")
local RS            = game:GetService("RunService")

-- Reset the flashbang attribute at spawn so it always starts in a clean state.
NPC:SetAttribute("Flashbanged", false)

-- Ensure all required RemoteEvents exist in ReplicatedStorage before anything fires.
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

-- ── CONFIGURATION ────────────────────────────────────────────────────────────
--[[
  CFG — Central table for all tunable gameplay values.
  Modify these to change NPC behavior without touching any logic code.

  ── DETECTION ──
  SIGHT_RANGE          Base vision radius in studs. Each characteristic can
                       add or subtract via SIGHT_BONUS in CHAR_CFG.
  SIGHT_FOV            Total field-of-view cone angle in degrees.
                       110 = 55 degrees on each side of the NPC's facing direction.

  ── COMBAT ──
  ATTACK_RANGE         Distance in studs at which the NPC switches into melee state.
  SHOOT_RANGE          Maximum distance at which the NPC will attempt to fire.
  SHOOT_COOLDOWN       Minimum seconds between individual shots.
  MELEE_COOLDOWN       Minimum seconds between melee hits.
  MELEE_DAMAGE         Damage dealt per melee hit.
  BULLET_DAMAGE        Damage dealt per bullet that connects.

  ── MOVEMENT ──
  WALK_SPEED           Speed used during patrol and alert states.
  RUN_SPEED            Speed used during combat and flee states.
  ROTATION_SPEED_DEG   Reference value for the BodyGyro smooth rotation setup.

  ── INTERACTION ──
  INTIMIDATE_RANGE     Maximum distance at which a player can intimidate this NPC.
  SURRENDER_HP_PCT     HP fraction (0 to 1) below which the NPC may randomly
                       surrender when damaged. E.g. 0.25 means below 25% HP.

  ── PATROL ──
  PATROL_WAIT          Seconds the NPC idles after arriving at a patrol point.
  PATROL_BLOCKED_MAX   Consecutive pathfinding failures before abandoning a point.

  ── PATHFINDING ──
  PATH_RECALC_INTERVAL Reserved for future use. Interval between path recalculations
                       during chase (currently handled inline per loop tick).
  WAYPOINT_TIMEOUT     Max seconds allowed to reach each individual waypoint
                       before skipping ahead to the next one.

  ── TARGET LOSS ──
  ALERT_EVAL_TIME      Seconds the NPC stares at a detected player before deciding
                       what to do (fight, flee, or ignore).
  IDLE_LOOK_INTERVAL   Seconds between random "curious look" rotations in patrol.
  LOSE_SIGHT_BUFFER    Seconds without line of sight before dropping from COMBAT
                       back to ALERT.
  OUT_OF_RANGE_BUFFER  Seconds the target can remain beyond SIGHT_RANGE * 1.5
                       before the NPC fully disengages and returns to PATROL.
]]
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
	MELEE_CHASE_DIST     = 0,   -- derived below; do not set manually here
}
-- The NPC pursues during MELEE until it is within ATTACK_RANGE + 6 studs.
CFG.MELEE_CHASE_DIST = CFG.ATTACK_RANGE + 6

-- ── STATE DEFINITIONS ────────────────────────────────────────────────────────
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
}

-- ── INTERNAL STATE VARIABLES ─────────────────────────────────────────────────
local state       = STATE.PATROL
local target      = nil       -- Character model of the current target player, or nil
local lastShot    = 0
local lastMelee   = 0
local surrendered = false
local arrested    = false
local weaponDrawn = false
local isBusy      = false     -- when true, skips the entire AI Heartbeat loop

local moveToken   = 0         -- increment to cancel any active movement coroutine
local spawnActive = false     -- true when a patrol/alert moveTo coroutine is running
local patrolToken = 0
local chaseActive = false     -- true when the combat chase loop coroutine is running

local lastPatrolArrival = -math.huge
local patrolWaitTimer   = 0

-- Decision flags set when entering ALERT; resolved when ALERT_EVAL_TIME expires.
local stateDecision = {
	willFight      = false,
	willFlee       = false,
	willDrawWeapon = false,
}

local loseSightTimer      = 0
local lastSeenPos         = nil  -- last known position of the target when sight was lost
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
local nextPath              = nil   -- pre-calculated path for the lookahead system
local nextPathReady         = false
local nextPathTarget        = nil

local meleeChasing = false

-- ── SMOOTH ROTATION ──────────────────────────────────────────────────────────
--[[
  A BodyGyro attached to the HRP rotates the NPC smoothly toward its target.
  Enabled only when the NPC needs to face something (ALERT, COMBAT, MELEE).
  When disabled, MaxTorque is zeroed so it doesn't fight locomotion animation.

  To adjust feel:
    bodyGyro.P  — spring force (higher = snappier turn, can overshoot)
    bodyGyro.D  — damping    (higher = smoother, less bounce)
]]
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

-- Update the BodyGyro CFrame every frame while rotation is active.
RS.Heartbeat:Connect(function()
	if not rotEnabled or not rotTargetPos then return end
	local dir = Vector3.new(rotTargetPos.X, HRP.Position.Y, rotTargetPos.Z) - HRP.Position
	if dir.Magnitude < 0.5 then return end
	bodyGyro.CFrame = CFrame.lookAt(HRP.Position, HRP.Position + dir)
end)

enableRotation(false)

-- ── CHARACTERISTICS ──────────────────────────────────────────────────────────
--[[
  Each NPC is randomly assigned one of three characteristics on spawn.
  This determines how it reacts to danger, whether it fights or runs,
  and how easily it can be intimidated or surrendered.

    Bravery   Aggressive. Hard to intimidate. Almost never surrenders or flees.
              Better long-range vision (+15 studs).
    Fear      Poor long-range vision (-10 studs). Runs easily. Surrenders often.
    Obedient  Balanced across all parameters. Moderate aggression and surrender chance.

  NOTE: The characteristic must be assigned BEFORE requiring AudioManager,
  because AudioManager reads the "Characteristic" attribute during initialization.
]]
local CHARACTERISTICS = { BRAVERY = "Bravery", FEAR = "Fear", OBEDIENT = "Obedient" }

local function assignRandomCharacteristic()
	local chars = { CHARACTERISTICS.BRAVERY, CHARACTERISTICS.FEAR, CHARACTERISTICS.OBEDIENT }
	local selected = chars[math.random(1, #chars)]
	NPC:SetAttribute("Characteristic", selected)
	return selected
end

local myCharacteristic = assignRandomCharacteristic()
print("[NPC] Characteristic:", myCharacteristic)

-- Require both managers only after the characteristic attribute is written.
local AnimManager  = require(NPC:WaitForChild("AnimationManager"))
local AudioManager = require(NPC:WaitForChild("AudioManager"))

-- ── PER-CHARACTERISTIC CONFIGURATION ────────────────────────────────────────
--[[
  CHAR_CFG — Behavioral multipliers per characteristic.
  Tune these to adjust the personality of each NPC type without touching logic.

  SURRENDER_CHANCE     Probability (0–1) of surrendering when taking critical damage
                       or after exhausting all flee attempts. 0 = never surrenders.
  INTIMIDATE_RESIST    Probability (0–1) of resisting an intimidation attempt and
                       turning hostile instead. 1 = always fights back.
  FLEE_DISTANCE        If the target is closer than this value in studs, the NPC
                       will consider fleeing instead of fighting. 0 = never flees.
  SIGHT_BONUS          Added to (or subtracted from) CFG.SIGHT_RANGE.
                       Use a negative value to make the NPC short-sighted.
  ALERT_TO_COMBAT      Probability (0–1) of escalating to COMBAT when a player
                       is spotted. 1.0 = always engages on sight.
  WEAPON_DRAW_CHANCE   Probability of drawing the weapon when entering combat.
                       0 = never draws; 1 = always draws.
  NEVER_IGNORE_PLAYER  If true, this NPC always enters ALERT when it spots a player,
                       bypassing the random ALERT_TO_COMBAT roll on first detection.
  FLEE_MAX_CYCLES      How many times the NPC can run away before giving up
                       and surrendering instead.
]]
local CHAR_CFG = {
	[CHARACTERISTICS.BRAVERY]  = {
		SURRENDER_CHANCE    = 0.10,
		INTIMIDATE_RESIST   = 0.90,
		FLEE_DISTANCE       = 0,
		SIGHT_BONUS         = 15,
		ALERT_TO_COMBAT     = 0.99,
		WEAPON_DRAW_CHANCE  = 1.0,
		NEVER_IGNORE_PLAYER = true,
		FLEE_MAX_CYCLES     = 5,
	},
	[CHARACTERISTICS.FEAR]     = {
		SURRENDER_CHANCE    = 0.50,
		INTIMIDATE_RESIST   = 0.20,
		FLEE_DISTANCE       = 40,
		SIGHT_BONUS         = -10,
		ALERT_TO_COMBAT     = 0.40,
		WEAPON_DRAW_CHANCE  = 0.40,
		NEVER_IGNORE_PLAYER = false,
		FLEE_MAX_CYCLES     = 1,
	},
	[CHARACTERISTICS.OBEDIENT] = {
		SURRENDER_CHANCE    = 0.60,
		INTIMIDATE_RESIST   = 0.40,
		FLEE_DISTANCE       = 0,
		SIGHT_BONUS         = 0,
		ALERT_TO_COMBAT     = 0.70,
		WEAPON_DRAW_CHANCE  = 0.60,
		NEVER_IGNORE_PLAYER = false,
		FLEE_MAX_CYCLES     = 2,
	},
}

local function getCharConfig()          return CHAR_CFG[myCharacteristic] or CHAR_CFG[CHARACTERISTICS.BRAVERY] end
local function getEffectiveSightRange() return CFG.SIGHT_RANGE + getCharConfig().SIGHT_BONUS end
local function getSurrenderChance()     return getCharConfig().SURRENDER_CHANCE end
local function shouldFleeFromCombat(d)
	local c = getCharConfig()
	return c.FLEE_DISTANCE > 0 and d < c.FLEE_DISTANCE
end

-- ── DETECTION HELPERS ────────────────────────────────────────────────────────

-- Returns true if the NPC has unobstructed line of sight to `char`
-- (distance check + FOV cone + raycast obstacle check).
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

-- Returns true if `char` is a living character with a HumanoidRootPart.
-- Uses pcall to handle edge cases where the character model is being destroyed.
local function isTargetValid(char)
	if not char then return false end
	local ok, result = pcall(function()
		local h = char:FindFirstChildOfClass("Humanoid")
		local r = char:FindFirstChild("HumanoidRootPart")
		return h and h.Health > 0 and r ~= nil
	end)
	return ok and result
end

-- Returns the character model of the closest visible player, or nil if none.
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

-- ── MOVEMENT HELPERS ─────────────────────────────────────────────────────────

-- Cancels any active movement by incrementing the token and halting the Humanoid.
-- Any coroutine holding an old token value will exit on its next check.
local function cancelMove()
	moveToken  += 1
	spawnActive = false
	Humanoid:MoveTo(HRP.Position)
end

-- Transitions to a new state, resetting variables tied to the previous state.
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
	state = newState
	cancelMove()
end

-- Stops the combat chase loop by invalidating the active move token.
local function stopCombatChase()
	moveToken   += 1
	chaseActive  = false
end

-- ── PATROL SYSTEM ────────────────────────────────────────────────────────────
--[[
  If workspace.PatrolPoints.<NPC.Name> exists, the NPC cycles through its
  BasePart children in ascending numeric order (loop repeats indefinitely).
  Otherwise, reachable random destinations are generated within patrolRadius.
]]
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

-- Generates a random patrol destination that is accessible via pathfinding.
-- Casts a ray downward to snap the position to the ground. Returns nil if no
-- valid position is found within PATROL_BLOCKED_MAX * 2 attempts.
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

-- Tracks consecutive pathfinding failures. After PATROL_BLOCKED_MAX failures,
-- the current patrol point is abandoned so a new one is selected next cycle.
local function onPathBlocked()
	patrolBlockedAttempts += 1
	if patrolBlockedAttempts >= CFG.PATROL_BLOCKED_MAX then
		currentPatrolPoint    = nil
		patrolBlockedAttempts = 0
	end
end

-- Returns the next patrol destination (manual point or newly generated one).
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
--[[
  Pre-calculates the path to the next destination in a background thread.
  This reduces per-step pathfinding latency during sequential waypoint traversal
  by having the next path ready before the previous leg finishes.
]]
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

-- ── MAIN MOVETO ──────────────────────────────────────────────────────────────
--[[
  Navigates to `pos` using pathfinding, following waypoints one by one.
  Fully cancellable via moveToken — any state change or cancelMove() call
  exits this function cleanly on the next loop iteration check.

  Parameters:
    pos      Vector3  Destination.
    running  bool     true = RUN_SPEED, false = WALK_SPEED.
    gunMode  bool     true = play GunWalk animation when weapon is drawn.
    myToken  number   Must match the current moveToken to keep running.
]]
local function moveTo(pos, running, gunMode, myToken)
	local function stateOk()
		return state == STATE.PATROL or state == STATE.ALERT
			or state == STATE.FLEE   or state == STATE.COMBAT
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

		-- Start pre-calculating the remainder of the route while walking this leg.
		if i < #waypoints then precalcPath(pos) end
	end

	if myToken == moveToken and state == STATE.PATROL then
		currentPatrolPoint  = nil
		lastPatrolArrival   = tick()
		AnimManager:PlayMovement("Idle")
	end
end

-- ── FLEE MOVEMENT ────────────────────────────────────────────────────────────
--[[
  Runs in the opposite direction of the target for a random 30–60 studs.
  Speed is RUN_SPEED * 1.2 so the NPC moves slightly faster while fleeing.
  Exits immediately if the state changes or the move token is invalidated.
]]
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

-- ── WEAPON DRAW ──────────────────────────────────────────────────────────────
-- Draws the weapon once and plays the draw animation + sound.
-- All subsequent calls while weaponDrawn is true are ignored.
local function drawWeapon()
	if weaponDrawn then return end
	weaponDrawn = true
	pcall(function()
		AnimManager:PlayAction("Draw")
		AudioManager:Play("Draw")
	end)
end

-- ── SHOOTING ─────────────────────────────────────────────────────────────────
--[[
  Fires a raycast from the "GunMuzzle" attachment (falls back to Head if absent).
  After SHOTS_PER_RELOAD shots, the NPC is forced to reload.
  During reload, isBusy is set to true for 1.2 seconds to prevent shooting
  while the reload animation plays.

  To adjust:
    Bullet damage       → CFG.BULLET_DAMAGE
    Fire rate           → CFG.SHOOT_COOLDOWN  (seconds between shots)
    Shots before reload → SHOTS_PER_RELOAD range  (random 6–12 per clip)
    Reload lock time    → the task.delay(1.2) value below
    Reload anim length  → ACTION_DURATION["Reload"] in AnimationManager
]]
local RELOAD_COOLDOWN  = 4
local lastReload       = 0
local shotCount        = 0
local SHOTS_PER_RELOAD = math.random(6, 12)

local function shoot(char)
	if tick() - lastShot < CFG.SHOOT_COOLDOWN then return end
	if isBusy then return end
	lastShot = tick()

	shotCount += 1
	if shotCount >= SHOTS_PER_RELOAD and not AnimManager:IsReloading() then
		shotCount           = 0
		SHOTS_PER_RELOAD    = math.random(6, 12)
		lastReload          = tick()
		isBusy              = true
		AnimManager:PlayAction("Reload")
		AudioManager:Play("Reload")
		task.delay(1.2, function()
			isBusy = false
		end)
		return
	end

	AnimManager:PlayAction("Shoot")
	AudioManager:Play("Shoot")

	-- Find GunMuzzle attachment for accurate bullet origin point.
	-- Falls back to Head.Position if the attachment doesn't exist on the model.
	local muzzlePos = Head.Position
	for _, d in ipairs(NPC:GetDescendants()) do
		if d:IsA("Attachment") and d.Name == "GunMuzzle" then
			muzzlePos = d.WorldPosition; break
		end
	end
	local targetRoot = char:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end
	local dir    = (targetRoot.Position - muzzlePos).Unit * CFG.SHOOT_RANGE
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { NPC }
	params.FilterType                 = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(muzzlePos, dir, params)
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model then
			local h = model:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then h:TakeDamage(CFG.BULLET_DAMAGE) end
		end
	end
	-- Notify all clients to render the bullet trail and impact FX.
	local fx = game.ReplicatedStorage:FindFirstChild("NPCBulletFX")
		or (function()
			local r = Instance.new("RemoteEvent")
			r.Name   = "NPCBulletFX"
			r.Parent = game.ReplicatedStorage
			return r
		end)()
	fx:FireAllClients(muzzlePos, hit and hit.Position or (muzzlePos + dir))
end

-- ── MELEE ATTACK ─────────────────────────────────────────────────────────────
--[[
  Plays the melee animation and deals damage after a 0.35 s delay (hit window).
  Damage is only applied if the target is still within ATTACK_RANGE + 2 studs
  at the moment the hit window fires, so targets who move away take no damage.

  To adjust:
    Melee damage  → CFG.MELEE_DAMAGE
    Attack speed  → CFG.MELEE_COOLDOWN  (seconds between swings)
    Hit window    → the task.wait(0.35) below (should match animation timing)
]]
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

-- ── COMBAT CHASE LOOP ────────────────────────────────────────────────────────
--[[
  Runs in a separate task.spawn() coroutine during COMBAT state.
  Updates Humanoid:MoveTo() every 0.1 seconds to continuously track the target.

  Uses full pathfinding when height difference > 3 studs (stairs, ledges, ramps);
  otherwise moves directly to the target for better responsiveness.

  Stops automatically when:
    • The target enters shooting or melee stop distance
    • The state changes or moveToken is incremented (NPC was redirected)
]]
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

-- ── SURRENDER AND ARREST ─────────────────────────────────────────────────────
--[[
  doSurrender()
    Halts all movement, plays the surrender animation and voice, and sets
    "Surrendered" = true — which automatically enables the arrest ProximityPrompt.
    Guards against double-call and ignores if already dead or arrested.

  doArrest()
    Executes when a player activates the ProximityPrompt or calls TryArrest.
    Plays ziptie animation and sound, sets "Arrested" = true, then fires:
      NPCArrested  → all clients (for scoring, UI feedback, etc.)
      ArrestVoice  → the closest player (voice line feedback)
    Returns true on success, false if NPC was not surrendered or already arrested.

  startArrestFollow()
    Currently a no-op placeholder. Implement here if you want the NPC to
    follow the arresting player after being restrained.
]]
local function doSurrender()
	if surrendered or arrested or state == STATE.DEAD then return end
	surrendered = true
	enableRotation(false)
	stopCombatChase()
	cancelMove()
	state  = STATE.SURRENDER
	isBusy = true
	AnimManager:StopAll()
	Humanoid.WalkSpeed = 0
	Humanoid:MoveTo(HRP.Position)
	AnimManager:PlayAction("Surrender")
	AudioManager:Play("Surrender")
	NPC:SetAttribute("Surrendered", true)
end

local function startArrestFollow() end  -- placeholder; implement if follow-on-arrest behavior is needed

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

-- BindableFunction so any external server script can invoke doArrest() directly:
--   NPC:FindFirstChild("TryArrest"):Invoke()
local arrestBind = Instance.new("BindableFunction")
arrestBind.Name, arrestBind.Parent, arrestBind.OnInvoke = "TryArrest", NPC, doArrest

-- ── PROXIMITY PROMPT ─────────────────────────────────────────────────────────
--[[
  Hidden by default. Becomes active automatically when "Surrendered" = true.
  Requires the player to hold for 1.5 s within 4 studs.
  Line of sight is intentionally disabled (RequiresLineOfSight = false) so
  players can arrest while standing close even if geometry is in the way.
]]
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText, prompt.ObjectText, prompt.MaxActivationDistance = "Arrest", NPC.Name, 4
prompt.HoldDuration, prompt.RequiresLineOfSight, prompt.Enabled, prompt.Parent = 1.5, false, false, HRP
NPC:GetAttributeChangedSignal("Surrendered"):Connect(function()
	prompt.Enabled = NPC:GetAttribute("Surrendered") == true and not arrested
end)
prompt.Triggered:Connect(function(_player)
	if surrendered then doArrest(); prompt.Enabled = false end
end)

-- ── INTIMIDATION ─────────────────────────────────────────────────────────────
--[[
  A client fires "IntimidateNPC" with this NPC's model as the argument.
  The server validates that the player is within INTIMIDATE_RANGE, then plays
  the IntimidateVoice line on the player's character.

  Based on INTIMIDATE_RESIST, the NPC either:
    Resists → immediately enters COMBAT targeting that player
    Caves   → calls doSurrender()
]]
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
		target = char; state = STATE.COMBAT
	else
		doSurrender()
	end
end)

-- ── FLASHBANG ────────────────────────────────────────────────────────────────
--[[
  To stun this NPC with a flashbang from any external script:
    npc:SetAttribute("Flashbanged", true)

  The NPC enters STUNNED state for 5 seconds:
    • All movement is halted
    • FlashbangReaction animation plays
    • A voice line plays

  After 5 seconds the NPC re-evaluates: if a player is visible it transitions
  to ALERT; otherwise it returns to PATROL.

  A 1.5 s internal cooldown prevents stacking multiple flashbang triggers.
  The "Flashbanged" attribute is automatically reset to false when the stun ends.
  To change stun duration → the task.delay(5) value below.
]]
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
		local visible      = nearestVisiblePlayer()
		if visible then
			target = visible
			local tr   = visible:FindFirstChild("HumanoidRootPart")
			local dist = tr and (tr.Position - HRP.Position).Magnitude or math.huge
			local cfg  = getCharConfig()
			stateDecision.willFlee       = cfg.FLEE_DISTANCE > 0 and dist < cfg.FLEE_DISTANCE
			stateDecision.willFight      = not stateDecision.willFlee and math.random() < cfg.ALERT_TO_COMBAT
			stateDecision.willDrawWeapon = math.random() < cfg.WEAPON_DRAW_CHANCE
			alertEvalTimer   = 0
			alertEvalStarted = false
			enableRotation(true)
			state = STATE.ALERT
		else
			target = nil
			state  = STATE.PATROL
			AnimManager:PlayMovement("Idle")
		end
	end)
end

NPC:GetAttributeChangedSignal("Flashbanged"):Connect(function()
	if NPC:GetAttribute("Flashbanged") then onFlashbang() end
end)
-- Handle edge case: attribute was already true when the script first loaded.
task.spawn(function()
	task.wait(0.5)
	if NPC:GetAttribute("Flashbanged") then onFlashbang() end
end)

-- ── PLAYER DEATH / DISCONNECT CLEANUP ────────────────────────────────────────
--[[
  If the current target dies, respawns, or disconnects, all combat state is
  cleaned up and the NPC returns to PATROL. This prevents the NPC from
  chasing a character model that no longer exists in the workspace.
]]
local function cleanTargetForPlayer(player)
	if not target then return end
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if targetPlayer ~= player then return end
	target          = nil
	weaponDrawn     = false
	isBusy          = false
	spawnActive     = false
	chaseActive     = false
	meleeChasing    = false
	patrolWaitTimer = CFG.PATROL_WAIT
	stopCombatChase()
	cancelMove()
	if state == STATE.COMBAT or state == STATE.MELEE
		or state == STATE.ALERT or state == STATE.FLEE then
		enableRotation(false)
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

-- ── NPC DEATH ────────────────────────────────────────────────────────────────
Humanoid.Died:Connect(function()
	state = STATE.DEAD
	enableRotation(false)
	stopCombatChase()
	cancelMove()
	prompt.Enabled = false
	AnimManager:StopAll()
	AnimManager:PlayAction("Death")
	bodyGyro.MaxTorque = Vector3.new(0, 0, 0)
end)

-- ── DAMAGE REACTION ──────────────────────────────────────────────────────────
--[[
  When the NPC takes damage:
    1. If HP falls below SURRENDER_HP_PCT while in COMBAT or FLEE, it may surrender.
    2. Plays the "Shot" voice line (pain reaction).
    3. Applies a speed stagger:
         WalkSpeed 0   for 0.2 s  — impact flinch
         WalkSpeed 7   for 0.8 s  — limping recovery
         Restores to previous WalkSpeed

  A 0.3 s cooldown between reactions prevents audio and stagger from stacking
  when the NPC takes rapid consecutive hits.

  To adjust stagger timing → the task.delay values and the WalkSpeed = 7 line below.
]]
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
--  MAIN AI LOOP
-- ═══════════════════════════════════════════════════════════════════════════════
--[[
  spawnMove and spawnFlee wrap their movement functions in task.spawn() so
  navigation runs asynchronously without blocking the Heartbeat loop.
  Both guard against launching duplicate concurrent coroutines.
]]
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
	-- Terminal and locked states skip the loop entirely.
	if state == STATE.DEAD or state == STATE.SURRENDER
		or state == STATE.ARRESTED or state == STATE.STUNNED
		or isBusy then return end

	-- ── PATROL ──────────────────────────────────────────────────────────────
	if state == STATE.PATROL then
		enableRotation(false)
		local v = nearestVisiblePlayer()
		if v then
			-- If we recently chose to ignore this same player, keep ignoring them.
			if tick() < detectionCooldown and lastDetectedPlayer == v then return end
			local cfg = getCharConfig()
			if cfg.NEVER_IGNORE_PLAYER or math.random() < cfg.ALERT_TO_COMBAT then
				target = v
				cancelMove()
				patrolToken += 1
				local tr   = v:FindFirstChild("HumanoidRootPart")
				local dist = tr and (tr.Position - HRP.Position).Magnitude or math.huge
				stateDecision.willFlee       = cfg.FLEE_DISTANCE > 0 and dist < cfg.FLEE_DISTANCE
				stateDecision.willFight      = not stateDecision.willFlee and math.random() < cfg.ALERT_TO_COMBAT
				stateDecision.willDrawWeapon = math.random() < cfg.WEAPON_DRAW_CHANCE
				alertEvalTimer     = 0
				alertEvalStarted   = false
				detectionCooldown  = 0
				lastDetectedPlayer = nil
				enableRotation(true)
				AudioManager:Play("Alert")
				state = STATE.ALERT
			else
				-- NPC noticed the player but decided to ignore them for 3 seconds.
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

		-- Periodic curious-look rotation while idling between patrol points.
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
			-- Lost sight before the eval timer finished. Return to patrol silently.
			alertEvalStarted = false
			alertEvalTimer   = 0
			target           = nil
			enableRotation(false)
			state       = STATE.PATROL
			weaponDrawn = false
			AnimManager:PlayMovement("Idle")
			return
		end
		target = v
		local tr = v:FindFirstChild("HumanoidRootPart")

		if not spawnActive then
			AnimManager:PlayMovement("Idle")
		end
		if tr then setRotationTarget(tr.Position) end

		-- Wait ALERT_EVAL_TIME seconds before committing to fight, flee, or ignore.
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
				enterState(STATE.FLEE)
				weaponDrawn = false
			elseif stateDecision.willFight then
				enterState(STATE.COMBAT)
				AudioManager:Play("Aggro")
				outOfRangeTimer = 0
				loseSightTimer  = 0
				lastSeenPos     = tr and tr.Position or nil
			else
				-- NPC decided not to engage — return to patrolling.
				enableRotation(false)
				enterState(STATE.PATROL)
				weaponDrawn = false
			end
		end

	-- ── FLEE ─────────────────────────────────────────────────────────────────
	elseif state == STATE.FLEE then
		if not target or not target:FindFirstChild("HumanoidRootPart") then
			fleeTargetDist = 0
			weaponDrawn    = false
			fleeCycleCount = 0
			enterState(STATE.PATROL)
			return
		end
		local distFlee = (target.HumanoidRootPart.Position - HRP.Position).Magnitude
		-- All flee cycles used up: give up and surrender.
		if fleeCycleCount >= getCharConfig().FLEE_MAX_CYCLES then
			doSurrender()
			return
		end
		if fleeTargetDist > 0 then
			-- Currently mid-flee run. Wait until we have covered sufficient distance.
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
			weaponDrawn = false
			enterState(STATE.PATROL)
			return
		end

		if not isTargetValid(target) then
			target      = nil
			weaponDrawn = false
			enableRotation(false)
			enterState(STATE.PATROL)
			return
		end

		local th = target:FindFirstChildOfClass("Humanoid")
		local tr = target:FindFirstChild("HumanoidRootPart")
		if not th or th.Health <= 0 or not tr then
			target      = nil
			weaponDrawn = false
			enableRotation(false)
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
			if loseSightTimer >= CFG.LOSE_SIGHT_BUFFER then
				-- Lost sight too long — step back to ALERT to re-evaluate.
				loseSightTimer   = 0
				lastSeenPos      = nil
				weaponDrawn      = false
				alertEvalStarted = false
				alertEvalTimer   = 0
				stateDecision.willFlee  = shouldFleeFromCombat(dist)
				stateDecision.willFight = not stateDecision.willFlee and math.random() < getCharConfig().ALERT_TO_COMBAT
				enableRotation(false)
				stopCombatChase()
				enterState(STATE.ALERT)
				return
			end
			-- Can't see target — move toward its last known position.
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
			enterState(STATE.FLEE)
			return
		end

		-- If the target has been out of the extended range too long, disengage.
		local extendedRange = CFG.SIGHT_RANGE * 1.5
		if dist > extendedRange then
			outOfRangeTimer += dt
			if outOfRangeTimer >= CFG.OUT_OF_RANGE_BUFFER then
				outOfRangeTimer = 0
				target          = nil
				weaponDrawn     = false
				enableRotation(false)
				stopCombatChase()
				enterState(STATE.PATROL)
				return
			end
		else
			outOfRangeTimer = 0
		end

		-- Every ~180 frames (~3 s) there's a small random chance to surrender if HP is low.
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

		if not weaponDrawn and stateDecision.willDrawWeapon then drawWeapon() end

		local actionBlocking = AnimManager:IsPlayingAction()

		if dist <= CFG.ATTACK_RANGE then
			-- Target is close enough to punch — switch to MELEE state.
			stopCombatChase()
			enterState(STATE.MELEE)

		elseif dist <= CFG.SHOOT_RANGE and weaponDrawn then
			-- Inside shooting range.
			-- Inner zone (< 75% of SHOOT_RANGE): stand still and shoot.
			-- Outer zone (> 90% of SHOOT_RANGE): advance slowly while shooting.
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
			-- Out of shooting range — run toward the target.
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

	-- ── MELEE ────────────────────────────────────────────────────────────────
	elseif state == STATE.MELEE then
		if not target then
			enableRotation(false)
			meleeChasing = false
			enterState(STATE.PATROL)
			return
		end

		local tr = target:FindFirstChild("HumanoidRootPart")

		if not tr or not isTargetValid(target) then
			enableRotation(false)
			meleeChasing = false
			target       = nil
			enterState(STATE.PATROL)
			return
		end

		local dist = (tr.Position - HRP.Position).Magnitude
		enableRotation(true)
		setRotationTarget(tr.Position)

		-- Target moved too far away — return to COMBAT to shoot them.
		if dist > CFG.MELEE_CHASE_DIST then
			meleeChasing = false
			enterState(STATE.COMBAT)
			return
		end

		local innerThreshold = CFG.ATTACK_RANGE
		local outerThreshold = CFG.ATTACK_RANGE + 2

		if dist <= innerThreshold then
			-- In striking range: stop and attack.
			meleeChasing = false
			Humanoid:MoveTo(HRP.Position)
			AnimManager:PlayMovement("Idle")
		elseif dist > outerThreshold then
			-- Slightly out of range: close the gap at run speed.
			meleeChasing = true
			Humanoid.WalkSpeed = CFG.RUN_SPEED
			Humanoid:MoveTo(tr.Position)
			AnimManager:PlayMovement("Run")
		end

		melee(target)
	end
end)