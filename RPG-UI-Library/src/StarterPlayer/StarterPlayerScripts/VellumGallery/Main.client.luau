--!strict
-- Vellum gallery client: opens straight into the component gallery. No character, no world.
-- In Studio it also exposes PlayerGui.VellumBridge (BindableFunction) for automated checks and captures.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Gallery = ReplicatedStorage:WaitForChild("VellumGallery")
local App = require(Gallery:WaitForChild("App"))
local Lib = require(Gallery:WaitForChild("Lib"))
local Scope = require(Lib.Core.Scope)
local Signal = require(Lib.Core.Signal)
local Motion = require(Lib.Core.Motion)
local Registry = require(Gallery:WaitForChild("Registry"))

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "VellumGallery"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local app = App.start(gui)

if RunService:IsStudio() then
	local bridge = Instance.new("BindableFunction")
	bridge.Name = "VellumBridge"
	bridge.OnInvoke = function(cmd: string, a: any, _b: any)
		if cmd == "list" then
			local ids = {}
			for _, s in Registry.list do
				table.insert(ids, s.id)
			end
			return ids
		elseif cmd == "show" then
			return app.show(a)
		elseif cmd == "capture" then
			app.setCapture(a == true, _b)
			return true
		elseif cmd == "batch" then
			local jobs = a or require(Gallery:WaitForChild("Captures"))
			if type(a) == "string" then
				-- a single id from the standard list
				for _, j in require(Gallery:WaitForChild("Captures")) do
					if j.id == a then
						jobs = { j }
					end
				end
			end
			return game:GetService("HttpService"):JSONEncode(app.captureBatch(jobs))
		elseif cmd == "tiles" then
			local opts = _b or {}
			local g = app.captureTiles(a or 2, opts.prep, opts.wait)
			return game:GetService("HttpService"):JSONEncode(g)
		elseif cmd == "width" then
			app.setWidth(a)
			return true
		elseif cmd == "reset" then
			app.reset()
			return true
		elseif cmd == "remount" then
			app.remount()
			return true
		elseif cmd == "motion" then
			Motion.reduced = a == false
			return true
		elseif cmd == "action" then
			for _, act in app.mounted.built.actions or {} do
				if act.label == a then
					task.spawn(act.run)
					return true
				end
			end
			return false
		elseif cmd == "actions" then
			local out = {}
			for _, act in app.mounted.built.actions or {} do
				table.insert(out, act.label)
			end
			return out
		elseif cmd == "stats" then
			return {
				id = app.current and app.current.id,
				scopes = Scope.liveCount(),
				listeners = Signal.listenerCount(),
				instances = if app.mounted then #app.mounted.canvas:GetDescendants() else 0,
				guiDescendants = #gui:GetDescendants(),
			}
		elseif cmd == "canvas" then
			local c = app.mounted.canvas
			return { x = c.AbsolutePosition.X, y = c.AbsolutePosition.Y, w = c.AbsoluteSize.X, h = c.AbsoluteSize.Y, scale = app.mounted.scale.Scale }
		elseif cmd == "find" then
			-- full path of the first stage descendant with this Name (for scripted input)
			for _, d in app.mounted.canvas.Parent.Parent:GetDescendants() do
				if d.Name == a then
					return d:GetFullName()
				end
			end
			return nil
		end
		return nil
	end
	bridge.Parent = playerGui
end
