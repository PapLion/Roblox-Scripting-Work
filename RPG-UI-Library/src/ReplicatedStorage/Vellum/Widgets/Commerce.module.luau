--!strict
-- Crafting & commerce: the crafting station (recipes, material requirements, quantity, timed progress)
-- and a vendor (buy / sell, stock, discounts, purchase confirmation with balance preview). Gold, stock and
-- materials are local example state: no economy, no backend, no real purchases.
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.Theme)
local Atlas = require(script.Parent.Parent.Atlas)
local Create = require(script.Parent.Parent.Core.Create)
local Store = require(script.Parent.Parent.Core.Store)
local Motion = require(script.Parent.Parent.Core.Motion)
local Interact = require(script.Parent.Parent.Core.Interact)
local Surface = require(script.Parent.Parent.Components.Surface)
local Button = require(script.Parent.Parent.Components.Button)
local Controls = require(script.Parent.Parent.Components.Controls)
local Feedback = require(script.Parent.Parent.Components.Feedback)
local Slot = require(script.Parent.Parent.Components.Slot)
local ItemCard = require(script.Parent.Parent.Components.ItemCard)
local Items = require(script.Parent.Parent.Data.Items)
local Recipes = require(script.Parent.Parent.Data.Recipes)

local C = Theme.color
local M = Theme.motion
local Commerce = {}
local fmt = Feedback.formatNumber

---------------------------------------------------------------- crafting rules (pure)
function Commerce.maxCraftable(stock, recipe): number
	local n = math.huge
	for _, m in recipe.materials do
		n = math.min(n, math.floor((stock[m.id] or 0) / m.need))
	end
	return if n == math.huge then 0 else n
end

function Commerce.missing(stock, recipe, qty: number)
	local out = {}
	for _, m in recipe.materials do
		local short = m.need * qty - (stock[m.id] or 0)
		if short > 0 then
			table.insert(out, { id = m.id, short = short })
		end
	end
	return out
end

---------------------------------------------------------------- Crafting station
function Commerce.crafting(scope: any, props: { [string]: any }?)
	local _ = props
	local store = Store.new({ stock = table.clone(Recipes.stock), category = 1, selected = "r_dawnsteel", qty = 1, crafting = nil :: any, crafted = {} })
	scope:add(store)
	local panel, content = Surface.panel({ title = "Forge & Workbench", size = UDim2.fromOffset(900, 580), padding = 18 })
	scope:add(panel)

	-- left: categories + recipe list
	local left = Create.box({ Size = UDim2.new(0, 330, 1, 0), Parent = content })
	local seg = Controls.segmented(scope, { options = Recipes.categories, index = 1, width = 330, changed = function(i)
		local first
		for _, r in Recipes.list do
			if r.category == Recipes.categories[i] then
				first = first or r.id
			end
		end
		store:set({ category = i, selected = first, qty = 1 })
	end })
	seg.Instance.Parent = left
	local list = Create("ScrollingFrame", {
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.goldDeep,
		Parent = left,
	}, { Create.corner(6), Create.padding(8), Create.list("y", 6) })

	-- right: detail
	local right = Create.box({ Position = UDim2.fromOffset(348, 0), Size = UDim2.new(1, -348, 1, 0), Parent = content })
	local rScope: any = nil
	local listScope: any = nil

	local function recipe(id: string)
		for _, r in Recipes.list do
			if r.id == id then
				return r
			end
		end
		error(id)
	end

	local function renderList(st)
		if listScope then
			listScope:Destroy()
		end
		listScope = scope:child()
		local n = 0
		for _, r in Recipes.list do
			if r.category ~= Recipes.categories[st.category] then
				continue
			end
			n += 1
			local it = Items.get(r.result)
			local can = Commerce.maxCraftable(st.stock, r)
			local row = listScope:add(Create("TextButton", { Name = r.id, Text = "", BackgroundColor3 = C.leather2, Size = UDim2.new(1, 0, 0, 58), LayoutOrder = n, Parent = list }, { Create.corner(6) }))
			local stroke = Create.stroke(C.seam, 1.5, 0)
			stroke.Parent = row
			local s = Slot.new(listScope, { size = 46, item = it, count = r.count })
			s.Instance.Position = UDim2.fromOffset(6, 6)
			s.Instance.Parent = row
			s.Instance.Active = false
			s.Instance.Interactable = false
			Surface.text({ role = "label", text = it.name, size = 15, color = Theme.rarityOf(it.rarity).color:Lerp(Color3.new(1, 1, 1), 0.25), Position = UDim2.fromOffset(62, 9), Parent = row })
			Surface.text({ role = "small", text = if can > 0 then `Can craft {can}` else "Missing materials", size = 12, color = if can > 0 then C.good else C.bad, Position = UDim2.fromOffset(62, 32), Parent = row })
			Surface.text({ role = "caps", text = `Lv {r.level}`, size = 10, color = C.textFaint, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Parent = row })
			Interact.attach(row, listScope, function(state)
				local sel = st.selected == r.id
				row.BackgroundColor3 = if sel then C.leather3 elseif state.hover then C.leather2:Lerp(C.leather3, 0.5) else C.leather2
				stroke.Color = if sel then C.gold elseif state.focused then C.arcane else C.seam
			end, function()
				if store:get().crafting then
					return
				end
				store:set({ selected = r.id, qty = 1 })
			end)
		end
	end

	local function renderDetail(st)
		if rScope then
			rScope:Destroy()
		end
		rScope = scope:child()
		local r = recipe(st.selected)
		local it = Items.get(r.result)
		local can = Commerce.maxCraftable(st.stock, r)
		local body = rScope:add(Create.box({ Size = UDim2.fromScale(1, 1), Parent = right }))
		-- preview: big slot + name + stats summary
		local head = Create.box({ Size = UDim2.new(1, 0, 0, 104), Parent = body })
		local big = Slot.new(rScope, { size = 96, item = it, count = r.count * st.qty })
		big.Instance.Parent = head
		Feedback.tooltip(rScope, big.Instance, function()
			return ItemCard.new(it, { count = r.count })
		end, { side = "below" })
		local names = Create.box({ Position = UDim2.fromOffset(112, 0), Size = UDim2.new(1, -112, 1, 0), Parent = head }, { Create.list("y", 4, nil, Enum.VerticalAlignment.Center) })
		local rar = Theme.rarityOf(it.rarity)
		Surface.text({ role = "title", text = it.name, size = 24, color = rar.color:Lerp(Color3.new(1, 1, 1), 0.2), LayoutOrder = 1, Parent = names })
		Surface.text({ role = "small", text = `{rar.name} {it.type} · {Recipes.categories[st.category]} · {r.time}s`, color = C.textSoft, LayoutOrder = 2, Parent = names })
		if it.stats then
			local parts = {}
			for _, k in Items.statOrder do
				if it.stats[k] then
					table.insert(parts, Items.formatStat(k, it.stats[k]))
				end
			end
			Surface.text({ role = "small", text = table.concat(parts, "  ·  "), color = C.text, size = 13, wrap = true, LayoutOrder = 3, Parent = names })
		elseif it.effect then
			Surface.text({ role = "small", text = it.effect, color = C.arcane, size = 13, wrap = true, LayoutOrder = 3, Parent = names })
		end
		Surface.caption("Materials", { Position = UDim2.fromOffset(0, 118), Parent = body })
		local mats = Create.box({ Position = UDim2.fromOffset(0, 144), Size = UDim2.new(1, 0, 0, 200), Parent = body }, { Create.list("y", 6) })
		for i, m in r.materials do
			local mi = Items.get(m.id)
			local have = st.stock[m.id] or 0
			local need = m.need * st.qty
			local ok = have >= need
			local row = Create("Frame", { BackgroundColor3 = C.void, BackgroundTransparency = 0.55, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = i, Parent = mats }, { Create.corner(6) })
			if not ok then
				Create.stroke(C.bad, 1, 0.5).Parent = row
			end
			local s = Slot.new(rScope, { size = 44, item = mi })
			s.Instance.Position = UDim2.fromOffset(4, 4)
			s.Instance.Parent = row
			Feedback.tooltip(rScope, s.Instance, function()
				return ItemCard.new(mi, { count = have })
			end, { side = "left" })
			Surface.text({ role = "label", text = mi.name, size = 15, Position = UDim2.fromOffset(60, 7), Parent = row })
			Surface.text({ role = "small", text = if ok then "In your satchel" else `Missing {need - have}`, size = 12, color = if ok then C.textFaint else C.bad, Position = UDim2.fromOffset(60, 29), Parent = row })
			Surface.text({ role = "number", text = `{have} / {need}`, size = 17, color = if ok then C.good else C.bad, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Parent = row })
		end
		-- footer: quantity + craft
		local foot = Create.box({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 96), Parent = body })
		local qtyRow = Create.box({ Size = UDim2.new(1, 0, 0, 40), Parent = foot }, { Create.list("x", 8, nil, Enum.VerticalAlignment.Center) })
		Surface.text({ role = "caps", text = "Quantity", size = 11, color = C.gold, LayoutOrder = 1, Parent = qtyRow })
		local minus = Controls.iconButton(rScope, { icon = "minus", size = 34, layoutOrder = 2, disabled = st.qty <= 1 or st.crafting ~= nil, onClick = function()
			store:set({ qty = math.max(1, store:get().qty - 1) })
		end })
		minus.Instance.Parent = qtyRow
		local qbox = Create("Frame", { BackgroundColor3 = C.void, Size = UDim2.fromOffset(52, 34), LayoutOrder = 3, Parent = qtyRow }, { Create.corner(5), Create.stroke(C.goldDeep, 1, 0) })
		Surface.text({ role = "number", text = tostring(st.qty), size = 17, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = qbox })
		local plus = Controls.iconButton(rScope, { icon = "plus", size = 34, layoutOrder = 4, disabled = st.qty >= math.max(1, can) or st.crafting ~= nil, onClick = function()
			store:set({ qty = store:get().qty + 1 })
		end })
		plus.Instance.Parent = qtyRow
		Surface.text({ role = "small", text = `max {can}`, size = 12, color = C.textFaint, LayoutOrder = 5, Parent = qtyRow })
		local missing = Commerce.missing(st.stock, r, st.qty)
		local progressHolder = Create.box({ Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, -196, 0, 44), Parent = foot })
		if st.crafting then
			local bar = Feedback.bar(rScope, { label = `Crafting {st.crafting.done + 1} of {st.qty}…`, glyph = "hammer", color = C.warn, max = 1, value = 0, height = 14, format = function(v)
				return `{math.floor(v * 100)}%`
			end })
			bar.Instance.Parent = progressHolder
			rScope:connect(RunService.Heartbeat, function()
				if Motion.paused then
					return
				end
				local cr = store:get().crafting
				if cr then
					bar:set(math.clamp((os.clock() - cr.started) / r.time, 0, 1), true)
				end
			end)
		elseif #missing > 0 then
			local parts = {}
			for _, mm in missing do
				table.insert(parts, `{mm.short} {Items.get(mm.id).name}`)
			end
			Surface.text({ role = "small", text = "Missing: " .. table.concat(parts, ", "), color = C.bad, wrap = true, Parent = progressHolder })
		else
			Surface.text({ role = "lore", text = `Uses {#r.materials} materials · takes {r.time * st.qty}s`, color = C.textFaint, Position = UDim2.fromOffset(0, 12), Parent = progressHolder })
		end
		local btn = Button.new(rScope, {
			text = if st.crafting then "Cancel" else "Craft",
			variant = if st.crafting then "secondary" else "primary",
			icon = if st.crafting then "close" else "hammer",
			width = 180,
			size = "large",
			disabled = st.crafting == nil and #missing > 0,
			onClick = function()
				local cur = store:get()
				if cur.crafting then
					store:set({ crafting = Store.NONE })
					Feedback.toast(scope, { tone = "warning", title = "Crafting cancelled", text = "Materials for unfinished items were kept.", duration = 2.5 })
				else
					store:set({ crafting = { started = os.clock(), done = 0, id = r.id } })
				end
			end,
		})
		btn.Instance.AnchorPoint = Vector2.new(1, 1)
		btn.Instance.Position = UDim2.fromScale(1, 1)
		btn.Instance.Parent = foot
	end

	local function render(st, prev)
		if not prev or prev.category ~= st.category or prev.stock ~= st.stock or prev.selected ~= st.selected then
			renderList(st)
		end
		renderDetail(st)
		seg:set(st.category)
	end
	scope:add(store:subscribe(render))
	render(store:get(), nil)

	-- crafting clock: one item per recipe.time, materials consumed per item
	scope:connect(RunService.Heartbeat, function()
		if Motion.paused then
			return
		end
		local st = store:get()
		local cr = st.crafting
		if not cr then
			return
		end
		local r = recipe(cr.id)
		if os.clock() - cr.started >= r.time then
			local stock = table.clone(st.stock)
			for _, m in r.materials do
				stock[m.id] -= m.need
			end
			local done = cr.done + 1
			local it = Items.get(r.result)
			local nextCr = if done < st.qty and Commerce.maxCraftable(stock, r) > 0 then { started = os.clock(), done = done, id = r.id } else nil
			store:set({ stock = stock, crafting = nextCr or Store.NONE, qty = if nextCr then st.qty else 1 })
			Feedback.toast(scope, { tone = "reward", title = `Crafted {it.name}`, text = `×{r.count} added to your satchel.`, icon = it.icon, duration = 2.6 })
		end
	end)

	return {
		Instance = panel,
		store = store,
		reset = function()
			store:reset()
		end,
		select = function(_, id: string, qty: number?)
			store:set({ selected = id, qty = qty or 1 })
		end,
		craft = function()
			local st = store:get()
			if not st.crafting and #Commerce.missing(st.stock, recipe(st.selected), st.qty) == 0 then
				store:set({ crafting = { started = os.clock(), done = 0, id = st.selected } })
			end
		end,
	}
end

---------------------------------------------------------------- Vendor item card
function Commerce.vendorCard(scope: any, entry, props: { [string]: any })
	local it = Items.get(entry.id)
	local rar = Theme.rarityOf(it.rarity)
	local price = if entry.discount then math.floor(entry.price * (100 - entry.discount) / 100) else entry.price
	local root = scope:add(Create("TextButton", { Name = "Vendor_" .. entry.id, Text = "", BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = props.layoutOrder or 0 }, { Create.corner(7), Create.gradient({ C.leather2, C.leather1 }, 90) }))
	local stroke = Create.stroke(C.seam, 1.5, 0)
	stroke.Parent = root
	local s = Slot.new(scope, { size = 60, item = it })
	s.Instance.Position = UDim2.fromOffset(10, 10)
	s.Instance.Interactable = false
	s.Instance.Parent = root
	Surface.text({ role = "label", text = it.name, size = 14, color = rar.color:Lerp(Color3.new(1, 1, 1), 0.25), Position = UDim2.fromOffset(80, 12), Size = UDim2.new(1, -88, 0, 36), wrap = false, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = root })
	Surface.text({ role = "caps", text = it.type, size = 9, color = C.textFaint, Position = UDim2.fromOffset(80, 50), Parent = root })
	local priceRow = Create.box({ Position = UDim2.new(0, 10, 1, -32), Size = UDim2.new(1, -20, 0, 24), Parent = root }, { Create.list("x", 5, nil, Enum.VerticalAlignment.Center) })
	Atlas.image("glyph", "coin", { Size = UDim2.fromOffset(15, 15), ImageColor3 = C.goldBright, LayoutOrder = 1, Parent = priceRow })
	local priceText = Surface.text({ role = "number", text = fmt(price), size = 15, color = C.goldBright, LayoutOrder = 2, Parent = priceRow })
	if entry.discount then
		local old = Surface.text({ role = "small", text = `<s>{fmt(entry.price)}</s>`, rich = true, size = 12, color = C.textFaint, LayoutOrder = 3, Parent = priceRow })
		local _o = old
	end
	local stockText = Surface.text({ role = "caps", text = "", size = 9, color = C.textFaint, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, if entry.discount then -64 else -10, 1, -20), Parent = root })
	local tag: Frame? = nil
	if entry.discount then
		tag = Feedback.tag({ text = `−{entry.discount}%`, color = C.good, solid = true, height = 18, textSize = 10, parent = root })
		tag.AnchorPoint = Vector2.new(1, 1)
		tag.Position = UDim2.new(1, -10, 1, -10)
		tag.ZIndex = 5
	end
	local veil = Create("Frame", { BackgroundColor3 = C.void, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = root }, { Create.corner(7) })
	local soldOut = Surface.text({ role = "heading", text = "Sold out", size = 18, color = C.textSoft, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = -8, Visible = false, ZIndex = 7, Parent = root })
	local press = Create.scale(1)
	press.Parent = root
	local gold = 0
	local stock = entry.stock
	local ctl
	local function paint(st)
		local out = stock == 0
		local poor = price > gold
		priceText.TextColor3 = if poor then C.bad else C.goldBright
		stroke.Color = if out then C.seam elseif st.hover or st.focused then C.gold else C.seam
		veil.BackgroundTransparency = if out then 0.35 else 1
		soldOut.Visible = out
		stockText.Text = if stock == nil then "" elseif out then "" else `{stock} left`
		Motion.tween(press, { Scale = if st.pressed and not out then 0.97 elseif st.hover and not out then 1.02 else 1 }, M.fast, nil, nil, "press")
	end
	ctl = Interact.attach(root, scope, paint, function()
		if stock ~= 0 and props.onClick then
			props.onClick(entry, price)
		end
	end)
	Feedback.tooltip(scope, root, function()
		return ItemCard.new(it, { price = price })
	end, { side = "right", delay = 0.35 })
	return {
		Instance = root,
		price = price,
		update = function(_, g: number, st: number?)
			gold = g
			stock = st
			paint(ctl.state)
		end,
		force = function(_, p)
			ctl:force(p)
		end,
	}
end

---------------------------------------------------------------- Vendor
function Commerce.vendor(scope: any, props: { [string]: any }?)
	local _ = props
	local function initial()
		local stock = {}
		for _, e in Recipes.vendor.items do
			stock[e.id] = e.stock
		end
		return {
			gold = 1840,
			mode = 1,
			stock = stock,
			bag = { { id = "woodcutter_axe", count = 1 }, { id = "traveler_gloves", count = 1 }, { id = "iron_ore", count = 40 }, { id = "glowcap", count = 14 }, { id = "warden_mace", count = 1 }, { id = "emberstone", count = 4 } },
		}
	end
	local store = Store.new(initial())
	scope:add(store)
	local panel, content = Surface.panel({ title = Recipes.vendor.name, size = UDim2.fromOffset(820, 500), padding = 18 })
	scope:add(panel)
	local top = Create.box({ Size = UDim2.new(1, 0, 0, 40), Parent = content })
	local seg = Controls.segmented(scope, { options = { "Buy", "Sell" }, index = 1, width = 220, changed = function(i)
		store:set({ mode = i })
	end })
	seg.Instance.Parent = top
	Surface.text({ role = "lore", text = Recipes.vendor.subtitle, color = C.textFaint, Position = UDim2.fromOffset(236, 10), Parent = top })
	local wallet = Create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(190, 40), BackgroundColor3 = C.void, BackgroundTransparency = 0.4, Parent = top }, { Create.corner(8), Create.list("x", 16, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local gold = Feedback.currency(scope, { amount = store:get().gold, kind = "gold", size = 17, layoutOrder = 1 })
	gold.Instance.Parent = wallet
	Feedback.currency(scope, { amount = 36, kind = "gem", size = 17, layoutOrder = 2 }).Instance.Parent = wallet

	local grid = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.goldDeep,
		Parent = content,
	}, {
		Create.padding(10, 6, 6, 6),
		Create.new("UIGridLayout", { CellSize = UDim2.fromOffset(240, 112), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local gScope: any = nil
	local cards = {}

	local function buy(entry, price)
		local st = store:get()
		local it = Items.get(entry.id)
		local maxQty = math.max(1, math.min(if entry.stock then st.stock[entry.id] else 20, math.max(1, math.floor(st.gold / price))))
		local qty = 1
		local after: TextLabel? = nil
		local totalText: TextLabel? = nil
		local m
		local function refresh()
			local total = price * qty
			local left = st.gold - total
			if totalText then
				totalText.Text = fmt(total)
			end
			if after then
				after.Text = fmt(left)
				after.TextColor3 = if left < 0 then C.bad else C.text
			end
			if m then
				m.confirm:setDisabled(left < 0)
				m.confirm:setText(if left < 0 then "Not enough gold" else `Buy for {fmt(total)}`)
			end
		end
		m = Feedback.modal(scope, {
			title = "Purchase",
			icon = it.icon,
			glow = Theme.rarityOf(it.rarity).color,
			body = `Buy <b>{it.name}</b> from {Recipes.vendor.name}?`,
			width = 440,
			confirm = { text = "Buy", variant = "primary" },
			extra = function(holder, s)
				Create.list("y", 8).Parent = holder
				if it.stack and maxQty > 1 then
					local sl = Controls.slider(s, { label = "Quantity", min = 1, max = maxQty, value = 1, layoutOrder = 1, changed = function(v)
						qty = v
						refresh()
					end })
					sl.Instance.Parent = holder
				end
				local function line(o: number, label: string, glyph: boolean): TextLabel
					local r = Create.box({ Size = UDim2.new(1, 0, 0, 24), LayoutOrder = o, Parent = holder })
					Surface.text({ role = "small", text = label, color = C.textSoft, Position = UDim2.fromOffset(0, 3), Parent = r })
					local right = Create.box({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Parent = r }, { Create.list("x", 5, nil, Enum.VerticalAlignment.Center) })
					if glyph then
						Atlas.image("glyph", "coin", { Size = UDim2.fromOffset(14, 14), ImageColor3 = C.goldBright, LayoutOrder = 1, Parent = right })
					end
					return Surface.text({ role = "number", text = "", size = 15, LayoutOrder = 2, Parent = right })
				end
				line(2, "Balance", true).Text = fmt(st.gold)
				totalText = line(3, "Total", true)
				Create("Frame", { BackgroundColor3 = C.seam, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 4, Parent = holder })
				after = line(5, "After purchase", true)
			end,
			onConfirm = function()
				local cur = store:get()
				local total = price * qty
				if cur.gold < total then
					return
				end
				local stock = table.clone(cur.stock)
				if stock[entry.id] then
					stock[entry.id] -= qty
				end
				local bag = Store.copy(cur.bag)
				table.insert(bag, 1, { id = entry.id, count = qty })
				store:set({ gold = cur.gold - total, stock = stock, bag = bag })
				Feedback.toast(scope, { tone = "reward", title = "Purchased", text = `{it.name}{if qty > 1 then ` ×{qty}` else ""} for {fmt(total)} gold.`, icon = it.icon, duration = 3 })
			end,
		})
		refresh()
		return m
	end

	local function sell(index: number)
		local st = store:get()
		local e = st.bag[index]
		local it = Items.get(e.id)
		local value = math.max(1, math.floor(it.value * 0.5)) * e.count
		Feedback.modal(scope, {
			title = "Sell item",
			icon = it.icon,
			glow = Theme.rarityOf(it.rarity).color,
			body = `Sell <b>{it.name}</b>{if e.count > 1 then ` ×{e.count}` else ""} for <font color="#F3D08A"><b>{fmt(value)}</b></font> gold?`,
			confirm = { text = "Sell", variant = "primary" },
			onConfirm = function()
				local cur = store:get()
				local bag = Store.copy(cur.bag)
				table.remove(bag, index)
				store:set({ gold = cur.gold + value, bag = bag })
			end,
		})
	end

	local function render(st, prev)
		if prev and prev.gold ~= st.gold then
			gold:set(st.gold)
		end
		seg:set(st.mode)
		if prev and prev.mode == st.mode and prev.bag == st.bag then
			for id, c in cards do
				c:update(st.gold, st.stock[id])
			end
			return
		end
		if gScope then
			gScope:Destroy()
		end
		gScope = scope:child()
		table.clear(cards)
		if st.mode == 1 then
			for i, e in Recipes.vendor.items do
				local c = Commerce.vendorCard(gScope, e, { layoutOrder = i, onClick = buy })
				c.Instance.Parent = grid
				c:update(st.gold, st.stock[e.id])
				cards[e.id] = c
			end
		else
			for i, e in st.bag do
				local it = Items.get(e.id)
				local entry = { id = e.id, price = math.max(1, math.floor(it.value * 0.5)) * e.count }
				local c = Commerce.vendorCard(gScope, entry, { layoutOrder = i, onClick = function()
					sell(i)
				end })
				c.Instance.Parent = grid
				c:update(math.huge, nil)
			end
		end
	end
	scope:add(store:subscribe(render))
	render(store:get(), nil)

	return {
		Instance = panel,
		store = store,
		cards = cards,
		buy = function(_, id: string)
			for _, e in Recipes.vendor.items do
				if e.id == id then
					local price = if e.discount then math.floor(e.price * (100 - e.discount) / 100) else e.price
					return buy(e, price)
				end
			end
			return nil
		end,
		reset = function()
			local init = initial()
			store:set(init)
			gold:set(init.gold, true)
		end,
	}
end

return Commerce
