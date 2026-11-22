--!strict
-- Skills & Abilities specimens.
local Lib = require(script.Parent.Parent.Lib)
local Create = require(Lib.Core.Create)
local SkillTree = require(Lib.Widgets.SkillTree)
local Abilities = require(Lib.Widgets.Abilities)
local Skills = require(Lib.Data.Skills)

local function ability(id: string)
	for _, a in Skills.abilities do
		if a.id == id then
			return a
		end
	end
	error(id)
end

return {
	{
		id = "skill-tree",
		family = "skills",
		title = "Skill tree",
		blurb = "Three branches with prerequisites, row gates, ranks and animated paths; inspect a node, learn or unlearn ranks, reset with confirmation.",
		size = Vector2.new(1090, 640),
		build = function(scope, parent)
			local tree = SkillTree.new(scope)
			tree.Instance.Parent = parent
			return {
				onReset = tree.reset,
				actions = {
					{ label = "Learn Falling Star", run = function()
						tree:learn("meteor")
					end },
					{ label = "Learn Rime ×2", run = function()
						tree:learn("rime")
						task.wait(0.3)
						tree:learn("rime")
					end },
					{ label = "Select locked keystone", run = function()
						tree:select("phoenix")
					end },
					{ label = "Select Kindle (has dependents)", run = function()
						tree:select("kindle")
					end },
				},
			}
		end,
	},
	{
		id = "ability-bar",
		family = "skills",
		title = "Ability bar",
		blurb = "Keybound abilities with cooldown sweeps and countdowns, global cooldown, mana costs, out-of-mana tint, a toggled ability and a locked slot.",
		size = Vector2.new(622, 150),
		build = function(scope, parent)
			local bar = Abilities.bar(scope)
			bar.Instance.Parent = parent
			return {
				onReset = bar.reset,
				actions = {
					{ label = "Cast 1", run = function()
						bar:trigger(1)
					end },
					{ label = "Cast 3", run = function()
						bar:trigger(3)
					end },
					{ label = "Toggle Fade (7)", run = function()
						bar:trigger(7)
					end },
					{ label = "Showcase states", run = function()
						bar:reset()
						bar:trigger(6)
						task.wait(1.0)
						bar:trigger(3)
						task.wait(1.0)
						bar:trigger(1)
						bar:trigger(7)
						bar:setMana(40)
					end },
					{ label = "Freeze", run = function()
						bar:freeze(true)
					end },
					{ label = "Unfreeze", run = function()
						bar:freeze(false)
					end },
				},
			}
		end,
	},
	{
		id = "ability-cards",
		family = "skills",
		title = "Ability cards",
		blurb = "Ability detail cards: school and ultimate tags, rank pips, cost, cooldown, cast time, range and a locked ability.",
		size = Vector2.new(960, 300),
		build = function(scope, parent)
			local row = Create.box({ Size = UDim2.fromScale(1, 1), Parent = parent }, { Create.list("x", 30, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
			for i, id in { "kindle", "meteor", "wolf" } do
				local c = Abilities.card(ability(id), { width = 300 })
				c.LayoutOrder = i
				c.Parent = row
				scope:add(c)
			end
			return nil
		end,
	},
}
