-- Arsenal: catalogue with filters, weapon sheet on the range card, stats, comparison, finishes and the
-- three loadout slots. Equipping updates the lobby stand, the loadout strip and the match HUD (same store).
-- Item states: equipped, selected (in this list), available (owned), locked (level), not owned (shop).

local PivotUI = script.Parent.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local Catalog = require(PivotUI.Data.Catalog)
local WeaponView = require(PivotUI.WeaponView)
local Icons = require(PivotUI.Icons)
local Theme = require(PivotUI.Theme)

local C, F = UI.C, UI.F
local Armory = {}

local function itemState(item)
	if Store.isEquipped(item.id) then
		return "equipped"
	elseif Store.owns(item.id) then
		return "owned"
	elseif Store.isLocked(item) then
		return "locked"
	end
	return "shop"
end

-- Stat rows: label, 0-100 bar and the raw value. `other` adds a comparison delta.
local function statRows(parent, item, other, order)
	local m = UI.m
	local box = UI.box({ Name = "Stats", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order or 0, Parent = parent })
	UI.list("v", 9).Parent = box
	if item.kind ~= "weapon" then
		UI.para(item.effect == "ammo" and "Efecto: repone la reserva de munición de las dos armas." or "Efecto: recupera 50 puntos de vida al instante.", { Parent = box })
		return box
	end
	local bars = Catalog.bars(item)
	local ob = other and other.kind == "weapon" and Catalog.bars(other) or nil
	local raw = {
		damage = item.stats.pellets > 1 and (item.stats.damage .. " × " .. item.stats.pellets) or tostring(item.stats.damage),
		rate = item.stats.rpm .. " /min",
		range = item.stats.range .. " m",
		mobility = tostring(item.stats.mobility),
		control = tostring(item.stats.control),
	}
	local value = {
		damage = function(w)
			return w.stats.damage * w.stats.pellets
		end,
		rate = function(w)
			return w.stats.rpm
		end,
		range = function(w)
			return w.stats.range
		end,
		mobility = function(w)
			return w.stats.mobility
		end,
		control = function(w)
			return w.stats.control
		end,
	}
	for i, key in Catalog.statOrder do
		local row = UI.box({ Size = UDim2.new(1, 0, 0, m.small + 12), LayoutOrder = i, Parent = box })
		local top = UI.box({ Size = UDim2.new(1, 0, 0, m.small + 2), Parent = row })
		UI.label("small", Catalog.statName[key], { Size = UDim2.fromScale(0.5, 1), Parent = top })
		local val = UI.label("mono", raw[key], { Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.paper, Parent = top })
		local bar = UI.bar({ height = 4, value = bars[key], max = 100, color = C.paper, size = UDim2.new(1, 0, 0, 4) })
		bar.inst.Position = UDim2.new(0, 0, 1, -4)
		bar.inst.Parent = row
		if ob then
			-- the delta is shown in the stat's own units (per minute, metres, points); the colour says which is better
			local d = value[key](item) - value[key](other)
			if d ~= 0 then
				val.Text = raw[key] .. string.format("  %s%s", d > 0 and "+" or "−", Util.num(math.abs(d)))
				val.TextColor3 = d > 0 and C.ok or C.bad
			end
			bar.color(d >= 0 and C.ok or C.bad)
		end
	end
	local facts = UI.box({ Size = UDim2.new(1, 0, 0, m.small + 6), LayoutOrder = 10, Parent = box })
	UI.list("h", 14).Parent = facts
	for i, f in { { "bullet", item.stats.mag .. " / " .. item.stats.reserve }, { "reload", string.format("%.1f s", item.stats.reload):gsub("%.", ",") }, { "aim", math.round(item.accuracy * 100) .. " %" } } do
		local cell = UI.box({ Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, Parent = facts })
		UI.list("h", 5).Parent = cell
		UI.icon(f[1], 14, C.steel, { LayoutOrder = 1, Parent = cell })
		UI.label("mono", f[2], { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = cell })
	end
	return box
end
Armory.statRows = statRows

local function compareModal(item)
	local m = UI.m
	local others = {}
	for _, w in Catalog.weapons do
		if w.id ~= item.id then
			table.insert(others, w)
		end
	end
	local otherId = others[1].id
	for _, w in others do
		if Store.isEquipped(w.id) and w.slot == item.slot then
			otherId = w.id
		end
	end
	UI.modal({
		title = "Comparar armas",
		eyebrow = "Arsenal  ·  " .. item.name,
		width = 860,
		build = function(body, api)
			UI.list("v", m.gap).Parent = body
			local opts = {}
			for _, w in others do
				table.insert(opts, { value = w.id, label = w.name })
			end
			local cols = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
			local function render()
				for _, c in cols:GetChildren() do
					c:Destroy()
				end
				UI.list("h", m.gap, { HorizontalFlex = Enum.UIFlexAlignment.Fill, VerticalAlignment = Enum.VerticalAlignment.Top }).Parent = cols
				local other = Catalog.get(otherId)
				for i, it in { item, other } do
					local col = UI.box({ Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = cols })
					UI.flex("fill").Parent = col
					UI.list("v", 8).Parent = col
					local card = WeaponView.card(it, { size = UDim2.new(1, 0, 0, UI.isPhone() and 110 or 170), order = 1, finish = Store.finishOf(it.id) })
					card.inst.Parent = col
					local head = UI.box({ Size = UDim2.new(1, 0, 0, m.h3 + 6), LayoutOrder = 2, Parent = col })
					UI.list("h", 8).Parent = head
					UI.label("h3", it.name, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = head })
					UI.rarityTag(it.rarity, { order = 2 }).Parent = head
					statRows(col, it, i == 1 and other or item, 3)
				end
			end
			local seg = UI.segmented({ options = opts, value = otherId, order = 1, onChange = function(v)
				otherId = v
				render()
			end })
			seg.inst.Parent = body
			cols.Parent = body
			render()
			UI.label("micro", "Verde: mejor que la otra arma  ·  rojo: peor.", { LayoutOrder = 3, Parent = body })
		end,
		actions = { { text = "Cerrar comparación", variant = "ghost", onClick = function()
			UI.closeModalSilently()
		end } },
	})
end

function Armory.build(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	local phone = UI.isPhone()
	local tablet = UI.layout == "tablet"
	local s = Store.state

	local filter = { slot = ctx.params.slot or "all", owned = false }
	local selectedId = ctx.params.item or (ctx.params.slot and s.loadout[ctx.params.slot]) or s.loadout.primary

	-- columns
	local listW = phone and 0.4 or (tablet and 0.36 or 0.3)
	local sideW = phone and 0 or (tablet and 0 or 0.26)
	local listCol = UI.box({ Name = "Catalogue", Size = UDim2.new(listW, 0, 1, -m.pad), Parent = root })
	UI.list("v", m.gapSm).Parent = listCol
	local detail = UI.scroll({ Name = "Detail", Size = UDim2.new(1 - listW - sideW, -m.gap * (sideW > 0 and 2 or 1), 1, -m.pad), Position = UDim2.new(listW, m.gap, 0, 0), ScrollBarThickness = 3, Parent = root })
	local side = sideW > 0 and UI.scroll({ Name = "Side", Size = UDim2.new(sideW, 0, 1, -m.pad), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), ScrollBarThickness = 3, Parent = root }) or nil

	-- filters
	local headRow = UI.header("Arsenal", { order = 1 })
	headRow.Parent = listCol
	local slotSeg = UI.segmented({
		fill = true,
		order = 2,
		value = filter.slot,
		options = {
			{ value = "all", label = "Todo" },
			-- the list column is narrow on tablet too: short labels everywhere except desktop
			{ value = "primary", label = UI.layout ~= "desktop" and "Princ." or "Principal" },
			{ value = "secondary", label = UI.layout ~= "desktop" and "Sec." or "Secundaria" },
			{ value = "support", label = "Apoyo" },
		},
	})
	slotSeg.inst.Parent = listCol
	local ownedRow = UI.box({ Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 3, Parent = listCol })
	UI.list("h", 10).Parent = ownedRow
	local ownedToggle = UI.toggle({ value = false, order = 1 })
	ownedToggle.inst.Parent = ownedRow
	local countLabel = UI.label("small", "Solo lo que tengo", { Size = UDim2.new(1, -60, 1, 0), LayoutOrder = 2, Parent = ownedRow })
	local list = UI.scroll({ Name = "Items", Size = UDim2.new(1, 0, 1, -(m.h3 * 1.35 + m.btnSm + 6 + 30 + 3 * m.gapSm)), LayoutOrder = 4, ScrollBarThickness = 3, Parent = listCol })
	UI.list("v", 6).Parent = list
	UI.pad(2, 6, 2, 2).Parent = list

	local tiles = {}
	local renderDetail

	local function renderList()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		table.clear(tiles)
		local n = 0
		for i, item in Catalog.gear() do
			local okSlot = filter.slot == "all" or item.slot == filter.slot
			local okOwned = not filter.owned or Store.owns(item.id)
			if okSlot and okOwned then
				n += 1
				local st = itemState(item)
				local h = phone and 56 or 72
				local b = UI.new("ImageButton", { Name = "Item_" .. item.id, BackgroundTransparency = 1, ImageColor3 = C.ink600, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, h), LayoutOrder = i, Parent = list })
				Icons.apply(b, "panelTone")
				b.SliceScale = 0.3
				local thumb = WeaponView.card(item, { compact = true, size = UDim2.new(0, math.floor(h * 1.55), 1, -8), finish = Store.finishOf(item.id) })
				thumb.inst.Position = UDim2.fromOffset(4, 4)
				thumb.inst.Parent = b
				-- only level-locked gear is veiled; items for sale keep a readable thumbnail (the price tag says the rest)
				if st == "locked" then
					local veil = UI.fill(C.ink900, { BackgroundTransparency = 0.58, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = thumb.inst })
					UI.icon("lock", 18, C.paper, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 6, Parent = veil })
				end
				local txt = UI.box({ Size = UDim2.new(1, -math.floor(h * 1.55) - 18, 1, 0), Position = UDim2.fromOffset(math.floor(h * 1.55) + 14, 0), Parent = b })
				UI.list("v", 3, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = txt
				UI.label("title", item.name, { LayoutOrder = 1, TextSize = phone and m.small + 1 or m.body, TextColor3 = (st == "locked") and C.steel2 or C.paper, Parent = txt })
				local sub = UI.box({ Size = UDim2.new(1, 0, 0, m.micro + 10), LayoutOrder = 2, Parent = txt })
				UI.list("h", 6).Parent = sub
				if st == "equipped" then
					UI.tag("Equipada", C.signal, { icon = "check", order = 1 }).Parent = sub
				elseif st == "locked" then
					UI.tag("Nivel " .. item.unlockLevel, C.steel, { icon = "lock", order = 1 }).Parent = sub
				elseif st == "shop" then
					UI.tag(Util.num(item.price), C.brass, { icon = "credits", order = 1 }).Parent = sub
				else
					UI.label("micro", Catalog.className[item.class] .. "  ·  " .. Catalog.slotName[item.slot], { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = sub })
				end
				if not phone and st ~= "owned" then
					UI.label("micro", Catalog.className[item.class], { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = sub })
				end
				local selRing = UI.shape("panelCutStroke", C.signal, { Name = "Selected", SliceScale = 0.3, Visible = false, ZIndex = 7, Parent = b })
				local hoverRing = UI.shape("panelCutStroke", C.steel, { Name = "Hover", SliceScale = 0.3, Visible = false, ZIndex = 6, Parent = b })
				for _, ev in { "MouseEnter", "SelectionGained" } do
					b[ev]:Connect(function()
						hoverRing.Visible = true
					end)
				end
				for _, ev in { "MouseLeave", "SelectionLost" } do
					b[ev]:Connect(function()
						hoverRing.Visible = false
					end)
				end
				b.Activated:Connect(function()
					if selectedId ~= item.id then
						UI.sfx("click")
						selectedId = item.id
						for id, t in tiles do
							t.sel.Visible = id == selectedId
							t.button.ImageColor3 = id == selectedId and C.signal:Lerp(C.ink600, 0.8) or C.ink600
						end
						renderDetail()
					end
				end)
				tiles[item.id] = { sel = selRing, button = b }
				selRing.Visible = item.id == selectedId
				if item.id == selectedId then
					b.ImageColor3 = C.signal:Lerp(C.ink600, 0.8)
				end
			end
		end
		if n == 0 then
			local e = UI.emptyState({ icon = "search", title = "Sin resultados", body = "No tienes nada en esta categoría todavía.", action = "Quitar filtros", onAction = function()
				filter.slot, filter.owned = "all", false
				slotSeg.set("all")
				ownedToggle.set(false)
				renderList()
			end })
			e.Parent = list
		end
	end

	-- detail ------------------------------------------------------------
	local detailScope = scope:child()
	local stampAt = 0
	function renderDetail()
		detailScope:clean()
		for _, c in detail:GetChildren() do
			if c:IsA("GuiObject") or c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		if side then
			for _, c in side:GetChildren() do
				if c:IsA("GuiObject") or c:IsA("UIListLayout") then
					c:Destroy()
				end
			end
			UI.list("v", m.gap).Parent = side
		end
		UI.list("v", m.gap).Parent = detail
		local item = Catalog.get(selectedId)
		local st = itemState(item)

		local title = UI.box({ Size = UDim2.new(1, 0, 0, m.h1 + 8), LayoutOrder = 1, Parent = detail })
		UI.list("h", 10).Parent = title
		UI.label("h1", item.name, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextSize = phone and m.h2 + 2 or m.h1, LayoutOrder = 1, Parent = title })
		UI.rarityTag(item.rarity, { order = 2 }).Parent = title

		local cardH = phone and 150 or math.clamp(math.floor(root.AbsoluteSize.Y * 0.42), 180, 360)
		local card = WeaponView.card(item, { size = UDim2.new(1, 0, 0, cardH), order = 2, drag = true, finish = Store.finishOf(item.id) })
		card.inst.Parent = detail
		if not UI.touch and not phone then
			local hint = UI.label("micro", "Arrastra para girar", { Size = UDim2.new(0, 120, 0, 14), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -m.pad, 1, -(m.pad + 30)), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.paperInk, ZIndex = 4, Parent = card.inst })
			hint.TextTransparency = 0.4
		end
		-- "EQUIPADA" stamp shown right after equipping
		local stamp = UI.new("ImageLabel", { Name = "Stamp", BackgroundTransparency = 1, ImageColor3 = C.signal, Size = UDim2.fromOffset(170, 44), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = -6, ZIndex = 8, Visible = false, Parent = card.inst })
		Icons.apply(stamp, "btnCutStroke")
		stamp.SliceScale = 0.35
		UI.label("h2", "Equipada", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.signal, ZIndex = 9, Parent = stamp })
		if os.clock() - stampAt < 0.3 then
			stamp.Visible = true
			local sc = UI.new("UIScale", { Scale = Util.reducedMotion and 1 or 1.5, Parent = stamp })
			Util.tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
			detailScope:delay(1.1, function()
				Util.tween(stamp, 0.3, { ImageTransparency = 1 })
				local l = stamp:FindFirstChildOfClass("TextLabel")
				if l then
					Util.tween(l, 0.3, { TextTransparency = 1 })
				end
			end)
		end

		local meta = UI.label("eyebrow", (Catalog.className[item.class] or "") .. "  ·  hueco " .. Catalog.slotName[item.slot], { LayoutOrder = 3, TextColor3 = C.signal2, Parent = detail })
		UI.para(item.desc, { LayoutOrder = 4, Parent = detail })

		-- actions
		local actions = UI.box({ Size = UDim2.new(1, 0, 0, m.btn), LayoutOrder = 5, Parent = detail })
		UI.list("h", m.gapSm).Parent = actions
		local main
		if st == "equipped" then
			main = UI.button({ text = "Equipada", icon = "check", variant = "secondary", disabled = true, order = 1 })
		elseif st == "owned" then
			main = UI.button({ text = "Equipar como " .. Catalog.slotName[item.slot]:lower(), icon = "check", variant = "primary", order = 1, onClick = function()
				local ok = Store.dispatch({ type = "EQUIP", id = item.id })
				if ok then
					stampAt = os.clock()
					UI.toast(item.name .. " equipada como " .. Catalog.slotName[item.slot]:lower(), "ok")
				end
			end })
		elseif st == "locked" then
			main = UI.button({ text = "Se desbloquea en el nivel " .. item.unlockLevel, icon = "lock", variant = "secondary", disabled = true, order = 1 })
		else
			main = UI.button({ text = "Ver en la tienda · " .. Util.num(item.price), icon = "shop", variant = "light", order = 1, onClick = function()
				ctx.go("shop", { item = item.id })
			end })
		end
		main.inst.Parent = actions
		if item.kind == "weapon" then
			local cmp = UI.button({ text = "Comparar", icon = "compare", variant = "ghost", order = 2, onClick = function()
				compareModal(item)
			end })
			cmp.inst.Parent = actions
		end
		if st == "locked" then
			local p = Store.state.profile
			local need = item.unlockLevel - p.level
			UI.label("small", string.format("Te faltan %d %s. Ganas XP jugando partidas y con las misiones.", need, need == 1 and "nivel" or "niveles"), { LayoutOrder = 6, TextColor3 = C.warn, Parent = detail })
		end

		local statsParent = side or detail
		local statsPanel = UI.surface({ Name = "StatsPanel", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 7, Parent = statsParent }, { edge = C.ink700, pad = 14 })
		UI.list("v", 10).Parent = statsPanel
		UI.header(item.kind == "weapon" and "Estadísticas" or "Efecto", { order = 1 }).Parent = statsPanel
		statRows(statsPanel, item, nil, 2)

		-- finishes (cosmetics) for weapons
		if item.kind == "weapon" then
			local fin = UI.surface({ Name = "Finishes", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 8, Parent = statsParent }, { edge = C.ink700, pad = 14 })
			UI.list("v", 10).Parent = fin
			local current = Store.finishOf(item.id)
			UI.header("Acabado", { order = 1, right = UI.label("small", Catalog.get(current).name, { Size = UDim2.fromOffset(120, 18), TextXAlignment = Enum.TextXAlignment.Right }) }).Parent = fin
			local grid = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = fin })
			UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(phone and 44 or 52, phone and 44 or 52), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
			local ownedWeapon = Store.owns(item.id)
			for i, f in Catalog.finishes do
				local owned = Store.owns(f.id)
				local on = current == f.id
				local sw = UI.new("ImageButton", { Name = "Finish_" .. f.id, BackgroundTransparency = 1, ImageColor3 = f.tint or C.steel2, AutoButtonColor = false, LayoutOrder = i, Parent = grid })
				Icons.apply(sw, "btnCut")
				sw.SliceScale = 0.3
				if not f.tint then
					UI.new("UIGradient", { Color = ColorSequence.new(Color3.fromHex("#3A4148"), Color3.fromHex("#8E9AA6")), Rotation = 45, Parent = sw })
				end
				local ring = UI.shape("btnCutStroke", on and C.paper or C.ink950, { SliceScale = 0.3, ZIndex = 3, Parent = sw })
				if not owned then
					sw.ImageTransparency = 0.55
					UI.icon("lock", 16, C.paper, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4, Parent = sw })
				elseif on then
					UI.icon("check", 18, C.ink950, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4, Parent = sw })
				end
				sw.MouseEnter:Connect(function()
					ring.ImageColor3 = C.paper
					card.setFinish(f.id) -- live preview
				end)
				sw.MouseLeave:Connect(function()
					ring.ImageColor3 = on and C.paper or C.ink950
					card.setFinish(Store.finishOf(item.id))
				end)
				sw.Activated:Connect(function()
					if not owned then
						UI.sfx("click")
						ctx.go("shop", { item = f.id })
						return
					end
					if not ownedWeapon then
						UI.toast("Consigue el arma antes de aplicarle un acabado.", "warn")
						return
					end
					local ok, info = Store.dispatch({ type = "SET_FINISH", weapon = item.id, finish = f.id })
					if ok then
						UI.sfx("confirm")
						UI.toast("Acabado " .. f.name .. " aplicado a " .. item.name, "ok")
						if info.mission then
							UI.toast("Misión completada: Equipa un acabado. Reclámala en Misiones.", "reward", 4)
						end
					end
				end)
			end
			UI.label("micro", "Pasa el cursor para previsualizar · los bloqueados están en la tienda", { LayoutOrder = 3, Parent = fin, Visible = not UI.touch })
		end

		-- current loadout reminder (desktop side column)
		if side then
			local lo = UI.surface({ Name = "CurrentLoadout", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 9, Parent = side }, { edge = C.ink700, pad = 14 })
			UI.list("v", 8).Parent = lo
			UI.header("Equipamiento actual", { order = 1 }).Parent = lo
			for i, slot in { "primary", "secondary", "support" } do
				local it = Catalog.get(Store.state.loadout[slot])
				local row = UI.box({ Size = UDim2.new(1, 0, 0, m.small + 8), LayoutOrder = 1 + i, Parent = lo })
				UI.label("micro", UI.upper(Catalog.slotName[slot]), { Size = UDim2.fromScale(0.42, 1), Parent = row })
				UI.label("small", it.name, { Size = UDim2.fromScale(0.58, 1), Position = UDim2.fromScale(0.42, 0), TextColor3 = it.id == item.id and C.signal or C.paper, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
			end
		end
	end

	slotSeg.inst:FindFirstChild("Track")
	local function onFilter()
		renderList()
	end
	-- segmented/toggle callbacks are set after creation
	slotSeg.inst.Destroying:Connect(function() end)
	local segApi = slotSeg
	for _, opt in { "all", "primary", "secondary", "support" } do
		local b = segApi.inst:FindFirstChild("Option_" .. opt, true)
		if b then
			b.Activated:Connect(function()
				filter.slot = opt
				onFilter()
			end)
		end
	end
	ownedToggle.inst.Activated:Connect(function()
		filter.owned = not filter.owned
		onFilter()
	end)

	renderList()
	renderDetail()
	scope:connect(Store.changed, function(a)
		if a.type == "EQUIP" or a.type == "SET_FINISH" or a.type == "PURCHASE" or a.type == "RESET" or a.type == "CLAIM_MISSION" then
			renderList()
			renderDetail()
		end
	end)
end

return Armory
