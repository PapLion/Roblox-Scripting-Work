--!strict
-- Example item catalogue for the demos. Local data only: no inventory service, no persistence.
-- stats: might, finesse, arcana, vigor (attributes); armor, power, crit (%), haste (%)

export type Item = {
	id: string,
	name: string,
	icon: string,
	rarity: string,
	kind: "weapon" | "armor" | "trinket" | "consumable" | "material" | "quest",
	slot: string?,
	type: string, -- display type ("One-handed sword")
	level: number,
	stats: { [string]: number }?,
	effect: string?,
	lore: string?,
	value: number, -- gold
	weight: number,
	stack: number?, -- max stack size
}

local Items = {}

Items.statNames = {
	power = "Power",
	armor = "Armor",
	might = "Might",
	finesse = "Finesse",
	arcana = "Arcana",
	vigor = "Vigor",
	crit = "Critical",
	haste = "Haste",
}
Items.statOrder = { "power", "armor", "might", "finesse", "arcana", "vigor", "crit", "haste" }
Items.percentStats = { crit = true, haste = true }

Items.slots = {
	{ id = "head", name = "Head", glyph = "user" },
	{ id = "neck", name = "Neck", glyph = "gem" },
	{ id = "back", name = "Back", glyph = "shield_small" },
	{ id = "chest", name = "Chest", glyph = "shield_small" },
	{ id = "hands", name = "Hands", glyph = "hammer" },
	{ id = "waist", name = "Waist", glyph = "bag" },
	{ id = "feet", name = "Feet", glyph = "compass" },
	{ id = "ring", name = "Ring", glyph = "gem" },
	{ id = "mainhand", name = "Main hand", glyph = "sword_small" },
	{ id = "offhand", name = "Off hand", glyph = "shield_small" },
}

local list: { Item } = {
	-- weapons
	{ id = "dawnsteel_blade", name = "Dawnsteel Blade", icon = "sword", rarity = "rare", kind = "weapon", slot = "mainhand", type = "One-handed sword", level = 18, stats = { power = 42, might = 6, crit = 4 }, lore = "Forged at first light; it remembers the sun.", value = 340, weight = 3.2 },
	{ id = "emberfang", name = "Emberfang", icon = "dagger", rarity = "epic", kind = "weapon", slot = "mainhand", type = "Dagger", level = 20, stats = { power = 38, finesse = 11, crit = 9 }, effect = "Hits ignite the target for 3s.", lore = "Still warm, a century after the dragon died.", value = 780, weight = 1.1 },
	{ id = "woodcutter_axe", name = "Woodcutter's Axe", icon = "axe", rarity = "common", kind = "weapon", slot = "mainhand", type = "One-handed axe", level = 4, stats = { power = 14, might = 2 }, value = 22, weight = 3.8 },
	{ id = "warden_mace", name = "Warden's Mace", icon = "mace", rarity = "uncommon", kind = "weapon", slot = "mainhand", type = "Mace", level = 12, stats = { power = 30, might = 5, vigor = 3 }, value = 120, weight = 4.6 },
	{ id = "galeheart_bow", name = "Galeheart Bow", icon = "bow", rarity = "legendary", kind = "weapon", slot = "mainhand", type = "Longbow", level = 24, stats = { power = 58, finesse = 16, haste = 8, crit = 6 }, effect = "Every fifth arrow splits in three.", lore = "Strung with a hair from the north wind.", value = 2400, weight = 2.4 },
	{ id = "staff_tides", name = "Staff of Low Tides", icon = "staff", rarity = "epic", kind = "weapon", slot = "mainhand", type = "Staff", level = 21, stats = { power = 34, arcana = 18, haste = 5 }, effect = "Spells cost 10% less mana.", value = 860, weight = 3.0 },
	{ id = "ashwood_wand", name = "Ashwood Wand", icon = "wand", rarity = "uncommon", kind = "weapon", slot = "offhand", type = "Wand", level = 10, stats = { arcana = 7, crit = 2 }, value = 96, weight = 0.6 },
	{ id = "oakheart_shield", name = "Oakheart Shield", icon = "shield", rarity = "rare", kind = "armor", slot = "offhand", type = "Shield", level = 16, stats = { armor = 46, vigor = 7 }, lore = "Cut from the oak that sheltered the first keep.", value = 290, weight = 6.5 },
	-- armour
	{ id = "iron_helm", name = "Ironbound Helm", icon = "helm", rarity = "uncommon", kind = "armor", slot = "head", type = "Plate helm", level = 14, stats = { armor = 22, vigor = 4 }, value = 110, weight = 4.0 },
	{ id = "sunforged_plate", name = "Sunforged Plate", icon = "chestplate", rarity = "epic", kind = "armor", slot = "chest", type = "Plate armour", level = 22, stats = { armor = 74, might = 9, vigor = 12 }, effect = "+15% healing received.", value = 1350, weight = 14.0 },
	{ id = "traveler_gloves", name = "Traveller's Gloves", icon = "gloves", rarity = "common", kind = "armor", slot = "hands", type = "Leather gloves", level = 6, stats = { armor = 6, finesse = 2 }, value = 18, weight = 0.8 },
	{ id = "striders", name = "Mistwalker Striders", icon = "boots", rarity = "rare", kind = "armor", slot = "feet", type = "Leather boots", level = 17, stats = { armor = 18, finesse = 6, haste = 4 }, value = 260, weight = 1.6 },
	{ id = "dusk_cloak", name = "Duskweave Cloak", icon = "cloak", rarity = "rare", kind = "armor", slot = "back", type = "Cloak", level = 18, stats = { armor = 12, finesse = 5, arcana = 5 }, value = 240, weight = 1.2 },
	{ id = "guild_belt", name = "Guildmaster's Belt", icon = "belt", rarity = "uncommon", kind = "armor", slot = "waist", type = "Belt", level = 11, stats = { armor = 8, vigor = 5 }, value = 84, weight = 0.9 },
	-- trinkets
	{ id = "ring_embers", name = "Ring of Embers", icon = "ring", rarity = "epic", kind = "trinket", slot = "ring", type = "Ring", level = 19, stats = { arcana = 9, crit = 5 }, effect = "Fire spells chain to one extra foe.", value = 920, weight = 0.1 },
	{ id = "amulet_stars", name = "Amulet of the Seventh Star", icon = "amulet", rarity = "mythic", kind = "trinket", slot = "neck", type = "Amulet", level = 25, stats = { arcana = 20, vigor = 10, haste = 10, crit = 7 }, effect = "Once per hour, cheat death.", lore = "The seventh star fell. This is where it landed.", value = 9999, weight = 0.2 },
	-- consumables
	{ id = "potion_health", name = "Healing Draught", icon = "potion_health", rarity = "common", kind = "consumable", type = "Potion", level = 1, effect = "Restores 250 health over 5s.", value = 12, weight = 0.3, stack = 20 },
	{ id = "potion_mana", name = "Mana Tonic", icon = "potion_mana", rarity = "common", kind = "consumable", type = "Potion", level = 1, effect = "Restores 180 mana over 5s.", value = 14, weight = 0.3, stack = 20 },
	{ id = "potion_stamina", name = "Stamina Brew", icon = "potion_stamina", rarity = "uncommon", kind = "consumable", type = "Potion", level = 5, effect = "Stamina regenerates 50% faster for 30s.", value = 30, weight = 0.3, stack = 20 },
	{ id = "elixir_valor", name = "Elixir of Valour", icon = "elixir", rarity = "rare", kind = "consumable", type = "Elixir", level = 15, effect = "+8 to all attributes for 10 minutes.", value = 150, weight = 0.4, stack = 5 },
	{ id = "scroll_recall", name = "Scroll of Recall", icon = "scroll", rarity = "uncommon", kind = "consumable", type = "Scroll", level = 1, effect = "Returns you to the last waystone.", value = 40, weight = 0.1, stack = 10 },
	{ id = "travel_bread", name = "Traveller's Bread", icon = "bread", rarity = "common", kind = "consumable", type = "Food", level = 1, effect = "Restores 60 stamina.", value = 3, weight = 0.2, stack = 40 },
	-- materials
	{ id = "iron_ore", name = "Iron Ore", icon = "ore", rarity = "common", kind = "material", type = "Crafting material", level = 1, value = 4, weight = 1.0, stack = 99 },
	{ id = "steel_ingot", name = "Steel Ingot", icon = "ingot", rarity = "uncommon", kind = "material", type = "Crafting material", level = 1, value = 18, weight = 1.0, stack = 99 },
	{ id = "moonpetal", name = "Moonpetal", icon = "herb", rarity = "uncommon", kind = "material", type = "Herb", level = 1, lore = "Only opens under a full moon.", value = 9, weight = 0.1, stack = 99 },
	{ id = "glowcap", name = "Glowcap", icon = "mushroom", rarity = "common", kind = "material", type = "Fungus", level = 1, value = 5, weight = 0.1, stack = 99 },
	{ id = "emberstone", name = "Emberstone", icon = "gem_ruby", rarity = "rare", kind = "material", type = "Gem", level = 1, value = 85, weight = 0.2, stack = 50 },
	{ id = "tidestone", name = "Tidestone", icon = "gem_sapphire", rarity = "rare", kind = "material", type = "Gem", level = 1, value = 85, weight = 0.2, stack = 50 },
	{ id = "aether_crystal", name = "Aether Crystal", icon = "crystal", rarity = "epic", kind = "material", type = "Reagent", level = 1, value = 260, weight = 0.3, stack = 25 },
	{ id = "tanned_leather", name = "Tanned Leather", icon = "leather", rarity = "common", kind = "material", type = "Crafting material", level = 1, value = 6, weight = 0.5, stack = 99 },
	{ id = "silk_thread", name = "Silk Thread", icon = "thread", rarity = "common", kind = "material", type = "Crafting material", level = 1, value = 4, weight = 0.1, stack = 99 },
	{ id = "ironwood", name = "Ironwood Plank", icon = "wood", rarity = "common", kind = "material", type = "Crafting material", level = 1, value = 5, weight = 1.5, stack = 99 },
	{ id = "griffon_feather", name = "Griffon Feather", icon = "feather", rarity = "rare", kind = "material", type = "Crafting material", level = 1, value = 60, weight = 0.1, stack = 50 },
	-- quest
	{ id = "vault_key", name = "Sunken Vault Key", icon = "key", rarity = "legendary", kind = "quest", type = "Quest item", level = 1, lore = "The lock it opens is under forty fathoms of water.", value = 0, weight = 0.2 },
	{ id = "old_map", name = "Cartographer's Map", icon = "map", rarity = "uncommon", kind = "quest", type = "Quest item", level = 1, lore = "Someone circled a spot in red ink.", value = 0, weight = 0.1 },
	{ id = "tome_ash", name = "Tome of Ash", icon = "tome", rarity = "epic", kind = "quest", type = "Quest item", level = 1, value = 0, weight = 1.4 },
}

local byId: { [string]: Item } = {}
for _, it in list do
	byId[it.id] = it
end
Items.list = list

function Items.get(id: string): Item
	local it = byId[id]
	assert(it, "unknown item " .. id)
	return it
end

function Items.formatStat(key: string, v: number): string
	local sign = if v >= 0 then "+" else "−"
	return `{sign}{math.abs(v)}{if Items.percentStats[key] then "%" else ""} {Items.statNames[key] or key}`
end

-- Rough item score used by sorting and the comparison arrows.
function Items.score(it: Item): number
	local s = 0
	for _, v in it.stats or {} do
		s += v
	end
	return s
end

return Items
