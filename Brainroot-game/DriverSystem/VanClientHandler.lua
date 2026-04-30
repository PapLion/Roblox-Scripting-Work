local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local vanInput = ReplicatedStorage:WaitForChild("Events"):WaitForChild("VanInput")
local camera = workspace.CurrentCamera

local cameraConnection = nil
local hiddenCharacterParts = {}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VanGui"
screenGui.Enabled = false
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 180)
mainFrame.Position = UDim2.new(0.5, -150, 0.8, -90)
mainFrame.BackgroundTransparency = 0.5
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Text = "VAN CONTROLS"
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.Parent = mainFrame

local currentSeat = nil
local activeInputs = {
	W = false,
	A = false,
	S = false,
	D = false
}

local function setLocalCharacterHidden(hidden)
	local character = player.Character
	if not character then return end

	for _, obj in character:GetDescendants() do
		if obj:IsA("BasePart") then
			if hidden then
				hiddenCharacterParts[obj] = obj.LocalTransparencyModifier
				obj.LocalTransparencyModifier = 1
			else
				obj.LocalTransparencyModifier = hiddenCharacterParts[obj] or 0
			end

		elseif obj:IsA("Decal") then
			if hidden then
				hiddenCharacterParts[obj] = obj.Transparency
				obj.Transparency = 1
			else
				obj.Transparency = hiddenCharacterParts[obj] or 0
			end
		end
	end

	if not hidden then
		table.clear(hiddenCharacterParts)
	end
end

player.CharacterAdded:Connect(function()
	table.clear(hiddenCharacterParts)
end)

local function startVanCamera()
	local runtimeFolder = workspace:WaitForChild("VanRuntime")
	local cameraAnchor = runtimeFolder:WaitForChild("VanCameraAnchor")

	if cameraConnection then
		cameraConnection:Disconnect()
	end

	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	local _, initialYaw = cameraAnchor.CFrame:ToOrientation()
	local yaw = initialYaw + math.rad(180)
	local pitch = math.rad(-12)

	local distance = 24
	local targetHeight = 3.5
	local targetForwardOffset = -9 -- move the focus toward the center/front of the van

	local minPitch = math.rad(-50)
	local maxPitch = math.rad(25)
	local sensitivity = 0.003

	cameraConnection = RunService.RenderStepped:Connect(function(dt)
		if not cameraAnchor or not cameraAnchor.Parent then return end

		local delta = UserInputService:GetMouseDelta()
		yaw -= delta.X * sensitivity
		pitch = math.clamp(pitch - delta.Y * sensitivity, minPitch, maxPitch)

		local anchorCF = cameraAnchor.CFrame

		-- This is the point the camera looks at.
		-- Move it toward the center/front of the van so it doesn't focus the rear.
		local targetPos =
			anchorCF.Position
			+ anchorCF.LookVector * targetForwardOffset
			+ Vector3.new(0, targetHeight, 0)

		local rotation =
			CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(pitch, 0, 0)

		local cameraOffset = rotation:VectorToWorldSpace(Vector3.new(0, 0, distance))
		local camPos = targetPos + cameraOffset

		local targetCF = CFrame.lookAt(camPos, targetPos)

		-- For PivotTo arcade movement, a direct camera usually looks better than Lerp.
		camera.CFrame = targetCF
	end)
end

local function stopVanCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function createButton(text, position, size, key)
	local btn = Instance.new("TextButton")
	btn.Text = text
	btn.Position = position
	btn.Size = size
	btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.SourceSansBold
	btn.TextSize = 20
	btn.Parent = mainFrame

	btn.MouseButton1Down:Connect(function()
		activeInputs[key] = true
	end)

	btn.MouseButton1Up:Connect(function()
		activeInputs[key] = false
	end)

	-- Handle button focus loss
	btn.MouseLeave:Connect(function()
		activeInputs[key] = false
	end)

	return btn
end

-- Create directional buttons
local btnW = createButton("W (Forward)", UDim2.new(0.5, -40, 0, 40), UDim2.new(0, 80, 0, 40), "W")
local btnA = createButton("A (Left)", UDim2.new(0.5, -125, 0, 85), UDim2.new(0, 80, 0, 40), "A")
local btnS = createButton("S (Back)", UDim2.new(0.5, -40, 0, 85), UDim2.new(0, 80, 0, 40), "S")
local btnD = createButton("D (Right)", UDim2.new(0.5, 45, 0, 85), UDim2.new(0, 80, 0, 40), "D")

local exitLabel = Instance.new("TextLabel")
exitLabel.Text = "Press SPACE or Jump to Exit"
exitLabel.Size = UDim2.new(1, 0, 0, 30)
exitLabel.Position = UDim2.new(0, 0, 0, 140)
exitLabel.BackgroundTransparency = 1
exitLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
exitLabel.Font = Enum.Font.SourceSansItalic
exitLabel.TextSize = 16
exitLabel.Parent = mainFrame

local function updateInput()
	if not currentSeat then return end

	-- Only send inputs if the seat still exists and is valid
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.SeatPart ~= currentSeat then return end

	local throttle = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or activeInputs.W then throttle = 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or activeInputs.S then throttle = -1 end

	local steer = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or activeInputs.A then steer = -1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or activeInputs.D then steer = 1 end

	vanInput:FireServer({Type = "Throttle", Value = throttle})
	vanInput:FireServer({Type = "Steer", Value = steer})
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			local seat = humanoid.SeatPart
			if seat and seat.Name == "VanSeat" then
				if not currentSeat then
					currentSeat = seat
					screenGui.Enabled = true
					setLocalCharacterHidden(true)
					startVanCamera()
				end
				updateInput()
			else
				if currentSeat then
					currentSeat = nil
					screenGui.Enabled = false
					setLocalCharacterHidden(false)
					stopVanCamera()
				end
			end
		end
	end
end)

UserInputService.JumpRequest:Connect(function()
	if currentSeat then
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.Sit = false
				setLocalCharacterHidden(false)
				stopVanCamera()
			end
		end
	end
end)
