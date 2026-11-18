-- Lobby home. The centre stays open for the equipped weapon on the 3D stand.
-- desktop/tablet: player + party | weapon, loadout, mode and Play | missions + news
-- phone: party (compact) | weapon | mode, Play and missions

local UserInputService = game:GetService("UserInputService")

local PivotUI = script.Parent.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local World = require(PivotUI.Data.World)
local Catalog = require(PivotUI.Data.Catalog)
local Parts = require(PivotUI.Screens.Parts)

local C, F = UI.C, UI.F
local Home = {}

local MODE_ICON = { teams = "users", duel = "duel", training = "target" }

-- Current mode + map, opens the Play tab.
local function modeChip(ctx, order)
	local m = UI.m
	local phone = UI.isPhone()
	local b = UI.new("ImageButton", { Name = "ModeChip", BackgroundTransparency = 1, ImageColor3 = C.ink600, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, phone and 52 or 62), LayoutOrder = order })
	require(PivotUI.Icons).apply(b, "panelTone")
	b.SliceScale = 0.35
	UI.pad(0, 12).Parent = b
	UI.list("h", 12).Parent = b
	local iconTile = UI.fill(C.ink800, { Size = UDim2.fromOffset(phone and 34 or 40, phone and 34 or 40), LayoutOrder = 1, Parent = b })
	UI.corner(4).Parent = iconTile
	local icon = UI.icon("users", 20, C.signal, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = iconTile })
	local txt = UI.box({ Size = UDim2.new(1, -(phone and 34 or 40) - 40, 1, 0), LayoutOrder = 2, Parent = b })
	UI.list("v", 0, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = txt
	local title = UI.label("h3", "", { LayoutOrder = 1, Parent = txt })
	local sub = UI.label("micro", "", { LayoutOrder = 2, Parent = txt })
	UI.icon("chevronRight", 18, C.steel, { LayoutOrder = 3, Parent = b })
	local ring = UI.shape("panelCutStroke", C.signal, { SliceScale = 0.35, Visible = false, ZIndex = 3, Parent = b })
	local function refresh()
		local s = Store.state
		local mode = World.mode(s.play.mode)
		local map = World.map(s.play.map)
		title.Text = UI.upper(mode.name .. "  ·  " .. map.name)
		-- the phone chip is narrow: the action shortens to one word (the chevron already marks it)
		sub.Text = mode.short .. "  ·  " .. mode.length .. "  ·  " .. (UI.isPhone() and "Cambiar" or "Cambiar modo o mapa")
		require(PivotUI.Icons).apply(icon, MODE_ICON[mode.id])
		b.Interactable = not Store.mmBusy()
		b.ImageTransparency = Store.mmBusy() and 0.5 or 0
	end
	for _, ev in { "MouseEnter", "SelectionGained" } do
		b[ev]:Connect(function()
			ring.Visible = true
		end)
	end
	for _, ev in { "MouseLeave", "SelectionLost" } do
		b[ev]:Connect(function()
			ring.Visible = false
		end)
	end
	b.Activated:Connect(function()
		ctx.go("play")
	end)
	refresh()
	ctx.scope:connect(Store.changed, refresh)
	return b
end

-- Daily missions summary with direct claim.
local function missionsPanel(ctx, order, compact)
	local m = UI.m
	local panel = UI.surface({ Name = "Missions", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, { edge = C.ink700, pad = compact and 10 or 14 })
	UI.list("v", compact and 6 or 10).Parent = panel
	local claimTag = UI.box({ Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X })
	local head = UI.header("Misiones diarias", { order = 1, right = claimTag })
	head.Parent = panel
	local list = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = panel })
	UI.list("v", compact and 6 or 10).Parent = list
	local all = UI.button({ text = "Ver todas las misiones", variant = "ghost", size = "sm", icon = "arrowRight", width = UDim.new(1, 0), order = 3, onClick = function()
		ctx.go("missions")
	end })
	all.inst.Parent = panel
	local function render()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, c in claimTag:GetChildren() do
			c:Destroy()
		end
		local n = Store.claimableCount()
		if n > 0 then
			local t = UI.tag(Util.plural(n, "{n} lista", "{n} listas"), C.brass, { icon = "gift" })
			t.Parent = claimTag
		end
		local i = 0
		for _, mission in World.missions do
			if mission.period == "daily" then
				i += 1
				local st = Store.missionState(mission)
				-- a claimable row on a phone gets room for a two-line title next to the button
				local tall = compact and st.claimable
				local row = UI.box({ Size = UDim2.new(1, 0, 0, tall and 46 or (compact and 34 or 42)), LayoutOrder = i, Parent = list })
				local txt = UI.box({ Size = UDim2.new(1, st.claimable and -(compact and 108 or 112) or -58, 1, 0), Parent = row })
				UI.list("v", 5, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = txt
				local title = UI.label("small", mission.title, { LayoutOrder = 1, TextColor3 = st.claimed and C.steel or C.paper, Parent = txt })
				if tall then
					title.TextWrapped = true
					title.TextTruncate = Enum.TextTruncate.None
					title.AutomaticSize = Enum.AutomaticSize.Y
					title.Size = UDim2.new(1, 0, 0, 0)
					title.LineHeight = 0.95
				end
				local bar = UI.bar({ height = 4, value = st.progress, max = mission.target, color = st.claimed and C.ink600 or (st.done and C.brass or C.signal), order = 2 })
				bar.inst.Parent = txt
				if st.claimable then
					local claim = UI.button({ text = "Reclamar", variant = "claim", size = "sm", width = UDim.new(0, compact and 100 or 104), onClick = function(api)
						local ok, info = Store.dispatch({ type = "CLAIM_MISSION", id = mission.id })
						if ok then
							UI.sfx("reward")
							UI.toast("Recompensa reclamada: " .. Store.rewardText(mission), "reward")
						elseif info.reason == "offline" then
							UI.toast("Sin conexión: no se puede reclamar ahora.", "bad")
						end
					end })
					claim.inst.AnchorPoint = Vector2.new(1, 0.5)
					claim.inst.Position = UDim2.fromScale(1, 0.5)
					claim.inst.Parent = row
				else
					local right = UI.label("mono", st.claimed and "Hecha" or (st.progress .. "/" .. mission.target), { Size = UDim2.new(0, 52, 1, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = st.claimed and C.ok or C.steel2, Parent = row })
				end
			end
		end
	end
	render()
	ctx.scope:connect(Store.changed, function(a)
		if a.type == "CLAIM_MISSION" or a.type == "MATCH_END" or a.type == "RESET" or a.type == "DEMO_COMPLETE_MISSIONS" or a.type == "SET_FINISH" or a.type == "EQUIP" then
			render()
		end
	end)
	return panel
end

-- Featured event + compact news list.
local function newsPanel(ctx, order, featuredOnly)
	local m = UI.m
	local panel = UI.surface({ Name = "News", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, { edge = C.ink700, pad = 14 })
	UI.list("v", 10).Parent = panel
	UI.header("Novedades", { order = 1 }).Parent = panel
	local f = World.news[1]
	-- grows with the copy (never below 104) so the last line is never clipped
	local feat = UI.new("ImageButton", { Name = "Featured", BackgroundTransparency = 1, ImageColor3 = C.ink600, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ClipsDescendants = true, Parent = panel })
	UI.new("UISizeConstraint", { MinSize = Vector2.new(0, 104), Parent = feat })
	require(PivotUI.Icons).apply(feat, "panelTone")
	feat.SliceScale = 0.35
	local plan = Parts.mapPreview("dock9", { Size = UDim2.fromOffset(96, 92), Position = UDim2.new(1, -102, 0, 6), Parent = feat })
	local txt = UI.box({ Size = UDim2.new(1, -120, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = feat })
	UI.pad(10, 0, 10, 12).Parent = txt
	UI.list("v", 4).Parent = txt
	local tagRow = UI.box({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = txt })
	UI.list("h", 6).Parent = tagRow
	UI.tag("Evento", C.signal, { solid = true, icon = "sparkle", order = 1 }).Parent = tagRow
	UI.label("micro", f.date, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = tagRow })
	UI.label("title", f.title, { LayoutOrder = 2, Parent = txt })
	UI.para(f.body, { TextSize = m.micro + 1, LayoutOrder = 3, Parent = txt })
	feat.Activated:Connect(function()
		Store.dispatch({ type = "SET_MODE", mode = "teams" })
		Store.dispatch({ type = "SET_MAP", map = "dock9" })
		ctx.go("play")
	end)
	if not featuredOnly then
		for i = 2, #World.news do
			local n = World.news[i]
			local row = UI.box({ Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1 + i, Parent = panel })
			UI.list("v", 0, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = row
			local top = UI.box({ Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = row })
			UI.list("h", 6).Parent = top
			UI.label("eyebrow", n.tag, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = C.signal, LayoutOrder = 1, Parent = top })
			UI.label("micro", n.date, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = top })
			UI.label("small", n.title, { LayoutOrder = 2, TextColor3 = C.paper, Parent = row })
		end
	end
	return panel
end

function Home.build(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	local phone = UI.isPhone()
	local tablet = UI.layout == "tablet"
	local colW = phone and 0.34 or (tablet and 0.3 or 0.25)
	local colMax = phone and 260 or 360

	local left = UI.scroll({ Name = "Left", Size = UDim2.new(colW, 0, 1, -m.pad), ScrollBarThickness = 0, Parent = root })
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(colMax, math.huge), Parent = left })
	UI.list("v", m.gap).Parent = left
	local right = UI.scroll({ Name = "Right", Size = UDim2.new(colW, 0, 1, -m.pad), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), ScrollBarThickness = 0, Parent = root })
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(colMax, math.huge), Parent = right })
	UI.list("v", m.gap).Parent = right

	if not phone then
		Parts.playerCard(scope, { order = 1 }).Parent = left
	end
	Parts.partyPanel(scope, { order = 2 }).Parent = left

	if phone then
		modeChip(ctx, 1).Parent = right
		local play = Parts.playButton(scope, { order = 2 })
		play.inst.Parent = right
		missionsPanel(ctx, 3, true).Parent = right
	else
		missionsPanel(ctx, 1, false).Parent = right
		newsPanel(ctx, 2, tablet).Parent = right
		-- centre column: loadout + mode + play anchored to the bottom
		local center = UI.box({ Name = "Center", Size = UDim2.new(1 - colW * 2, -m.gap * 4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -m.pad), Parent = root })
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(600, math.huge), Parent = center })
		UI.list("v", m.gapSm + 2).Parent = center
		local eq = UI.box({ Size = UDim2.new(1, 0, 0, m.micro + 6), LayoutOrder = 1, Parent = center })
		UI.list("h", 8).Parent = eq
		UI.label("eyebrow", "Equipamiento", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = eq })
		UI.label("micro", "·  elige un hueco para cambiarlo", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = eq })
		Parts.loadoutStrip(scope, { order = 2, height = tablet and 76 or 88, onSlot = function(slot)
			ctx.go("armory", { slot = slot })
		end }).Parent = center
		modeChip(ctx, 3).Parent = center
		local play = Parts.playButton(scope, { order = 4 })
		play.inst.Parent = center
		-- Enter starts the main action from the home screen
		scope:connect(UserInputService.InputBegan, function(input, processed)
			if processed or UI.modalOpen() then
				return
			end
			if input.KeyCode == Enum.KeyCode.Return and not game:GetService("GuiService").SelectedObject then
				play.activate()
			end
		end)
	end
end

return Home
