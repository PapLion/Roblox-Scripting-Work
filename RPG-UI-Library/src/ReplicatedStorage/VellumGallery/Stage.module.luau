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

	-- Tiled capture: the slot becomes a clipped window filled with the canvas colour; the canvas is
	-- pinned top-left at a fixed scale and moved by setTile(), so a specimen larger than the viewport is
	-- rendered in pieces that tools/capture/tiles.py stitches back together.
	if o.tiled then
		slot.BackgroundTransparency = 0
		slot.BackgroundColor3 = Stage.CANVAS
		-- No ClipsDescendants here: the engine culls large clipped 9-slice / gradient frames that cross the
		-- clip edge. Matte masks around the window hide the overflow instead.
		for _, r in {
			{ UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, ins[2]) },
			{ UDim2.new(0, 0, 1, -ins[4]), UDim2.new(1, 0, 0, ins[4] + 2000) },
			{ UDim2.new(0, 0, 0, 0), UDim2.new(0, ins[1], 1, 2000) },
			{ UDim2.new(1, -ins[3], 0, 0), UDim2.new(0, ins[3] + 2000, 1, 2000) },
		} do
			Create("Frame", { Name = "Mask", BorderSizePixel = 0, BackgroundColor3 = Stage.MATTE, Position = r[1], Size = r[2], ZIndex = 20000, Parent = area })
		end
	end
	local canvas = Create("Frame", {
		Name = "Canvas",
		AnchorPoint = if o.tiled then Vector2.zero else Vector2.new(0.5, 0.5),
		Position = if o.tiled then UDim2.new() else UDim2.fromScale(0.5, 0.5),
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
		if o.tiled then
			scale.Scale = o.fixedScale or 2
			return
		end
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

	-- six marker squares above the window's top-right corner encode the tile index (63 = done)
	-- row 1 (lower) = tile index, row 2 (upper) = batch job index
	local markers, jobMarkers = {}, {}
	if o.tiled then
		for i = 1, 6 do
			for row, list in { markers, jobMarkers } do
				list[i] = Create("Frame", {
					Name = "Marker" .. row .. "_" .. i,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -(16 + (i - 1) * 24) - ins[3], 0, ins[2] - 16 - (row - 1) * 24),
					Size = UDim2.fromOffset(16, 16),
					BackgroundColor3 = Color3.new(0, 0, 0),
					ZIndex = 20001,
					Parent = area,
				})
			end
		end
	end
	if o.capture then
		-- input shield: the real pointer must not hover anything while a capture is being taken
		Create("TextButton", { Name = "CaptureShield", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10000, Parent = area })
	end
	local function setTile(tx: number, ty: number)
		canvas.Position = UDim2.fromOffset(-tx, -ty)
	end
	local function marker(index: number, job: number?)
		for i = 1, 6 do
			markers[i].BackgroundColor3 = if bit32.extract(index, i - 1) == 1 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
			jobMarkers[i].BackgroundColor3 = if bit32.extract(job or 0, i - 1) == 1 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		end
	end

	return {
		setTile = setTile,
		marker = marker,
		slot = slot,
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
