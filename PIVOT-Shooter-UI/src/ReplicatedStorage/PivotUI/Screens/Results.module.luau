-- Results: the after-action report ("parte de tiro"), printed on the same paper as the armory range cards.
-- Left: the sheet (stamped verdict, final score, your line, both teams). Right: what the match paid out.
-- One orchestrated moment: the stamp lands, then credits and XP count up. Reduced motion shows the end state.

local UserInputService = game:GetService("UserInputService")

local PivotUI = script.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local Stage = require(PivotUI.Match.Stage)
local World = require(PivotUI.Data.World)
local Catalog = require(PivotUI.Data.Catalog)
local Icons = require(PivotUI.Icons)
local Theme = require(PivotUI.Theme)

local C, F = UI.C, UI.F
local Results = {}

local VERDICT = {
	victory = { text = "Victoria", ink = C.inkWin },
	defeat = { text = "Derrota", ink = C.inkLoss },
	draw = { text = "Empate", ink = C.inkNeutral },
	complete = { text = "Completado", ink = C.inkNeutral },
}

local function img(name: string, color: Color3, props)
	local i = UI.new("ImageLabel", props)
	i.BackgroundTransparency = 1
	i.ImageColor3 = color
	Icons.apply(i, name)
	return i
end

local function inkLabel(kind: string, text: string, props)
	local l = UI.label(kind, text, props)
	if not (props and props.TextColor3) then
		l.TextColor3 = C.paperInk
	end
	return l
end

---------------------------------------------------------------- the printed sheet
local function sheet(parent, r, motion)
	local m = UI.m
	local phone = UI.isPhone()
	local sum = r.summary
	local mode = World.mode(sum.mode)
	local map = World.map(sum.map)
	local training = sum.mode == "training"
	local verdict = VERDICT[sum.result] or VERDICT.draw

	local holder = UI.box({ Name = "Sheet", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = parent })
	UI.list("v", 0).Parent = holder
	local paper = UI.fill(C.paper, { Name = "Paper", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ClipsDescendants = true, Parent = holder })
	local grid = img("pattern_grid", C.paperLine, { Name = "Grid", Size = UDim2.fromScale(1, 1), ImageTransparency = 0.55, ZIndex = 0, Parent = paper })
	grid.ScaleType = Enum.ScaleType.Tile
	grid.TileSize = UDim2.fromOffset(112, 56)
	-- tear-off edge: the sheet ends in round bites, like a pad of range cards
	local edge = img("perforation", C.paper, { Name = "TearOff", Size = UDim2.new(1, 0, 0, 8), LayoutOrder = 2, Parent = holder })
	edge.ScaleType = Enum.ScaleType.Tile
	edge.TileSize = UDim2.fromOffset(16, 8)

	local body = UI.box({ Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2, Parent = paper })
	UI.pad(m.pad, m.pad + 4, m.pad + 4, m.pad + 4).Parent = body
	UI.list("v", phone and 8 or 14).Parent = body

	-- header: form title on the left, serial and time stamp typed on the right
	local head = UI.box({ Name = "Head", Size = UDim2.new(1, 0, 0, m.h3 + 6), LayoutOrder = 1, Parent = body })
	inkLabel("h3", "Parte de tiro", { Size = UDim2.fromScale(0.5, 1), Parent = head })
	inkLabel("mono", string.format("N.º %04d    %s", Store.state.matchCount, os.date("%d/%m  %H:%M")), {
		FontFace = F.paper, TextSize = m.small, Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = head,
	})
	UI.fill(C.paperInk, { Name = "Rule", Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 0.15, LayoutOrder = 2, Parent = body })

	-- hero: rubber stamp + final score
	local heroH = phone and 96 or 150
	local hero = UI.box({ Name = "Hero", Size = UDim2.new(1, 0, 0, heroH), LayoutOrder = 3, Parent = body })
	local stampW = math.floor(heroH * 2.05)
	local stamp = UI.box({ Name = "Stamp", Size = UDim2.fromOffset(stampW, math.floor(heroH * 0.78)), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Rotation = -6, Parent = hero })
	local ring = img("stamp", verdict.ink, { Name = "Ring", Size = UDim2.fromScale(1, 1), Parent = stamp })
	ring.SliceScale = phone and 0.55 or 0.8
	local word = UI.label("h1", verdict.text, {
		Name = "Verdict", TextScaled = true, TextColor3 = verdict.ink, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -math.floor(heroH * 0.32), 1, -math.floor(heroH * 0.3)), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Parent = stamp,
	})
	local stampScale = UI.new("UIScale", { Parent = stamp })

	local scoreBox = UI.box({ Name = "Score", Size = UDim2.new(1, -(stampW + 24), 1, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = hero })
	UI.list("v", 2, { HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = scoreBox
	if not training then
		local nums = UI.box({ Size = UDim2.new(1, 0, 0, math.floor(heroH * 0.52)), LayoutOrder = 1, Parent = scoreBox })
		UI.list("h", 14, { HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent = nums
		local function team(value, color, order)
			local col = UI.box({ Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order, Parent = nums })
			inkLabel("num", tostring(value), { TextScaled = true, Size = UDim2.new(0, math.floor(heroH * 0.62), 1, -6), TextXAlignment = Enum.TextXAlignment.Center, Parent = col })
			UI.fill(color, { Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, -4), Parent = col })
		end
		team(sum.scores[1], C.ally, 1)
		inkLabel("num", "–", { TextSize = math.floor(heroH * 0.3), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = C.ink600, LayoutOrder = 2, Parent = nums })
		team(sum.scores[2], C.enemy, 3)
	end
	inkLabel("small", string.format("%s %s  ·  %s  ·  %s", mode.name, mode.short, map.name, Util.clock(sum.duration)), {
		TextXAlignment = Enum.TextXAlignment.Right, LayoutOrder = 2, TextColor3 = C.ink600, Parent = scoreBox,
	})

	-- your line: five figures separated by hairlines
	local acc = sum.shots > 0 and string.format("%d %%", math.floor(sum.hits / sum.shots * 100 + 0.5)) or "—"
	local stats = { { "Eliminaciones", sum.kills }, { "Muertes", sum.deaths }, { "Asistencias", sum.assists }, { "Precisión", acc }, { "Daño", Util.num(math.floor(sum.damage)) } }
	local statRow = UI.box({ Name = "Line", Size = UDim2.new(1, 0, 0, phone and 44 or 62), LayoutOrder = 4, Parent = body })
	UI.list("h", 0, { HorizontalFlex = Enum.UIFlexAlignment.Fill }).Parent = statRow
	for i, s in stats do
		local cell = UI.box({ Size = UDim2.fromScale(0, 1), LayoutOrder = i, Parent = statRow })
		UI.flex("fill").Parent = cell
		if i > 1 then
			UI.fill(C.paperInk, { Size = UDim2.new(0, 1, 0.8, 0), Position = UDim2.fromScale(0, 0.1), BackgroundTransparency = 0.7, Parent = cell })
		end
		inkLabel("num", tostring(s[2]), { TextSize = phone and m.h2 or math.floor(m.h2 * 1.25), Size = UDim2.new(1, -14, 0.62, 0), Position = UDim2.fromOffset(14, 0), Parent = cell })
		inkLabel("small", s[1], { TextSize = m.micro + 1, TextColor3 = C.ink600, Size = UDim2.new(1, -14, 0.38, 0), Position = UDim2.new(0, 14, 0.62, 0), Parent = cell })
	end

	-- both teams, typed into a ruled table
	local teams = UI.box({ Name = "Teams", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = body })
	UI.list(phone and "v" or "h", phone and 10 or 24, { HorizontalFlex = Enum.UIFlexAlignment.Fill, VerticalAlignment = Enum.VerticalAlignment.Top }).Parent = teams
	local best = sum.roster[1]
	local rowH = phone and 24 or 30
	for ti, teamId in training and { "ally" } or { "ally", "enemy" } do
		local col = UI.box({ Size = UDim2.new(phone and 1 or 0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = ti, Parent = teams })
		UI.flex("fill").Parent = col
		UI.list("v", 0).Parent = col
		local color = teamId == "ally" and C.ally or C.enemy
		local th = UI.box({ Size = UDim2.new(1, 0, 0, rowH), LayoutOrder = 0, Parent = col })
		UI.fill(color, { Size = UDim2.new(0, 4, 0, math.floor(rowH * 0.6)), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Parent = th })
		inkLabel("h3", teamId == "ally" and (training and "Tú" or "Tu equipo") or "Rivales", { TextSize = m.small + 1, Size = UDim2.new(0.5, -12, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = th })
		local cols = { { "E", 0.6, 0.1 }, { "M", 0.7, 0.1 }, { "A", 0.8, 0.08 }, { "Pts", 0.88, 0.12 } }
		for _, c in cols do
			inkLabel("micro", c[1], { TextColor3 = C.ink600, Size = UDim2.fromScale(c[3], 1), Position = UDim2.fromScale(c[2], 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = th })
		end
		UI.fill(C.paperInk, { Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.25, LayoutOrder = 1, Parent = col })
		local n = 0
		for _, p in sum.roster do
			if p.team == teamId then
				n += 1
				local row = UI.box({ Name = p.me and "Me" or "Row", Size = UDim2.new(1, 0, 0, rowH), LayoutOrder = 1 + n * 2, Parent = col })
				if p.me then
					UI.fill(C.signal, { Name = "Mark", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.82, Parent = row })
					UI.fill(C.signal, { Size = UDim2.new(0, 3, 1, 0), Parent = row })
				end
				local nameX = 12
				if p == best and not training then
					UI.icon("mvp", rowH - 10, C.inkWin, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Parent = row })
					nameX = rowH + 2
				end
				inkLabel("strong", p.name, { TextSize = m.small, Size = UDim2.new(0.6, -nameX - 4, 1, 0), Position = UDim2.fromOffset(nameX, 0), Parent = row })
				local vals = { p.k, p.d, p.a, Util.num(p.score) }
				for ci, c in cols do
					inkLabel("mono", tostring(vals[ci]), { FontFace = F.paper, TextSize = m.small, TextColor3 = C.paperInk, Size = UDim2.fromScale(c[3], 1), Position = UDim2.fromScale(c[2], 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
				end
				UI.fill(C.paperInk, { Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.82, LayoutOrder = 2 + n * 2, Parent = col })
			end
		end
	end

	-- the moment: the stamp comes down onto the sheet
	if motion then
		stampScale.Scale = 1.7
		ring.ImageTransparency = 1
		word.TextTransparency = 1
		task.delay(0.35, function()
			if not stamp.Parent then
				return
			end
			UI.sfx(sum.result == "victory" and "reward" or "confirm")
			Util.tween(stampScale, 0.14, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Util.tween(ring, 0.1, { ImageTransparency = 0.05 })
			Util.tween(word, 0.1, { TextTransparency = 0 })
		end)
	else
		ring.ImageTransparency = 0.05
	end
	return holder
end

---------------------------------------------------------------- payout column
local function payout(parent, r, scope, motion)
	local m = UI.m
	local col = UI.box({ Name = "Payout", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = parent })
	UI.list("v", m.gap).Parent = col

	local function plate(name, order)
		local p = UI.surface({ Name = name, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = col }, { edge = C.ink600 })
		UI.list("v", m.gapSm + 2).Parent = p
		return p
	end

	-- rewards
	local rw = plate("Rewards", 1)
	UI.header("Recompensas", { order = 1 }).Parent = rw
	if #r.rewards.lines == 0 then
		UI.para("Las partidas de entrenamiento no dan XP ni créditos.", { LayoutOrder = 2, Parent = rw })
	end
	local function line(label, xp, credits, order, strong)
		local row = UI.box({ Size = UDim2.new(1, 0, 0, m.body + 10), LayoutOrder = order, Parent = rw })
		UI.label(strong and "strong" or "body", label, { Size = UDim2.new(0.55, 0, 1, 0), TextColor3 = strong and C.paper or C.steel2, Parent = row })
		UI.label(strong and "strong" or "body", "+" .. Util.num(xp) .. " XP", { Size = UDim2.new(0.22, 0, 1, 0), Position = UDim2.fromScale(0.55, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = strong and C.paper or C.steel2, Parent = row })
		-- a line that pays no credits shows a dash instead of "◇ 0"
		if credits == 0 and not strong then
			UI.label("body", "—", { Size = UDim2.new(0.2, 0, 1, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.steel, Parent = row })
		else
			local cr = UI.credits(credits, { textSize = strong and m.body + 1 or m.small + 1, color = strong and C.paper or C.steel2 })
			cr.inst.AnchorPoint = Vector2.new(1, 0.5)
			cr.inst.Position = UDim2.fromScale(1, 0.5)
			cr.inst.Parent = row
		end
	end
	for i, l in r.rewards.lines do
		line(l.label, l.xp, l.credits, 1 + i)
	end
	if #r.rewards.lines > 0 then
		UI.divider({ LayoutOrder = 50, Parent = rw })
		line("Total", r.rewards.xp, r.rewards.credits, 51, true)
	end

	-- level and balance
	local lv = plate("Progress", 2)
	local lvHead = UI.box({ Size = UDim2.new(1, 0, 0, m.h3 + 8), LayoutOrder = 1, Parent = lv })
	UI.list("h", m.gapSm).Parent = lvHead
	local lvLabel = UI.label("h3", "Nivel " .. r.before.level, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = lvHead })
	local up
	if r.levels > 0 then
		up = UI.tag("Subes de nivel", C.ok, { icon = "xp", order = 2 })
		up.Parent = lvHead
		up.Visible = not motion
	end
	local xpBar = UI.bar({ height = 8, color = C.signal, order = 2, value = r.before.xp, max = Store.xpToNext(r.before.level) })
	xpBar.inst.Parent = lv
	local xpText = UI.label("small", "", { LayoutOrder = 3, Parent = lv })
	local balRow = UI.box({ Size = UDim2.new(1, 0, 0, m.h3 + 8), LayoutOrder = 4, Parent = lv })
	UI.label("small", "Saldo", { Size = UDim2.fromScale(0.5, 1), Parent = balRow })
	local bal = UI.credits(motion and r.before.credits or r.after.credits, { textSize = m.h3 })
	bal.inst.AnchorPoint = Vector2.new(1, 0.5)
	bal.inst.Position = UDim2.fromScale(1, 0.5)
	bal.inst.Parent = balRow

	local function final()
		lvLabel.Text = UI.upper("Nivel " .. r.after.level)
		xpBar.set(r.after.xp, Store.xpToNext(r.after.level), motion)
		xpText.Text = string.format("%s / %s XP para el nivel %d", Util.num(r.after.xp), Util.num(Store.xpToNext(r.after.level)), r.after.level + 1)
		if up then
			up.Visible = true
		end
	end
	if motion then
		xpText.Text = string.format("%s / %s XP", Util.num(r.before.xp), Util.num(Store.xpToNext(r.before.level)))
		scope:delay(0.75, function()
			bal.set(r.after.credits, true)
			if r.levels > 0 then
				-- fill the old level, then roll over into the new one
				xpBar.set(1, 1, true)
				scope:delay(Theme.motion.slow * 2 + 0.05, function()
					xpBar.set(0, 1, false)
					final()
				end)
			else
				final()
			end
		end)
	else
		final()
	end

	-- missions moved by this match
	if #r.missionChanges > 0 then
		local ms = plate("Missions", 3)
		UI.header("Misiones", { order = 1 }).Parent = ms
		for i, c in r.missionChanges do
			local row = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 + i, Parent = ms })
			UI.list("v", 4).Parent = row
			local top = UI.box({ Size = UDim2.new(1, 0, 0, m.body + 6), LayoutOrder = 1, Parent = row })
			UI.label("strong", c.title, { Size = UDim2.new(0.72, 0, 1, 0), Parent = top })
			if c.completed then
				local t = UI.tag("Lista", C.ok, { icon = "check" })
				t.AnchorPoint = Vector2.new(1, 0.5)
				t.Position = UDim2.fromScale(1, 0.5)
				t.Parent = top
			else
				UI.label("mono", string.format("%d / %d", c.to, c.target), { Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.fromScale(0.72, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = top })
			end
			local b = UI.bar({ height = 5, color = c.completed and C.ok or C.signal, order = 2, value = c.from, max = c.target })
			b.inst.Parent = row
			if motion then
				scope:delay(0.9 + i * 0.12, function()
					b.set(c.to, c.target, true)
				end)
			else
				b.set(c.to, c.target, false)
			end
		end
	end

	-- unlocks reached by levelling up
	if #r.unlocks > 0 then
		local ul = plate("Unlocks", 4)
		UI.header("Desbloqueado", { order = 1 }).Parent = ul
		local tags = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = ul })
		UI.list("h", 6, { Wraps = true }).Parent = tags
		for i, id in r.unlocks do
			local item = Catalog.get(id)
			if item then
				local t = UI.tag(item.name, Theme.rarity[item.rarity] or C.steel2, { order = i })
				t.Parent = tags
			end
		end
	end
	return col
end

---------------------------------------------------------------- screen
function Results.build(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	local phone = UI.isPhone()
	local r = Store.state.lastResult
	local motion = not Util.reducedMotion
	Stage.results()

	-- backdrop: the arena, darkened towards the sheet side
	local shade = UI.fill(C.ink950, { Name = "Shade", Parent = ctx.backdrop })
	UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(0.6, 0.3), NumberSequenceKeypoint.new(1, 0.55) }), Parent = shade })

	local done = false
	local function continue()
		if done then
			return
		end
		done = true
		Store.dispatch({ type = "RESULTS_CONTINUE" })
	end

	local footH = m.btnLg + m.pad
	local scroll = UI.scroll({ Name = "Report", Size = UDim2.new(1, 0, 1, -footH), Parent = root })
	-- side margins live on the column box: scale sizes inside a ScrollingFrame ignore its UIPadding
	local sideX = m.pad * (phone and 1 or 2) + 4
	UI.pad(m.pad, 0, m.pad, 0).Parent = scroll
	local cols = UI.box({ Name = "Columns", Size = UDim2.new(1, -2 * sideX, 0, 0), Position = UDim2.fromOffset(sideX, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll })
	UI.list(phone and "v" or "h", m.gap * (phone and 1 or 2), { VerticalAlignment = Enum.VerticalAlignment.Top }).Parent = cols

	if not r then
		UI.emptyState({ icon = "info", title = "No hay datos de la partida", body = "Vuelve al lobby para jugar otra." }).Parent = cols
	else
		local left = UI.box({ Name = "Left", Size = UDim2.new(phone and 1 or 0.6, phone and 0 or -m.gap, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = cols })
		sheet(left, r, motion)
		local right = UI.box({ Name = "Right", Size = UDim2.new(phone and 1 or 0.4, phone and 0 or -m.gap, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = cols })
		payout(right, r, scope, motion)
	end

	local foot = UI.box({ Name = "Footer", Size = UDim2.new(1, -2 * m.pad * (phone and 1 or 2), 0, m.btnLg), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -math.floor(m.pad * 0.6)), Parent = root })
	UI.list("h", m.gap, { HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent = foot
	local btn = UI.button({ text = "Continuar", icon = "arrowRight", variant = "primary", size = "lg", key = not UI.touch and "Intro" or nil, order = 2, onClick = continue, name = "Continue" })
	btn.inst.Parent = foot

	scope:connect(UserInputService.InputBegan, function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter then
			btn.click()
		end
	end)
end

return Results
