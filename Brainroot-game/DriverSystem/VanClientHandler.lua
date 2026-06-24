local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local vanInput = ReplicatedStorage:WaitForChild("Events"):WaitForChild("VanInput")
local vanFuelUpdate = ReplicatedStorage:WaitForChild("Events"):WaitForChild("VanFuelUpdate")
local camera = workspace.CurrentCamera

local cameraConnection = nil
local hiddenCharacterParts = {}
local mouseUnlocked = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VanGui"
screenGui.Enabled = false
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 200)
mainFrame.Position = UDim2.new(0, 24, 1, -200)
mainFrame.BackgroundTransparency = 1
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Text = "VAN"
title.Size = UDim2.new(0, 120, 0, 28)
title.Position = UDim2.new(0, 70, 0, 0)
title.BackgroundTransparency = 0.35
title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = title

local mouseHint = Instance.new("TextLabel")
mouseHint.Text = "Press V to unlock mouse"
mouseHint.Size = UDim2.new(0, 160, 0, 18)
mouseHint.Position = UDim2.new(0, 50, 0, 28)
mouseHint.BackgroundTransparency = 1
mouseHint.TextColor3 = Color3.fromRGB(230, 230, 230)
mouseHint.Font = Enum.Font.Gotham
mouseHint.TextSize = 12
mouseHint.Parent = mainFrame

local fuelFrame = Instance.new("Frame")
fuelFrame.Size = UDim2.new(0, 180, 0, 46)
fuelFrame.Position = UDim2.new(1, -210, 1, -90)
fuelFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fuelFrame.BackgroundTransparency = 0.35
fuelFrame.Visible = false
fuelFrame.Parent = screenGui

local fuelCorner = Instance.new("UICorner")
fuelCorner.CornerRadius = UDim.new(0, 10)
fuelCorner.Parent = fuelFrame

local fuelLabel = Instance.new("TextLabel")
fuelLabel.Size = UDim2.new(1, 0, 0, 18)
fuelLabel.Position = UDim2.new(0, 0, 0, 3)
fuelLabel.BackgroundTransparency = 1
fuelLabel.Text = "Fuel: 100/100"
fuelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
fuelLabel.Font = Enum.Font.GothamBold
fuelLabel.TextSize = 13
fuelLabel.Parent = fuelFrame

local fuelBarBack = Instance.new("Frame")
fuelBarBack.Size = UDim2.new(1, -20, 0, 14)
fuelBarBack.Position = UDim2.new(0, 10, 0, 25)
fuelBarBack.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
fuelBarBack.BorderSizePixel = 0
fuelBarBack.Parent = fuelFrame

local fuelBarBackCorner = Instance.new("UICorner")
fuelBarBackCorner.CornerRadius = UDim.new(1, 0)
fuelBarBackCorner.Parent = fuelBarBack

local fuelBarFill = Instance.new("Frame")
fuelBarFill.Size = UDim2.new(1, 0, 1, 0)
fuelBarFill.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
fuelBarFill.BorderSizePixel = 0
fuelBarFill.Parent = fuelBarBack

local fuelBarFillCorner = Instance.new("UICorner")
fuelBarFillCorner.CornerRadius = UDim.new(1, 0)
fuelBarFillCorner.Parent = fuelBarFill

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

local function updateMouseState()
	if mouseUnlocked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
end

local function canToggleMouse()
	return currentSeat ~= nil and not UserInputService.TouchEnabled
end

vanFuelUpdate.OnClientEvent:Connect(function(data)
	local current = data.current or 0
	local maxFuel = data.max or 100
	local percent = math.clamp(data.percent or 0, 0, 1)

	fuelLabel.Text = "Fuel: " .. current .. "/" .. maxFuel
	fuelBarFill.Size = UDim2.new(percent, 0, 1, 0)
end)

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
	mouseUnlocked = false
	updateMouseState()

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

	mouseUnlocked = true
	updateMouseState()

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
	btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	btn.BackgroundTransparency = 0.18
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 22
	btn.AutoButtonColor = false
	btn.Parent = mainFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.35
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Parent = btn

	local function setPressed(isPressed)
		activeInputs[key] = isPressed

		if isPressed then
			btn.BackgroundTransparency = 0
			btn.TextSize = 24
		else
			btn.BackgroundTransparency = 0.18
			btn.TextSize = 22
		end
	end

	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setPressed(true)
		end
	end)

	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setPressed(false)
		end
	end)

	btn.MouseLeave:Connect(function()
		setPressed(false)
	end)

	btn.TouchLongPress:Connect(function(_, state)
		if state == Enum.UserInputState.End then
			setPressed(false)
		end
	end)

	btn.Activated:Connect(function()
		-- Activated is click/tap release, so we do not toggle here.
		-- Movement is handled by MouseButton1Down / MouseButton1Up.
	end)

	return btn
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if not canToggleMouse() then return end

	if input.KeyCode == Enum.KeyCode.V then
		mouseUnlocked = not mouseUnlocked
		updateMouseState()
	end
end)

local buttonSize = UDim2.new(0, 64, 0, 64)

local btnW = createButton("▲", UDim2.new(0, 88, 0, 34), buttonSize, "W")
local btnA = createButton("◀", UDim2.new(0, 20, 0, 102), buttonSize, "A")
local btnS = createButton("▼", UDim2.new(0, 88, 0, 102), buttonSize, "S")
local btnD = createButton("▶", UDim2.new(0, 156, 0, 102), buttonSize, "D")

local exitLabel = Instance.new("TextLabel")
exitLabel.Text = "Jump / Space to exit"
exitLabel.Size = UDim2.new(0, 220, 0, 24)
exitLabel.Position = UDim2.new(0, 20, 0, 166)
exitLabel.BackgroundTransparency = 1
exitLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
exitLabel.Font = Enum.Font.Gotham
exitLabel.TextSize = 13
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
					fuelFrame.Visible = true
					setLocalCharacterHidden(true)
					startVanCamera()
				end
				updateInput()
			else
				if currentSeat then
					currentSeat = nil
					screenGui.Enabled = false
					fuelFrame.Visible = false
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
