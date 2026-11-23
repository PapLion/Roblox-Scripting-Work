--!strict
-- Gallery app: a neutral shell for browsing specimens. Sidebar (families → specimens), header (title,
-- blurb, stage width presets, reduced motion, capture mode, reset), the stage, and an action bar with
-- the specimen's state actions. The shell deliberately uses plain system type and greys so the
-- Vellum pieces are the only styled thing on screen.
local UserInputService = game:GetService("UserInputService")

local Lib = require(script.Parent.Lib)
local Create = require(Lib.Core.Create)
local Scope = require(Lib.Core.Scope)
local Signal = require(Lib.Core.Signal)
local Motion = require(Lib.Core.Motion)
local Registry = require(script.Parent.Registry)
local Stage = require(script.Parent.Stage)

local App = {}

local G = {
	bg = Color3.fromHex("0B0A09"),
	side = Color3.fromHex("121110"),
	line = Color3.fromHex("26231F"),
	text = Color3.fromHex("E8E2D8"),
	soft = Color3.fromHex("9A938A"),
	faint = Color3.fromHex("5F5952"),
	hi = Color3.fromHex("1F1C19"),
	accent = Color3.fromHex("D4A55A"),
}
local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local FONT_B = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

local function label(text: string, size: number, color: Color3, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		FontFace = FONT,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
	}
	for k, v in props or {} do
		p[k] = v
	end
	return Create("TextLabel", p)
end

local function chip(text: string, onClick: () -> (), props: { [string]: any }?): TextButton
	local p: { [string]: any } = {
		Text = text,
		TextSize = 13,
		FontFace = FONT,
		TextColor3 = G.soft,
		BackgroundColor3 = G.hi,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
	}
	for k, v in props or {} do
		p[k] = v
	end
	local b = Create("TextButton", p, { Create.corner(6), Create.padding(0, 12, 0, 12), Create.stroke(G.line, 1, 0) })
	b.MouseEnter:Connect(function()
		b.TextColor3 = G.text
	end)
	b.MouseLeave:Connect(function()
		if not b:GetAttribute("On") then
			b.TextColor3 = G.soft
		end
	end)
	b.Activated:Connect(onClick)
	return b
end

local function setOn(b: TextButton, on: boolean)
	b:SetAttribute("On", on)
	b.TextColor3 = if on then G.bg else G.soft
	b.BackgroundColor3 = if on then G.accent else G.hi
end

function App.start(gui: ScreenGui)
	local self = {
		current = nil :: any,
		mounted = nil :: any,
		changed = Signal.new(),
		capture = false,
		width = "full",
	}
	local root = Create("Frame", { Name = "Gallery", BackgroundColor3 = G.bg, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = gui })

	-- sidebar
	local side = Create("Frame", { Name = "Sidebar", BackgroundColor3 = G.side, BorderSizePixel = 0, Size = UDim2.new(0, 250, 1, 0), Parent = root }, { Create.stroke(G.line, 1, 0) })
	local brand = Create.box({ Size = UDim2.new(1, 0, 0, 84), Parent = side }, { Create.padding(20, 18, 0, 20) })
	label("VELLUM", 20, G.accent, { FontFace = FONT_B, Parent = brand })
	label("Fantasy RPG UI Library", 13, G.soft, { Position = UDim2.fromOffset(0, 28), Parent = brand })
	label("Component gallery · Studio", 11, G.faint, { Position = UDim2.fromOffset(0, 46), Parent = brand })
	local list = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 1, -84 - 64),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = G.line,
		Parent = side,
	}, { Create.padding(4, 10, 16, 10), Create.list("y", 2) })
	local entries = {}
	local order = 0
	for _, fam in Registry.families do
		order += 1
		local h = label(string.upper(fam.title), 11, G.faint, { FontFace = FONT_B, LayoutOrder = order, Parent = list })
		Create.padding(14, 0, 6, 10).Parent = h
		for _, s in Registry.inFamily(fam.id) do
			order += 1
			local b = Create("TextButton", {
				Name = s.id,
				Text = s.title,
				TextSize = 14,
				FontFace = FONT,
				TextColor3 = G.soft,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = G.hi,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = order,
				Parent = list,
			}, { Create.corner(6), Create.padding(0, 10, 0, 10) })
			b.MouseEnter:Connect(function()
				if self.current ~= s then
					b.BackgroundTransparency = 0.5
				end
			end)
			b.MouseLeave:Connect(function()
				if self.current ~= s then
					b.BackgroundTransparency = 1
				end
			end)
			b.Activated:Connect(function()
				self.show(s.id)
			end)
			entries[s.id] = b
		end
	end
	local leak = label("", 11, G.faint, { Position = UDim2.new(0, 20, 1, -52), Parent = side })
	label("PgUp/PgDn specimen · Ctrl+R reset · F8 capture", 11, G.faint, { Position = UDim2.new(0, 20, 1, -30), Parent = side })

	-- main column
	local main = Create.box({ Name = "Main", Position = UDim2.fromOffset(250, 0), Size = UDim2.new(1, -250, 1, 0), Parent = root })
	local header = Create("Frame", { Name = "Header", BackgroundColor3 = G.bg, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 76), Parent = main }, { Create.padding(16, 24, 0, 28) })
	local title = label("", 22, G.text, { FontFace = FONT_B, Parent = header })
	local blurb = label("", 13, G.soft, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, -520, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Parent = header })
	local tools = Create.box({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Parent = header }, { Create.list("x", 6, nil, Enum.VerticalAlignment.Center) })
	local widthChips = {}
	for i, w in { { "full", "Fit" }, { "1024", "1024 px" }, { "720", "720 px" } } do
		local c = chip(w[2], function()
			self.setWidth(w[1])
		end, { LayoutOrder = i, Parent = tools })
		widthChips[w[1]] = c
	end
	Create.box({ Size = UDim2.fromOffset(8, 1), LayoutOrder = 10, Parent = tools })
	local motionChip = chip("Motion", function()
		Motion.reduced = not Motion.reduced
		self.refreshChips()
	end, { LayoutOrder = 11, Parent = tools })
	local captureChip = chip("Capture", function()
		self.setCapture(not self.capture)
	end, { LayoutOrder = 12, Parent = tools })
	chip("Reset", function()
		self.reset()
	end, { LayoutOrder = 13, Parent = tools })

	local stageHost = Create.box({ Name = "StageHost", Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 1, -76 - 56), ClipsDescendants = true, Parent = main })
	local actionBar = Create("Frame", { Name = "Actions", BackgroundColor3 = G.side, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 56), Parent = main }, {
		Create.stroke(G.line, 1, 0),
		Create.padding(0, 24, 0, 24),
		Create.list("x", 8, nil, Enum.VerticalAlignment.Center),
	})

	function self.refreshChips()
		for k, c in widthChips do
			setOn(c, self.width == k)
		end
		setOn(motionChip, not Motion.reduced)
		setOn(captureChip, self.capture)
	end

	local function mount()
		if self.mounted then
			self.mounted.scope:Destroy()
			self.mounted = nil
		end
		local s = self.current
		local insets = { 0, 0, 0, 0 }
		if self.width ~= "full" and not self.capture then
			local w = tonumber(self.width) :: number
			local avail = stageHost.AbsoluteSize.X
			local side = math.max(0, (avail - w) / 2)
			insets = { side, 0, side, 0 }
		end
		if self.capture then
			-- keep the canvas clear of Roblox's top-bar buttons (top-left corner of the viewport)
			insets = { 8, 64, 8, 8 }
		end
		local host: GuiObject = if self.capture then root else stageHost
		self.mounted = Stage.mount(host, s, {
			capture = self.capture,
			tiled = self.capture and self.tiled,
			fixedScale = self.captureScale or 2,
			maxScale = if self.capture then (self.captureScale or 2) else 1.5,
			insets = insets,
			margin = if self.capture then 28 else 36,
		})
		if self.capture then
			self.mounted.canvas.Parent.Parent.ZIndex = 50
			for _, d in self.mounted.canvas.Parent.Parent:GetDescendants() do
				if d:IsA("GuiObject") then
					d.ZIndex += 50
				end
			end
		end
		-- actions
		for _, ch in actionBar:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		label("STATE", 11, G.faint, { FontFace = FONT_B, LayoutOrder = 0, Parent = actionBar })
		for i, a in self.mounted.built.actions or {} do
			chip(a.label, function()
				task.spawn(a.run)
			end, { LayoutOrder = i, Parent = actionBar })
		end
		if not self.mounted.built.actions or #self.mounted.built.actions == 0 then
			label("Hover, click and focus the pieces directly.", 12, G.faint, { LayoutOrder = 1, Parent = actionBar })
		end
	end

	function self.show(id: string)
		local s = Registry.get(id)
		if not s then
			return false
		end
		if self.current then
			local prev = entries[self.current.id]
			prev.BackgroundTransparency = 1
			prev.TextColor3 = G.soft
		end
		self.current = s
		local e = entries[id]
		e.BackgroundTransparency = 0
		e.TextColor3 = G.text
		title.Text = s.title
		blurb.Text = s.blurb
		mount()
		self.changed:Fire(id)
		return true
	end

	function self.reset()
		if not self.mounted then
			return
		end
		local r = self.mounted.built.onReset
		if r then
			r()
		else
			mount()
		end
	end

	function self.remount()
		mount()
	end

	function self.setWidth(w: string)
		self.width = w
		self.refreshChips()
		mount()
	end

	function self.setCapture(on: boolean, scale: number?)
		if not on then
			self.tiled = false
		end
		Motion.paused = false
		self.capture = on
		self.captureScale = scale
		UserInputService.MouseIconEnabled = not on
		side.Visible = not on
		header.Visible = not on
		actionBar.Visible = not on
		self.refreshChips()
		mount()
	end

	-- Tiled capture: render the current specimen at `scale` and walk the tile grid, holding each tile with
	-- its marker so tools/capture/tiles.py can grab and stitch them. Returns the grid geometry.
	-- prep: action labels to run (in order) on the fresh mount before tiling; prepWait: settle time after.
	function self.captureTiles(scale: number, prep: { string }?, prepWait: number?)
		local hold = nil
		self.tiled = true
		self.setCapture(true, scale)
		task.wait(0.3)
		local m = self.mounted
		for _, label in prep or {} do
			for _, a in m.built.actions or {} do
				if a.label == label then
					a.run()
				end
			end
			task.wait(0.2)
		end
		task.wait(prepWait or 0.4)
		Motion.paused = true
		local size = m.canvas.AbsoluteSize -- scaled canvas, logical px
		local win = m.slot.AbsoluteSize
		local stepX = math.floor(win.X / 4) * 4
		local stepY = math.floor(win.Y / 4) * 4
		local cols = math.max(1, math.ceil(size.X / stepX))
		local rows = math.max(1, math.ceil(size.Y / stepY))
		local token = {}
		self.tileToken = token
		task.spawn(function()
			local i = 0
			for r = 0, rows - 1 do
				for c = 0, cols - 1 do
					if self.tileToken ~= token then
						return
					end
					m.setTile(c * stepX, r * stepY)
					m.marker(62) -- "moving"
					task.wait(0.35)
					m.marker(i)
					task.wait(if i == 0 then 6 else (hold or 0.9))
					i += 1
				end
			end
			m.marker(63)
		end)
		return { w = size.X, h = size.Y, winW = win.X, winH = win.Y, stepX = stepX, stepY = stepY, cols = cols, rows = rows }
	end

	-- Batch capture: jobs = { {id, scale, prep, wait} }. Returns every job's geometry at once and then walks
	-- them in order (job index in the upper marker row, tile index in the lower one; tile 63 = job done).
	function self.captureBatch(jobs: { any })
		local vp = workspace.CurrentCamera.ViewportSize
		local winW, winH = vp.X - 16, vp.Y - 64 - 8
		local stepX, stepY = math.floor(winW / 4) * 4, math.floor(winH / 4) * 4
		local geo = {}
		for j, job in jobs do
			local s = Registry.get(job.id)
			assert(s, job.id)
			local scale = job.scale or 2
			local w, h = (s.size.X + 56) * scale, (s.size.Y + 56) * scale
			geo[j] = { id = job.id, w = w, h = h, winW = winW, winH = winH, stepX = stepX, stepY = stepY, cols = math.ceil(w / stepX), rows = math.ceil(h / stepY) }
		end
		local token = {}
		self.tileToken = token
		task.spawn(function()
			for j, job in jobs do
				if self.tileToken ~= token then
					return
				end
				self.show(job.id)
				self.tiled = true
				self.setCapture(true, job.scale or 2)
				task.wait(0.4)
				local m = self.mounted
				m.marker(62, j - 1)
				for _, label in job.prep or {} do
					for _, a in m.built.actions or {} do
						if a.label == label then
							a.run()
						end
					end
					task.wait(0.25)
				end
				task.wait(job.wait or 0.5)
				Motion.paused = true
				local g = geo[j]
				local i = 0
				for r = 0, g.rows - 1 do
					for c = 0, g.cols - 1 do
						m.setTile(c * stepX, r * stepY)
						m.marker(62, j - 1)
						task.wait(0.3)
						m.marker(i, j - 1)
						task.wait(if j == 1 and i == 0 then 15 else 0.8)
						i += 1
					end
				end
				m.marker(63, j - 1)
				task.wait(0.8)
				Motion.paused = false
			end
			self.setCapture(false)
		end)
		return geo
	end

	function self.step(d: number)
		local i = table.find(Registry.list, self.current) or 1
		local n = #Registry.list
		self.show(Registry.list[(i - 1 + d + n) % n + 1].id)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.PageDown or (input.KeyCode == Enum.KeyCode.Down and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)) then
			self.step(1)
		elseif input.KeyCode == Enum.KeyCode.PageUp or (input.KeyCode == Enum.KeyCode.Up and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)) then
			self.step(-1)
		elseif input.KeyCode == Enum.KeyCode.R and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			self.reset()
		elseif input.KeyCode == Enum.KeyCode.F8 then
			self.setCapture(not self.capture)
		end
	end)

	-- live leak counter: scopes and listeners alive, instances under the stage
	task.spawn(function()
		while root.Parent do
			local n = 0
			if self.mounted then
				n = #self.mounted.canvas:GetDescendants()
			end
			leak.Text = `Scopes {Scope.liveCount()} · listeners {Signal.listenerCount()} · instances {n}`
			task.wait(0.5)
		end
	end)

	self.refreshChips()
	self.show(Registry.list[1].id)
	return self
end

return App
