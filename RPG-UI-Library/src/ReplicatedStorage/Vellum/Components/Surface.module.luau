--!strict
-- Surface: the shared building blocks every component is made of.
--   text      typographic label with the library's type roles
--   panel     leather panel: grained fill, gilt 9-slice frame, flourished corners, optional title plaque
--   parchment vellum card with fibres and an inked edge
--   well      recessed dark area inside a panel (lists, slot grids)
--   divider   gilt rule with a centre ornament
--   header    panel title row: display title, optional subtitle and right-side content
local Theme = require(script.Parent.Parent.Theme)
local Atlas = require(script.Parent.Parent.Atlas)
local Create = require(script.Parent.Parent.Core.Create)

local C = Theme.color
local Surface = {}

export type TextRole = "hero" | "title" | "heading" | "label" | "body" | "small" | "tiny" | "lore" | "number" | "caps"

local ROLE: { [string]: { font: Font, size: number } } = {
	hero = { font = Theme.font.blackletter, size = Theme.text.hero },
	title = { font = Theme.font.display, size = Theme.text.title },
	heading = { font = Theme.font.display, size = Theme.text.heading },
	label = { font = Theme.font.bodyBold, size = Theme.text.label },
	body = { font = Theme.font.body, size = Theme.text.body },
	small = { font = Theme.font.body, size = Theme.text.small },
	tiny = { font = Theme.font.bodyBold, size = Theme.text.tiny },
	lore = { font = Theme.font.italic, size = Theme.text.small },
	number = { font = Theme.font.numeric, size = Theme.text.label },
	caps = { font = Theme.font.bodyBold, size = Theme.text.tiny },
}

-- props: text, role, color, size (font size), plus any TextLabel props.
-- Labels auto-size on X unless a Size is given; `wrap = true` makes width fixed and height automatic.
function Surface.text(props: { [string]: any }): TextLabel
	local role = ROLE[props.role or "body"]
	local p: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = role.font,
		TextSize = props.size or role.size,
		TextColor3 = props.color or C.text,
		Text = props.text or "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = props.rich == true,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
	}
	if props.role == "caps" then
		p.Text = string.upper(p.Text)
	end
	if props.wrap then
		p.TextWrapped = true
		p.AutomaticSize = Enum.AutomaticSize.Y
		p.Size = UDim2.new(1, 0, 0, 0)
		p.TextYAlignment = Enum.TextYAlignment.Top
	end
	if props.Size ~= nil and props.AutomaticSize == nil and not props.wrap then
		-- an explicit Size means a fixed box (truncation, alignment); auto-size only when asked
		p.AutomaticSize = Enum.AutomaticSize.None
	end
	for k, v in props do
		if k ~= "role" and k ~= "color" and k ~= "size" and k ~= "text" and k ~= "wrap" and k ~= "rich" then
			p[k] = v
		end
	end
	if props.size and typeof(props.size) == "UDim2" then
		p.Size = props.size
		p.TextSize = role.size
		p.AutomaticSize = if props.wrap then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	end
	return Create("TextLabel", p)
end

-- Leather panel. Returns (panel, content) where content is the padded inner frame.
-- opts: title, subtitle, size, padding, corners (bool), tone ("leather" | "deep"), parent
function Surface.panel(opts: { [string]: any }): (Frame, Frame)
	local pad = opts.padding or 18
	-- Auto-sized frames also measure scale-sized descendants that carry offsets or UIStrokes, so every
	-- decoration here is exactly scale (1, 1) with no offset and no stroke: the gilt frame covers the
	-- fill's rounded edge.
	local panel = Create.box({
		Name = opts.name or "Panel",
		Size = opts.size or UDim2.fromOffset(360, 240),
		Position = opts.position,
		AnchorPoint = opts.anchor,
		LayoutOrder = opts.layoutOrder or 0,
		Parent = opts.parent,
	})
	local fill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = panel,
	}, {
		Create.corner(10),
		Create.gradient(if opts.tone == "deep" then { C.leather1, C.leather0 } else { C.leather2, C.leather1, C.leather0 }, 90),
	})
	Atlas.texture("leather", { Name = "Grain", ImageColor3 = C.goldPale, ImageTransparency = 0.9, ZIndex = 0, Parent = fill })
	Atlas.image("chrome", "frame_gilt", {
		Name = "Frame",
		Size = UDim2.fromScale(1, 1),
		SliceScale = opts.frameScale or 0.62,
		ZIndex = 4,
		Parent = panel,
	})

	local content = Create.box({
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = panel,
	}, { Create.padding(pad + 4, pad + 2, pad + 2, pad + 2) })
	if opts.autoSize then
		-- Height from the content's UIListLayout (exact extent of the direct children). AutomaticSize would
		-- also count decorative overflow deep in the tree (glows, rays) and leave dead space.
		local function hook(layout: UIListLayout)
			local function fit()
				local unit = panel.Size.X.Offset
				local scale = if unit > 0 and panel.AbsoluteSize.X > 0 then panel.AbsoluteSize.X / unit else 1
				local padding = content:FindFirstChildOfClass("UIPadding") :: UIPadding
				local h = layout.AbsoluteContentSize.Y / scale + padding.PaddingTop.Offset + padding.PaddingBottom.Offset
				panel.Size = UDim2.new(panel.Size.X, UDim.new(0, math.ceil(h)))
			end
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
			panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
			task.defer(fit)
		end
		content.ChildAdded:Connect(function(c)
			if c:IsA("UIListLayout") then
				hook(c)
			end
		end)
	end

	if opts.title then
		local plaque = Atlas.image("chrome", "plaque", {
			Name = "TitlePlaque",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.X,
			SliceScale = 0.8,
			ZIndex = 6,
			Parent = panel,
		})
		Create.padding(0, 34, 0, 34).Parent = plaque
		local t = Surface.text({
			role = "heading",
			text = opts.title,
			color = C.goldBright,
			size = 19,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 7,
			Parent = plaque,
		})
		t.Name = "Title"
		content:FindFirstChildOfClass("UIPadding").PaddingTop = UDim.new(0, pad + 22)
	end
	return panel, content
end

-- Parchment card. Returns (card, content).
function Surface.parchment(opts: { [string]: any }): (Frame, Frame)
	local pad = opts.padding or 14
	local card = Create("Frame", {
		Name = opts.name or "Parchment",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = opts.size or UDim2.fromOffset(300, 180),
		AutomaticSize = opts.autoSize,
		Position = opts.position,
		AnchorPoint = opts.anchor,
		Parent = opts.parent,
	}, {
		Create.corner(5),
		Create.gradient(ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.goldPale),
			ColorSequenceKeypoint.new(0.45, C.vellum),
			ColorSequenceKeypoint.new(1, C.vellumDeep),
		}), 60),
		Create.stroke(C.vellumEdge, 2, 0),
	})
	Atlas.texture("parchment", { Name = "Fibres", Parent = card })
	local content = Create.box({
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = opts.autoSize,
		ZIndex = 2,
		Parent = card,
	}, { Create.padding(pad) })
	return card, content
end

-- Recessed well inside a panel.
function Surface.well(props: { [string]: any }): Frame
	local p: { [string]: any } = {
		Name = "Well",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in props do
		p[k] = v
	end
	return Create("Frame", p, { Create.corner(6), Create.stroke(C.seam, 1, 0.2) })
end

-- Gilt rule with the centre ornament. Fills its parent's width.
function Surface.divider(props: { [string]: any }?): Frame
	local p: { [string]: any } = { Name = "Divider", Size = UDim2.new(1, 0, 0, 16) }
	for k, v in props or {} do
		p[k] = v
	end
	local f = Create.box(p)
	local fade = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0) })
	for _, side in { -1, 1 } do
		Create("Frame", {
			BackgroundColor3 = C.gold,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(if side < 0 then 1 else 0, 0.5),
			Position = UDim2.new(0.5, side * 30, 0.5, 0),
			Size = UDim2.new(0.5, -32, 0, 1),
			Parent = f,
		}, { Create("UIGradient", { Transparency = fade, Rotation = if side < 0 then 0 else 180 }) })
	end
	Atlas.image("chrome", "divider_mark", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(64, 16),
		Parent = f,
	})
	return f
end

-- Small uppercase section caption followed by a fading hairline, used inside panels.
function Surface.caption(text: string, props: { [string]: any }?): Frame
	local p: { [string]: any } = { Name = "Caption", Size = UDim2.new(1, 0, 0, 18) }
	for k, v in props or {} do
		p[k] = v
	end
	local f = Create.box(p, { Create.list("x", 10, nil, Enum.VerticalAlignment.Center) })
	Surface.text({ role = "caps", text = text, color = C.gold, LayoutOrder = 1, Parent = f })
	Create("Frame", {
		BackgroundColor3 = C.goldDeep,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 0, 1),
		LayoutOrder = 2,
		Parent = f,
	}, { Create.flex(), Create("UIGradient", { Transparency = NumberSequence.new(0.1, 1) }) })
	return f
end

return Surface
