--[[
================================================================================
  AudioManager.lua  —  NPC Audio Module (v2 - Con Subtítulos)
================================================================================

  CAMBIOS vs v1
  -------------
  • NUEVO: playOnHead ahora dispara el RemoteEvent "NPCSubtitle" a todos los
    clientes cuando reproduce un sonido en el Head.
    El SubtitleClient (LocalScript en StarterPlayerScripts) recibe
    (npcModel, characteristic, category) y muestra el texto en pantalla.

  Todo lo demás permanece idéntico al original.

  NUEVO REMOTE EVENT en ReplicatedStorage (auto-creado)
  -------------------------------------------------------
  • NPCSubtitle   Server → AllClients
    Args: npcModel (Model), characteristic (string), category (string)
    SubtitleClient filtra por proximidad al NPC del lado del cliente,
    así que disparar a todos es seguro y simple.

================================================================================
]]

local AudioManager = {}

local NPC    = script.Parent
local Head   = NPC:WaitForChild("Head")
local Debris = game:GetService("Debris")

local CHAR = NPC:GetAttribute("Characteristic") or "Bravery"

-- ── SOUND BANKS BY CHARACTERISTIC ────────────────────────────────────────────
local SOUNDS_BY_CHAR = {
	Bravery = {
		Alert       = {"rbxassetid://0"},
		Aggro       = {"rbxassetid://0"},
		Surrender   = {"rbxassetid://84143932528095"},
		Shot        = {"rbxassetid://140045834988316"},
		Flashbanged = {"rbxassetid://137401766352518"},
		Melee       = {"rbxassetid://135847631817120"},
		Ziptie      = {"rbxassetid://9113259709"},
		Shoot       = {"rbxassetid://131845096216428"},
		Reload      = {"rbxassetid://140341132746608"},
		Draw        = {"rbxassetid://136872990277782"},
		Intimidate  = {"rbxassetid://84143932528095"},
		Arrest      = {"rbxassetid://9113259709"},
		Flashbang   = {"rbxassetid://82954122669886"},
	},
	Fear = {
		Alert       = {"rbxassetid://0"},
		Aggro       = {"rbxassetid://0"},
		Surrender   = {"rbxassetid://84143932528095"},
		Shot        = {"rbxassetid://140045834988316"},
		Flashbanged = {"rbxassetid://137401766352518"},
		Melee       = {"rbxassetid://135847631817120"},
		Ziptie      = {"rbxassetid://9113259709"},
		Shoot       = {"rbxassetid://131845096216428"},
		Reload      = {"rbxassetid://140341132746608"},
		Draw        = {"rbxassetid://136872990277782"},
		Intimidate  = {"rbxassetid://84143932528095"},
		Arrest      = {"rbxassetid://9113259709"},
		Flashbang   = {"rbxassetid://82954122669886"},
	},
	Obedient = {
		Alert       = {"rbxassetid://0"},
		Aggro       = {"rbxassetid://0"},
		Surrender   = {"rbxassetid://124812826088685"},
		Shot        = {"rbxassetid://140045834988316"},
		Flashbanged = {"rbxassetid://137401766352518"},
		Melee       = {"rbxassetid://135847631817120"},
		Ziptie      = {"rbxassetid://9113259709"},
		Shoot       = {"rbxassetid://131845096216428"},
		Reload      = {"rbxassetid://140341132746608"},
		Draw        = {"rbxassetid://136872990277782"},
		Intimidate  = {"rbxassetid://84143932528095"},
		Arrest      = {"rbxassetid://9113259709"},
		Flashbang   = {"rbxassetid://82954122669886"},
	},
}

local SOUNDS = SOUNDS_BY_CHAR[CHAR] or SOUNDS_BY_CHAR.Bravery

-- ── COOLDOWNS ────────────────────────────────────────────────────────────────
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

local lastPlayed  = {}
local activeSound = {}

-- ── REMOTE EVENTS ─────────────────────────────────────────────────────────────
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

-- El evento de subtítulos se crea aquí junto con los demás.
local subtitleEvent = ensureEvent("NPCSubtitle")

-- ── PRIVATE HELPERS ──────────────────────────────────────────────────────────

local function getSound(category)
	local list = SOUNDS[category]
	if not list or #list == 0 then return nil end
	return list[math.random(1, #list)]
end

local function canPlay(category)
	local cd   = COOLDOWN[category] or 0
	local last = lastPlayed[category] or 0
	return tick() - last >= cd
end

-- ── HEAD SOUND PLAYBACK ──────────────────────────────────────────────────────
--[[
  CAMBIO v2: después de confirmar que el sonido va a reproducirse
  (id existe + cooldown ok), dispara NPCSubtitle a todos los clientes
  ANTES de crear el Sound, para que el subtítulo aparezca en pantalla
  al mismo tiempo que empieza el audio.

  SubtitleClient filtra por proximidad al Head del NPC del lado del
  cliente, así que no hay riesgo de mostrar subtítulos de NPCs lejanos.
]]
local function playOnHead(category)
	local id = getSound(category)
	if not id then
		print("[AudioManager] DEBUG A - ABORTADO: no hay sound id para categoría:", category)
		return
	end
	if not canPlay(category) then
		print("[AudioManager] DEBUG A - ABORTADO: cooldown activo para:", category)
		return
	end

	lastPlayed[category] = tick()

	-- DEBUG A: confirmar que vamos a disparar el evento
	print("[AudioManager] DEBUG A - Disparando NPCSubtitle | NPC:", NPC.Name, "| CHAR:", CHAR, "| category:", category)

	subtitleEvent:FireAllClients(NPC, CHAR, category)

	-- DEBUG B: confirmar que el FireAllClients no crasheó
	print("[AudioManager] DEBUG B - FireAllClients completado")

	local prev = activeSound[category]
	if prev and prev.Parent then
		prev:Stop()
		prev:Destroy()
	end
	activeSound[category] = nil

	local s = Instance.new("Sound")
	s.SoundId            = id
	s.RollOffMaxDistance = 60
	s.RollOffMinDistance = 5
	s.Volume             = 1
	s.Parent             = Head
	s:Play()
	Debris:AddItem(s, 12)

	activeSound[category] = s
	s.Ended:Connect(function()
		if activeSound[category] == s then
			activeSound[category] = nil
		end
	end)
end

-- ── PUBLIC API ────────────────────────────────────────────────────────────────

function AudioManager:Play(category)
	playOnHead(category)
end

-- ── PLAYER-DIRECTED VOICE LINES ──────────────────────────────────────────────
local playerCooldowns   = {}
local playerActiveSound = {}

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

ensureEvent("IntimidateVoice").OnServerEvent:Connect(function(player)
	playForPlayer(player, "Intimidate")
end)

ensureEvent("ArrestVoice").OnServerEvent:Connect(function(player)
	playForPlayer(player, "Arrest")
end)

ensureEvent("FlashbangVoice").OnServerEvent:Connect(function(player)
	playForPlayer(player, "Flashbang")
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	playerCooldowns[player]   = nil
	playerActiveSound[player] = nil
end)

return AudioManager