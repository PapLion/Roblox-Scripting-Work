--!strict
-- Layers: the overlay surface for tooltips, popovers, context menus, drag ghosts, modals and toasts.
-- A host (the gallery stage, or a game's ScreenGui) mounts one overlay frame; components ask Layers
-- for it. Coordinates are converted from screen pixels to the overlay's local units, so overlays stay
-- correct inside a UIScale (the capture stage renders at 2x).
local Create = require(script.Parent.Create)

local Layers = {}

local overlay: Frame? = nil
local probe: Frame? = nil

function Layers.mount(parent: GuiObject | LayerCollector, zindex: number?): Frame
	if overlay then
		overlay:Destroy()
	end
	local o = Create.box({
		Name = "VellumOverlay",
		Size = UDim2.fromScale(1, 1),
		ZIndex = zindex or 1000,
		Parent = parent,
	})
	probe = Create.box({ Name = "ScaleProbe", Size = UDim2.fromOffset(100, 100), Visible = true, Parent = o })
	overlay = o
	return o
end

function Layers.get(): Frame
	assert(overlay, "Vellum.Layers: no overlay mounted (call Layers.mount)")
	return overlay :: Frame
end

function Layers.scale(): number
	local p = probe
	if not p or p.AbsoluteSize.X == 0 then
		return 1
	end
	return p.AbsoluteSize.X / 100
end

-- screen pixels → overlay offset units
function Layers.toLocal(screen: Vector2): Vector2
	local o = Layers.get()
	return (screen - o.AbsolutePosition) / Layers.scale()
end

function Layers.size(): Vector2
	return Layers.get().AbsoluteSize / Layers.scale()
end

-- local rect of a gui object inside the overlay: position, size
function Layers.rectOf(gui: GuiObject): (Vector2, Vector2)
	return Layers.toLocal(gui.AbsolutePosition), gui.AbsoluteSize / Layers.scale()
end

-- Place a popover of `size` next to an anchor rect, preferring `side`, flipping and clamping so it
-- always stays inside the overlay. Returns the top-left in local units and the side used.
function Layers.place(anchorPos: Vector2, anchorSize: Vector2, size: Vector2, side: ("right" | "left" | "below" | "above")?, gap: number?): (Vector2, string)
	local area = Layers.size()
	local g = gap or 10
	local order = {
		right = { "right", "left", "below", "above" },
		left = { "left", "right", "below", "above" },
		below = { "below", "above", "right", "left" },
		above = { "above", "below", "right", "left" },
	}
	local function at(s: string): Vector2
		if s == "right" then
			return Vector2.new(anchorPos.X + anchorSize.X + g, anchorPos.Y)
		elseif s == "left" then
			return Vector2.new(anchorPos.X - size.X - g, anchorPos.Y)
		elseif s == "below" then
			return Vector2.new(anchorPos.X, anchorPos.Y + anchorSize.Y + g)
		end
		return Vector2.new(anchorPos.X, anchorPos.Y - size.Y - g)
	end
	local function fits(p: Vector2)
		return p.X >= 4 and p.Y >= 4 and p.X + size.X <= area.X - 4 and p.Y + size.Y <= area.Y - 4
	end
	local chosen, pos = side or "right", at(side or "right")
	for _, s in order[side or "right"] do
		local p = at(s)
		if fits(p) then
			chosen, pos = s, p
			break
		end
	end
	pos = Vector2.new(math.clamp(pos.X, 4, math.max(4, area.X - size.X - 4)), math.clamp(pos.Y, 4, math.max(4, area.Y - size.Y - 4)))
	return pos, chosen
end

return Layers
