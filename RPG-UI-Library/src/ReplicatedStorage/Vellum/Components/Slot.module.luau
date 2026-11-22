--!strict
-- Slot: the square every item lives in (inventory, equipment, vendor, rewards, crafting).
-- Rarity tints the frame and an inner glow; count, lock, equipped mark, drag highlight and dim states.
local Theme = require(script.Parent.Parent.Theme)
local Atlas = require(script.Parent.Parent.Atlas)
local Create = require(script.Parent.Parent.Core.Create)
local Motion = require(script.Parent.Parent.Core.Motion)
local Interact = require(script.Parent.Parent.Core.Interact)
local Surface = require(script.Parent.Surface)

local C = Theme.color
local M = Theme.motion
local Slot = {}

export type Props = {
	size: number?,
	item: any?,
	count: number?,
	locked: boolean?,
	emptyGlyph: string?,
	label: string?, -- caption under an empty slot (equipment)
	equipped: boolean?,
	onClick: (() -> ())?,
	layoutOrder: number?,
	parent: Instance?,
}

function Slot.new(scope: any, props: Props)
	local size = props.size or Theme.size.slot
	local root = scope:add(Create("ImageButton", {
		Name = "Slot",
		BackgroundTransparency = 1,
		Image = "",
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = props.layoutOrder or 0,
	}))
	local face = Create.box({ Name = "Face", Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = root })
	local scale = Create.scale(1)
	scale.Parent = face
	local well = Create("Frame", { Name = "Well", BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), Parent = face }, {
		Create.corner(math.floor(size * 0.1)),
		Create.gradient({ C.leather1, C.void }, 90),
	})
	local glow = Atlas.image("chrome", "glow", { Name = "Glow", Size = UDim2.fromScale(1.05, 1.05), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), ImageTransparency = 0.6, ZIndex = 1, Parent = face })
	local empty = Atlas.image("glyph", props.emptyGlyph or "bag", { Name = "EmptyGlyph", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, if props.label then 0.42 else 0.5), Size = UDim2.fromScale(0.36, 0.36), ImageColor3 = C.textGhost, ImageTransparency = 0.35, ZIndex = 1, Parent = face })
	local caption: TextLabel? = nil
	if props.label then
		caption = Surface.text({ role = "caps", text = props.label, color = C.textGhost, size = 9, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -7), ZIndex = 1, Parent = face })
	end
	local icon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), ZIndex = 2, Parent = face })
	local frame = Atlas.image("chrome", "frame_slot", { Name = "Frame", Size = UDim2.fromScale(1, 1), SliceScale = math.clamp(size / 150, 0.3, 0.6), ZIndex = 3, Parent = face })
	local count = Surface.text({
		role = "number",
		text = "",
		size = math.max(12, math.floor(size * 0.22)),
		color = C.text,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, -3),
		ZIndex = 5,
		Parent = face,
	})
	count.TextStrokeColor3 = C.void
	count.TextStrokeTransparency = 0.1
	local equippedMark = Atlas.image("chrome", "pip", { Name = "Equipped", Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(14, 14), Visible = false, ZIndex = 5, Parent = face })
	local lock = Create("Frame", { Name = "Lock", BackgroundColor3 = C.void, BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 6, Parent = face }, { Create.corner(math.floor(size * 0.1)) })
	Atlas.image("glyph", "lock", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.34, 0.34), ImageColor3 = C.textSoft, ZIndex = 7, Parent = lock })
	local ring = Create("Frame", { Name = "Ring", BackgroundTransparency = 1, Size = UDim2.new(1, -2, 1, -2), Position = UDim2.fromOffset(1, 1), Visible = false, ZIndex = 8, Parent = face }, { Create.corner(math.floor(size * 0.12)), Create.stroke(C.arcane, 2.5, 0) })
	local hint = Create("Frame", { Name = "DropHint", BackgroundColor3 = C.arcane, BackgroundTransparency = 1, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = 4, Parent = face }, { Create.corner(math.floor(size * 0.1)) })

	local item: any = nil
	local n = 0
	local flags = { selected = false, dim = false, drop = nil :: string?, lifted = false, locked = props.locked == true, equipped = props.equipped == true }
	local ctl

	local function paint(s)
		local r = Theme.rarityOf(item and item.rarity)
		local has = item ~= nil
		icon.Visible = has
		empty.Visible = not has
		if caption then
			caption.Visible = not has
		end
		glow.Visible = has
		glow.ImageColor3 = r.color
		glow.ImageTransparency = if s.hover or flags.selected then 0.4 else 0.62
		frame.ImageColor3 = if has then r.color else C.seam
		if has and r.rank == 1 then
			frame.ImageColor3 = Color3.fromHex("9C9385")
		end
		if s.hover and not flags.locked then
			frame.ImageColor3 = frame.ImageColor3:Lerp(Color3.new(1, 1, 1), 0.3)
		end
		count.Visible = has and n > 1
		count.Text = tostring(n)
		equippedMark.Visible = has and flags.equipped
		lock.Visible = flags.locked
		ring.Visible = flags.selected or (s.focused and not flags.locked)
		ring:FindFirstChildOfClass("UIStroke").Color = if flags.selected then C.goldBright else C.arcane
		local fade = if flags.lifted then 0.75 elseif flags.dim then 0.78 else 0
		icon.ImageTransparency = fade
		well.BackgroundTransparency = if flags.dim then 0.5 else 0
		frame.ImageTransparency = if flags.dim then 0.6 else 0
		hint.BackgroundTransparency = if flags.drop == "valid" then 0.72 elseif flags.drop == "invalid" then 0.75 else 1
		hint.BackgroundColor3 = if flags.drop == "invalid" then C.bad else C.arcane
		Motion.tween(scale, { Scale = if s.pressed then 0.94 elseif s.hover and has and not flags.locked then 1.04 else 1 }, M.fast, nil, nil, "press")
	end

	ctl = Interact.attach(root, scope, paint, props.onClick)
	local handle = {} :: any
	function handle.setItem(_, it: any?, c: number?)
		item = it
		n = if it then (c or 1) else 0
		if it then
			for k, v in Atlas.icon(it.icon) do
				(icon :: any)[k] = v
			end
		end
		paint(ctl.state)
	end
	function handle.set(_, patch: { [string]: any })
		for k, v in patch do
			(flags :: any)[k] = v
		end
		paint(ctl.state)
	end
	function handle.getItem()
		return item, n
	end
	function handle.pop()
		Motion.pop(scale, 0.12)
	end
	function handle.force(_, p)
		ctl:force(p)
	end
	handle.Instance = root
	handle.icon = icon
	handle.controller = ctl
	handle:setItem(props.item, props.count)
	if props.parent then
		root.Parent = props.parent
	end
	return handle
end

return Slot
