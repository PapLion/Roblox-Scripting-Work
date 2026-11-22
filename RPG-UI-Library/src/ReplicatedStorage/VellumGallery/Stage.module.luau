--!strict
-- Stage: renders one specimen in isolation. The specimen sits on a neutral canvas (its natural size plus
-- a margin) centred in the viewport and scaled to fit with a UIScale, so it is rendered sharply at the
-- largest size the window allows. The overlay layer (tooltips, menus, modals, toasts) lives inside the
-- canvas, so popovers belong to the capture too.
--
-- Capture mode paints the surroundings with a magenta matte; tools/boardcap.py finds the canvas edge on
-- that matte and crops the PrintWindow capture to exactly the canvas.
local Lib = require(script.Parent.Lib)
local Theme = require(Lib.Theme)
local Create = require(Lib.Core.Create)
local Scope = require(Lib.Core.Scope)
local Layers = require(Lib.Core.Layers)
local Registry = require(script.Parent.Registry)

local Stage = {}

Stage.MATTE = Color3.fromRGB(255, 0, 255)
Stage.CANVAS = Color3.fromHex("16130F") -- warm neutral charcoal
Stage.MARGIN = 36

export type Mounted = {
	scope: any,
	canvas: Frame,
	content: Frame,
	scale: UIScale,
	specimen: any,
	built: any,
	fit: () -> (),
}

-- Mount a specimen into `host` (a full-size frame). opts: capture (matte), maxScale, insets {l,t,r,b}
function Stage.mount(host: GuiObject | LayerCollector, specimen: any, opts: { [string]: any }?): Mounted
	local o = opts or {}
	local scope = Scope.new()
	local margin = o.margin or Stage.MARGIN
	local natural = specimen.size + Vector2.new(margin * 2, margin * 2)

	local area = Create.box({ Name = "StageArea", Size = UDim2.fromScale(1, 1), Parent = host })
	scope:add(area)
	if o.capture then
		area.BackgroundTransparency = 0
		area.BackgroundColor3 = Stage.MATTE
	end
	local ins = o.insets or { 0, 0, 0, 0 }
	local slot = Create.box({
		Name = "Slot",
		Position = UDim2.fromOffset(ins[1], ins[2]),
		Size = UDim2.new(1, -(ins[1] + ins[3]), 1, -(ins[2] + ins[4])),
		Parent = area,
	})

	local canvas = Create("Frame", {
		Name = "Canvas",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(natural.X, natural.Y),
		BackgroundColor3 = Stage.CANVAS,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = slot,
	})
	if not o.capture then
		Create.corner(10).Parent = canvas
		Create.stroke(Color3.fromHex("2A231C"), 1, 0).Parent = canvas
	end
	-- soft vignette keeps the neutral ground from looking flat
	Create("Frame", {
		Name = "Vignette",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = canvas,
	}, {
		Create("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0.55) }),
			Rotation = 90,
		}),
	})
	local scale = Create.scale(1)
	scale.Parent = canvas

	local content = Create.box({
		Name = "Specimen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(specimen.size.X, specimen.size.Y),
		Parent = canvas,
	})
	Layers.mount(canvas, 1000)

	local function fit()
		local avail = slot.AbsoluteSize
		if avail.X <= 0 then
			return
		end
		local s = math.min(avail.X / natural.X, avail.Y / natural.Y, o.maxScale or 2)
		scale.Scale = s
	end
	scope:connect(slot:GetPropertyChangedSignal("AbsoluteSize"), fit)
	fit()

	local ctx = { capture = o.capture == true, stageScope = scope }
	local built = specimen.build(scope, content, ctx) or {}

	return {
		scope = scope,
		canvas = canvas,
		content = content,
		scale = scale,
		specimen = specimen,
		built = built,
		fit = fit,
	} :: any
end

-- Edit-mode preview used by tools/preview.luau
function Stage.preview(gui: ScreenGui, opts: { [string]: any }): (any, string)
	local id = opts.id or Registry.list[1].id
	local specimen = Registry.get(id)
	assert(specimen, "unknown specimen " .. tostring(id))
	local host = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("0C0A08"), BorderSizePixel = 0, Parent = gui })
	local m = Stage.mount(host, specimen, { capture = opts.capture, maxScale = opts.maxScale or 1.6 })
	if opts.action and m.built.actions then
		for _, a in m.built.actions do
			if a.label == opts.action then
				a.run()
			end
		end
	end
	return m.scope, `{id} {specimen.size.X}x{specimen.size.Y} scale {string.format("%.2f", m.scale.Scale)}`
end

return Stage
