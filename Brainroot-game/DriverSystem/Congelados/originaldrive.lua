local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local vanInput = Instance.new("RemoteEvent")
vanInput.Name = "VanInput"
vanInput.Parent = ReplicatedStorage:WaitForChild("Events")

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
	position = van:GetPivot().Position,
	orientation = 0,  -- Y-axis rotation in radians
	currentDriver = nil,
	velocity = Vector3.new(0, 0, 0)
}

local DRIVE_SPEED = 20
local STEER_SPEED = 2
local FRICTION = 0.92

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
	local vanPos = vanState.position
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
	-- Only accept input from current driver
	if vanState.currentDriver ~= player then return end
	
	if input.Type == "Throttle" then
		vanState.velocity = Vector3.new(0, 0, input.Value * DRIVE_SPEED)
	elseif input.Type == "Steer" then
		vanState.orientation = input.Value * STEER_SPEED
	end
end)

-- Main drive loop - manually move the anchored van
RunService.Heartbeat:Connect(function(dt)
	if not vanState.currentDriver then return end
	
	-- Get current van orientation
	local vanCFrame = van:GetPivot()
	local forward = vanCFrame.LookVector
	
	-- Calculate movement
	local moveDir = (forward * vanState.velocity.Z) + Vector3.new(0, 0, 0)
	
	-- Apply movement
	if moveDir.Magnitude > 0.1 then
		local newPos = vanCFrame.Position + (moveDir * dt)
		van:PivotTo(CFrame.new(newPos) * CFrame.Angles(0, vanState.orientation, 0))
		
		-- Keep seat positioned relative to van
		local seatOffset = seat.Position - vanCFrame.Position
		seat:PivotTo(CFrame.new(newPos + seatOffset))
	end
	
	-- Apply friction to slow down when no throttle
	if vanState.velocity.Magnitude > 0 then
		vanState.velocity = vanState.velocity * FRICTION
		if vanState.velocity.Magnitude < 0.5 then
			vanState.velocity = Vector3.new(0, 0, 0)
			vanState.orientation = 0
		end
	end
end)

-- Handle player exiting
seat:GetPropertyChangedSignal("Occupant"):Connect(function()
	local occupant = seat.Occupant
	if occupant and occupant.Parent then
		local player = Players:GetPlayerFromCharacter(occupant.Parent)
		if player then
			vanState.currentDriver = nil
			vanState.velocity = Vector3.new(0, 0, 0)
			vanState.orientation = 0
			print("[VanServerManager] Player exited van")
		end
	end
end)

print("[VanServerManager] Loaded successfully - Van is anchored and ready")