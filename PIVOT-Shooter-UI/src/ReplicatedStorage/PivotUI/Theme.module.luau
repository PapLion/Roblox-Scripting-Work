--!strict
-- PIVOT visual tokens. Edit colours, fonts and sizes here; every screen reads from this module.
-- Steel-grey base, signal orange for the main action, brass only for currency,
-- light "range card" behind each weapon (the only light surface in the UI).

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local Theme = {}

Theme.color = {
	ink950 = hex("#151A20"),
	ink900 = hex("#191F26"),
	ink850 = hex("#1E252D"),
	ink800 = hex("#252D36"),
	ink700 = hex("#303A45"),
	ink600 = hex("#414D5A"),
	steel = hex("#8E9AA6"),
	steel2 = hex("#B8C1CA"),
	paper = hex("#ECE7DC"),
	paper2 = hex("#DDD6C7"),
	paperLine = hex("#CFC7B6"),
	paperInk = hex("#22262B"),
	signal = hex("#FF7A1A"),
	signal2 = hex("#FF9B52"),
	signalDeep = hex("#C85A0C"),
	signalInk = hex("#1C0F05"),
	brass = hex("#E2B65A"),
	ally = hex("#4EA8FF"),
	enemy = hex("#FF4F64"),
	ok = hex("#59C98A"),
	warn = hex("#F2B84B"),
	bad = hex("#FF5A5F"),
	black = hex("#000000"),
	white = hex("#FFFFFF"),
}

-- Colour-blind friendly team palette (Settings > Accessibility).
Theme.teamPalettes = {
	default = { ally = hex("#4EA8FF"), enemy = hex("#FF4F64") },
	colorblind = { ally = hex("#3D8BFF"), enemy = hex("#FFB000") },
}

Theme.rarity = {
	common = hex("#9AA4AE"),
	rare = hex("#3FC1A5"),
	epic = hex("#A783FF"),
	legendary = hex("#F2C14E"),
}

local function family(name: string): string
	return "rbxasset://fonts/families/" .. name .. ".json"
end

Theme.font = {
	display = Font.new(family("Oswald"), Enum.FontWeight.Bold),
	displayMedium = Font.new(family("Oswald"), Enum.FontWeight.SemiBold),
	displayLight = Font.new(family("Oswald"), Enum.FontWeight.Regular),
	body = Font.new(family("BuilderSans"), Enum.FontWeight.Medium),
	bodyRegular = Font.new(family("BuilderSans"), Enum.FontWeight.Regular),
	bodySemi = Font.new(family("BuilderSans"), Enum.FontWeight.SemiBold),
	bodyBold = Font.new(family("BuilderSans"), Enum.FontWeight.Bold),
	bodyHeavy = Font.new(family("BuilderSans"), Enum.FontWeight.ExtraBold),
	mono = Font.new(family("BuilderMono"), Enum.FontWeight.Regular),
	monoBold = Font.new(family("BuilderMono"), Enum.FontWeight.Bold),
}

-- Motion: short, only where something changes. Reduced motion turns them into instant changes.
Theme.motion = {
	fast = 0.12,
	base = 0.18,
	slow = 0.28,
}

-- Sizes per layout class. "desktop" >= 1100x620, "tablet" >= 820x540, "phone" otherwise (landscape phones).
local metrics = {
	desktop = {
		pad = 24, gap = 16, gapSm = 8, radius = 6,
		h1 = 44, h2 = 26, h3 = 19, body = 17, small = 15, micro = 13,
		btn = 44, btnLg = 58, btnSm = 34, topbar = 64, nav = 46, tile = 168,
	},
	tablet = {
		pad = 18, gap = 12, gapSm = 8, radius = 6,
		h1 = 38, h2 = 23, h3 = 18, body = 16, small = 14, micro = 12,
		btn = 44, btnLg = 54, btnSm = 34, topbar = 58, nav = 44, tile = 150,
	},
	phone = {
		pad = 10, gap = 8, gapSm = 6, radius = 5,
		h1 = 28, h2 = 19, h3 = 16, body = 14, small = 13, micro = 11,
		btn = 40, btnLg = 46, btnSm = 32, topbar = 46, nav = 40, tile = 118,
	},
}

function Theme.metrics(layout: string)
	return metrics[layout] or metrics.desktop
end

return Theme
