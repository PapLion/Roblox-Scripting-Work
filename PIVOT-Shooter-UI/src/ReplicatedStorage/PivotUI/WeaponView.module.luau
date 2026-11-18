-- Weapon presentation: the "range card" (light paper card with grid and ruler) holding a ViewportFrame
-- with the real 3D model from ReplicatedStorage.PivotUI.Assets.Weapons.
-- Models are normalised in Studio: length along X (muzzle towards +X), height along Y, pivot at the centre.
-- Parts with the attribute Paint = true take the colour of the equipped finish.

local UserInputService = game:GetService("UserInputService")

local PivotUI = script.Parent
local UI = require(PivotUI.UI)
local Catalog = require(PivotUI.Data.Catalog)
local Icons = require(PivotUI.Icons)

local C = UI.C
local F = UI.F
local ASSETS = PivotUI.Assets.Weapons

local WeaponView = {}

-- Clone of the model for an item (nil if the asset is missing).
function WeaponView.model(item)
	local src = item and item.model and ASSETS:FindFirstChild(item.model)
	if not src then
		return nil
	end
	local m = src:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	return m
end

-- Recolours the painted parts. "factory" restores the colour stored on each part.
function WeaponView.applyFinish(model: Model, finishId: string?)
	local finish = finishId and Catalog.get(finishId)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Paint") then
			if d:GetAttribute("FactoryColor") == nil then
				d:SetAttribute("FactoryColor", d.Color)
			end
			d.Color = (finish and finish.tint) or d:GetAttribute("FactoryColor")
		end
	end
end

-- Frames the camera on the model's bounding box for the given viewport size.
local function frameCamera(cam: Camera, model: Model, vpSize: Vector2, yaw: number, pitch: number, margin: number)
	local cf, size = model:GetBoundingBox()
	local center = cf.Position
	local aspect = math.max(0.2, vpSize.X / math.max(1, vpSize.Y))
	local vfov = math.rad(cam.FieldOfView)
	local hfov = 2 * math.atan(math.tan(vfov / 2) * aspect)
	-- rotated footprint: length seen at an angle, plus a bit of depth
	local w = math.abs(size.X * math.cos(yaw)) + math.abs(size.Z * math.sin(yaw))
	local hgt = size.Y + math.abs(size.X * math.sin(pitch)) * 0.3
	local dist = math.max((w / 2) / math.tan(hfov / 2), (hgt / 2) / math.tan(vfov / 2)) * margin + size.Z
	local dir = (CFrame.Angles(0, yaw, 0) * CFrame.Angles(-pitch, 0, 0)).LookVector
	cam.CFrame = CFrame.lookAt(center - dir * dist, center)
end

--[[ WeaponView.viewport(item, opts) -> api
	opts: finish, yaw (radians, default 0.32), pitch (0.12), margin (1.12), drag (bool: drag to rotate),
	      ambient (Color3), parent, size, position
	api: inst, setFinish(id), setItem(item, finish), destroy() ]]
function WeaponView.viewport(item, opts)
	opts = opts or {}
	local vp = UI.new("ViewportFrame", {
		Name = "WeaponViewport",
		BackgroundTransparency = 1,
		Size = opts.size or UDim2.fromScale(1, 1),
		Position = opts.position or UDim2.new(),
		AnchorPoint = opts.anchor or Vector2.zero,
		Ambient = opts.ambient or Color3.fromRGB(150, 150, 158),
		LightColor = Color3.fromRGB(255, 248, 236),
		LightDirection = Vector3.new(-0.55, -1, -0.65),
		ZIndex = opts.zIndex or 2,
		LayoutOrder = opts.order or 0,
	})
	local cam = UI.new("Camera", { FieldOfView = opts.fov or 28, Parent = vp })
	vp.CurrentCamera = cam
	local world = UI.new("WorldModel", { Parent = vp })
	local model
	local yaw = opts.yaw or 0.32
	local pitch = opts.pitch or 0.12
	local margin = opts.margin or 1.12
	local api = { inst = vp }
	local function refit()
		if model and vp.AbsoluteSize.X > 0 then
			frameCamera(cam, model, vp.AbsoluteSize, yaw, pitch, margin)
		end
	end
	function api.setItem(newItem, finish)
		if model then
			model:Destroy()
			model = nil
		end
		item = newItem
		model = WeaponView.model(item)
		if model then
			WeaponView.applyFinish(model, finish)
			model.Parent = world
		end
		refit()
	end
	function api.setFinish(finish)
		if model then
			WeaponView.applyFinish(model, finish)
		end
	end
	function api.hasModel()
		return model ~= nil
	end
	vp:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	if opts.drag then
		local dragConn, endConn
		vp.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local last = input.Position
			if dragConn then
				dragConn:Disconnect()
			end
			dragConn = UserInputService.InputChanged:Connect(function(i2)
				if i2.UserInputType == Enum.UserInputType.MouseMovement or i2.UserInputType == Enum.UserInputType.Touch then
					local dx = i2.Position.X - last.X
					last = i2.Position
					yaw = math.clamp(yaw + dx * 0.012, -1.3, 1.3)
					refit()
				end
			end)
			if endConn then
				endConn:Disconnect()
			end
			endConn = UserInputService.InputEnded:Connect(function(i3)
				if i3.UserInputType == input.UserInputType then
					if dragConn then
						dragConn:Disconnect()
						dragConn = nil
					end
					endConn:Disconnect()
					endConn = nil
				end
			end)
		end)
		vp.Destroying:Connect(function()
			if dragConn then
				dragConn:Disconnect()
			end
			if endConn then
				endConn:Disconnect()
			end
		end)
	end
	if opts.parent then
		vp.Parent = opts.parent
	end
	api.setItem(item, opts.finish)
	return api
end

-- Hatched outline shown when an item has no model at all (never expected for catalog items).
local function missingArt(parent, item)
	local box = UI.box({ Name = "MissingArt", Size = UDim2.fromScale(0.7, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = parent })
	local h = UI.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ImageColor3 = C.paperInk, ImageTransparency = 0.85, Parent = box })
	Icons.apply(h, "hatch")
	UI.label("micro", "Modelo pendiente", { TextColor3 = C.paperInk, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, 4), Parent = box })
end

--[[ WeaponView.card(item, opts) -> api
	The signature range card. opts: finish, compact (no ruler/labels), drag, size, order, caption (bool, default true)
	api: inst, viewport api, setItem(item, finish), setFinish(id) ]]
function WeaponView.card(item, opts)
	opts = opts or {}
	local m = UI.m
	local card = UI.new("ImageLabel", {
		Name = "RangeCard",
		BackgroundTransparency = 1,
		ImageColor3 = C.paper,
		Size = opts.size or UDim2.fromScale(1, 1),
		LayoutOrder = opts.order or 0,
		ClipsDescendants = true,
	})
	Icons.apply(card, "panelCut")
	card.SliceScale = opts.compact and 0.32 or 0.5
	-- millimetre grid
	local grid = UI.new("ImageLabel", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		ImageColor3 = C.paperLine,
		ImageTransparency = 0.5,
		Parent = card,
	})
	Icons.apply(grid, "pattern_grid")
	grid.ScaleType = Enum.ScaleType.Tile
	grid.TileSize = UDim2.fromOffset(opts.compact and 64 or 112, opts.compact and 32 or 56)

	local vpHolder = UI.box({ Name = "View", Size = opts.compact and UDim2.new(1, -12, 1, -12) or UDim2.new(1, -2 * m.pad, 1, -(m.pad + 44)), Position = opts.compact and UDim2.fromOffset(6, 6) or UDim2.fromOffset(m.pad, m.pad), ZIndex = 2, Parent = card })
	local api = { inst = card }
	local vp = WeaponView.viewport(item, { finish = opts.finish, drag = opts.drag, parent = vpHolder, margin = opts.margin or (opts.compact and 1.05 or 1.08), yaw = opts.yaw, pitch = opts.pitch })
	api.viewport = vp

	local caption, ruler, length, ticks
	if not opts.compact then
		caption = UI.label("eyebrow", "", { Name = "Caption", TextColor3 = C.paperInk, Size = UDim2.new(1, -2 * m.pad, 0, m.micro + 6), Position = UDim2.fromOffset(m.pad, math.floor(m.pad * 0.6)), ZIndex = 3, Visible = opts.caption ~= false, Parent = card })
		ruler = UI.box({ Name = "Ruler", Size = UDim2.new(1, -2 * m.pad, 0, 22), Position = UDim2.new(0, m.pad, 1, -(22 + math.floor(m.pad * 0.6))), ZIndex = 3, Parent = card })
		UI.fill(C.paperInk, { Name = "Line", Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, 0), BackgroundTransparency = 0.2, Parent = ruler })
		ticks = UI.box({ Name = "Ticks", Size = UDim2.new(1, 0, 0, 8), Parent = ruler })
		for i = 0, 20 do
			UI.fill(C.paperInk, { Size = UDim2.fromOffset(1, i % 5 == 0 and 8 or 4), Position = UDim2.fromScale(i / 20, 0), BackgroundTransparency = 0.25, Parent = ticks })
		end
		length = UI.label("mono", "", { Name = "Length", FontFace = F.paper, TextColor3 = C.paperInk, TextSize = m.micro + 1, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 10), TextXAlignment = Enum.TextXAlignment.Right, Parent = ruler })
	end

	local missing
	local function decorate()
		if missing then
			missing:Destroy()
			missing = nil
		end
		if not vp.hasModel() then
			missingArt(vpHolder, item)
			missing = vpHolder:FindFirstChild("MissingArt")
		end
		if caption then
			local cls = Catalog.className[item.class] or ""
			caption.Text = UI.upper(item.name .. "  ·  " .. cls)
		end
		if length then
			local facts = item.modelFacts
			length.Text = facts and string.format("%d mm", facts.lengthMm) or ""
		end
	end
	function api.setItem(newItem, finish)
		item = newItem
		vp.setItem(newItem, finish)
		decorate()
	end
	function api.setFinish(finish)
		vp.setFinish(finish)
	end
	decorate()
	return api
end

return WeaponView
