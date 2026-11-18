-- Single source of truth for everything the player can own, equip or buy.
-- Lobby, armory, shop, loadout card and match HUD all read names, stats and models from here.
-- `model` = name of the Model in ReplicatedStorage.PivotUI.Assets.Weapons.
-- `modelFacts` are real figures from Dani's Blender exports; `stats` are fictional game-design values.
-- Wasp, Lance and the medkit use models built in Studio; their `lengthMm` is measured from those models.

local Catalog = {}

Catalog.rarities = { "common", "rare", "epic", "legendary" }
Catalog.rarityName = { common = "Común", rare = "Rara", epic = "Épica", legendary = "Legendaria" }
Catalog.rarityRank = { common = 1, rare = 2, epic = 3, legendary = 4 }
Catalog.slotName = { primary = "Principal", secondary = "Secundaria", support = "Apoyo" }
Catalog.className = { rifle = "Rifle", shotgun = "Escopeta", smg = "Subfusil", dmr = "Tirador", pistol = "Pistola", support = "Apoyo" }

Catalog.weapons = {
	{
		id = "kite", kind = "weapon", slot = "primary", class = "rifle", name = "Kite C7",
		model = "Rifle", rarity = "common", price = 0, unlockLevel = 1, auto = true, accuracy = 0.58,
		modelFacts = { tris = 5186, parts = 12, lengthMm = 749 },
		stats = { damage = 24, pellets = 1, rpm = 650, mag = 30, reserve = 120, reload = 2.2, range = 70, mobility = 70, control = 64 },
		desc = "Rifle compacto de cadencia estable. Funciona a media distancia y perdona los errores de control.",
	},
	{
		id = "anvil", kind = "weapon", slot = "primary", class = "shotgun", name = "Anvil 12",
		model = "Shotgun", rarity = "rare", price = 2400, unlockLevel = 5, auto = false, accuracy = 0.72,
		modelFacts = { tris = 6344, parts = 12, lengthMm = 998 },
		stats = { damage = 12, pellets = 8, rpm = 70, mag = 6, reserve = 24, reload = 2.8, range = 18, mobility = 66, control = 55 },
		desc = "Escopeta de corredera. Decide los duelos en interiores; más allá de diez metros pierde casi todo el daño.",
	},
	{
		id = "wasp", kind = "weapon", slot = "primary", class = "smg", name = "Wasp SMG",
		model = "WaspStandIn", rarity = "rare", price = 1800, unlockLevel = 4, auto = true, accuracy = 0.5,
		modelFacts = { lengthMm = 707 },
		stats = { damage = 18, pellets = 1, rpm = 900, mag = 32, reserve = 128, reload = 1.9, range = 40, mobility = 84, control = 58 },
		desc = "Subfusil ligero para flanquear. Mucha cadencia y poco alcance.",
	},
	{
		id = "lance", kind = "weapon", slot = "primary", class = "dmr", name = "Lance DMR",
		model = "LanceStandIn", rarity = "epic", price = 4500, unlockLevel = 10, auto = false, accuracy = 0.64,
		modelFacts = { lengthMm = 1211 },
		stats = { damage = 52, pellets = 1, rpm = 180, mag = 10, reserve = 40, reload = 2.5, range = 90, mobility = 58, control = 72 },
		desc = "Fusil de tirador. Dos impactos bastan contra un rival sin armadura.",
	},
	{
		id = "tern", kind = "weapon", slot = "secondary", class = "pistol", name = "Tern P9",
		model = "Pistol", rarity = "common", price = 0, unlockLevel = 1, auto = false, accuracy = 0.52,
		modelFacts = { tris = 3654, parts = 7, lengthMm = 220 },
		stats = { damage = 28, pellets = 1, rpm = 400, mag = 12, reserve = 48, reload = 1.5, range = 35, mobility = 92, control = 78 },
		desc = "Pistola semiautomática. Cambiar a ella es más rápido que recargar el arma principal.",
	},
}

Catalog.support = {
	{
		id = "crate", kind = "support", slot = "support", class = "support", name = "Caja de munición",
		model = "AmmoBox", rarity = "common", price = 0, unlockLevel = 1, effect = "ammo",
		modelFacts = { tris = 1768, parts = 8, lengthMm = 307 },
		desc = "Repone la reserva de munición de tus dos armas. Una por vida.",
	},
	{
		id = "medkit", kind = "support", slot = "support", class = "support", name = "Botiquín de campo",
		model = "MedkitStandIn", rarity = "rare", price = 900, unlockLevel = 3, effect = "heal",
		modelFacts = { lengthMm = 305 },
		desc = "Recupera 50 puntos de vida. Uno por vida.",
	},
}

-- Finishes recolour the painted parts of the real model (viewport, lobby stand and viewmodel).
Catalog.finishes = {
	{ id = "factory", kind = "finish", name = "De fábrica", tint = nil, rarity = "common", price = 0 },
	{ id = "sand", kind = "finish", name = "Arena", tint = Color3.fromHex("#C9A36B"), rarity = "common", price = 400 },
	{ id = "glacier", kind = "finish", name = "Glaciar", tint = Color3.fromHex("#9CC7DE"), rarity = "rare", price = 800 },
	{ id = "signal", kind = "finish", name = "Señal", tint = Color3.fromHex("#FF7A1A"), rarity = "epic", price = 1200 },
	{ id = "dusk", kind = "finish", name = "Ocaso", tint = Color3.fromHex("#7B5CE0"), rarity = "legendary", price = 2000 },
}

-- Player card backgrounds (two-stop gradients) and emblems (shape + colour).
Catalog.banners = {
	{ id = "grid", kind = "banner", name = "Retícula", rarity = "common", price = 0, colors = { Color3.fromHex("#2B343E"), Color3.fromHex("#1E252D") } },
	{ id = "tape", kind = "banner", name = "Cinta", rarity = "common", price = 300, colors = { Color3.fromHex("#4A3A22"), Color3.fromHex("#1E252D") } },
	{ id = "contour", kind = "banner", name = "Curvas de nivel", rarity = "rare", price = 600, colors = { Color3.fromHex("#1F4A48"), Color3.fromHex("#18212A") } },
	{ id = "ember", kind = "banner", name = "Brasa", rarity = "epic", price = 900, colors = { Color3.fromHex("#7A2E12"), Color3.fromHex("#231A1A") } },
}

Catalog.emblems = {
	{ id = "pivot", kind = "emblem", name = "Pivote", rarity = "common", price = 0, shape = "diamond", color = Color3.fromHex("#FF7A1A") },
	{ id = "hawk", kind = "emblem", name = "Halcón", rarity = "common", price = 200, shape = "chevron", color = Color3.fromHex("#B8C1CA") },
	{ id = "bolt", kind = "emblem", name = "Descarga", rarity = "rare", price = 450, shape = "bars", color = Color3.fromHex("#3FC1A5") },
	{ id = "crown", kind = "emblem", name = "Corona", rarity = "legendary", price = 1500, shape = "ring", color = Color3.fromHex("#F2C14E") },
}

Catalog.startingOwned = { "kite", "tern", "crate", "factory", "grid", "pivot" }
Catalog.startingLoadout = { primary = "kite", secondary = "tern", support = "crate" }

local byId = {}
for _, list in { Catalog.weapons, Catalog.support, Catalog.finishes, Catalog.banners, Catalog.emblems } do
	for _, item in list do
		assert(byId[item.id] == nil, "duplicate item id " .. item.id)
		byId[item.id] = item
	end
end

function Catalog.get(id: string)
	return byId[id]
end

function Catalog.all()
	local out = {}
	for _, list in { Catalog.weapons, Catalog.support, Catalog.finishes, Catalog.banners, Catalog.emblems } do
		for _, item in list do
			table.insert(out, item)
		end
	end
	return out
end

-- Weapons and support items share the "gear" lists of the armory.
function Catalog.gear()
	local out = table.clone(Catalog.weapons)
	for _, item in Catalog.support do
		table.insert(out, item)
	end
	return out
end

Catalog.kindName = { weapon = "Arma", support = "Apoyo", finish = "Acabado", banner = "Fondo", emblem = "Emblema" }

-- 0-100 bars derived from raw stats so every weapon is compared on the same scale.
Catalog.statOrder = { "damage", "rate", "range", "mobility", "control" }
Catalog.statName = { damage = "Daño", rate = "Cadencia", range = "Alcance", mobility = "Movilidad", control = "Control" }

function Catalog.bars(w)
	local s = w.stats
	return {
		damage = math.min(100, math.round(s.damage * s.pellets)),
		rate = math.min(100, math.round(s.rpm / 900 * 100)),
		range = s.range,
		mobility = s.mobility,
		control = s.control,
	}
end

return Catalog
