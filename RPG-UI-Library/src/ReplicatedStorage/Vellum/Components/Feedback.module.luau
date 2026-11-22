--!strict
-- Feedback & overlays: Tooltip, ContextMenu, Modal, Toast, ProgressBar, Radial (ring / cooldown sweep),
-- Tag, Spinner and Currency. Overlay pieces render into Layers, so they work inside any host.
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.Theme)
local Atlas = require(script.Parent.Parent.Atlas)
local Create = require(script.Parent.Parent.Core.Create)
local Motion = require(script.Parent.Parent.Core.Motion)
local Interact = require(script.Parent.Parent.Core.Interact)
local Layers = require(script.Parent.Parent.Core.Layers)
local Surface = require(script.Parent.Surface)
local Button = require(script.Parent.Button)

local C = Theme.color
local M = Theme.motion
local Z = Theme.z
local Feedback = {}

---------------------------------------------------------------- Tooltip
-- A dark card with a thin gilt frame. props: title, body, hint, width, accent
function Feedback.tooltipCard(props: { [string]: any }): Frame
	-- root: auto height; fill inset under a thin gilt frame that sits on the bounds (no overhang)
	local card = Create.box({ Name = "Tooltip", Size = UDim2.fromOffset(props.width or 240, 0), AutomaticSize = Enum.AutomaticSize.Y })
	Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		Parent = card,
	}, { Create.corner(6), Create.gradient({ C.leather2, C.leather0 }, 90) })
	Atlas.image("chrome", "frame_thin", { Name = "Frame", Size = UDim2.fromScale(1, 1), SliceScale = 0.6, ZIndex = 3, Parent = card })
	local body = Create.box({ Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2, Parent = card }, {
		Create.padding(13, 15, 13, 15),
		Create.list("y", 6),
	})
	if props.title then
		Surface.text({ role = "heading", text = props.title, color = props.accent or C.goldBright, size = 17, LayoutOrder = 1, ZIndex = 2, Parent = body, wrap = true })
	end
	if props.body then
		Surface.text({ role = "small", text = props.body, color = C.textSoft, LayoutOrder = 2, ZIndex = 2, Parent = body, wrap = true, rich = true })
	end
	if props.hint then
		Surface.text({ role = "lore", text = props.hint, color = C.textFaint, size = 12, LayoutOrder = 3, ZIndex = 2, Parent = body, wrap = true })
	end
	return card
end

-- Attach a hover / focus tooltip to `target`. build() returns the card (built fresh on each show).
-- opts: side ("right" default), delay (s)
function Feedback.tooltip(scope: any, target: GuiObject, build: () -> GuiObject, opts: { [string]: any }?)
	local o = opts or {}
	local showing: any = nil
	local pending: thread? = nil
	local function hide()
		if pending then
			pcall(task.cancel, pending)
			pending = nil
		end
		if showing then
			showing:Destroy()
			showing = nil
		end
	end
	local function show()
		hide()
		local s = scope:child()
		showing = s
		local card = build()
		card.Visible = false
		card.ZIndex = Z.tooltip
		card.Parent = Layers.get()
		s:add(card)
		-- raise every descendant above popovers
		for _, d in card:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += Z.tooltip
			end
		end
		task.defer(function()
			if showing ~= s or not card.Parent then
				return
			end
			local pos, size = Layers.rectOf(target)
			local cs = card.AbsoluteSize / Layers.scale()
			local at = Layers.place(pos, size, cs, o.side or "right", 10)
			card.Position = UDim2.fromOffset(at.X, at.Y + 4)
			card.Visible = true
			Motion.tween(card, { Position = UDim2.fromOffset(at.X, at.Y) }, M.base)
		end)
	end
	local function queue()
		if pending then
			return
		end
		pending = task.delay(o.delay or 0.18, function()
			pending = nil
			show()
		end)
	end
	scope:connect(target.MouseEnter, queue)
	scope:connect(target.MouseLeave, hide)
	scope:connect(target.SelectionGained, queue)
	scope:connect(target.SelectionLost, hide)
	scope:defer(hide)
	return { show = show, hide = hide }
end

---------------------------------------------------------------- ContextMenu
-- items: { {text, icon?, danger?, disabled?, hint?, run?} | "-" }. at: overlay-local position.
function Feedback.contextMenu(scope: any, at: Vector2, items: { any }, title: string?)
	local s = scope:child()
	local overlay = Layers.get()
	local catcher = s:add(Create("TextButton", { Name = "MenuCatcher", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = Z.popover, Parent = overlay }))
	local w = 210
	local menu = s:add(Create("Frame", {
		Name = "ContextMenu",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(w, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = Z.popover + 1,
		Parent = overlay,
	}, { Create.corner(6), Create.gradient({ C.leather2, C.leather1 }, 90), Create.stroke(C.gold, 1.5, 0), Create.padding(6), Create.list("y", 2) }))
	local function close()
		s:Destroy()
	end
	s:connect(catcher.Activated, close)
	s:connect(catcher.MouseButton2Click, close)
	if title then
		Surface.text({ role = "caps", text = title, color = C.gold, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, ZIndex = Z.popover + 2, Parent = menu }, nil)
		local t = menu:FindFirstChildOfClass("TextLabel") :: TextLabel
		Create.padding(0, 0, 0, 8).Parent = t
	end
	local first: GuiObject? = nil
	for i, it in items do
		if it == "-" then
			Create("Frame", { BackgroundColor3 = C.seam, BorderSizePixel = 0, Size = UDim2.new(1, -12, 0, 1), LayoutOrder = i, ZIndex = Z.popover + 2, Parent = menu })
			continue
		end
		local b = Create("TextButton", { Name = "Item_" .. it.text, Text = "", BackgroundColor3 = if it.danger then C.healthDeep else C.leather3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i, ZIndex = Z.popover + 2, Parent = menu }, { Create.corner(4) })
		local row = Create.box({ Size = UDim2.fromScale(1, 1), ZIndex = Z.popover + 3, Parent = b }, { Create.list("x", 9, nil, Enum.VerticalAlignment.Center), Create.padding(0, 8, 0, 8) })
		local col = if it.disabled then C.textGhost elseif it.danger then C.bad else C.text
		local ic = Atlas.image("glyph", it.icon or "chevron_right", { Size = UDim2.fromOffset(16, 16), ImageColor3 = if it.disabled then C.textGhost elseif it.danger then C.bad else C.gold, LayoutOrder = 1, ZIndex = Z.popover + 3, Parent = row })
		local t = Surface.text({ role = "body", text = it.text, color = col, size = 14, LayoutOrder = 2, ZIndex = Z.popover + 3, Parent = row })
		if it.hint then
			Surface.text({ role = "tiny", text = it.hint, color = C.textFaint, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), ZIndex = Z.popover + 3, Parent = b })
		end
		Interact.attach(b, s, function(st)
			b.BackgroundTransparency = if not it.disabled and (st.hover or st.focused) then 0 else 1
			t.TextColor3 = if not it.disabled and (st.hover or st.focused) and not it.danger then C.goldPale else col
			local _ = ic
		end, function()
			if it.disabled then
				return
			end
			close()
			if it.run then
				it.run()
			end
		end)
		if not first and not it.disabled then
			first = b
		end
	end
	s:connect(UserInputService.InputBegan, function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
			close()
		end
	end)
	task.defer(function()
		if not menu.Parent then
			return
		end
		local size = menu.AbsoluteSize / Layers.scale()
		local area = Layers.size()
		local x = math.clamp(at.X, 4, area.X - size.X - 4)
		local y = if at.Y + size.Y > area.Y - 4 then at.Y - size.Y else at.Y
		menu.Position = UDim2.fromOffset(x, math.max(4, y))
		menu.Visible = true
		local sc = Create.scale(0.94)
		sc.Parent = menu
		Motion.tween(sc, { Scale = 1 }, M.base, M.spring)
		if GuiService.SelectedObject ~= nil and first then
			GuiService.SelectedObject = first
		end
	end)
	return { close = close, Instance = menu }
end

---------------------------------------------------------------- Modal
-- props: title, body (string), icon (item icon name), tone ("gold" | "danger" | "arcane"),
-- confirm {text, variant}, cancel {text}, onConfirm, onCancel, width, extra (builder fn(parent))
function Feedback.modal(scope: any, props: { [string]: any })
	local s = scope:child()
	local overlay = Layers.get()
	local dim = s:add(Create("TextButton", {
		Name = "ModalDim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.void,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = Z.modal,
		Parent = overlay,
	}))
	Motion.tween(dim, { BackgroundTransparency = 0.35 }, M.slow)
	local width = props.width or 420
	local panel, content = Surface.panel({ title = props.title, size = UDim2.fromOffset(width, 0), autoSize = Enum.AutomaticSize.Y, padding = 22, parent = overlay })
	panel.Name = "Modal"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	s:add(panel)
	content.Size = UDim2.new(1, 0, 0, 0)
	for _, d in panel:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += Z.modal
		end
	end
	panel.ZIndex = Z.modal + 1
	Create.list("y", 14, Enum.HorizontalAlignment.Center).Parent = content
	local appear = Create.scale(0.9)
	appear.Parent = panel
	Motion.tween(appear, { Scale = 1 }, M.slow, M.spring)

	if props.icon then
		local medal = Create.box({ Size = UDim2.fromOffset(84, 84), LayoutOrder = 1, ZIndex = Z.modal + 3, Parent = content })
		Atlas.image("chrome", "glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.6, 1.6), ImageColor3 = props.glow or C.goldBright, ImageTransparency = 0.6, ZIndex = Z.modal + 3, Parent = medal })
		Atlas.image("chrome", "disc", { Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.07, 0.07), ImageColor3 = C.leather0, ZIndex = Z.modal + 4, Parent = medal })
		Atlas.image("icon", props.icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7), ZIndex = Z.modal + 5, Parent = medal })
		Atlas.image("chrome", "medallion", { Size = UDim2.fromScale(1, 1), ZIndex = Z.modal + 6, Parent = medal })
	end
	if props.body then
		local t = Surface.text({ role = "body", text = props.body, color = C.textSoft, rich = true, wrap = true, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, ZIndex = Z.modal + 3, Parent = content })
		t.LineHeight = 1.15
	end
	if props.extra then
		local holder = Create.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, ZIndex = Z.modal + 3, Parent = content })
		props.extra(holder, s)
		for _, d in holder:GetDescendants() do
			if d:IsA("GuiObject") and d.ZIndex < Z.modal then
				d.ZIndex += Z.modal + 3
			end
		end
	end
	local actions = Create.box({ Size = UDim2.new(1, 0, 0, Theme.size.control), LayoutOrder = 4, ZIndex = Z.modal + 3, Parent = content }, { Create.list("x", 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	Surface.divider({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 14), Parent = content })

	local closed = false
	local handle = {} :: any
	local function close(confirmed: boolean)
		if closed then
			return
		end
		closed = true
		Motion.tween(appear, { Scale = 0.94 }, M.base)
		Motion.tween(dim, { BackgroundTransparency = 1 }, M.base)
		task.delay(M.base, function()
			s:Destroy()
		end)
		if confirmed and props.onConfirm then
			props.onConfirm()
		elseif not confirmed and props.onCancel then
			props.onCancel()
		end
	end
	local cancelBtn, confirmBtn
	if props.cancel ~= false then
		cancelBtn = Button.new(s, { text = (props.cancel and props.cancel.text) or "Cancel", variant = "secondary", width = 150, keyHint = "Esc", layoutOrder = 1, onClick = function()
			close(false)
		end })
		cancelBtn.Instance.Parent = actions
	end
	confirmBtn = Button.new(s, { text = (props.confirm and props.confirm.text) or "Confirm", variant = (props.confirm and props.confirm.variant) or "primary", width = 170, keyHint = "Enter", disabled = props.confirm and props.confirm.disabled, layoutOrder = 2, onClick = function()
		close(true)
	end })
	confirmBtn.Instance.Parent = actions
	for _, b in { cancelBtn, confirmBtn } do
		if b then
			for _, d in b.Instance:GetDescendants() do
				if d:IsA("GuiObject") then
					d.ZIndex += Z.modal + 3
				end
			end
			b.Instance.ZIndex += Z.modal + 3
		end
	end
	-- focus trap: keyboard focus starts on the safe choice for danger dialogs, otherwise on confirm,
	-- and can only move between the dialog's buttons
	local safe = if props.tone == "danger" and cancelBtn then cancelBtn else confirmBtn
	if cancelBtn then
		cancelBtn.Instance.NextSelectionRight = confirmBtn.Instance
		cancelBtn.Instance.NextSelectionLeft = confirmBtn.Instance
		confirmBtn.Instance.NextSelectionLeft = cancelBtn.Instance
		confirmBtn.Instance.NextSelectionRight = cancelBtn.Instance
		for _, b in { cancelBtn, confirmBtn } do
			b.Instance.NextSelectionUp = b.Instance
			b.Instance.NextSelectionDown = b.Instance
		end
	end
	if GuiService.SelectedObject ~= nil or props.focus then
		task.defer(function()
			pcall(function()
				GuiService.SelectedObject = safe.Instance
			end)
		end)
	end
	s:connect(UserInputService.InputBegan, function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
			close(false)
		end
	end)
	handle.close = close
	handle.Instance = panel
	handle.confirm = confirmBtn
	handle.cancel = cancelBtn
	return handle
end

---------------------------------------------------------------- Toast
-- Stacked notifications in the overlay's top-right. props: tone, title, text, icon (item icon) or glyph, duration
local TONES = {
	info = { color = C.info, glyph = "info" },
	success = { color = C.good, glyph = "check" },
	warning = { color = C.warn, glyph = "bell" },
	error = { color = C.bad, glyph = "close" },
	reward = { color = C.goldBright, glyph = "sparkle" },
	quest = { color = C.arcane, glyph = "quest" },
}
Feedback.TONES = TONES

function Feedback.toastCard(props: { [string]: any }): Frame
	local tone = TONES[props.tone or "info"]
	local card = Create("Frame", {
		Name = "Toast",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(props.width or 320, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { Create.corner(6), Create.gradient({ C.leather2, C.leather1 }, 90), Create.stroke(C.void, 2, 0.2) })
	Create("Frame", { Name = "Accent", BackgroundColor3 = tone.color, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, -12), Position = UDim2.fromOffset(6, 6), Parent = card }, { Create.corner(2) })
	local body = Create.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card }, { Create.padding(12, 14, 12, 64), Create.list("y", 3) })
	local badge = Create.box({ Name = "Badge", Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(18, 10), Parent = card })
	if props.icon then
		Atlas.image("chrome", "disc", { Size = UDim2.fromScale(1, 1), ImageColor3 = C.leather0, Parent = badge })
		Atlas.image("icon", props.icon, { Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.07, 0.07), ZIndex = 2, Parent = badge })
		Atlas.image("chrome", "ring_thin", { Size = UDim2.fromScale(1, 1), ImageColor3 = tone.color, ZIndex = 3, Parent = badge })
	else
		Atlas.image("chrome", "disc", { Size = UDim2.fromScale(1, 1), ImageColor3 = tone.color, ImageTransparency = 0.82, Parent = badge })
		Atlas.image("chrome", "ring_thin", { Size = UDim2.fromScale(1, 1), ImageColor3 = tone.color, ZIndex = 2, Parent = badge })
		Atlas.image("glyph", props.glyph or tone.glyph, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), ImageColor3 = tone.color, ZIndex = 3, Parent = badge })
	end
	if props.title then
		Surface.text({ role = "label", text = props.title, color = tone.color, size = 15, wrap = true, LayoutOrder = 1, Parent = body })
	end
	if props.text then
		Surface.text({ role = "small", text = props.text, color = C.textSoft, wrap = true, rich = true, LayoutOrder = 2, Parent = body })
	end
	local timer = Create("Frame", { Name = "Timer", BackgroundColor3 = tone.color, BackgroundTransparency = 0.4, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -3), Size = UDim2.new(1, -12, 0, 2), Visible = false, Parent = card })
	local _ = timer
	return card
end

local stackFrame: Frame? = nil
function Feedback.toast(scope: any, props: { [string]: any })
	local overlay = Layers.get()
	if not stackFrame or stackFrame.Parent ~= overlay then
		stackFrame = Create.box({
			Name = "ToastStack",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 16),
			Size = UDim2.fromOffset(props.width or 320, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = Z.toast,
			Parent = overlay,
		}, { Create.list("y", 10, Enum.HorizontalAlignment.Right) })
		scope:add(stackFrame)
	end
	local stack = stackFrame :: Frame
	local s = scope:child()
	-- keep at most 4: drop the oldest
	local cards = {}
	for _, c in stack:GetChildren() do
		if c:IsA("Frame") then
			table.insert(cards, c)
		end
	end
	if #cards >= 4 then
		table.sort(cards, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		cards[1]:Destroy()
	end
	local holder = s:add(Create.box({ Name = "ToastSlot", Size = UDim2.fromOffset(props.width or 320, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = os.clock() * 1000 // 1, Parent = stack }))
	local card = Feedback.toastCard(props)
	card.Position = UDim2.fromOffset(40, 0)
	card.Parent = holder
	for _, d in holder:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += Z.toast
		end
	end
	Motion.tween(card, { Position = UDim2.fromOffset(0, 0) }, M.slow, M.spring)
	local timer = card:FindFirstChild("Timer") :: Frame
	local duration = props.duration or 4
	if duration > 0 then
		timer.Visible = true
		Motion.tween(timer, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)
		s:delay(duration, function()
			Motion.tween(card, { Position = UDim2.fromOffset(60, 0) }, M.base)
			task.wait(M.base)
			s:Destroy()
		end)
	end
	return { close = function()
		s:Destroy()
	end }
end

---------------------------------------------------------------- ProgressBar
-- props: value, max, color, deep, width, height, label, showValue, segments, glyph, format(v, max)
-- set(v) animates; drops leave a pale trail that drains after a beat (damage), gains flash the edge.
function Feedback.bar(scope: any, props: { [string]: any })
	local max = props.max or 100
	local value = math.clamp(props.value or max, 0, max)
	local h = props.height or 18
	local root = scope:add(Create.box({
		Name = "Bar",
		Size = UDim2.new(if props.width then 0 else 1, props.width or 0, 0, h + (if props.label then 22 else 0)),
		LayoutOrder = props.layoutOrder or 0,
	}))
	local top = 0
	local readout: TextLabel? = nil
	if props.label then
		local lab = Create.box({ Size = UDim2.new(1, 0, 0, 18), Parent = root })
		local x = 0
		if props.glyph then
			Atlas.image("glyph", props.glyph, { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(0, 2), ImageColor3 = props.color, Parent = lab })
			x = 20
		end
		Surface.text({ role = "caps", text = props.label, color = C.textSoft, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = lab })
		readout = Surface.text({ role = "number", text = "", color = C.text, size = 13, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = lab })
		top = 22
	end
	local rail = Create.box({ Name = "Rail", Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 0, h), Parent = root })
	Atlas.image("chrome", "frame_bar", { Size = UDim2.new(1, 0, 1, 0), SliceScale = math.min(0.75, h / 30), ZIndex = 5, Parent = rail })
	local inset = math.max(3, math.floor(h * 0.2))
	local well = Create("Frame", { Name = "Well", BackgroundColor3 = props.deep or C.void, Position = UDim2.fromOffset(inset, inset), Size = UDim2.new(1, -inset * 2, 1, -inset * 2), ClipsDescendants = true, Parent = rail }, { Create.corner(2) })
	Create("Frame", { BackgroundColor3 = C.void, BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = well })
	local trail = Create("Frame", { Name = "Trail", BackgroundColor3 = C.goldPale, BackgroundTransparency = 0.25, BorderSizePixel = 0, Size = UDim2.fromScale(value / max, 1), ZIndex = 2, Parent = well }, { Create.corner(2) })
	local fill = Atlas.image("chrome", "bar_fill", { Name = "Fill", ImageColor3 = props.color or C.gold, SliceScale = 0.4, Size = UDim2.fromScale(value / max, 1), ZIndex = 3, Parent = well })
	local edge = Create("Frame", { Name = "Edge", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 6, 1, 0), ZIndex = 4, Parent = fill })
	if props.segments then
		for i = 1, props.segments - 1 do
			Create("Frame", { BackgroundColor3 = C.void, BackgroundTransparency = 0.25, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(i / props.segments, 0), Size = UDim2.new(0, 2, 1, 0), ZIndex = 4, Parent = well })
		end
	end
	local function txt(v: number)
		if readout then
			readout.Text = if props.format then props.format(v, max) else `{math.floor(v + 0.5)} / {max}`
		end
	end
	txt(value)
	local handle = {} :: any
	local cancelCount: (() -> ())? = nil
	function handle.set(_, v: number, instant: boolean?)
		v = math.clamp(v, 0, max)
		local from = value
		value = v
		local t = v / max
		if instant or Motion.reduced then
			fill.Size = UDim2.fromScale(t, 1)
			trail.Size = UDim2.fromScale(t, 1)
			txt(v)
			return
		end
		if cancelCount then
			cancelCount()
		end
		cancelCount = Motion.number(from, v, M.slow, txt)
		if v < from then
			-- damage: fill snaps, the pale trail lingers then drains
			Motion.tween(fill, { Size = UDim2.fromScale(t, 1) }, M.fast, nil, nil, "fill")
			trail.BackgroundColor3 = C.goldPale
			scope:add(task.delay(0.35, function()
				Motion.tween(trail, { Size = UDim2.fromScale(t, 1) }, 0.5, Enum.EasingStyle.Quad, nil, "trail")
			end))
		else
			-- gain: trail leads, fill catches up, the edge flashes
			trail.Size = UDim2.fromScale(t, 1)
			trail.BackgroundColor3 = props.color or C.gold
			Motion.tween(fill, { Size = UDim2.fromScale(t, 1) }, M.slow, nil, nil, "fill")
			edge.BackgroundTransparency = 0.2
			Motion.tween(edge, { BackgroundTransparency = 1 }, 0.6, nil, nil, "edge")
		end
	end
	function handle.get()
		return value
	end
	function handle.setMax(_, m: number)
		max = m
		handle:set(math.min(value, m), true)
	end
	handle.Instance = root
	return handle
end

---------------------------------------------------------------- Radial
-- Clockwise sweep from 12 o'clock built from two clipped halves of a sprite with a hard-edged
-- UIGradient. Used for progress rings (sprite "ring") and cooldown shades (sprite "disc").
function Feedback.radial(scope: any, props: { [string]: any })
	local size = props.size or 64
	local root = scope:add(Create.box({ Name = "Radial", Size = UDim2.fromOffset(size, size), LayoutOrder = props.layoutOrder or 0 }))
	local sprite = props.sprite or "ring"
	if props.track ~= false then
		Atlas.image("chrome", sprite, { Name = "Track", Size = UDim2.fromScale(1, 1), ImageColor3 = props.trackColor or C.void, ImageTransparency = props.trackTransparency or 0.3, Parent = root })
	end
	local halves = {}
	for i, side in { "Right", "Left" } do
		local clip = Create.box({ Name = side, ClipsDescendants = true, Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(if side == "Right" then 0.5 else 0, 0), ZIndex = 2, Parent = root })
		local img = Atlas.image("chrome", sprite, {
			Size = UDim2.fromScale(2, 1),
			Position = UDim2.fromScale(if side == "Right" then -1 else 0, 0),
			ImageColor3 = props.color or C.gold,
			ImageTransparency = props.transparency or 0,
			ZIndex = 2,
			Parent = clip,
		})
		local g = Create("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.5001, 1), NumberSequenceKeypoint.new(1, 1) }),
			Parent = img,
		})
		halves[i] = { clip = clip, img = img, g = g }
	end
	local value = 0
	local handle = {} :: any
	-- a = swept angle in degrees (0..360), clockwise from 12 o'clock
	local function draw(a: number)
		local right, left = halves[1], halves[2]
		right.clip.Visible = a > 0
		right.g.Rotation = math.min(a, 180)
		left.clip.Visible = a > 180
		left.g.Rotation = a
	end
	function handle.set(_, v: number)
		value = math.clamp(v, 0, 1)
		draw(value * 360)
	end
	function handle.get()
		return value
	end
	function handle.setColor(_, c: Color3)
		for _, h in halves do
			h.img.ImageColor3 = c
		end
	end
	-- Animate from the current value to v over t seconds.
	function handle.animate(_, v: number, t: number, style: Enum.EasingStyle?)
		return Motion.number(value, v, t, function(x)
			handle:set(x)
		end, style)
	end
	handle.Instance = root
	handle:set(props.value or 0)
	return handle
end

-- Progress ring with a centred label.
function Feedback.ring(scope: any, props: { [string]: any })
	local r = Feedback.radial(scope, { size = props.size or 72, color = props.color, sprite = "ring", trackColor = C.void, trackTransparency = 0.2, value = props.value, layoutOrder = props.layoutOrder })
	Atlas.image("chrome", "ring_thin", { Size = UDim2.new(1, 8, 1, 8), Position = UDim2.fromOffset(-4, -4), ImageColor3 = C.goldDeep, ZIndex = 3, Parent = r.Instance })
	local label = Surface.text({ role = "number", text = "", color = C.text, size = props.textSize or 16, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, if props.caption then 0.44 else 0.5), ZIndex = 4, Parent = r.Instance })
	if props.caption then
		Surface.text({ role = "caps", text = props.caption, color = C.textFaint, size = 9, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), ZIndex = 4, Parent = r.Instance })
	end
	local set = r.set
	function r.set(self, v: number)
		set(self, v)
		label.Text = if props.format then props.format(v) else `{math.floor(v * 100 + 0.5)}%`
	end
	r:set(props.value or 0)
	return r
end

---------------------------------------------------------------- Tag / Badge
-- props: text, color, glyph, solid
function Feedback.tag(props: { [string]: any }): Frame
	local color = props.color or C.gold
	local f = Create("Frame", {
		Name = "Tag",
		BackgroundColor3 = if props.solid then color else C.void,
		BackgroundTransparency = if props.solid then 0 else 0.35,
		Size = UDim2.fromOffset(0, props.height or 22),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = props.layoutOrder or 0,
		Parent = props.parent,
	}, { Create.corner(4), Create.stroke(color, 1, if props.solid then 1 else 0.2), Create.padding(0, 8, 0, 8), Create.list("x", 5, nil, Enum.VerticalAlignment.Center) })
	if props.glyph then
		Atlas.image("glyph", props.glyph, { Size = UDim2.fromOffset(12, 12), ImageColor3 = if props.solid then C.void else color, LayoutOrder = 1, Parent = f })
	end
	Surface.text({ role = "caps", text = props.text, color = if props.solid then C.void else color, size = props.textSize or 11, LayoutOrder = 2, Parent = f })
	return f
end

---------------------------------------------------------------- Spinner
-- props: size, color, text
function Feedback.spinner(scope: any, props: { [string]: any })
	local size = props.size or 44
	local root = scope:add(Create.box({ Name = "Spinner", Size = UDim2.fromOffset(size, size + (if props.text then 26 else 0)), LayoutOrder = props.layoutOrder or 0 }))
	local rune = Atlas.image("chrome", "spinner", { Size = UDim2.fromOffset(size, size), ImageColor3 = props.color or C.goldBright, Parent = root })
	if props.ring ~= false then
		Atlas.image("chrome", "node_round", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(size / 2, size / 2), Size = UDim2.fromOffset(size * 0.55, size * 0.55), Parent = root })
	end
	if props.text then
		Surface.text({ role = "lore", text = props.text, color = C.textSoft, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, size + 8), Parent = root })
	end
	scope:connect(RunService.RenderStepped, function(dt)
		rune.Rotation = (rune.Rotation + dt * (props.speed or 240)) % 360
	end)
	return { Instance = root }
end

---------------------------------------------------------------- Currency
-- props: amount, kind ("gold" | "gem" | "shard"), size; set(n) counts up/down with a flash
local CUR = {
	gold = { glyph = "coin", color = C.goldBright },
	gem = { glyph = "gem", color = Color3.fromHex("8FD3FF") },
	shard = { glyph = "sparkle", color = Color3.fromHex("C9A2FF") },
}
local function group(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end
Feedback.formatNumber = group

function Feedback.currency(scope: any, props: { [string]: any })
	local kind = CUR[props.kind or "gold"]
	local amount = props.amount or 0
	local size = props.size or 16
	local root = scope:add(Create.box({ Name = "Currency", Size = UDim2.fromOffset(0, size + 8), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = props.layoutOrder or 0 }, { Create.list("x", 6, nil, Enum.VerticalAlignment.Center) }))
	local icon = Atlas.image("glyph", kind.glyph, { Size = UDim2.fromOffset(size + 2, size + 2), ImageColor3 = kind.color, LayoutOrder = 1, Parent = root })
	local label = Surface.text({ role = "number", text = group(amount), color = props.color or C.text, size = size, LayoutOrder = 2, Parent = root })
	local pop = Create.scale(1)
	pop.Parent = icon
	local handle = {} :: any
	local cancel: (() -> ())? = nil
	function handle.set(_, n: number, instant: boolean?)
		local from = amount
		amount = n
		if cancel then
			cancel()
		end
		if instant then
			label.Text = group(n)
			return
		end
		label.TextColor3 = if n < from then C.bad else C.good
		cancel = Motion.number(from, n, 0.6, function(v)
			label.Text = group(v)
		end)
		Motion.pop(pop, 0.25)
		scope:add(task.delay(0.7, function()
			Motion.tween(label, { TextColor3 = props.color or C.text }, M.slow)
		end))
	end
	function handle.get()
		return amount
	end
	function handle.setInsufficient(_, v: boolean)
		label.TextColor3 = if v then C.bad else (props.color or C.text)
	end
	handle.Instance = root
	return handle
end

return Feedback
