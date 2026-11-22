-- PIVOT component kit. Every screen builds its interface from these pieces so that
-- spacing, type, colours and interaction states stay identical everywhere.
-- States handled by the interactive components: hover, pressed, selected, focused (keyboard
-- selection ring), disabled and loading.

local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local PivotUI = script.Parent
local Theme = require(PivotUI.Theme)
local Util = require(PivotUI.Util)
local Icons = require(PivotUI.Icons)
local Catalog = require(PivotUI.Data.Catalog)

local C = Theme.color
local F = Theme.font

local UI = {}
UI.C = C
UI.F = F
UI.layout = "desktop"
UI.m = Theme.metrics("desktop")
UI.touch = false
UI.overlay = nil :: ScreenGui?

function UI.setLayout(layout: string, touch: boolean)
	UI.layout = layout
	UI.m = Theme.metrics(layout)
	UI.touch = touch
end

function UI.isPhone(): boolean
	return UI.layout == "phone"
end

---------------------------------------------------------------- text helpers
local ACCENTS = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü" }
function UI.upper(text: string): string
	local out = text:upper()
	for lower, upper in ACCENTS do
		out = out:gsub(lower, upper)
	end
	return out
end

---------------------------------------------------------------- sound
-- Engine-bundled sound, pitched per event. Volume follows Settings > Audio (SoundGroup).
local sfxGroup = SoundService:FindFirstChild("PivotSFX") or Instance.new("SoundGroup")
sfxGroup.Name = "PivotSFX"
sfxGroup.Parent = SoundService
UI.sfxGroup = sfxGroup
local SFX = {
	click = { pitch = 1.35, vol = 0.35 },
	hover = { pitch = 2.2, vol = 0.08 },
	confirm = { pitch = 1.0, vol = 0.45 },
	back = { pitch = 0.85, vol = 0.3 },
	error = { pitch = 0.55, vol = 0.45 },
	reward = { pitch = 1.7, vol = 0.5 },
	found = { pitch = 1.2, vol = 0.6 },
	hit = { pitch = 2.6, vol = 0.35 },
	kill = { pitch = 1.9, vol = 0.6 },
	shot = { pitch = 0.7, vol = 0.25 },
	reload = { pitch = 1.1, vol = 0.35 },
}
local sounds = {}
for name, def in SFX do
	local snd = Instance.new("Sound")
	snd.Name = "PivotSFX_" .. name
	snd.SoundId = "rbxasset://sounds/volume_slider.ogg"
	snd.PlaybackSpeed = def.pitch
	snd.Volume = def.vol
	snd.SoundGroup = sfxGroup
	snd.Parent = sfxGroup
	sounds[name] = snd
end
function UI.sfx(name: string)
	local snd = sounds[name]
	if snd then
		SoundService:PlayLocalSound(snd)
	end
end

---------------------------------------------------------------- primitives
function UI.new(class: string, props, children)
	local inst = Instance.new(class)
	local parent
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			elseif type(k) == "number" then
				v.Parent = inst
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local new = UI.new

local function merge(defaults, props)
	if props then
		for k, v in props do
			defaults[k] = v
		end
	end
	return defaults
end

function UI.corner(px: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, px or UI.m.radius) })
end

function UI.stroke(color: Color3?, thickness: number?, transparency: number?)
	return new("UIStroke", { Color = color or C.ink700, Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UI.pad(top: number, right: number?, bottom: number?, left: number?)
	right = right or top
	bottom = bottom or top
	left = left or right
	return new("UIPadding", {
		PaddingTop = UDim.new(0, top), PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom), PaddingLeft = UDim.new(0, left),
	})
end

-- Vertical ("v") or horizontal ("h") list in LayoutOrder.
function UI.list(dir: string, gap: number?, props)
	return new("UIListLayout", merge({
		FillDirection = dir == "h" and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = dir == "h" and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top,
	}, props))
end

function UI.flex(mode: string?, grow: number?)
	return new("UIFlexItem", { FlexMode = mode == "grow" and Enum.UIFlexMode.Grow or Enum.UIFlexMode.Fill, GrowRatio = grow or 1 })
end

function UI.box(props)
	return new("Frame", merge({ BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, props))
end

function UI.fill(color: Color3, props)
	return new("Frame", merge({ BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, props))
end

-- Text. `kind` picks the type role: display (condensed caps), title, body, small, micro, mono, num.
function UI.label(kind: string, text: string, props)
	local m = UI.m
	local font, size, color = F.body, m.body, C.paper
	if kind == "h1" then
		font, size = F.display, m.h1
	elseif kind == "h2" then
		font, size = F.display, m.h2
	elseif kind == "h3" then
		font, size = F.displayMedium, m.h3
	elseif kind == "title" then
		font, size = F.bodyBold, m.body + 1
	elseif kind == "body" then
		font, size, color = F.bodyRegular, m.body, C.steel2
	elseif kind == "strong" then
		font, size = F.bodySemi, m.body
	elseif kind == "small" then
		font, size, color = F.body, m.small, C.steel2
	elseif kind == "micro" then
		font, size, color = F.bodySemi, m.micro, C.steel
	elseif kind == "eyebrow" then
		font, size, color = F.displayMedium, m.micro + 1, C.steel
	elseif kind == "mono" then
		font, size, color = F.mono, m.small, C.steel2
	elseif kind == "num" then
		font, size = F.display, m.h2
	end
	if kind == "h1" or kind == "h2" or kind == "h3" or kind == "eyebrow" then
		text = UI.upper(text)
	end
	local label = new("TextLabel", merge({
		Name = "Label",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = font,
		TextSize = size,
		TextColor3 = color,
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, math.ceil(size * 1.3)),
		LineHeight = 1.05,
	}, props))
	-- a label that sizes itself to its text never truncates: inside a panel that is scaling in, the width
	-- is measured a few pixels short and "AtEnd" would clip the last characters for good
	if label.AutomaticSize == Enum.AutomaticSize.X or label.AutomaticSize == Enum.AutomaticSize.XY then
		label.TextTruncate = Enum.TextTruncate.None
	end
	return label
end

-- Wrapped paragraph that grows to fit its text.
function UI.para(text: string, props)
	return UI.label("body", text, merge({
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.15,
	}, props))
end

function UI.icon(name: string, size: number, color: Color3?, props)
	local img = new("ImageLabel", merge({
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		ImageColor3 = color or C.paper,
		ScaleType = Enum.ScaleType.Fit,
	}, props))
	Icons.apply(img, name)
	return img
end

-- 9-slice atlas shape (panelCut, btnCut, pill, rounded...) as a background layer.
function UI.shape(name: string, color: Color3, props)
	local img = new("ImageLabel", merge({
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = color,
		SliceScale = 0.5,
		ZIndex = 0,
	}, props))
	Icons.apply(img, name)
	return img
end

-- Panel surface: a single two-tone 9-slice image (cut top-right corner, outline lighter than the fill).
-- `opts.edge` is the outline colour and the fill comes out at 62 % of it (ink700 edge -> ink850 fill).
-- `opts.flat` draws a plain fill of `opts.color` without outline. Children and layouts go straight inside.
function UI.surface(props, opts)
	opts = opts or {}
	local img = new("ImageLabel", merge({ Name = "Panel", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, props))
	if opts.flat then
		Icons.apply(img, "panelCut")
		img.ImageColor3 = opts.color or C.ink850
	else
		Icons.apply(img, "panelTone")
		img.ImageColor3 = opts.edge or C.ink700
	end
	img.SliceScale = opts.cut or 0.5
	if opts.pad ~= false then
		UI.pad(opts.pad or UI.m.pad).Parent = img
	end
	return img
end

-- Section header: signal tick, condensed caps title, optional index ("02") and right-side slot.
function UI.header(title: string, opts)
	opts = opts or {}
	local m = UI.m
	local size = opts.size or "h3"
	local h = math.ceil((size == "h2" and m.h2 or m.h3) * 1.35)
	local row = UI.box({ Name = "Header", Size = UDim2.new(1, 0, 0, h), LayoutOrder = opts.order or 0 })
	local left = UI.box({ Name = "Left", Size = UDim2.new(1, 0, 1, 0), Parent = row })
	UI.list("h", 8).Parent = left
	local tick = new("ImageLabel", { Name = "Tick", BackgroundTransparency = 1, ImageColor3 = opts.tick or C.signal, Size = UDim2.fromOffset(math.floor(h * 0.4), math.floor(h * 0.6)), LayoutOrder = 1, Parent = left })
	Icons.apply(tick, "hatchSlant")
	if opts.index then
		UI.label("mono", opts.index, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = C.steel, LayoutOrder = 2, Parent = left })
	end
	local t = UI.label(size, title, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, Parent = left })
	if opts.right then
		opts.right.AnchorPoint = Vector2.new(1, 0.5)
		opts.right.Position = UDim2.fromScale(1, 0.5)
		opts.right.Parent = row
	end
	return row, t
end

function UI.divider(props)
	return UI.fill(C.ink700, merge({ Name = "Divider", Size = UDim2.new(1, 0, 0, 1) }, props))
end

function UI.scroll(props)
	return new("ScrollingFrame", merge({
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.ink600,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Selectable = false,
	}, props))
end

function UI.spinner(size: number, color: Color3?)
	local img = UI.icon("spinner", size, color or C.paper, { Name = "Spinner" })
	if not Util.reducedMotion then
		local tw = game:GetService("TweenService"):Create(img, TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
		tw:Play()
	end
	return img
end

-- Key hint shown next to actions on keyboard layouts (hidden on touch).
function UI.keycap(key: string, props)
	local m = UI.m
	local cap = new("Frame", merge({
		Name = "Key",
		BackgroundColor3 = C.ink950,
		BackgroundTransparency = 0.2,
		Size = UDim2.fromOffset(0, m.micro + 8),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = not UI.touch,
	}, props))
	UI.corner(3).Parent = cap
	UI.stroke(C.ink600, 1).Parent = cap
	UI.pad(0, 5).Parent = cap
	UI.label("mono", key, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextSize = m.micro, TextColor3 = C.steel2, TextXAlignment = Enum.TextXAlignment.Center, Parent = cap })
	return cap
end

---------------------------------------------------------------- button
local VARIANTS = {
	primary = { fill = C.signal, hover = C.signal2, press = C.signalDeep, text = C.signalInk, font = F.display, upper = true, slant = true, hatch = true },
	secondary = { fill = C.ink700, hover = C.ink600, press = C.ink800, text = C.paper, font = F.bodySemi },
	ghost = { fill = C.ink850, hover = C.ink800, press = C.ink900, text = C.steel2, textHover = C.paper, font = F.bodySemi, edge = C.ink600 },
	light = { fill = C.paper, hover = C.white, press = C.paper2, text = C.paperInk, font = F.display, upper = true, slant = true },
	danger = { fill = Color3.fromHex("#3B2024"), hover = Color3.fromHex("#4C252A"), press = Color3.fromHex("#2E191C"), text = Color3.fromHex("#FFB0B2"), font = F.bodySemi, edge = C.bad },
	claim = { fill = C.brass, hover = Color3.fromHex("#F0C978"), press = Color3.fromHex("#B88E3E"), text = C.signalInk, font = F.display, upper = true, slant = true },
}

-- Controls that draw their own focus state point Roblox's selection image at an empty frame,
-- so keyboard/gamepad focus shows one indicator, not the generic ring on top of the custom one.
local noRing = new("Frame", { Name = "NoSelectionRing", BackgroundTransparency = 1, Size = UDim2.fromScale(0, 0) })
function UI.ownFocus(inst)
	inst.SelectionImageObject = noRing
end

--[[ UI.button(opts)
	text, icon, variant (primary|secondary|ghost|light|danger|claim), size (sm|md|lg),
	width (UDim, default auto), flex (fill its row), key (keycap hint), onClick,
	disabled, loading, loadingText, selected, name, order, tooltip
	Returns an api: { inst, set(patch), click() }.
]]
function UI.button(opts)
	local m = UI.m
	local v = VARIANTS[opts.variant or "secondary"]
	local h = opts.height or (opts.size == "lg" and m.btnLg or (opts.size == "sm" and m.btnSm or m.btn))
	local st = { hover = false, press = false, focus = false, disabled = opts.disabled == true, loading = opts.loading == true, selected = opts.selected == true, text = opts.text or "" }

	local cut = h >= 50 and 0.42 or 0.34
	-- Action variants lean forward (parallelogram); the rest are chamfered plates. Icon-only squares
	-- stay plates so toolbars and steppers keep a calm, square rhythm.
	local slanted = v.slant and opts.text ~= nil and opts.text ~= ""
	local shapeName = slanted and "btnSlant" or "btnCut"
	local strokeName = slanted and "btnSlantStroke" or "btnCutStroke"
	-- the button image is the cut fill itself; outline and focus ring are full-size overlays
	local btn = new("ImageButton", {
		Name = opts.name or "Button",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		ImageColor3 = v.fill,
		Size = opts.width and UDim2.new(opts.width.Scale, opts.width.Offset, 0, h) or UDim2.fromOffset(0, h),
		AutomaticSize = opts.width and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		LayoutOrder = opts.order or 0,
		Selectable = true,
	})
	Icons.apply(btn, shapeName)
	btn.SliceScale = cut
	local fill = btn
	local edge
	if v.edge then
		edge = UI.shape(strokeName, v.edge, { Name = "Edge", SliceScale = cut, Parent = btn })
	end
	-- focus: plates get a full outline; slanted buttons get a bar along the bottom edge (in the label
	-- colour, inside the paint), which reads clearly on the bright fills and has no slanted joins
	local ring
	if slanted then
		local inset = math.ceil(30 * cut) + 4
		ring = new("Frame", {
			Name = "Focus",
			BackgroundColor3 = v.text,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -2 * inset, 0, 3),
			Position = UDim2.new(0, inset, 1, -6),
			Visible = false,
			ZIndex = 3,
			Parent = btn,
		})
	else
		ring = UI.shape(strokeName, C.paper, { Name = "Focus", SliceScale = cut, Visible = false, ZIndex = 3, Parent = btn })
	end
	UI.ownFocus(btn)
	local scale = new("UIScale", { Parent = btn })
	if opts.flex then
		UI.flex(opts.flex == "grow" and "grow" or "fill").Parent = btn
	end

	local padX = opts.compact and math.floor(h * 0.3) or math.floor(h * 0.48)
	-- the slanted edges eat 24/128 of the slice on each side: keep the content clear of them
	local slantInset = slanted and math.ceil(24 * cut) or 0
	local content = UI.box({
		Name = "Content",
		ZIndex = 2,
		Size = opts.width and UDim2.fromScale(1, 1) or UDim2.fromScale(0, 1),
		AutomaticSize = opts.width and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		Parent = btn,
	})
	-- auto-width buttons grow to clear the slant; fixed-width ones keep their room for the label
	local sidePad = opts.width and math.max(padX, slantInset + 4) or padX + slantInset
	UI.pad(0, sidePad, 0, sidePad).Parent = content
	UI.list("h", math.floor(h * 0.2), { HorizontalAlignment = opts.align == "left" and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center }).Parent = content
	-- hazard lead-in on the main call to action: the same forward slant, printed into the paint
	if v.hatch and slanted and h >= m.btn and not opts.compact then
		local hatchH = math.floor(h * 0.5)
		new("ImageLabel", {
			Name = "Hatch",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(math.floor(hatchH * 0.66), hatchH),
			ImageColor3 = v.text,
			ImageTransparency = 0.72,
			LayoutOrder = -1,
			ZIndex = 2,
			Parent = content,
		}, nil)
		Icons.apply(content:FindFirstChild("Hatch"), "hatchSlant")
	end

	local iconSize = math.floor(h * 0.44)
	local icon = opts.icon and UI.icon(opts.icon, iconSize, v.text, { LayoutOrder = 1, ZIndex = 2, Parent = content }) or nil
	local textSize = opts.size == "lg" and math.floor(m.h3 * 1.08) or (opts.size == "sm" and m.small or m.body)
	local label = new("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		FontFace = v.font,
		TextSize = v.upper and textSize + 1 or textSize,
		TextColor3 = v.text,
		Text = v.upper and UI.upper(st.text) or st.text,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 2,
		ZIndex = 2,
		Visible = st.text ~= "",
		Parent = content,
	})
	if not opts.width then
		-- auto-width buttons grow with the label, so it never needs (or gets) an ellipsis
		label.TextTruncate = Enum.TextTruncate.None
	end
	if opts.width then
		-- nothing spills past the slant: with a key hint the label fills the gap so the key sits on the edge;
		-- otherwise icon and label stay together in the centre and the label only shrinks (with "…") if it must
		label.TextXAlignment = opts.align == "left" and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
		if opts.key or opts.align == "left" then
			label.AutomaticSize = Enum.AutomaticSize.None
			label.Size = UDim2.fromScale(0, 1)
			UI.flex("fill").Parent = label
		else
			new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Shrink, Parent = label })
		end
	end
	local key = opts.key and UI.keycap(opts.key, { LayoutOrder = 3, ZIndex = 2, Parent = content }) or nil
	local spin

	local api = { inst = btn, label = label }

	local function paint(instant)
		local color, textColor = v.fill, v.text
		if st.disabled then
			color = C.ink800
			textColor = C.steel
		elseif st.loading then
			color = v.press
		elseif st.press then
			color = v.press
		elseif st.hover or st.focus then
			color = v.hover
			textColor = v.textHover or v.text
		end
		if st.selected and not st.disabled then
			textColor = v.textHover or v.text
		end
		local t = instant and 0 or Theme.motion.fast
		Util.tween(fill, t, { ImageColor3 = color })
		label.TextColor3 = textColor
		label.TextTransparency = st.disabled and 0.25 or 0
		if icon then
			icon.ImageColor3 = textColor
			icon.ImageTransparency = st.disabled and 0.35 or 0
		end
		if edge then
			edge.ImageColor3 = st.selected and C.signal or (st.disabled and C.ink700 or v.edge)
		end
		ring.Visible = st.focus
		Util.tween(scale, Theme.motion.fast, { Scale = st.press and 0.965 or 1 })
		btn.Interactable = not st.disabled
		btn.Selectable = not st.disabled
	end

	local function setLoading(on)
		if on and not spin then
			spin = UI.spinner(math.floor(h * 0.42), v.text)
			spin.LayoutOrder = 0
			spin.ZIndex = 2
			spin.Parent = content
			if icon then
				icon.Visible = false
			end
		elseif not on and spin then
			spin:Destroy()
			spin = nil
			if icon then
				icon.Visible = true
			end
		end
		local text = on and (opts.loadingText or st.text) or st.text
		label.Text = v.upper and UI.upper(text) or text
	end

	function api.set(patch)
		for k, val in patch do
			st[k] = val
		end
		if patch.text ~= nil then
			label.Text = v.upper and UI.upper(st.text) or st.text
			label.Visible = st.text ~= ""
		end
		if patch.icon and icon then
			Icons.apply(icon, patch.icon)
		end
		if patch.loading ~= nil then
			setLoading(st.loading)
		end
		paint(false)
	end

	function api.isEnabled()
		return not st.disabled and not st.loading
	end

	function api.click()
		if st.disabled or st.loading then
			return
		end
		if opts.onClick then
			UI.sfx(opts.sound or (opts.variant == "primary" and "confirm" or "click"))
			opts.onClick(api)
		end
	end

	btn.MouseEnter:Connect(function()
		if st.disabled then
			return
		end
		st.hover = true
		paint(false)
	end)
	btn.MouseLeave:Connect(function()
		st.hover = false
		st.press = false
		paint(false)
	end)
	btn.MouseButton1Down:Connect(function()
		if st.disabled or st.loading then
			return
		end
		st.press = true
		paint(false)
	end)
	btn.MouseButton1Up:Connect(function()
		st.press = false
		paint(false)
	end)
	btn.SelectionGained:Connect(function()
		st.focus = true
		paint(false)
	end)
	btn.SelectionLost:Connect(function()
		st.focus = false
		paint(false)
	end)
	btn.Activated:Connect(function()
		st.press = false
		api.click()
		paint(false)
	end)

	if st.loading then
		setLoading(true)
	end
	paint(true)
	return api
end

-- Square icon-only button (close, steppers, toolbar). `label` is announced as its name.
function UI.iconButton(opts)
	local m = UI.m
	local size = opts.size or m.btnSm
	local api = UI.button({
		name = opts.name or opts.label or "IconButton",
		icon = opts.icon,
		text = "",
		variant = opts.variant or "ghost",
		height = size,
		width = UDim.new(0, size),
		compact = true,
		onClick = opts.onClick,
		disabled = opts.disabled,
		order = opts.order,
		sound = opts.sound,
	})
	-- centre the icon in the square
	local content = api.inst:FindFirstChild("Content")
	local pad = content:FindFirstChildOfClass("UIPadding")
	if pad then
		pad:Destroy()
	end
	return api
end

---------------------------------------------------------------- small pieces
function UI.tag(text: string, color: Color3, opts)
	opts = opts or {}
	local m = UI.m
	local h = opts.height or (m.micro + 10)
	local solid = opts.solid
	local tag = new("ImageLabel", { Name = opts.name or "Tag", BackgroundTransparency = 1, ImageColor3 = solid and color or color:Lerp(C.ink900, 0.8), Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = opts.order or 0 })
	-- cargo tag: pointed left end with an eyelet, like the tags wired onto crates on the dock
	Icons.apply(tag, "tagCargo")
	tag.SliceScale = h / 128
	UI.pad(0, math.floor(h * 0.5), 0, math.floor(h * 0.92)).Parent = tag
	local row = tag
	UI.list("h", 4).Parent = row
	if opts.icon then
		UI.icon(opts.icon, h - 6, solid and C.signalInk or color, { LayoutOrder = 1, Parent = row })
	end
	UI.label("micro", UI.upper(text), {
		FontFace = F.displayMedium,
		TextSize = m.micro + 1,
		TextColor3 = solid and (opts.textColor or C.signalInk) or color,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = row,
	})
	return tag
end

function UI.rarityTag(rarity: string, opts)
	return UI.tag(Catalog.rarityName[rarity], Theme.rarity[rarity], opts)
end

-- Progress bar. api.set(value, max) animates the fill.
function UI.bar(opts)
	opts = opts or {}
	local h = opts.height or 6
	local track = UI.fill(opts.track or C.ink700, { Name = opts.name or "Bar", Size = opts.size or UDim2.new(1, 0, 0, h), LayoutOrder = opts.order or 0, ClipsDescendants = true })
	UI.corner(math.ceil(h / 2)).Parent = track
	local fill = UI.fill(opts.color or C.signal, { Name = "Fill", Size = UDim2.fromScale(0, 1), Parent = track })
	UI.corner(math.ceil(h / 2)).Parent = fill
	local api = { inst = track, fill = fill }
	function api.set(value: number, max: number, animate: boolean?)
		local p = max > 0 and math.clamp(value / max, 0, 1) or 0
		Util.tween(fill, animate and Theme.motion.slow * 2 or 0, { Size = UDim2.fromScale(p, 1) })
	end
	function api.color(c: Color3)
		fill.BackgroundColor3 = c
	end
	api.set(opts.value or 0, opts.max or 100, false)
	return api
end

-- Credits: brass glyph + tabular figure. api.set(value, animate).
function UI.credits(value: number, opts)
	opts = opts or {}
	local m = UI.m
	local size = opts.textSize or m.body
	local row = UI.box({ Name = "Credits", Size = UDim2.fromOffset(0, math.ceil(size * 1.3)), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = opts.order or 0 })
	UI.list("h", math.max(4, math.floor(size * 0.3))).Parent = row
	UI.icon("credits", math.floor(size * 0.95), C.brass, { LayoutOrder = 1, Parent = row })
	local num = UI.label("num", Util.num(value), {
		FontFace = opts.font or F.display,
		TextSize = size + 2,
		TextColor3 = opts.color or C.paper,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = row,
	})
	local api = { inst = row, num = num, value = value }
	function api.set(v: number, animate: boolean?)
		if animate then
			Util.countTo(num, api.value, v, 0.65)
		else
			num.Text = Util.num(v)
		end
		api.value = v
	end
	return api
end

function UI.emblem(id: string, size: number, props)
	local item = Catalog.get(id) or Catalog.get("pivot")
	return UI.icon("emblem_" .. item.id, size, item.color, merge({ Name = "Emblem" }, props))
end

-- Avatar tile: the real Roblox headshot for the local player, a monogram tile for simulated players.
function UI.avatar(opts)
	local size = opts.size or 40
	local tile = new("Frame", { Name = "Avatar", BackgroundColor3 = opts.color or C.ink700, Size = UDim2.fromOffset(size, size), LayoutOrder = opts.order or 0, ClipsDescendants = true })
	UI.corner(math.floor(size * 0.18)).Parent = tile
	if opts.userId then
		new("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", opts.userId),
			Parent = tile,
		})
	else
		local name = opts.name or "?"
		local initials = name:gsub("[^%w]", ""):sub(1, 2):upper()
		if opts.emblem then
			UI.emblem(opts.emblem, math.floor(size * 0.62), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = tile })
		else
			UI.label("h3", initials, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = math.floor(size * 0.42), Parent = tile })
		end
	end
	if opts.ring then
		UI.stroke(opts.ring, 2).Parent = tile
	end
	return tile
end

-- Player card background: banner gradient + pattern, used in lobby, profile, party and results.
function UI.banner(id: string, props)
	local item = Catalog.get(id) or Catalog.get("grid")
	local frame = new("Frame", merge({ Name = "Banner", BackgroundColor3 = C.white, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ClipsDescendants = true }, props))
	new("UIGradient", { Color = ColorSequence.new(item.colors[1], item.colors[2]), Rotation = 0, Parent = frame })
	local pat = new("ImageLabel", { Name = "Pattern", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ImageColor3 = C.white, ImageTransparency = 0.9, ScaleType = Enum.ScaleType.Crop, Parent = frame })
	Icons.apply(pat, "pattern_" .. item.id)
	pat.ScaleType = Enum.ScaleType.Crop
	return frame
end

---------------------------------------------------------------- choice controls
--[[ UI.segmented({ options = {{value, label, icon?, disabled?}}, value, onChange, size, order, fill })
	A row of mutually exclusive buttons (radio group). Arrow keys move between them with UI navigation. ]]
function UI.segmented(opts)
	local m = UI.m
	local h = opts.height or m.btnSm
	local row = UI.box({ Name = opts.name or "Segmented", Size = UDim2.new(opts.fill and 1 or 0, 0, 0, h + 6), AutomaticSize = opts.fill and Enum.AutomaticSize.None or Enum.AutomaticSize.X, LayoutOrder = opts.order or 0 })
	local track = UI.surface({ Name = "Track", Size = UDim2.fromScale(opts.fill and 1 or 0, 1), AutomaticSize = opts.fill and Enum.AutomaticSize.None or Enum.AutomaticSize.X, Parent = row }, { edge = C.ink700, pad = 3, cut = 0.3 })
	UI.list("h", 2).Parent = track
	local value = opts.value
	local items = {}
	local api = { inst = row }
	local function paint()
		for _, it in items do
			local on = it.value == value
			it.fill.ImageTransparency = on and 0 or 1
			it.text.TextColor3 = it.disabled and C.ink600 or (on and C.paper or C.steel)
			it.bar.Visible = on
		end
	end
	for i, o in opts.options do
		local b = new("ImageButton", {
			Name = "Option_" .. tostring(o.value),
			BackgroundTransparency = 1,
			ImageColor3 = C.ink600,
			ImageTransparency = 1,
			AutoButtonColor = false,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = i,
			Selectable = not o.disabled,
			Interactable = not o.disabled,
			Parent = track,
		})
		Icons.apply(b, "rounded")
		b.SliceScale = 0.25
		local fill = b
		local inner = UI.box({ Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 2, Parent = b })
		UI.pad(0, math.floor(h * 0.38)).Parent = inner
		UI.list("h", 6).Parent = inner
		if o.icon then
			UI.icon(o.icon, math.floor(h * 0.45), C.steel2, { LayoutOrder = 1, Parent = inner })
		end
		local text = UI.label("strong", o.label, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextSize = m.small, LayoutOrder = 2, Parent = inner })
		local bar = UI.fill(C.signal, { Name = "On", Size = UDim2.new(1, -16, 0, 2), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Visible = false, ZIndex = 3, Parent = b })
		if opts.fill then
			-- equal columns; the label never truncates inside its own column
			b.AutomaticSize = Enum.AutomaticSize.None
			b.Size = UDim2.new(1 / #opts.options, -2, 1, 0)
			-- the label fills its column (centred) and scales down a little if the column is too narrow
			inner.AutomaticSize = Enum.AutomaticSize.None
			inner.Size = UDim2.fromScale(1, 1)
			inner:FindFirstChildOfClass("UIPadding"):Destroy()
			UI.pad(0, 4).Parent = inner
			inner:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
			text.TextTruncate = Enum.TextTruncate.None
			text.AutomaticSize = Enum.AutomaticSize.None
			text.Size = UDim2.new(1, o.icon and -(math.floor(h * 0.45) + 6) or 0, 1, 0)
			text.TextXAlignment = o.icon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
			text.TextScaled = true
			new("UITextSizeConstraint", { MaxTextSize = m.small, MinTextSize = 9, Parent = text })
		end
		local ring = UI.shape("roundedStroke", C.paper, { Name = "Focus", SliceScale = 0.25, Visible = false, ZIndex = 3, Parent = b })
		UI.ownFocus(b)
		local it = { value = o.value, fill = fill, text = text, bar = bar, disabled = o.disabled }
		table.insert(items, it)
		b.MouseEnter:Connect(function()
			if it.value ~= value and not it.disabled then
				text.TextColor3 = C.paper
			end
		end)
		b.MouseLeave:Connect(paint)
		b.SelectionGained:Connect(function()
			ring.Visible = true
		end)
		b.SelectionLost:Connect(function()
			ring.Visible = false
		end)
		b.Activated:Connect(function()
			if it.disabled or value == it.value then
				return
			end
			value = it.value
			UI.sfx("click")
			paint()
			if opts.onChange then
				opts.onChange(value)
			end
		end)
	end
	function api.set(v)
		value = v
		paint()
	end
	function api.get()
		return value
	end
	paint()
	return api
end

-- On/off switch.
function UI.toggle(opts)
	local w, h = 46, 26
	local value = opts.value == true
	local b = new("ImageButton", { Name = opts.name or "Toggle", BackgroundColor3 = C.ink700, AutoButtonColor = false, ImageTransparency = 1, Size = UDim2.fromOffset(w, h), LayoutOrder = opts.order or 0, Selectable = true })
	UI.corner(h // 2).Parent = b
	local st = UI.stroke(C.ink600, 1)
	st.Parent = b
	local knob = UI.fill(C.steel2, { Name = "Knob", Size = UDim2.fromOffset(h - 8, h - 8), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Parent = b })
	UI.corner(h).Parent = knob
	UI.ownFocus(b)
	local api = { inst = b }
	local function paint(instant)
		local t = instant and 0 or Theme.motion.base
		Util.tween(b, t, { BackgroundColor3 = value and C.signal or C.ink700 })
		Util.tween(knob, t, { Position = value and UDim2.new(1, -(h - 4), 0.5, 0) or UDim2.new(0, 4, 0.5, 0), BackgroundColor3 = value and C.signalInk or C.steel2 })
		st.Color = value and C.signal or C.ink600
	end
	b.SelectionGained:Connect(function()
		st.Color = C.paper
		st.Thickness = 2
	end)
	b.SelectionLost:Connect(function()
		st.Thickness = 1
		paint(true)
	end)
	b.Activated:Connect(function()
		value = not value
		UI.sfx("click")
		paint(false)
		if opts.onChange then
			opts.onChange(value)
		end
	end)
	function api.set(v)
		value = v
		paint(true)
	end
	paint(true)
	return api
end

--[[ UI.slider({ min, max, step, value, onChange, format, width, order })
	Drag the track (mouse or touch) or use the - / + steppers (keyboard and precise touch input). ]]
function UI.slider(opts)
	local m = UI.m
	local value = opts.value
	local row = UI.box({ Name = opts.name or "Slider", Size = UDim2.new(opts.width or UDim.new(1, 0), UDim.new(0, m.btnSm)), LayoutOrder = opts.order or 0 })
	UI.list("h", 8).Parent = row
	local function snap(v)
		local s = opts.step or 1
		return math.clamp(math.round(v / s) * s, opts.min, opts.max)
	end
	local minus = UI.iconButton({ icon = "minus", label = "Bajar", size = m.btnSm, order = 1 })
	minus.inst.Parent = row
	local trackHit = new("ImageButton", { Name = "Track", BackgroundTransparency = 1, ImageTransparency = 1, AutoButtonColor = false, Size = UDim2.new(1, 0, 1, 0), LayoutOrder = 2, Selectable = false, Parent = row })
	UI.flex("fill").Parent = trackHit
	local track = UI.fill(C.ink700, { Name = "Rail", Size = UDim2.new(1, 0, 0, 4), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Parent = trackHit })
	UI.corner(2).Parent = track
	local fill = UI.fill(C.signal, { Name = "Fill", Size = UDim2.fromScale(0, 1), Parent = track })
	UI.corner(2).Parent = fill
	local knob = UI.fill(C.paper, { Name = "Knob", Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), ZIndex = 2, Parent = track })
	UI.corner(8).Parent = knob
	UI.stroke(C.ink950, 2).Parent = knob
	local plus = UI.iconButton({ icon = "plus", label = "Subir", size = m.btnSm, order = 3 })
	plus.inst.Parent = row
	local readout = UI.label("strong", "", { Size = UDim2.fromOffset(opts.readoutWidth or 56, m.btnSm), TextXAlignment = Enum.TextXAlignment.Right, FontFace = F.display, TextSize = m.body + 1, LayoutOrder = 4, Parent = row })
	local api = { inst = row }
	local function paint()
		local p = (value - opts.min) / (opts.max - opts.min)
		fill.Size = UDim2.fromScale(p, 1)
		knob.Position = UDim2.fromScale(p, 0.5)
		readout.Text = opts.format and opts.format(value) or tostring(value)
		minus.set({ disabled = value <= opts.min })
		plus.set({ disabled = value >= opts.max })
	end
	local function setValue(v, fire)
		v = snap(v)
		if v == value then
			return
		end
		value = v
		paint()
		if fire and opts.onChange then
			opts.onChange(value)
		end
	end
	local function fromX(x)
		local p = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		setValue(opts.min + p * (opts.max - opts.min), true)
	end
	local dragging
	trackHit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			fromX(input.Position.X)
			if dragging then
				dragging:Disconnect()
			end
			dragging = UserInputService.InputChanged:Connect(function(i2)
				if i2.UserInputType == Enum.UserInputType.MouseMovement or i2.UserInputType == Enum.UserInputType.Touch then
					fromX(i2.Position.X)
				end
			end)
			local ended
			ended = UserInputService.InputEnded:Connect(function(i3)
				if i3.UserInputType == input.UserInputType then
					if dragging then
						dragging:Disconnect()
						dragging = nil
					end
					ended:Disconnect()
				end
			end)
		end
	end)
	row.Destroying:Connect(function()
		if dragging then
			dragging:Disconnect()
		end
	end)
	local step = opts.step or 1
	local bigStep = opts.bigStep or step
	minus.inst.Activated:Connect(function()
		setValue(value - bigStep, true)
	end)
	plus.inst.Activated:Connect(function()
		setValue(value + bigStep, true)
	end)
	function api.set(v)
		value = snap(v)
		paint()
	end
	paint()
	return api
end

-- Empty / error / blocked state block with an optional action.
function UI.emptyState(opts)
	local m = UI.m
	local frame = UI.box({ Name = opts.name or "EmptyState", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = opts.order or 0 })
	UI.list("v", m.gapSm, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = frame
	UI.pad(m.pad, 0).Parent = frame
	UI.icon(opts.icon or "info", math.floor(m.h1 * 0.9), opts.color or C.steel, { LayoutOrder = 1, Parent = frame })
	UI.label("title", opts.title, { TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = frame })
	if opts.body then
		UI.para(opts.body, { TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Size = UDim2.new(0.9, 0, 0, 0), Parent = frame })
	end
	if opts.action then
		local b = UI.button({ text = opts.action, icon = opts.actionIcon, variant = "secondary", order = 4, onClick = opts.onAction })
		b.inst.Parent = frame
	end
	return frame
end

---------------------------------------------------------------- overlay: modal
-- Only one modal at a time: opening another closes the current one (no stacked dialogs).
-- The card is a SelectionGroup so keyboard navigation stays inside it; Backspace or the X closes it.
local current = nil
local previousSelection = nil

function UI.modalOpen(): boolean
	return current ~= nil
end

--[[ UI.modal({ title, eyebrow, width, dismissable (default true), build = function(body, api) , actions = {buttonOpts...}, onClose, tone })
	api: close(), setActions(list), setTitle(text), body, scope ]]
function UI.modal(opts)
	if current then
		current.close("replaced")
	end
	local m = UI.m
	local root = UI.overlay
	local dismissable = opts.dismissable ~= false
	local layer = new("TextButton", {
		Name = "Modal",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.black,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Selectable = false,
	})
	local holder = UI.box({ Name = "Holder", ZIndex = 51, Parent = layer })
	UI.pad(m.pad).Parent = holder
	local width = math.min(opts.width or 520, (root.AbsoluteSize.X - m.pad * 2))
	local card = UI.surface({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, width, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 52,
		SelectionGroup = true,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
		SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
		SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		Parent = holder,
	}, { edge = C.ink600, pad = m.pad })
	local maxH = root.AbsoluteSize.Y - m.pad * 2
	new("UISizeConstraint", { MaxSize = Vector2.new(width, maxH), Parent = card })
	local scale = new("UIScale", { Scale = Util.reducedMotion and 1 or 0.96, Parent = card })
	UI.list("v", m.gap).Parent = card

	local api = { scope = Util.scope() }

	-- header
	local headRow = UI.box({ Name = "Head", Size = UDim2.new(1, 0, 0, math.ceil(m.h2 * 1.35)), LayoutOrder = 1, Parent = card })
	local titleBox = UI.box({ Size = UDim2.new(1, -(m.btnSm + 8), 1, 0), Parent = headRow })
	UI.list("v", 0, { VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = titleBox
	if opts.eyebrow then
		headRow.Size = UDim2.new(1, 0, 0, math.ceil(m.h2 * 1.35 + m.micro * 1.5))
		UI.label("eyebrow", opts.eyebrow, { LayoutOrder = 1, TextColor3 = opts.tone == "danger" and C.bad or C.signal, Parent = titleBox })
	end
	local title = UI.label("h2", opts.title or "", { LayoutOrder = 2, Parent = titleBox })
	if dismissable then
		local x = UI.iconButton({ icon = "close", label = "Cerrar", name = "Close", sound = "back", onClick = function()
			api.close("x")
		end })
		x.inst.AnchorPoint = Vector2.new(1, 0)
		x.inst.Position = UDim2.fromScale(1, 0)
		x.inst.Parent = headRow
	end

	-- the body scrolls when its content is taller than the screen allows; header and actions stay visible
	local headH = headRow.Size.Y.Offset
	local maxBody = math.max(120, maxH - m.pad * 2 - headH - m.btn - m.gap * 2)
	local body = UI.scroll({ Name = "Body", Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, ScrollBarThickness = 3, Parent = card })
	api.body = body
	-- height follows the content (measured from the body's list layout) up to maxBody, then it scrolls
	local fitConn
	local function contentHeight()
		local layout = body:FindFirstChildOfClass("UIListLayout")
		local h = layout and layout.AbsoluteContentSize.Y or 0
		if not layout then
			for _, c in body:GetChildren() do
				if c:IsA("GuiObject") then
					h = math.max(h, c.AbsoluteSize.Y)
				end
			end
		end
		return h
	end
	-- auto-sized wrapped text never grows past its container: a body that is still short (it starts at 0)
	-- keeps a paragraph at one line and the rest is cut. When that happens the body is measured once more
	-- at full height and then trimmed to the content (truncated single-line labels are left alone).
	local function clipped()
		for _, d in body:GetDescendants() do
			if d:IsA("TextLabel") and d.TextWrapped and d.AutomaticSize ~= Enum.AutomaticSize.None and d.Visible and not d.TextFits then
				return true
			end
		end
		return false
	end
	local remeasuring = false
	local function fit()
		if remeasuring then
			return
		end
		body.Size = UDim2.new(1, 0, 0, math.min(contentHeight() + 2, maxBody))
		if clipped() then
			remeasuring = true
			body.Size = UDim2.new(1, 0, 0, maxBody)
			task.spawn(function()
				task.wait()
				remeasuring = false
				if body.Parent then
					body.Size = UDim2.new(1, 0, 0, math.min(contentHeight() + 2, maxBody))
				end
			end)
		end
	end
	body.ChildAdded:Connect(function(c)
		if c:IsA("UIListLayout") then
			if fitConn then
				fitConn:Disconnect()
			end
			fitConn = c:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
		end
		task.defer(fit)
	end)
	api.fit = fit
	local foot = UI.box({ Name = "Actions", Size = UDim2.new(1, 0, 0, m.btn), LayoutOrder = 3, Parent = card })
	UI.list("h", m.gapSm, { HorizontalAlignment = Enum.HorizontalAlignment.Right, HorizontalFlex = UI.isPhone() and Enum.UIFlexAlignment.Fill or Enum.UIFlexAlignment.None }).Parent = foot

	local closed = false
	function api.close(reason)
		if closed then
			return
		end
		closed = true
		if current == api then
			current = nil
		end
		api.scope:destroy()
		if reason ~= "replaced" then
			local prev = previousSelection
			previousSelection = nil
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(layer) then
				GuiService.SelectedObject = (prev and prev.Parent) and prev or nil
			end
		end
		layer:Destroy()
		if opts.onClose then
			opts.onClose(reason)
		end
	end
	function api.setTitle(text: string)
		title.Text = UI.upper(text)
	end
	local firstAction
	function api.setActions(list)
		for _, c in foot:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		foot.Visible = list ~= nil and #list > 0
		firstAction = nil
		for i, b in list or {} do
			b.order = i
			b.name = b.name or ("Action" .. i)
			if UI.isPhone() then
				b.flex = true
			end
			local btn = UI.button(b)
			btn.inst.Parent = foot
			if b.focus or (not firstAction) then
				firstAction = btn.inst
			end
		end
		-- only once the dialog is mounted: SelectedObject must live under PlayerGui (the first focus is set below)
		if GuiService.SelectedObject and firstAction and layer.Parent then
			GuiService.SelectedObject = firstAction
		end
	end
	function api.clearBody()
		api.scope:clean()
		for _, c in body:GetChildren() do
			c:Destroy()
		end
		body.CanvasPosition = Vector2.zero
	end
	function api.isOpen()
		return not closed
	end

	layer.Activated:Connect(function()
		-- clicking the dimmed backdrop (not the card) closes dismissable dialogs
		if dismissable then
			UI.sfx("back")
			api.close("backdrop")
		end
	end)
	card.Active = true -- the card sinks clicks so they never reach the backdrop or the screen below

	current = api
	api.dismissable = dismissable
	if opts.build then
		opts.build(body, api)
	end
	api.setActions(opts.actions)
	layer.Parent = root
	task.delay(0.05, fit)
	Util.tween(layer, Theme.motion.base, { BackgroundTransparency = 0.42 })
	Util.tween(scale, Theme.motion.base, { Scale = 1 })
	-- text that sized itself while the card was still scaling in was measured short (a wrapped paragraph
	-- could keep one line and clip the rest): once the card is at full size, every auto-sized label is
	-- measured again. Roblox only re-measures if AutomaticSize really changes for a frame, so each label
	-- holds its current size for that frame (no visible jump) and then gets its AutomaticSize back.
	task.delay(Util.reducedMotion and 0 or Theme.motion.base + 0.03, function()
		if not card.Parent then
			return
		end
		local held = {}
		for _, d in card:GetDescendants() do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.AutomaticSize ~= Enum.AutomaticSize.None then
				table.insert(held, { d, d.AutomaticSize, d.Size })
				d.Size = UDim2.fromOffset(d.AbsoluteSize.X, d.AbsoluteSize.Y)
				d.AutomaticSize = Enum.AutomaticSize.None
			end
		end
		task.wait()
		for _, h in held do
			if h[1].Parent then
				h[1].Size = h[3]
				h[1].AutomaticSize = h[2]
			end
		end
		task.defer(fit)
	end)
	if GuiService.SelectedObject then
		previousSelection = GuiService.SelectedObject
		GuiService.SelectedObject = firstAction or card:FindFirstChildWhichIsA("GuiButton", true)
	end
	return api
end

-- Called by the client on Backspace / Gamepad B equivalents.
function UI.closeModal(): boolean
	if current and current.dismissable then
		UI.sfx("back")
		current.close("key")
		return true
	end
	return false
end

function UI.closeModalSilently()
	if current then
		current.close("system")
	end
end

function UI.confirm(opts)
	return UI.modal({
		title = opts.title,
		eyebrow = opts.eyebrow,
		tone = opts.tone,
		width = opts.width or 460,
		build = function(body)
			UI.list("v", 8).Parent = body
			UI.para(opts.body, { Parent = body })
		end,
		onClose = opts.onCancelled,
		actions = {
			{ text = opts.cancelText or "Cancelar", variant = "ghost", focus = true, sound = "back", onClick = function()
				UI.closeModalSilently()
			end },
			{ text = opts.confirmText or "Confirmar", variant = opts.tone == "danger" and "danger" or "primary", icon = opts.confirmIcon, onClick = function()
				UI.closeModalSilently()
				opts.onConfirm()
			end },
		},
	})
end

---------------------------------------------------------------- overlay: toasts
-- Short notices. They stack in a corner reserved for them (top right in menus, top centre-left in
-- the match), never over primary actions, and expire on their own. Max three at once.
local toastHolder = nil
local TONES = { info = C.steel2, ok = C.ok, warn = C.warn, bad = C.bad, signal = C.signal, reward = C.brass }
local TONE_ICON = { info = "info", ok = "check", warn = "warning", bad = "warning", signal = "sparkle", reward = "gift" }

function UI.setToastAnchor(anchor: string)
	if not toastHolder then
		return
	end
	local m = UI.m
	if anchor == "match" then
		toastHolder.AnchorPoint = Vector2.new(0, 0)
		toastHolder.Position = UDim2.new(0, m.pad, 0, m.pad + (UI.isPhone() and 52 or 96))
		toastHolder:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Left
	else
		-- menus: top centre, below the top bar, over the 3D stand area (no primary actions there)
		toastHolder.AnchorPoint = Vector2.new(0.5, 0)
		toastHolder.Position = UDim2.new(0.5, 0, 0, m.topbar + 6)
		toastHolder:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
end

function UI.initOverlay(screenGui: ScreenGui)
	UI.overlay = screenGui
	if toastHolder then
		toastHolder:Destroy()
	end
	toastHolder = UI.box({ Name = "Toasts", Size = UDim2.fromOffset(340, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 80, Parent = screenGui })
	UI.list("v", 8).Parent = toastHolder
	UI.setToastAnchor("menu")
end

local toastSeq = 0
function UI.toast(text: string, tone: string?, seconds: number?)
	if not toastHolder then
		return
	end
	tone = tone or "info"
	local m = UI.m
	local width = UI.isPhone() and 270 or 340
	toastHolder.Size = UDim2.fromOffset(width, 0)
	toastSeq += 1
	local items = {}
	for _, c in toastHolder:GetChildren() do
		if c:IsA("Frame") then
			table.insert(items, c)
		end
	end
	table.sort(items, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #items >= 3 do
		table.remove(items, 1):Destroy()
	end
	local color = TONES[tone] or C.steel2
	local t = UI.surface({ Name = "Toast", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = toastSeq, ZIndex = 81 }, { edge = C.ink600, pad = 12, cut = 0.3 })
	local row = UI.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = t })
	UI.list("h", 10, { VerticalAlignment = Enum.VerticalAlignment.Top }).Parent = row
	UI.icon(TONE_ICON[tone] or "info", 18, color, { LayoutOrder = 1, Parent = row })
	UI.para(text, { TextColor3 = C.paper, FontFace = F.body, TextSize = m.small, Size = UDim2.new(1, -28, 0, 0), LayoutOrder = 2, Parent = row })
	UI.fill(color, { Name = "Accent", Size = UDim2.new(0, 3, 1, 0), Position = UDim2.fromOffset(-8, 0), ZIndex = 82, Parent = t })
	local sc = new("UIScale", { Scale = Util.reducedMotion and 1 or 0.92, Parent = t })
	t.Parent = toastHolder
	Util.tween(sc, Theme.motion.base, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(seconds or 3.4, function()
		if t.Parent then
			t:Destroy()
		end
	end)
	return t
end

return UI
