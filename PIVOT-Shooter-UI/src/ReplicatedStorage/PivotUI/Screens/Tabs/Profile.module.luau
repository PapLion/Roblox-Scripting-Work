-- Profile: player card with banner/emblem customisation, career stats and recent matches.
-- Simulated matches are prepended to the history by MATCH_END.

local PivotUI = script.Parent.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local World = require(PivotUI.Data.World)
local Catalog = require(PivotUI.Data.Catalog)
local Parts = require(PivotUI.Screens.Parts)
local Icons = require(PivotUI.Icons)

local C, F = UI.C, UI.F
local Profile = {}

local RESULT = { victory = { "Victoria", C.ok }, defeat = { "Derrota", C.bad }, draw = { "Empate", C.steel2 } }

local function cosmeticPicker(ctx, kind, order)
	local m = UI.m
	local list = kind == "banner" and Catalog.banners or Catalog.emblems
	local box = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order })
	UI.list("v", 6).Parent = box
	UI.label("eyebrow", kind == "banner" and "Fondo de tarjeta" or "Emblema", { LayoutOrder = 1, Parent = box })
	local row = UI.box({ Size = UDim2.new(1, 0, 0, kind == "banner" and 46 or 52), LayoutOrder = 2, Parent = box })
	UI.list("h", 8).Parent = row
	local current = kind == "banner" and Store.state.profile.banner or Store.state.profile.emblem
	for i, item in list do
		local owned = Store.owns(item.id)
		local on = current == item.id
		local b = UI.new("ImageButton", { Name = item.id, BackgroundTransparency = 1, ImageColor3 = C.ink600, AutoButtonColor = false, Size = kind == "banner" and UDim2.fromOffset(78, 46) or UDim2.fromOffset(52, 52), LayoutOrder = i, Parent = row })
		Icons.apply(b, "panelTone")
		b.SliceScale = 0.25
		if kind == "banner" then
			local bn = UI.banner(item.id, { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Parent = b })
			UI.corner(3).Parent = bn
		else
			UI.emblem(item.id, 34, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = b })
		end
		local ring = UI.shape("panelCutStroke", on and C.signal or C.paper, { SliceScale = 0.25, Visible = on, ZIndex = 4, Parent = b })
		if not owned then
			local veil = UI.fill(C.ink950, { BackgroundTransparency = 0.4, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = 3, Parent = b })
			UI.corner(3).Parent = veil
			UI.icon("lock", 16, C.paper, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4, Parent = veil })
		end
		for _, ev in { "MouseEnter", "SelectionGained" } do
			b[ev]:Connect(function()
				ring.Visible = true
			end)
		end
		for _, ev in { "MouseLeave", "SelectionLost" } do
			b[ev]:Connect(function()
				ring.Visible = on
			end)
		end
		b.Activated:Connect(function()
			if not owned then
				UI.sfx("click")
				ctx.go("shop", { item = item.id })
				return
			end
			if Store.dispatch({ type = "EQUIP", id = item.id }) then
				UI.sfx("confirm")
				UI.toast((kind == "banner" and "Fondo " or "Emblema ") .. item.name .. " equipado", "ok")
			end
		end)
	end
	return box
end

function Profile.build(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	local phone = UI.isPhone()
	local leftW = phone and 0.42 or 0.36

	local left = UI.scroll({ Name = "Identity", Size = UDim2.new(leftW, 0, 1, -m.pad), ScrollBarThickness = 0, Parent = root })
	local right = UI.scroll({ Name = "Career", Size = UDim2.new(1 - leftW, -m.gap, 1, -m.pad), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), ScrollBarThickness = 3, Parent = root })

	local function render()
		for _, f in { left, right } do
			for _, c in f:GetChildren() do
				c:Destroy()
			end
		end
		local childScope = scope:child()
		UI.list("v", m.gap).Parent = left
		UI.list("v", m.gap).Parent = right
		UI.pad(0, 6, 0, 0).Parent = right
		local p = Store.state.profile
		local st = p.stats

		UI.header("Perfil", { order = 1 }).Parent = left
		Parts.playerCard(childScope, { order = 2, height = phone and 72 or 110 }).Parent = left
		local custom = UI.surface({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = left }, { edge = C.ink700, pad = 14 })
		UI.list("v", 12).Parent = custom
		UI.header("Personalización", { order = 0 }).Parent = custom
		cosmeticPicker(ctx, "banner", 1).Parent = custom
		cosmeticPicker(ctx, "emblem", 2).Parent = custom
		UI.label("micro", "Los bloqueados se consiguen en la Tienda o con misiones.", { LayoutOrder = 3, Parent = custom })

		-- career stats
		UI.header("Estadísticas", { order = 1, right = UI.label("micro", "Temporada actual · partidas igualadas", { Size = UDim2.fromOffset(260, 16), TextXAlignment = Enum.TextXAlignment.Right }) }).Parent = right
		local grid = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = right })
		UI.new("UIGridLayout", { CellSize = UDim2.new(phone and 0.5 or 1 / 3, -8, 0, phone and 58 or 76), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		local fav, favK = "kite", -1
		for w, k in st.weaponKills do
			if k > favK then
				fav, favK = w, k
			end
		end
		local cells = {
			{ "Partidas", Util.num(st.matches), "play" },
			{ "Victorias", math.round(st.wins / math.max(1, st.matches) * 100) .. " %", "trophy" },
			{ "E / M", string.format("%.2f", st.kills / math.max(1, st.deaths)):gsub("%.", ","), "skull" },
			{ "Precisión", math.round(st.hits / math.max(1, st.shots) * 100) .. " %", "aim" },
			{ "Daño medio", Util.num(st.damage / math.max(1, st.matches)), "fire" },
			{ "Arma favorita", Catalog.get(fav).name, "armory" },
		}
		for i, c in cells do
			local cell = UI.surface({ LayoutOrder = i, Parent = grid }, { edge = C.ink700, pad = phone and 8 or 12, cut = 0.3 })
			UI.list("v", 2, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = cell
			local top = UI.box({ Size = UDim2.new(1, 0, 0, m.micro + 4), LayoutOrder = 1, Parent = cell })
			UI.list("h", 6).Parent = top
			UI.icon(c[3], 14, C.signal, { LayoutOrder = 1, Parent = top })
			UI.label("eyebrow", c[1], { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = top })
			UI.label("num", c[2], { TextSize = phone and m.h3 or m.h2, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, (phone and m.h3 or m.h2) * 1.15), Parent = cell })
		end

		-- history
		UI.header("Últimas partidas", { order = 3 }).Parent = right
		local hist = UI.surface({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = right }, { edge = C.ink700, pad = 12 })
		UI.list("v", 0).Parent = hist
		local head = UI.box({ Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, Parent = hist })
		local colsX = phone and { 0, 0.28, 0.66, 0.84 } or { 0, 0.2, 0.56, 0.72, 0.86 }
		local heads = phone and { "Resultado", "Modo · mapa", "E/M/A", "Puntos" } or { "Resultado", "Modo · mapa", "E / M / A", "Puntos", "Cuándo" }
		for i, h in heads do
			UI.label("eyebrow", h, { Size = UDim2.fromScale((colsX[i + 1] or 1) - colsX[i], 1), Position = UDim2.fromScale(colsX[i], 0), TextXAlignment = i >= 3 and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left, Parent = head })
		end
		for i, h in p.history do
			local row = UI.box({ Size = UDim2.new(1, 0, 0, phone and 34 or 40), LayoutOrder = i, Parent = hist })
			UI.divider({ Parent = row })
			local r = RESULT[h.result] or RESULT.draw
			local tag = UI.tag(r[1], r[2])
			tag.AnchorPoint = Vector2.new(0, 0.5)
			tag.Position = UDim2.fromScale(0, 0.5)
			tag.Parent = row
			local mode = World.mode(h.mode)
			UI.label("small", mode.name .. " · " .. World.map(h.map).name .. "  " .. h.scores[1] .. "–" .. h.scores[2], { Size = UDim2.fromScale(colsX[3] - colsX[2], 1), Position = UDim2.fromScale(colsX[2], 0), TextColor3 = C.paper, Parent = row })
			UI.label("mono", h.k .. " / " .. h.d .. " / " .. h.a, { Size = UDim2.fromScale(colsX[4] - colsX[3], 1), Position = UDim2.fromScale(colsX[3], 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.paper, Parent = row })
			UI.label("mono", Util.num(h.score), { Size = UDim2.fromScale((colsX[5] or 1) - colsX[4], 1), Position = UDim2.fromScale(colsX[4], 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
			if not phone then
				UI.label("micro", h.when, { Size = UDim2.fromScale(1 - colsX[5], 1), Position = UDim2.fromScale(colsX[5], 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
			end
		end
		return childScope
	end
	local current = render()
	scope:connect(Store.changed, function(a)
		if a.type == "EQUIP" or a.type == "MATCH_END" or a.type == "PURCHASE" or a.type == "RESET" or a.type == "CLAIM_MISSION" then
			current:destroy()
			current = render()
		end
	end)
end

return Profile
