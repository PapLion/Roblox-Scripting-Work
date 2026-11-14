-- Shop with demo credits only (no MarketplaceService, no real payments, no payment data).
-- Flow: item sheet -> confirm (balance before/after) -> processing -> receipt or error.
-- The confirm button locks on the first click and PURCHASE is refused for owned items, so a double
-- click or a repeated purchase can never charge twice.

local PivotUI = script.Parent.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local Catalog = require(PivotUI.Data.Catalog)
local WeaponView = require(PivotUI.WeaponView)
local Icons = require(PivotUI.Icons)

local C, F = UI.C, UI.F
local Shop = {}

local CATEGORIES = {
	{ value = "all", label = "Todo" },
	{ value = "weapon", label = "Armas" },
	{ value = "support", label = "Apoyo" },
	{ value = "finish", label = "Acabados" },
	{ value = "banner", label = "Fondos" },
	{ value = "emblem", label = "Emblemas" },
}

-- Visual for any catalogue item: range card (gear), swatch (finish), banner or emblem tile.
local function preview(item, size, opts)
	opts = opts or {}
	if item.kind == "weapon" or item.kind == "support" then
		local c = WeaponView.card(item, { compact = opts.compact ~= false, size = size, drag = opts.drag, finish = opts.finish })
		return c.inst, c
	end
	local tile = UI.new("ImageLabel", { BackgroundTransparency = 1, ImageColor3 = C.ink600, Size = size, ClipsDescendants = true })
	Icons.apply(tile, "panelTone")
	tile.SliceScale = 0.3
	if item.kind == "finish" then
		local sw = UI.new("ImageLabel", { BackgroundTransparency = 1, ImageColor3 = item.tint or C.steel2, Size = UDim2.fromScale(0.62, 0.62), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = tile })
		Icons.apply(sw, "btnCut")
		sw.SliceScale = 0.5
		UI.new("UIAspectRatioConstraint", { AspectRatio = 1.6, Parent = sw })
		if not item.tint then
			UI.new("UIGradient", { Color = ColorSequence.new(Color3.fromHex("#3A4148"), Color3.fromHex("#8E9AA6")), Rotation = 45, Parent = sw })
		end
		local sheen = UI.new("ImageLabel", { BackgroundTransparency = 1, ImageColor3 = C.white, ImageTransparency = 0.8, Size = UDim2.fromScale(1, 1), Parent = sw })
		Icons.apply(sheen, "pattern_tape")
		sheen.ScaleType = Enum.ScaleType.Crop
	elseif item.kind == "banner" then
		local b = UI.banner(item.id, { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Parent = tile })
		UI.corner(4).Parent = b
		b.Pattern.ImageTransparency = 0.82
	elseif item.kind == "emblem" then
		local e = UI.emblem(item.id, 64, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), Parent = tile })
		UI.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = e })
	end
	return tile
end
Shop.preview = preview

local function stateOf(item)
	if Store.isEquipped(item.id) and Store.owns(item.id) then
		return "equipped"
	elseif Store.owns(item.id) then
		return "owned"
	elseif Store.isLocked(item) then
		return "locked"
	end
	return "buy"
end

local function equip(item)
	if item.kind == "finish" then
		local weapon = Store.state.loadout.primary
		local ok = Store.dispatch({ type = "SET_FINISH", weapon = weapon, finish = item.id })
		if ok then
			UI.toast("Acabado " .. item.name .. " aplicado a " .. Catalog.get(weapon).name, "ok")
		end
		return ok
	end
	local ok = Store.dispatch({ type = "EQUIP", id = item.id })
	if ok then
		UI.toast(item.name .. " equipado", "ok")
	end
	return ok
end

-- Purchase dialog with its internal steps. Returns nothing; everything happens inside the modal.
local function purchaseFlow(item)
	local m = UI.m
	local phone = UI.isPhone()
	local modal
	local step = "detail"
	local receipt
	local function go(nextStep)
		step = nextStep
		modal.clearBody()
		local body = modal.body
		UI.list("v", m.gap).Parent = body
		local s = Store.state
		local st = stateOf(item)
		if step == "detail" then
			modal.setTitle(item.name)
			local top = UI.box({ Size = UDim2.new(1, 0, 0, phone and 130 or 210), LayoutOrder = 1, Parent = body })
			local pv, cardApi = preview(item, UDim2.fromScale(1, 1), { compact = false, drag = true })
			pv.Parent = top
			local tags = UI.box({ Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 2, Parent = body })
			UI.list("h", 6).Parent = tags
			UI.rarityTag(item.rarity, { order = 1 }).Parent = tags
			UI.tag(Catalog.kindName[item.kind], C.steel2, { order = 2 }).Parent = tags
			if item.kind == "finish" then
				UI.label("micro", "Se aplica al arma que elijas en el Arsenal", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, Parent = tags })
			end
			if item.desc then
				UI.para(item.desc, { LayoutOrder = 3, Parent = body })
			end
			if item.kind == "weapon" then
				require(PivotUI.Screens.Tabs.Armory).statRows(body, item, nil, 4)
			end
			-- price line
			local priceRow = UI.box({ Size = UDim2.new(1, 0, 0, m.h3 + 8), LayoutOrder = 5, Parent = body })
			UI.list("h", 12).Parent = priceRow
			UI.label("eyebrow", "Precio", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = priceRow })
			UI.credits(item.price, { textSize = m.h3, order = 2 }).inst.Parent = priceRow
			UI.label("small", "Saldo: " .. Util.num(s.profile.credits), { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, Parent = priceRow })
			local ok, reason, extra = Store.canBuy(item)
			local actions = { { text = "Cerrar", variant = "ghost", sound = "back", onClick = function()
				UI.closeModalSilently()
			end } }
			if st == "equipped" then
				table.insert(actions, { text = "Equipado", icon = "check", variant = "secondary", disabled = true })
			elseif st == "owned" then
				table.insert(actions, { text = "Equipar", icon = "check", variant = "primary", onClick = function()
					equip(item)
					go("detail")
				end })
			elseif reason == "level" then
				table.insert(actions, { text = "Requiere nivel " .. extra, icon = "lock", variant = "secondary", disabled = true })
			elseif reason == "funds" then
				local warn = UI.surface({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 6, Parent = body }, { edge = C.warn:Lerp(C.ink700, 0.7), pad = 12, cut = 0.3 })
				UI.list("h", 10).Parent = warn
				UI.icon("warning", 18, C.warn, { LayoutOrder = 1, Parent = warn })
				UI.para("Te faltan " .. Util.num(extra) .. " créditos. Consíguelos jugando partidas y reclamando misiones.", { Size = UDim2.new(1, -28, 0, 0), TextColor3 = C.paper, LayoutOrder = 2, Parent = warn })
				table.insert(actions, { text = "Te faltan " .. Util.num(extra), icon = "credits", variant = "secondary", disabled = true })
			elseif reason == "offline" then
				table.insert(actions, { text = "Sin conexión con la tienda", icon = "wifiOff", variant = "secondary", disabled = true })
			elseif ok then
				table.insert(actions, { text = "Comprar", icon = "shop", variant = "primary", focus = true, onClick = function()
					go("confirm")
				end })
			end
			modal.setActions(actions)
		elseif step == "confirm" then
			modal.setTitle("¿Comprar " .. item.name .. "?")
			local rows = UI.surface({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body }, { edge = C.ink600, pad = 14, cut = 0.3 })
			UI.list("v", 10).Parent = rows
			for i, r in { { "Saldo actual", s.profile.credits, C.paper }, { "Precio", -item.price, C.bad }, { "Saldo después", s.profile.credits - item.price, C.brass } } do
				local row = UI.box({ Size = UDim2.new(1, 0, 0, m.body + 8), LayoutOrder = i, Parent = rows })
				UI.label("small", r[1], { Size = UDim2.fromScale(0.5, 1), Parent = row })
				UI.label("num", (r[2] < 0 and "−" or "") .. Util.num(math.abs(r[2])), { TextSize = m.h3, Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = r[3], Parent = row })
				if i == 2 then
					UI.divider({ Position = UDim2.new(0, 0, 1, 4), Parent = row })
				end
			end
			UI.para("Operación simulada con créditos de la demo. No se usa dinero real ni se piden datos de pago.", { LayoutOrder = 2, TextSize = m.small, Parent = body })
			local locked = false
			modal.setActions({
				{ text = "Volver", variant = "ghost", sound = "back", onClick = function()
					if not locked then
						go("detail")
					end
				end },
				{ text = "Confirmar compra", icon = "check", variant = "primary", focus = true, loadingText = "Procesando…", onClick = function(btn)
					if locked then
						return -- duplicate click: ignored
					end
					locked = true
					btn.set({ loading = true })
					go("processing")
				end },
			})
		elseif step == "processing" then
			modal.setTitle("Procesando compra…")
			local row = UI.box({ Size = UDim2.new(1, 0, 0, 80), LayoutOrder = 1, Parent = body })
			UI.list("h", 14, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = row
			UI.spinner(34, C.signal).Parent = row
			UI.label("small", "Confirmando con el servidor de la demo", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = row })
			modal.setActions({})
			modal.scope:delay(0.9, function()
				if Store.state.network ~= "online" then
					go("error")
					return
				end
				local ok, info = Store.dispatch({ type = "PURCHASE", id = item.id })
				if ok then
					receipt = info.receipt
					UI.sfx("reward")
					go("success")
				elseif info.reason == "offline" then
					go("error")
				else
					-- owned meanwhile, not enough credits or level: the sheet explains it
					UI.sfx("error")
					go("detail")
				end
			end)
		elseif step == "success" then
			modal.setTitle("Compra completada")
			local head = UI.box({ Size = UDim2.new(1, 0, 0, phone and 90 or 120), LayoutOrder = 1, Parent = body })
			UI.list("h", m.gap).Parent = head
			local pv = preview(item, UDim2.new(0, phone and 140 or 190, 1, 0), {})
			pv.LayoutOrder = 1
			pv.Parent = head
			local txt = UI.box({ Size = UDim2.new(1, -(phone and 140 or 190) - m.gap, 1, 0), LayoutOrder = 2, Parent = head })
			UI.list("v", 4, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = txt
			UI.tag("Comprado", C.ok, { icon = "check", order = 1 }).Parent = txt
			UI.label("h3", item.name, { LayoutOrder = 2, Parent = txt })
			UI.label("small", "Ya está en tu inventario.", { LayoutOrder = 3, Parent = txt })
			local rc = UI.surface({ Name = "Receipt", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = body }, { edge = C.ink600, pad = 14, cut = 0.3 })
			UI.list("v", 6).Parent = rc
			local hr = UI.box({ Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0, Parent = rc })
			UI.list("h", 6).Parent = hr
			UI.icon("receipt", 16, C.steel2, { LayoutOrder = 1, Parent = hr })
			UI.label("eyebrow", "Comprobante", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = hr })
			for i, r in { { "N.º", receipt.code }, { "Fecha", receipt.when }, { "Artículo", item.name }, { "Precio", Util.num(receipt.price) .. " créditos" }, { "Saldo", Util.num(receipt.before) .. "  →  " .. Util.num(receipt.after) } } do
				local row = UI.box({ Size = UDim2.new(1, 0, 0, m.small + 6), LayoutOrder = i, Parent = rc })
				UI.label("small", r[1], { Size = UDim2.fromScale(0.35, 1), Parent = row })
				UI.label("mono", r[2], { Size = UDim2.fromScale(0.65, 1), Position = UDim2.fromScale(0.35, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.paper, Parent = row })
			end
			local acts = { { text = "Cerrar", variant = "ghost", onClick = function()
				UI.closeModalSilently()
			end } }
			if item.kind ~= "finish" or Store.owns(Store.state.loadout.primary) then
				table.insert(acts, { text = item.kind == "finish" and ("Aplicar a " .. Catalog.get(Store.state.loadout.primary).name) or "Equipar ahora", icon = "check", variant = "primary", focus = true, onClick = function()
					equip(item)
					UI.closeModalSilently()
				end })
			end
			modal.setActions(acts)
		elseif step == "error" then
			UI.sfx("error")
			modal.setTitle("No se pudo completar la compra")
			local box = UI.surface({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body }, { edge = C.bad:Lerp(C.ink700, 0.7), pad = 14, cut = 0.3 })
			UI.list("h", 10).Parent = box
			UI.icon("wifiOff", 20, C.bad, { LayoutOrder = 1, Parent = box })
			UI.para("Se ha perdido la conexión con la tienda. No se ha cobrado nada: tu saldo sigue en " .. Util.num(Store.state.profile.credits) .. " créditos.", { Size = UDim2.new(1, -30, 0, 0), TextColor3 = C.paper, LayoutOrder = 2, Parent = box })
			modal.setActions({
				{ text = "Cerrar", variant = "ghost", onClick = function()
					UI.closeModalSilently()
				end },
				{ text = "Reintentar", icon = "refresh", variant = "primary", onClick = function()
					go("detail")
				end },
			})
		end
	end
	local watch
	modal = UI.modal({ title = item.name, eyebrow = "Tienda", width = 620, build = function() end, onClose = function()
		if watch then
			watch:Disconnect()
		end
	end })
	go("detail")
	-- keep the sheet truthful if balance, ownership or connection change while it is open
	watch = Store.changed:Connect(function(a)
		local t = a.type
		if t == "PURCHASE" or t == "DEMO_CREDITS" or t == "NET" or t == "EQUIP" or t == "SET_FINISH" or t == "CLAIM_MISSION" or t == "MATCH_END" then
			if step == "detail" then
				go("detail")
			elseif step == "confirm" and not Store.canBuy(item) then
				go("detail")
			end
		end
	end)
end
Shop.purchaseFlow = purchaseFlow

local function historyModal()
	local m = UI.m
	UI.modal({
		title = "Historial de compras",
		eyebrow = "Tienda",
		width = 600,
		build = function(body)
			UI.list("v", 6).Parent = body
			local list = Store.state.purchases
			if #list == 0 then
				UI.emptyState({ icon = "receipt", title = "Aún no has comprado nada", body = "Lo que compres aparecerá aquí con su comprobante." }).Parent = body
				return
			end
			local head = UI.box({ Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0, Parent = body })
			for i, h in { { "Comprobante", 0 }, { "Artículo", 0.25 }, { "Fecha", 0.6 }, { "Precio", 0.8 } } do
				UI.label("eyebrow", h[1], { Size = UDim2.fromScale(0.2, 1), Position = UDim2.fromScale(h[2], 0), TextXAlignment = i == 4 and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left, Parent = head })
			end
			for i, r in list do
				local row = UI.box({ Size = UDim2.new(1, 0, 0, m.body + 14), LayoutOrder = i, Parent = body })
				UI.divider({ Parent = row })
				UI.label("mono", r.code, { Size = UDim2.fromScale(0.25, 1), Parent = row })
				UI.label("small", Catalog.get(r.item).name, { Size = UDim2.fromScale(0.35, 1), Position = UDim2.fromScale(0.25, 0), TextColor3 = C.paper, Parent = row })
				UI.label("mono", r.when, { Size = UDim2.fromScale(0.2, 1), Position = UDim2.fromScale(0.6, 0), Parent = row })
				UI.label("mono", Util.num(r.price), { Size = UDim2.fromScale(0.2, 1), Position = UDim2.fromScale(0.8, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.brass, Parent = row })
			end
		end,
		actions = { { text = "Cerrar", variant = "ghost", onClick = function()
			UI.closeModalSilently()
		end } },
	})
end

function Shop.build(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	local phone = UI.isPhone()
	local tablet = UI.layout == "tablet"
	local filter = { cat = "all", sort = "featured", hideOwned = false }

	-- featured column (desktop/tablet)
	local featW = phone and 0 or (tablet and 0.34 or 0.3)
	if featW > 0 then
		local item = Catalog.get("anvil")
		local feat = UI.surface({ Name = "Featured", Size = UDim2.new(featW, 0, 1, -m.pad), Parent = root }, { edge = C.signal:Lerp(C.ink700, 0.72), pad = 16 })
		UI.list("v", m.gapSm + 2).Parent = feat
		local tr = UI.box({ Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = feat })
		UI.list("h", 6).Parent = tr
		UI.tag("Destacado", C.signal, { solid = true, icon = "star", order = 1 }).Parent = tr
		UI.rarityTag(item.rarity, { order = 2 }).Parent = tr
		UI.label("h1", item.name, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, m.h1 + 6), Parent = feat })
		local card = WeaponView.card(item, { size = UDim2.new(1, 0, 0.42, 0), order = 3, drag = true })
		card.inst.Parent = feat
		UI.para(item.desc, { LayoutOrder = 4, TextSize = m.small, Parent = feat })
		local priceRow = UI.box({ Size = UDim2.new(1, 0, 0, m.h2 + 6), LayoutOrder = 5, Parent = feat })
		UI.list("h", 10).Parent = priceRow
		UI.credits(item.price, { textSize = m.h2, order = 1 }).inst.Parent = priceRow
		UI.label("micro", "Desde el nivel " .. item.unlockLevel, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = priceRow })
		local buy = UI.button({ text = "Ver oferta", icon = "shop", variant = "primary", width = UDim.new(1, 0), order = 6, onClick = function()
			purchaseFlow(item)
		end })
		buy.inst.Parent = feat
		local function refreshFeat()
			local st = stateOf(item)
			buy.set({ text = st == "equipped" and "Equipada" or (st == "owned" and "Comprada · ver" or "Ver oferta"), icon = st == "buy" and "shop" or "check" })
		end
		refreshFeat()
		scope:connect(Store.changed, refreshFeat)
	end

	local main = UI.box({ Name = "Catalogue", Size = UDim2.new(1 - featW, featW > 0 and -m.gap or 0, 1, -m.pad), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = root })
	UI.list("v", m.gapSm).Parent = main
	-- toolbar
	local bar1 = UI.box({ Size = UDim2.new(1, 0, 0, m.btnSm + 6), LayoutOrder = 1, Parent = main })
	UI.list("h", m.gapSm).Parent = bar1
	local cats = {}
	for _, c in CATEGORIES do
		if not (phone and (c.value == "banner" or c.value == "emblem")) then
			table.insert(cats, c)
		end
	end
	local catSeg = UI.segmented({ options = cats, value = "all", order = 1 })
	catSeg.inst.Parent = bar1
	local hist = UI.button({ text = phone and "" or "Historial", icon = "history", variant = "ghost", size = "sm", order = 2, onClick = historyModal })
	hist.inst.Parent = bar1
	local bar2 = UI.box({ Size = UDim2.new(1, 0, 0, m.btnSm + 6), LayoutOrder = 2, Parent = main })
	UI.list("h", m.gap).Parent = bar2
	local sortSeg = UI.segmented({ options = { { value = "featured", label = "Recomendado" }, { value = "price", label = "Precio" }, { value = "rarity", label = "Rareza" } }, value = "featured", order = 1 })
	sortSeg.inst.Parent = bar2
	local hideRow = UI.box({ Size = UDim2.fromOffset(0, m.btnSm + 6), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = bar2 })
	UI.list("h", 8).Parent = hideRow
	local hideToggle = UI.toggle({ value = false, order = 1 })
	hideToggle.inst.Parent = hideRow
	UI.label("small", "Ocultar comprados", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = hideRow })
	if phone then
		sortSeg.inst.Visible = false
	end

	local grid = UI.scroll({ Name = "Grid", Size = UDim2.new(1, 0, 1, -(2 * (m.btnSm + 6) + 2 * m.gapSm)), LayoutOrder = 3, ScrollBarThickness = 3, Parent = main })
	UI.pad(2, 8, 8, 2).Parent = grid
	local cols = phone and 3 or (tablet and 3 or 4)
	local gl = UI.new("UIGridLayout", { CellPadding = UDim2.fromOffset(m.gapSm + 2, m.gapSm + 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local function sizeCells()
		local w = grid.AbsoluteSize.X - 14
		local cw = math.floor((w - (cols - 1) * (m.gapSm + 2)) / cols)
		gl.CellSize = UDim2.fromOffset(cw, math.floor(cw * (phone and 1.02 or 0.92)))
	end
	sizeCells()
	scope:connect(grid:GetPropertyChangedSignal("AbsoluteSize"), sizeCells)

	local function render()
		for _, c in grid:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local items = {}
		for _, item in Catalog.all() do
			if item.price and item.price > 0 and (filter.cat == "all" or item.kind == filter.cat) and not (filter.hideOwned and Store.owns(item.id)) then
				table.insert(items, item)
			end
		end
		if filter.sort == "price" then
			table.sort(items, function(a, b)
				return a.price < b.price
			end)
		elseif filter.sort == "rarity" then
			table.sort(items, function(a, b)
				local ra, rb = Catalog.rarityRank[a.rarity], Catalog.rarityRank[b.rarity]
				if ra == rb then
					return a.price > b.price
				end
				return ra > rb
			end)
		end
		if #items == 0 then
			local e = UI.emptyState({ icon = "check", title = "Ya lo tienes todo en esta categoría", body = "Desactiva «Ocultar comprados» para ver tus artículos.", action = "Mostrar todo", onAction = function()
				filter.hideOwned = false
				hideToggle.set(false)
				render()
			end })
			e.Size = UDim2.new(1, -14, 0, 0)
			gl.Parent = nil
			e.Parent = grid
			return
		end
		gl.Parent = grid
		for i, item in items do
			local st = stateOf(item)
			local b = UI.new("ImageButton", { Name = "Item_" .. item.id, BackgroundTransparency = 1, ImageColor3 = C.ink600, AutoButtonColor = false, LayoutOrder = i, Parent = grid })
			Icons.apply(b, "panelTone")
			b.SliceScale = 0.35
			local pv = preview(item, UDim2.new(1, -10, 0.6, -6), {})
			pv.Position = UDim2.fromOffset(5, 5)
			pv.Parent = b
			local txt = UI.box({ Size = UDim2.new(1, -16, 0.4, -4), Position = UDim2.new(0, 8, 0.6, 2), Parent = b })
			UI.list("v", 3, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = txt
			local r1 = UI.box({ Size = UDim2.new(1, 0, 0, m.micro + 8), LayoutOrder = 1, Parent = txt })
			UI.list("h", 5).Parent = r1
			UI.rarityTag(item.rarity, { order = 1, height = m.micro + 6 }).Parent = r1
			if not phone then
				UI.label("micro", Catalog.kindName[item.kind], { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = r1 })
			end
			UI.label("title", item.name, { LayoutOrder = 2, TextSize = phone and m.small or m.body, Parent = txt })
			local r3 = UI.box({ Size = UDim2.new(1, 0, 0, m.body + 4), LayoutOrder = 3, Parent = txt })
			if st == "equipped" then
				UI.tag("Equipado", C.signal, { icon = "check" }).Parent = r3
			elseif st == "owned" then
				UI.tag("Comprado", C.ok, { icon = "check" }).Parent = r3
			else
				local cr = UI.credits(item.price, { textSize = m.body - 1, color = Store.state.profile.credits >= item.price and C.paper or C.steel })
				cr.inst.Parent = r3
				if st == "locked" then
					local lk = UI.tag("Nv. " .. item.unlockLevel, C.steel, { icon = "lock" })
					lk.AnchorPoint = Vector2.new(1, 0)
					lk.Position = UDim2.fromScale(1, 0)
					lk.Parent = r3
				end
			end
			local hover = UI.shape("panelCutStroke", C.signal, { SliceScale = 0.35, Visible = false, ZIndex = 6, Parent = b })
			for _, ev in { "MouseEnter", "SelectionGained" } do
				b[ev]:Connect(function()
					hover.Visible = true
				end)
			end
			for _, ev in { "MouseLeave", "SelectionLost" } do
				b[ev]:Connect(function()
					hover.Visible = false
				end)
			end
			b.Activated:Connect(function()
				UI.sfx("click")
				purchaseFlow(item)
			end)
		end
	end

	for _, c in cats do
		local b = catSeg.inst:FindFirstChild("Option_" .. c.value, true)
		b.Activated:Connect(function()
			filter.cat = c.value
			render()
		end)
	end
	for _, v in { "featured", "price", "rarity" } do
		local b = sortSeg.inst:FindFirstChild("Option_" .. v, true)
		b.Activated:Connect(function()
			filter.sort = v
			render()
		end)
	end
	hideToggle.inst.Activated:Connect(function()
		filter.hideOwned = not filter.hideOwned
		render()
	end)
	render()
	scope:connect(Store.changed, function(a)
		local t = a.type
		if t == "PURCHASE" or t == "EQUIP" or t == "SET_FINISH" or t == "DEMO_CREDITS" or t == "RESET" or t == "NET" or t == "CLAIM_MISSION" then
			render()
		end
	end)

	-- deep link from the arsenal ("Ver en la tienda")
	if ctx.params.item then
		local item = Catalog.get(ctx.params.item)
		if item then
			scope:delay(0.1, function()
				purchaseFlow(item)
			end)
		end
	end
end

return Shop
