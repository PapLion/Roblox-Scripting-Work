--!strict
-- Character & Equipment specimens.
local Lib = require(script.Parent.Parent.Lib)
local Create = require(Lib.Core.Create)
local Character = require(Lib.Widgets.Character)
local Feedback = require(Lib.Components.Feedback)

return {
	{
		id = "character-card",
		family = "character",
		title = "Character card & vitals",
		blurb = "Crest portrait with an experience ring, class and points tags, health, mana and stamina bars with damage trails, and experience.",
		size = Vector2.new(400, 380),
		build = function(scope, parent)
			local card = Character.card(scope, { width = 400 })
			card.Instance.Parent = parent
			local v = card.vitals
			return {
				onReset = function()
					v.reset()
				end,
				actions = {
					{ label = "Take 180 damage", run = function()
						v:damage(180)
					end },
					{ label = "Heal 120", run = function()
						v:heal(120)
					end },
					{ label = "Cast (−60 mana)", run = function()
						v:cast(60)
					end },
					{ label = "Sprint (−35%)", run = function()
						v:sprint(35)
					end },
					{ label = "Gain 900 XP", run = function()
						v:gainXp(900)
					end },
					{ label = "Gain 3000 XP (level up)", run = function()
						v:gainXp(3000)
					end },
					{ label = "Restore", run = function()
						v:restore()
					end },
				},
			}
		end,
	},
	{
		id = "status-effects",
		family = "character",
		title = "Status effects",
		blurb = "Blessings and afflictions with live radial timers, stacks and tooltips; refreshed effects add a stack.",
		size = Vector2.new(470, 210),
		build = function(scope, parent)
			local holder = Create.box({ Size = UDim2.fromScale(1, 1), Parent = parent }, { Create.list("y", 14) })
			local eff = Character.effects(scope, { effects = { "blessed", "haste", "regen", "ward", "burning", "poison", "chilled" }, layoutOrder = 1 })
			eff.Instance.Parent = holder
			return {
				onReset = function()
					eff:clear()
					for _, id in { "blessed", "haste", "regen", "ward", "burning", "poison", "chilled" } do
						eff:add(id)
					end
				end,
				actions = {
					{ label = "Stack Burning", run = function()
						eff:add("burning")
					end },
					{ label = "Freeze timers", run = function()
						eff:freeze(true)
					end },
					{ label = "Resume timers", run = function()
						eff:freeze(false)
					end },
				},
			}
		end,
	},
	{
		id = "equipment",
		family = "character",
		title = "Equipment & attributes",
		blurb = "Paperdoll slots with an item chooser, attribute point allocation with commit and undo, and derived stats that update as gear changes.",
		size = Vector2.new(880, 620),
		build = function(scope, parent)
			local eq = Character.equipment(scope)
			eq.Instance.Parent = parent
			return {
				onReset = eq.reset,
				actions = {
					{ label = "Equip Galeheart Bow", run = function()
						eq:equip("mainhand", "galeheart_bow")
					end },
					{ label = "Select neck slot", run = function()
						eq.store:set({ selected = "neck" })
					end },
					{ label = "Equip amulet", run = function()
						eq:equip("neck", "amulet_stars")
					end },
					{ label = "Assign 2 Might", run = function()
						eq.store:set({ pending = { might = 2, finesse = 0, arcana = 0, vigor = 0 } })
					end },
				},
			}
		end,
	},
}
