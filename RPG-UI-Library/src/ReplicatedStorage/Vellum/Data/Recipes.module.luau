--!strict
-- Example recipes, material stock and a vendor list for the crafting and commerce components.
local Recipes = {}

Recipes.categories = { "Smithing", "Alchemy", "Tailoring" }

Recipes.list = {
	{ id = "r_dawnsteel", category = "Smithing", result = "dawnsteel_blade", count = 1, time = 2.4, level = 18, materials = { { id = "steel_ingot", need = 6 }, { id = "emberstone", need = 1 }, { id = "tanned_leather", need = 2 } } },
	{ id = "r_helm", category = "Smithing", result = "iron_helm", count = 1, time = 1.8, level = 14, materials = { { id = "steel_ingot", need = 4 }, { id = "tanned_leather", need = 1 } } },
	{ id = "r_shield", category = "Smithing", result = "oakheart_shield", count = 1, time = 2.0, level = 16, materials = { { id = "ironwood", need = 5 }, { id = "steel_ingot", need = 2 } } },
	{ id = "r_plate", category = "Smithing", result = "sunforged_plate", count = 1, time = 3.2, level = 22, materials = { { id = "steel_ingot", need = 12 }, { id = "emberstone", need = 3 }, { id = "aether_crystal", need = 1 } } },
	{ id = "r_ingot", category = "Smithing", result = "steel_ingot", count = 1, time = 0.8, level = 1, materials = { { id = "iron_ore", need = 3 } } },
	{ id = "r_health", category = "Alchemy", result = "potion_health", count = 2, time = 1.2, level = 1, materials = { { id = "glowcap", need = 2 }, { id = "moonpetal", need = 1 } } },
	{ id = "r_mana", category = "Alchemy", result = "potion_mana", count = 2, time = 1.2, level = 1, materials = { { id = "moonpetal", need = 2 }, { id = "tidestone", need = 1 } } },
	{ id = "r_elixir", category = "Alchemy", result = "elixir_valor", count = 1, time = 2.6, level = 15, materials = { { id = "aether_crystal", need = 1 }, { id = "moonpetal", need = 4 }, { id = "griffon_feather", need = 1 } } },
	{ id = "r_cloak", category = "Tailoring", result = "dusk_cloak", count = 1, time = 2.2, level = 18, materials = { { id = "silk_thread", need = 8 }, { id = "tanned_leather", need = 3 }, { id = "aether_crystal", need = 1 } } },
	{ id = "r_gloves", category = "Tailoring", result = "traveler_gloves", count = 1, time = 1.0, level = 6, materials = { { id = "tanned_leather", need = 2 }, { id = "silk_thread", need = 2 } } },
	{ id = "r_belt", category = "Tailoring", result = "guild_belt", count = 1, time = 1.4, level = 11, materials = { { id = "tanned_leather", need = 4 }, { id = "steel_ingot", need = 1 } } },
}

Recipes.stock = {
	steel_ingot = 9, emberstone = 4, tanned_leather = 11, ironwood = 3, aether_crystal = 2, iron_ore = 40,
	glowcap = 14, moonpetal = 23, tidestone = 0, griffon_feather = 1, silk_thread = 12,
}

-- Vendor: price multiplier on item value, optional stock and discount
Recipes.vendor = {
	name = "The Gilded Lantern",
	subtitle = "Curios, arms and remedies",
	items = {
		{ id = "potion_health", price = 15, stock = nil },
		{ id = "potion_mana", price = 18, stock = nil },
		{ id = "scroll_recall", price = 45, stock = 5 },
		{ id = "elixir_valor", price = 180, stock = 2, discount = 20 },
		{ id = "striders", price = 320, stock = 1 },
		{ id = "oakheart_shield", price = 360, stock = 1 },
		{ id = "staff_tides", price = 1100, stock = 1 },
		{ id = "galeheart_bow", price = 2900, stock = 1 },
		{ id = "griffon_feather", price = 75, stock = 0 },
	},
}

return Recipes
