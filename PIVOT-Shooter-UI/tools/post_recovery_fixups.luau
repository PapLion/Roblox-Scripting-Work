-- Paste into the Studio command bar once after opening place/PIVOT_ShooterUI.rbxl.
-- Re-applies the 3D set tweaks made after the 12:05 autosave (scripts are already up to date in the file).
local lobby = workspace.PivotStage.Lobby
for _, p in lobby:GetChildren() do
	if p.Name == "Stripe" then
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromHex("#8A3E12")
		p.Size = Vector3.new(90, 0.1, 0.2)
	elseif p.Name == "StripeLow" then
		p:Destroy()
	end
end
local O = Vector3.new(0, 0, 500)
lobby.WeaponMount.CFrame = CFrame.new(O + Vector3.new(0, 5.7, 2))
lobby.Mast.Size = Vector3.new(0.3, 3.6, 0.3)
lobby.Mast.CFrame = CFrame.new(O + Vector3.new(0, 3.5, 2))
lobby.LobbyCam.CFrame = CFrame.lookAt(O + Vector3.new(0, 5.6, 15.5), O + Vector3.new(0, 4.6, 2))

local marks = workspace.PivotStage.Arena.Marks
local A = Vector3.new(0, 0.1, -400)
marks.TargetA.CFrame = CFrame.new(A + Vector3.new(-4, 0, -9))
marks.TargetB.CFrame = CFrame.new(A + Vector3.new(5, 0, -12))
marks.TargetC.CFrame = CFrame.new(A + Vector3.new(1, 0, -15))
marks.TargetD.CFrame = CFrame.new(A + Vector3.new(-8, 0, -13))

-- small set with no character: everything streams at once
workspace.StreamingEnabled = false
for _, m in workspace.PivotStage:GetChildren() do
	if m:IsA("Model") then
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
end
print("PIVOT fixups applied")
