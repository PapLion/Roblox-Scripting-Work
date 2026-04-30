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
		
		local position
		if highestY > -math.huge then
			position = Vector3.new(pivot.Position.X, highestY + 3, pivot.Position.Z)
		else
			position = pivot.Position + Vector3.new(0, 5, 0)
		end
		
		seat.CFrame = CFrame.new(position)
		seat.Parent = van
		
		print("[VanServerManager] Seat positioned at Y =", position.Y)
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
local vanState = {
	currentDriver = nil,
	throttle = 0,
	steer = 0,
	speed = 0
}

local MAX_SPEED = 45
local REVERSE_SPEED = 22
local ACCELERATION = 55
local BRAKE_ACCELERATION = 70
local FRICTION = 38
local TURN_SPEED = 2.4

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
		vanState.speed = 0
		return
	end

	local currentPivot = van:GetPivot()

	-- Target speed based on W/S.
	local targetSpeed = 0
	if vanState.throttle > 0 then
		targetSpeed = MAX_SPEED * vanState.throttle
	elseif vanState.throttle < 0 then
		targetSpeed = REVERSE_SPEED * vanState.throttle
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

	-- Turn less when almost stopped.
	local speedFactor = math.clamp(math.abs(vanState.speed) / MAX_SPEED, 0, 1)

	local turnAmount = 0
	if speedFactor > 0 then
		local reverseMultiplier = vanState.speed < 0 and -1 or 1
		turnAmount = -vanState.steer * TURN_SPEED * speedFactor * reverseMultiplier * dt
	end

	-- Movement is local to the van orientation.
	local rotation = CFrame.Angles(0, turnAmount, 0)
	local movement = CFrame.new(0, 0, -vanState.speed * dt)

	van:PivotTo(currentPivot * rotation * movement)
end)

-- Handle player exiting
seat:GetPropertyChangedSignal("Occupant"):Connect(function()
	if not seat.Occupant then
		vanState.currentDriver = nil
		vanState.throttle = 0
		vanState.steer = 0
		vanState.speed = 0
		print("[VanServerManager] Player exited van")
	end
end)

print("[VanServerManager] Loaded successfully - Van is anchored and ready")