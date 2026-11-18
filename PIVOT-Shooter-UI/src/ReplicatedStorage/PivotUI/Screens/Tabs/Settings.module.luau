-- Settings with a draft: Apply commits, Cancel discards, Restore loads defaults (still needs Apply).
-- Every row takes effect when applied; nothing here is decorative.
-- Leaving the tab with unapplied changes asks to discard them. Preferences last for the session.
-- Settings.build also works embedded (pause menu): ctx.embedded + ctx.onClose.

local PivotUI = script.Parent.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local Icons = require(PivotUI.Icons)
local Theme = require(PivotUI.Theme)

local C, F = UI.C, UI.F
local Settings = {}

Settings.crosshairColors = {
	white = Color3.fromHex("#FFFFFF"),
	green = Color3.fromHex("#59F28A"),
	cyan = Color3.fromHex("#4FE3F0"),
	yellow = Color3.fromHex("#FFE14D"),
}

local pct = function(v)
	return v .. " %"
end

Settings.schema = {
	{ id = "audio", label = "Audio", icon = "sound", rows = {
		{ key = "master", label = "Volumen general", kind = "slider", min = 0, max = 100, step = 5, format = pct, help = "Afecta a los sonidos de la interfaz y de la partida." },
		{ key = "effects", label = "Efectos", kind = "slider", min = 0, max = 100, step = 5, format = pct },
	} },
	{ id = "graphics", label = "Gráficos", icon = "monitor", rows = {
		{ key = "quality", label = "Calidad", kind = "choice", options = { { "low", "Baja" }, { "medium", "Media" }, { "high", "Alta" } }, help = "Baja quita sombras, bloom y el decorado lejano del mapa." },
		{ key = "fov", label = "Campo de visión", kind = "slider", min = 70, max = 100, step = 1, format = function(v)
			return v .. "°"
		end, help = "Se aplica a la cámara de la partida." },
	} },
	{ id = "controls", label = "Controles", icon = "mouse", rows = {
		{ key = "sensitivity", label = "Sensibilidad", kind = "slider", min = 0.2, max = 3, step = 0.1, format = function(v)
			return string.format("%.1f", v):gsub("%.", ",")
		end, help = "Cuánto gira la cámara de la partida al mover el ratón." },
		{ key = "invertY", label = "Invertir eje vertical", kind = "toggle" },
		{ key = "touch", label = "Controles táctiles", kind = "choice", options = { { "auto", "Automático" }, { "always", "Siempre" }, { "never", "Nunca" } }, help = "Muestra los botones táctiles del HUD y la navegación compacta." },
	} },
	{ id = "interface", label = "Interfaz", icon = "layout", rows = {
		{ key = "hudScale", label = "Escala del HUD", kind = "slider", min = 80, max = 130, step = 5, format = pct },
		{ key = "crosshair", label = "Mira", kind = "choice", options = { { "cross", "Cruz" }, { "dot", "Punto" }, { "circle", "Círculo" } } },
		{ key = "crosshairSize", label = "Tamaño de la mira", kind = "slider", min = 60, max = 160, step = 10, format = pct },
		{ key = "crosshairColor", label = "Color de la mira", kind = "swatch", options = { "white", "green", "cyan", "yellow" } },
		{ key = "killfeed", label = "Registro de eliminaciones", kind = "toggle" },
		{ key = "damageNumbers", label = "Números de daño", kind = "toggle" },
	} },
	{ id = "accessibility", label = "Accesibilidad", icon = "accessibility", rows = {
		{ key = "reducedMotion", label = "Movimiento reducido", kind = "toggle", help = "Quita animaciones, giros y balanceos; los cambios son directos." },
		{ key = "colorblind", label = "Colores para daltonismo", kind = "toggle", help = "Equipos en azul y ámbar en lugar de azul y rojo." },
		{ key = "screenShake", label = "Vibración de cámara", kind = "toggle", help = "Retroceso visible de la cámara al disparar y recibir daño." },
	} },
}

-- Crosshair drawn with frames; shared with the HUD.
function Settings.crosshair(parent, s)
	local color = Settings.crosshairColors[s.interface.crosshairColor] or Color3.new(1, 1, 1)
	local k = s.interface.crosshairSize / 100
	local holder = UI.box({ Name = "Crosshair", Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = parent })
	local function bar(w, h, x, y)
		local f = UI.fill(color, { Size = UDim2.fromOffset(w, h), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.5, y), Parent = holder })
		UI.stroke(Color3.new(0, 0, 0), 1, 0.55).Parent = f
		return f
	end
	local style = s.interface.crosshair
	if style == "cross" then
		local len, gap = math.floor(8 * k), math.floor(5 * k)
		bar(2, len, 0, -(gap + len / 2))
		bar(2, len, 0, gap + len / 2)
		bar(len, 2, -(gap + len / 2), 0)
		bar(len, 2, gap + len / 2, 0)
	elseif style == "dot" then
		local d = bar(math.max(4, math.floor(5 * k)), math.max(4, math.floor(5 * k)), 0, 0)
		UI.corner(8).Parent = d
	else
		local r = UI.icon("ring", math.floor(26 * k), color, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = holder })
		local d = bar(3, 3, 0, 0)
		UI.corner(2).Parent = d
	end
	return holder
end

function Settings.build(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	local phone = UI.isPhone()
	local embedded = ctx.embedded
	local draft = Util.deepCopy(Store.state.settings)
	local group = (ctx.params and ctx.params.group) or "audio"

	local navW = phone and 0 or (embedded and 0.28 or 0.22)
	local previewW = (phone or embedded) and 0 or 0.27
	local footerH = m.btn + m.pad

	local nav, seg
	if navW > 0 then
		-- side panels hug their content; only the rows column runs the full height (it scrolls)
		nav = UI.surface({ Name = "Groups", Size = UDim2.new(navW, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = root }, { edge = C.ink700, pad = 10 })
		UI.list("v", 4).Parent = nav
	end
	local body = UI.scroll({ Name = "Rows", Size = UDim2.new(1 - navW - previewW, -m.gap * ((navW > 0 and 1 or 0) + (previewW > 0 and 1 or 0)), 1, -(footerH + m.pad)), Position = UDim2.new(navW, navW > 0 and m.gap or 0, 0, 0), ScrollBarThickness = 3, Parent = root })
	UI.pad(0, 8, 0, 0).Parent = body
	local preview = previewW > 0 and UI.surface({ Name = "Preview", Size = UDim2.new(previewW, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = root }, { edge = C.ink700, pad = 14 }) or nil

	-- footer
	local footer = UI.surface({ Name = "Footer", Size = UDim2.new(1, 0, 0, footerH), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -m.pad * 0.5), Parent = root }, { edge = C.ink700, pad = math.floor(m.pad / 2), cut = 0.35 })
	local status = UI.box({ Size = UDim2.new(0.4, 0, 1, 0), Parent = footer })
	UI.list("h", 8).Parent = status
	local statusIcon = UI.icon("check", 16, C.ok, { LayoutOrder = 1, Parent = status })
	local statusText = UI.label("small", "", { Size = UDim2.new(1, -24, 1, 0), LayoutOrder = 2, Parent = status })
	local btns = UI.box({ Size = UDim2.new(0.6, 0, 1, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = footer })
	UI.list("h", m.gapSm, { HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent = btns

	local renderRows, paintFooter, renderPreview
	local controls = {}

	local function dirty()
		return not Util.equal(draft, Store.state.settings)
	end
	local reset = UI.button({ text = "Restablecer", icon = "refresh", variant = "ghost", order = 1, onClick = function()
		draft = Util.deepCopy(Store.defaultSettings)
		renderRows()
		paintFooter()
		UI.toast("Valores por defecto cargados: pulsa Aplicar para guardarlos.", "info")
	end })
	reset.inst.Parent = btns
	local cancel = UI.button({ text = embedded and "Cerrar" or "Cancelar", variant = "secondary", order = 2, sound = "back", onClick = function()
		if dirty() then
			draft = Util.deepCopy(Store.state.settings)
			renderRows()
			paintFooter()
			UI.toast("Cambios descartados", "info")
		elseif embedded and ctx.onClose then
			ctx.onClose()
		elseif not embedded then
			ctx.go("home")
		end
	end })
	cancel.inst.Parent = btns
	local apply = UI.button({ text = "Aplicar", icon = "check", variant = "primary", order = 3, onClick = function()
		Store.dispatch({ type = "SETTINGS_APPLY", settings = draft })
		draft = Util.deepCopy(Store.state.settings)
		paintFooter()
		UI.toast("Ajustes aplicados", "ok")
	end })
	apply.inst.Parent = btns

	function paintFooter()
		local d = dirty()
		apply.set({ disabled = not d })
		cancel.set({ text = d and "Cancelar" or (embedded and "Cerrar" or "Volver") })
		statusText.Text = d and "Cambios sin aplicar" or "Todo aplicado"
		statusText.TextColor3 = d and C.warn or C.steel2
		Icons.apply(statusIcon, d and "warning" or "check")
		statusIcon.ImageColor3 = d and C.warn or C.ok
		if renderPreview then
			renderPreview()
		end
	end

	function renderRows()
		for _, c in body:GetChildren() do
			if c:IsA("GuiObject") or c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		table.clear(controls)
		UI.list("v", m.gapSm).Parent = body
		local g
		for _, x in Settings.schema do
			if x.id == group then
				g = x
			end
		end
		local head = UI.header(g.label, { order = 0, size = "h2" })
		head.Parent = body
		local values = draft[g.id]
		for i, row in g.rows do
			local r = UI.surface({ Name = "Row_" .. row.key, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 + i, Parent = body }, { edge = C.ink700, pad = phone and 10 or 14, cut = 0.25 })
			local line = UI.box({ Size = UDim2.new(1, 0, 0, m.btnSm + 4), Parent = r })
			local labelBox = UI.box({ Size = UDim2.new(0.42, 0, 1, 0), Parent = line })
			UI.list("h", 8).Parent = labelBox
			UI.label("strong", row.label, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, TextSize = phone and m.small or m.body, Parent = labelBox })
			local ctl = UI.box({ Size = UDim2.new(0.58, 0, 1, 0), Position = UDim2.fromScale(0.42, 0), Parent = line })
			local function set(v)
				values[row.key] = v
				paintFooter()
			end
			if row.kind == "slider" then
				local s = UI.slider({ min = row.min, max = row.max, step = row.step, value = values[row.key], format = row.format, onChange = set, readoutWidth = 60 })
				s.inst.Parent = ctl
			elseif row.kind == "toggle" then
				local holder = UI.box({ Size = UDim2.fromScale(1, 1), Parent = ctl })
				UI.list("h", 10, { HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent = holder
				local state = UI.label("small", values[row.key] and "Activado" or "Desactivado", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = holder })
				local tg = UI.toggle({ value = values[row.key], order = 2, onChange = function(v)
					state.Text = v and "Activado" or "Desactivado"
					set(v)
				end })
				tg.inst.Parent = holder
			elseif row.kind == "choice" then
				local opts = {}
				for _, o in row.options do
					table.insert(opts, { value = o[1], label = o[2] })
				end
				local sg = UI.segmented({ options = opts, value = values[row.key], onChange = set, fill = true })
				sg.inst.Parent = ctl
			elseif row.kind == "swatch" then
				local holder = UI.box({ Size = UDim2.fromScale(1, 1), Parent = ctl })
				UI.list("h", 8, { HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent = holder
				local swatches = {}
				for j, key in row.options do
					local sw = UI.new("ImageButton", { Name = "Color_" .. key, BackgroundColor3 = Settings.crosshairColors[key], AutoButtonColor = false, ImageTransparency = 1, Size = UDim2.fromOffset(m.btnSm, m.btnSm), LayoutOrder = j, Parent = holder })
					UI.corner(m.btnSm).Parent = sw
					local st = UI.stroke(C.ink950, 3)
					st.Parent = sw
					swatches[key] = st
					sw.Activated:Connect(function()
						UI.sfx("click")
						for k2, s2 in swatches do
							s2.Color = k2 == key and C.paper or C.ink950
						end
						set(key)
					end)
					sw.SelectionGained:Connect(function()
						st.Thickness = 4
					end)
					sw.SelectionLost:Connect(function()
						st.Thickness = 3
					end)
				end
				swatches[values[row.key]].Color = C.paper
			end
			if row.help then
				UI.list("v", 4).Parent = r
				UI.label("micro", row.help, { LayoutOrder = 2, Parent = r })
			end
		end
		if group == "controls" then
			local keys = UI.surface({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 50, Parent = body }, { edge = C.ink700, pad = 14, cut = 0.25 })
			UI.list("v", 6).Parent = keys
			UI.label("eyebrow", "Teclas de la partida", { LayoutOrder = 1, Parent = keys })
			UI.para("Clic o Espacio dispara · clic derecho apunta · R recarga · 1 / 2 o rueda cambian de arma · G apoyo · Tab puntuaciones · P pausa.", { TextSize = m.small, LayoutOrder = 2, Parent = keys })
		end
	end

	-- group navigation
	local navButtons = {}
	local function paintNav()
		for id, b in navButtons do
			b.set({ selected = id == group })
			b.inst.ImageColor3 = id == group and C.ink600 or C.ink850
		end
	end
	if nav then
		for i, g in Settings.schema do
			local b = UI.button({ text = g.label, icon = g.icon, variant = "ghost", width = UDim.new(1, 0), align = "left", order = i, onClick = function()
				group = g.id
				paintNav()
				renderRows()
			end })
			b.inst.Parent = nav
			navButtons[g.id] = b
		end
	else
		local opts = {}
		for _, g in Settings.schema do
			table.insert(opts, { value = g.id, label = phone and g.label:sub(1, 5) .. (#g.label > 5 and "." or "") or g.label, icon = g.icon })
		end
		body.Size = UDim2.new(body.Size.X.Scale, body.Size.X.Offset, 1, -(footerH + m.pad + m.btnSm + 6 + m.gapSm))
		body.Position = UDim2.new(body.Position.X.Scale, body.Position.X.Offset, 0, m.btnSm + 6 + m.gapSm)
		seg = UI.segmented({ options = opts, value = group, fill = true, onChange = function(v)
			group = v
			renderRows()
		end })
		seg.inst.Size = UDim2.new(1 - previewW, 0, 0, m.btnSm + 6)
		seg.inst.Parent = root
	end

	-- live preview of interface settings (desktop)
	if preview then
		UI.list("v", 10).Parent = preview
		UI.header("Vista previa", { order = 1 }).Parent = preview
		local stage = UI.new("ImageLabel", { Name = "Sample", BackgroundTransparency = 1, ImageColor3 = C.ink600, Size = UDim2.new(1, 0, 0, 200), LayoutOrder = 2, ClipsDescendants = true, Parent = preview })
		Icons.apply(stage, "panelTone")
		stage.SliceScale = 0.3
		local sky = UI.fill(Color3.fromHex("#9A7A62"), { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Parent = stage })
		UI.corner(4).Parent = sky
		UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#C9946A"), Color3.fromHex("#3E4650")), Parent = sky })
		local sampleHolder = UI.box({ Parent = sky })
		local note = UI.para("", { TextSize = m.small, LayoutOrder = 3, Parent = preview })
		function renderPreview()
			for _, c in sampleHolder:GetChildren() do
				c:Destroy()
			end
			Settings.crosshair(sampleHolder, draft)
			local k = draft.interface.hudScale / 100
			local hp = UI.box({ Size = UDim2.fromOffset(110, 30), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Parent = sampleHolder })
			UI.new("UIScale", { Scale = k, Parent = hp })
			UI.label("num", "100", { TextSize = 22, Size = UDim2.fromOffset(50, 22), Parent = hp })
			local b = UI.bar({ height = 4, value = 100, max = 100, color = C.paper, size = UDim2.fromOffset(100, 4) })
			b.inst.Position = UDim2.fromOffset(0, 24)
			b.inst.Parent = hp
			local ammo = UI.box({ Size = UDim2.fromOffset(90, 30), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Parent = sampleHolder })
			UI.new("UIScale", { Scale = k, Parent = ammo })
			UI.label("num", "30 / 120", { TextSize = 22, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = ammo })
			local pal = Theme.teamPalettes[draft.accessibility.colorblind and "colorblind" or "default"]
			for j, col in { pal.ally, pal.enemy } do
				local chip = UI.fill(col, { Size = UDim2.fromOffset(34, 18), Position = UDim2.new(0.5, j == 1 and -38 or 4, 0, 10), Parent = sampleHolder })
				UI.corner(3).Parent = chip
				UI.label("num", j == 1 and "12" or "9", { TextSize = 14, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.ink950, Parent = chip })
			end
			note.Text = string.format("Mira %s al %d %% · HUD al %d %% · equipos %s.", ({ cross = "en cruz", dot = "de punto", circle = "circular" })[draft.interface.crosshair], draft.interface.crosshairSize, draft.interface.hudScale, draft.accessibility.colorblind and "azul / ámbar" or "azul / rojo")
		end
	end

	paintNav()
	renderRows()
	paintFooter()

	-- guard: leaving with unapplied changes
	if ctx.setGuard then
		ctx.setGuard(function(proceed)
			if not dirty() then
				proceed()
				return
			end
			UI.confirm({
				title = "¿Descartar cambios?",
				body = "Tienes ajustes sin aplicar. Si sales ahora se perderán.",
				cancelText = "Seguir editando",
				confirmText = "Descartar",
				tone = "danger",
				onConfirm = proceed,
			})
		end)
	end
	Settings.isDirty = dirty
end

return Settings
