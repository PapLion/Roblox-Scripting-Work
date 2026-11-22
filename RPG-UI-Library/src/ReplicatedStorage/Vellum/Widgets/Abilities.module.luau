--!strict
-- Abilities: an action bar (keybinds 1–8, cooldown sweeps with countdown, global cooldown, mana cost and
-- out-of-mana state, toggled abilities, locked slot, ready flash) and ability cards. Activating an ability
-- only drives the UI: it spends local mana and starts the cooldown display. No ability is executed.
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.Theme)
local Atlas = require(script.Parent.Parent.Atlas)
local Create = require(script.Parent.Parent.Core.Create)
local Motion = require(script.Parent.Parent.Core.Motion)
local Interact = require(script.Parent.Parent.Core.Interact)
local Surface = require(script.Parent.Parent.Components.Surface)
local Feedback = require(script.Parent.Parent.Components.Feedback)
local Skills = require(script.Parent.Parent.Data.Skills)

local C = Theme.color
local M = Theme.motion
local Abilities = {}

local KEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8,
}
local GCD = 0.9

---------------------------------------------------------------- Ability card
function Abilities.card(ab: any, opts: { [string]: any }?): Frame
	local o = opts or {}
	local panel, content = Surface.panel({ size = UDim2.fromOffset(o.width or 300, 0), autoSize = Enum.AutomaticSize.Y, padding = 14, frameScale = 0.5 })
	Create.list("y", 10).Parent = content
	local head = Create.box({ Size = UDim2.new(1, 0, 0, 72), LayoutOrder = 1, Parent = content })
	local medal = Create.box({ Size = UDim2.fromOffset(72, 72), Parent = head })
	Atlas.image("chrome", "glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.5, 1.5), ImageColor3 = if ab.ultimate then C.warn else C.arcane, ImageTransparency = if ab.locked then 1 else 0.65, Parent = medal })
	Atlas.image("chrome", "diamond", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86), ImageColor3 = C.leather0, ZIndex = 2, Parent = medal })
	Atlas.image("icon", ab.icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.56, 0.56), ImageColor3 = if ab.locked then Color3.fromRGB(110, 100, 92) else Color3.new(1, 1, 1), ZIndex = 3, Parent = medal })
	Atlas.image("chrome", "node_diamond", { Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = medal })
	if ab.locked then
		Atlas.image("glyph", "lock", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.3), ImageColor3 = C.textSoft, ZIndex = 5, Parent = medal })
	end
	local names = Create.box({ Position = UDim2.fromOffset(84, 0), Size = UDim2.new(1, -84, 1, 0), Parent = head }, { Create.list("y", 4, nil, Enum.VerticalAlignment.Center) })
	Surface.text({ role = "heading", text = ab.name, size = 20, color = if ab.locked then C.textFaint else C.goldBright, LayoutOrder = 1, Parent = names })
	local tags = Create.box({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 2, Parent = names }, { Create.list("x", 5, nil, Enum.VerticalAlignment.Center) })
	Feedback.tag({ text = ab.school, color = C.info, height = 18, textSize = 9, layoutOrder = 1, parent = tags })
	if ab.ultimate then
		Feedback.tag({ text = "Ultimate", color = C.warn, glyph = "crown", height = 18, textSize = 9, layoutOrder = 2, parent = tags })
	end
	if ab.toggle then
		Feedback.tag({ text = "Toggle", color = C.arcane, height = 18, textSize = 9, layoutOrder = 3, parent = tags })
	end
	local pips = Create.box({ Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 3, Parent = names }, { Create.list("x", 4, nil, Enum.VerticalAlignment.Center) })
	for i = 1, ab.maxRank do
		Atlas.image("chrome", "pip", { Size = UDim2.fromOffset(11, 11), ImageColor3 = if i <= ab.rank then Color3.new(1, 1, 1) else Color3.fromRGB(70, 60, 50), LayoutOrder = i, Parent = pips })
	end
	-- meta grid
	local meta = Create.box({ Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 2, Parent = content }, {
		Create.new("UIGridLayout", { CellSize = UDim2.new(0.25, -4, 1, 0), CellPadding = UDim2.fromOffset(5, 0) }),
	})
	for i, m in { { "drop", "Cost", if ab.cost > 0 then `{ab.cost}` else "—" }, { "hourglass", "Cooldown", if ab.cooldown > 0 then `{ab.cooldown}s` else "—" }, { "bolt", "Cast", ab.cast }, { "compass", "Range", ab.range } } do
		local cell = Create("Frame", { BackgroundColor3 = C.void, BackgroundTransparency = 0.5, LayoutOrder = i, Parent = meta }, { Create.corner(5) })
		Atlas.image("glyph", m[1], { Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(7, 7), ImageColor3 = C.gold, Parent = cell })
		Surface.text({ role = "caps", text = m[2], size = 8, color = C.textFaint, Position = UDim2.fromOffset(22, 6), Parent = cell })
		Surface.text({ role = "number", text = m[3], size = 13, color = C.text, Position = UDim2.fromOffset(7, 22), Parent = cell })
	end
	Surface.text({ role = "body", text = ab.text, size = 14, color = if ab.locked then C.textFaint else C.textSoft, wrap = true, LayoutOrder = 3, Parent = content })
	return panel
end

---------------------------------------------------------------- Action bar
-- props: abilities (list), mana, manaMax, slot
function Abilities.bar(scope: any, props: { [string]: any }?)
	local p = props or {}
	local list = p.abilities or Skills.abilities
	local slotSize = p.slot or 64
	local gap = 10
	local width = #list * slotSize + (#list - 1) * gap + 40
	local panel, content = Surface.panel({ size = UDim2.fromOffset(width, 0), autoSize = Enum.AutomaticSize.Y, padding = 12, tone = "deep", frameScale = 0.5 })
	scope:add(panel)
	Create.list("y", 10).Parent = content
	local manaMax = p.manaMax or 300
	local mana = p.mana or 260
	local manaBar = Feedback.bar(scope, { label = "Mana", glyph = "drop", color = C.mana, deep = C.manaDeep, max = manaMax, value = mana, height = 12, layoutOrder = 1 })
	manaBar.Instance.Parent = content
	local row = Create.box({ Name = "Slots", Size = UDim2.new(1, 0, 0, slotSize + 18), LayoutOrder = 2, Parent = content }, { Create.list("x", gap) })

	local slots = {}
	local gcdUntil = 0
	local handle = {} :: any

	local function trigger(i: number)
		local s = slots[i]
		if not s then
			return
		end
		local ab = s.ab
		if ab.locked then
			Motion.shake(s.root)
			return
		end
		local now = os.clock()
		if ab.toggle then
			s.toggled = not s.toggled
			Motion.pop(s.pop, 0.12)
			return
		end
		if now < s.readyAt or now < gcdUntil then
			Motion.shake(s.root)
			return
		end
		if mana < ab.cost then
			Motion.shake(s.root)
			Feedback.toast(scope, { tone = "error", title = "Not enough mana", text = `{ab.name} needs {ab.cost} mana.`, duration = 2.2 })
			return
		end
		mana -= ab.cost
		manaBar:set(mana)
		s.readyAt = now + ab.cooldown
		s.cdStart = now
		gcdUntil = now + GCD
		s.flash.ImageTransparency = 0.2
		Motion.tween(s.flash, { ImageTransparency = 1 }, 0.4)
		Motion.pop(s.pop, -0.08)
	end

	for i, ab in list do
		local cell = Create.box({ Name = "Ability_" .. ab.id, Size = UDim2.fromOffset(slotSize, slotSize + 18), LayoutOrder = i, Parent = row })
		local btn = Create("ImageButton", { BackgroundTransparency = 1, Image = "", Size = UDim2.fromOffset(slotSize, slotSize), Parent = cell })
		local well = Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), Parent = btn }, { Create.corner(7), Create.gradient({ C.leather1, C.void }, 90) })
		local _w = well
		local icon = Atlas.image("icon", ab.icon, { Size = UDim2.fromScale(0.82, 0.82), Position = UDim2.fromScale(0.09, 0.09), ZIndex = 2, Parent = btn })
		local cd = Feedback.radial(scope, { size = slotSize - 8, sprite = "disc", color = C.void, transparency = 0.3, track = false })
		cd.Instance.Position = UDim2.fromOffset(4, 4)
		for _, d in cd.Instance:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 3
			end
		end
		cd.Instance.ZIndex = 3
		cd.Instance.Parent = btn
		local gcdShade = Create("Frame", { BackgroundColor3 = C.void, BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 3, Parent = btn }, { Create.corner(6) })
		local frame = Atlas.image("chrome", "frame_slot", { Size = UDim2.fromScale(1, 1), SliceScale = 0.42, ImageColor3 = if ab.ultimate then C.warn else C.gold, ZIndex = 4, Parent = btn })
		local flash = Atlas.image("chrome", "glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.5, 1.5), ImageColor3 = C.goldPale, ImageTransparency = 1, ZIndex = 6, Parent = btn })
		local cdText = Surface.text({ role = "number", text = "", size = 20, color = C.text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 7, Parent = btn })
		cdText.TextStrokeTransparency = 0.2
		local key = Create("Frame", { BackgroundColor3 = C.void, Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(18, 18), ZIndex = 7, Parent = btn }, { Create.corner(4), Create.stroke(C.goldDeep, 1, 0) })
		Surface.text({ role = "tiny", text = ab.key, size = 11, color = C.goldPale, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = key })
		local lock = Atlas.image("glyph", "lock", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.34, 0.34), ImageColor3 = C.textSoft, Visible = ab.locked == true, ZIndex = 7, Parent = btn })
		local _l = lock
		local toggleRing = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 4, 1, 4), Position = UDim2.fromOffset(-2, -2), Visible = false, ZIndex = 5, Parent = btn }, { Create.corner(9), Create.stroke(C.arcane, 2.5, 0) })
		local costText = Surface.text({ role = "number", text = if ab.cost > 0 then tostring(ab.cost) else "", size = 11, color = Color3.fromHex("8FB8F2"), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, slotSize + 2), Parent = cell })
		local pop = Create.scale(1)
		pop.Parent = btn
		local s = { ab = ab, root = cell, btn = btn, icon = icon, cd = cd, gcd = gcdShade, frame = frame, flash = flash, cdText = cdText, toggleRing = toggleRing, costText = costText, pop = pop, readyAt = 0, cdStart = 0, toggled = false, wasCooling = false, hover = false }
		slots[i] = s
		Interact.attach(btn, scope, function(st)
			s.hover = st.hover or st.focused
			Motion.tween(pop, { Scale = if st.pressed then 0.93 elseif st.hover then 1.04 else 1 }, M.fast, nil, nil, "press")
		end, function()
			trigger(i)
		end)
		Feedback.tooltip(scope, btn, function()
			return Abilities.card(ab, { width = 300 })
		end, { side = "above" })
	end

	scope:connect(UserInputService.InputBegan, function(input, processed)
		if processed then
			return
		end
		local i = KEYS[input.KeyCode]
		if i then
			trigger(i)
		end
	end)

	-- per-frame visuals; mana regenerates slowly so the out-of-mana state is recoverable
	scope:connect(RunService.Heartbeat, function(dt)
		if handle.frozen then
			return
		end
		local now = os.clock()
		for _, s in slots do
			if s.ab.toggle and s.toggled then
				mana = math.max(0, mana - 4 * dt)
				if mana <= 0 then
					s.toggled = false
				end
			end
		end
		mana = math.min(manaMax, mana + 6 * dt)
		manaBar:set(mana, true)
		local gcdLeft = math.max(0, gcdUntil - now)
		for _, s in slots do
			local ab = s.ab
			local left = s.readyAt - now
			local cooling = left > 0
			if cooling then
				s.cd:set(1 - left / ab.cooldown)
				s.cdText.Text = if left >= 1 then tostring(math.ceil(left)) else string.format("%.1f", left)
			else
				s.cd:set(0)
				s.cdText.Text = ""
				if s.wasCooling then
					-- ready flash
					s.flash.ImageColor3 = C.arcane
					s.flash.ImageTransparency = 0.25
					Motion.tween(s.flash, { ImageTransparency = 1 }, 0.5)
				end
			end
			s.wasCooling = cooling
			s.gcd.BackgroundTransparency = if not cooling and gcdLeft > 0 and not ab.toggle and not ab.locked then 0.55 else 1
			local short = ab.cost > mana and not ab.locked
			s.icon.ImageColor3 = if ab.locked then Color3.fromRGB(90, 84, 78) elseif short then Color3.fromRGB(120, 140, 200) else Color3.new(1, 1, 1)
			s.costText.TextColor3 = if short then C.bad else Color3.fromHex("8FB8F2")
			s.toggleRing.Visible = s.toggled
			s.frame.ImageColor3 = if s.toggled then C.arcane elseif ab.locked then C.seam elseif ab.ultimate then C.warn else C.gold
		end
	end)

	handle.Instance = panel
	handle.trigger = function(_, i: number)
		trigger(i)
	end
	handle.setMana = function(_, v: number)
		mana = v
		manaBar:set(v, true)
	end
	handle.reset = function()
		mana = p.mana or 260
		gcdUntil = 0
		for _, s in slots do
			s.readyAt = 0
			s.toggled = false
		end
		manaBar:set(mana, true)
	end
	-- show a frozen cooldown at a given fraction (for state boards)
	handle.freezeAt = function(_, i: number, remaining: number)
		local s = slots[i]
		s.readyAt = os.clock() + remaining
	end
	handle.freeze = function(_, v: boolean)
		handle.frozen = v
	end
	return handle
end

return Abilities
