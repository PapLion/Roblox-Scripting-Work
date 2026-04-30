--[[
================================================================================
  AnimationManager.lua  —  NPC Animation Module
================================================================================

  OVERVIEW
  --------
  Centralized module that loads, prioritizes, and plays all NPC animations.
  Manages two independent layers so locomotion and action animations can
  coexist cleanly without one accidentally canceling the other.

    MOVEMENT layer  Locomotion: Idle, Walk, Run, GunWalk, GunIdle.
                    Only one movement animation plays at a time.

    ACTION layer    One-shot or looping combat/interaction animations:
                    Shoot, Reload, Melee, Ziptie, Death, Surrender, etc.
                    Only one action animation plays at a time.

  When a non-looping action finishes, the module automatically resumes the
  last active movement animation, so the NPC never gets stuck in an idle
  T-pose after shooting or reloading.

  Some actions are flagged as "blocking movement" (Draw, Reload, FlashbangReaction).
  While these are active, IsPlayingAction() returns true so the NPC script
  knows not to override the animation with a locomotion change.

  DEPENDENCIES
  ------------
  This module must be a direct child of the NPC model (script.Parent = NPC).
  The NPC must have a Humanoid with an Animator child.

  BASIC USAGE
  -----------
  local AnimManager = require(NPC:WaitForChild("AnimationManager"))

  AnimManager:Play("Walk")            -- auto-routes to the correct layer
  AnimManager:PlayMovement("Run")     -- explicit MOVEMENT layer call
  AnimManager:PlayAction("Shoot")     -- explicit ACTION layer call
  AnimManager:Stop("Reload")          -- stops one specific animation
  AnimManager:StopAll()               -- stops everything and resets state
  AnimManager:IsReloading()           -- true while a reload is active
  AnimManager:IsPlayingAction()       -- true while a blocking action is active

  QUICK CUSTOMIZATION GUIDE
  -------------------------
  Change an animation ID       → ANIMATION_IDS table below
  Change animation priorities  → PRIORITY table
  Toggle looping behavior      → LOOPING table
  Change action duration        → ACTION_DURATION table (fallback timer)
  Mark an action as blocking   → BLOCKS_MOVEMENT table

================================================================================
]]

local AnimationManager = {}

local NPC      = script.Parent
local Humanoid = NPC:WaitForChild("Humanoid")
local Animator = Humanoid:WaitForChild("Animator")

-- ── ANIMATION IDs ────────────────────────────────────────────────────────────
--[[
  Replace any rbxassetid value to swap out an animation.
  Setting an ID to "" or "rbxassetid://0" will silently skip loading that track.
  Run and Walk share the same ID here — replace Run's ID if they differ.
]]
local ANIMATION_IDS = {
	Idle              = "rbxassetid://81158304881872",
	Walk              = "rbxassetid://75776647586406",
	Run               = "rbxassetid://75776647586406",   -- same as Walk; replace if you have a separate run anim
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

-- ── ANIMATION PRIORITIES ─────────────────────────────────────────────────────
--[[
  Priorities determine which animation "wins" when multiple tracks are playing.
  Roblox blends in ascending order: Idle < Movement < Action < Action2 < Action3 < Action4.
  Only change these if you need to alter how animations blend against each other.
]]
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

-- ── LOOPING FLAGS ────────────────────────────────────────────────────────────
--[[
  true  = animation repeats indefinitely until explicitly stopped.
  false = animation plays once; the module automatically cleans up state when done.
]]
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

-- ── ACTION DURATIONS  (fallback timers) ──────────────────────────────────────
--[[
  When an action ends, the module normally relies on the AnimationTrack.Stopped
  event to clean up state. These durations are a safety fallback: if Stopped
  never fires (edge case), the state is cleared after this many seconds.

  Keep these values slightly longer than the actual animation duration.
  Death, FlashbangReaction, and Surrender use 999 because they are meant to
  persist until explicitly stopped via :Stop() or :StopAll().

  If you change an animation to a longer/shorter clip, update the matching value here.
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

-- ── MOVEMENT-BLOCKING ACTIONS ────────────────────────────────────────────────
--[[
  Actions listed here set isActionBlocking = true for their duration.
  The NPC script calls IsPlayingAction() to avoid changing the locomotion
  animation mid-way through these (e.g. don't start running during a reload).
  Add any new action here if it should suppress locomotion animation changes.
]]
local BLOCKS_MOVEMENT = {
	Draw              = true,
	Reload            = true,
	FlashbangReaction = true,
}

-- ── LAYER ASSIGNMENTS ────────────────────────────────────────────────────────
--[[
  Maps each animation name to its layer. Used by :Play() to route automatically
  to either PlayMovement() or PlayAction().
  Update this if you add a new animation.
]]
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

-- ── LOAD ALL TRACKS ──────────────────────────────────────────────────────────
-- All animation tracks are loaded once at module init time.
-- Skips any IDs that are empty or set to zero.
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

-- ── INTERNAL STATE ───────────────────────────────────────────────────────────
local currentMovement   = ""     -- name of the currently active MOVEMENT animation
local currentAction     = ""     -- name of the currently active ACTION animation
local isReloading       = false  -- true while a reload action is in progress
local isActionBlocking  = false  -- true while a movement-blocking action is active

-- ── PRIVATE HELPERS ──────────────────────────────────────────────────────────

local function stopTrack(name, fadeTime)
	if tracks[name] and tracks[name].IsPlaying then
		tracks[name]:Stop(fadeTime or 0.15)
	end
end

local function playTrack(name, fadeTime)
	local t = tracks[name]
	if not t then
		warn("AnimationManager: no track loaded for '" .. name .. "'")
		return
	end
	if t.IsPlaying then return end
	t:Play(fadeTime or 0.15)
end

-- ── PUBLIC API ────────────────────────────────────────────────────────────────

--[[
  PlayMovement(name, fadeTime, forceRestart)
  ------------------------------------------
  Plays an animation on the MOVEMENT layer.

  If the same animation is already playing and forceRestart is not true,
  this is a no-op (prevents redundant interruptions during the AI loop).
  If a different movement animation was playing, it is crossfaded out first.

  Parameters:
    name         string   Animation name. Must be in LAYER with value "MOVEMENT".
    fadeTime     number   Crossfade duration in seconds. Default: 0.15.
    forceRestart bool     If true, restarts the track even if already playing.
                          Used after action animations end to snap back cleanly.
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
  Plays an animation on the ACTION layer.

  If a different action is already active, it is faded out first.
  After a non-looping action ends (via Stopped event or fallback timer),
  the module automatically resumes the last active movement animation.

  Special behaviors:
    Reload     — ignored if a reload is already in progress.
    Ziptie     — automatically chains into ZipTieIdle when it finishes.
    Other non-looping actions — cleaned up via Stopped event, with a timer
                                fallback in case Stopped never fires.

  Parameters:
    name      string   Animation name. Must be in LAYER with value "ACTION".
    fadeTime  number   Crossfade duration in seconds. Default: 0.10.
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

		-- Special case: Ziptie chains into ZipTieIdle on completion.
		if playedName == "Ziptie" then
			tracks["Ziptie"].Stopped:Once(function()
				if currentAction == "Ziptie" then
					currentAction = ""
				end
				playTrack("ZipTieIdle", 0.15)
				currentAction = "ZipTieIdle"
			end)
			return
		end

		-- Safety fallback: if Stopped never fires, clean up state after duration + buffer.
		local fallbackToken  = {}
		local activeFallback = fallbackToken
		task.delay(duration + 0.2, function()
			if activeFallback ~= fallbackToken then return end
			if currentAction == playedName then
				currentAction = ""
				if playedName == "Reload" then isReloading = false end
				if BLOCKS_MOVEMENT[playedName] then isActionBlocking = false end
				if currentMovement ~= "" then
					self:PlayMovement(currentMovement, 0.15, true)
				end
			end
		end)

		-- Primary cleanup path: triggered when the track stops naturally.
		tracks[name].Stopped:Once(function()
			activeFallback = nil  -- cancel the safety fallback
			if playedName == "Reload" then isReloading = false end
			if BLOCKS_MOVEMENT[playedName] then isActionBlocking = false end
			if currentAction == playedName then
				currentAction = ""
				-- Resume whatever movement animation was active before the action.
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
  Convenience method. Automatically routes to PlayMovement or PlayAction
  based on the animation's entry in the LAYER table.
  Prefer this for generic calls where you don't need to specify the layer.
]]
function AnimationManager:Play(name, fadeTime)
	local layer = LAYER[name]
	if layer == "MOVEMENT" then
		self:PlayMovement(name, fadeTime)
	elseif layer == "ACTION" then
		self:PlayAction(name, fadeTime)
	else
		warn("AnimationManager: unknown layer for animation '" .. name .. "'")
	end
end

--[[
  Stop(name, fadeTime)
  --------------------
  Stops a specific animation and clears its associated internal state.

  Parameters:
    name      string   Animation name to stop.
    fadeTime  number   Fade-out duration. Default: 0.15.
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
  StopAll(fadeTime)
  -----------------
  Stops every currently playing animation and resets all internal state.
  Call this before major state transitions (death, stun, arrest) to ensure
  no animation is left playing from a previous state.

  Parameters:
    fadeTime  number   Fade-out applied to all tracks. Default: 0.15.
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
end

--[[
  IsReloading() → bool
  --------------------
  Returns true while a reload action is in progress.
  Used by the shooting logic in NpcScript to avoid triggering a second reload
  before the first one completes.
]]
function AnimationManager:IsReloading()
	return isReloading
end

--[[
  IsPlayingAction() → bool
  ------------------------
  Returns true while one of the movement-blocking actions is active
  (Draw, Reload, or FlashbangReaction).

  The NPC script checks this before changing the locomotion animation, so
  it won't switch from "reloading" to "running" mid-reload.
]]
function AnimationManager:IsPlayingAction()
	return isActionBlocking
end

return AnimationManager