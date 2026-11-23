--!strict
-- Inventory specimens: satchel, item tooltips, slot states.
local Lib = require(script.Parent.Parent.Lib)
local Theme = require(Lib.Theme)
local Create = require(Lib.Core.Create)
local Store = require(Lib.Core.Store)
local Surface = require(Lib.Components.Surface)
local Slot = require(Lib.Components.Slot)
local ItemCard = require(Lib.Components.ItemCard)
local Inventory = require(Lib.Widgets.Inventory)
local Items = require(Lib.Data.Items)

local C = Theme.color

return {
	{
		id = "inventory",
		family = "inventory",
		title = "Satchel inventory",
		blurb = "Drag-and-drop slots with stack merging, category filters, search, sorting, comparison tooltips and a context menu.",
		size = Vector2.new(586, 540),
		build = function(scope, parent)
			local inv = Inventory.new(scope)
			inv.Instance.AnchorPoint = Vector2.new(0.5, 0)
			inv.Instance.Position = UDim2.fromScale(0.5, 0)
			inv.Instance.Parent = parent
			local function patch(fn)
				local st = Store.copy(inv.store:get())
				fn(st)
				inv.store:set(st)
			end
			return {
				onReset = inv.reset,
				actions = {
					{ label = "Filter: weapons", run = function()
						inv.store:set({ filter = "weapon" })
					end },
					{ label = "Search “potion”", run = function()
						inv.search:set("potion")
					end },
					{ label = "Sort by rarity", run = function()
						patch(function(st)
							Inventory.sort(st, "Rarity")
							st.sortIndex = 1
						end)
					end },
					{ label = "Drag slot 1 → 3", run = function()
						inv.drag:dropOn({ from = 1 }, inv.cells[3].slot.Instance)
					end },
					{ label = "Merge potions", run = function()
						patch(function(st)
							st.slots[3] = { id = "potion_health", count = 6 }
						end)
						task.wait(0.4)
						inv.drag:dropOn({ from = 3 }, inv.cells[4].slot.Instance)
					end },
					{ label = "Pick up slot 2", run = function()
						inv.store:set({ picked = 2 })
					end },
					{ label = "Context menu", run = function()
						inv.openMenu(4)
					end },
					{ label = "Inspect Galeheart Bow", run = function()
						inv.cells[10].tip.show()
					end },
				},
			}
		end,
	},
	{
		id = "item-tooltips",
		family = "inventory",
		title = "Item tooltips & comparison",
		blurb = "Item cards by rarity: stat comparison against the equipped item, effects, lore, stack value and weight.",
		size = Vector2.new(1070, 356),
		build = function(scope, parent)
			local row = Create.box({ Size = UDim2.fromScale(1, 1), Parent = parent }, { Create.list("x", 24, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
			local function add(card: Frame, order: number)
				card.LayoutOrder = order
				card.Parent = row
				scope:add(card)
			end
			-- comparison pair
			local pair = Create.box({ Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1, Parent = row }, { Create.list("x", 10) })
			local bow = Items.get("galeheart_bow")
			local mace = Items.get("warden_mace")
			local a = ItemCard.new(bow, { compare = mace })
			a.LayoutOrder = 1
			a.Parent = pair
			local b = ItemCard.new(mace, { equipped = true, width = 250 })
			b.LayoutOrder = 2
			b.Parent = pair
			add(ItemCard.new(Items.get("amulet_stars"), { width = 250 }), 2)
			local col = Create.box({ Size = UDim2.fromOffset(220, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = row }, { Create.list("y", 14) })
			local p = ItemCard.new(Items.get("potion_health"), { count = 12, width = 220 })
			p.Parent = col
			local q = ItemCard.new(Items.get("vault_key"), { width = 220 })
			q.LayoutOrder = 2
			q.Parent = col
			return nil
		end,
	},
	{
		id = "slots",
		family = "inventory",
		title = "Item slots",
		blurb = "Six rarities and every slot state: empty, hover, picked up, keyboard focus, locked, drop targets, filtered out and equipped.",
		size = Vector2.new(724, 262),
		build = function(scope, parent)
			local grid = Create.box({ Size = UDim2.fromScale(1, 1), Parent = parent }, { Create.list("y", 16) })
			local function row(order: number, title: string)
				local r = Create.box({ Size = UDim2.new(1, 0, 0, 98), LayoutOrder = order, Parent = grid }, { Create.list("x", 14) })
				Surface.caption(title, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 16), Parent = grid }).LayoutOrder = order - 1
				return r
			end
			local function cell(parent: Instance, order: number, label: string, build: (Frame) -> ())
				local c = Create.box({ Size = UDim2.fromOffset(78, 98), LayoutOrder = order, Parent = parent })
				local holder = Create.box({ Size = UDim2.fromOffset(68, 68), Position = UDim2.fromOffset(5, 0), Parent = c })
				build(holder)
				Surface.text({ role = "caps", text = label, color = C.textFaint, size = 9, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 76), TextXAlignment = Enum.TextXAlignment.Center, Parent = c })
			end
			local rar = row(2, "Rarity")
			local samples = { common = "woodcutter_axe", uncommon = "warden_mace", rare = "dawnsteel_blade", epic = "emberfang", legendary = "galeheart_bow", mythic = "amulet_stars" }
			for i, r in Theme.rarityOrder do
				cell(rar, i, Theme.rarity[r].name, function(h)
					local s = Slot.new(scope, { size = 68, item = Items.get(samples[r]) })
					s.Instance.Parent = h
				end)
			end
			local states = row(4, "States")
			local defs = {
				{ "Empty", nil, nil },
				{ "Stack", "potion_mana", function(s)
					s:setItem(Items.get("potion_mana"), 7)
				end },
				{ "Hover", "emberstone", function(s)
					s:force({ hover = true })
				end },
				{ "Picked", "sunforged_plate", function(s)
					s:set({ selected = true })
				end },
				{ "Focus", "ring_embers", function(s)
					s:force({ focused = true })
				end },
				{ "Drop ok", nil, function(s)
					s:set({ drop = "valid" })
				end },
				{ "Locked", nil, function(s)
					s:set({ locked = true })
				end },
				{ "Filtered", "glowcap", function(s)
					s:set({ dim = true })
				end },
			}
			for i, d in defs do
				cell(states, i, d[1], function(h)
					local s = Slot.new(scope, { size = 68, item = d[2] and Items.get(d[2]) or nil })
					s.Instance.Parent = h
					if d[3] then
						d[3](s)
					end
				end)
			end
			return nil
		end,
	},
}
