--!strict
-- Example skill tree and abilities. Descriptions only: nothing here is executed as a game ability.
-- Node: id, name, icon, branch, col (1-3), row (1-5), kind ("passive" | "active" | "keystone"),
-- max (ranks), requires {ids}, text (with {v} replaced by the per-rank value), values {per rank}
local Skills = {}

Skills.branches = {
	{ id = "ember", name = "Emberheart", color = Color3.fromHex("F2803C"), glyph = "flame" },
	{ id = "aegis", name = "Bastion", color = Color3.fromHex("D4A55A"), glyph = "shield_small" },
	{ id = "frost", name = "Wintermere", color = Color3.fromHex("6FC3F2"), glyph = "snow" },
}

-- points that must be spent in a branch before a row unlocks
Skills.rowGate = { 0, 1, 3, 5, 8 }

local function n(t)
	return t
end

Skills.nodes = {
	-- Emberheart
	n({ id = "kindle", name = "Kindle", icon = "fireball", branch = "ember", col = 2, row = 1, kind = "active", max = 1, requires = {}, text = "Hurl a mote of fire that deals {v} damage.", values = { 120 }, cost = 30, cooldown = 4 }),
	n({ id = "searing", name = "Searing Touch", icon = "rage", branch = "ember", col = 1, row = 2, kind = "passive", max = 3, requires = { "kindle" }, text = "Fire damage increased by {v}%.", values = { 4, 8, 12 } }),
	n({ id = "cinder", name = "Cinder Veins", icon = "potion_health", branch = "ember", col = 3, row = 2, kind = "passive", max = 2, requires = { "kindle" }, text = "Burning enemies heal you for {v}% of damage dealt.", values = { 2, 4 } }),
	n({ id = "meteor", name = "Falling Star", icon = "meteor", branch = "ember", col = 2, row = 3, kind = "active", max = 1, requires = { "searing" }, text = "Call down a meteor for {v} damage in an area.", values = { 480 }, cost = 90, cooldown = 18 }),
	n({ id = "pyre", name = "Pyre", icon = "fireball", branch = "ember", col = 1, row = 4, kind = "passive", max = 3, requires = { "meteor" }, text = "Critical hits ignite for {v}s.", values = { 2, 3, 4 } }),
	n({ id = "phoenix", name = "Heart of the Phoenix", icon = "smite", branch = "ember", col = 2, row = 5, kind = "keystone", max = 1, requires = { "pyre" }, text = "Once per battle, rise from death at {v}% health in a burst of flame.", values = { 40 } }),
	-- Aegis
	n({ id = "guard", name = "Steadfast", icon = "shield", branch = "aegis", col = 2, row = 1, kind = "passive", max = 3, requires = {}, text = "Armor increased by {v}.", values = { 10, 20, 30 } }),
	n({ id = "ward", name = "Arcane Ward", icon = "ward", branch = "aegis", col = 1, row = 2, kind = "active", max = 1, requires = { "guard" }, text = "Absorb the next {v} damage.", values = { 220 }, cost = 50, cooldown = 12 }),
	n({ id = "thorns", name = "Briar Mail", icon = "thorns", branch = "aegis", col = 3, row = 2, kind = "passive", max = 2, requires = { "guard" }, text = "Reflect {v}% of melee damage taken.", values = { 6, 12 } }),
	n({ id = "renew", name = "Renewal", icon = "regen", branch = "aegis", col = 2, row = 3, kind = "active", max = 1, requires = { "ward" }, text = "Restore {v} health over 6 seconds.", values = { 360 }, cost = 60, cooldown = 15 }),
	n({ id = "bulwark", name = "Bulwark", icon = "chestplate", branch = "aegis", col = 3, row = 4, kind = "passive", max = 3, requires = { "renew", "thorns" }, text = "Damage taken reduced by {v}%.", values = { 3, 6, 9 } }),
	n({ id = "dawnwall", name = "Dawnwall", icon = "heal", branch = "aegis", col = 2, row = 5, kind = "keystone", max = 1, requires = { "bulwark" }, text = "Allies behind you take {v}% less damage.", values = { 20 } }),
	-- Wintermere
	n({ id = "shard", name = "Frost Shard", icon = "frost_shard", branch = "frost", col = 2, row = 1, kind = "active", max = 1, requires = {}, text = "Launch a shard that chills for {v}s.", values = { 3 }, cost = 25, cooldown = 3 }),
	n({ id = "rime", name = "Rime", icon = "crystal", branch = "frost", col = 1, row = 2, kind = "passive", max = 3, requires = { "shard" }, text = "Chilled enemies take {v}% more damage.", values = { 5, 10, 15 } }),
	n({ id = "glide", name = "Iceglide", icon = "dash", branch = "frost", col = 3, row = 2, kind = "active", max = 1, requires = { "shard" }, text = "Dash {v} metres on a trail of ice.", values = { 8 }, cost = 20, cooldown = 8 }),
	n({ id = "blizzard", name = "Blizzard", icon = "blizzard", branch = "frost", col = 2, row = 3, kind = "active", max = 1, requires = { "rime" }, text = "A storm deals {v} damage per second for 6s.", values = { 90 }, cost = 80, cooldown = 20 }),
	n({ id = "stillness", name = "Stillness", icon = "stealth", branch = "frost", col = 1, row = 4, kind = "passive", max = 2, requires = { "blizzard" }, text = "Standing still grants {v}% haste.", values = { 8, 16 } }),
	n({ id = "winterheart", name = "Winter's Heart", icon = "spirit_wolf", branch = "frost", col = 2, row = 5, kind = "keystone", max = 1, requires = { "stillness" }, text = "Summon a frost wolf that fights for {v}s.", values = { 30 } }),
}

local byId = {}
for _, node in Skills.nodes do
	byId[node.id] = node
end
function Skills.get(id: string)
	return byId[id]
end

function Skills.describe(node, rank: number): string
	local v = node.values[math.max(1, math.min(rank, #node.values))]
	return (string.gsub(node.text, "{v}", tostring(v)))
end

-- Abilities for the action bar (independent of the tree; local demo values)
Skills.abilities = {
	{ id = "kindle", name = "Kindle", icon = "fireball", key = "1", cost = 30, cooldown = 4, cast = "Instant", range = "30 m", text = "Hurl a mote of fire that deals 120 damage and ignites the target.", rank = 3, maxRank = 5, school = "Fire" },
	{ id = "shard", name = "Frost Shard", icon = "frost_shard", key = "2", cost = 25, cooldown = 3, cast = "Instant", range = "35 m", text = "Launch a shard of ice that chills the target for 3 seconds.", rank = 2, maxRank = 5, school = "Frost" },
	{ id = "ward", name = "Arcane Ward", icon = "ward", key = "3", cost = 50, cooldown = 12, cast = "Instant", range = "Self", text = "Wrap yourself in a ward that absorbs the next 220 damage.", rank = 1, maxRank = 3, school = "Arcane" },
	{ id = "glide", name = "Iceglide", icon = "dash", key = "4", cost = 20, cooldown = 8, cast = "Instant", range = "8 m", text = "Dash forward on a trail of ice, leaving chilling frost behind.", rank = 1, maxRank = 3, school = "Frost" },
	{ id = "renew", name = "Renewal", icon = "regen", key = "5", cost = 60, cooldown = 15, cast = "1.5 s", range = "Self", text = "Restore 360 health over 6 seconds.", rank = 2, maxRank = 3, school = "Nature" },
	{ id = "meteor", name = "Falling Star", icon = "meteor", key = "6", cost = 90, cooldown = 18, cast = "2 s", range = "40 m", text = "Call down a meteor that deals 480 damage in an area.", rank = 1, maxRank = 3, school = "Fire", ultimate = true },
	{ id = "stealth", name = "Fade", icon = "stealth", key = "7", cost = 0, cooldown = 0, cast = "Toggle", range = "Self", text = "Toggle: move unseen. Drains 4 mana per second.", rank = 1, maxRank = 1, school = "Shadow", toggle = true },
	{ id = "wolf", name = "Winter's Heart", icon = "spirit_wolf", key = "8", cost = 120, cooldown = 60, cast = "Instant", range = "Self", text = "Summon a frost wolf. Learned at level 30.", rank = 0, maxRank = 1, school = "Frost", locked = true },
}

return Skills
