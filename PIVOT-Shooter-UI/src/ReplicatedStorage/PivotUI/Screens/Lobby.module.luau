-- Lobby shell: top bar (brand, navigation, party state, credits, level, player), the tab host and the
-- first-visit intro. Tabs live in Screens/Tabs and are rebuilt on tab change (their scope is cleaned).
-- Keyboard: Q / E switch tabs, arrows + Enter navigate, Backspace closes dialogs.

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local PivotUI = script.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local World = require(PivotUI.Data.World)
local Stage = require(PivotUI.Match.Stage)
local Theme = require(PivotUI.Theme)

local C, F = UI.C, UI.F
local Lobby = {}

Lobby.tabs = {
	{ id = "home", label = "Inicio", icon = "home" },
	{ id = "play", label = "Jugar", icon = "play" },
	{ id = "armory", label = "Arsenal", icon = "armory" },
	{ id = "shop", label = "Tienda", icon = "shop" },
	{ id = "missions", label = "Misiones", icon = "missions" },
	{ id = "profile", label = "Perfil", icon = "profile" },
	{ id = "settings", label = "Ajustes", icon = "settings" },
}
local TAB_MODULE = { home = "Home", play = "Play", armory = "Armory", shop = "Shop", missions = "Missions", profile = "Profile", settings = "Settings" }

local function partyStatusText()
	local s = Store.state
	local mm = s.mm.status
	if mm == "searching" then
		return "Buscando partida", C.signal
	elseif mm == "found" or mm == "accepted" or mm == "loading" then
		return "Partida encontrada", C.ok
	elseif s.network ~= "online" then
		return "Sin conexión", C.bad
	end
	local n = #s.party + 1
	return (n > 1 and ("Grupo · " .. n .. "/4") or "En solitario") .. (s.meReady and "  ·  Listo" or ""), s.meReady and C.ok or C.steel2
end

function Lobby.build(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	local phone = UI.isPhone()
	local tablet = UI.layout == "tablet"
	local s = Store.state

	local stage = Stage.lobby(scope)
	local function refreshStage()
		stage.refresh(Store.state.loadout.primary, Store.finishOf(Store.state.loadout.primary))
	end
	refreshStage()

	-- backdrop: vignette + dim layer used by full-panel tabs
	local vig = UI.icon("vignette", 0, C.ink950, { Name = "Vignette", Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Stretch, ImageTransparency = 0.15, Parent = ctx.backdrop })
	local dim = UI.fill(C.ink950, { Name = "Dim", BackgroundTransparency = 1, Parent = ctx.backdrop })
	local topShade = UI.fill(C.ink950, { Name = "TopShade", Size = UDim2.new(1, 0, 0, m.topbar + 90), Parent = ctx.backdrop })
	UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.05, 1), Parent = topShade })

	---------------------------------------------------------------- top bar
	local top = UI.box({ Name = "TopBar", Size = UDim2.new(1, 0, 0, m.topbar), Parent = root })
	UI.pad(0, m.pad).Parent = top
	local left = UI.box({ Name = "Left", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = top })
	UI.list("h", phone and 8 or 18).Parent = left
	local brand = UI.box({ Name = "Brand", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = left })
	UI.list("h", 8).Parent = brand
	UI.icon("logo", phone and 22 or 28, C.signal, { LayoutOrder = 1, Parent = brand })
	UI.label("h2", "PIVOT", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextSize = phone and m.h3 + 2 or m.h2, LayoutOrder = 2, Parent = brand })

	local right = UI.box({ Name = "Right", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = top })
	UI.list("h", phone and 10 or 16, { HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent = right

	-- party / player state pill
	local statusPill = UI.surface({ Name = "Status", Size = UDim2.fromOffset(0, m.btnSm), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Visible = not phone }, { edge = C.ink600, pad = 10, cut = 0.25 })
	UI.pad(0, 12).Parent = statusPill
	UI.list("h", 8).Parent = statusPill
	local statusDot = UI.icon("dot", 10, C.ok, { LayoutOrder = 1, Parent = statusPill })
	local statusText = UI.label("small", "", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = C.paper, LayoutOrder = 2, Parent = statusPill })
	statusPill.Parent = right

	-- credits
	local credits = UI.credits(s.profile.credits, { textSize = phone and m.body or m.h3, order = 2 })
	credits.inst.Parent = right

	-- level + xp
	local lvl = UI.box({ Name = "Level", Size = UDim2.fromOffset(phone and 86 or 196, m.topbar - 16), LayoutOrder = 3 })
	UI.list("v", 4, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = lvl
	local lvlRow = UI.box({ Size = UDim2.new(1, 0, 0, m.small + 4), LayoutOrder = 1, Parent = lvl })
	local lvlText = UI.label("eyebrow", "", { TextColor3 = C.paper, TextSize = m.small, Size = UDim2.fromScale(phone and 1 or 0.38, 1), Parent = lvlRow })
	local xpText = UI.label("mono", "", { TextSize = m.micro, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(0.62, 1), Position = UDim2.fromScale(0.38, 0), Visible = not phone, Parent = lvlRow })
	local xpBar = UI.bar({ height = 4, color = C.signal, order = 2 })
	xpBar.inst.Parent = lvl
	lvl.Parent = right

	-- player chip: avatar + name (opens profile)
	local chip = UI.new("ImageButton", { Name = "PlayerChip", BackgroundTransparency = 1, ImageTransparency = 1, AutoButtonColor = false, Size = UDim2.fromOffset(0, m.topbar - 14), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 4, Parent = right })
	UI.list("h", 10).Parent = chip
	UI.avatar({ userId = Players.LocalPlayer.UserId > 0 and Players.LocalPlayer.UserId or nil, name = s.profile.name, size = m.topbar - 18, order = 1, ring = C.ink600 }).Parent = chip
	local nameLabel = UI.label("title", s.profile.name, { Size = UDim2.fromOffset(phone and 0 or 120, m.topbar - 14), TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 2, Visible = not phone and not tablet, Parent = chip })

	local gear = UI.iconButton({ icon = "settings", label = "Ajustes", order = 5, size = m.btnSm, onClick = function()
		ctx.go("settings")
	end })
	gear.inst.Parent = right

	local function refreshTop(animate)
		local st = Store.state
		local text, color = partyStatusText()
		statusText.Text = text
		statusDot.ImageColor3 = color
		if credits.value ~= st.profile.credits then
			credits.set(st.profile.credits, animate)
		end
		lvlText.Text = UI.upper("Nivel " .. st.profile.level)
		xpText.Text = Util.num(st.profile.xp) .. " / " .. Util.num(Store.xpToNext(st.profile.level)) .. " XP"
		xpBar.set(st.profile.xp, Store.xpToNext(st.profile.level), animate)
		nameLabel.Text = st.profile.name
	end
	refreshTop(false)

	---------------------------------------------------------------- navigation
	local navItems = {}
	local nav
	if phone then
		-- icon rail on the left (thumb reach, frees the full width for content)
		nav = UI.surface({ Name = "Nav", Size = UDim2.new(0, 62, 1, -(m.topbar + m.pad)), Position = UDim2.fromOffset(m.pad, m.topbar), Parent = root }, { edge = C.ink700, pad = 3, cut = 0.3 })
		UI.list("v", 0, { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = nav
	else
		nav = UI.box({ Name = "Nav", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = left })
		UI.list("h", tablet and 2 or 4).Parent = nav
		UI.keycap("Q", { LayoutOrder = 0, Parent = nav })
	end
	for i, tab in Lobby.tabs do
		if not (tab.id == "settings" and not phone) then -- desktop/tablet reach settings from the gear
			local b = UI.new("ImageButton", {
				Name = "Tab_" .. tab.id,
				BackgroundTransparency = 1,
				ImageColor3 = C.ink700,
				ImageTransparency = 1,
				AutoButtonColor = false,
				-- phone rail: seven items share the rail height so it never overflows short screens
				Size = phone and UDim2.new(0, 56, 1 / 7, -1) or UDim2.fromOffset(0, m.topbar),
				AutomaticSize = phone and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
				LayoutOrder = i,
				Parent = nav,
			})
			require(PivotUI.Icons).apply(b, "rounded")
			b.SliceScale = 0.25
			local inner = UI.box({ Size = phone and UDim2.fromScale(1, 1) or UDim2.fromScale(0, 1), AutomaticSize = phone and Enum.AutomaticSize.None or Enum.AutomaticSize.X, Parent = b })
			if phone then
				UI.list("v", 2, { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = inner
			else
				UI.pad(0, tablet and 8 or 12).Parent = inner
				UI.list("h", 7).Parent = inner
			end
			local icon = UI.icon(tab.icon, phone and 17 or 18, C.steel, { LayoutOrder = 1, Parent = inner })
			local label = UI.label(phone and "micro" or "h3", tab.label, {
				Size = phone and UDim2.new(1, 0, 0, 11) or UDim2.fromScale(0, 1),
				AutomaticSize = phone and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
				TextXAlignment = phone and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
				TextSize = phone and 9 or (tablet and m.small + 1 or m.body + 1),
				FontFace = phone and F.bodySemi or F.displayMedium,
				TextColor3 = C.steel,
				LayoutOrder = 2,
				Visible = not (tablet and false),
				Parent = inner,
			})
			local bar = UI.fill(C.signal, phone and { Name = "On", Size = UDim2.new(0, 3, 0.6, 0), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -4, 0.5, 0), Visible = false, Parent = b }
				or { Name = "On", Size = UDim2.new(1, -16, 0, 3), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Visible = false, Parent = b })
			local badge = UI.new("Frame", { Name = "Badge", BackgroundColor3 = C.brass, Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = phone and UDim2.new(1, -10, 0, 10) or UDim2.new(1, -4, 0.3, 0), Visible = false, ZIndex = 4, Parent = b })
			UI.corner(9).Parent = badge
			local badgeText = UI.label("micro", "", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.signalInk, FontFace = F.bodyHeavy, ZIndex = 5, Parent = badge })
			local ring = UI.shape("roundedStroke", C.paper, { Name = "Focus", SliceScale = 0.25, Visible = false, ZIndex = 3, Parent = b })
			UI.ownFocus(b)
			local item = { id = tab.id, button = b, icon = icon, label = label, bar = bar, badge = badge, badgeText = badgeText }
			navItems[tab.id] = item
			b.MouseEnter:Connect(function()
				if Store.state.tab ~= tab.id then
					label.TextColor3 = C.paper
					icon.ImageColor3 = C.paper
				end
			end)
			b.MouseLeave:Connect(function()
				if Store.state.tab ~= tab.id then
					label.TextColor3 = C.steel
					icon.ImageColor3 = C.steel
				end
			end)
			b.SelectionGained:Connect(function()
				ring.Visible = true
			end)
			b.SelectionLost:Connect(function()
				ring.Visible = false
			end)
			b.Activated:Connect(function()
				ctx.go(tab.id)
			end)
		end
	end
	if not phone then
		UI.keycap("E", { LayoutOrder = 99, Parent = nav })
	end

	local function paintNav()
		local cur = Store.state.tab
		for id, it in navItems do
			local on = id == cur
			it.label.TextColor3 = on and C.paper or C.steel
			it.icon.ImageColor3 = on and C.signal or C.steel
			it.bar.Visible = on
			it.button.ImageTransparency = (on and phone) and 0 or 1
		end
		local claim = Store.claimableCount()
		local mi = navItems.missions
		if mi then
			mi.badge.Visible = claim > 0
			mi.badgeText.Text = tostring(claim)
		end
	end

	---------------------------------------------------------------- tab host
	local host = UI.box({
		Name = "Content",
		Size = phone and UDim2.new(1, -(62 + m.pad * 2 + m.gap), 1, -(m.topbar + m.pad)) or UDim2.new(1, -2 * m.pad, 1, -(m.topbar + m.pad)),
		Position = phone and UDim2.fromOffset(62 + m.pad + m.gap, m.topbar) or UDim2.fromOffset(m.pad, m.topbar + 4),
		Parent = root,
	})
	local tabScope = scope:child()
	local guard = nil -- function(proceed) used by Settings when it has unapplied changes
	local tabApi = {}
	local function mountTab()
		tabScope:clean()
		for _, c in host:GetChildren() do
			c:Destroy()
		end
		guard = nil
		local id = Store.state.tab
		local full = id ~= "home"
		Util.tween(dim, 0.25, { BackgroundTransparency = full and 0.28 or 1 })
		vig.ImageTransparency = full and 0.0 or 0.15
		stage.focus("center")
		stage.show(not full)
		local ok, err = pcall(function()
			require(PivotUI.Screens.Tabs:WaitForChild(TAB_MODULE[id])).build({
				root = host,
				scope = tabScope,
				go = ctx.go,
				app = ctx.app,
				stage = stage,
				setGuard = function(fn)
					guard = fn
				end,
				params = tabApi.params or {},
			})
			tabApi.params = nil
		end)
		if not ok then
			warn("[PIVOT] tab " .. id .. " failed: " .. tostring(err))
			UI.emptyState({ icon = "warning", color = C.warn, title = "No se pudo abrir esta sección", body = "Ha ocurrido un error al construir la pantalla. Detalle en Output.", action = "Volver al inicio", onAction = function()
				ctx.go("home")
			end, Parent = host }).Parent = host
		end
		paintNav()
	end

	-- navigation entry point shared with every tab: go(tabId, params)
	function ctx.go(id: string, params)
		if id == Store.state.tab then
			return
		end
		local function proceed()
			tabApi.params = params
			UI.sfx("click")
			Store.dispatch({ type = "NAV", tab = id })
		end
		if guard then
			guard(proceed)
		else
			proceed()
		end
	end
	ctx.app.onBack = function()
		if Store.state.tab ~= "home" then
			ctx.go("home")
		end
	end
	scope:add(function()
		ctx.app.onBack = nil
	end)

	local order = {}
	for _, tab in Lobby.tabs do
		table.insert(order, tab.id)
	end
	scope:connect(UserInputService.InputBegan, function(input, processed)
		if processed or UI.modalOpen() or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.E then
			local i = table.find(order, Store.state.tab) or 1
			local j = ((i - 1 + (input.KeyCode == Enum.KeyCode.E and 1 or -1)) % #order) + 1
			ctx.go(order[j])
		end
	end)

	scope:connect(Store.changed, function(action)
		local t = action.type
		if t == "NAV" then
			mountTab()
		elseif t == "EQUIP" or t == "SET_FINISH" or t == "RESET" then
			refreshStage()
		end
		refreshTop(true)
		paintNav()
	end)

	mountTab()
	require(PivotUI.Screens.Matchmaking).attach({ root = root, scope = scope, go = ctx.go, app = ctx.app })

	---------------------------------------------------------------- first visit intro
	if not s.introSeen then
		scope:delay(0.45, function()
			if Store.state.introSeen or UI.modalOpen() then
				return
			end
			UI.modal({
				title = "Bienvenido a PIVOT",
				eyebrow = "Primera visita",
				width = 560,
				onClose = function()
					Store.dispatch({ type = "DISMISS_INTRO" })
				end,
				build = function(body)
					UI.list("v", m.gap).Parent = body
					UI.para("Partidas cortas de 4 contra 4 entre contenedores y grúas. Esto es lo básico para empezar:", { LayoutOrder = 1, Parent = body })
					local steps = {
						{ "play", "Jugar", "Elige modo y mapa, prepárate con tu grupo y busca partida." },
						{ "armory", "Arsenal", "Equipa armas y acabados; los verás en el lobby y en el HUD." },
						{ "missions", "Misiones", "Las partidas hacen avanzar misiones que dan XP y créditos." },
					}
					for i, st in steps do
						local row = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 + i, Parent = body })
						UI.list("h", 12, { VerticalAlignment = Enum.VerticalAlignment.Top }).Parent = row
						local tile = UI.surface({ Size = UDim2.fromOffset(40, 40), LayoutOrder = 1, Parent = row }, { edge = C.ink600, pad = 0, cut = 0.25 })
						UI.icon(st[1], 20, C.signal, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = tile })
						local txt = UI.box({ Size = UDim2.new(1, -52, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = row })
						UI.list("v", 2).Parent = txt
						UI.label("title", st[2], { LayoutOrder = 1, Parent = txt })
						UI.para(st[3], { LayoutOrder = 2, TextSize = m.small, Parent = txt })
					end
					if not UI.touch then
						UI.label("mono", "Q / E cambia de sección  ·  flechas + Intro navegan  ·  Retroceso cierra", { TextSize = m.micro, LayoutOrder = 9, Parent = body })
					end
				end,
				actions = {
					{ text = "Entendido", variant = "primary", icon = "check", onClick = function()
						UI.closeModalSilently()
					end },
				},
			})
		end)
	end
end

return Lobby
