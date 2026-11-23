--!strict
-- Crafting & Commerce specimens.
local Lib = require(script.Parent.Parent.Lib)
local Commerce = require(Lib.Widgets.Commerce)

return {
	{
		id = "crafting",
		family = "commerce",
		title = "Crafting station",
		blurb = "Recipe list with craftable counts, material requirements (have / need), quantity, timed crafting with cancel, and the missing-materials state.",
		size = Vector2.new(900, 580),
		build = function(scope, parent)
			local c = Commerce.crafting(scope)
			c.Instance.Parent = parent
			return {
				onReset = c.reset,
				actions = {
					{ label = "Select Sunforged Plate (missing)", run = function()
						c:select("r_plate")
					end },
					{ label = "Craft 1 Dawnsteel", run = function()
						c:select("r_dawnsteel")
						c.craft()
					end },
					{ label = "Steel ingots ×3", run = function()
						c:select("r_ingot", 3)
						c.craft()
					end },
				},
			}
		end,
	},
	{
		id = "vendor",
		family = "commerce",
		title = "Vendor",
		blurb = "Buy and sell modes, wallet, rarity-framed item cards with stock, discounts, sold-out and unaffordable prices.",
		size = Vector2.new(820, 500),
		build = function(scope, parent)
			local v = Commerce.vendor(scope)
			v.Instance.Parent = parent
			return {
				onReset = v.reset,
				actions = {
					{ label = "Buy Healing Draught", run = function()
						v:buy("potion_health")
					end },
					{ label = "Try Galeheart Bow", run = function()
						v:buy("galeheart_bow")
					end },
					{ label = "Sell mode", run = function()
						v.store:set({ mode = 2 })
					end },
				},
			}
		end,
	},
	{
		id = "purchase-dialog",
		family = "commerce",
		title = "Purchase confirmation",
		blurb = "Quantity slider, balance, total and the balance after purchase; the confirm button refuses when gold runs short.",
		size = Vector2.new(560, 470),
		build = function(scope, parent)
			-- the dialog over a real vendor, isolated: the vendor sits behind the dim
			local v = Commerce.vendor(scope)
			v.Instance.Visible = false
			v.Instance.Parent = parent
			task.defer(function()
				v:buy("potion_mana")
			end)
			return {
				onReset = function()
					v:buy("potion_mana")
				end,
				actions = {
					{ label = "Unaffordable item", run = function()
						v:buy("galeheart_bow")
					end },
				},
			}
		end,
	},
}
