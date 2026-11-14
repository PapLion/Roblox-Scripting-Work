-- Matchmaking layer of the lobby (lives above every tab so it survives tab changes):
--   searching -> dock under the top bar with elapsed time, estimate and Cancel
--   failed    -> same dock in error state with Retry / Change mode
--   found     -> "Partida encontrada" dialog with a 10 s accept window and the other players' accepts
--   loading   -> full-screen map loading card, then the match starts (Sim drives the timers)

local RunService = game:GetService("RunService")

local PivotUI = script.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local Sim = require(PivotUI.Sim)
local World = require(PivotUI.Data.World)
local Parts = require(PivotUI.Screens.Parts)

local C, F = UI.C, UI.F
local MM = {}

local TIPS = {
	"La Tern P9 se saca antes de lo que tardas en recargar la principal.",
	"La caja de munición repone la reserva de tus dos armas una vez por vida.",
	"Apuntar mejora la precisión pero reduce tu campo de visión.",
	"En Muelle 9 los contenedores del centro cortan la línea de tiro larga.",
}

function MM.attach(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	local phone = UI.isPhone()
	local dock, dockScope
	local foundModal
	local loading

	local function closeDock()
		if dockScope then
			dockScope:destroy()
			dockScope = nil
		end
		if dock then
			dock:Destroy()
			dock = nil
		end
	end

	local function openDock(kind)
		closeDock()
		dockScope = scope:child()
		local s = Store.state
		local mode = World.mode(s.mm.mode or s.play.mode)
		local map = World.map(s.mm.map or s.play.map)
		local failed = kind == "failed"
		dock = UI.surface({
			Name = "MatchmakingDock",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, phone and 36 or 0, 0, m.topbar + 6),
			Size = UDim2.fromOffset(phone and 470 or 620, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 30,
			Parent = root,
		}, { edge = (failed and C.bad or C.signal):Lerp(C.ink600, 0.55), pad = phone and 10 or 14, cut = 0.35 })
		local row = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = dock })
		UI.list("h", 14).Parent = row
		if failed then
			UI.icon("warning", 26, C.bad, { LayoutOrder = 1, Parent = row })
		else
			local sp = UI.spinner(26, C.signal)
			sp.LayoutOrder = 1
			sp.Parent = row
		end
		local txt = UI.box({ Size = UDim2.new(1, -(phone and 170 or 300), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = row })
		UI.list("v", 2).Parent = txt
		UI.label("h3", failed and "No hemos encontrado partida" or "Buscando partida", { LayoutOrder = 1, TextColor3 = failed and C.bad or C.paper, Parent = txt })
		if failed then
			UI.para("No hay suficientes jugadores de tu nivel en tu región para " .. mode.name .. ". Prueba otra vez o cambia de modo.", { LayoutOrder = 2, TextSize = m.small, Parent = txt })
		else
			UI.label("small", mode.name .. "  ·  " .. map.name .. "  ·  " .. mode.players, { LayoutOrder = 2, Parent = txt })
		end
		local right = UI.box({ Size = UDim2.fromOffset(0, m.btn), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, Parent = row })
		UI.list("h", 10).Parent = right
		if failed then
			local retry = UI.button({ text = "Reintentar", icon = "refresh", variant = "primary", order = 1, onClick = function()
				Store.dispatch({ type = "MM_CANCEL" })
				Store.dispatch({ type = "MM_START" })
			end })
			retry.inst.Parent = right
			local change = UI.button({ text = phone and "Modo" or "Cambiar modo", variant = "ghost", order = 2, onClick = function()
				Store.dispatch({ type = "MM_CANCEL" })
				ctx.go("play")
			end })
			change.inst.Parent = right
		else
			local times = UI.box({ Size = UDim2.fromOffset(phone and 54 or 96, m.btn), LayoutOrder = 1, Parent = right })
			UI.list("v", 0, { VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent = times
			local elapsed = UI.label("num", "0:00", { TextSize = m.h2, TextXAlignment = Enum.TextXAlignment.Right, LayoutOrder = 1, Parent = times })
			UI.label("micro", "Estimado " .. Util.clock(mode.queue), { TextXAlignment = Enum.TextXAlignment.Right, LayoutOrder = 2, Visible = not phone, Parent = times })
			local cancel = UI.button({ text = "Cancelar", icon = "close", variant = "secondary", order = 2, sound = "back", onClick = function()
				Store.dispatch({ type = "MM_CANCEL" })
				UI.toast("Búsqueda cancelada", "info")
			end })
			cancel.inst.Parent = right
			local started = s.mm.startedAt or os.clock()
			dockScope:connect(RunService.Heartbeat, function()
				elapsed.Text = Util.clock(os.clock() - started)
			end)
		end
		local sc = UI.new("UIScale", { Scale = Util.reducedMotion and 1 or 0.94, Parent = dock })
		Util.tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	local function openFound()
		local s = Store.state
		local mode = World.mode(s.mm.mode)
		local map = World.map(s.mm.map)
		local mmId = s.mm.id
		UI.sfx("found")
		foundModal = UI.modal({
			title = "Partida encontrada",
			eyebrow = mode.name .. "  ·  " .. map.name,
			width = 560,
			dismissable = false,
			build = function(body, api)
				UI.list("v", m.gap).Parent = body
				local top = UI.box({ Size = UDim2.new(1, 0, 0, phone and 96 or 132), LayoutOrder = 1, Parent = body })
				UI.list("h", m.gap).Parent = top
				local prev = Parts.mapPreview(map.id, { Size = UDim2.new(0, phone and 96 or 132, 1, 0), LayoutOrder = 1 })
				prev.Parent = top
				local info = UI.box({ Size = UDim2.new(1, -(phone and 96 or 132) - m.gap, 1, 0), LayoutOrder = 2, Parent = top })
				UI.list("v", 6).Parent = info
				UI.label("small", mode.objective .. "  ·  " .. mode.length, { LayoutOrder = 1, Parent = info })
				local countdown = UI.label("num", "10", { TextSize = phone and m.h1 or m.h1 * 1.2, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, (phone and m.h1 or m.h1 * 1.2) * 1.1), Parent = info })
				local timeBar = UI.bar({ height = 4, color = C.signal, order = 3, value = 1, max = 1 })
				timeBar.inst.Parent = info
				-- other players' accept pips
				local pipsRow = UI.box({ Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2, Parent = body })
				UI.list("h", 6).Parent = pipsRow
				local _, total = Sim.othersAccepted()
				local pips = {}
				for i = 1, total do
					local p = UI.fill(C.ink700, { Size = UDim2.fromOffset(phone and 26 or 34, 10), LayoutOrder = i, Parent = pipsRow })
					UI.corner(2).Parent = p
					pips[i] = p
				end
				local pipsText = UI.label("small", "", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = total + 1, Parent = pipsRow })
				local found0 = s.mm.foundAt or os.clock()
				api.scope:connect(RunService.Heartbeat, function()
					local left = math.max(0, Sim.ACCEPT_WINDOW - (os.clock() - found0))
					countdown.Text = tostring(math.ceil(left))
					countdown.TextColor3 = left <= 3 and C.bad or C.paper
					timeBar.set(left, Sim.ACCEPT_WINDOW, false)
					timeBar.color(left <= 3 and C.bad or C.signal)
					local n = Sim.othersAccepted()
					for i, p in pips do
						p.BackgroundColor3 = i <= n and C.ok or C.ink700
					end
					pipsText.Text = n .. " / " .. total .. " listos"
				end)
			end,
			actions = {
				{ text = "Rechazar", variant = "ghost", sound = "back", onClick = function()
					Store.dispatch({ type = "MM_DECLINE" })
				end },
				{ text = "Aceptar", icon = "check", variant = "primary", focus = true, onClick = function(b)
					if Store.state.mm.id == mmId then
						Store.dispatch({ type = "MM_ACCEPT" })
					end
				end },
			},
		})
	end

	local function openLoading()
		if loading then
			return
		end
		local s = Store.state
		local mode = World.mode(s.mm.mode)
		local map = World.map(s.mm.map)
		UI.closeModalSilently()
		loading = UI.fill(C.ink950, { Name = "MapLoading", ZIndex = 60, Parent = ctx.app.overlay })
		local pat = UI.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ImageColor3 = C.ink700, ImageTransparency = 0.6, ZIndex = 60, Parent = loading })
		require(PivotUI.Icons).apply(pat, "pattern_contour")
		pat.ScaleType = Enum.ScaleType.Crop
		local box = UI.box({ Size = UDim2.new(1, -2 * m.pad * 2, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, m.pad * 2, 1, -m.pad * 2), ZIndex = 61, Parent = loading })
		UI.list("v", 8).Parent = box
		UI.label("eyebrow", mode.name .. "  ·  " .. mode.objective, { TextColor3 = C.signal, LayoutOrder = 1, ZIndex = 61, Parent = box })
		UI.label("h1", map.name, { TextSize = phone and m.h1 * 1.3 or m.h1 * 1.6, Size = UDim2.new(1, 0, 0, (phone and m.h1 * 1.3 or m.h1 * 1.6) * 1.05), LayoutOrder = 2, ZIndex = 61, Parent = box })
		UI.para(map.desc, { LayoutOrder = 3, ZIndex = 61, Size = UDim2.new(phone and 1 or 0.5, 0, 0, 0), Parent = box })
		local bar = UI.bar({ height = 4, color = C.signal, order = 4, size = UDim2.new(phone and 1 or 0.5, 0, 0, 4) })
		bar.inst.Parent = box
		local tip = UI.label("small", "Consejo: " .. TIPS[(s.matchCount % #TIPS) + 1], { LayoutOrder = 5, ZIndex = 61, TextColor3 = C.steel, Parent = box })
		local plan = Parts.mapPreview(map.id, { Size = UDim2.fromOffset(phone and 140 or 260, phone and 140 or 260), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -m.pad * 2, 0, m.pad * 2 + 40), ZIndex = 61, Parent = loading })
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not loading or not loading.Parent then
				conn:Disconnect()
				return
			end
			bar.set(math.min(1, (os.clock() - t0) / Sim.LOADING_TIME), 1, false)
		end)
		-- the loading card is removed by the match screen once it is ready (smooth hand-off)
		ctx.app.mapLoading = loading
	end

	local function sync()
		local st = Store.state.mm.status
		if st == "searching" then
			if not dock or dock:GetAttribute("Kind") ~= "searching" then
				openDock("searching")
				dock:SetAttribute("Kind", "searching")
			end
		elseif st == "failed" then
			if not dock or dock:GetAttribute("Kind") ~= "failed" then
				UI.sfx("error")
				openDock("failed")
				dock:SetAttribute("Kind", "failed")
			end
		else
			closeDock()
		end
		if st == "found" then
			if not (foundModal and foundModal.isOpen()) then
				openFound()
			end
		elseif st == "accepted" then
			if foundModal and foundModal.isOpen() then
				foundModal.setActions({ { text = "Aceptada · esperando al resto", variant = "primary", icon = "check", loading = true, loadingText = "Aceptada · esperando al resto" } })
			end
		elseif foundModal and foundModal.isOpen() then
			foundModal.close("state")
			foundModal = nil
		end
		if st == "loading" then
			openLoading()
		end
	end
	sync()
	scope:connect(Store.changed, function(a)
		if a.type:sub(1, 3) == "MM_" or a.type == "NET" or a.type == "TRAINING_START" or a.type == "RESET" then
			sync()
		end
	end)
	scope:add(closeDock)
end

return MM
