local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local npcDialogEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("NPCDialogEvent")
local activePairId = nil

local gui = Instance.new("ScreenGui")
gui.Name = "NPCDialogGui"
gui.Enabled = false
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 420, 0, 170)
frame.Position = UDim2.new(0.5, -210, 0.72, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.15
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = frame

local npcName = Instance.new("TextLabel")
npcName.Size = UDim2.new(1, -30, 0, 35)
npcName.Position = UDim2.new(0, 15, 0, 10)
npcName.BackgroundTransparency = 1
npcName.TextColor3 = Color3.fromRGB(255, 255, 255)
npcName.Font = Enum.Font.GothamBold
npcName.TextSize = 20
npcName.TextXAlignment = Enum.TextXAlignment.Left
npcName.Parent = frame

local message = Instance.new("TextLabel")
message.Size = UDim2.new(1, -30, 0, 55)
message.Position = UDim2.new(0, 15, 0, 50)
message.BackgroundTransparency = 1
message.TextColor3 = Color3.fromRGB(230, 230, 230)
message.Font = Enum.Font.Gotham
message.TextSize = 16
message.TextWrapped = true
message.TextXAlignment = Enum.TextXAlignment.Left
message.Parent = frame

local deliverButton = Instance.new("TextButton")
deliverButton.Size = UDim2.new(0, 180, 0, 42)
deliverButton.Position = UDim2.new(1, -195, 1, -55)
deliverButton.BackgroundColor3 = Color3.fromRGB(70, 170, 90)
deliverButton.TextColor3 = Color3.fromRGB(255, 255, 255)
deliverButton.Font = Enum.Font.GothamBold
deliverButton.TextSize = 16
deliverButton.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 10)
btnCorner.Parent = deliverButton

deliverButton.MouseButton1Click:Connect(function()
	if activePairId then
		npcDialogEvent:FireServer("CompleteMockDelivery", activePairId)
	end
end)

npcDialogEvent.OnClientEvent:Connect(function(data)
	if data.close then
		if not data.pairId or data.pairId == activePairId then
			gui.Enabled = false
			activePairId = nil
		end
		return
	end

	activePairId = data.pairId
	npcName.Text = data.npcName or "NPC"
	message.Text = data.message or "..."
	deliverButton.Text = data.buttonText or "Continue"

	gui.Enabled = true
	print("[NPCDoorInteraction] Client dialog opened")
end)
