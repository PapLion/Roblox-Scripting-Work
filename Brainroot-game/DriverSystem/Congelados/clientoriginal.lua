local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local vanInput = ReplicatedStorage:WaitForChild("Events"):WaitForChild("VanInput")

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
				end
				updateInput()
			else
				if currentSeat then
					currentSeat = nil
					screenGui.Enabled = false
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
			end
		end
	end
end)
