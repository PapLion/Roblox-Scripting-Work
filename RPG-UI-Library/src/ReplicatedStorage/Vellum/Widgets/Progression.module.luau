--!strict
-- Quests & progression: QuestCard, QuestLog, QuestTracker, AchievementCard, LevelUp and the
-- quest-complete notice. Quest state is a local Store; objectives advance only through UI actions.
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.Theme)
local Atlas = require(script.Parent.Parent.Atlas)
local Create = require(script.Parent.Parent.Core.Create)
local Store = require(script.Parent.Parent.Core.Store)
local Motion = require(script.Parent.Parent.Core.Motion)
local Interact = require(script.Parent.Parent.Core.Interact)
local Layers = require(script.Parent.Parent.Core.Layers)
local Surface = require(script.Parent.Parent.Components.Surface)
local Button = require(script.Parent.Parent.Components.Button)
local Controls = require(script.Parent.Parent.Components.Controls)
local Feedback = require(script.Parent.Parent.Components.Feedback)
local Slot = require(script.Parent.Parent.Components.Slot)
local ItemCard = require(script.Parent.Parent.Components.ItemCard)
local Items = require(script.Parent.Parent.Data.Items)
local Quests = require(script.Parent.Parent.Data.Quests)

local C = Theme.color
local M = Theme.motion
local Progression = {}

local function progress(q): (number, number)
	local cur, tot = 0, 0
	for _, o in q.objectives do
		if not o.optional then
			cur += math.min(o.current, o.target)
			tot += o.target
		end
	end
	return cur, tot
end

local function isDone(q): boolean
	local cur, tot = progress(q)
	return tot > 0 and cur >= tot
end

---------------------------------------------------------------- QuestCard
-- props: quest, selected, width, onClick
function Progression.questCard(scope: any, props: { [string]: any })
	local q = props.quest
	local ty = Quests.types[q.type]
	local width = props.width or 340
	local root = scope:add(Create("TextButton", { Name = "Quest_" .. q.id, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 88), LayoutOrder = props.layoutOrder or 0 }))
	local body = Create("Frame", { Name = "Body", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = root }, { Create.corner(7), Create.gradient({ C.leather2, C.leather1 }, 90) })
	local stroke = Create.stroke(C.seam, 1.5, 0)
	stroke.Parent = body
	Create("Frame", { Name = "Stripe", BackgroundColor3 = ty.color, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 5, 1, 0), Parent = body }, { Create.corner(3) })
	local medal = Create.box({ Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(40, 40), Parent = body })
	Atlas.image("chrome", "disc", { Size = UDim2.fromScale(1, 1), ImageColor3 = C.void, Parent = medal })
	local glyph = Atlas.image("glyph", ty.glyph, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), ImageColor3 = ty.color, ZIndex = 2, Parent = medal })
	Atlas.image("chrome", "ring_thin", { Size = UDim2.fromScale(1, 1), ImageColor3 = ty.color, ImageTransparency = 0.3, ZIndex = 3, Parent = medal })
	local title = Surface.text({ role = "heading", text = q.title, size = 17, color = C.text, Position = UDim2.fromOffset(68, 12), Size = UDim2.new(1, -110, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd, Parent = body })
	local meta = Surface.text({ role = "caps", text = `{ty.name} · {q.region} · Lv {q.level}`, size = 10, color = C.textFaint, Position = UDim2.fromOffset(68, 36), Parent = body })
	local barHolder = Create.box({ Position = UDim2.fromOffset(68, 58), Size = UDim2.new(1, -130, 0, 10), Parent = body })
	local cur, tot = progress(q)
	local bar = Feedback.bar(scope, { color = ty.color, max = math.max(1, tot), value = cur, height = 10 })
	bar.Instance.Size = UDim2.fromScale(1, 1)
	bar.Instance.Parent = barHolder
	local count = Surface.text({ role = "number", text = `{cur}/{tot}`, size = 12, color = C.textSoft, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 54), Parent = body })
	-- right-top status mark
	local mark = Create.box({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(24, 24), Parent = body })
	local markIcon = Atlas.image("glyph", "pin", { Size = UDim2.fromScale(1, 1), ImageColor3 = C.arcane, Parent = mark })
	local readyGlow = Atlas.image("chrome", "glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(2.4, 2.4), ImageColor3 = C.goldBright, ImageTransparency = 1, Parent = mark })
	local lockVeil = Create("Frame", { BackgroundColor3 = C.void, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = body }, { Create.corner(7) })
	local press = Create.scale(1)
	press.Parent = root
	local selected = props.selected == true
	local ctl
	local handle = {} :: any
	local function paint(s)
		local status = q.status
		local ready = status == "ready" or (status == "active" and isDone(q))
		stroke.Color = if selected then C.gold elseif s.hover or s.focused then C.goldDeep else C.seam
		stroke.Thickness = if selected then 2 else 1.5
		body.BackgroundTransparency = 0
		markIcon.Visible = true
		if status == "locked" then
			Atlas.set(markIcon, "glyph", "lock")
			markIcon.ImageColor3 = C.textFaint
		elseif status == "complete" then
			Atlas.set(markIcon, "glyph", "check")
			markIcon.ImageColor3 = C.good
		elseif ready then
			Atlas.set(markIcon, "glyph", "quest")
			markIcon.ImageColor3 = C.goldBright
		elseif q.tracked then
			Atlas.set(markIcon, "glyph", "pin")
			markIcon.ImageColor3 = C.arcane
		else
			markIcon.Visible = false
		end
		readyGlow.ImageTransparency = if ready then 0.55 else 1
		title.TextColor3 = if status == "locked" then C.textFaint elseif status == "complete" then C.textSoft else C.text
		lockVeil.BackgroundTransparency = if status == "locked" then 0.45 elseif status == "complete" then 0.7 else 1
		glyph.ImageColor3 = if status == "locked" then C.textGhost else ty.color
		local c2, t2 = progress(q)
		count.Text = if status == "locked" then "—" elseif ready then "Turn in" else `{c2}/{t2}`
		count.TextColor3 = if ready then C.goldBright else C.textSoft
		meta.Text = `{ty.name} · {q.region} · Lv {q.level}`
		Motion.tween(press, { Scale = if s.pressed then 0.98 else 1 }, M.fast, nil, nil, "press")
	end
	ctl = Interact.attach(root, scope, paint, props.onClick)
	handle.Instance = root
	function handle.update(_, quest, sel: boolean?)
		q = quest
		selected = sel == true
		local c2, t2 = progress(q)
		bar:setMax(math.max(1, t2))
		bar:set(c2)
		paint(ctl.state)
	end
	function handle.force(_, p)
		ctl:force(p)
	end
	return handle
end

---------------------------------------------------------------- reward row (used by log and notices)
local function rewardRow(scope: any, parent: Instance, rewards, order: number, onParchment: boolean)
	local row = Create.box({ Name = "Rewards", Size = UDim2.new(1, 0, 0, 56), LayoutOrder = order, Parent = parent }, { Create.list("x", 10, nil, Enum.VerticalAlignment.Center) })
	local function chip(glyph: string, color: Color3, text: string, o: number)
		local f = Create("Frame", { BackgroundColor3 = if onParchment then C.ink else C.void, BackgroundTransparency = if onParchment then 0.88 else 0.4, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = o, Parent = row }, { Create.corner(6), Create.padding(0, 12, 0, 10), Create.list("x", 6, nil, Enum.VerticalAlignment.Center) })
		Atlas.image("glyph", glyph, { Size = UDim2.fromOffset(18, 18), ImageColor3 = color, LayoutOrder = 1, Parent = f })
		Surface.text({ role = "number", text = text, size = 15, color = if onParchment then C.ink else C.text, LayoutOrder = 2, Parent = f })
		return f
	end
	chip("star", if onParchment then Color3.fromHex("7B4FB8") else C.xp, `{Feedback.formatNumber(rewards.xp)} XP`, 1)
	chip("coin", if onParchment then C.goldDeep else C.goldBright, Feedback.formatNumber(rewards.gold), 2)
	for i, it in rewards.items do
		local item = Items.get(it.id)
		local s = Slot.new(scope, { size = 48, item = item, count = it.count, layoutOrder = 2 + i })
		s.Instance.Parent = row
		Feedback.tooltip(scope, s.Instance, function()
			return ItemCard.new(item, { count = it.count })
		end, { side = "above" })
	end
	return row
end
Progression.rewardRow = rewardRow

---------------------------------------------------------------- Quest complete notice
-- A parchment notice: the wax seal stamps down, then rewards arrive one by one.
function Progression.completeNotice(scope: any, quest, opts: { [string]: any }?)
	local o = opts or {}
	local card, content = Surface.parchment({ size = UDim2.fromOffset(o.width or 460, 0), autoSize = Enum.AutomaticSize.Y, padding = 22 })
	scope:add(card)
	Create.list("y", 10, Enum.HorizontalAlignment.Center).Parent = content
	local sealBox = Create.box({ Size = UDim2.fromOffset(96, 96), LayoutOrder = 1, Parent = content })
	local seal = Atlas.image("chrome", "seal", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = sealBox })
	Atlas.image("glyph", "check", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.4, 0.4), ImageColor3 = Color3.fromHex("F6C9C2"), ZIndex = 2, Parent = seal })
	local sealScale = Create.scale(1)
	sealScale.Parent = seal
	local head = Surface.text({ role = "hero", text = "Quest Complete", size = 40, color = C.ink, LayoutOrder = 2, Parent = content })
	local name = Surface.text({ role = "lore", text = quest.title, size = 16, color = C.inkSoft, LayoutOrder = 3, Parent = content })
	local div = Create.box({ Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 4, Parent = content })
	Create("Frame", { BackgroundColor3 = C.inkFaint, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.8, 0, 0, 1), Parent = div }, { Create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }) })
	local rewards = rewardRow(scope, content, quest.rewards, 5, true)
	rewards:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
	local cont = Button.new(scope, { text = "Continue", variant = "primary", width = 180, layoutOrder = 6, onClick = o.onContinue })
	cont.Instance.Parent = content

	local handle = { Instance = card } :: any
	function handle.play()
		if Motion.reduced then
			return
		end
		sealScale.Scale = 2.4
		seal.Rotation = -25
		seal.ImageTransparency = 1
		Motion.tween(seal, { ImageTransparency = 0, Rotation = -8 }, 0.25)
		Motion.tween(sealScale, { Scale = 1 }, 0.35, Enum.EasingStyle.Bounce)
		head.TextTransparency = 1
		name.TextTransparency = 1
		task.delay(0.25, function()
			Motion.tween(head, { TextTransparency = 0 }, 0.4)
			Motion.tween(name, { TextTransparency = 0 }, 0.4)
		end)
		local kids = {}
		for _, ch in rewards:GetChildren() do
			if ch:IsA("GuiObject") then
				table.insert(kids, ch)
			end
		end
		table.sort(kids, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i, ch in kids do
			local sc = ch:FindFirstChild("RewardPop") or Create.scale(0)
			sc.Name = "RewardPop"
			sc.Parent = ch
			sc.Scale = 0
			task.delay(0.45 + i * 0.12, function()
				Motion.tween(sc, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
			end)
		end
	end
	return handle
end

---------------------------------------------------------------- QuestLog
function Progression.questLog(scope: any, props: { [string]: any }?)
	local _ = props
	local store = Store.new({ quests = Store.copy(Quests.list), tab = 1, selected = "ashen_gate" })
	scope:add(store)
	local panel, content = Surface.panel({ title = "Quest Journal", size = UDim2.fromOffset(940, 620), padding = 18 })
	scope:add(panel)

	local left = Create.box({ Name = "List", Size = UDim2.new(0, 356, 1, 0), Parent = content })
	local tabs = Controls.tabs(scope, { tabs = { { text = "Active", icon = "quest" }, { text = "Completed", icon = "check" } }, width = 150, changed = function(i)
		store:set({ tab = i })
	end })
	tabs.Instance.Parent = left
	local scroll = Create("ScrollingFrame", {
		Name = "Scroll",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.goldDeep,
		Parent = left,
	}, { Create.corner(6), Create.padding(8, 10, 8, 8), Create.list("y", 8) })

	-- right: parchment detail
	local detail, dc = Surface.parchment({ name = "Detail", position = UDim2.fromOffset(372, 0), size = UDim2.new(1, -372, 1, 0), padding = 20, parent = content })
	local _d = detail
	local dScope: any = nil
	local cards = {}
	local listScope: any = nil

	local function setQuest(id: string, fn: (any) -> ())
		local quests = Store.copy(store:get().quests)
		for _, q in quests do
			if q.id == id then
				fn(q)
			end
		end
		store:set({ quests = quests })
	end

	local function showComplete(q)
		local overlay = Layers.get()
		local s = scope:child()
		local dim = s:add(Create("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.void, BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), ZIndex = Theme.z.modal, Parent = overlay }))
		local _dm = dim
		local notice = Progression.completeNotice(s, q, { onContinue = function()
			s:Destroy()
		end })
		notice.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
		notice.Instance.Position = UDim2.fromScale(0.5, 0.5)
		notice.Instance.Parent = overlay
		for _, d in notice.Instance:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += Theme.z.modal
			end
		end
		notice.Instance.ZIndex += Theme.z.modal
		notice.play()
	end

	local function renderDetail(q)
		if dScope then
			dScope:Destroy()
		end
		dScope = scope:child()
		local body = dScope:add(Create.box({ Size = UDim2.fromScale(1, 1), Parent = dc }, { Create.list("y", 10) }))
		local ty = Quests.types[q.type]
		local tagRow = Create.box({ Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = body }, { Create.list("x", 6, nil, Enum.VerticalAlignment.Center) })
		local tg = Feedback.tag({ text = ty.name, color = ty.color:Lerp(C.ink, 0.35), glyph = ty.glyph, layoutOrder = 1, parent = tagRow })
		tg.BackgroundColor3 = C.ink
		tg.BackgroundTransparency = 0.9
		Surface.text({ role = "caps", text = `{q.region} · recommended level {q.level}`, size = 10, color = C.inkFaint, LayoutOrder = 2, Parent = tagRow })
		Surface.text({ role = "title", text = q.title, size = 30, color = C.ink, LayoutOrder = 2, Parent = body })
		Surface.text({ role = "body", text = q.text, size = 15, color = C.inkSoft, wrap = true, LayoutOrder = 3, Parent = body }).LineHeight = 1.15
		if #q.objectives > 0 then
			local cap = Surface.text({ role = "caps", text = "Objectives", size = 11, color = Color3.fromHex("8A4A1E"), LayoutOrder = 4, Parent = body })
			Create.padding(10, 0, 0, 0).Parent = cap
			for i, o in q.objectives do
				local done = o.current >= o.target
				local row = Create.box({ Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 4 + i, Parent = body })
				local box = Create("Frame", { BackgroundColor3 = C.vellumDeep, Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(0, 3), Parent = row }, { Create.corner(3), Create.stroke(C.inkSoft, 1.5, 0) })
				if done then
					Atlas.image("glyph", "check", { Size = UDim2.fromScale(1.2, 1.2), Position = UDim2.fromScale(-0.05, -0.15), ImageColor3 = Color3.fromHex("2F6B2A"), Parent = box })
				end
				local t = Surface.text({ role = "body", text = o.text .. (if o.optional then " (optional)" else ""), size = 15, color = if done then C.inkFaint else C.ink, rich = true, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -90, 1, 0), Parent = row })
				if done then
					t.Text = `<s>{t.Text}</s>`
				end
				Surface.text({ role = "number", text = `{math.min(o.current, o.target)} / {o.target}`, size = 14, color = if done then Color3.fromHex("2F6B2A") else C.ink, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = row })
			end
		end
		Create.padding(10, 0, 0, 0).Parent = Surface.text({ role = "caps", text = "Rewards", size = 11, color = Color3.fromHex("8A4A1E"), LayoutOrder = 10, Parent = body })
		rewardRow(dScope, body, q.rewards, 11, true)
		-- actions at the bottom
		local actions = dScope:add(Create.box({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, Theme.size.control), Parent = dc }, { Create.list("x", 10, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) }))
		local ready = q.status == "ready" or (q.status == "active" and isDone(q))
		if q.status == "active" or q.status == "ready" then
			local track = Controls.toggle(dScope, { label = "Track", labelColor = C.ink, value = q.tracked, width = 130, layoutOrder = 1, changed = function(v)
				setQuest(q.id, function(x)
					x.tracked = v
				end)
			end })
			track.Instance.Parent = actions
			local spacer = Create.box({ Size = UDim2.fromOffset(0, 1), LayoutOrder = 2, Parent = actions })
			Create.flex().Parent = spacer
			local abandon = Button.new(dScope, { text = "Abandon", variant = "ink", icon = "trash", layoutOrder = 3, onClick = function()
				Feedback.modal(scope, {
					title = "Abandon quest",
					tone = "danger",
					icon = "scroll",
					body = `Abandon <b>{q.title}</b>? Progress on its objectives will be lost.`,
					confirm = { text = "Abandon", variant = "danger" },
					cancel = { text = "Keep quest" },
					onConfirm = function()
						local quests = Store.copy(store:get().quests)
						for i, x in quests do
							if x.id == q.id then
								table.remove(quests, i)
								break
							end
						end
						store:set({ quests = quests, selected = quests[1].id })
					end,
				})
			end })
			abandon.Instance.Parent = actions
			local turnIn = Button.new(dScope, { text = "Turn in", variant = "primary", icon = "check", disabled = not ready, layoutOrder = 4, onClick = function()
				setQuest(q.id, function(x)
					x.status = "complete"
					x.tracked = false
				end)
				showComplete(q)
			end })
			turnIn.Instance.Parent = actions
		elseif q.status == "locked" then
			Surface.text({ role = "lore", text = "This quest is not yet available.", color = C.inkFaint, LayoutOrder = 1, Parent = actions })
		else
			Surface.text({ role = "lore", text = "Completed. Rewards claimed.", color = Color3.fromHex("2F6B2A"), LayoutOrder = 1, Parent = actions })
		end
	end

	local function render(st, prev)
		if not prev or prev.quests ~= st.quests or prev.tab ~= st.tab then
			if listScope then
				listScope:Destroy()
			end
			listScope = scope:child()
			table.clear(cards)
			local n = 0
			for _, q in st.quests do
				local inTab = if st.tab == 1 then q.status ~= "complete" else q.status == "complete"
				if inTab then
					n += 1
					local card = Progression.questCard(listScope, { quest = q, width = 328, selected = q.id == st.selected, layoutOrder = n, onClick = function()
						store:set({ selected = q.id })
					end })
					card.Instance.Parent = scroll
					cards[q.id] = card
				end
			end
			if n == 0 then
				Surface.text({ role = "lore", text = "Nothing here yet.", color = C.textFaint, Parent = scroll }).Parent = scroll
			end
		end
		for id, card in cards do
			for _, q in st.quests do
				if q.id == id then
					card:update(q, id == st.selected)
				end
			end
		end
		for _, q in st.quests do
			if q.id == st.selected then
				renderDetail(q)
			end
		end
		tabs:set(st.tab)
	end
	scope:add(store:subscribe(render))
	render(store:get(), nil)

	return {
		Instance = panel,
		store = store,
		reset = function()
			store:reset()
		end,
		advance = function(_, id: string)
			setQuest(id, function(q)
				for _, o in q.objectives do
					if o.current < o.target then
						o.current += 1
						break
					end
				end
			end)
		end,
		select = function(_, id: string)
			store:set({ selected = id })
		end,
		showComplete = showComplete,
	}
end

---------------------------------------------------------------- QuestTracker (HUD widget)
function Progression.tracker(scope: any, props: { [string]: any }?)
	local p = props or {}
	local quests = Store.copy(p.quests or { Quests.get("ashen_gate"), Quests.get("moonpetal"), Quests.get("daily_forge") })
	local width = p.width or 330
	local root = scope:add(Create("Frame", { Name = "QuestTracker", BackgroundColor3 = C.void, BackgroundTransparency = 0.25, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y }, {
		Create.corner(8),
		Create.stroke(C.seam, 1, 0.2),
		Create.padding(14, 16, 14, 16),
		Create.list("y", 12),
		Create("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.35) }) }),
	}))
	local head = Create.box({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 0, Parent = root }, { Create.list("x", 8, nil, Enum.VerticalAlignment.Center) })
	Atlas.image("glyph", "quest", { Size = UDim2.fromOffset(16, 16), ImageColor3 = C.gold, LayoutOrder = 1, Parent = head })
	Surface.text({ role = "caps", text = "Tracked quests", size = 11, color = C.gold, LayoutOrder = 2, Parent = head })
	local blocks = {}
	local function build()
		for _, b in blocks do
			b.frame:Destroy()
		end
		table.clear(blocks)
		for i, q in quests do
			local ty = Quests.types[q.type]
			local f = Create.box({ Name = q.id, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = root }, { Create.list("y", 5) })
			local tr = Create.box({ Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, Parent = f })
			Create("Frame", { BackgroundColor3 = ty.color, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(3, 14), Parent = tr })
			local title = Surface.text({ role = "label", text = q.title, size = 15, color = ty.color:Lerp(Color3.new(1, 1, 1), 0.35), Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -10, 1, 0), Parent = tr })
			local banner = Surface.text({ role = "caps", text = "Ready to turn in", size = 10, color = C.goldBright, Position = UDim2.fromOffset(10, 0), Visible = false, LayoutOrder = 99, Parent = f })
			local lines = {}
			for j, o in q.objectives do
				local line = Create.box({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = j, Parent = f })
				local mark = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(12, 12), Parent = line }, { Create.corner(2), Create.stroke(C.textFaint, 1, 0) })
				local check = Atlas.image("glyph", "check", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(-2, -3), ImageColor3 = C.good, Visible = false, Parent = mark })
				local t = Surface.text({ role = "small", text = o.text, size = 13, color = C.textSoft, rich = true, Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -78, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = line })
				local n = Surface.text({ role = "number", text = "", size = 12, color = C.text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = line })
				local pop = Create.scale(1)
				pop.Parent = check
				lines[j] = { mark = mark, check = check, text = t, n = n, o = o, pop = pop, done = false }
			end
			blocks[i] = { frame = f, q = q, lines = lines, banner = banner, title = title }
		end
	end
	local function paint(animate: boolean)
		for _, b in blocks do
			for _, l in b.lines do
				local done = l.o.current >= l.o.target
				l.n.Text = `{math.min(l.o.current, l.o.target)}/{l.o.target}`
				l.n.TextColor3 = if done then C.good else C.text
				l.check.Visible = done
				l.mark:FindFirstChildOfClass("UIStroke").Color = if done then C.good else C.textFaint
				l.text.Text = if done then `<s>{l.o.text}</s>` else l.o.text
				l.text.TextColor3 = if done then C.textFaint else C.textSoft
				if done and not l.done and animate then
					l.pop.Scale = 1.8
					Motion.tween(l.pop, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
				end
				l.done = done
			end
			local ready = isDone(b.q)
			b.banner.Visible = ready
		end
	end
	build()
	paint(false)
	local handle = { Instance = root } :: any
	function handle.advance(_, qi: number)
		local q = quests[qi]
		for _, o in q.objectives do
			if o.current < o.target then
				o.current += 1
				break
			end
		end
		paint(true)
		if isDone(q) then
			Feedback.toast(scope, { tone = "quest", title = "Objectives complete", text = q.title, duration = 3 })
		end
	end
	function handle.reset()
		quests = Store.copy(p.quests or { Quests.get("ashen_gate"), Quests.get("moonpetal"), Quests.get("daily_forge") })
		build()
		paint(false)
	end
	return handle
end

---------------------------------------------------------------- AchievementCard
function Progression.achievement(scope: any, a, props: { [string]: any }?)
	local p = props or {}
	local unlocked = a.unlocked == true
	local width = p.width or 400
	local root = scope:add(Create("Frame", { Name = "Achievement_" .. a.id, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(width, 96), LayoutOrder = p.layoutOrder or 0 }, {
		Create.corner(8),
		Create.gradient(if unlocked then { C.leather3, C.leather1 } else { C.leather1, C.leather0 }, 90),
		Create.stroke(if unlocked then C.gold else C.seam, 1.5, 0),
	}))
	if unlocked then
		Atlas.image("chrome", "glow", { Position = UDim2.fromOffset(-30, -30), Size = UDim2.fromOffset(150, 150), ImageColor3 = C.goldBright, ImageTransparency = 0.82, Parent = root })
	end
	local medal = Create.box({ Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(72, 72), ZIndex = 2, Parent = root })
	if unlocked then
		Atlas.image("chrome", "seal", { Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = medal })
		Atlas.image("icon", a.icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.56, 0.56), ZIndex = 3, Parent = medal })
	else
		Atlas.image("chrome", "disc", { Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.07, 0.07), ImageColor3 = C.void, ZIndex = 2, Parent = medal })
		if a.hidden then
			Atlas.image("glyph", "info", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.36, 0.36), ImageColor3 = C.textGhost, ZIndex = 3, Parent = medal })
		else
			Atlas.image("icon", a.icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.56, 0.56), ImageColor3 = Color3.fromRGB(110, 100, 92), ImageTransparency = if a.locked then 0.4 else 0, ZIndex = 3, Parent = medal })
		end
		Atlas.image("chrome", "medallion", { Size = UDim2.fromScale(1, 1), ImageColor3 = Color3.fromRGB(150, 140, 130), ZIndex = 4, Parent = medal })
	end
	local x = 100
	Surface.text({ role = "heading", text = a.title, size = 18, color = if unlocked then C.goldBright elseif a.hidden then C.textFaint else C.text, Position = UDim2.fromOffset(x, 14), ZIndex = 2, Parent = root })
	Surface.text({ role = "small", text = a.text, size = 13, color = C.textSoft, Position = UDim2.fromOffset(x, 40), Size = UDim2.new(1, -x - 70, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, Parent = root })
	if a.target and not unlocked then
		local b = Feedback.bar(scope, { color = C.arcane, max = a.target, value = a.current, height = 10 })
		b.Instance.Position = UDim2.fromOffset(x, 66)
		b.Instance.Size = UDim2.new(1, -x - 172, 0, 10)
		b.Instance.Parent = root
		Surface.text({ role = "number", text = `{Feedback.formatNumber(a.current)} / {Feedback.formatNumber(a.target)}`, size = 11, color = C.textSoft, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -66, 0, 62), ZIndex = 2, Parent = root })
	elseif unlocked then
		Surface.text({ role = "caps", text = `Unlocked · {a.date}`, size = 10, color = C.good, Position = UDim2.fromOffset(x, 66), ZIndex = 2, Parent = root })
	else
		Surface.text({ role = "caps", text = if a.hidden then "Hidden" else "Locked", size = 10, color = C.textGhost, Position = UDim2.fromOffset(x, 66), ZIndex = 2, Parent = root })
	end
	-- points shield
	local pts = Create.box({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(46, 52), ZIndex = 2, Parent = root })
	Atlas.image("chrome", "crest", { Size = UDim2.fromScale(1, 1), ImageColor3 = if unlocked then C.gold else C.leather3, ZIndex = 2, Parent = pts })
	Surface.text({ role = "number", text = tostring(a.points), size = 15, color = if unlocked then C.ink else C.textFaint, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), ZIndex = 3, Parent = pts })
	return { Instance = root }
end

---------------------------------------------------------------- Level up
-- A presentation card: rotating rays, ribbon banner, the new level counting up, and staggered gains.
function Progression.levelUp(scope: any, props: { [string]: any }?)
	local p = props or {}
	local from, to = p.from or 23, p.to or 24
	local root = scope:add(Create.box({ Name = "LevelUp", Size = UDim2.fromOffset(560, 380) }))
	local rays = Atlas.image("chrome", "rays", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(420, 420), ImageColor3 = C.goldBright, ImageTransparency = 0.55, Parent = root })
	local glow = Atlas.image("chrome", "glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(300, 300), ImageColor3 = C.goldBright, ImageTransparency = 0.35, ZIndex = 2, Parent = root })
	local medal = Create.box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(150, 150), ZIndex = 3, Parent = root })
	Atlas.image("chrome", "diamond", { Size = UDim2.fromScale(1, 1), ImageColor3 = C.xpDeep, ZIndex = 3, Parent = medal })
	Atlas.image("chrome", "node_keystone", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.12, 1.12), ZIndex = 4, Parent = medal })
	local num = Surface.text({ role = "hero", text = tostring(from), size = 64, color = C.goldPale, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), ZIndex = 5, Parent = medal })
	num.TextStrokeColor3 = C.void
	num.TextStrokeTransparency = 0.4
	local medalScale = Create.scale(1)
	medalScale.Parent = medal
	local ribbon = Atlas.image("chrome", "ribbon", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(360, 80), SliceScale = 1, ZIndex = 6, Parent = root })
	Surface.text({ role = "hero", text = "Level Up", size = 38, color = C.goldPale, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -6), ZIndex = 7, Parent = ribbon })
	local ribbonScale = Create.scale(1)
	ribbonScale.Parent = ribbon
	local gains = Create.box({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.7, 4), Size = UDim2.fromOffset(460, 100), ZIndex = 6, Parent = root }, {
		Create.new("UIGridLayout", { CellSize = UDim2.fromOffset(225, 26), CellPadding = UDim2.fromOffset(10, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	local lines = {
		{ "plus", C.arcane, "+3 attribute points" },
		{ "star", C.xp, "+1 skill point" },
		{ "heart", C.health, "+45 maximum health" },
		{ "unlock", C.goldBright, "Unlocked: Falling Star II" },
	}
	local lineFrames = {}
	for i, l in lines do
		local f = Create("Frame", { BackgroundColor3 = C.void, BackgroundTransparency = 0.4, LayoutOrder = i, ZIndex = 6, Parent = gains }, { Create.corner(5), Create.padding(0, 10, 0, 10), Create.list("x", 8, nil, Enum.VerticalAlignment.Center) })
		Atlas.image("glyph", l[1], { Size = UDim2.fromOffset(14, 14), ImageColor3 = l[2], LayoutOrder = 1, ZIndex = 7, Parent = f })
		Surface.text({ role = "small", text = l[3], size = 13, color = C.text, LayoutOrder = 2, ZIndex = 7, Parent = f })
		lineFrames[i] = f
	end
	scope:connect(RunService.Heartbeat, function(dt)
		if Motion.paused then
			return
		end
		rays.Rotation = (rays.Rotation + dt * 9) % 360
	end)
	local handle = { Instance = root } :: any
	function handle.play()
		num.Text = tostring(from)
		medalScale.Scale = 0.4
		ribbonScale.Scale = 0
		rays.ImageTransparency = 1
		glow.ImageTransparency = 1
		for _, f in lineFrames do
			f.BackgroundTransparency = 1
			for _, d in f:GetDescendants() do
				if d:IsA("TextLabel") then
					d.TextTransparency = 1
				elseif d:IsA("ImageLabel") then
					d.ImageTransparency = 1
				end
			end
		end
		Motion.tween(glow, { ImageTransparency = 0.35 }, 0.5)
		Motion.tween(rays, { ImageTransparency = 0.55 }, 0.8)
		Motion.tween(medalScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Back)
		task.delay(0.45, function()
			num.Text = tostring(to)
			medalScale.Scale = 1.18
			Motion.tween(medalScale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
			Motion.tween(ribbonScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
		end)
		for i, f in lineFrames do
			task.delay(0.85 + i * 0.12, function()
				Motion.tween(f, { BackgroundTransparency = 0.4 }, 0.3)
				for _, d in f:GetDescendants() do
					if d:IsA("TextLabel") then
						Motion.tween(d, { TextTransparency = 0 }, 0.3)
					elseif d:IsA("ImageLabel") then
						Motion.tween(d, { ImageTransparency = 0 }, 0.3)
					end
				end
			end)
		end
	end
	num.Text = tostring(to)
	return handle
end

---------------------------------------------------------------- Loot reveal (reward popup)
-- items: { {id, count} }. Slots flip in one by one, rarest last with a bigger flare.
function Progression.lootReveal(scope: any, items: { any }, props: { [string]: any }?)
	local p = props or {}
	local panel, content = Surface.panel({ title = p.title or "Treasure Found", size = UDim2.fromOffset(p.width or 520, 0), autoSize = Enum.AutomaticSize.Y, padding = 20 })
	scope:add(panel)
	Create.list("y", 14, Enum.HorizontalAlignment.Center).Parent = content
	local stage = Create.box({ Size = UDim2.new(1, 0, 0, 120), LayoutOrder = 1, ClipsDescendants = false, Parent = content })
	local rays = Atlas.image("chrome", "rays", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(260, 260), ImageColor3 = C.goldBright, ImageTransparency = 0.7, Parent = stage })
	local chest = Create.box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(110, 110), ZIndex = 2, Parent = stage })
	Atlas.image("chrome", "glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.4, 1.4), ImageColor3 = C.goldBright, ImageTransparency = 0.45, ZIndex = 2, Parent = chest })
	Atlas.image("icon", "chest", { Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = chest })
	local chestScale = Create.scale(1)
	chestScale.Parent = chest
	Surface.text({ role = "lore", text = p.subtitle or "The sealed coffer gives up its contents.", color = C.textSoft, LayoutOrder = 2, Parent = content })
	local row = Create.box({ Size = UDim2.new(1, 0, 0, 92), LayoutOrder = 3, Parent = content }, { Create.list("x", 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
	local cells = {}
	for i, e in items do
		local it = Items.get(e.id)
		local cell = Create.box({ Size = UDim2.fromOffset(72, 92), LayoutOrder = i, Parent = row })
		local holder = Create.box({ Size = UDim2.fromOffset(72, 72), Parent = cell })
		local flare = Atlas.image("chrome", "glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.8, 1.8), ImageColor3 = Theme.rarityOf(it.rarity).color, ImageTransparency = 0.55, Parent = holder })
		local s = Slot.new(scope, { size = 72, item = it, count = e.count })
		s.Instance.Parent = holder
		Feedback.tooltip(scope, s.Instance, function()
			return ItemCard.new(it, { count = e.count })
		end, { side = "below" })
		local sc = Create.scale(1)
		sc.Parent = holder
		local label = Surface.text({ role = "caps", text = Theme.rarityOf(it.rarity).name, size = 9, color = Theme.rarityOf(it.rarity).color, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76), Parent = cell })
		cells[i] = { sc = sc, flare = flare, label = label, rank = Theme.rarityOf(it.rarity).rank }
	end
	local actions = Create.box({ Size = UDim2.new(1, 0, 0, Theme.size.control), LayoutOrder = 4, Parent = content }, { Create.list("x", 12, Enum.HorizontalAlignment.Center) })
	Button.new(scope, { text = "Leave", variant = "secondary", width = 140, layoutOrder = 1 }).Instance.Parent = actions
	local take = Button.new(scope, { text = "Take all", variant = "primary", icon = "bag", width = 170, keyHint = "E", layoutOrder = 2, onClick = function()
		Feedback.toast(scope, { tone = "reward", title = "Loot collected", text = `{#items} items added to your satchel.`, icon = "coin_pouch", duration = 2.5 })
	end })
	take.Instance.Parent = actions
	scope:connect(RunService.Heartbeat, function(dt)
		if Motion.paused then
			return
		end
		rays.Rotation = (rays.Rotation + dt * 12) % 360
	end)
	local handle = { Instance = panel } :: any
	function handle.play()
		chestScale.Scale = 0.6
		Motion.tween(chestScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
		for i, c in cells do
			c.sc.Scale = 0
			c.flare.ImageTransparency = 1
			c.label.TextTransparency = 1
			task.delay(0.3 + i * 0.16, function()
				Motion.tween(c.sc, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
				c.flare.ImageTransparency = if c.rank >= 4 then 0.1 else 0.35
				Motion.tween(c.flare, { ImageTransparency = 0.55 }, 0.8)
				Motion.tween(c.label, { TextTransparency = 0 }, 0.3)
			end)
		end
	end
	return handle
end

return Progression
