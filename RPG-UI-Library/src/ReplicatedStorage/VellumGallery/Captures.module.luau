--!strict
-- The portfolio capture list: specimen, prep actions (run on the fresh capture mount) and settle time.
-- Run with the bridge: VellumBridge:Invoke("batch") and tools/capture/batch.py (see README).
return {
	{ id = "buttons" },
	{ id = "controls", prep = { "Open dropdown" }, wait = 0.8 },
	{ id = "inventory", prep = { "Inspect Galeheart Bow" }, wait = 0.9 },
	{ id = "item-tooltips" },
	{ id = "slots" },
	{ id = "character-card", prep = { "Take 180 damage", "Cast (−60 mana)" }, wait = 1.6 },
	{ id = "status-effects", wait = 1.0 },
	{ id = "equipment", prep = { "Assign 2 Might" }, wait = 1.8 },
	{ id = "skill-tree", prep = { "Learn Rime ×2" }, wait = 1.2 },
	{ id = "ability-bar", prep = { "Showcase states" }, wait = 0.9 },
	{ id = "ability-cards" },
	{ id = "quest-log", wait = 0.6 },
	{ id = "quest-cards" },
	{ id = "quest-tracker", prep = { "Advance Moonpetal" }, wait = 1.0 },
	{ id = "achievements" },
	{ id = "level-up", wait = 2.0 },
	{ id = "quest-complete", wait = 1.8 },
	{ id = "crafting", prep = { "Craft 1 Dawnsteel" }, wait = 1.0 },
	{ id = "vendor", wait = 0.5 },
	{ id = "purchase-dialog", wait = 1.0 },
	{ id = "toasts" },
	{ id = "dialogs", wait = 0.8 },
	{ id = "loot-reveal", wait = 2.0 },
	{ id = "feedback-kit", wait = 1.0 },
}
