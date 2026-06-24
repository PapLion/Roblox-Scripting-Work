local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local eventsFolder = ReplicatedStorage:WaitForChild("Events")

local vanInput = eventsFolder:FindFirstChild("VanInput")
if not vanInput then
	vanInput = Instance.new("RemoteEvent")
	vanInput.Name = "VanInput"
	vanInput.Parent = eventsFolder
end

local vanFuelUpdate = eventsFolder:FindFirstChild("VanFuelUpdate")
if not vanFuelUpdate then
	vanFuelUpdate = Instance.new("RemoteEvent")
	vanFuelUpdate.Name = "VanFuelUpdate"
	vanFuelUpdate.Parent = eventsFolder
end

local SEAT_HEIGHT_IDLE = 0.3
local SEAT_ROTATION_Y = math.rad(180)
local CAMERA_BACK_OFFSET = -12
local CAMERA_UP_OFFSET = 7

local runtimeFolder = workspace:FindFirstChild("VanRuntime")
if not runtimeFolder then
	runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = "VanRuntime"
	runtimeFolder.Parent = workspace
end

local function getSeatPosition(van)
	local pivot = van:GetPivot()
	local highestY = -math.huge

	for _, desc in van:GetDescendants() do
		if desc:IsA("BasePart") then
			local topY = desc.Position.Y + desc.Size.Y / 2
			if topY > highestY then highestY = topY end
		end
	end

	local position
	if highestY > -math.huge then
		position =
			pivot.Position
			+ Vector3.new(0, highestY - pivot.Position.Y - 0.3, 0)
	else
		position = pivot.Position + Vector3.new(0, 5, 0)
	end

	return CFrame.new(position) * CFrame.Angles(0, SEAT_ROTATION_Y, 0)
end

local function getCameraAnchorCFrame(van)
	local pivot = van:GetPivot()

	return pivot * CFrame.new(0, CAMERA_UP_OFFSET, CAMERA_BACK_OFFSET)
end

local function getExitCFrame(van)
	return van:GetPivot() * CFrame.new(0, 8, 0)
end

local function getDriveSeat(van)
	local seat = van:FindFirstChild("VanSeat")
	if not seat then
		seat = Instance.new("VehicleSeat")
		seat.Name = "VanSeat"
		seat.Size = Vector3.new(2, 1, 2)
		seat.Transparency = 1
		seat.CanCollide = false  -- Prevent collision with van body
		seat.Anchored = true  -- Keep seat anchored

		-- Find the highest point of the van to position seat well above it
		local pivot = van:GetPivot()
		local highestY = -math.huge

		-- Scan all parts to find the highest point
		for _, desc in van:GetDescendants() do
			if desc:IsA("BasePart") then
				local sizeY = desc.Size.Y / 2
				local topY = desc.Position.Y + sizeY
				if topY > highestY then highestY = topY end
			end
		end

		seat.CFrame = getSeatPosition(van)
		seat.Parent = van

		print("[VanServerManager] Seat positioned")
	end
	return seat
end

-- Find the van and button
local van = workspace:FindFirstChild("Scene"):FindFirstChild("Van")
if not van then
	van = workspace:FindFirstChildWhichIsA("Model"):FindFirstChild("Van") or workspace:FindFirstChild("Van")
end

local button = workspace:FindFirstChild("base 4"):FindFirstChild("button")
if not button then
	button = workspace:FindFirstChild("base 4") or workspace:FindFirstChild("button")
end

if not van or not button then
	warn("[VanServerManager] Could not find Van or button!")
	return
end

local clickDetector = button:FindFirstChildOfClass("ClickDetector")
if not clickDetector then
	clickDetector = Instance.new("ClickDetector")
	clickDetector.Parent = button
end

local seat = getDriveSeat(van)

local cameraAnchor = runtimeFolder:FindFirstChild("VanCameraAnchor")
if not cameraAnchor then
	cameraAnchor = Instance.new("Part")
	cameraAnchor.Name = "VanCameraAnchor"
	cameraAnchor.Size = Vector3.new(1, 1, 1)
	cameraAnchor.Transparency = 1
	cameraAnchor.Anchored = true
	cameraAnchor.CanCollide = false
	cameraAnchor.CanTouch = false
	cameraAnchor.CanQuery = false
	cameraAnchor.Parent = runtimeFolder
end

-- Keep ALL van parts anchored to prevent falling apart
for _, part in van:GetDescendants() do
	if part:IsA("BasePart") then
		part.Anchored = true
		part.CanCollide = true  -- Van should have collisions
	end
end
if seat:IsA("BasePart") then
	seat.Anchored = true
end

-- Van driving state
local MAX_SPEED = 38
local REVERSE_SPEED = 16

local MAX_FUEL = 100
local FUEL_DRAIN_PER_SECOND = 4
local FUEL_UPDATE_INTERVAL = 0.15

local REFUEL_TO_FULL = true
local REFUEL_AMOUNT = MAX_FUEL

local vanState = {
	currentDriver = nil,
	throttle = 0,
	steer = 0,
	smoothSteer = 0,
	speed = 0,
	fuel = MAX_FUEL,
	lastFuelUpdate = 0
}

local function sendFuelUpdate(player)
	if not player then return end

	vanFuelUpdate:FireClient(player, {
		current = math.floor(vanState.fuel),
		max = MAX_FUEL,
		percent = math.clamp(vanState.fuel / MAX_FUEL, 0, 1)
	})
end

local function refuelVan(player)
	if not player then return end

	-- Solo el conductor actual puede recargar esta van.
	if vanState.currentDriver ~= player then
		return
	end

	if vanState.fuel >= MAX_FUEL then
		sendFuelUpdate(player)
		return
	end

	if REFUEL_TO_FULL then
		vanState.fuel = MAX_FUEL
	else
		vanState.fuel = math.min(MAX_FUEL, vanState.fuel + REFUEL_AMOUNT)
	end

	vanState.lastFuelUpdate = 0
	sendFuelUpdate(player)

	print("[VanServerManager] Van refueled by", player.Name, "| Fuel:", math.floor(vanState.fuel))
end

local connectedFuelPrompts = {}

local function connectFuelPrompt(prompt)
	if connectedFuelPrompts[prompt] then return end
	connectedFuelPrompts[prompt] = true

	prompt.ActionText = "Refuel"
	prompt.ObjectText = "Gas Station"
	prompt.HoldDuration = 3
	prompt.RequiresLineOfSight = false

	prompt.Triggered:Connect(function(player)
		refuelVan(player)
	end)

	print("[VanServerManager] Connected fuel prompt:", prompt:GetFullName())
end

local function setupFuelStations()
	for _, obj in workspace:GetDescendants() do
		if obj:IsA("ProximityPrompt") then
			local parentModel = obj:FindFirstAncestorWhichIsA("Model")

			if parentModel and string.find(string.lower(parentModel.Name), "gasolina") then
				connectFuelPrompt(obj)
			end
		end
	end
end

setupFuelStations()

workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("ProximityPrompt") then
		task.wait()

		local parentModel = obj:FindFirstAncestorWhichIsA("Model")
		if parentModel and string.find(string.lower(parentModel.Name), "gasolina") then
			connectFuelPrompt(obj)
		end
	end
end)

local ACCELERATION = 32
local BRAKE_ACCELERATION = 48
local FRICTION = 26

local TURN_SPEED = 1.55
local STEER_SMOOTHNESS = 8

-- Cambia a 1 si W vuelve a ir hacia atrás.
local FORWARD_SIGN = -1

-- Handle button click to enter van
clickDetector.MouseClick:Connect(function(player)
	local character = player.Character
	if not character or not character:FindFirstChild("Humanoid") then return end
	local humanoid = character.Humanoid

	-- If someone is already driving, kick them out
	if vanState.currentDriver and vanState.currentDriver ~= player then
		local prevChar = vanState.currentDriver.Character
		if prevChar and prevChar:FindFirstChild("Humanoid") then
			prevChar.Humanoid.Sit = false
		end
	end

	-- Position player safely on ground
	local vanPos = van:GetPivot().Position
	character:PivotTo(CFrame.new(vanPos.X, 20, vanPos.Z))
	task.wait(0.2)

	-- Teleport to seat and sit
	character:PivotTo(seat.CFrame)
	task.wait(0.1)
	seat:Sit(humanoid)

	vanState.currentDriver = player
	sendFuelUpdate(player)
	print("[VanServerManager] Player entered van")
end)

-- Handle input from client
vanInput.OnServerEvent:Connect(function(player, input)
	if typeof(input) ~= "table" then return end

	if not vanState.currentDriver then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoid and humanoid.SeatPart == seat then
			vanState.currentDriver = player
		else
			return
		end
	end

	if vanState.currentDriver ~= player then return end

	if input.Type == "Throttle" then
		vanState.throttle = math.clamp(tonumber(input.Value) or 0, -1, 1)
	elseif input.Type == "Steer" then
		vanState.steer = math.clamp(tonumber(input.Value) or 0, -1, 1)
	end
end)

-- Main drive loop - arcade movement with PivotTo
RunService.Heartbeat:Connect(function(dt)
	if not vanState.currentDriver then
		return
	end

	local character = vanState.currentDriver.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	-- If the driver left the seat, stop the van and remove control.
	if not humanoid or humanoid.SeatPart ~= seat then
		vanState.currentDriver = nil
		vanState.throttle = 0
		vanState.steer = 0
		vanState.smoothSteer = 0
		vanState.speed = 0
		return
	end

	local currentPivot = van:GetPivot()
	local hasFuel = vanState.fuel > 0

	-- Target speed based on W/S.
	local targetSpeed = 0
	if hasFuel then
		if vanState.throttle > 0 then
			targetSpeed = MAX_SPEED * vanState.throttle
		elseif vanState.throttle < 0 then
			targetSpeed = REVERSE_SPEED * vanState.throttle
		end
	end

	if hasFuel and vanState.throttle ~= 0 then
		local drainMultiplier = 1

		-- Reverse consumes less because it is slower / less useful movement.
		if vanState.throttle < 0 then
			drainMultiplier = 0.45
		end

		-- Turning while moving consumes slightly less to avoid punishing steering.
		if math.abs(vanState.steer) > 0 then
			drainMultiplier *= 0.85
		end

		vanState.fuel = math.max(0, vanState.fuel - FUEL_DRAIN_PER_SECOND * drainMultiplier * dt)

		vanState.lastFuelUpdate += dt
		if vanState.lastFuelUpdate >= FUEL_UPDATE_INTERVAL then
			vanState.lastFuelUpdate = 0
			sendFuelUpdate(vanState.currentDriver)
		end
	end

	-- Smooth acceleration / braking / friction.
	if targetSpeed > vanState.speed then
		vanState.speed = math.min(vanState.speed + ACCELERATION * dt, targetSpeed)
	elseif targetSpeed < vanState.speed then
		if targetSpeed == 0 then
			vanState.speed = math.max(vanState.speed - FRICTION * dt, 0)
		else
			vanState.speed = math.max(vanState.speed - BRAKE_ACCELERATION * dt, targetSpeed)
		end
	end

	if math.abs(vanState.speed) < 0.05 then
		vanState.speed = 0
	end

	-- Smooth steering input.
	local steerAlpha = math.clamp(dt * STEER_SMOOTHNESS, 0, 1)
	vanState.smoothSteer = vanState.smoothSteer + (vanState.steer - vanState.smoothSteer) * steerAlpha

	-- Turn less when almost stopped.
	local speedFactor = math.clamp(math.abs(vanState.speed) / MAX_SPEED, 0, 1)

	local turnAmount = 0
	if speedFactor > 0.05 then
		local reverseMultiplier = vanState.speed < 0 and -1 or 1
		turnAmount = -vanState.smoothSteer * TURN_SPEED * speedFactor * reverseMultiplier * dt
	end

	-- Movement is local to the van orientation.
	-- FORWARD_SIGN fixes imported models that face backward.
	local rotation = CFrame.Angles(0, turnAmount, 0)
	local movement = CFrame.new(0, 0, FORWARD_SIGN * -vanState.speed * dt)

	van:PivotTo(currentPivot * rotation * movement)

	cameraAnchor.CFrame = getCameraAnchorCFrame(van)
end)

-- Handle player exiting
seat:GetPropertyChangedSignal("Occupant"):Connect(function()
	if not seat.Occupant then
		vanState.currentDriver = nil
		vanState.throttle = 0
		vanState.steer = 0
		vanState.smoothSteer = 0
		vanState.speed = 0
		print("[VanServerManager] Player exited van")
	end
end)

print("[VanServerManager] Loaded successfully - Van is anchored and ready")