-- PIVOT UI atlas (1024x1024, white on transparent, tinted with ImageColor3).
-- Source: pivot-roblox/art/build_atlas.py (original icons, emblems, 9-slice shapes and HUD effects).
-- Set the uploaded image here; everything that draws an icon or a cut panel reads this module.

local Icons = {}

-- Uploaded atlas id. While it is empty the local development copy in Studio's content folder is used
-- (content/textures/pivot/pivot_atlas.png), which only exists on the machine that built the project.
Icons.uploaded = ""
Icons.image = Icons.uploaded ~= "" and Icons.uploaded or "rbxasset://textures/pivot/pivot_atlas.png"

-- 64 px icon cells, 16 per row, in this exact order (keep in sync with ICONS in build_atlas.py).
local ORDER = string.split(
	"home play armory shop missions profile settings credits xp lock check close plus minus chevronLeft chevronRight "
		.. "chevronDown chevronUp arrowLeft arrowRight search filter star info warning wifi wifiOff refresh clock users userPlus logout "
		.. "crown skull eye pause trophy shield health bullet reload swap crate medkit aim fire scoreboard map "
		.. "compare receipt gift sound monitor mouse layout accessibility keyboard touch flag bolt duel target dot menu "
		.. "history external palette tag sparkle ready notReady hourglass gamepadOff kick scope rotate",
	" "
)

local rects = {}
for i, name in ORDER do
	local k = i - 1
	rects[name] = { (k % 16) * 64, (k // 16) * 64, 64, 64 }
end

local big = {
	emblem_pivot = { 0, 384, 128, 128 }, emblem_hawk = { 128, 384, 128, 128 }, emblem_bolt = { 256, 384, 128, 128 },
	emblem_crown = { 384, 384, 128, 128 }, logo = { 512, 384, 128, 128 }, hitmarker = { 640, 384, 128, 128 },
	damageArc = { 768, 384, 128, 128 }, ring = { 896, 384, 128, 128 }, spinner = { 0, 512, 128, 128 },
	panelCut = { 128, 512, 128, 128 }, panelCutStroke = { 256, 512, 128, 128 }, btnCut = { 384, 512, 128, 128 },
	btnCutStroke = { 512, 512, 128, 128 }, pill = { 640, 512, 128, 128 }, rounded = { 768, 512, 128, 128 },
	roundedStroke = { 896, 512, 128, 128 }, glow = { 0, 640, 128, 128 }, hatch = { 128, 640, 128, 128 },
	vignette = { 0, 768, 256, 256 }, pattern_grid = { 256, 640, 256, 128 }, pattern_tape = { 512, 640, 256, 128 },
	pattern_contour = { 256, 768, 256, 128 }, pattern_ember = { 512, 768, 256, 128 }, fadeRight = { 256, 896, 512, 32 },
	-- two-tone: tint = border colour, fill comes out at 62 % of it
	panelTone = { 768, 640, 128, 128 }, btnTone = { 896, 640, 128, 128 },
}
for k, v in big do
	rects[k] = v
end

-- 9-slice centres (in atlas pixels relative to the cell) for the shapes.
Icons.slice = {
	panelCut = Rect.new(32, 32, 96, 96),
	panelCutStroke = Rect.new(32, 32, 96, 96),
	btnCut = Rect.new(32, 32, 96, 96),
	btnCutStroke = Rect.new(32, 32, 96, 96),
	panelTone = Rect.new(32, 32, 96, 96),
	btnTone = Rect.new(32, 32, 96, 96),
	pill = Rect.new(63, 63, 65, 65),
	rounded = Rect.new(24, 24, 104, 104),
	roundedStroke = Rect.new(24, 24, 104, 104),
}

function Icons.has(name: string): boolean
	return rects[name] ~= nil
end

-- Applies an atlas entry to an ImageLabel/ImageButton.
function Icons.apply(image: ImageLabel | ImageButton, name: string)
	local r = rects[name]
	if not r then
		warn("[PIVOT] unknown icon", name)
		return
	end
	image.Image = Icons.image
	image.ImageRectOffset = Vector2.new(r[1], r[2])
	image.ImageRectSize = Vector2.new(r[3], r[4])
	local slice = Icons.slice[name]
	if slice then
		image.ScaleType = Enum.ScaleType.Slice
		image.SliceCenter = slice
	end
end

return Icons
