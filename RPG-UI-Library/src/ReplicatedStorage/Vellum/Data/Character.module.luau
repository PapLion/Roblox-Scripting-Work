--!strict
-- Example character for the equipment / character components. The derived numbers are display sums
-- (base + attributes + gear) so the panels have something consistent to show; there is no combat model.
local Items = require(script.Parent.Items)

local Character = {}

function Character.example()
	return {
		name = "Elowen Vey",
		title = "Warden of the Ashen Gate",
		class = "Warden",
		crest = "ward",
		level = 23,
		xp = 7420,
		xpNext = 9800,
		points = 3,
		attributes = { might = 14, finesse = 11, arcana = 8, vigor = 16 },
		equipped = {
			head = "iron_helm",
			chest = "sunforged_plate",
			back = "dusk_cloak",
			hands = "traveler_gloves",
			feet = "striders",
			waist = "guild_belt",
			ring = "ring_embers",
			mainhand = "dawnsteel_blade",
			offhand = "oakheart_shield",
		},
		-- items in the bag that can be equipped (by slot)
		stash = { "emberfang", "galeheart_bow", "warden_mace", "woodcutter_axe", "staff_tides", "ashwood_wand", "amulet_stars" },
	}
end

Character.attributeInfo = {
	{ id = "might", name = "Might", glyph = "sword_small", text = "+2 Power and +5 Health per point." },
	{ id = "finesse", name = "Finesse", glyph = "bolt", text = "+0.4% Critical and +2 Stamina per point." },
	{ id = "arcana", name = "Arcana", glyph = "sparkle", text = "+8 Mana and +0.3% Haste per point." },
	{ id = "vigor", name = "Vigor", glyph = "heart", text = "+15 Health and +1 Armor per point." },
}

-- Derived display stats.
function Character.derive(ch): { [string]: number }
	local a = table.clone(ch.attributes)
	local gear = { power = 0, armor = 0, crit = 0, haste = 0 }
	for _, id in ch.equipped do
		local it = Items.get(id)
		for k, v in it.stats or {} do
			if a[k] ~= nil then
				a[k] += v
			elseif gear[k] ~= nil then
				gear[k] += v
			end
		end
	end
	return {
		might = a.might,
		finesse = a.finesse,
		arcana = a.arcana,
		vigor = a.vigor,
		power = gear.power + a.might * 2,
		armor = gear.armor + a.vigor,
		crit = math.floor((5 + gear.crit + a.finesse * 0.4) * 10 + 0.5) / 10,
		haste = math.floor((gear.haste + a.arcana * 0.3) * 10 + 0.5) / 10,
		health = 400 + a.might * 5 + a.vigor * 15,
		mana = 200 + a.arcana * 8,
		stamina = 100 + a.finesse * 2,
	}
end

Character.derivedOrder = {
	{ id = "health", name = "Health", glyph = "heart" },
	{ id = "mana", name = "Mana", glyph = "drop" },
	{ id = "stamina", name = "Stamina", glyph = "bolt" },
	{ id = "power", name = "Power", glyph = "sword_small" },
	{ id = "armor", name = "Armor", glyph = "shield_small" },
	{ id = "crit", name = "Critical", glyph = "star", pct = true },
	{ id = "haste", name = "Haste", glyph = "hourglass", pct = true },
}

Character.effects = {
	{ id = "blessed", name = "Blessing of Dawn", icon = "smite", kind = "buff", duration = 120, text = "+10% healing received." },
	{ id = "haste", name = "Quickened", icon = "haste", kind = "buff", duration = 18, text = "+15% movement speed." },
	{ id = "regen", name = "Regeneration", icon = "regen", kind = "buff", duration = 30, stacks = 3, text = "Restores 12 health per second per stack." },
	{ id = "ward", name = "Arcane Ward", icon = "ward", kind = "buff", duration = 45, text = "Absorbs the next 220 damage." },
	{ id = "burning", name = "Burning", icon = "fireball", kind = "debuff", duration = 8, stacks = 2, text = "Takes fire damage every second." },
	{ id = "poison", name = "Witherbloom Poison", icon = "poison", kind = "debuff", duration = 14, text = "−25% healing received." },
	{ id = "chilled", name = "Chilled", icon = "frost_shard", kind = "debuff", duration = 6, text = "−20% attack speed." },
}

return Character
