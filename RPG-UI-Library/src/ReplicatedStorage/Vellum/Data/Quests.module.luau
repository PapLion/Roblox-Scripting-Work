--!strict
-- Example quests and achievements for the progression components (local data; no quest engine).
local Quests = {}

Quests.types = {
	main = { name = "Main story", color = Color3.fromHex("F2A93B"), glyph = "crown" },
	side = { name = "Side quest", color = Color3.fromHex("6FB3EE"), glyph = "scroll_small" },
	daily = { name = "Daily", color = Color3.fromHex("57D1C4"), glyph = "hourglass" },
	guild = { name = "Guild contract", color = Color3.fromHex("B472EE"), glyph = "shield_small" },
}

Quests.list = {
	{
		id = "ashen_gate",
		title = "The Ashen Gate",
		type = "main",
		level = 23,
		region = "Cindervale",
		tracked = true,
		status = "active",
		text = "The gate that held the cinder-wyrms for a century is failing. Gather what the old wardens left behind and find out who broke the seals.",
		objectives = {
			{ text = "Recover the warden's journals", current = 3, target = 4 },
			{ text = "Inspect the broken seals", current = 2, target = 2 },
			{ text = "Report to the gatekeeper", current = 0, target = 1 },
		},
		rewards = { xp = 2400, gold = 350, items = { { id = "emberfang", count = 1 }, { id = "potion_health", count = 5 } } },
	},
	{
		id = "moonpetal",
		title = "Moonpetal Harvest",
		type = "side",
		level = 19,
		region = "Silverfen",
		tracked = true,
		status = "active",
		text = "The apothecary needs moonpetals for a fever draught. They only open at night.",
		objectives = {
			{ text = "Gather moonpetals", current = 7, target = 10 },
			{ text = "Avoid waking the fen-lurkers", current = 1, target = 1, optional = true },
		},
		rewards = { xp = 900, gold = 120, items = { { id = "elixir_valor", count = 2 } } },
	},
	{
		id = "bounty",
		title = "Bounty: The Hollow Stag",
		type = "guild",
		level = 22,
		region = "Duskwood",
		tracked = false,
		status = "ready",
		text = "A stag that walks without a heartbeat haunts the old road. The guild pays well for proof.",
		objectives = {
			{ text = "Find the Hollow Stag's trail", current = 1, target = 1 },
			{ text = "Bring back an antler", current = 1, target = 1 },
		},
		rewards = { xp = 1600, gold = 500, items = { { id = "griffon_feather", count = 3 } } },
	},
	{
		id = "daily_forge",
		title = "Stoke the Forge",
		type = "daily",
		level = 10,
		region = "Ironhold",
		tracked = false,
		status = "active",
		text = "The forge-master needs fuel and ore before dawn.",
		objectives = {
			{ text = "Deliver iron ore", current = 14, target = 20 },
			{ text = "Deliver ironwood planks", current = 5, target = 5 },
		},
		rewards = { xp = 400, gold = 60, items = { { id = "steel_ingot", count = 4 } } },
	},
	{
		id = "lighthouse",
		title = "Light at Sorrow's End",
		type = "side",
		level = 15,
		region = "Saltmere",
		tracked = false,
		status = "complete",
		text = "The keeper's lamp is lit again; ships no longer break on the rocks.",
		objectives = {
			{ text = "Repair the lens", current = 1, target = 1 },
			{ text = "Light the lamp", current = 1, target = 1 },
		},
		rewards = { xp = 700, gold = 90, items = {} },
	},
	{
		id = "drowned_vault",
		title = "The Drowned Vault",
		type = "main",
		level = 26,
		region = "Saltmere",
		tracked = false,
		status = "locked",
		text = "Requires level 26 and completion of “The Ashen Gate”.",
		objectives = {},
		rewards = { xp = 3200, gold = 600, items = { { id = "vault_key", count = 1 } } },
	},
}

function Quests.get(id: string)
	for _, q in Quests.list do
		if q.id == id then
			return q
		end
	end
	error("unknown quest " .. id)
end

Quests.achievements = {
	{ id = "first_blood", title = "First Steps", text = "Complete your first quest.", icon = "scroll", points = 10, unlocked = true, date = "Day 1", rarity = 92 },
	{ id = "hoarder", title = "Dragon's Hoard", text = "Hold 10,000 gold at once.", icon = "coin_pouch", points = 25, current = 1840, target = 10000, rarity = 11 },
	{ id = "cartographer", title = "Cartographer", text = "Discover every region of the Vale.", icon = "map", points = 25, current = 9, target = 12, rarity = 23 },
	{ id = "untouchable", title = "Untouchable", text = "Defeat a warden-captain without taking damage.", icon = "ward", points = 50, unlocked = true, date = "Day 14", rarity = 4 },
	{ id = "mythsmith", title = "Mythsmith", text = "Craft an item of mythic rarity.", icon = "ingot", points = 100, locked = true, hidden = false, rarity = 1 },
	{ id = "secret", title = "???", text = "A hidden achievement. Keep exploring.", icon = "key", points = 50, locked = true, hidden = true, rarity = 2 },
}

return Quests
