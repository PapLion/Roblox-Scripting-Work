-- Lobby building blocks shared by several tabs: player card, party panel, play button,
-- loadout strip and map preview. Each one listens to the store inside the scope it is given.

local Players = game:GetService("Players")

local PivotUI = script.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local World = require(PivotUI.Data.World)
local Catalog = require(PivotUI.Data.Catalog)
local WeaponView = require(PivotUI.WeaponView)
local Theme = require(PivotUI.Theme)

local C, F = UI.C, UI.F
local Parts = {}

---------------------------------------------------------------- player card
function Parts.playerCard(scope, opts)
	opts = opts or {}
	local m = UI.m
	local h = opts.height or (UI.isPhone() and 64 or 92)
	local card = UI.new("ImageLabel", { Name = "PlayerCard", BackgroundTransparency = 1, ImageColor3 = C.ink600, Size = UDim2.new(1, 0, 0, h), LayoutOrder = opts.order or 0, ClipsDescendants = true })
	require(PivotUI.Icons).apply(card, "panelTone")
	card.SliceScale = 0.4
	local banner = UI.banner(Store.state.profile.banner, { Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), Parent = card })
	UI.corner(4).Parent = banner
	local row = UI.box({ Size = UDim2.new(1, 0, 1, 0), ZIndex = 2, Parent = card })
	UI.pad(0, 14).Parent = row
	UI.list("h", 12).Parent = row
	local av = UI.avatar({ userId = Players.LocalPlayer.UserId > 0 and Players.LocalPlayer.UserId or nil, name = Store.state.profile.name, size = h - 22, order = 1, ring = C.ink600 })
	av.ZIndex = 2
	av.Parent = row
	local txt = UI.box({ Size = UDim2.new(1, -(h - 22) - 12 - 44, 1, 0), LayoutOrder = 2, Parent = row })
	UI.list("v", 2, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = txt
	local name = UI.label("title", "", { TextSize = m.body + 2, LayoutOrder = 1, Parent = txt })
	local sub = UI.label("small", "", { LayoutOrder = 2, TextColor3 = C.steel2, Parent = txt })
	local xp = UI.bar({ height = 3, color = C.signal, order = 3, size = UDim2.new(0.9, 0, 0, 3) })
	xp.inst.Parent = txt
	local emblemHolder = UI.box({ Size = UDim2.fromOffset(40, 40), LayoutOrder = 3, Parent = row })
	local function refresh()
		local p = Store.state.profile
		name.Text = p.name
		sub.Text = string.format("Nivel %d  ·  %s / %s XP", p.level, Util.num(p.xp), Util.num(Store.xpToNext(p.level)))
		xp.set(p.xp, Store.xpToNext(p.level), true)
		for _, c in emblemHolder:GetChildren() do
			c:Destroy()
		end
		UI.emblem(p.emblem, 36, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = emblemHolder })
		local b = Catalog.get(p.banner)
		banner:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(b.colors[1], b.colors[2])
		require(PivotUI.Icons).apply(banner.Pattern, "pattern_" .. b.id)
		banner.Pattern.ScaleType = Enum.ScaleType.Crop
	end
	refresh()
	scope:connect(Store.changed, function(a)
		if a.type == "EQUIP" or a.type == "MATCH_END" or a.type == "CLAIM_MISSION" or a.type == "RESET" then
			refresh()
		end
	end)
	return card
end

---------------------------------------------------------------- party
local function memberRow(info, opts)
	local m = UI.m
	local phone = UI.isPhone()
	local h = phone and 40 or 50
	local row = UI.new("ImageLabel", { Name = "Member_" .. info.id, BackgroundTransparency = 1, ImageColor3 = info.me and C.ink600 or C.ink700, Size = UDim2.new(1, 0, 0, h), LayoutOrder = opts.order })
	require(PivotUI.Icons).apply(row, "rounded")
	row.SliceScale = 0.2
	row.ImageTransparency = info.me and 0.2 or 0.45
	UI.pad(0, 8).Parent = row
	UI.list("h", 10).Parent = row
	local av
	if info.me then
		av = UI.avatar({ userId = Players.LocalPlayer.UserId > 0 and Players.LocalPlayer.UserId or nil, name = info.name, size = h - 12, order = 1 })
	else
		local b = Catalog.get(info.banner or "grid")
		av = UI.avatar({ name = info.name, emblem = info.emblem, color = b.colors[1], size = h - 12, order = 1 })
	end
	av.Parent = row
	-- phone: compact row (no kick button, status as a coloured dot) so names keep their width
	if phone then
		opts.kick = nil
	end
	local txt = UI.box({ Size = UDim2.new(1, -(h - 12) - 10 - (opts.kick and (m.btnSm + 10) or 0) - (phone and 22 or 86), 1, 0), LayoutOrder = 2, Parent = row })
	UI.list("v", 0, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = txt
	local nameRow = UI.box({ Size = UDim2.new(1, 0, 0, m.body + 4), LayoutOrder = 1, Parent = txt })
	UI.list("h", 6).Parent = nameRow
	if info.leader then
		UI.icon("crown", 14, C.brass, { LayoutOrder = 1, Parent = nameRow })
	end
	UI.label("strong", info.name, { Size = UDim2.new(1, info.leader and -20 or 0, 1, 0), TextSize = m.small + 1, LayoutOrder = 2, Parent = nameRow })
	UI.label("micro", (info.me and "Tú" or "Amigo") .. "  ·  Nivel " .. tostring(info.level), { LayoutOrder = 2, Parent = txt })
	local pillColor = info.ready and C.ok or C.steel
	if phone then
		UI.icon(info.ready and "ready" or "notReady", 16, pillColor, { LayoutOrder = 3, Parent = row })
	else
		local pill = UI.tag(info.ready and "Listo" or "No listo", pillColor, { icon = info.ready and "check" or nil, order = 3 })
		pill.Parent = row
	end
	if opts.kick then
		local k = UI.iconButton({ icon = "kick", label = "Expulsar del grupo", order = 4, size = m.btnSm - 4, disabled = Store.mmBusy(), onClick = opts.kick })
		k.inst.Parent = row
	end
	return row
end

local function inviteModal()
	local m = UI.m
	UI.modal({
		title = "Invitar al grupo",
		eyebrow = "Amigos",
		width = 520,
		build = function(body, api)
			UI.list("v", 8).Parent = body
			local note = UI.label("small", "", { LayoutOrder = 0, Parent = body })
			local list = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body })
			UI.list("v", 6).Parent = list
			local function render()
				for _, c in list:GetChildren() do
					if c:IsA("GuiObject") then
						c:Destroy()
					end
				end
				local s = Store.state
				local free = 3 - #s.party
				note.Text = free > 0 and Util.plural(free, "{n} plaza libre en tu grupo", "{n} plazas libres en tu grupo") or "Grupo completo: 4 de 4"
				local inParty = {}
				for _, p in s.party do
					inParty[p.id] = true
				end
				for i, f in World.friends do
					local row = UI.new("ImageLabel", { BackgroundTransparency = 1, ImageColor3 = C.ink700, ImageTransparency = 0.4, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = i, Parent = list })
					require(PivotUI.Icons).apply(row, "rounded")
					row.SliceScale = 0.2
					UI.pad(0, 10).Parent = row
					UI.list("h", 10).Parent = row
					local b = Catalog.get(f.banner)
					UI.avatar({ name = f.name, emblem = f.emblem, color = b.colors[1], size = 36, order = 1 }).Parent = row
					local txt = UI.box({ Size = UDim2.new(1, -36 - 20 - 150, 1, 0), LayoutOrder = 2, Parent = row })
					UI.list("v", 0, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = txt
					UI.label("strong", f.name, { TextSize = m.small + 1, LayoutOrder = 1, Parent = txt })
					local statusColor = f.status == "online" and C.ok or (f.status == "offline" and C.steel or C.warn)
					local st = UI.box({ Size = UDim2.new(1, 0, 0, m.micro + 4), LayoutOrder = 2, Parent = txt })
					UI.list("h", 5).Parent = st
					UI.icon("dot", 8, statusColor, { LayoutOrder = 1, Parent = st })
					UI.label("micro", World.statusName[f.status] .. "  ·  Nivel " .. f.level, { Size = UDim2.new(1, -14, 1, 0), LayoutOrder = 2, Parent = st })
					local invite = s.invites[f.id]
					local btn
					if inParty[f.id] then
						btn = UI.tag("En el grupo", C.ok, { icon = "check", order = 3 })
					elseif invite == "pending" then
						btn = UI.button({ text = "Enviada", variant = "ghost", size = "sm", loading = true, loadingText = "Enviada", width = UDim.new(0, 140), order = 3 }).inst
					elseif invite == "declined" then
						btn = UI.button({ text = "Volver a invitar", variant = "ghost", size = "sm", width = UDim.new(0, 140), order = 3, disabled = free <= 0, onClick = function()
							Store.state.invites[f.id] = nil
							Store.dispatch({ type = "INVITE", id = f.id })
						end }).inst
					elseif f.status ~= "online" then
						btn = UI.button({ text = World.statusName[f.status], variant = "ghost", size = "sm", width = UDim.new(0, 140), order = 3, disabled = true }).inst
					else
						btn = UI.button({ text = "Invitar", icon = "userPlus", variant = "secondary", size = "sm", width = UDim.new(0, 140), order = 3, disabled = free <= 0 or Store.mmBusy(), onClick = function()
							Store.dispatch({ type = "INVITE", id = f.id })
						end }).inst
					end
					btn.Parent = row
				end
			end
			render()
			api.scope:connect(Store.changed, function(a)
				if a.type == "INVITE" or a.type == "INVITE_RESOLVE" or a.type == "KICK" or a.type == "LEAVE_PARTY" or a.type == "MM_START" then
					render()
				end
			end)
		end,
		actions = { { text = "Cerrar", variant = "ghost", onClick = function()
			UI.closeModalSilently()
		end } },
	})
end
Parts.inviteModal = inviteModal

-- Party panel. opts.compact shows only avatars (phone).
function Parts.partyPanel(scope, opts)
	opts = opts or {}
	local m = UI.m
	local panel = UI.surface({ Name = "Party", Size = opts.size or UDim2.new(1, 0, 0, 0), AutomaticSize = opts.size and Enum.AutomaticSize.None or Enum.AutomaticSize.Y, LayoutOrder = opts.order or 0 }, { edge = C.ink700, pad = UI.isPhone() and 10 or 14 })
	UI.list("v", 8).Parent = panel
	local countLabel = UI.label("mono", "", { TextSize = m.micro, Size = UDim2.fromOffset(60, 16), TextXAlignment = Enum.TextXAlignment.Right })
	local head = UI.header("Grupo", { order = 1, right = countLabel })
	head.Parent = panel
	local list = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = panel })
	UI.list("v", 6).Parent = list
	local note = UI.label("small", "", { LayoutOrder = 3, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextTruncate = Enum.TextTruncate.None, Parent = panel })
	local actions = UI.box({ Size = UDim2.new(1, 0, 0, m.btnSm), LayoutOrder = 4, Parent = panel })
	UI.list("h", 8, { HorizontalFlex = Enum.UIFlexAlignment.Fill }).Parent = actions
	local invite = UI.button({ text = "Invitar", icon = "userPlus", variant = "secondary", size = "sm", order = 1, onClick = inviteModal })
	invite.inst.Parent = actions
	local leave = UI.button({ text = "Salir del grupo", icon = "logout", variant = "ghost", size = "sm", order = 2, onClick = function()
		UI.confirm({
			title = "¿Salir del grupo?",
			body = "Volverás a jugar en solitario. Tus amigos seguirán en el lobby y podrás invitarlos de nuevo.",
			confirmText = "Salir del grupo",
			tone = "danger",
			onConfirm = function()
				Store.dispatch({ type = "LEAVE_PARTY" })
				UI.toast("Has salido del grupo", "info")
			end,
		})
	end })
	leave.inst.Parent = actions

	local function render()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local s = Store.state
		local solo = World.mode(s.play.mode).maxParty == 1
		memberRow({ id = "me", name = s.profile.name, level = s.profile.level, ready = s.meReady, me = true, leader = true }, { order = 1 }).Parent = list
		for i, p in s.party do
			local f = World.friend(p.id)
			memberRow({ id = f.id, name = f.name, level = f.level, ready = p.ready, banner = f.banner, emblem = f.emblem }, {
				order = 1 + i,
				kick = function()
					UI.confirm({
						title = "¿Expulsar a " .. f.name .. "?",
						body = "Saldrá del grupo y tendrás que invitarle otra vez para jugar juntos.",
						confirmText = "Expulsar",
						tone = "danger",
						onConfirm = function()
							Store.dispatch({ type = "KICK", id = f.id })
						end,
					})
				end,
			}).Parent = list
		end
		for id, st in s.invites do
			if st == "pending" then
				local f = World.friend(id)
				local row = UI.box({ Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 50, Parent = list })
				UI.pad(0, 10).Parent = row
				UI.list("h", 8).Parent = row
				UI.spinner(14, C.steel2).Parent = row
				UI.label("small", "Invitación enviada a " .. f.name, { Size = UDim2.new(1, -24, 1, 0), LayoutOrder = 2, Parent = row })
			end
		end
		countLabel.Text = (#s.party + 1) .. " / 4"
		local waiting = 0
		for _, p in s.party do
			if not p.ready then
				waiting += 1
			end
		end
		if solo and #s.party > 0 then
			note.Text = "Este modo es individual: tu grupo te esperará en el lobby."
			note.TextColor3 = C.warn
		elseif s.meReady and waiting > 0 then
			note.Text = Util.plural(waiting, "Esperando a {n} jugador…", "Esperando a {n} jugadores…")
			note.TextColor3 = C.steel2
		else
			note.Text = ""
		end
		note.Visible = note.Text ~= ""
		invite.set({ disabled = #s.party >= 3 or Store.mmBusy() or s.network ~= "online", text = #s.party >= 3 and "Grupo completo" or "Invitar" })
		leave.inst.Visible = #s.party > 0
		leave.set({ disabled = Store.mmBusy() })
	end
	render()
	scope:connect(Store.changed, function(a)
		local t = a.type
		if t:sub(1, 3) == "MM_" or t == "INVITE" or t == "INVITE_RESOLVE" or t == "KICK" or t == "LEAVE_PARTY" or t == "SET_READY" or t == "ME_READY" or t == "SET_MODE" or t == "NET" or t == "RESET" then
			render()
		end
	end)
	return panel
end

---------------------------------------------------------------- play button
-- One button that walks through: "Estoy listo" -> waiting for the party -> "Buscar partida" -> searching
-- (shows elapsed time, click = cancel) and is disabled offline. Training starts directly.
function Parts.playButton(scope, opts)
	opts = opts or {}
	local m = UI.m
	local btn = UI.button({ text = "Buscar partida", icon = "play", variant = "primary", size = "lg", width = opts.width or UDim.new(1, 0), order = opts.order, key = not UI.touch and "Intro" or nil })
	local function stateNow()
		local s = Store.state
		local mode = World.mode(s.play.mode)
		if s.network ~= "online" then
			return { text = "Sin conexión", icon = "wifiOff", disabled = true }
		end
		local st = s.mm.status
		if st == "searching" then
			return { text = "Cancelar búsqueda", icon = "close", variant = "secondary", action = "cancel" }
		elseif st == "found" or st == "accepted" or st == "loading" then
			return { text = "Entrando…", icon = "play", loading = true }
		end
		if mode.id == "training" then
			return { text = "Entrar al campo de tiro", icon = "target", action = "training" }
		end
		if not s.meReady then
			return { text = "Estoy listo", icon = "check", action = "ready" }
		end
		if not Store.partyAllReady() then
			local waiting = 0
			for _, p in s.party do
				if not p.ready then
					waiting += 1
				end
			end
			return { text = Util.plural(waiting, "Esperando a {n} jugador", "Esperando a {n} jugadores"), icon = "hourglass", disabled = true }
		end
		return { text = st == "failed" and "Reintentar búsqueda" or "Buscar partida", icon = st == "failed" and "refresh" or "play", action = "search" }
	end
	local current
	local function refresh()
		current = stateNow()
		btn.set({ text = current.text, icon = current.icon, disabled = current.disabled == true, loading = current.loading == true })
	end
	local function activate()
		if not current or current.disabled or current.loading then
			return
		end
		local a = current.action
		if a == "ready" then
			Store.dispatch({ type = "ME_READY", ready = true })
		elseif a == "search" then
			if Store.state.mm.status == "failed" then
				Store.dispatch({ type = "MM_CANCEL" })
			end
			Store.dispatch({ type = "MM_START" })
		elseif a == "cancel" then
			Store.dispatch({ type = "MM_CANCEL" })
			UI.toast("Búsqueda cancelada", "info")
		elseif a == "training" then
			Store.dispatch({ type = "TRAINING_START" })
		end
	end
	btn.inst.Activated:Connect(function()
		UI.sfx("confirm")
		activate()
	end)
	btn.activate = activate
	refresh()
	scope:connect(Store.changed, refresh)
	return btn
end

---------------------------------------------------------------- loadout strip
-- The three equipped slots with a small model view each. Click opens the armory on that slot.
function Parts.loadoutStrip(scope, opts)
	opts = opts or {}
	local m = UI.m
	local phone = UI.isPhone()
	local h = opts.height or (phone and 64 or 92)
	local strip = UI.box({ Name = "Loadout", Size = UDim2.new(1, 0, 0, h), LayoutOrder = opts.order or 0 })
	UI.list("h", 8, { HorizontalFlex = Enum.UIFlexAlignment.Fill }).Parent = strip
	local cells = {}
	for i, slot in { "primary", "secondary", "support" } do
		local b = UI.new("ImageButton", { Name = "Slot_" .. slot, BackgroundTransparency = 1, ImageColor3 = C.ink600, AutoButtonColor = false, Size = UDim2.fromScale(0, 1), LayoutOrder = i, Parent = strip })
		require(PivotUI.Icons).apply(b, "panelTone")
		b.SliceScale = 0.35
		UI.flex("fill", slot == "primary" and 1.5 or 1).Parent = b
		local card = WeaponView.card(Catalog.get(Store.state.loadout[slot]), { compact = true, size = UDim2.new(phone and 0.42 or 0.5, -6, 1, -8), finish = Store.finishOf(Store.state.loadout[slot]) })
		card.inst.Position = UDim2.fromOffset(4, 4)
		card.inst.Parent = b
		local txt = UI.box({ Size = UDim2.new(phone and 0.58 or 0.5, -12, 1, 0), Position = UDim2.new(phone and 0.42 or 0.5, 6, 0, 0), Parent = b })
		UI.list("v", 2, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = txt
		UI.label("eyebrow", Catalog.slotName[slot], { LayoutOrder = 1, TextSize = m.micro, Parent = txt })
		local name = UI.label("title", "", { LayoutOrder = 2, TextSize = phone and m.small or m.body, Parent = txt })
		local sub = UI.label("micro", "", { LayoutOrder = 3, Visible = not phone, Parent = txt })
		local ring = UI.shape("panelCutStroke", C.signal, { Name = "Hover", SliceScale = 0.35, Visible = false, ZIndex = 3, Parent = b })
		b.MouseEnter:Connect(function()
			ring.Visible = true
		end)
		b.MouseLeave:Connect(function()
			ring.Visible = false
		end)
		b.SelectionGained:Connect(function()
			ring.Visible = true
		end)
		b.SelectionLost:Connect(function()
			ring.Visible = false
		end)
		b.Activated:Connect(function()
			if opts.onSlot then
				UI.sfx("click")
				opts.onSlot(slot)
			end
		end)
		cells[slot] = { card = card, name = name, sub = sub, id = nil, finish = nil }
	end
	local function refresh()
		for slot, cell in cells do
			local id = Store.state.loadout[slot]
			local item = Catalog.get(id)
			local finish = Store.finishOf(id)
			if cell.id ~= id then
				cell.card.setItem(item, finish)
			elseif cell.finish ~= finish then
				cell.card.setFinish(finish)
			end
			cell.id, cell.finish = id, finish
			cell.name.Text = item.name
			if item.kind == "weapon" then
				local fin = Catalog.get(finish)
				cell.sub.Text = Catalog.className[item.class] .. "  ·  " .. item.stats.mag .. " balas  ·  " .. fin.name
			else
				cell.sub.Text = "Un uso por vida"
			end
		end
	end
	refresh()
	scope:connect(Store.changed, function(a)
		if a.type == "EQUIP" or a.type == "SET_FINISH" or a.type == "RESET" then
			refresh()
		end
	end)
	return strip
end

---------------------------------------------------------------- map preview
-- Schematic top-down plan of the map (blocks + spawns) on a dark plate with a grid.
function Parts.mapPreview(mapId: string, props)
	local map = World.map(mapId)
	local plate = UI.new("ImageLabel", { Name = "MapPreview", BackgroundTransparency = 1, ImageColor3 = C.ink600, ClipsDescendants = true })
	require(PivotUI.Icons).apply(plate, "panelTone")
	plate.SliceScale = 0.35
	for k, v in props or {} do
		(plate :: any)[k] = v
	end
	local inner = UI.fill(Color3.fromHex("#222A33"), { Name = "Plan", Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), Parent = plate })
	UI.corner(3).Parent = inner
	local grid = UI.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ImageColor3 = C.ink600, ImageTransparency = 0.55, Parent = inner })
	require(PivotUI.Icons).apply(grid, "pattern_grid")
	grid.ScaleType = Enum.ScaleType.Tile
	grid.TileSize = UDim2.fromOffset(128, 64)
	local area = UI.box({ Size = UDim2.fromScale(0.84, 0.84), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = inner })
	UI.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = area })
	for _, r in map.layout do
		local blk = UI.fill(map.accent:Lerp(C.ink600, 0.35), { Size = UDim2.fromScale(r[3] / 100, r[4] / 100), Position = UDim2.fromScale(r[1] / 100, r[2] / 100), Parent = area })
		UI.corner(2).Parent = blk
		UI.stroke(map.accent:Lerp(C.paper, 0.2), 1, 0.6).Parent = blk
	end
	local pal = Theme.teamPalettes[Store.state.settings.accessibility.colorblind and "colorblind" or "default"]
	for i, spot in { { 0.08, 0.9, pal.ally }, { 0.92, 0.1, pal.enemy } } do
		local d = UI.fill(spot[3], { Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(spot[1], spot[2]), ZIndex = 3, Parent = area })
		UI.corner(5).Parent = d
	end
	return plate
end

return Parts
