--[[
================================================================================
  AudioManager.lua  —  NPC Audio Module
================================================================================

  OVERVIEW
  --------
  Centralized module that plays NPC voice lines and sound effects.
  Supports three NPC characteristics (Bravery, Fear, Obedient), each with
  its own sound bank so NPCs sound distinct from one another.

  Two playback contexts are managed:

    playOnHead       3D sound parented to the NPC's Head. Heard by all nearby
                     players with natural distance attenuation.

    playForPlayer    3D sound parented to a specific player's HumanoidRootPart.
                     Used for voice lines directed at a particular player
                     (e.g. intimidation responses, arrest reactions).
                     Triggered via RemoteEvents from the server.

  Anti-overlap system: before spawning a new sound instance for any category,
  the previous instance of that same category is stopped and destroyed first.
  This prevents the same voice line from overlapping itself on rapid calls.

  DEPENDENCIES
  ------------
  This module must be a direct child of the NPC model (script.Parent = NPC).
  The NPC must have its "Characteristic" attribute set before this module
  is required — NpcScript handles that ordering automatically.
  The NPC must have a "Head" part.

  REMOTE EVENTS in ReplicatedStorage  (auto-created if they don't exist)
  -----------------------------------------------------------------------
  • IntimidateVoice   Server → Client   Plays the player's intimidation voice line.
  • ArrestVoice       Server → Client   Plays the player's arrest voice line.
  • FlashbangVoice    Server → Client   Plays the player's flashbang voice line.

  BASIC USAGE
  -----------
  local AudioManager = require(NPC:WaitForChild("AudioManager"))
  AudioManager:Play("Shoot")     -- plays the shoot sound from the NPC's head
  AudioManager:Play("Alert")     -- plays the alert voice line from the NPC's head

  Player-directed voice lines (Intimidate, Arrest, Flashbang) are fired
  automatically through RemoteEvents. You do not need to call them manually.

  QUICK CUSTOMIZATION GUIDE
  -------------------------
  Change a sound for a characteristic  → Replace the rbxassetid in SOUNDS_BY_CHAR.
  Add sound variants (random pick)     → Add more IDs to the array for that category:
                                         Alert = {"rbxassetid://111", "rbxassetid://222"}
  Adjust cooldown between repeats      → Change the value in COOLDOWN.
  Change hearing range                 → Adjust RollOffMaxDistance / RollOffMinDistance
                                         in playOnHead() or playForPlayer() below.

================================================================================
]]

local AudioManager = {}

local NPC    = script.Parent
local Head   = NPC:WaitForChild("Head")
local Debris = game:GetService("Debris")

-- Read the characteristic set by NpcScript before this module was required.
-- Falls back to "Bravery" if the attribute is missing for any reason.
local CHAR = NPC:GetAttribute("Characteristic") or "Bravery"

-- ── SOUND BANKS BY CHARACTERISTIC ────────────────────────────────────────────
--[[
  Each characteristic has its own sound bank so NPCs sound different from
  one another based on personality.

  To add sound variation for a category, add more IDs to its array:
    Alert = {"rbxassetid://ID1", "rbxassetid://ID2", "rbxassetid://ID3"}
  A random one is selected on each playback.

  Sound categories and when they play:
    Alert       When the NPC first spots a player (PATROL → ALERT).
    Aggro       When the NPC decides to fight (ALERT → COMBAT).
    Surrender   When the NPC surrenders.
    Shot        When the NPC takes a hit (pain reaction).
    Flashbanged When the NPC is stunned by a flashbang.
    Melee       When the NPC throws a punch.
    Ziptie      When the NPC is arrested.
    Shoot       When the NPC fires their weapon.
    Reload      When the NPC reloads.
    Draw        When the NPC draws their weapon.
    Intimidate  Voice line played on the player who intimidates the NPC.
    Arrest      Voice line played on the player who arrests the NPC.
    Flashbang   Voice line played on the player who used a flashbang.
]]
local SOUNDS_BY_CHAR = {
	Bravery = {
		Alert       = {"rbxassetid://9119701508"},
		Aggro       = {"rbxassetid://9119701508"},
		Surrender   = {"rbxassetid://9119701508"},
		Shot        = {"rbxassetid://9119701508"},
		Flashbanged = {"rbxassetid://9119701508"},
		Melee       = {"rbxassetid://9119701508"},
		Ziptie      = {"rbxassetid://9119701508"},
		Shoot       = {"rbxassetid://9119701508"},
		Reload      = {"rbxassetid://9119701508"},
		Draw        = {"rbxassetid://9119701508"},
		Intimidate  = {"rbxassetid://9119701508"},
		Arrest      = {"rbxassetid://9119701508"},
		Flashbang   = {"rbxassetid://9119701508"},
	},
	Fear = {
		Alert       = {"rbxassetid://6042053626"},
		Aggro       = {"rbxassetid://6042053626"},
		Surrender   = {"rbxassetid://6042053626"},
		Shot        = {"rbxassetid://6042053626"},
		Flashbanged = {"rbxassetid://6042053626"},
		Melee       = {"rbxassetid://6042053626"},
		Ziptie      = {"rbxassetid://6042053626"},
		Shoot       = {"rbxassetid://6042053626"},
		Reload      = {"rbxassetid://6042053626"},
		Draw        = {"rbxassetid://6042053626"},
		Intimidate  = {"rbxassetid://6042053626"},
		Arrest      = {"rbxassetid://6042053626"},
		Flashbang   = {"rbxassetid://6042053626"},
	},
	Obedient = {
		Alert       = {"rbxassetid://7084812679"},
		Aggro       = {"rbxassetid://7084812679"},
		Surrender   = {"rbxassetid://7084812679"},
		Shot        = {"rbxassetid://7084812679"},
		Flashbanged = {"rbxassetid://7084812679"},
		Melee       = {"rbxassetid://7084812679"},
		Ziptie      = {"rbxassetid://7084812679"},
		Shoot       = {"rbxassetid://7084812679"},
		Reload      = {"rbxassetid://7084812679"},
		Draw        = {"rbxassetid://7084812679"},
		Intimidate  = {"rbxassetid://7084812679"},
		Arrest      = {"rbxassetid://7084812679"},
		Flashbang   = {"rbxassetid://7084812679"},
	},
}

-- Active sound bank for this NPC. Falls back to Bravery if characteristic is unrecognized.
local SOUNDS = SOUNDS_BY_CHAR[CHAR] or SOUNDS_BY_CHAR.Bravery

-- ── COOLDOWNS ────────────────────────────────────────────────────────────────
--[[
  Minimum seconds that must pass before a category can play again.
  0 = no cooldown (plays every time it's triggered).

  Longer cooldowns prevent voice lines from spamming.
  Short or zero cooldowns are appropriate for gameplay-feedback sounds
  like Shoot, Reload, and Ziptie that need to play reliably every time.
]]
local COOLDOWN = {
	Alert       = 6,
	Aggro       = 8,
	Surrender   = 0,
	Shot        = 0.3,
	Flashbanged = 0,
	Melee       = 2.0,
	Ziptie      = 0,
	Shoot       = 0,
	Reload      = 0,
	Draw        = 0,
	Intimidate  = 3,
	Arrest      = 0,
	Flashbang   = 4,
}

local lastPlayed  = {}   -- { [category] = tick() }  tracks when each category last played
local activeSound = {}   -- { [category] = Sound }   current live Sound instance per category on Head

-- ── PRIVATE HELPERS ──────────────────────────────────────────────────────────

-- Returns a random sound ID from the bank for this category, or nil if none exists.
local function getSound(category)
	local list = SOUNDS[category]
	if not list or #list == 0 then return nil end
	return list[math.random(1, #list)]
end

-- Returns true if enough time has passed since this category last played.
local function canPlay(category)
	local cd   = COOLDOWN[category] or 0
	local last = lastPlayed[category] or 0
	return tick() - last >= cd
end

-- ── HEAD SOUND PLAYBACK ──────────────────────────────────────────────────────
--[[
  Creates a new Sound on the NPC's Head, plays it, and schedules cleanup.

  Anti-overlap: if a Sound instance for this category already exists and is
  playing, it is stopped and destroyed before the new one is created.

  Debris:AddItem(s, 12) ensures the instance is cleaned up even if the
  Ended event never fires (e.g. NPC is destroyed mid-playback).

  To adjust 3D hearing range:
    RollOffMaxDistance  — studs at which the sound becomes completely inaudible
    RollOffMinDistance  — studs at which the sound plays at full volume
]]
local function playOnHead(category)
	local id = getSound(category)
	if not id then return end
	if not canPlay(category) then return end

	lastPlayed[category] = tick()

	-- Stop and destroy the previous instance for this category before spawning a new one.
	local prev = activeSound[category]
	if prev and prev.Parent then
		prev:Stop()
		prev:Destroy()
	end
	activeSound[category] = nil

	local s = Instance.new("Sound")
	s.SoundId            = id
	s.RollOffMaxDistance = 60   -- fully inaudible beyond 60 studs
	s.RollOffMinDistance = 5    -- full volume within 5 studs
	s.Volume             = 1
	s.Parent             = Head
	s:Play()
	Debris:AddItem(s, 12)   -- safety cleanup after 12 s

	activeSound[category] = s
	s.Ended:Connect(function()
		if activeSound[category] == s then
			activeSound[category] = nil
		end
	end)
end

-- ── PUBLIC API ────────────────────────────────────────────────────────────────

--[[
  Play(category)
  --------------
  Plays a sound from the given category on the NPC's Head.
  Respects cooldowns and anti-overlap rules.

  Parameters:
    category  string  Must match a key in SOUNDS_BY_CHAR and COOLDOWN.
]]
function AudioManager:Play(category)
	playOnHead(category)
end

-- ── PLAYER-DIRECTED VOICE LINES ──────────────────────────────────────────────
--[[
  These sounds are played on the player's own HumanoidRootPart rather than
  on the NPC's Head. This is used for voice lines that represent the player's
  own character reacting (e.g. yelling "Freeze!" or "Hands up!").

  Placing the sound on the player's character ensures:
    • The player hears it at full volume regardless of NPC distance.
    • Other nearby players also hear it spatially from the player's position.

  Per-player cooldowns: each player has their own timer per category,
  so multiple NPCs being interacted with simultaneously don't stack the
  same voice line on the same player.

  The sounds are triggered by RemoteEvents fired from NpcScript:
    IntimidateVoice → plays "Intimidate" on the firing player
    ArrestVoice     → plays "Arrest" on the firing player
    FlashbangVoice  → plays "Flashbang" on the firing player

  To adjust player sound range:
    RollOffMaxDistance / RollOffMinDistance in playForPlayer() below.
]]
local RS = game:GetService("ReplicatedStorage")

local function ensureEvent(name)
	local e = RS:FindFirstChild(name)
	if not e then
		e        = Instance.new("RemoteEvent")
		e.Name   = name
		e.Parent = RS
	end
	return e
end

local playerCooldowns   = {}   -- { [player] = { [category] = tick() } }
local playerActiveSound = {}   -- { [player] = { [category] = Sound } }

local function canPlayerPlay(player, category)
	playerCooldowns[player] = playerCooldowns[player] or {}
	local cd   = COOLDOWN[category] or 0
	local last = playerCooldowns[player][category] or 0
	return tick() - last >= cd
end

local function playForPlayer(player, category)
	local id = getSound(category)
	if not id then return end
	if not canPlayerPlay(player, category) then return end

	playerCooldowns[player][category] = tick()

	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Stop and destroy any previous instance for this player + category.
	playerActiveSound[player] = playerActiveSound[player] or {}
	local prev = playerActiveSound[player][category]
	if prev and prev.Parent then
		prev:Stop()
		prev:Destroy()
	end
	playerActiveSound[player][category] = nil

	local s = Instance.new("Sound")
	s.SoundId            = id
	s.RollOffMaxDistance = 60
	s.RollOffMinDistance = 2
	s.Volume             = 1
	s.Parent             = hrp
	s:Play()
	Debris:AddItem(s, 10)

	playerActiveSound[player][category] = s
	s.Ended:Connect(function()
		if playerActiveSound[player] and playerActiveSound[player][category] == s then
			playerActiveSound[player][category] = nil
		end
	end)
end

-- Wire up the RemoteEvents that trigger player-directed voice lines.
ensureEvent("IntimidateVoice").OnServerEvent:Connect(function(player)
	playForPlayer(player, "Intimidate")
end)

ensureEvent("ArrestVoice").OnServerEvent:Connect(function(player)
	playForPlayer(player, "Arrest")
end)

ensureEvent("FlashbangVoice").OnServerEvent:Connect(function(player)
	playForPlayer(player, "Flashbang")
end)

-- Clean up per-player data when a player leaves to avoid memory leaks.
game:GetService("Players").PlayerRemoving:Connect(function(player)
	playerCooldowns[player]   = nil
	playerActiveSound[player] = nil
end)

return AudioManager