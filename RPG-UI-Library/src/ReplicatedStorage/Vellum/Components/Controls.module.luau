--!strict
-- Controls: IconButton, Toggle, Checkbox / Radio, Segmented, Tabs, Slider, Dropdown and SearchBox.
-- Every control: new(scope, props) -> handle with .Instance, setters, and a `changed` callback in props.
-- All pressables go through Interact, so hover / press / focus / disabled behave the same everywhere.
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Parent.Theme)
local Atlas = require(script.Parent.Parent.Atlas)
local Create = require(script.Parent.Parent.Core.Create)
local Motion = require(script.Parent.Parent.Core.Motion)
local Interact = require(script.Parent.Parent.Core.Interact)
local Layers = require(script.Parent.Parent.Core.Layers)
local Surface = require(script.Parent.Surface)

local C = Theme.color
local M = Theme.motion
local Controls = {}

local function focusRing(parent: GuiObject, radius: number, pad: number?): Frame
	local p = pad or 4
	return Create("Frame", {
		Name = "FocusRing",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-p, -p),
		Size = UDim2.new(1, p * 2, 1, p * 2),
		Visible = false,
		ZIndex = 8,
		Parent = parent,
	}, { Create.corner(radius + p), Create.stroke(C.arcane, 2, 0) })
end

---------------------------------------------------------------- IconButton
-- Round gilt medallion with a glyph. props: icon, size, badge (number), tone ("gold" | "arcane" | "danger"), onClick
function Controls.iconButton(scope: any, props: { [string]: any })
	local size = props.size or 46
	local root = scope:add(Create("ImageButton", {
		Name = "IconButton_" .. (props.icon or ""),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = props.layoutOrder or 0,
		Image = "",
	}))
	local disc = Atlas.image("chrome", "disc", { Name = "Disc", Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.07, 0.07), ImageColor3 = C.leather2, Parent = root })
	local grad = Create.gradient({ C.leather3, C.leather1 }, 90)
	grad.Parent = disc
	local ring = Atlas.image("chrome", "medallion", { Name = "Ring", Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = root })
	local glyph = Atlas.image("glyph", props.icon or "star", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.46, 0.46),
		ImageColor3 = C.goldBright,
		ZIndex = 3,
		Parent = root,
	})
	local glow = Atlas.image("chrome", "glow", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.5, 1.5), ImageColor3 = C.goldBright, ImageTransparency = 1, ZIndex = 0, Parent = root })
	local fr = focusRing(root, size / 2, 3)
	local press = Create.scale(1)
	press.Parent = root
	local badge: TextLabel? = nil
	local badgeFrame: Frame? = nil
	if props.badge then
		badgeFrame = Create("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -2),
			Size = UDim2.fromOffset(20, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = C.bad,
			ZIndex = 9,
			Parent = root,
		}, { Create.corner(10), Create.stroke(C.void, 2, 0), Create.padding(0, 5, 0, 5) })
		badge = Surface.text({ role = "tiny", text = tostring(props.badge), color = C.goldPale, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 10, Parent = badgeFrame })
	end
	local tone = if props.tone == "arcane" then C.arcane elseif props.tone == "danger" then C.bad else C.goldBright

	local ctl = Interact.attach(root, scope, function(s)
		glyph.ImageColor3 = if s.disabled then C.textGhost elseif s.selected then C.void else tone
		disc.ImageColor3 = if s.selected then tone else Color3.new(1, 1, 1)
		grad.Enabled = not s.selected
		ring.ImageColor3 = if s.disabled then Color3.fromRGB(120, 110, 100) else Color3.new(1, 1, 1)
		Motion.tween(glow, { ImageTransparency = if s.disabled then 1 elseif s.hover or s.selected then 0.6 else 1 }, M.base)
		Motion.tween(press, { Scale = if s.pressed then 0.92 elseif s.hover and not s.disabled then 1.05 else 1 }, M.fast, nil, nil, "press")
		fr.Visible = s.focused and not s.disabled
	end, props.onClick)
	ctl:set({ disabled = props.disabled == true, selected = props.selected == true })

	return {
		Instance = root,
		controller = ctl,
		setBadge = function(_, n: number?)
			if badgeFrame and badge then
				badgeFrame.Visible = n ~= nil and n > 0
				badge.Text = tostring(n or 0)
			end
		end,
		force = function(_, p)
			ctl:force(p)
		end,
	}
end

---------------------------------------------------------------- Toggle
-- Rune switch with label. props: label, value, disabled, changed(value)
function Controls.toggle(scope: any, props: { [string]: any })
	local value = props.value == true
	local root = scope:add(Create("TextButton", {
		Name = "Toggle",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(if props.width then 0 else 1, props.width or 0, 0, 34),
		LayoutOrder = props.layoutOrder or 0,
	}))
	local label = Surface.text({ role = "body", text = props.label or "", color = C.text, Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Parent = root })
	local track = Create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(56, 26),
		BackgroundColor3 = C.void,
		Parent = root,
	}, { Create.corner(13), Create.stroke(C.goldDeep, 1.5, 0) })
	local fill = Create("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.arcaneDeep, BackgroundTransparency = 1, Parent = track }, { Create.corner(13) })
	local rune = Atlas.image("glyph", "sparkle", { Name = "Rune", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(12, 12), ImageColor3 = C.arcane, ImageTransparency = 1, ZIndex = 2, Parent = track })
	local knob = Create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = track,
	}, { Create.corner(10), Create.gradient({ C.goldPale, C.gold, C.goldDeep }, 90), Create.stroke(C.void, 1.5, 0.1) })
	local fr = focusRing(track, 13, 3)
	local handle = {} :: any
	local ctl

	local function paint(s)
		local on = value
		Motion.tween(knob, { Position = UDim2.new(0, if on then 33 else 3, 0.5, 0) }, M.base, M.ease, nil, "slide")
		Motion.tween(fill, { BackgroundTransparency = if on then 0 else 1 }, M.base)
		Motion.tween(rune, { ImageTransparency = if on and not s.disabled then 0 else 1 }, M.base)
		track:FindFirstChildOfClass("UIStroke").Color = if s.disabled then C.seam elseif on or s.hover then C.arcane else C.goldDeep
		label.TextColor3 = if s.disabled then C.textGhost else C.text
		knob.BackgroundTransparency = if s.disabled then 0.5 else 0
		fr.Visible = s.focused and not s.disabled
	end
	ctl = Interact.attach(root, scope, paint, function()
		handle:set(not value)
		if props.changed then
			props.changed(value)
		end
	end)
	ctl:set({ disabled = props.disabled == true })
	handle.Instance = root
	handle.controller = ctl
	function handle.set(_, v: boolean)
		value = v
		paint(ctl.state)
	end
	function handle.get()
		return value
	end
	return handle
end

---------------------------------------------------------------- Checkbox / Radio
-- props: label, value, radio (bool), group (shared table for radios), disabled, changed(value)
function Controls.checkbox(scope: any, props: { [string]: any })
	local value = props.value == true
	local radio = props.radio == true
	local root = scope:add(Create("TextButton", {
		Name = if radio then "Radio" else "Checkbox",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = props.layoutOrder or 0,
	}, { Create.list("x", 10, nil, Enum.VerticalAlignment.Center) }))
	local box = Create("Frame", {
		Name = "Box",
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = C.void,
		LayoutOrder = 1,
		Parent = root,
	}, { Create.corner(if radio then 11 else 4), Create.stroke(C.gold, 1.5, 0) })
	local mark: GuiObject
	if radio then
		mark = Create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.goldBright, Parent = box }, { Create.corner(5), Create.gradient({ C.goldPale, C.gold }, 90) })
	else
		mark = Atlas.image("glyph", "check", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), ImageColor3 = C.goldBright, Parent = box })
	end
	local markScale = Create.scale(value and 1 or 0)
	markScale.Parent = mark
	local label = Surface.text({ role = "body", text = props.label or "", LayoutOrder = 2, Parent = root })
	local fr = focusRing(box, 4, 3)
	local handle = {} :: any
	local ctl
	local function paint(s)
		Motion.tween(markScale, { Scale = if value then 1 else 0 }, M.base, if value then M.spring else M.ease, nil, "mark")
		local st = box:FindFirstChildOfClass("UIStroke") :: UIStroke
		st.Color = if s.disabled then C.seam elseif s.hover or s.focused then C.goldBright else C.gold
		box.BackgroundColor3 = if value and not s.disabled then C.leather3 else C.void
		label.TextColor3 = if s.disabled then C.textGhost else C.text
		fr.Visible = s.focused and not s.disabled
	end
	ctl = Interact.attach(root, scope, paint, function()
		if radio then
			if value then
				return
			end
			if props.group then
				for _, other in props.group do
					if other ~= handle then
						other:set(false)
					end
				end
			end
			handle:set(true)
		else
			handle:set(not value)
		end
		if props.changed then
			props.changed(value)
		end
	end)
	ctl:set({ disabled = props.disabled == true })
	handle.Instance = root
	handle.controller = ctl
	function handle.set(_, v: boolean)
		value = v
		paint(ctl.state)
	end
	function handle.get()
		return value
	end
	if props.group then
		table.insert(props.group, handle)
	end
	return handle
end

---------------------------------------------------------------- Segmented
-- props: options {string}, index, width, disabled {[index]=true}, changed(index, option)
function Controls.segmented(scope: any, props: { [string]: any })
	local options = props.options
	local index = props.index or 1
	local h = props.height or 36
	local root = scope:add(Create("Frame", {
		Name = "Segmented",
		Size = UDim2.fromOffset(props.width or (#options * 96), h),
		BackgroundColor3 = C.void,
		LayoutOrder = props.layoutOrder or 0,
	}, { Create.corner(6), Create.stroke(C.goldDeep, 1.5, 0) }))
	local plate = Create("Frame", {
		Name = "Plate",
		Size = UDim2.new(1 / #options, -6, 1, -6),
		Position = UDim2.new((index - 1) / #options, 3, 0, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = root,
	}, { Create.corner(4), Create.gradient({ C.goldPale, C.goldBright, C.gold }, 90), Create.stroke(C.void, 1, 0.2) })
	local row = Create.box({ Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = root }, { Create.list("x", 0) })
	local labels, ctls = {}, {}
	local handle = {} :: any
	local function paintAll()
		for i, l in labels do
			if not ctls[i] then
				continue
			end
			local s = ctls[i].state
			local dis = props.disabled and props.disabled[i]
			l.TextColor3 = if i == index then C.ink elseif dis then C.textGhost elseif s.hover or s.focused then C.goldPale else C.textSoft
		end
		Motion.tween(plate, { Position = UDim2.new((index - 1) / #options, 3, 0, 3) }, M.slow, M.ease, nil, "slide")
	end
	for i, opt in options do
		local b = Create("TextButton", { Name = "Option" .. i, Text = "", BackgroundTransparency = 1, Size = UDim2.new(1 / #options, 0, 1, 0), LayoutOrder = i, Parent = row })
		local l = Surface.text({ role = "label", text = opt, size = 14, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = b })
		local fr = Create("Frame", { Name = "Focus", BackgroundTransparency = 1, Size = UDim2.new(1, -2, 1, -2), Position = UDim2.fromOffset(1, 1), Visible = false, ZIndex = 4, Parent = b }, { Create.corner(5), Create.stroke(C.arcane, 2, 0) })
		labels[i] = l
		ctls[i] = Interact.attach(b, scope, function(s)
			fr.Visible = s.focused
			paintAll()
		end, function()
			if props.disabled and props.disabled[i] then
				return
			end
			handle:set(i)
			if props.changed then
				props.changed(i, opt)
			end
		end)
		if props.disabled and props.disabled[i] then
			ctls[i]:set({ disabled = true })
		end
	end
	handle.Instance = root
	function handle.set(_, i: number)
		index = i
		paintAll()
	end
	function handle.get()
		return index
	end
	paintAll()
	return handle
end

---------------------------------------------------------------- Tabs
-- Bookmark tabs. props: tabs { {text, icon?, badge?} }, index, changed(index), width (per tab)
function Controls.tabs(scope: any, props: { [string]: any })
	local index = props.index or 1
	local root = scope:add(Create.box({
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = props.layoutOrder or 0,
	}, { Create.list("x", props.gap or 4, nil, Enum.VerticalAlignment.Bottom) }))
	local handle = {} :: any
	local items = {}
	local function paint()
		for i, it in items do
			if not it.ctl then
				continue
			end
			local s = it.ctl.state
			local active = i == index
			it.bg.ImageColor3 = if active then C.leather3 elseif s.hover then C.leather2 else C.leather1
			Motion.tween(it.btn, { Size = UDim2.fromOffset(it.w, if active then 46 else 40) }, M.base, M.ease, nil, "grow")
			it.label.TextColor3 = if active then C.goldBright elseif s.hover or s.focused then C.text else C.textFaint
			if it.icon then
				it.icon.ImageColor3 = it.label.TextColor3
			end
			it.edge.Visible = active
			it.fr.Visible = s.focused
		end
	end
	for i, t in props.tabs do
		local w = props.width or 132
		local btn = Create("TextButton", { Name = "Tab" .. i, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(w, 40), LayoutOrder = i, Parent = root })
		local bg = Atlas.image("chrome", "tab", { Name = "Bookmark", Size = UDim2.new(1, 0, 1, 8), SliceScale = 0.5, ImageColor3 = C.leather1, Parent = btn })
		local edge = Create("Frame", { Name = "Edge", BackgroundColor3 = C.gold, BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, 2), Position = UDim2.fromOffset(4, 0), ZIndex = 3, Parent = btn })
		local row = Create.box({ Size = UDim2.new(1, 0, 1, 0), ZIndex = 2, Parent = btn }, { Create.list("x", 7, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center), Create.padding(4, 6, 0, 6) })
		local icon = if t.icon then Atlas.image("glyph", t.icon, { Size = UDim2.fromOffset(16, 16), LayoutOrder = 1, ZIndex = 3, Parent = row }) else nil
		local label = Surface.text({ role = "heading", text = t.text, size = 16, LayoutOrder = 2, ZIndex = 3, Parent = row })
		if t.badge then
			local b = Create("Frame", { Size = UDim2.fromOffset(18, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.bad, LayoutOrder = 3, ZIndex = 3, Parent = row }, { Create.corner(9), Create.padding(0, 4, 0, 4) })
			Surface.text({ role = "tiny", text = tostring(t.badge), color = C.goldPale, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 4, Parent = b })
		end
		local fr = Create("Frame", { Name = "Focus", BackgroundTransparency = 1, Size = UDim2.new(1, -4, 1, -2), Position = UDim2.fromOffset(2, 2), Visible = false, ZIndex = 5, Parent = btn }, { Create.corner(5), Create.stroke(C.arcane, 2, 0) })
		local it = { btn = btn, bg = bg, label = label, icon = icon, edge = edge, fr = fr, w = w } :: any
		items[i] = it
		it.ctl = Interact.attach(btn, scope, function()
			paint()
		end, function()
			if index ~= i then
				handle:set(i)
				if props.changed then
					props.changed(i)
				end
			end
		end)
	end
	handle.Instance = root
	function handle.set(_, i: number)
		index = i
		paint()
	end
	function handle.get()
		return index
	end
	paint()
	return handle
end

---------------------------------------------------------------- Slider
-- props: label, min, max, step, value, width, format(v) -> string, changed(v), disabled
function Controls.slider(scope: any, props: { [string]: any })
	local min, max, step = props.min or 0, props.max or 100, props.step or 1
	local value = math.clamp(props.value or min, min, max)
	local root = scope:add(Create("TextButton", {
		Name = "Slider",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(if props.width then 0 else 1, props.width or 0, 0, 52),
		LayoutOrder = props.layoutOrder or 0,
	}))
	local label = Surface.text({ role = "body", text = props.label or "", color = C.text, Parent = root })
	local readout = Surface.text({ role = "number", text = "", color = C.goldBright, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = root })
	local rail = Create.box({ Name = "Rail", Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 18), Parent = root })
	Atlas.image("chrome", "frame_bar", { Size = UDim2.fromScale(1, 1), SliceScale = 0.6, ZIndex = 3, Parent = rail })
	local well = Create("Frame", { Name = "Well", BackgroundColor3 = C.void, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), Parent = rail }, { Create.corner(3) })
	local fill = Atlas.image("chrome", "bar_fill", { Name = "Fill", SliceScale = 0.5, ImageColor3 = C.gold, Size = UDim2.fromScale(0, 1), ZIndex = 2, Parent = well })
	-- tick marks every quarter
	for q = 1, 3 do
		Create("Frame", { BackgroundColor3 = C.goldDeep, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(q / 4, 0, 1, 4), Size = UDim2.fromOffset(1, 4), Parent = rail })
	end
	local knob = Atlas.image("chrome", "gem", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(26, 26),
		ImageColor3 = C.goldBright,
		ZIndex = 5,
		Parent = rail,
	})
	local knobGlow = Atlas.image("chrome", "glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(2.2, 2.2), ImageColor3 = C.arcane, ImageTransparency = 1, ZIndex = 4, Parent = knob })
	local handle = {} :: any
	local ctl
	local dragging = false

	local function text(v: number)
		return if props.format then props.format(v) else tostring(v)
	end
	local function paint(s)
		local t = (value - min) / (max - min)
		fill.Size = UDim2.fromScale(t, 1)
		knob.Position = UDim2.fromScale(t, 0.5)
		readout.Text = text(value)
		local dis = s.disabled
		fill.ImageColor3 = if dis then C.seam else C.gold
		knob.ImageColor3 = if dis then C.textGhost elseif s.focused or dragging then C.arcane else C.goldBright
		knobGlow.ImageTransparency = if (s.focused or s.hover or dragging) and not dis then 0.55 else 1
		label.TextColor3 = if dis then C.textGhost else C.text
		readout.TextColor3 = if dis then C.textGhost else C.goldBright
	end
	local function setValue(v: number, fire: boolean)
		v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
		if v ~= value then
			value = v
			paint(ctl.state)
			if fire and props.changed then
				props.changed(value)
			end
		end
	end
	local function fromX(x: number)
		local a, w = rail.AbsolutePosition.X, rail.AbsoluteSize.X
		setValue(min + math.clamp((x - a) / w, 0, 1) * (max - min), true)
	end
	ctl = Interact.attach(root, scope, paint)
	scope:connect(root.InputBegan, function(input)
		if ctl.state.disabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	scope:connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)
	scope:connect(UserInputService.InputEnded, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			paint(ctl.state)
		end
	end)
	-- keyboard: left/right step, shift = 10 steps (when focused, arrows are taken from UI navigation)
	scope:connect(UserInputService.InputBegan, function(input)
		if GuiService.SelectedObject ~= root or ctl.state.disabled then
			return
		end
		local mult = if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then 10 else 1
		if input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.D then
			setValue(value + step * mult, true)
		elseif input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.A then
			setValue(value - step * mult, true)
		end
	end)
	-- Left/Right must adjust the value, not move UI selection
	root.NextSelectionLeft = root
	root.NextSelectionRight = root
	ctl:set({ disabled = props.disabled == true })
	handle.Instance = root
	handle.controller = ctl
	function handle.set(_, v: number)
		setValue(v, false)
	end
	function handle.get()
		return value
	end
	paint(ctl.state)
	return handle
end

---------------------------------------------------------------- Dropdown
-- props: options { {text, icon?} | string }, index, width, label (placeholder), changed(index)
function Controls.dropdown(scope: any, props: { [string]: any })
	local options = {}
	for i, o in props.options do
		options[i] = if type(o) == "string" then { text = o } else o
	end
	local index = props.index
	local width = props.width or 220
	local root = scope:add(Create("TextButton", {
		Name = "Dropdown",
		Text = "",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(width, Theme.size.control),
		LayoutOrder = props.layoutOrder or 0,
	}, { Create.corner(6), Create.gradient({ C.leather2, C.leather1 }, 90), Create.stroke(C.goldDeep, 1.5, 0) }))
	local value = Surface.text({ role = "body", text = "", Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -48, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = root })
	local chev = Atlas.image("glyph", "chevron_down", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(16, 16), ImageColor3 = C.gold, Parent = root })
	local fr = focusRing(root, 6, 3)
	local handle = {} :: any
	local menuScope: any = nil
	local open = false
	local ctl

	local function paint(s)
		local stroke = root:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = if s.disabled then C.seam elseif open or s.hover or s.focused then C.gold else C.goldDeep
		value.Text = if index then options[index].text else (props.label or "Choose…")
		value.TextColor3 = if s.disabled then C.textGhost elseif index then C.text else C.textFaint
		Motion.tween(chev, { Rotation = if open then 180 else 0 }, M.base, nil, nil, "chev")
		fr.Visible = s.focused and not open
	end

	local function close(refocus: boolean?)
		if menuScope then
			menuScope:Destroy()
			menuScope = nil
		end
		open = false
		paint(ctl.state)
		if refocus and GuiService.SelectedObject == nil then
			pcall(function()
				GuiService.SelectedObject = root
			end)
		end
	end

	local function openMenu()
		if open then
			close()
			return
		end
		open = true
		menuScope = scope:child()
		local overlay = Layers.get()
		-- click-away catcher
		local catcher = menuScope:add(Create("TextButton", { Name = "DropdownCatcher", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = Theme.z.popover, Parent = overlay }))
		menuScope:connect(catcher.Activated, function()
			close()
		end)
		local pos, size = Layers.rectOf(root)
		local itemH = 36
		local h = #options * itemH + 12
		local at = Layers.place(pos, size, Vector2.new(size.X, h), "below", 4)
		local menu = menuScope:add(Create("Frame", {
			Name = "DropdownMenu",
			Position = UDim2.fromOffset(at.X, at.Y),
			Size = UDim2.fromOffset(size.X, h),
			BackgroundColor3 = C.leather1,
			ZIndex = Theme.z.popover + 1,
			Parent = overlay,
		}, { Create.corner(6), Create.stroke(C.gold, 1.5, 0), Create.padding(6), Create.list("y", 0) }))
		local appear = Create.scale(0.96)
		appear.Parent = menu
		Motion.tween(appear, { Scale = 1 }, M.base, M.spring)
		local first: GuiObject? = nil
		for i, o in options do
			local b = Create("TextButton", { Name = "Item" .. i, Text = "", BackgroundColor3 = C.leather3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, itemH), LayoutOrder = i, ZIndex = Theme.z.popover + 2, Parent = menu }, { Create.corner(4) })
			local row = Create.box({ Size = UDim2.fromScale(1, 1), ZIndex = Theme.z.popover + 3, Parent = b }, { Create.list("x", 8, nil, Enum.VerticalAlignment.Center), Create.padding(0, 10, 0, 10) })
			if o.icon then
				Atlas.image("glyph", o.icon, { Size = UDim2.fromOffset(16, 16), ImageColor3 = C.gold, LayoutOrder = 1, ZIndex = Theme.z.popover + 3, Parent = row })
			end
			local t = Surface.text({ role = "body", text = o.text, LayoutOrder = 2, ZIndex = Theme.z.popover + 3, Parent = row })
			if i == index then
				Atlas.image("glyph", "check", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(14, 14), ImageColor3 = C.arcane, ZIndex = Theme.z.popover + 3, Parent = b })
				t.TextColor3 = C.goldBright
			end
			Interact.attach(b, menuScope, function(s)
				b.BackgroundTransparency = if s.hover or s.focused then 0 else 1
			end, function()
				index = i
				close(true)
				if props.changed then
					props.changed(i, o)
				end
			end)
			if i == (index or 1) then
				first = b
			end
		end
		-- keyboard: focus the current item; Backspace/Escape closes
		if GuiService.SelectedObject ~= nil and first then
			GuiService.SelectedObject = first
		end
		menuScope:connect(UserInputService.InputBegan, function(input)
			if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
				close(true)
			end
		end)
		paint(ctl.state)
	end

	ctl = Interact.attach(root, scope, paint, openMenu)
	ctl:set({ disabled = props.disabled == true })
	handle.Instance = root
	handle.controller = ctl
	function handle.set(_, i: number?)
		index = i
		paint(ctl.state)
	end
	function handle.get()
		return index
	end
	function handle.open()
		if not open then
			openMenu()
		end
	end
	handle.close = function()
		close()
	end
	return handle
end

---------------------------------------------------------------- SearchBox
-- props: placeholder, width, changed(text)
function Controls.search(scope: any, props: { [string]: any })
	local root = scope:add(Create("Frame", {
		Name = "Search",
		Size = UDim2.new(if props.width then 0 else 1, props.width or 0, 0, Theme.size.control),
		BackgroundColor3 = C.void,
		LayoutOrder = props.layoutOrder or 0,
	}, { Create.corner(6), Create.stroke(C.goldDeep, 1.5, 0) }))
	Atlas.image("glyph", "search", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(16, 16), ImageColor3 = C.gold, Parent = root })
	local box = Create("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -70, 1, 0),
		FontFace = Theme.font.body,
		TextSize = 15,
		TextColor3 = C.text,
		PlaceholderText = props.placeholder or "Search…",
		PlaceholderColor3 = C.textFaint,
		Text = "",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})
	local clear = Create("ImageButton", { Name = "Clear", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Image = "", Visible = false, Parent = root })
	local cg = Atlas.image("glyph", "close", { Size = UDim2.fromScale(1, 1), ImageColor3 = C.textSoft, Parent = clear })
	local stroke = root:FindFirstChildOfClass("UIStroke") :: UIStroke
	scope:connect(box.Focused, function()
		stroke.Color = C.arcane
	end)
	scope:connect(box.FocusLost, function()
		stroke.Color = C.goldDeep
	end)
	scope:connect(box:GetPropertyChangedSignal("Text"), function()
		clear.Visible = box.Text ~= ""
		if props.changed then
			props.changed(box.Text)
		end
	end)
	scope:connect(clear.MouseEnter, function()
		cg.ImageColor3 = C.goldBright
	end)
	scope:connect(clear.MouseLeave, function()
		cg.ImageColor3 = C.textSoft
	end)
	scope:connect(clear.Activated, function()
		box.Text = ""
	end)
	return {
		Instance = root,
		box = box,
		set = function(_, t: string)
			box.Text = t
		end,
		get = function()
			return box.Text
		end,
	}
end

return Controls
