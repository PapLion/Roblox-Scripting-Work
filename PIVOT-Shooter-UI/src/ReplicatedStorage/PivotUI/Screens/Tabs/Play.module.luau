-- Play: mode, map, party and the search. Mode/map are locked while a search or match load is running.
-- desktop/tablet: modes | maps + mode facts | party + play     phone: modes row, maps row, play

local PivotUI = script.Parent.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local World = require(PivotUI.Data.World)
local Parts = require(PivotUI.Screens.Parts)
local Icons = require(PivotUI.Icons)

local C, F = UI.C, UI.F
local Play = {}

local MODE_ICON = { teams = "users", duel = "duel", training = "target" }

-- Selectable card (mode or map). Returns { inst, selected, disabled, paint() }.
local function choiceCard(opts)
	local b = UI.new("ImageButton", { Name = opts.name, BackgroundTransparency = 1, ImageColor3 = C.ink600, AutoButtonColor = false, Size = opts.size, LayoutOrder = opts.order })
	Icons.apply(b, "panelTone")
	b.SliceScale = 0.4
	local sel = UI.shape("panelCutStroke", C.signal, { Name = "Selected", SliceScale = 0.4, Visible = false, ZIndex = 4, Parent = b })
	local hover = UI.shape("panelCutStroke", C.steel, { Name = "Hover", SliceScale = 0.4, Visible = false, ZIndex = 3, Parent = b })
	local check = UI.fill(C.signal, { Name = "Check", Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Visible = false, ZIndex = 5, Parent = b })
	UI.corner(11).Parent = check
	UI.icon("check", 14, C.signalInk, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 6, Parent = check })
	local api = { inst = b, selected = false, disabled = false }
	function api.paint()
		sel.Visible = api.selected
		check.Visible = api.selected
		b.ImageColor3 = api.selected and C.signal:Lerp(C.ink600, 0.78) or C.ink600
		b.Interactable = not api.disabled
		b.ImageTransparency = api.disabled and not api.selected and 0.5 or 0
	end
	for _, ev in { "MouseEnter", "SelectionGained" } do
		b[ev]:Connect(function()
			hover.Visible = not api.disabled
		end)
	end
	for _, ev in { "MouseLeave", "SelectionLost" } do
		b[ev]:Connect(function()
			hover.Visible = false
		end)
	end
	b.Activated:Connect(function()
		if not api.disabled and not api.selected then
			UI.sfx("click")
			opts.onPick()
		end
	end)
	return api
end

function Play.build(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	local phone = UI.isPhone()
	local tablet = UI.layout == "tablet"

	local modeCards, mapCards = {}, {}
	local modesCol, mapsCol, sideCol
	if phone then
		local main = UI.box({ Size = UDim2.new(0.62, -m.gap, 1, -m.pad), Parent = root })
		UI.list("v", m.gapSm).Parent = main
		UI.header("Modo", { order = 1 }).Parent = main
		modesCol = UI.box({ Size = UDim2.new(1, 0, 0, 78), LayoutOrder = 2, Parent = main })
		UI.list("h", 6, { HorizontalFlex = Enum.UIFlexAlignment.Fill }).Parent = modesCol
		UI.header("Mapa", { order = 3 }).Parent = main
		mapsCol = UI.box({ Size = UDim2.new(1, 0, 1, -(78 + 2 * (m.h3 * 1.35) + 3 * m.gapSm)), LayoutOrder = 4, Parent = main })
		UI.list("h", 6, { HorizontalFlex = Enum.UIFlexAlignment.Fill }).Parent = mapsCol
		sideCol = UI.scroll({ Size = UDim2.new(0.38, 0, 1, -m.pad), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), ScrollBarThickness = 0, Parent = root })
		UI.list("v", m.gapSm).Parent = sideCol
	else
		local modesW = tablet and 0.3 or 0.26
		local sideW = tablet and 0.32 or 0.27
		local left = UI.box({ Name = "Modes", Size = UDim2.new(modesW, 0, 1, -m.pad), Parent = root })
		UI.list("v", m.gap).Parent = left
		UI.header("Modo de juego", { index = "01", order = 1 }).Parent = left
		modesCol = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = left })
		UI.list("v", m.gapSm).Parent = modesCol
		local mid = UI.box({ Name = "Maps", Size = UDim2.new(1 - modesW - sideW, -m.gap * 2, 1, -m.pad), Position = UDim2.new(modesW, m.gap, 0, 0), Parent = root })
		UI.list("v", m.gap).Parent = mid
		UI.header("Mapa", { index = "02", order = 1 }).Parent = mid
		mapsCol = UI.box({ Size = UDim2.new(1, 0, 0.62, 0), LayoutOrder = 2, Parent = mid })
		UI.list("h", m.gapSm, { HorizontalFlex = Enum.UIFlexAlignment.Fill }).Parent = mapsCol
		local facts = UI.surface({ Name = "Facts", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = mid }, { edge = C.ink700, pad = 14 })
		UI.list("h", m.gap, { HorizontalFlex = Enum.UIFlexAlignment.Fill }).Parent = facts
		local factLabels = {}
		for i, f in { { "flag", "Objetivo" }, { "users", "Jugadores" }, { "clock", "Duración" } } do
			local cell = UI.box({ Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = facts })
			UI.flex("fill").Parent = cell
			UI.list("v", 4).Parent = cell
			local top = UI.box({ Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Parent = cell })
			UI.list("h", 6).Parent = top
			UI.icon(f[1], 14, C.signal, { LayoutOrder = 1, Parent = top })
			UI.label("eyebrow", f[2], { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = top })
			factLabels[i] = UI.para("", { TextColor3 = C.paper, FontFace = F.bodySemi, TextSize = m.small + 1, LayoutOrder = 2, Parent = cell })
		end
		local function refreshFacts()
			local mode = World.mode(Store.state.play.mode)
			factLabels[1].Text = mode.objective
			factLabels[2].Text = mode.players
			factLabels[3].Text = mode.length .. (mode.counts and "  ·  da XP y créditos" or "  ·  sin recompensas")
		end
		refreshFacts()
		scope:connect(Store.changed, function(a)
			if a.type == "SET_MODE" then
				refreshFacts()
			end
		end)
		sideCol = UI.scroll({ Name = "Side", Size = UDim2.new(sideW, 0, 1, -m.pad), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), ScrollBarThickness = 0, Parent = root })
		UI.list("v", m.gap).Parent = sideCol
	end

	for i, mode in World.modes do
		local h = phone and 78 or (tablet and 96 or 104)
		local card = choiceCard({ name = "Mode_" .. mode.id, order = i, size = phone and UDim2.fromScale(0, 1) or UDim2.new(1, 0, 0, h), onPick = function()
			Store.dispatch({ type = "SET_MODE", mode = mode.id })
		end })
		if phone then
			UI.flex("fill").Parent = card.inst
		end
		local inner = UI.box({ Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = card.inst })
		UI.pad(phone and 8 or 14).Parent = inner
		UI.list(phone and "v" or "h", phone and 2 or 14, { VerticalAlignment = phone and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Center }).Parent = inner
		local tile = UI.fill(C.ink800, { Size = UDim2.fromOffset(phone and 26 or 46, phone and 26 or 46), LayoutOrder = 1, Parent = inner })
		UI.corner(5).Parent = tile
		UI.icon(MODE_ICON[mode.id], phone and 16 or 24, C.signal, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = tile })
		local txt = UI.box({ Size = phone and UDim2.new(1, 0, 0, 0) or UDim2.new(1, -60 - 24, 1, 0), AutomaticSize = phone and Enum.AutomaticSize.Y or Enum.AutomaticSize.None, LayoutOrder = 2, Parent = inner })
		UI.list("v", 2, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = txt
		UI.label("h3", mode.name, { LayoutOrder = 1, TextSize = phone and m.small + 1 or m.h3, Parent = txt })
		UI.label("micro", mode.short .. "  ·  " .. mode.length, { LayoutOrder = 2, TextColor3 = C.signal2, Parent = txt })
		if not phone then
			local d = UI.para(mode.desc, { TextSize = m.micro + 1, LayoutOrder = 3, Parent = txt })
			d.TextTruncate = Enum.TextTruncate.AtEnd
			d.AutomaticSize = Enum.AutomaticSize.None
			d.Size = UDim2.new(1, 0, 0, (m.micro + 1) * 2.4)
		end
		card.inst.Parent = modesCol
		modeCards[mode.id] = card
	end

	local function renderMaps()
		for _, c in mapsCol:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		table.clear(mapCards)
		for i, map in World.mapsFor(Store.state.play.mode) do
			local card = choiceCard({ name = "Map_" .. map.id, order = i, size = UDim2.fromScale(0, 1), onPick = function()
				Store.dispatch({ type = "SET_MAP", map = map.id })
			end })
			UI.flex("fill").Parent = card.inst
			UI.new("UISizeConstraint", { MaxSize = Vector2.new(phone and 200 or 300, math.huge), Parent = card.inst })
			local inner = UI.box({ Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = card.inst })
			UI.pad(phone and 6 or 10).Parent = inner
			Parts.mapPreview(map.id, { Size = UDim2.new(1, 0, 1, phone and -40 or -(m.h3 * 1.35 + m.micro * 3.6 + 16)), ZIndex = 2, Parent = inner })
			local txt = UI.box({ Size = UDim2.new(1, 0, 0, phone and 34 or (m.h3 * 1.35 + m.micro * 3.6 + 8)), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = inner })
			UI.list("v", 2).Parent = txt
			local title = UI.label("h3", map.name, { LayoutOrder = 1, TextSize = phone and m.small + 1 or m.h3, Parent = txt })
			-- narrow tablet cards: the map name shrinks a little instead of ending in "…"
			title.TextScaled = true
			title.TextTruncate = Enum.TextTruncate.None
			UI.new("UITextSizeConstraint", { MaxTextSize = phone and m.small + 1 or m.h3, MinTextSize = 11, Parent = title })
			local d = UI.para(map.desc, { TextSize = m.micro, LayoutOrder = 2, Visible = not phone, Parent = txt })
			d.AutomaticSize = Enum.AutomaticSize.None
			-- room for three lines: on tablet the cards are narrow and the copy wraps once more
			d.Size = UDim2.new(1, 0, 0, m.micro * 3.6)
			d.TextTruncate = Enum.TextTruncate.AtEnd
			card.inst.Parent = mapsCol
			mapCards[map.id] = card
		end
	end

	Parts.partyPanel(scope, { order = 1 }).Parent = sideCol
	local play = Parts.playButton(scope, { order = 2 })
	play.inst.Parent = sideCol
	local lockNote = UI.label("small", "", { LayoutOrder = 3, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextColor3 = C.steel, Parent = sideCol })

	local function paint()
		local s = Store.state
		local busy = Store.mmBusy()
		for id, card in modeCards do
			card.selected = id == s.play.mode
			card.disabled = busy
			card.paint()
		end
		for id, card in mapCards do
			card.selected = id == s.play.map
			card.disabled = busy
			card.paint()
		end
		if busy then
			lockNote.Text = "Modo y mapa bloqueados mientras buscas partida. Cancela la búsqueda para cambiarlos."
		elseif World.mode(s.play.mode).maxParty == 1 and #s.party > 0 then
			lockNote.Text = "Modo individual: tu grupo te esperará en el lobby."
		else
			lockNote.Text = ""
		end
		lockNote.Visible = lockNote.Text ~= ""
	end
	renderMaps()
	paint()
	scope:connect(Store.changed, function(a)
		if a.type == "SET_MODE" then
			renderMaps()
		end
		paint()
	end)
end

return Play
