--!strict
-- Instance builder: Create("Frame", { Size = ..., Parent = ... }, { children })
-- Parent is assigned last so the subtree is complete before it enters the DataModel.
-- Shorthands for the modifiers used everywhere (corner, stroke, padding, list, gradient, scale).
local Create = {}

local function new(class: string, props: { [string]: any }?, children: { Instance? }?): any
	local inst = Instance.new(class)
	local parent
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			if c then
				c.Parent = inst
			end
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

setmetatable(Create, {
	__call = function(_, class, props, children)
		return new(class, props, children)
	end,
})
Create.new = new

function Create.corner(r: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

function Create.stroke(color: Color3, thickness: number?, transparency: number?, mode: Enum.ApplyStrokeMode?): UIStroke
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
	})
end

function Create.padding(t: number, r: number?, b: number?, l: number?): UIPadding
	return new("UIPadding", {
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r or t),
		PaddingBottom = UDim.new(0, b or t),
		PaddingLeft = UDim.new(0, l or r or t),
	})
end

function Create.list(dir: "x" | "y", gap: number?, halign: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?): UIListLayout
	return new("UIListLayout", {
		FillDirection = if dir == "x" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
	})
end

function Create.gradient(colors: { Color3 } | ColorSequence, rotation: number?, transparency: NumberSequence?): UIGradient
	local seq: ColorSequence
	if typeof(colors) == "ColorSequence" then
		seq = colors
	else
		local list = colors :: { Color3 }
		local keys = {}
		for i, c in list do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #list - 1), c))
		end
		if #keys == 1 then
			table.insert(keys, ColorSequenceKeypoint.new(1, list[1]))
		end
		seq = ColorSequence.new(keys)
	end
	return new("UIGradient", { Color = seq, Rotation = rotation or 90, Transparency = transparency })
end

function Create.scale(s: number?): UIScale
	return new("UIScale", { Scale = s or 1 })
end

function Create.flex(mode: Enum.UIFlexMode?, grow: number?): UIFlexItem
	return new("UIFlexItem", { FlexMode = mode or Enum.UIFlexMode.Fill, GrowRatio = grow or 1 })
end

-- Size `root` to the width of an auto-sized `row` inside it, in root's own units. AutomaticSize on
-- root would also measure decorations that overhang (focus rings), so width is set explicitly; the
-- scale factor of any ancestor UIScale is recovered from the known height.
function Create.fitWidth(root: GuiObject, row: GuiObject, height: number, extra: number?): RBXScriptConnection
	local function fit()
		local a = row.AbsoluteSize
		if a.Y > 0 then
			root.Size = UDim2.fromOffset(math.ceil(a.X * height / a.Y) + (extra or 0), height)
		end
	end
	local c = row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
	return c
end

-- Transparent container frame.
function Create.box(props: { [string]: any }?, children: { Instance? }?): Frame
	local p = { BackgroundTransparency = 1, BorderSizePixel = 0 }
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return new("Frame", p, children)
end

return Create
