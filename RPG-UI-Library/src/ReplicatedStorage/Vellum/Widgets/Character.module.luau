--!strict
-- Character components: Vitals, StatusEffects, CharacterCard and the Equipment panel (paperdoll,
-- attribute allocation, derived stats). Local example state only.
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.Theme)
local Atlas = require(script.Parent.Parent.Atlas)
local Create = require(script.Parent.Parent.Core.Create)
local Store = require(script.Parent.Parent.Core.Store)
local Motion = require(script.Parent.Parent.Core.Motion)
local Surface = require(script.Parent.Parent.Components.Surface)
local Button = require(script.Parent.Parent.Components.Button)
local Controls = require(script.Parent.Parent.Components.Controls)
local Feedback = require(script.Parent.Parent.Components.Feedback)
local Slot = require(script.Parent.Parent.Components.Slot)
local ItemCard = require(script.Parent.Parent.Components.ItemCard)
local Items = require(script.Parent.Parent.Data.Items)
local CharData = require(script.Parent.Parent.Data.Character)

local C = Theme.color
local M = Theme.motion
local Character = {}

local function fmtNum(n: number): string
	return Feedback.formatNumber(n)
end

---------------------------------------------------------------- Vitals
-- props: width, health/mana/stamina {value, max}, level, xp, xpNext, onLevelUp(level)
function Character.vitals(scope: any, props: { [string]: any })
	local width = props.width or 340
	local root = scope:add(Create.box({ Name = "Vitals", Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = props.layoutOrder or 0 }, { Create.list("y", 10) }))
	local hp = Feedback.bar(scope, { label = "Health", glyph = "heart", color = C.health, deep = C.healthDeep, max = props.health and props.health.max or 640, value = props.health and props.health.value or 640, height = 20, layoutOrder = 1 })
	hp.Instance.Parent = root
	local mp = Feedback.bar(scope, { label = "Mana", glyph = "drop", color = C.mana, deep = C.manaDeep, max = props.mana and props.mana.max or 264, value = props.mana and props.mana.value or 264, height = 16, layoutOrder = 2 })
	mp.Instance.Parent = root
	local st = Feedback.bar(scope, { label = "Stamina", glyph = "bolt", color = C.stamina, deep = C.staminaDeep, max = 100, value = 100, height = 12, segments = 5, format = function(v, m)
		return `{math.floor(v / m * 100 + 0.5)}%`
	end, layoutOrder = 3 })
	st.Instance.Parent = root
	-- experience
	local level = props.level or 23
	local xp, xpNext = props.xp or 7420, props.xpNext or 9800
	local xpRow = Create.box({ Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 4, Parent = root })
	local badge = Create.box({ Size = UDim2.fromOffset(34, 34), Parent = xpRow })
	Atlas.image("chrome", "diamond", { Size = UDim2.fromScale(1, 1), ImageColor3 = C.xpDeep, Parent = badge })
	Atlas.image("chrome", "node_diamond", { Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = badge })
	local lvText = Surface.text({ role = "number", text = tostring(level), size = 13, color = C.goldPale, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3, Parent = badge })
	local badgePop = Create.scale(1)
	badgePop.Parent = badge
	local xpBar = Feedback.bar(scope, { color = C.xp, deep = C.xpDeep, max = xpNext, value = xp, height = 10 })
	xpBar.Instance.Position = UDim2.fromOffset(44, 18)
	xpBar.Instance.Size = UDim2.new(1, -44, 0, 10)
	xpBar.Instance.Parent = xpRow
	local xpText = Surface.text({ role = "caps", text = "", size = 10, color = C.textSoft, Position = UDim2.fromOffset(44, 0), Parent = xpRow })
	local function xpLabel()
		xpText.Text = `Level {level} · {fmtNum(xp)} / {fmtNum(xpNext)} XP`
	end
	xpLabel()

	local handle = {} :: any
	handle.Instance = root
	handle.bars = { health = hp, mana = mp, stamina = st }
	function handle.damage(_, n: number)
		hp:set(hp:get() - n)
	end
	function handle.heal(_, n: number)
		hp:set(hp:get() + n)
	end
	function handle.cast(_, n: number)
		mp:set(mp:get() - n)
	end
	function handle.restore()
		hp:set(640)
		mp:set(264)
		st:set(100)
	end
	function handle.sprint(_, n: number)
		st:set(st:get() - n)
	end
	function handle.gainXp(_, n: number)
		xp += n
		if xp >= xpNext then
			xpBar:set(xpNext)
			task.delay(0.45, function()
				xp -= xpNext
				level += 1
				xpNext = math.floor(xpNext * 1.12 / 10) * 10
				lvText.Text = tostring(level)
				Motion.pop(badgePop, 0.35)
				xpBar:setMax(xpNext)
				xpBar:set(0, true)
				xpBar:set(xp)
				xpLabel()
				if props.onLevelUp then
					props.onLevelUp(level)
				end
			end)
		else
			xpBar:set(xp)
		end
		xpLabel()
	end
	function handle.reset()
		level, xp, xpNext = props.level or 23, props.xp or 7420, props.xpNext or 9800
		lvText.Text = tostring(level)
		xpBar:setMax(xpNext)
		xpBar:set(xp, true)
		hp:set(640, true)
		mp:set(264, true)
		st:set(100, true)
		xpLabel()
	end
	return handle
end

---------------------------------------------------------------- StatusEffects
-- props: effects (ids from CharData.effects), size, perRow. Timers tick live; expired effects fade out.
function Character.effects(scope: any, props: { [string]: any })
	local size = props.size or 46
	local root = scope:add(Create.box({ Name = "StatusEffects", Size = UDim2.fromOffset(0, size + 22), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = props.layoutOrder or 0 }, { Create.list("x", 8) }))
	local byId = {}
	for _, e in CharData.effects do
		byId[e.id] = e
	end
	local live: { [string]: any } = {}
	local order = 0
	local function fmt(t: number)
		if t >= 60 then
			return `{math.ceil(t / 60)}m`
		end
		return `{math.ceil(t)}s`
	end
	local handle = {} :: any
	function handle.add(_, id: string, remaining: number?)
		local def = byId[id]
		if live[id] then
			live[id].left = def.duration
			live[id].stacks = math.min((live[id].stacks or 1) + 1, 9)
			live[id].stackText.Text = tostring(live[id].stacks)
			live[id].stackText.Visible = true
			Motion.pop(live[id].pop, 0.2)
			return
		end
		order += 1
		local es = scope:child()
		local cell = es:add(Create.box({ Name = "Effect_" .. id, Size = UDim2.fromOffset(size, size + 22), LayoutOrder = order, Parent = root }))
		local hit = Create("ImageButton", { BackgroundTransparency = 1, Image = "", Size = UDim2.fromOffset(size, size), Parent = cell })
		local color = if def.kind == "buff" then C.gold else C.bad
		Atlas.image("chrome", "disc", { Size = UDim2.fromScale(1, 1), ImageColor3 = C.void, Parent = hit })
		Atlas.image("icon", def.icon, { Size = UDim2.fromScale(0.84, 0.84), Position = UDim2.fromScale(0.08, 0.08), ZIndex = 2, Parent = hit })
		local shade = Feedback.radial(es, { size = size, sprite = "disc", color = C.void, transparency = 0.42, track = false })
		shade.Instance.ZIndex = 3
		for _, d in shade.Instance:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 3
			end
		end
		shade.Instance.Parent = hit
		Atlas.image("chrome", "ring_thin", { Size = UDim2.fromScale(1, 1), ImageColor3 = color, ZIndex = 4, Parent = hit })
		local pop = Create.scale(0.6)
		pop.Parent = hit
		Motion.tween(pop, { Scale = 1 }, M.slow, M.spring)
		local stackText = Surface.text({ role = "number", text = tostring(def.stacks or 1), size = 12, color = C.goldPale, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 2, 1, 2), Visible = (def.stacks or 1) > 1, ZIndex = 6, Parent = hit })
		stackText.TextStrokeTransparency = 0
		stackText.TextStrokeColor3 = C.void
		local timer = Surface.text({ role = "number", text = "", size = 11, color = if def.kind == "buff" then C.textSoft else C.bad, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, size + 4), Parent = cell })
		local entry = { def = def, left = remaining or def.duration, stacks = def.stacks or 1, shade = shade, timer = timer, stackText = stackText, pop = pop, scope = es, cell = cell }
		live[id] = entry
		Feedback.tooltip(es, hit, function()
			return Feedback.tooltipCard({
				title = def.name,
				accent = color,
				body = def.text .. (if entry.stacks > 1 then ` <font color="#F3D08A">×{entry.stacks}</font>` else ""),
				hint = `{if def.kind == "buff" then "Blessing" else "Affliction"} · {fmt(entry.left)} remaining`,
				width = 220,
			})
		end, { side = "below" })
	end
	function handle.clear()
		for id, e in live do
			e.scope:Destroy()
			live[id] = nil
		end
	end
	function handle.freeze(_, v: boolean)
		handle.frozen = v
	end
	scope:connect(RunService.Heartbeat, function(dt)
		if Motion.paused then
			return
		end
		for id, e in live do
			if not handle.frozen then
				e.left -= dt
			end
			e.shade:set(1 - math.max(0, e.left) / e.def.duration)
			e.timer.Text = fmt(math.max(0, e.left))
			if e.left <= 0 then
				live[id] = nil
				Motion.tween(e.pop, { Scale = 0 }, M.base)
				task.delay(M.base, function()
					e.scope:Destroy()
				end)
			end
		end
	end)
	for _, id in props.effects or {} do
		handle:add(id)
	end
	handle.Instance = root
	return handle
end

---------------------------------------------------------------- Crest (portrait medallion)
function Character.crest(scope: any, props: { [string]: any })
	local size = props.size or 112
	local root = scope:add(Create.box({ Name = "Crest", Size = UDim2.fromOffset(size, size), LayoutOrder = props.layoutOrder or 0 }))
	local ring = Feedback.radial(scope, { size = size, sprite = "ring", color = C.xp, trackColor = C.void, trackTransparency = 0.1, value = props.progress or 0.75 })
	ring.Instance.Parent = root
	Atlas.image("chrome", "disc", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), ImageColor3 = C.leather0, ZIndex = 3, Parent = root })
	local crest = Atlas.image("chrome", "crest", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.5, 0.56), ImageColor3 = props.color or Color3.fromHex("3B6EA8"), ZIndex = 4, Parent = root })
	Create.gradient({ Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150) }, 90).Parent = crest
	Atlas.image("icon", props.icon or "ward", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.36, 0.36), ZIndex = 5, Parent = root })
	Atlas.image("chrome", "medallion", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86), ZIndex = 6, Parent = root })
	-- level gem at the bottom
	local gem = Create.box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.94), Size = UDim2.fromOffset(38, 38), ZIndex = 7, Parent = root })
	Atlas.image("chrome", "diamond", { Size = UDim2.fromScale(1, 1), ImageColor3 = C.xpDeep, ZIndex = 7, Parent = gem })
	Atlas.image("chrome", "node_diamond", { Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = gem })
	local lv = Surface.text({ role = "number", text = tostring(props.level or 1), size = 14, color = C.goldPale, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 9, Parent = gem })
	return {
		Instance = root,
		ring = ring,
		setLevel = function(_, n: number)
			lv.Text = tostring(n)
		end,
	}
end

---------------------------------------------------------------- CharacterCard
function Character.card(scope: any, props: { [string]: any }?)
	local p = props or {}
	local ch = p.character or CharData.example()
	local panel, content = Surface.panel({ size = UDim2.fromOffset(p.width or 380, 0), autoSize = Enum.AutomaticSize.Y, padding = 16 })
	scope:add(panel)
	Create.list("y", 12).Parent = content
	local top = Create.box({ Size = UDim2.new(1, 0, 0, 118), LayoutOrder = 1, Parent = content })
	local crest = Character.crest(scope, { size = 112, level = ch.level, progress = ch.xp / ch.xpNext, icon = ch.crest })
	crest.Instance.Parent = top
	local names = Create.box({ Position = UDim2.fromOffset(128, 0), Size = UDim2.new(1, -128, 1, 0), Parent = top }, { Create.list("y", 4, nil, Enum.VerticalAlignment.Center) })
	Surface.text({ role = "title", text = ch.name, color = C.goldBright, size = 26, LayoutOrder = 1, Parent = names })
	Surface.text({ role = "lore", text = ch.title, color = C.textSoft, wrap = true, LayoutOrder = 2, Parent = names })
	local tags = Create.box({ Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 3, Parent = names }, { Create.list("x", 6, nil, Enum.VerticalAlignment.Center) })
	Feedback.tag({ text = ch.class, color = C.info, glyph = "shield_small", layoutOrder = 1, parent = tags })
	Feedback.tag({ text = `{ch.points} points`, color = C.goldBright, glyph = "plus", solid = true, layoutOrder = 2, parent = tags })
	local vit = Character.vitals(scope, { width = (p.width or 380) - 40, layoutOrder = 2, level = ch.level, xp = ch.xp, xpNext = ch.xpNext })
	vit.Instance.Parent = content
	return { Instance = panel, vitals = vit, crest = crest }
end

---------------------------------------------------------------- Equipment
local LEFT = { "head", "neck", "back", "chest", "hands" }
local RIGHT = { "waist", "feet", "ring", "mainhand", "offhand" }

function Character.equipment(scope: any, props: { [string]: any }?)
	local _ = props
	local store = Store.new({ ch = CharData.example(), selected = "mainhand", pending = { might = 0, finesse = 0, arcana = 0, vigor = 0 } })
	scope:add(store)
	local slotInfo = {}
	for _, s in Items.slots do
		slotInfo[s.id] = s
	end

	local panel, content = Surface.panel({ title = "Equipment", size = UDim2.fromOffset(880, 620), padding = 18 })
	scope:add(panel)
	-- left: paperdoll + chooser; right: attributes + stats
	local doll = Create.box({ Name = "Paperdoll", Size = UDim2.fromOffset(420, 400), Parent = content })
	local sil = Atlas.image("chrome", "silhouette", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(214, 374), ImageTransparency = 0.05, Parent = doll })
	Atlas.image("chrome", "glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(300, 300), ImageColor3 = C.gold, ImageTransparency = 0.88, ZIndex = 0, Parent = doll })
	local _s = sil
	local slots = {}
	local function place(list, x: number, anchorX: number)
		for i, sid in list do
			local info = slotInfo[sid]
			local holder = Create.box({ Name = "Slot_" .. sid, AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.new(x, 0, 0, (i - 1) * 76), Size = UDim2.fromOffset(66, 66), Parent = doll })
			local s = Slot.new(scope, { size = 66, emptyGlyph = info.glyph, label = info.name, onClick = function()
				store:set({ selected = sid })
			end })
			s.Instance.Parent = holder
			slots[sid] = s
			Feedback.tooltip(scope, s.Instance, function()
				local id = store:get().ch.equipped[sid]
				if id then
					return ItemCard.new(Items.get(id), { equipped = true, width = 260 })
				end
				return Feedback.tooltipCard({ title = info.name, body = "Empty slot. Choose an item below.", width = 200 })
			end, { side = if anchorX == 0 then "left" else "right" })
		end
	end
	place(LEFT, 0, 0)
	place(RIGHT, 1, 1)

	-- chooser strip under the paperdoll
	local chooser = Create.box({ Name = "Chooser", Position = UDim2.fromOffset(0, 412), Size = UDim2.fromOffset(420, 152), Parent = content })
	local well = Surface.well({ Size = UDim2.fromScale(1, 1), Parent = chooser })
	local _w = well
	local chooserTitle = Surface.text({ role = "caps", text = "", color = C.gold, Position = UDim2.fromOffset(14, 12), Parent = chooser })
	local candRow = Create.box({ Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 0, 60), Parent = chooser }, { Create.list("x", 8, nil, Enum.VerticalAlignment.Center) })
	local chooserHint = Surface.text({ role = "lore", text = "", color = C.textFaint, size = 12, Position = UDim2.fromOffset(14, 112), Size = UDim2.new(1, -150, 0, 28), wrap = false, Parent = chooser })
	local unequip = Button.new(scope, { text = "Unequip", variant = "ghost", size = "small", icon = "close", onClick = function()
		local st = store:get()
		local id = st.ch.equipped[st.selected]
		if not id then
			return
		end
		local ch = Store.copy(st.ch)
		ch.equipped[st.selected] = nil
		table.insert(ch.stash, 1, id)
		store:set({ ch = ch })
	end })
	unequip.Instance.AnchorPoint = Vector2.new(1, 0)
	unequip.Instance.Position = UDim2.new(1, -12, 0, 108)
	unequip.Instance.Parent = chooser
	local candScope: any = nil

	-- right column
	local right = Create.box({ Name = "Sheet", Position = UDim2.fromOffset(446, 0), Size = UDim2.new(1, -446, 1, 0), Parent = content }, { Create.list("y", 10) })
	local head = Create.box({ Size = UDim2.new(1, 0, 0, 58), LayoutOrder = 1, Parent = right })
	local ch0 = store:get().ch
	Surface.text({ role = "title", text = ch0.name, color = C.goldBright, size = 24, Parent = head })
	Surface.text({ role = "lore", text = `Level {ch0.level} {ch0.class} · {ch0.title}`, color = C.textSoft, Position = UDim2.fromOffset(0, 32), Parent = head })
	local attrCap = Surface.caption("Attributes", { LayoutOrder = 2, Parent = right })
	local _a = attrCap
	local pointsTag = Create.box({ Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 3, Parent = right })
	local pointsText = Surface.text({ role = "small", text = "", color = C.textSoft, rich = true, Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Parent = pointsTag })
	local attrRows = {}
	for i, a in CharData.attributeInfo do
		local row = Create.box({ Name = "Attr_" .. a.id, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 3 + i, Parent = right })
		Create("Frame", { BackgroundColor3 = C.void, BackgroundTransparency = 0.6, Size = UDim2.fromScale(1, 1), Parent = row }, { Create.corner(5) })
		Atlas.image("glyph", a.glyph, { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(10, 9), ImageColor3 = C.gold, Parent = row })
		local name = Surface.text({ role = "label", text = a.name, size = 15, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(0, 120, 1, 0), Parent = row })
		local val = Surface.text({ role = "number", text = "", size = 17, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -86, 0.5, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		local minus = Controls.iconButton(scope, { icon = "minus", size = 30, onClick = function()
			local st = store:get()
			if st.pending[a.id] > 0 then
				local pnd = table.clone(st.pending)
				pnd[a.id] -= 1
				store:set({ pending = pnd })
			end
		end })
		minus.Instance.AnchorPoint = Vector2.new(1, 0.5)
		minus.Instance.Position = UDim2.new(1, -42, 0.5, 0)
		minus.Instance.Parent = row
		local plus = Controls.iconButton(scope, { icon = "plus", size = 30, tone = "arcane", onClick = function()
			local st = store:get()
			local spent = 0
			for _, v in st.pending do
				spent += v
			end
			if spent < st.ch.points then
				local pnd = table.clone(st.pending)
				pnd[a.id] += 1
				store:set({ pending = pnd })
			else
				Motion.shake(row)
			end
		end })
		plus.Instance.AnchorPoint = Vector2.new(1, 0.5)
		plus.Instance.Position = UDim2.new(1, -6, 0.5, 0)
		plus.Instance.Parent = row
		Feedback.tooltip(scope, row, function()
			return Feedback.tooltipCard({ title = a.name, body = a.text, width = 220 })
		end, { side = "left" })
		attrRows[a.id] = { val = val, minus = minus, plus = plus, name = name }
	end
	local applyRow = Create.box({ Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 9, Parent = right }, { Create.list("x", 10, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	local undo = Button.new(scope, { text = "Undo", variant = "ghost", size = "small", layoutOrder = 1, onClick = function()
		store:set({ pending = { might = 0, finesse = 0, arcana = 0, vigor = 0 } })
	end })
	undo.Instance.Parent = applyRow
	local apply = Button.new(scope, { text = "Commit points", variant = "primary", size = "small", icon = "check", layoutOrder = 2, onClick = function()
		local st = store:get()
		local ch = Store.copy(st.ch)
		local spent = 0
		for k, v in st.pending do
			ch.attributes[k] += v
			spent += v
		end
		ch.points -= spent
		store:set({ ch = ch, pending = { might = 0, finesse = 0, arcana = 0, vigor = 0 } })
		Feedback.toast(scope, { tone = "success", title = "Attributes committed", text = `{spent} point{if spent == 1 then "" else "s"} spent.`, duration = 3 })
	end })
	apply.Instance.Parent = applyRow

	Surface.caption("Derived", { LayoutOrder = 10, Parent = right })
	local statsGrid = Create.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 11, Parent = right }, {
		Create.new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 30), CellPadding = UDim2.fromOffset(12, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local statRows = {}
	for i, d in CharData.derivedOrder do
		local row = Create.box({ Name = "Stat_" .. d.id, LayoutOrder = i, Parent = statsGrid })
		Atlas.image("glyph", d.glyph, { Size = UDim2.fromOffset(15, 15), Position = UDim2.fromOffset(0, 8), ImageColor3 = C.textFaint, Parent = row })
		Surface.text({ role = "small", text = d.name, color = C.textSoft, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = row })
		local v = Surface.text({ role = "number", text = "", size = 15, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = row })
		Create("Frame", { BackgroundColor3 = C.seam, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), Parent = row })
		statRows[d.id] = { label = v, def = d, last = nil :: number? }
	end

	local function preview(st)
		local ch = Store.copy(st.ch)
		for k, v in st.pending do
			ch.attributes[k] += v
		end
		return ch
	end

	local function renderChooser(st)
		if candScope then
			candScope:Destroy()
		end
		candScope = scope:child()
		local sid = st.selected
		local info = slotInfo[sid]
		chooserTitle.Text = `{info.name} — choose an item`
		local current = st.ch.equipped[sid]
		local n = 0
		for _, id in st.ch.stash do
			local it = Items.get(id)
			if it.slot == sid then
				n += 1
				local s = Slot.new(candScope, { size = 56, item = it, layoutOrder = n, onClick = function()
					local s2 = store:get()
					local ch = Store.copy(s2.ch)
					local prev = ch.equipped[sid]
					ch.equipped[sid] = id
					local idx = table.find(ch.stash, id)
					if idx then
						table.remove(ch.stash, idx)
					end
					if prev then
						table.insert(ch.stash, 1, prev)
					end
					store:set({ ch = ch })
					slots[sid]:pop()
				end })
				s.Instance.Parent = candRow
				Feedback.tooltip(candScope, s.Instance, function()
					return ItemCard.new(it, { compare = current and Items.get(current) or nil, width = 270 })
				end, { side = "above" })
			end
		end
		chooserHint.Text = if n == 0 then "Nothing in the satchel fits this slot." else "Hover to compare · click to equip"
		unequip:setDisabled(current == nil)
	end

	local function render(st, prev)
		for sid, s in slots do
			local id = st.ch.equipped[sid]
			s:setItem(if id then Items.get(id) else nil)
			s:set({ selected = st.selected == sid })
		end
		if not prev or prev.selected ~= st.selected or prev.ch ~= st.ch then
			renderChooser(st)
		end
		local spent = 0
		for _, v in st.pending do
			spent += v
		end
		local left = st.ch.points - spent
		pointsText.Text = if left > 0 then `<font color="#57D1C4"><b>{left}</b></font> unspent point{if left == 1 then "" else "s"}` elseif st.ch.points > 0 then "All points assigned — commit to keep them" else "No unspent points"
		for k, r in attrRows do
			local base = st.ch.attributes[k]
			local p = st.pending[k]
			r.val.Text = if p > 0 then `{base} <font color="#57D1C4">+{p}</font>` else tostring(base)
			r.val.RichText = true
			r.minus.controller:set({ disabled = p == 0 })
			r.plus.controller:set({ disabled = left == 0 })
		end
		undo:setDisabled(spent == 0)
		apply:setDisabled(spent == 0)
		local d = CharData.derive(preview(st))
		for id, r in statRows do
			local v = d[id]
			local txt = function(x: number)
				r.label.Text = if r.def.pct then string.format("%.1f%%", x) else fmtNum(x)
			end
			if r.last ~= nil and r.last ~= v then
				local up = v > r.last
				r.label.TextColor3 = if up then C.good else C.bad
				Motion.number(r.last, v, 0.5, txt)
				task.delay(0.9, function()
					Motion.tween(r.label, { TextColor3 = C.text }, M.slow)
				end)
			else
				txt(v)
			end
			r.last = v
		end
	end
	scope:add(store:subscribe(render))
	render(store:get(), nil)

	return {
		Instance = panel,
		store = store,
		slots = slots,
		reset = function()
			store:reset()
		end,
		equip = function(_, sid: string, id: string)
			store:set({ selected = sid })
			local st = store:get()
			local ch = Store.copy(st.ch)
			local prev = ch.equipped[sid]
			ch.equipped[sid] = id
			local idx = table.find(ch.stash, id)
			if idx then
				table.remove(ch.stash, idx)
			end
			if prev then
				table.insert(ch.stash, 1, prev)
			end
			store:set({ ch = ch })
		end,
	}
end

return Character
