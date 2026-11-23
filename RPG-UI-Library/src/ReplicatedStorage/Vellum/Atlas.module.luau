--!strict
-- Atlas: turns sprite names into ImageLabel properties (image, rect, slice), with mirroring for the
-- corner ornaments. Sprite data comes from the generated AtlasMap.
local Map = require(script.Parent.AtlasMap)
local Create = require(script.Parent.Core.Create)

local Atlas = {}
Atlas.images = Map.images

type Props = { [string]: any }

local function rectProps(image: string, r: any, flipX: boolean?, flipY: boolean?): Props
	local ox, oy, w, h = r.x, r.y, r.w, r.h
	if flipX then
		ox += w
		w = -w
	end
	if flipY then
		oy += h
		h = -h
	end
	return { Image = image, ImageRectOffset = Vector2.new(ox, oy), ImageRectSize = Vector2.new(w, h) }
end

function Atlas.has(kind: "icon" | "chrome" | "glyph", name: string): boolean
	if kind == "icon" then
		return Map.icons[name] ~= nil
	elseif kind == "glyph" then
		return Map.chrome["g_" .. name] ~= nil
	end
	return Map.chrome[name] ~= nil
end

function Atlas.icon(name: string): Props
	local r = Map.icons[name]
	if not r then
		warn(`Vellum.Atlas: unknown icon '{name}'`)
		return { Image = "" }
	end
	return rectProps(Map.images.icons, r)
end

function Atlas.glyph(name: string): Props
	local r = Map.chrome["g_" .. name]
	if not r then
		warn(`Vellum.Atlas: unknown glyph '{name}'`)
		return { Image = "" }
	end
	return rectProps(Map.images.chrome, r)
end

-- Chrome sprite; sliced sprites get ScaleType.Slice with their slice centre.
function Atlas.chrome(name: string, flipX: boolean?, flipY: boolean?): Props
	local r = Map.chrome[name]
	if not r then
		warn(`Vellum.Atlas: unknown sprite '{name}'`)
		return { Image = "" }
	end
	local p = rectProps(Map.images.chrome, r, flipX, flipY)
	if r.slice then
		p.ScaleType = Enum.ScaleType.Slice
		p.SliceCenter = r.slice
	end
	return p
end

-- Build an ImageLabel from a sprite plus extra props.
function Atlas.image(kind: "icon" | "chrome" | "glyph", name: string, props: Props?, flipX: boolean?, flipY: boolean?): ImageLabel
	local p: Props = if kind == "icon" then Atlas.icon(name) elseif kind == "glyph" then Atlas.glyph(name) else Atlas.chrome(name, flipX, flipY)
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Create("ImageLabel", p)
end

-- Swap the sprite on an existing image (keeps colour, size, etc.).
function Atlas.set(img: ImageLabel | ImageButton, kind: "icon" | "chrome" | "glyph", name: string)
	local p: Props = if kind == "icon" then Atlas.icon(name) elseif kind == "glyph" then Atlas.glyph(name) else Atlas.chrome(name)
	for k, v in p do
		(img :: any)[k] = v
	end
end

-- Tiled surface texture (leather grain / parchment fibres) laid over a fill.
function Atlas.texture(kind: "leather" | "parchment", props: Props?): ImageLabel
	local p: Props = {
		Image = Map.images[kind],
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(256, 256),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ImageTransparency = if kind == "leather" then 0.82 else 0.35,
		ImageColor3 = Color3.new(1, 1, 1),
		ZIndex = 0,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Create("ImageLabel", p)
end

-- Four mirrored corner flourishes inside a frame.
function Atlas.corners(parent: GuiObject, size: number?, inset: number?, color: Color3?, z: number?)
	local s = size or 30
	local i = inset or -4
	for _, c in { { 0, 0, false, false }, { 1, 0, true, false }, { 0, 1, false, true }, { 1, 1, true, true } } do
		Atlas.image("chrome", "corner", {
			Name = "Corner",
			AnchorPoint = Vector2.new(c[1], c[2]),
			Position = UDim2.new(c[1], if c[1] == 0 then i else -i, c[2], if c[2] == 0 then i else -i),
			Size = UDim2.fromOffset(s, s),
			ImageColor3 = color or Color3.new(1, 1, 1),
			ZIndex = z or 3,
			Parent = parent,
		}, c[3], c[4])
	end
end

return Atlas
