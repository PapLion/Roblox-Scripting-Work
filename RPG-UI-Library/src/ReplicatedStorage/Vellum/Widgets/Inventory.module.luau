--!strict
-- Inventory ("Satchel"): a slot grid driven by a local Store.
--   • drag an item onto another slot to move / swap it; same stackable item merges stacks
--   • click (or Enter) picks an item up, click another slot to place it — the keyboard path for moves
--   • category filter and search reduce the grid to matching items; sort rewrites the slot order
--   • hover / focus shows the item card compared against what is equipped
--   • right-click opens a context menu: use, equip, split stack, mark as junk, discard (with confirm)
-- Everything is local example state. Nothing is persisted.
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.Theme)
local Atlas = require(script.Parent.Parent.Atlas)
local Create = require(script.Parent.Parent.Core.Create)
local Store = require(script.Parent.Parent.Core.Store)
local Layers = require(script.Parent.Parent.Core.Layers)
local DragDrop = require(script.Parent.Parent.Core.DragDrop)
local Surface = require(script.Parent.Parent.Components.Surface)
local Controls = require(script.Parent.Parent.Components.Controls)
local Feedback = require(script.Parent.Parent.Components.Feedback)
local Slot = require(script.Parent.Parent.Components.Slot)
local ItemCard = require(script.Parent.Parent.Components.ItemCard)
local Items = require(script.Parent.Parent.Data.Items)

local C = Theme.color
local Inventory = {}

Inventory.categories = {
	{ id = "all", name = "All items", glyph = "bag" },
	{ id = "weapon", name = "Weapons", glyph = "sword_small" },
	{ id = "armor", name = "Armour", glyph = "shield_small" },
	{ id = "trinket", name = "Trinkets", glyph = "gem" },
	{ id = "consumable", name = "Consumables", glyph = "drop" },
	{ id = "material", name = "Materials", glyph = "hammer" },
	{ id = "quest", name = "Quest items", glyph = "quest" },
}
Inventory.sorts = { "Rarity", "Type", "Name", "Value", "Weight" }

local KIND_ORDER = { weapon = 1, armor = 2, trinket = 3, consumable = 4, material = 5, quest = 6 }

-- Default example contents: 40 slots, some empty.
function Inventory.exampleState()
	local s: { any } = {
		{ id = "dawnsteel_blade", count = 1 }, { id = "emberfang", count = 1 }, false, { id = "potion_health", count = 12 },
		{ id = "potion_mana", count = 7 }, { id = "oakheart_shield", count = 1 }, { id = "moonpetal", count = 23 }, false,
		{ id = "iron_helm", count = 1 }, { id = "galeheart_bow", count = 1 }, { id = "scroll_recall", count = 3 }, { id = "iron_ore", count = 40 },
		false, { id = "ring_embers", count = 1 }, { id = "steel_ingot", count = 9 }, { id = "elixir_valor", count = 2 },
		{ id = "striders", count = 1 }, false, { id = "vault_key", count = 1 }, { id = "glowcap", count = 14 },
		{ id = "woodcutter_axe", count = 1 }, { id = "travel_bread", count = 18 }, { id = "aether_crystal", count = 2 }, false,
		{ id = "dusk_cloak", count = 1 }, { id = "emberstone", count = 4 }, { id = "old_map", count = 1 }, { id = "potion_stamina", count = 5 },
		false, false, { id = "staff_tides", count = 1 }, { id = "tanned_leather", count = 11 },
		false, false, false, false, false, false, false, false,
	}
	return {
		slots = s,
		filter = "all",
		query = "",
		sortIndex = nil :: number?,
		picked = nil :: number?,
		gold = 1840,
		junk = {},
		equipped = { mainhand = "warden_mace", head = "iron_helm", ring = "ring_embers", back = "dusk_cloak", feet = "striders" },
	}
end

local function matches(state, entry): boolean
	if not entry then
		return false
	end
	local it = Items.get(entry.id)
	if state.filter ~= "all" and it.kind ~= state.filter then
		return false
	end
	local q = string.lower(state.query)
	if q ~= "" then
		local hay = string.lower(it.name .. " " .. it.type .. " " .. Theme.rarityOf(it.rarity).name)
		if not string.find(hay, q, 1, true) then
			return false
		end
	end
	return true
end

local function filtered(state): boolean
	return state.filter ~= "all" or state.query ~= ""
end

-- Underlying slot indices shown, in order. Unfiltered: every slot. Filtered: only matching items.
function Inventory.view(state): { number }
	local out = {}
	for i, e in state.slots do
		if not filtered(state) or matches(state, e) then
			table.insert(out, i)
		end
	end
	return out
end

-- Pure state transitions (also used by tests and the gallery's scripted demo)
function Inventory.move(state, from: number, to: number)
	if from == to then
		return state
	end
	local slots = table.clone(state.slots)
	local a, b = slots[from], slots[to]
	if not a then
		return state
	end
	local it = Items.get(a.id)
	if b and b.id == a.id and it.stack then
		-- merge stacks up to the stack size; remainder stays at the source
		local room = it.stack - b.count
		local moved = math.min(room, a.count)
		slots[to] = { id = b.id, count = b.count + moved }
		slots[from] = if a.count - moved > 0 then { id = a.id, count = a.count - moved } else false
	else
		slots[from], slots[to] = b, a
	end
	state.slots = slots
	return state
end

function Inventory.sort(state, key: string)
	local items = {}
	for _, e in state.slots do
		if e then
			table.insert(items, e)
		end
	end
	local function v(e)
		return Items.get(e.id)
	end
	table.sort(items, function(x, y)
		local a, b = v(x), v(y)
		if key == "Rarity" then
			local ra, rb = Theme.rarityOf(a.rarity).rank, Theme.rarityOf(b.rarity).rank
			if ra ~= rb then
				return ra > rb
			end
		elseif key == "Type" then
			if KIND_ORDER[a.kind] ~= KIND_ORDER[b.kind] then
				return KIND_ORDER[a.kind] < KIND_ORDER[b.kind]
			end
		elseif key == "Value" then
			if a.value * x.count ~= b.value * y.count then
				return a.value * x.count > b.value * y.count
			end
		elseif key == "Weight" then
			if a.weight * x.count ~= b.weight * y.count then
				return a.weight * x.count > b.weight * y.count
			end
		end
		return a.name < b.name
	end)
	local slots = {}
	for i = 1, #state.slots do
		slots[i] = items[i] or false
	end
	state.slots = slots
	return state
end

local function firstEmpty(slots): number?
	for i, e in slots do
		if not e then
			return i
		end
	end
	return nil
end

-- props: columns, slotSize, width
function Inventory.new(scope: any, props: { [string]: any }?)
	local p = props or {}
	local cols = p.columns or 8
	local slotSize = p.slotSize or 62
	local gap = 6
	local store = Store.new(Inventory.exampleState())
	scope:add(store)
	local gridW = cols * slotSize + (cols - 1) * gap
	local width = gridW + 2 * 22 + 4

	local panel, content = Surface.panel({ title = "Satchel", size = UDim2.fromOffset(width, 0), autoSize = Enum.AutomaticSize.Y, padding = 18 })
	scope:add(panel)
	Create.list("y", 10, Enum.HorizontalAlignment.Center).Parent = content

	-- toolbar: categories + search
	local bar = Create.box({ Name = "Toolbar", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Parent = content }, { Create.list("x", 10, nil, Enum.VerticalAlignment.Center) })
	local cats = Create.box({ Name = "Categories", Size = UDim2.fromOffset(#Inventory.categories * 38 + (#Inventory.categories - 1) * 4, 40), LayoutOrder = 1, Parent = bar }, { Create.list("x", 4, nil, Enum.VerticalAlignment.Center) })
	local catButtons = {}
	for i, cat in Inventory.categories do
		local b = Controls.iconButton(scope, { icon = cat.glyph, size = 38, layoutOrder = i, onClick = function()
			store:set({ filter = cat.id, picked = Store.NONE })
		end })
		b.Instance.Parent = cats
		catButtons[cat.id] = b
		Feedback.tooltip(scope, b.Instance, function()
			return Feedback.tooltipCard({ title = cat.name, width = 150 })
		end, { side = "above" })
	end
	local search = Controls.search(scope, { placeholder = "Search…", layoutOrder = 2, changed = function(t)
		store:set({ query = t, picked = Store.NONE })
	end })
	search.Instance.Parent = bar
	Create.flex().Parent = search.Instance

	-- status line + sort
	local status = Create.box({ Name = "Status", Size = UDim2.new(1, 0, 0, Theme.size.control), LayoutOrder = 2, Parent = content })
	local statusText = Surface.text({ role = "small", text = "", color = C.textSoft, Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), rich = true, Parent = status })
	local sortDrop = Controls.dropdown(scope, {
		width = 190,
		label = "Sort by…",
		options = {
			{ text = "Rarity", icon = "star" },
			{ text = "Type", icon = "filter" },
			{ text = "Name", icon = "sort" },
			{ text = "Value", icon = "coin" },
			{ text = "Weight", icon = "bag" },
		},
		changed = function(i)
			local st = Store.copy(store:get())
			Inventory.sort(st, Inventory.sorts[i])
			st.sortIndex = i
			st.picked = Store.NONE
			store:set(st)
		end,
	})
	sortDrop.Instance.AnchorPoint = Vector2.new(1, 0.5)
	sortDrop.Instance.Position = UDim2.fromScale(1, 0.5)
	sortDrop.Instance.Parent = status

	-- grid
	local gridHolder = Create.box({ Name = "Grid", Size = UDim2.fromOffset(gridW, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = content }, {
		Create.new("UIGridLayout", { CellSize = UDim2.fromOffset(slotSize, slotSize), CellPadding = UDim2.fromOffset(gap, gap), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local drag = DragDrop.new(scope)
	local cells = {}
	local capacity = #store:get().slots

	local function compareFor(it): any?
		if not it.slot then
			return nil
		end
		local eq = store:get().equipped[it.slot]
		if eq and eq ~= it.id then
			return Items.get(eq)
		end
		return nil
	end

	local function toast(tone, title, text, icon)
		Feedback.toast(scope, { tone = tone, title = title, text = text, icon = icon, duration = 3 })
	end

	local function openMenu(index: number)
		local st = store:get()
		local e = st.slots[index]
		if not e then
			return
		end
		local it = Items.get(e.id)
		local menuItems = {}
		if it.kind == "consumable" then
			table.insert(menuItems, { text = "Use", icon = "heart", hint = "E", run = function()
				local s2 = Store.copy(store:get())
				local cur = s2.slots[index]
				s2.slots[index] = if cur.count > 1 then { id = cur.id, count = cur.count - 1 } else false
				store:set({ slots = s2.slots })
				toast("success", `Used {it.name}`, it.effect, it.icon)
			end })
		end
		if it.slot then
			local isEq = st.equipped[it.slot] == it.id
			table.insert(menuItems, { text = if isEq then "Equipped" else "Equip", icon = "shield_small", disabled = isEq, run = function()
				local s2 = Store.copy(store:get())
				local prev = s2.equipped[it.slot]
				s2.equipped[it.slot] = it.id
				s2.slots[index] = if prev then { id = prev, count = 1 } else false
				store:set({ slots = s2.slots, equipped = s2.equipped })
				toast("info", `Equipped {it.name}`, if prev then `{Items.get(prev).name} moved to the satchel.` else nil, it.icon)
			end })
		end
		if e.count > 1 then
			table.insert(menuItems, { text = "Split stack", icon = "swap", disabled = firstEmpty(st.slots) == nil, run = function()
				local s2 = Store.copy(store:get())
				local to = firstEmpty(s2.slots)
				if not to then
					return
				end
				local half = math.floor(e.count / 2)
				s2.slots[index] = { id = e.id, count = e.count - half }
				s2.slots[to] = { id = e.id, count = half }
				store:set({ slots = s2.slots })
			end })
		end
		local junk = st.junk[index] == true
		table.insert(menuItems, { text = if junk then "Unmark junk" else "Mark as junk", icon = "coin", disabled = it.kind == "quest", run = function()
			local j = table.clone(store:get().junk)
			j[index] = not junk or nil
			store:set({ junk = j })
		end })
		table.insert(menuItems, "-")
		table.insert(menuItems, { text = "Discard…", icon = "trash", danger = true, disabled = it.kind == "quest", run = function()
			Feedback.modal(scope, {
				title = "Discard item",
				icon = it.icon,
				glow = Theme.rarityOf(it.rarity).color,
				tone = "danger",
				body = `Discard <b>{it.name}</b>{if e.count > 1 then ` ×{e.count}` else ""}? It will be gone for good.`,
				confirm = { text = "Discard", variant = "danger" },
				cancel = { text = "Keep" },
				onConfirm = function()
					local s2 = Store.copy(store:get())
					s2.slots[index] = false
					store:set({ slots = s2.slots })
					toast("warning", "Item discarded", it.name, it.icon)
				end,
			})
		end })
		local mouse = UserInputService:GetMouseLocation()
		local cell = cells[index]
		local at = if cell then Layers.toLocal(Vector2.new(mouse.X, mouse.Y)) else Vector2.new(20, 20)
		Feedback.contextMenu(scope, at, menuItems, it.name)
	end

	-- Each cell is bound to a display position; render() maps it to an underlying slot index.
	for c = 1, capacity do
		local cell: any = { index = nil :: number? }
		local slot = Slot.new(scope, { size = slotSize, layoutOrder = c, onClick = function()
			local st = store:get()
			local i = cell.index
			if not i then
				return
			end
			if st.picked == nil then
				if st.slots[i] then
					store:set({ picked = i })
				end
			elseif st.picked == i then
				store:set({ picked = Store.NONE })
			else
				local s2 = Store.copy(st)
				Inventory.move(s2, st.picked, i)
				s2.picked = Store.NONE
				store:set(s2)
				cell.slot:pop()
			end
		end })
		slot.Instance.Name = `Cell{c}`
		slot.Instance.Parent = gridHolder
		cell.slot = slot
		cells[c] = cell
		-- drag source
		drag:bindSource(scope, slot.Instance, function()
			local i = cell.index
			if i and store:get().slots[i] then
				return { from = i }
			end
			return nil
		end, function()
			local it = slot.getItem()
			local g = Create.box({ Size = UDim2.fromOffset(slotSize, slotSize) })
			Atlas.image("chrome", "glow", { Size = UDim2.fromScale(1.3, 1.3), Position = UDim2.fromScale(-0.15, -0.15), ImageColor3 = Theme.rarityOf(it.rarity).color, ImageTransparency = 0.35, Parent = g })
			Atlas.image("icon", it.icon, { Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.05, 0.05), Parent = g })
			return g
		end, {
			onStart = function()
				Feedback.hideTooltips()
				slot:set({ lifted = true })
				store:set({ picked = Store.NONE })
			end,
			onEnd = function()
				slot:set({ lifted = false })
			end,
		})
		-- drop target
		drag:addTarget({
			gui = slot.Instance,
			accepts = function(payload)
				return cell.index ~= nil and cell.index ~= payload.from
			end,
			highlight = function(state)
				-- false, not nil: nil keys vanish from the patch table
				slot:set({ drop = state or false })
			end,
			drop = function(payload)
				local s2 = Store.copy(store:get())
				Inventory.move(s2, payload.from, cell.index)
				store:set(s2)
				slot:pop()
			end,
		})
		-- tooltip with comparison
		cell.tip = Feedback.tooltip(scope, slot.Instance, function()
			local i = cell.index
			local e = i and store:get().slots[i]
			if not e or drag:isDragging() then
				return Create.box({ Size = UDim2.fromOffset(1, 1) })
			end
			local it = Items.get(e.id)
			return ItemCard.new(it, { compare = compareFor(it), count = e.count })
		end)
		scope:connect(slot.Instance.MouseButton2Click, function()
			if cell.index then
				openMenu(cell.index)
			end
		end)
	end

	-- footer: capacity, weight, gold
	local foot = Create.box({ Name = "Footer", Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 4, Parent = content })
	local capBar = Feedback.bar(scope, { width = 170, height = 12, max = capacity, value = 0, color = C.gold })
	capBar.Instance.Position = UDim2.fromOffset(0, 11)
	capBar.Instance.Parent = foot
	local capText = Surface.text({ role = "number", text = "", size = 13, color = C.textSoft, Position = UDim2.fromOffset(180, 8), Parent = foot })
	local weightText = Surface.text({ role = "small", text = "", color = C.textFaint, Position = UDim2.fromOffset(270, 8), Parent = foot })
	local gold = Feedback.currency(scope, { amount = store:get().gold, size = 16 })
	gold.Instance.AnchorPoint = Vector2.new(1, 0)
	gold.Instance.Position = UDim2.new(1, 0, 0, 4)
	gold.Instance.Parent = foot

	local function render(st)
		for id, b in catButtons do
			b.controller:set({ selected = st.filter == id })
		end
		local view = Inventory.view(st)
		local isFiltered = filtered(st)
		for c, cell in cells do
			local i = view[c]
			cell.index = i
			local e = i and st.slots[i]
			if e then
				cell.slot:setItem(Items.get(e.id), e.count)
			else
				cell.slot:setItem(nil)
			end
			local it = if e then Items.get(e.id) else nil
			cell.slot:set({
				selected = i ~= nil and st.picked == i,
				dim = (isFiltered and i == nil) or (i ~= nil and st.junk[i] == true),
				equipped = it ~= nil and it.slot ~= nil and st.equipped[it.slot] == it.id,
			})
			cell.slot.Instance.Selectable = i ~= nil
		end
		local used, weight = 0, 0
		for _, e in st.slots do
			if e then
				used += 1
				weight += Items.get(e.id).weight * e.count
			end
		end
		capBar:set(used)
		capText.Text = `{used} / {capacity}`
		weightText.Text = string.format("%.1f lb", weight)
		if isFiltered then
			local n = 0
			for _, i in view do
				if st.slots[i] then
					n += 1
				end
			end
			local cat = "items"
			for _, cc in Inventory.categories do
				if cc.id == st.filter and cc.id ~= "all" then
					cat = string.lower(cc.name)
				end
			end
			statusText.Text = `<font color="#F3D08A"><b>{n}</b></font> {cat}{if st.query ~= "" then ` matching “{st.query}”` else ""}`
		else
			statusText.Text = if st.picked then `Moving <font color="#F3D08A">{Items.get(st.slots[st.picked].id).name}</font> — choose a slot` else `<b>{used}</b> items · drag to rearrange`
		end
		sortDrop:set(st.sortIndex)
	end
	scope:add(store:subscribe(function(st)
		render(st)
	end))
	render(store:get())
	scope:connect(UserInputService.InputBegan, function(input)
		if input.KeyCode == Enum.KeyCode.Escape and store:get().picked then
			store:set({ picked = Store.NONE })
		end
	end)

	return {
		Instance = panel,
		store = store,
		drag = drag,
		cells = cells,
		search = search,
		reset = function()
			search:set("")
			store:reset()
		end,
		openMenu = openMenu,
		gold = gold,
	}
end

return Inventory
