-- Missions and progression. States: in progress, completed (claimable), claimed.
-- Claiming is enforced once in the store (CLAIM_MISSION refuses claimed missions and offline claims).

local RunService = game:GetService("RunService")

local PivotUI = script.Parent.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local World = require(PivotUI.Data.World)
local Catalog = require(PivotUI.Data.Catalog)
local Icons = require(PivotUI.Icons)

local C, F = UI.C, UI.F
local Missions = {}

local STAT_ICON = { matches = "play", kills = "skull", wins = "trophy", finishEquipped = "palette" }

-- Simulated reset times relative to when the session started.
local sessionStart = os.clock()
local DAILY_LEFT = 6 * 3600 + 42 * 60 + 18
local WEEKLY_LEFT = 3 * 86400 + 4 * 3600 + 10 * 60

local function hms(sec)
	sec = math.max(0, math.floor(sec))
	local d = sec // 86400
	local h = (sec % 86400) // 3600
	local mi = (sec % 3600) // 60
	local s = sec % 60
	if d > 0 then
		return string.format("%d d %02d h %02d min", d, h, mi)
	end
	return string.format("%02d:%02d:%02d", h, mi, s)
end

local function missionCard(mission, order)
	local m = UI.m
	local phone = UI.isPhone()
	local st = Store.missionState(mission)
	local card = UI.surface({ Name = "Mission_" .. mission.id, Size = UDim2.new(1, 0, 0, phone and 64 or 78), LayoutOrder = order }, { edge = st.claimable and C.brass:Lerp(C.ink700, 0.68) or C.ink700, pad = phone and 10 or 14, cut = 0.35 })
	UI.list("h", phone and 10 or 14).Parent = card
	local tile = UI.fill(st.claimed and C.ink800 or (st.done and C.brass:Lerp(C.ink800, 0.75) or C.ink800), { Size = UDim2.fromOffset(phone and 36 or 46, phone and 36 or 46), LayoutOrder = 1, Parent = card })
	UI.corner(5).Parent = tile
	UI.icon(st.claimed and "check" or (STAT_ICON[mission.stat] or "flag"), phone and 18 or 22, st.claimed and C.ok or (st.done and C.brass or C.steel2), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = tile })
	local actionW = phone and 96 or 130
	local txt = UI.box({ Size = UDim2.new(1, -(phone and 36 or 46) - actionW - 2 * (phone and 10 or 14), 1, 0), LayoutOrder = 2, Parent = card })
	UI.list("v", 5, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = txt
	UI.label("title", mission.title, { LayoutOrder = 1, TextSize = phone and m.small + 1 or m.body, TextColor3 = st.claimed and C.steel or C.paper, Parent = txt })
	local pr = UI.box({ Size = UDim2.new(1, 0, 0, m.micro + 4), LayoutOrder = 2, Parent = txt })
	local bar = UI.bar({ height = 4, value = st.progress, max = mission.target, color = st.claimed and C.ink600 or (st.done and C.brass or C.signal), size = UDim2.new(1, -70, 0, 4) })
	bar.inst.AnchorPoint = Vector2.new(0, 0.5)
	bar.inst.Position = UDim2.fromScale(0, 0.5)
	bar.inst.Parent = pr
	UI.label("mono", st.progress .. " / " .. mission.target, { Size = UDim2.new(0, 62, 1, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = m.micro, Parent = pr })
	local rw = UI.box({ Size = UDim2.new(1, 0, 0, m.micro + 8), LayoutOrder = 3, Visible = not phone, Parent = txt })
	UI.list("h", 6).Parent = rw
	if mission.reward.xp then
		UI.tag("+" .. Util.num(mission.reward.xp) .. " XP", C.signal2, { order = 1, height = m.micro + 6 }).Parent = rw
	end
	if mission.reward.credits then
		UI.tag("+" .. Util.num(mission.reward.credits), C.brass, { icon = "credits", order = 2, height = m.micro + 6 }).Parent = rw
	end
	if mission.reward.item then
		local it = Catalog.get(mission.reward.item)
		UI.tag(Catalog.kindName[it.kind] .. " «" .. it.name .. "»", C.paper, { icon = "gift", order = 3, height = m.micro + 6 }).Parent = rw
	end
	local act = UI.box({ Size = UDim2.new(0, actionW, 1, 0), LayoutOrder = 3, Parent = card })
	if st.claimable then
		local b = UI.button({ text = "Reclamar", icon = "gift", variant = "claim", width = UDim.new(1, 0), size = phone and "sm" or nil, onClick = function(api)
			api.set({ loading = true })
			local ok, info = Store.dispatch({ type = "CLAIM_MISSION", id = mission.id })
			if ok then
				UI.sfx("reward")
				UI.toast("Recompensa reclamada: " .. Store.rewardText(mission), "reward")
				if info.levels > 0 then
					UI.toast("¡Subes al nivel " .. info.level .. "!", "signal", 4)
				end
			else
				api.set({ loading = false })
				if info.reason == "offline" then
					UI.toast("Sin conexión: no se puede reclamar ahora. Tu recompensa sigue disponible.", "bad")
				end
			end
		end })
		b.inst.AnchorPoint = Vector2.new(0, 0.5)
		b.inst.Position = UDim2.fromScale(0, 0.5)
		b.inst.Parent = act
	else
		local t = st.claimed and UI.tag("Reclamada", C.ok, { icon = "check" }) or UI.tag("En curso", C.steel2, { icon = "clock" })
		t.AnchorPoint = Vector2.new(1, 0.5)
		t.Position = UDim2.fromScale(1, 0.5)
		t.Parent = act
	end
	if st.claimed then
		card.ImageTransparency = 0.35
	end
	return card
end

function Missions.build(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	local phone = UI.isPhone()
	local leftW = phone and 0.36 or 0.3

	-- progression panel
	local left = UI.surface({ Name = "Progress", Size = UDim2.new(leftW, 0, 1, -m.pad), Parent = root }, { edge = C.ink700, pad = phone and 12 or 18 })
	UI.list("v", m.gap).Parent = left
	local lists = UI.scroll({ Name = "Lists", Size = UDim2.new(1 - leftW, -m.gap, 1, -m.pad), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), ScrollBarThickness = 3, Parent = root })
	UI.pad(0, 6, 0, 0).Parent = lists
	UI.list("v", m.gapSm).Parent = lists

	local timers = {}
	local function render()
		for _, c in left:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, c in lists:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		table.clear(timers)
		local p = Store.state.profile
		UI.header("Progreso", { index = "05", order = 1 }).Parent = left
		local lv = UI.box({ Size = UDim2.new(1, 0, 0, phone and 60 or 92), LayoutOrder = 2, Parent = left })
		UI.list("h", 12, { VerticalAlignment = Enum.VerticalAlignment.Bottom }).Parent = lv
		local big = UI.label("num", tostring(p.level), { TextScaled = true, Size = UDim2.fromOffset(phone and 54 or 86, phone and 60 or 92), LayoutOrder = 1, TextColor3 = C.paper, Parent = lv })
		local lvTxt = UI.box({ Size = UDim2.new(1, -100, 1, 0), LayoutOrder = 2, Parent = lv })
		UI.list("v", 2, { VerticalAlignment = Enum.VerticalAlignment.Bottom }).Parent = lvTxt
		UI.label("eyebrow", "Nivel actual", { LayoutOrder = 1, Parent = lvTxt })
		UI.label("small", Util.num(Store.xpToNext(p.level) - p.xp) .. " XP para el nivel " .. (p.level + 1), { LayoutOrder = 2, TextColor3 = C.paper, Parent = lvTxt })
		local bar = UI.bar({ height = 8, value = p.xp, max = Store.xpToNext(p.level), color = C.signal, order = 3 })
		bar.inst.Parent = left
		UI.label("mono", Util.num(p.xp) .. " / " .. Util.num(Store.xpToNext(p.level)) .. " XP", { LayoutOrder = 4, TextSize = m.micro, Parent = left })
		if not phone then
			UI.divider({ LayoutOrder = 5, Parent = left })
			UI.label("eyebrow", "Próximos desbloqueos", { LayoutOrder = 6, Parent = left })
			local n = 0
			for _, item in Catalog.gear() do
				if item.unlockLevel and item.unlockLevel > p.level then
					n += 1
					local row = UI.box({ Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 6 + n, Parent = left })
					UI.list("h", 10).Parent = row
					local chip = UI.fill(C.ink800, { Size = UDim2.fromOffset(34, 34), LayoutOrder = 1, Parent = row })
					UI.corner(4).Parent = chip
					UI.label("h3", tostring(item.unlockLevel), { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = chip })
					local t = UI.box({ Size = UDim2.new(1, -44, 1, 0), LayoutOrder = 2, Parent = row })
					UI.list("v", 0, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = t
					UI.label("small", item.name, { TextColor3 = C.paper, LayoutOrder = 1, Parent = t })
					UI.label("micro", Catalog.className[item.class] .. "  ·  disponible en la tienda", { LayoutOrder = 2, Parent = t })
				end
			end
			if n == 0 then
				UI.label("small", "Has desbloqueado todo el arsenal.", { LayoutOrder = 7, Parent = left })
			end
			UI.para("Las partidas de Entrenamiento no dan XP ni cuentan para misiones.", { LayoutOrder = 20, TextSize = m.micro + 1, Parent = left })
		end

		local order = 0
		for _, period in { "daily", "weekly" } do
			order += 1
			local timer = UI.label("mono", "", { Size = UDim2.fromOffset(220, 18), TextXAlignment = Enum.TextXAlignment.Right, TextSize = m.micro })
			timers[period] = timer
			UI.header(period == "daily" and "Diarias" or "Semanales", { order = order, right = timer }).Parent = lists
			for _, mission in World.missions do
				if mission.period == period then
					order += 1
					missionCard(mission, order).Parent = lists
				end
			end
		end
	end
	render()
	scope:connect(RunService.Heartbeat, function()
		local el = os.clock() - sessionStart
		if timers.daily then
			timers.daily.Text = "Se renuevan en " .. hms(DAILY_LEFT - el)
		end
		if timers.weekly then
			timers.weekly.Text = "Se renuevan en " .. hms(WEEKLY_LEFT - el)
		end
	end)
	scope:connect(Store.changed, function(a)
		local t = a.type
		if t == "CLAIM_MISSION" or t == "MATCH_END" or t == "RESET" or t == "DEMO_COMPLETE_MISSIONS" or t == "SET_FINISH" or t == "NET" then
			render()
		end
	end)
end

return Missions
