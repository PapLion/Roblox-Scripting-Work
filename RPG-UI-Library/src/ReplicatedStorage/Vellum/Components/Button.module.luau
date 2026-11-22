--!strict
-- Button: gilded primary, leather secondary, ghost, danger and arcane variants in three sizes.
-- States (via Interact): hover lifts and brightens, pressed sinks, focus draws an arcane ring,
-- selected shows a gem, disabled desaturates, loading swaps the icon for a turning rune and blocks input.
local Theme = require(script.Parent.Parent.Theme)
local Atlas = require(script.Parent.Parent.Atlas)
local Create = require(script.Parent.Parent.Core.Create)
local Motion = require(script.Parent.Parent.Core.Motion)
local Interact = require(script.Parent.Parent.Core.Interact)
local Surface = require(script.Parent.Surface)

local C = Theme.color
local Button = {}

export type Variant = "primary" | "secondary" | "ghost" | "danger" | "arcane"
export type Size = "small" | "medium" | "large"

type Look = { fill: { Color3 }, text: Color3, stroke: Color3, strokeT: number, inset: Color3, insetT: number }

local LOOK: { [string]: Look } = {
	primary = { fill = { C.goldPale, C.goldBright, C.gold, C.goldDeep }, text = C.ink, stroke = C.void, strokeT = 0.1, inset = C.goldPale, insetT = 0.25 },
	secondary = { fill = { C.leather3, C.leather2, C.leather1 }, text = C.goldBright, stroke = C.gold, strokeT = 0.15, inset = C.gold, insetT = 0.75 },
	ghost = { fill = { C.leather2, C.leather2 }, text = C.goldBright, stroke = C.gold, strokeT = 1, inset = C.gold, insetT = 1 },
	danger = { fill = { Color3.fromHex("D0574F"), Color3.fromHex("A8332D"), Color3.fromHex("6E1A18") }, text = C.goldPale, stroke = C.void, strokeT = 0.1, inset = Color3.fromHex("F2A097"), insetT = 0.55 },
	arcane = { fill = { Color3.fromHex("7FE3D7"), Color3.fromHex("3FAEA2"), Color3.fromHex("1E5D58") }, text = C.void, stroke = C.void, strokeT = 0.1, inset = Color3.fromHex("CFF7F2"), insetT = 0.4 },
}

local SIZE = {
	small = { h = Theme.size.controlSmall, text = 14, pad = 14, icon = 16 },
	medium = { h = Theme.size.control, text = 16, pad = 20, icon = 18 },
	large = { h = Theme.size.controlLarge, text = 19, pad = 28, icon = 22 },
}

local function lerp(a: Color3, b: Color3, t: number)
	return a:Lerp(b, t)
end

local function seq(colors: { Color3 }, f: (Color3) -> Color3): ColorSequence
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), f(c)))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, f(colors[1])))
	end
	return ColorSequence.new(keys)
end

export type Props = {
	text: string?,
	variant: Variant?,
	size: Size?,
	icon: string?, -- glyph name
	width: number?, -- fixed width; otherwise fits the label
	fill: boolean?, -- stretch to parent width
	keyHint: string?,
	disabled: boolean?,
	selected: boolean?,
	onClick: (() -> ())?,
	layoutOrder: number?,
	parent: Instance?,
}

function Button.new(scope: any, props: Props)
	local variant = props.variant or "primary"
	local look = LOOK[variant]
	local sz = SIZE[props.size or "medium"]

	local root = Create("TextButton", {
		Name = "Button_" .. variant,
		Text = "",
		BackgroundTransparency = 1,
		Size = if props.fill then UDim2.new(1, 0, 0, sz.h) elseif props.width then UDim2.fromOffset(props.width, sz.h) else UDim2.fromOffset(120, sz.h),
		LayoutOrder = props.layoutOrder or 0,
	})
	scope:add(root)

	-- Decorations live in a scale-1 container: an auto-sized root only measures its direct children,
	-- so rings that overhang the button (scale 1 + offset) cannot feed back into its width.
	local deco = Create.box({ Name = "Deco", Size = UDim2.fromScale(1, 1), Parent = root })
	-- body moves for press / hover; root keeps the hitbox steady
	local body = Create("Frame", {
		Name = "Body",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = deco,
	}, { Create.corner(5) })
	local gradient = Create.gradient(look.fill, 90)
	gradient.Parent = body
	local stroke = Create.stroke(look.stroke, 2, look.strokeT)
	stroke.Parent = body
	local inset = Atlas.image("chrome", "frame_inset", {
		Name = "Inset",
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = look.inset,
		ImageTransparency = look.insetT,
		SliceScale = 1,
		ZIndex = 2,
		Parent = body,
	})
	-- top sheen
	local sheen = Create("Frame", {
		Name = "Sheen",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = if variant == "ghost" then 1 else 0.82,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 0.42, -3),
		ZIndex = 2,
		Parent = body,
	}, { Create.corner(3), Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }) })
	local press = Create.scale(1)
	press.Parent = root

	local row = Create.box({
		Name = "Row",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = if not (props.fill or props.width) then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 1),
		AutomaticSize = if not (props.fill or props.width) then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		ZIndex = 3,
		Parent = root,
	}, {
		Create.list("x", 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
		Create.padding(0, sz.pad, 0, sz.pad),
	})

	if not (props.fill or props.width) then
		scope:add(Create.fitWidth(root, row, sz.h))
	end

	local icon: ImageLabel? = nil
	if props.icon then
		icon = Atlas.image("glyph", props.icon, {
			Name = "Icon",
			Size = UDim2.fromOffset(sz.icon, sz.icon),
			ImageColor3 = look.text,
			LayoutOrder = 1,
			ZIndex = 3,
			Parent = row,
		})
	end
	local spinner = Atlas.image("chrome", "spinner", {
		Name = "Spinner",
		Size = UDim2.fromOffset(sz.icon, sz.icon),
		ImageColor3 = look.text,
		Visible = false,
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = row,
	})
	local label = Surface.text({
		role = "heading",
		text = props.text or "",
		size = sz.text,
		color = look.text,
		LayoutOrder = 2,
		ZIndex = 3,
		Parent = row,
	})
	label.Name = "Label"
	label.Visible = (props.text or "") ~= ""
	if variant == "primary" or variant == "arcane" or variant == "danger" then
		-- engraved text: a 1px highlight under the ink on light fills, a shadow on dark ones
		label.TextStrokeTransparency = 1
	end

	local keycap: Frame? = nil
	if props.keyHint then
		keycap = Create("Frame", {
			Name = "KeyHint",
			BackgroundColor3 = C.void,
			BackgroundTransparency = 0.55,
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 3,
			ZIndex = 3,
			Parent = row,
		}, { Create.corner(4), Create.padding(0, 6, 0, 6), Create.stroke(look.text, 1, 0.5) })
		Surface.text({ role = "tiny", text = props.keyHint, color = if variant == "secondary" or variant == "ghost" then C.textSoft else C.goldPale, size = 11, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 4, Parent = keycap })
	end

	-- selected gem and focus ring sit outside the body
	local gem = Atlas.image("chrome", "gem", {
		Name = "SelectedGem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, -1),
		Size = UDim2.fromOffset(16, 16),
		ImageColor3 = C.arcane,
		Visible = false,
		ZIndex = 6,
		Parent = deco,
	})
	local ring = Create("Frame", {
		Name = "FocusRing",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-5, -5),
		Size = UDim2.new(1, 10, 1, 10),
		Visible = false,
		ZIndex = 5,
		Parent = deco,
	}, { Create.corner(8), Create.stroke(C.arcane, 2, 0) })
	local ringGlow = Create.stroke(C.arcane, 6, 0.8)
	ringGlow.Parent = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = ring }, { Create.corner(8) })

	local spinConn: RBXScriptConnection? = nil
	local handle = {} :: any

	local function render(s)
		local bright = if s.pressed then -0.12 elseif s.hover or s.focused then 0.12 else 0
		local disabled = s.disabled
		local f = function(c: Color3)
			if disabled then
				local g = c.R * 0.3 + c.G * 0.55 + c.B * 0.15
				return Color3.new(g, g, g):Lerp(C.leather2, 0.55)
			end
			if bright > 0 then
				return lerp(c, Color3.new(1, 1, 1), bright)
			elseif bright < 0 then
				return lerp(c, Color3.new(0, 0, 0), -bright)
			end
			return c
		end
		gradient.Color = seq(look.fill, f)
		if variant == "ghost" then
			body.BackgroundTransparency = if disabled then 1 elseif s.pressed then 0.55 elseif s.hover or s.focused or s.selected then 0.75 else 1
			stroke.Transparency = if s.hover or s.focused or s.selected then 0.45 else 1
		else
			body.BackgroundTransparency = 0
			stroke.Transparency = if disabled then 0.6 else look.strokeT
		end
		local textColor = if disabled then C.textFaint else look.text
		label.TextColor3 = textColor
		if icon then
			icon.ImageColor3 = textColor
		end
		spinner.ImageColor3 = textColor
		inset.ImageTransparency = if disabled then 0.9 else look.insetT
		sheen.Visible = not disabled and not s.pressed and variant ~= "ghost"
		Motion.tween(press, { Scale = if s.pressed then 0.96 else 1 }, Theme.motion.fast, nil, nil, "press")
		local dy = if s.pressed then 1 elseif (s.hover and not disabled) then -1 else 0
		Motion.tween(body, { Position = UDim2.fromOffset(0, dy) }, Theme.motion.fast, nil, nil, "lift")
		Motion.tween(row, { Position = UDim2.new(0.5, 0, 0, dy) }, Theme.motion.fast, nil, nil, "lift")
		ring.Visible = s.focused and not disabled
		gem.Visible = s.selected
		if s.selected and variant == "secondary" then
			stroke.Color = C.goldBright
			stroke.Thickness = 2.5
		else
			stroke.Color = look.stroke
			stroke.Thickness = 2
		end

		local loading = s.loading
		spinner.Visible = loading
		if icon then
			icon.Visible = not loading
		end
		if loading and not spinConn then
			spinConn = scope:connect(game:GetService("RunService").RenderStepped, function(dt)
				spinner.Rotation = (spinner.Rotation + dt * 300) % 360
			end)
		elseif not loading and spinConn then
			spinConn:Disconnect()
			spinConn = nil
		end
		label.TextTransparency = if loading then 0.35 else 0
	end

	local ctl = Interact.attach(root, scope, render, function()
		if props.onClick then
			props.onClick()
		end
	end)
	ctl:set({ disabled = props.disabled == true, selected = props.selected == true })

	handle.Instance = root
	handle.controller = ctl
	function handle.setText(_, t: string)
		label.Text = t
		label.Visible = t ~= ""
	end
	function handle.setDisabled(_, v: boolean)
		ctl:set({ disabled = v })
	end
	function handle.setLoading(_, v: boolean)
		ctl:set({ loading = v })
	end
	function handle.setSelected(_, v: boolean)
		ctl:set({ selected = v })
	end
	function handle.force(_, patch)
		ctl:force(patch)
	end
	if props.parent then
		root.Parent = props.parent
	end
	return handle
end

return Button
