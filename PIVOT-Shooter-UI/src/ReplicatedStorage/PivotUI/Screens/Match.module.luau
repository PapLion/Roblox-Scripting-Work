-- Match HUD over the 3D stage. The simulation (Match.Engine) owns the rules; this screen renders it and
-- feeds it input. Layout: score + timer (top centre), kill feed (top right), notices (upper centre),
-- crosshair + hit/kill feedback (centre), vitals (bottom left), weapon + ammo (bottom right),
-- touch cluster (right, only in touch mode), scoreboard / pause / death / spectator overlays.
-- Keys: click or Space fire, right click aim, R reload, 1/2 or wheel switch, G support, Tab (hold)
-- scoreboard, P pause. Escape stays with Roblox (its own menu).

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local PivotUI = script.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local World = require(PivotUI.Data.World)
local Catalog = require(PivotUI.Data.Catalog)
local Engine = require(PivotUI.Match.Engine)
local Stage = require(PivotUI.Match.Stage)
local Theme = require(PivotUI.Theme)
local Icons = require(PivotUI.Icons)

local C, F = UI.C, UI.F
local Match = {}

local TONE = { good = C.ok, bad = C.bad, warn = C.warn, info = C.paper }

local function plate(props, opts)
	return UI.surface(props, { edge = (opts and opts.edge) or C.ink600, pad = (opts and opts.pad) or 10, cut = (opts and opts.cut) or 0.3 })
end

function Match.build(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	local app = ctx.app
	local s = Store.state
	local phone = UI.isPhone()
	local touch = UI.touch
	local settings = s.settings
	local palette = Theme.teamPalettes[settings.accessibility.colorblind and "colorblind" or "default"]
	local ALLY, ENEMY = palette.ally, palette.enemy

	local config = s.match
	local match = Engine.new(config)
	local mode = World.mode(config.mode)
	local map = World.map(config.map)
	local training = mode.id == "training"
	local stage = Stage.match(scope, { mode = mode.id, palette = settings.accessibility.colorblind and "colorblind" or "default" })

	-- hand-off from the map loading card
	if app.mapLoading then
		local card = app.mapLoading
		app.mapLoading = nil
		task.delay(0.35, function()
			if card.Parent then
				card:Destroy()
			end
		end)
	end
	scope:add(function()
		if app.mapLoading then
			app.mapLoading:Destroy()
			app.mapLoading = nil
		end
	end)

	local hud = UI.box({ Name = "HUD", Parent = root })
	UI.new("UIScale", { Scale = settings.interface.hudScale / 100, Parent = hud })
	-- keep the scaled HUD inside the safe area
	local k = settings.interface.hudScale / 100
	hud.Size = UDim2.fromScale(1 / k, 1 / k)
	local pad = phone and 10 or 18

	-- full-screen effect layers (backdrop gui, under the HUD)
	local vignette = UI.icon("vignette", 0, C.bad, { Name = "DamageVignette", Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Stretch, ImageTransparency = 1, Parent = ctx.backdrop })
	local deathTint = Instance.new("ColorCorrectionEffect")
	deathTint.Name = "PivotDeathTint"
	deathTint.Saturation = 0
	deathTint.Parent = Lighting
	scope:add(deathTint)

	---------------------------------------------------------------- score header
	local header = UI.box({ Name = "Score", Size = UDim2.fromOffset(phone and 300 or 420, phone and 54 or 70), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, pad * 0.5), Parent = hud })
	local function scoreBlock(color, anchorX)
		local b = UI.new("ImageLabel", { BackgroundTransparency = 1, ImageColor3 = color, Size = UDim2.new(0, phone and 64 or 86, 0, phone and 40 or 50), AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.fromScale(anchorX, 0), Parent = header })
		Icons.apply(b, "btnCut")
		b.SliceScale = 0.35
		local t = UI.label("num", "0", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = phone and 30 or 40, TextColor3 = C.ink950, Parent = b })
		return b, t
	end
	local allyBlock, allyScore = scoreBlock(ALLY, 0)
	local enemyBlock, enemyScore = scoreBlock(ENEMY, 1)
	local mid = plate({ Size = UDim2.new(1, -(phone and 136 or 180), 0, phone and 40 or 50), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Parent = header }, { edge = C.ink600, pad = 0 })
	local timer = UI.label("num", "3:00", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = phone and 26 or 34, Parent = mid })
	local objective = UI.label("eyebrow", "", { Size = UDim2.new(1, 40, 0, 16), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.paper, TextStrokeTransparency = 0.6, Parent = header })
	if training then
		allyBlock.Visible = false
		enemyBlock.Visible = false
		mid.Size = UDim2.new(0, phone and 120 or 150, 0, phone and 40 or 50)
	end
	local limitBar = UI.box({ Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 0, phone and 43 or 53), Visible = not training, Parent = header })
	local allyFill = UI.fill(ALLY, { Size = UDim2.fromScale(0, 1), Parent = limitBar })
	local enemyFill = UI.fill(ENEMY, { Size = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = limitBar })
	objective.Position = UDim2.new(0.5, 0, 1, phone and 2 or 4)

	-- top-left: mode/map + pause button
	local topLeft = UI.box({ Size = UDim2.fromOffset(260, 40), Position = UDim2.fromOffset(pad, pad * 0.5), Parent = hud })
	UI.list("h", 8).Parent = topLeft
	local pauseBtn = UI.iconButton({ icon = "pause", label = "Pausa", size = phone and 40 or 36, order = 1, variant = "secondary" })
	pauseBtn.inst.Parent = topLeft
	local boardBtn = UI.iconButton({ icon = "scoreboard", label = "Puntuaciones", size = phone and 40 or 36, order = 2, variant = "secondary" })
	boardBtn.inst.Parent = topLeft
	local where = UI.box({ Size = UDim2.new(0, 160, 1, 0), LayoutOrder = 3, Visible = not phone, Parent = topLeft })
	UI.list("v", 0, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = where
	UI.label("eyebrow", mode.name, { LayoutOrder = 1, TextColor3 = C.signal, TextStrokeTransparency = 0.7, Parent = where })
	UI.label("micro", map.name .. (not UI.touch and "  ·  P pausa" or ""), { LayoutOrder = 2, TextColor3 = C.paper, TextStrokeTransparency = 0.7, Parent = where })

	---------------------------------------------------------------- kill feed
	local feed = UI.box({ Name = "KillFeed", Size = UDim2.fromOffset(phone and 250 or 340, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -pad, 0, pad * 0.5), Visible = settings.interface.killfeed, Parent = hud })
	UI.list("v", 4, { HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent = feed
	local feedRows = {}
	local function feedRow(e)
		local row = UI.new("ImageLabel", { Name = "Feed" .. e.id, BackgroundTransparency = 1, ImageColor3 = e.me and C.ink700 or C.ink950, ImageTransparency = e.me and 0.05 or 0.25, Size = UDim2.fromOffset(0, phone and 24 or 28), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = e.id })
		Icons.apply(row, "rounded")
		row.SliceScale = 0.15
		UI.pad(0, 10).Parent = row
		UI.list("h", 8).Parent = row
		local ts = phone and m.micro + 1 or m.small
		local function name(text, team, order)
			local l = UI.label("strong", text, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextSize = ts, TextColor3 = team == "ally" and ALLY or ENEMY, LayoutOrder = order, Parent = row })
			UI.new("UISizeConstraint", { MaxSize = Vector2.new(phone and 90 or 130, 40), Parent = l })
		end
		name(e.killer, e.kt, 1)
		local w = Catalog.get(e.weapon)
		UI.label("mono", w and w.name or "", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextSize = ts - 2, TextColor3 = C.steel2, LayoutOrder = 2, Parent = row })
		UI.icon("skull", ts, C.steel2, { LayoutOrder = 3, Parent = row })
		name(e.victim, e.vt, 4)
		if e.me then
			UI.stroke(C.signal, 1, 0.3).Parent = row
		end
		row.Parent = feed
		return row
	end

	---------------------------------------------------------------- notices
	local notices = UI.box({ Name = "Notices", Size = UDim2.fromOffset(520, 80), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, (phone and 80 or 112)), Parent = hud })
	UI.list("v", 2, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = notices
	local noticeShown = {}

	---------------------------------------------------------------- centre: crosshair + feedback
	local center = UI.box({ Name = "Center", Size = UDim2.fromOffset(240, 240), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = hud })
	local cross = require(PivotUI.Screens.Tabs.Settings).crosshair(center, settings)
	local hitmarker = UI.icon("hitmarker", 34, C.white, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ImageTransparency = 1, ZIndex = 3, Parent = center })
	local arcs = {}
	local killBanner = UI.box({ Name = "KillConfirm", Size = UDim2.fromOffset(320, 56), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 52), Visible = false, Parent = hud })
	UI.list("v", 0, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = killBanner
	local kbTitle = UI.label("h2", "Eliminación", { TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.signal, TextStrokeTransparency = 0.5, LayoutOrder = 1, Parent = killBanner })
	local kbSub = UI.label("strong", "", { TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5, LayoutOrder = 2, Parent = killBanner })
	local dmgNumbers = UI.box({ Name = "DamageNumbers", Size = UDim2.fromOffset(200, 120), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 60, 0.5, -10), Parent = hud })

	---------------------------------------------------------------- vitals
	local vitals = plate({ Name = "Vitals", Size = UDim2.fromOffset(phone and 210 or 290, phone and 64 or 82), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, pad, 1, -pad), Parent = hud }, { edge = C.ink600, pad = phone and 8 or 12 })
	vitals.ImageTransparency = 0.12
	local hpRow = UI.box({ Size = UDim2.new(1, 0, 0.62, 0), Parent = vitals })
	UI.icon("health", phone and 16 or 20, C.paper, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Parent = hpRow })
	local hpNum = UI.label("num", "100", { TextSize = phone and 26 or 36, Size = UDim2.fromOffset(70, 40), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, phone and 22 or 28, 0.5, 0), Parent = hpRow })
	local hpBar = UI.bar({ height = phone and 6 or 8, value = 100, max = 100, color = C.paper, size = UDim2.new(1, -(phone and 92 or 110), 0, phone and 6 or 8) })
	hpBar.inst.AnchorPoint = Vector2.new(1, 0.5)
	hpBar.inst.Position = UDim2.fromScale(1, 0.5)
	hpBar.inst.Parent = hpRow
	local arRow = UI.box({ Size = UDim2.new(1, 0, 0.38, 0), Position = UDim2.fromScale(0, 0.62), Parent = vitals })
	UI.icon("shield", phone and 13 or 16, C.ally:Lerp(C.paper, 0.4), { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Parent = arRow })
	local arNum = UI.label("mono", "50", { TextSize = m.small, Size = UDim2.fromOffset(40, 20), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, phone and 22 or 28, 0.5, 0), TextColor3 = C.steel2, Parent = arRow })
	local arBar = UI.bar({ height = 4, value = 50, max = 50, color = Color3.fromHex("#8FC3FF"), size = UDim2.new(1, -(phone and 92 or 110), 0, 4) })
	arBar.inst.AnchorPoint = Vector2.new(1, 0.5)
	arBar.inst.Position = UDim2.fromScale(1, 0.5)
	arBar.inst.Parent = arRow

	---------------------------------------------------------------- weapon panel
	local wpW = phone and 230 or 330
	local weapon = plate({ Name = "Weapon", Size = UDim2.fromOffset(wpW, phone and 76 or 104), AnchorPoint = touch and Vector2.new(0.5, 1) or Vector2.new(1, 1), Position = touch and UDim2.new(0.5, 0, 1, -pad) or UDim2.new(1, -pad, 1, -pad), Parent = hud }, { edge = C.ink600, pad = phone and 8 or 12 })
	weapon.ImageTransparency = 0.12
	local wName = UI.label("h3", "", { Size = UDim2.new(0.6, 0, 0, m.h3 + 4), TextSize = phone and m.small + 1 or m.h3, Parent = weapon })
	local wClass = UI.label("micro", "", { Size = UDim2.new(0.6, 0, 0, m.micro + 4), Position = UDim2.fromOffset(0, m.h3 + 2), Parent = weapon })
	local ammoBox = UI.box({ Size = UDim2.new(0.5, 0, 0, phone and 40 or 52), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = weapon })
	local magNum = UI.label("num", "30", { TextSize = phone and 34 or 48, Size = UDim2.new(1, -(phone and 46 or 60), 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = ammoBox })
	local resNum = UI.label("mono", "/ 120", { TextSize = phone and m.small or m.body, Size = UDim2.new(0, phone and 44 or 58, 0, 20), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, -6), TextColor3 = C.steel2, Parent = ammoBox })
	local ammoState = UI.label("eyebrow", "", { Size = UDim2.new(1, 0, 0, m.micro + 6), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -(phone and 16 or 24)), TextColor3 = C.warn, Parent = weapon })
	local reloadBar = UI.bar({ height = 3, value = 0, max = 1, color = C.signal, size = UDim2.new(1, 0, 0, 3) })
	reloadBar.inst.AnchorPoint = Vector2.new(0, 1)
	reloadBar.inst.Position = UDim2.new(0, 0, 1, -(phone and 12 or 18))
	reloadBar.inst.Visible = false
	reloadBar.inst.Parent = weapon
	local slotsRow = UI.box({ Size = UDim2.new(1, 0, 0, phone and 12 or 16), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = weapon })
	UI.list("h", 10).Parent = slotsRow
	local slotLabels = {}
	for i = 1, 2 do
		slotLabels[i] = UI.label("micro", "", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, Parent = slotsRow })
	end
	local supportLabel = UI.label("micro", "", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, Parent = slotsRow })

	---------------------------------------------------------------- touch controls
	-- Right-hand cluster; it never overlaps the vitals (bottom left) or the weapon panel (bottom centre).
	local touchButtons = {}
	if touch then
		local cluster = UI.box({ Name = "TouchControls", Size = UDim2.fromOffset(phone and 210 or 250, phone and 190 or 230), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -(pad + 14), 1, -(pad + 8)), Parent = hud })
		local function tb(name, icon, size, pos, color)
			local b = UI.new("ImageButton", { Name = name, BackgroundTransparency = 1, ImageColor3 = color or C.ink850, ImageTransparency = 0.18, Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Parent = cluster })
			Icons.apply(b, "pill")
			b.SliceScale = size / 128
			UI.stroke(C.paper, 1.5, 0.55).Parent = b
			UI.corner(size).Parent = b
			UI.icon(icon, math.floor(size * 0.42), color and C.signalInk or C.paper, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = b })
			touchButtons[name] = b
			return b
		end
		local big = phone and 84 or 98
		tb("Fire", "fire", big, UDim2.new(1, -big / 2, 1, -big / 2), C.signal)
		tb("Aim", "scope", phone and 56 or 64, UDim2.new(1, -big - 34, 1, -30))
		tb("Reload", "reload", phone and 52 or 58, UDim2.new(1, -big - 26, 1, -96))
		tb("Swap", "swap", phone and 52 or 58, UDim2.new(1, -big / 2 - 6, 1, -big - 36))
		tb("Support", "crate", phone and 46 or 52, UDim2.new(1, -big - 70, 1, -big - 46))
	end

	---------------------------------------------------------------- overlays
	local overlay = UI.box({ Name = "Overlays", Parent = root })

	-- intro countdown
	local intro = UI.box({ Name = "Intro", Size = UDim2.fromOffset(600, 200), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Parent = overlay })
	UI.list("v", 4, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = intro
	UI.label("eyebrow", mode.name .. "  ·  " .. map.name, { TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.signal, TextStrokeTransparency = 0.6, LayoutOrder = 1, Parent = intro })
	local introNum = UI.label("h1", "3", { TextScaled = true, Size = UDim2.new(1, 0, 0, phone and 70 or 110), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6, LayoutOrder = 2, Parent = intro })
	UI.label("strong", mode.objective, { TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6, LayoutOrder = 3, Parent = intro })

	-- ended banner
	local ended = UI.box({ Name = "Ended", Size = UDim2.fromOffset(700, 180), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Visible = false, Parent = overlay })
	UI.list("v", 4, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = ended
	UI.label("eyebrow", "Fin de la partida", { TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6, LayoutOrder = 1, Parent = ended })
	local endedTitle = UI.label("h1", "", { TextScaled = true, Size = UDim2.new(1, 0, 0, phone and 80 or 120), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5, LayoutOrder = 2, Parent = ended })

	-- death / spectator
	local death = UI.box({ Name = "Death", Visible = false, Parent = overlay })
	local deathCard = plate({ Size = UDim2.fromOffset(phone and 330 or 440, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, phone and 0.5 or 0.55), Parent = death }, { edge = C.bad:Lerp(C.ink600, 0.72), pad = phone and 12 or 18 })
	UI.list("v", 10, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = deathCard
	UI.label("h2", "Has sido eliminado", { TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.bad, LayoutOrder = 1, Parent = deathCard })
	local killerRow = UI.box({ Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 2, Parent = deathCard })
	UI.list("h", 10, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = killerRow
	local killerAvatarHolder = UI.box({ Size = UDim2.fromOffset(42, 42), LayoutOrder = 1, Parent = killerRow })
	local killerText = UI.box({ Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = killerRow })
	UI.list("v", 0, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = killerText
	local killerName = UI.label("title", "", { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = ENEMY, LayoutOrder = 1, Parent = killerText })
	local killerWeapon = UI.label("small", "", { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = killerText })
	local respawnText = UI.label("num", "", { TextSize = m.h2, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Parent = deathCard })
	local respawnBar = UI.bar({ height = 4, value = 0, max = 1, color = C.paper, order = 4 })
	respawnBar.inst.Parent = deathCard
	local deathActions = UI.box({ Size = UDim2.new(1, 0, 0, m.btn), LayoutOrder = 5, Parent = deathCard })
	UI.list("h", 8, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = deathActions
	local specBtn = UI.button({ text = "Espectar", icon = "eye", variant = "secondary", order = 1, key = "F" })
	specBtn.inst.Parent = deathActions

	local spec = UI.box({ Name = "Spectator", Visible = false, Parent = overlay })
	local specBar = plate({ Size = UDim2.fromOffset(phone and 380 or 520, phone and 56 or 66), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -(touch and (phone and 96 or 130) or pad + 4)), Parent = spec }, { edge = C.ink600, pad = 8 })
	UI.list("h", 10, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = specBar
	local specPrev = UI.iconButton({ icon = "chevronLeft", label = "Anterior", order = 1, variant = "secondary" })
	specPrev.inst.Parent = specBar
	local specInfo = UI.box({ Size = UDim2.new(0, phone and 180 or 260, 1, 0), LayoutOrder = 2, Parent = specBar })
	UI.list("v", 0, { VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = specInfo
	UI.label("eyebrow", "Espectando", { TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.signal, LayoutOrder = 1, Parent = specInfo })
	local specName = UI.label("title", "", { TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = ALLY, LayoutOrder = 2, Parent = specInfo })
	local specNext = UI.iconButton({ icon = "chevronRight", label = "Siguiente", order = 3, variant = "secondary" })
	specNext.inst.Parent = specBar
	local specStop = UI.button({ text = phone and "" or "Salir", icon = "close", variant = "ghost", size = "sm", order = 4 })
	specStop.inst.Parent = specBar
	local specRespawn = UI.label("strong", "", { Size = UDim2.fromOffset(300, 20), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5, Parent = specBar })

	-- scoreboard
	local board = UI.box({ Name = "Scoreboard", Visible = false, Parent = overlay })
	UI.fill(C.ink950, { BackgroundTransparency = 0.45, Parent = board })
	local boardCard = plate({ Size = UDim2.new(0, math.min(860, root.AbsoluteSize.X - 2 * pad), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = board }, { edge = C.ink600, pad = phone and 10 or 18 })
	UI.list("v", phone and 6 or 10).Parent = boardCard
	local boardBody = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = boardCard })
	local boardHead = UI.box({ Size = UDim2.new(1, 0, 0, m.h2 + 4), LayoutOrder = 1, Parent = boardCard })
	local boardTitle = UI.label("h2", "Puntuaciones", { Size = UDim2.fromScale(0.6, 1), Parent = boardHead })
	local boardMeta = UI.label("mono", "", { Size = UDim2.fromScale(0.4, 1), Position = UDim2.fromScale(0.6, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = boardHead })
	local function renderBoard()
		for _, c in boardBody:GetChildren() do
			c:Destroy()
		end
		local sum = Engine.summarize(match)
		boardMeta.Text = mode.name .. " · " .. map.name .. " · " .. Util.clock(Engine.timeLeft(match)) .. " restantes"
		UI.list(phone and "h" or "h", phone and 8 or 16, { HorizontalFlex = Enum.UIFlexAlignment.Fill, VerticalAlignment = Enum.VerticalAlignment.Top }).Parent = boardBody
		for ti, team in training and { "ally" } or { "ally", "enemy" } do
			local col = UI.box({ Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = ti, Parent = boardBody })
			UI.flex("fill").Parent = col
			UI.list("v", 3).Parent = col
			local teamColor = team == "ally" and ALLY or ENEMY
			local th = UI.box({ Size = UDim2.new(1, 0, 0, phone and 22 or 28), LayoutOrder = 0, Parent = col })
			UI.fill(teamColor, { Size = UDim2.new(0, 4, 1, 0), Parent = th })
			UI.label("h3", team == "ally" and (training and "Tú" or "Tu equipo") or "Rivales", { Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.fromOffset(10, 0), TextColor3 = teamColor, Parent = th })
			UI.label("num", tostring(team == "ally" and match.scores.ally or match.scores.enemy), { Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = m.h3, TextColor3 = teamColor, Visible = not training, Parent = th })
			local cols = { { "Jugador", 0, 0.52, Enum.TextXAlignment.Left }, { "E", 0.52, 0.12 }, { "M", 0.64, 0.12 }, { "A", 0.76, 0.1 }, { "Pts", 0.86, 0.14 } }
			local hr = UI.box({ Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Parent = col })
			for _, c in cols do
				UI.label("eyebrow", c[1], { Size = UDim2.fromScale(c[3], 1), Position = UDim2.fromScale(c[2], 0), TextXAlignment = c[4] or Enum.TextXAlignment.Right, TextSize = m.micro, Parent = hr })
			end
			local i = 0
			for _, p in sum.roster do
				if p.team == team then
					i += 1
					local row = UI.new("ImageLabel", { BackgroundTransparency = 1, ImageColor3 = p.me and C.signal:Lerp(C.ink700, 0.7) or C.ink800, Size = UDim2.new(1, 0, 0, phone and 26 or 32), LayoutOrder = 1 + i, Parent = col })
					Icons.apply(row, "rounded")
					row.SliceScale = 0.15
					UI.pad(0, 8).Parent = row
					local vals = { p.name, tostring(p.k), tostring(p.d), tostring(p.a), Util.num(p.score) }
					for ci, c in cols do
						UI.label(ci == 1 and "strong" or "mono", vals[ci], { Size = UDim2.fromScale(c[3], 1), Position = UDim2.fromScale(c[2], 0), TextXAlignment = c[4] or Enum.TextXAlignment.Right, TextSize = phone and m.micro + 1 or m.small, TextColor3 = ci == 1 and (p.me and C.paper or C.steel2) or C.paper, Parent = row })
					end
				end
			end
		end
	end
	local boardHint = UI.label("micro", touch and "Toca el botón de puntuaciones para cerrar" or "Suelta Tab para cerrar", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Center, Parent = boardCard })

	-- offline pause overlay
	local offline = UI.box({ Name = "Offline", Visible = false, Parent = overlay })
	UI.fill(C.ink950, { BackgroundTransparency = 0.35, Parent = offline })
	local offCard = plate({ Size = UDim2.fromOffset(420, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = offline }, { edge = C.warn:Lerp(C.ink600, 0.7), pad = 18 })
	UI.list("v", 8, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = offCard
	UI.icon("wifiOff", 34, C.warn, { LayoutOrder = 1, Parent = offCard })
	UI.label("h3", "Partida en pausa", { TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = offCard })
	UI.para("Se ha perdido la conexión. La partida continúa al recuperarla.", { TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Parent = offCard })

	---------------------------------------------------------------- state + loop
	local look = Vector2.zero
	local paused = false
	local boardHeld = false
	local boardToggled = false
	local finished = false
	local lastFeedId = 0
	local killAt, hitAt, lastHitLethal = -99, -99, false
	local lastHp = 100

	local function step(a)
		Engine.step(match, a)
	end
	app.match = { state = match, step = step }
	scope:add(function()
		app.match = nil
	end)

	local function setPaused(on)
		paused = on
		step({ type = "PAUSE", paused = on or Store.state.network ~= "online" })
	end

	local function openPause()
		if finished or UI.modalOpen() then
			return
		end
		setPaused(true)
		UI.modal({
			title = "Pausa",
			eyebrow = mode.name .. "  ·  " .. map.name,
			width = 440,
			onClose = function()
				setPaused(false)
			end,
			build = function(body)
				UI.list("v", 8).Parent = body
				local function item(text, icon, variant, order, fn)
					local b = UI.button({ text = text, icon = icon, variant = variant, width = UDim.new(1, 0), align = "left", order = order, onClick = fn })
					b.inst.Parent = body
				end
				item("Reanudar", "play", "primary", 1, function()
					UI.closeModalSilently()
					setPaused(false)
				end)
				item("Ajustes", "settings", "secondary", 2, function()
					UI.closeModalSilently()
					setPaused(true)
					local sm
					sm = UI.modal({
						title = "Ajustes",
						eyebrow = "Partida en pausa",
						width = 980,
						dismissable = false,
						build = function(b2, api)
							local host = UI.box({ Size = UDim2.new(1, 0, 0, math.min(520, root.AbsoluteSize.Y - 160)), Parent = b2 })
							require(PivotUI.Screens.Tabs.Settings).build({
								root = host,
								scope = api.scope,
								embedded = true,
								params = { group = "interface" },
								onClose = function()
									sm.close("done")
									openPause()
								end,
							})
						end,
					})
				end)
				item("Abandonar partida", "logout", "danger", 3, function()
					UI.confirm({
						title = "¿Abandonar la partida?",
						body = training and "Saldrás del campo de tiro y volverás al lobby." or "Si sales ahora no recibirás experiencia, créditos ni progreso de misiones.",
						cancelText = "Seguir jugando",
						confirmText = "Abandonar",
						tone = "danger",
						onCancelled = function(reason)
							if reason ~= "system" then
								setPaused(false)
							end
						end,
						onConfirm = function()
							finished = true
							Store.dispatch({ type = "MATCH_ABANDON" })
							UI.toast("Has abandonado la partida. No se han dado recompensas.", "warn", 4)
						end,
					})
				end)
				UI.para("En una partida online el juego seguiría en curso. En esta demo la pausa detiene la simulación.", { TextSize = m.micro + 1, LayoutOrder = 4, Parent = body })
			end,
		})
	end

	local function toggleBoard(on)
		boardToggled = on
	end

	pauseBtn.inst.Activated:Connect(openPause)
	boardBtn.inst.Activated:Connect(function()
		toggleBoard(not boardToggled)
	end)
	specBtn.inst.Activated:Connect(function()
		step({ type = "SPECTATE_START" })
	end)
	specPrev.inst.Activated:Connect(function()
		step({ type = "SPECTATE_NEXT", dir = -1 })
	end)
	specNext.inst.Activated:Connect(function()
		step({ type = "SPECTATE_NEXT", dir = 1 })
	end)
	specStop.inst.Activated:Connect(function()
		step({ type = "SPECTATE_STOP" })
	end)

	if touch then
		touchButtons.Fire.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
				step({ type = "FIRE_DOWN" })
			end
		end)
		touchButtons.Fire.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
				step({ type = "FIRE_UP" })
			end
		end)
		touchButtons.Aim.Activated:Connect(function()
			step({ type = "AIM", on = not match.aiming })
		end)
		touchButtons.Reload.Activated:Connect(function()
			step({ type = "RELOAD" })
		end)
		touchButtons.Swap.Activated:Connect(function()
			step({ type = "SWAP" })
		end)
		touchButtons.Support.Activated:Connect(function()
			step({ type = "SUPPORT" })
		end)
	end

	scope:connect(UserInputService.InputBegan, function(input, processed)
		if finished then
			return
		end
		local t = input.UserInputType
		local key = input.KeyCode
		if UI.modalOpen() then
			return
		end
		if t == Enum.UserInputType.MouseButton1 and not processed and not touch then
			step({ type = "FIRE_DOWN" })
		elseif t == Enum.UserInputType.MouseButton2 and not processed then
			step({ type = "AIM", on = true })
		elseif processed then
			return
		elseif key == Enum.KeyCode.Space then
			step({ type = "FIRE_DOWN" })
		elseif key == Enum.KeyCode.R then
			step({ type = "RELOAD" })
		elseif key == Enum.KeyCode.One then
			step({ type = "SWITCH", slot = 1 })
		elseif key == Enum.KeyCode.Two then
			step({ type = "SWITCH", slot = 2 })
		elseif key == Enum.KeyCode.G then
			step({ type = "SUPPORT" })
		elseif key == Enum.KeyCode.Tab then
			boardHeld = true
		elseif key == Enum.KeyCode.P then
			openPause()
		elseif key == Enum.KeyCode.F then
			if not match.me.alive then
				step({ type = match.spectate and "SPECTATE_STOP" or "SPECTATE_START" })
			end
		elseif key == Enum.KeyCode.Left or key == Enum.KeyCode.Right then
			if match.spectate then
				step({ type = "SPECTATE_NEXT", dir = key == Enum.KeyCode.Left and -1 or 1 })
			end
		end
	end)
	scope:connect(UserInputService.InputEnded, function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Space then
			step({ type = "FIRE_UP" })
		elseif t == Enum.UserInputType.MouseButton2 then
			step({ type = "AIM", on = false })
		elseif input.KeyCode == Enum.KeyCode.Tab then
			boardHeld = false
		end
	end)
	scope:connect(UserInputService.InputChanged, function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processed and not UI.modalOpen() then
			step({ type = "SWAP" })
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			local vp = workspace.CurrentCamera.ViewportSize
			look = Vector2.new(math.clamp((input.Position.X / vp.X) * 2 - 1, -1, 1), math.clamp((input.Position.Y / vp.Y) * 2 - 1, -1, 1))
		end
	end)
	-- connection loss pauses the match; recovery resumes it
	scope:connect(Store.changed, function(a)
		if a.type == "NET" then
			setPaused(paused)
		elseif a.type == "SETTINGS_APPLY" then
			-- settings changed from the pause menu apply live to the HUD
			settings = Store.state.settings
			cross:Destroy()
			cross = require(PivotUI.Screens.Tabs.Settings).crosshair(center, settings)
			k = settings.interface.hudScale / 100
			hud:FindFirstChildOfClass("UIScale").Scale = k
			hud.Size = UDim2.fromScale(1 / k, 1 / k)
			feed.Visible = settings.interface.killfeed
		end
	end)

	-- events from the simulation -> feedback
	local function onEvent(ev)
		stage.onEvent(ev)
		local kind = ev.kind
		if kind == "shot" then
			UI.sfx("shot")
		elseif kind == "hit" then
			hitAt = os.clock()
			lastHitLethal = ev.lethal
			UI.sfx("hit")
			if settings.interface.damageNumbers then
				local n = UI.label("num", tostring(ev.damage), { TextSize = 22, Size = UDim2.fromOffset(60, 24), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, math.random(-30, 30), 1, 0), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = ev.lethal and C.signal or C.paper, TextStrokeTransparency = 0.4, Parent = dmgNumbers })
				Util.tween(n, 0.7, { Position = n.Position - UDim2.fromOffset(0, 50), TextTransparency = 1, TextStrokeTransparency = 1 })
				task.delay(0.75, function()
					n:Destroy()
				end)
			end
		elseif kind == "kill" then
			killAt = os.clock()
			UI.sfx("kill")
			kbTitle.Text = ev.streak >= 2 and UI.upper(({ [2] = "Doble eliminación", [3] = "Triple eliminación" })[ev.streak] or ("Racha de " .. ev.streak)) or UI.upper(training and "Diana abatida" or "Eliminación")
			kbSub.Text = (ev.victim or "") .. "  ·  +100"
		elseif kind == "damage" then
			local arc = UI.icon("damageArc", 220, C.bad, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = ev.angle, ImageTransparency = 0.1, ZIndex = 2, Parent = center })
			Util.tween(arc, 1.3, { ImageTransparency = 1 }, Enum.EasingStyle.Quad)
			task.delay(1.35, function()
				arc:Destroy()
			end)
			vignette.ImageTransparency = 0.35
			Util.tween(vignette, 0.6, { ImageTransparency = 1 })
			UI.sfx("error")
		elseif kind == "reload" then
			UI.sfx("reload")
		elseif kind == "death" then
			for _, c in killerAvatarHolder:GetChildren() do
				c:Destroy()
			end
			local kb = match.me.killedBy
			if kb then
				UI.avatar({ name = kb.name, size = 42, color = ENEMY:Lerp(C.ink900, 0.55) }).Parent = killerAvatarHolder
				killerName.Text = kb.name
				killerWeapon.Text = "te ha eliminado con " .. (Catalog.get(kb.weapon) and Catalog.get(kb.weapon).name or "un arma")
			end
		elseif kind == "ended" then
			local r = ev.result
			endedTitle.Text = UI.upper(({ victory = "Victoria", defeat = "Derrota", draw = "Empate", complete = "Entrenamiento terminado" })[r] or r)
			endedTitle.TextColor3 = r == "victory" and C.signal or (r == "defeat" and C.bad or C.paper)
		end
	end

	local function paintNotices()
		local alive = {}
		for _, n in match.notices do
			alive[n.id] = true
			if not noticeShown[n.id] then
				local l = UI.label("h2", n.text, { TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = TONE[n.tone] or C.paper, TextStrokeTransparency = 0.45, TextSize = phone and m.h3 + 2 or m.h2, Size = UDim2.new(1, 0, 0, phone and 24 or 32), LayoutOrder = n.id, Parent = notices })
				local sc = UI.new("UIScale", { Scale = Util.reducedMotion and 1 or 1.25, Parent = l })
				Util.tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
				noticeShown[n.id] = l
			end
		end
		for id, l in noticeShown do
			if not alive[id] then
				l:Destroy()
				noticeShown[id] = nil
			end
		end
	end

	local function paintFeed()
		for _, e in match.feed do
			if e.id > lastFeedId then
				lastFeedId = e.id
				local row = feedRow(e)
				feedRows[e.id] = { row = row, at = os.clock() }
			end
		end
		local keep = {}
		for _, e in match.feed do
			keep[e.id] = true
		end
		for id, r in feedRows do
			local age = os.clock() - r.at
			if not keep[id] or age > 7 then
				r.row:Destroy()
				feedRows[id] = nil
			elseif age > 6 then
				r.row.ImageTransparency = 0.25 + (age - 6) * 0.75
			end
		end
	end

	local endAt = nil
	scope:connect(RunService.RenderStepped, function(dt)
		dt = math.min(dt, 0.1)
		if not paused and Store.state.network == "online" then
			step({ type = "TICK", dt = dt })
		end
		for _, ev in Engine.drain(match) do
			onEvent(ev)
		end
		local me = match.me
		local slot = match.slots[match.active]
		local w = Catalog.get(slot.weapon)

		-- header
		timer.Text = Util.clock(Engine.timeLeft(match))
		timer.TextColor3 = Engine.timeLeft(match) <= 30 and C.warn or C.paper
		allyScore.Text = tostring(match.scores.ally)
		enemyScore.Text = tostring(match.scores.enemy)
		if training then
			objective.Text = UI.upper("Dianas abatidas: " .. me.kills)
		else
			objective.Text = UI.upper(mode.objective)
			allyFill.Size = UDim2.fromScale(0.5 * match.scores.ally / mode.scoreLimit, 1)
			enemyFill.Size = UDim2.fromScale(0.5 * match.scores.enemy / mode.scoreLimit, 1)
		end

		-- vitals
		hpNum.Text = tostring(me.hp)
		local low = me.hp <= 30 and me.alive
		hpNum.TextColor3 = low and C.bad or C.paper
		hpBar.set(me.hp, 100, false)
		hpBar.color(low and C.bad or C.paper)
		arNum.Text = tostring(me.armor)
		arBar.set(me.armor, 50, false)
		if me.hp < lastHp and not low then
			-- brief flash on the bar handled by the vignette
		end
		lastHp = me.hp
		if low and not Util.reducedMotion then
			vignette.ImageTransparency = math.min(vignette.ImageTransparency, 0.55 + 0.2 * math.sin(os.clock() * 5))
		end

		-- weapon
		wName.Text = UI.upper(w.name)
		wClass.Text = Catalog.className[w.class] .. (match.aiming and "  ·  apuntando" or "")
		magNum.Text = tostring(slot.mag)
		resNum.Text = "/ " .. slot.reserve
		local lowAmmo = slot.mag > 0 and slot.mag <= math.ceil(w.stats.mag * 0.25)
		magNum.TextColor3 = slot.mag == 0 and C.bad or (lowAmmo and C.warn or C.paper)
		if match.reload then
			ammoState.Text = UI.upper("Recargando")
			ammoState.TextColor3 = C.signal
			reloadBar.inst.Visible = true
			reloadBar.set((match.t - match.reload.start) / (match.reload.untilT - match.reload.start), 1, false)
		else
			reloadBar.inst.Visible = false
			if slot.mag == 0 then
				ammoState.Text = UI.upper(slot.reserve > 0 and (touch and "Sin munición · toca recargar" or "Sin munición · pulsa R") or "Sin munición")
				ammoState.TextColor3 = C.bad
			elseif lowAmmo then
				ammoState.Text = UI.upper("Munición baja")
				ammoState.TextColor3 = C.warn
			elseif match.t < match.switchUntil then
				ammoState.Text = UI.upper("Cambiando de arma")
				ammoState.TextColor3 = C.steel2
			else
				ammoState.Text = ""
			end
		end
		for i = 1, 2 do
			local sw = Catalog.get(match.slots[i].weapon)
			slotLabels[i].Text = (touch and "" or (i .. "  ")) .. sw.name
			slotLabels[i].TextColor3 = i == match.active and C.signal or C.steel
			slotLabels[i].FontFace = i == match.active and F.bodyBold or F.bodySemi
		end
		local sup = Catalog.get(match.support)
		supportLabel.Text = (touch and "" or "G  ") .. sup.name .. (me.supportUsed and " · usado" or "")
		supportLabel.TextColor3 = me.supportUsed and C.ink600 or C.steel2
		if touch and touchButtons.Support then
			touchButtons.Support.ImageTransparency = me.supportUsed and 0.7 or 0.18
			touchButtons.Aim.ImageColor3 = match.aiming and C.signal2 or C.ink850
		end

		-- centre feedback
		local sinceHit = os.clock() - hitAt
		hitmarker.ImageTransparency = sinceHit < 0.16 and 0 or 1
		hitmarker.ImageColor3 = lastHitLethal and C.signal or C.white
		local sinceKill = os.clock() - killAt
		killBanner.Visible = sinceKill < 1.3
		cross.Visible = me.alive and not match.spectate and match.phase == "live"
		cross.Size = match.aiming and UDim2.fromOffset(44, 44) or UDim2.fromOffset(60, 60)

		paintNotices()
		paintFeed()

		-- overlays
		intro.Visible = match.phase == "intro"
		if match.phase == "intro" then
			introNum.Text = tostring(math.max(1, math.ceil(Engine.INTRO - match.t)))
		end
		local dead = not me.alive and match.phase == "live"
		death.Visible = dead and not match.spectate
		spec.Visible = dead and match.spectate ~= nil
		deathTint.Saturation = dead and -0.75 or 0
		deathTint.TintColor = dead and Color3.fromRGB(255, 225, 225) or Color3.new(1, 1, 1)
		if dead then
			local left = math.max(0, me.respawnAt - match.t)
			respawnText.Text = "Reapareces en " .. math.ceil(left)
			respawnBar.set(1 - left / ({ duel = 3, teams = 5, training = 2 })[mode.id], 1, false)
			specBtn.set({ disabled = #Engine.spectatable(match) == 0 })
			if match.spectate then
				local list = Engine.spectatable(match)
				local p = list[match.spectate]
				specName.Text = p and p.name or ""
				specRespawn.Text = "Reapareces en " .. math.ceil(left)
			end
		end
		local showBoard = (boardHeld or boardToggled) and match.phase ~= "ended"
		if showBoard and not board.Visible then
			renderBoard()
		end
		board.Visible = showBoard
		offline.Visible = Store.state.network ~= "online" and match.phase ~= "ended"
		hud.Visible = match.phase ~= "ended"

		stage.update(match, look, Store.state.settings, dt)

		-- end of match -> results (once)
		if match.phase == "ended" and not finished then
			ended.Visible = true
			endAt = endAt or os.clock()
			if os.clock() - endAt > 2.2 then
				finished = true
				UI.closeModalSilently()
				Store.dispatch({ type = "MATCH_END", summary = Engine.summarize(match) })
			end
		end
	end)
end

return Match
