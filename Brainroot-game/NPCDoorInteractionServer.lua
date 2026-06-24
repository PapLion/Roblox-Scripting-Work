local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[NPCDoorInteraction] Loaded")

local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = ReplicatedStorage
end

local npcDialogEvent = eventsFolder:FindFirstChild("NPCDialogEvent")
if not npcDialogEvent then
	npcDialogEvent = Instance.new("RemoteEvent")
	npcDialogEvent.Name = "NPCDialogEvent"
	npcDialogEvent.Parent = eventsFolder
end

local COOLDOWN_TIME = 3
local pairsById = {}

local function setNPCVisible(npc, isVisible)
	for _, obj in npc:GetDescendants() do
		if obj:IsA("BasePart") then
			obj.Transparency = isVisible and 0 or 1
			obj.CanCollide = false
		elseif obj:IsA("Decal") then
			obj.Transparency = isVisible and 0 or 1
		end
	end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = isVisible
			and Enum.HumanoidDisplayDistanceType.Viewer
			or Enum.HumanoidDisplayDistanceType.None
	end
end

local function warnMissing(zoneName, doorName, reason)
	warn(("[NPCDoorInteraction] Missing pair: %s %s reason: %s"):format(
		zoneName,
		doorName,
		reason
	))
end

local function findDoorInZone(zone, doorName)
	for _, obj in zone:GetDescendants() do
		if obj:IsA("Model") and obj.Name == doorName then
			return obj
		end
	end

	return nil
end

local function setupPair(zoneName, door, npc, doorName, reparterName)
	local prompt = door:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		warnMissing(zoneName, doorName, "missing ProximityPrompt")
		return
	end

	local pairId = ("%s:%s"):format(zoneName, doorName)

	if pairsById[pairId] then
		warnMissing(zoneName, doorName, "duplicate pair id " .. pairId)
		return
	end

	local pair = {
		id = pairId,
		zoneName = zoneName,
		doorName = doorName,
		reparterName = reparterName,
		door = door,
		npc = npc,
		prompt = prompt,
		busy = false,
		activePlayer = nil,
	}

	pairsById[pairId] = pair

	setNPCVisible(npc, false)

	prompt.ActionText = "Knock"
	prompt.ObjectText = "Door"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 12)
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true

	prompt.Triggered:Connect(function(player)
		if pair.busy then
			return
		end

		print(("[NPCDoorInteraction] Triggered %s %s by %s"):format(
			pair.zoneName,
			pair.doorName,
			player.Name
		))

		pair.busy = true
		pair.activePlayer = player
		pair.prompt.Enabled = false

		setNPCVisible(pair.npc, true)

		npcDialogEvent:FireClient(player, {
			pairId = pair.id,
			npcName = pair.npc.Name,
			message = "Hey! Do you have my package?",
			buttonText = "Deliver Package",
		})
	end)

	print(("[NPCDoorInteraction] Connected %s %s -> %s"):format(
		zoneName,
		doorName,
		reparterName
	))
end

for zoneIndex = 1, 4 do
	local zoneName = "Zone" .. zoneIndex
	local zone = workspace:FindFirstChild(zoneName)

	if not zone then
		warn(("[NPCDoorInteraction] Missing zone: %s"):format(zoneName))
	else
		for doorIndex = 1, 2 do
			local doorName = "Door_" .. doorIndex
			local reparterName = "Reparter_" .. doorIndex

			local door = findDoorInZone(zone, doorName)
			local npc = zone:FindFirstChild(reparterName)

			if door and npc then
				setupPair(zoneName, door, npc, doorName, reparterName)
			else
				if not door then
					warnMissing(zoneName, doorName, "missing door anywhere inside zone")
				end

				if not npc then
					warnMissing(zoneName, doorName, "missing " .. reparterName)
				end
			end
		end
	end
end

npcDialogEvent.OnServerEvent:Connect(function(player, action, pairId)
	if action ~= "CompleteMockDelivery" then
		return
	end

	local pair = pairsById[pairId]
	if not pair then
		return
	end

	if pair.activePlayer ~= player then
		return
	end

	print(("[NPCDoorInteraction] Mock delivery completed %s %s by %s"):format(
		pair.zoneName,
		pair.doorName,
		player.Name
	))

	npcDialogEvent:FireClient(player, {
		close = true,
		pairId = pair.id,
	})

	setNPCVisible(pair.npc, false)

	pair.activePlayer = nil

	task.delay(COOLDOWN_TIME, function()
		pair.busy = false
		pair.prompt.Enabled = true
	end)
end)