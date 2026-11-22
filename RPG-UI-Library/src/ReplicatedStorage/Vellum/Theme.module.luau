--!strict
-- Vellum design tokens: colour, type, spacing, motion and rarity. Every component reads from here;
-- nothing hard-codes a colour or a font.
--
-- Identity: an illuminated grimoire. Dark umber leather panels with gilt edges, parchment cards with
-- iron-gall ink, jewel-toned rarity and a single arcane teal for magic and focus.

local Theme = {}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

Theme.color = {
	-- leather surfaces (darkest → raised)
	void = hex("0E0A08"),
	leather0 = hex("17100C"),
	leather1 = hex("221812"),
	leather2 = hex("2E2119"),
	leather3 = hex("3C2C21"),
	seam = hex("4A3628"),

	-- parchment surfaces
	vellum = hex("EADCBF"),
	vellumDeep = hex("D9C59E"),
	vellumEdge = hex("B39568"),
	ink = hex("2B1D12"),
	inkSoft = hex("5E4630"),
	inkFaint = hex("8C735A"),

	-- gilt
	gold = hex("D4A55A"),
	goldBright = hex("F3D08A"),
	goldPale = hex("FBEBC4"),
	goldDeep = hex("8A6630"),
	bronze = hex("6E4E2A"),

	-- text on leather
	text = hex("F1E6D2"),
	textSoft = hex("C2B39C"),
	textFaint = hex("8D7D69"),
	textGhost = hex("5F5246"),

	-- signal
	arcane = hex("57D1C4"), -- focus, magic, selection
	arcaneDeep = hex("1E5D58"),
	good = hex("7BCB5E"),
	bad = hex("E5574F"),
	warn = hex("F0B04A"),
	info = hex("6FB3EE"),

	-- vitals
	health = hex("D8453F"),
	healthDeep = hex("6E1A18"),
	mana = hex("4D8FE6"),
	manaDeep = hex("1B3466"),
	stamina = hex("E0B23C"),
	staminaDeep = hex("6A4F12"),
	xp = hex("B98CF0"),
	xpDeep = hex("3D2466"),
}

export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary" | "mythic"
Theme.rarityOrder = { "common", "uncommon", "rare", "epic", "legendary", "mythic" } :: { Rarity }
Theme.rarity = {
	common = { name = "Common", color = hex("B7AE9F"), deep = hex("3A342D"), rank = 1 },
	uncommon = { name = "Uncommon", color = hex("72C45A"), deep = hex("1D3A17"), rank = 2 },
	rare = { name = "Rare", color = hex("4F9DE8"), deep = hex("132E4F"), rank = 3 },
	epic = { name = "Epic", color = hex("B472EE"), deep = hex("341A4D"), rank = 4 },
	legendary = { name = "Legendary", color = hex("F2A93B"), deep = hex("4D300B"), rank = 5 },
	mythic = { name = "Mythic", color = hex("EE5A5F"), deep = hex("4D1517"), rank = 6 },
}

local FAMILY = "rbxasset://fonts/families/"
Theme.font = {
	display = Font.new(FAMILY .. "AccanthisADFStd.json", Enum.FontWeight.Regular),
	blackletter = Font.new(FAMILY .. "GrenzeGotisch.json", Enum.FontWeight.SemiBold),
	body = Font.new(FAMILY .. "Merriweather.json", Enum.FontWeight.Regular),
	bodyLight = Font.new(FAMILY .. "Merriweather.json", Enum.FontWeight.Light),
	bodyBold = Font.new(FAMILY .. "Merriweather.json", Enum.FontWeight.Bold),
	bodyHeavy = Font.new(FAMILY .. "Merriweather.json", Enum.FontWeight.Heavy),
	italic = Font.new(FAMILY .. "Merriweather.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic),
	numeric = Font.new(FAMILY .. "Merriweather.json", Enum.FontWeight.Bold),
}

-- type scale (px at UIScale 1)
Theme.text = { hero = 44, title = 26, heading = 20, label = 16, body = 15, small = 13, tiny = 11 }

Theme.space = { xxs = 2, xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32 }
Theme.radius = { sm = 3, md = 6, lg = 10, pill = 999 }

-- sizes that keep proportions consistent between components
Theme.size = {
	control = 40, -- buttons, inputs, dropdowns
	controlSmall = 32,
	controlLarge = 52,
	slot = 64, -- inventory / equipment slot
	slotSmall = 48,
	icon = 20,
	node = 58, -- skill tree node
}

Theme.motion = {
	fast = 0.08,
	base = 0.16,
	slow = 0.32,
	reveal = 0.55,
	ease = Enum.EasingStyle.Quint,
	spring = Enum.EasingStyle.Back,
}

Theme.z = { base = 1, raised = 5, popover = 50, tooltip = 80, modal = 100, toast = 120, drag = 200 }

function Theme.rarityOf(r: string?)
	return (Theme.rarity :: any)[r or "common"] or Theme.rarity.common
end

-- Layout classes: components read the class, not raw pixels.
export type LayoutClass = "wide" | "compact" | "narrow"
function Theme.layoutClass(width: number): LayoutClass
	if width >= 1100 then
		return "wide"
	elseif width >= 720 then
		return "compact"
	end
	return "narrow"
end

return Theme
