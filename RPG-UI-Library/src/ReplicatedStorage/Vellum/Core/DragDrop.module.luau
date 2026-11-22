--!strict
-- DragDrop: pointer drag between registered targets. A source starts a drag with a payload after a small
-- movement threshold; a ghost follows the pointer in the overlay; targets under the pointer are asked
-- accepts(payload) and get highlight(state) ("valid" | "invalid" | nil); release calls drop(payload) on the
-- target or cancel on the source. Works inside a UIScale (coordinates go through Layers).
local UserInputService = game:GetService("UserInputService")
local Layers = require(script.Parent.Layers)
local Motion = require(script.Parent.Motion)
local Theme = require(script.Parent.Parent.Theme)

export type Target = {
	gui: GuiObject,
	accepts: (payload: any) -> boolean,
	highlight: (state: string?) -> (),
	drop: (payload: any) -> (),
}

local DragDrop = {}
DragDrop.__index = DragDrop

-- One context per widget (or shared between widgets that exchange items).
function DragDrop.new(scope: any)
	local self = setmetatable({ targets = {} :: { Target }, active = nil :: any, scope = scope }, DragDrop)
	scope:add(function()
		self:_end(nil)
	end)
	return self
end

function DragDrop:addTarget(t: Target)
	table.insert(self.targets, t)
	return function()
		local i = table.find(self.targets, t)
		if i then
			table.remove(self.targets, i)
		end
	end
end

local function inside(gui: GuiObject, p: Vector2): boolean
	local a, s = gui.AbsolutePosition, gui.AbsoluteSize
	return gui.Visible and p.X >= a.X and p.Y >= a.Y and p.X <= a.X + s.X and p.Y <= a.Y + s.Y
end

function DragDrop:_targetAt(p: Vector2): Target?
	for _, t in self.targets do
		if t.gui.Parent and inside(t.gui, p) then
			return t
		end
	end
	return nil
end

-- source: the pressed GuiObject. payload: anything. makeGhost(): GuiObject sized in local units.
-- callbacks: onStart(), onCancel(), onEnd()
function DragDrop:bindSource(scope: any, source: GuiObject, getPayload: () -> any?, makeGhost: () -> GuiObject, callbacks: { [string]: any }?)
	local cb = callbacks or {}
	scope:connect(source.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local payload = getPayload()
		if payload == nil or self.active then
			return
		end
		local start = Vector2.new(input.Position.X, input.Position.Y)
		local pending = { payload = payload, start = start, source = source, makeGhost = makeGhost, cb = cb, started = false }
		self.active = pending
		local moveConn, endConn
		moveConn = UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
				self:_move(Vector2.new(i.Position.X, i.Position.Y))
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				moveConn:Disconnect()
				endConn:Disconnect()
				self:_end(Vector2.new(i.Position.X, i.Position.Y))
			end
		end)
		pending.conns = { moveConn, endConn }
	end)
end

function DragDrop:_move(p: Vector2)
	local a = self.active
	if not a then
		return
	end
	if not a.started then
		if (p - a.start).Magnitude < 6 then
			return
		end
		a.started = true
		local ghost = a.makeGhost()
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.ZIndex = Theme.z.drag
		for _, d in ghost:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += Theme.z.drag
			end
		end
		ghost.Parent = Layers.get()
		local sc = Instance.new("UIScale")
		sc.Scale = 1
		sc.Parent = ghost
		Motion.tween(sc, { Scale = 1.12 }, Theme.motion.base, Theme.motion.spring)
		a.ghost = ghost
		if a.cb.onStart then
			a.cb.onStart()
		end
	end
	local l = Layers.toLocal(p)
	a.ghost.Position = UDim2.fromOffset(l.X, l.Y)
	a.ghost.Rotation = math.clamp((p.X - (a.lastX or p.X)) * 0.6, -8, 8)
	a.lastX = p.X
	local t = self:_targetAt(p)
	if t ~= a.hover then
		if a.hover then
			a.hover.highlight(nil)
		end
		a.hover = t
		if t then
			t.highlight(if t.accepts(a.payload) then "valid" else "invalid")
		end
	end
end

-- Programmatic drag (tests, keyboard moves and the gallery's scripted demo): drop payload on a target gui.
function DragDrop:dropOn(payload: any, gui: GuiObject): boolean
	for _, t in self.targets do
		if t.gui == gui and t.accepts(payload) then
			t.drop(payload)
			return true
		end
	end
	return false
end

function DragDrop:_end(p: Vector2?)
	local a = self.active
	if not a then
		return
	end
	self.active = nil
	if a.conns then
		for _, c in a.conns do
			c:Disconnect()
		end
	end
	if a.hover then
		a.hover.highlight(nil)
	end
	if a.ghost then
		a.ghost:Destroy()
	end
	if not a.started then
		return
	end
	local t = if p then self:_targetAt(p) else nil
	if t and t.accepts(a.payload) then
		t.drop(a.payload)
	elseif a.cb.onCancel then
		a.cb.onCancel()
	end
	if a.cb.onEnd then
		a.cb.onEnd()
	end
end

function DragDrop:isDragging(): boolean
	return self.active ~= nil and self.active.started == true
end

return DragDrop
