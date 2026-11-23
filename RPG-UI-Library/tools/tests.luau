-- Unit tests for the library's pure logic. Run in Studio (Edit) after a sync:
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:34873/f/tools/tests.luau"))()
-- Uses a fresh copy of the library so require() sees current sources. Returns a summary string.
local RS = game:GetService("ReplicatedStorage")
local old = RS:FindFirstChild("VellumTest")
if old then
	old:Destroy()
end
local lib = RS.Vellum:Clone()
lib.Name = "VellumTest"
lib.Parent = RS

local results, failed = {}, 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		failed += 1
	end
	table.insert(results, (if ok then "ok   " else "FAIL ") .. name .. (if ok then "" else " :: " .. tostring(err)))
end
local function eq(a, b, msg)
	if a ~= b then
		error(`{msg or "expected"}: {tostring(b)}, got {tostring(a)}`, 2)
	end
end

local Store = require(lib.Core.Store)
local Scope = require(lib.Core.Scope)
local Signal = require(lib.Core.Signal)
local Inventory = require(lib.Widgets.Inventory)
local SkillTree = require(lib.Widgets.SkillTree)
local Commerce = require(lib.Widgets.Commerce)
local Recipes = require(lib.Data.Recipes)
local CharData = require(lib.Data.Character)
local Items = require(lib.Data.Items)
local Skills = require(lib.Data.Skills)

test("Store.set patches, NONE removes, reset restores", function()
	local s = Store.new({ a = 1, b = 2 })
	local fired = 0
	s:subscribe(function()
		fired += 1
	end)
	s:set({ a = 5 })
	eq(s:get().a, 5)
	eq(s:get().b, 2)
	s:set({ b = Store.NONE })
	eq(s:get().b, nil, "b removed")
	s:reset()
	eq(s:get().a, 1)
	eq(s:get().b, 2)
	eq(fired, 3, "subscriber calls")
	s:Destroy()
end)

test("Scope releases connections, instances, children, functions", function()
	local before = Scope.liveCount()
	local sc = Scope.new()
	local f = sc:add(Instance.new("Frame"))
	local child = sc:child()
	local ran = false
	child:defer(function()
		ran = true
	end)
	local be = Instance.new("BindableEvent")
	local hits = 0
	sc:connect(be.Event, function()
		hits += 1
	end)
	be:Fire()
	sc:Destroy()
	be:Fire()
	task.wait()
	eq(hits, 1, "connection disconnected")
	eq(f.Parent, nil)
	eq(ran, true, "child scope deferred fn ran")
	eq(Scope.liveCount(), before, "no scopes left alive")
end)

test("Signal listener count returns to zero", function()
	local before = Signal.listenerCount()
	local s = Signal.new()
	local c = s:Connect(function() end)
	s:Connect(function() end)
	c:Disconnect()
	s:Destroy()
	eq(Signal.listenerCount(), before)
end)

test("Inventory.move swaps items and moves into empty slots", function()
	local st = Inventory.exampleState()
	local a, b = st.slots[1], st.slots[2]
	Inventory.move(st, 1, 2)
	eq(st.slots[1].id, b.id)
	eq(st.slots[2].id, a.id)
	Inventory.move(st, 2, 3) -- slot 3 starts empty
	eq(st.slots[2], false)
	eq(st.slots[3].id, a.id)
end)

test("Inventory.move merges stacks up to the stack size", function()
	local st = Inventory.exampleState()
	st.slots[3] = { id = "potion_health", count = 15 } -- slot 4 has 12, stack 20
	Inventory.move(st, 3, 4)
	eq(st.slots[4].count, 20, "target filled to stack size")
	eq(st.slots[3].count, 7, "remainder stays at source")
end)

test("Inventory.view filters by category and search", function()
	local st = Inventory.exampleState()
	st.filter = "weapon"
	for _, i in Inventory.view(st) do
		eq(Items.get(st.slots[i].id).kind, "weapon")
	end
	st.filter = "all"
	st.query = "potion"
	local v = Inventory.view(st)
	eq(#v, 3, "three potions")
	st.query = ""
	eq(#Inventory.view(st), #st.slots, "unfiltered shows every slot")
end)

test("Inventory.sort by rarity puts the rarest first and keeps every item", function()
	local st = Inventory.exampleState()
	local n = 0
	for _, e in st.slots do
		if e then
			n += 1
		end
	end
	Inventory.sort(st, "Rarity")
	local m, last = 0, 99
	for i, e in st.slots do
		if e then
			m += 1
			local r = require(lib.Theme).rarityOf(Items.get(e.id).rarity).rank
			assert(r <= last, "rarity not descending at " .. i)
			last = r
		else
			assert(i > n, "items compacted to the front")
		end
	end
	eq(m, n, "item count preserved")
end)

test("SkillTree: prerequisites and row gates", function()
	local st = SkillTree.exampleState()
	-- Falling Star (row 3) needs Searing Touch (learned) and 3 points above in Emberheart (kindle 1 + searing 2)
	local ok = SkillTree.canLearn(st, Skills.get("meteor"))
	eq(ok, true, "meteor learnable")
	-- Pyre needs meteor
	eq((SkillTree.canLearn(st, Skills.get("pyre"))), false, "pyre locked")
	-- Blizzard: rime not learned
	eq((SkillTree.canLearn(st, Skills.get("blizzard"))), false, "blizzard locked")
end)

test("SkillTree: learn spends a point, unlearn refunds, dependents block", function()
	local st = SkillTree.exampleState()
	local p = st.points
	assert(SkillTree.learn(st, "meteor"), "learn meteor")
	eq(st.points, p - 1)
	eq(st.ranks.meteor, 1)
	-- searing at rank 2 can drop to 1 (meteor needs rank >= 1), but its rows-above gate for meteor needs 3 points
	local okU = SkillTree.canUnlearn(st, Skills.get("searing"))
	eq(okU, false, "gate protects meteor")
	-- kindle has dependents
	eq((SkillTree.canUnlearn(st, Skills.get("kindle"))), false, "kindle has dependents")
	assert(SkillTree.unlearn(st, "meteor"), "unlearn meteor")
	eq(st.points, p)
end)

test("SkillTree: cannot learn without points or past max rank", function()
	local st = SkillTree.exampleState()
	st.points = 0
	eq((SkillTree.canLearn(st, Skills.get("meteor"))), false)
	st.points = 5
	eq((SkillTree.canLearn(st, Skills.get("guard"))), false, "guard maxed at 3/3")
end)

test("Crafting: max craftable and missing materials", function()
	local stock = table.clone(Recipes.stock)
	local function r(id)
		for _, x in Recipes.list do
			if x.id == id then
				return x
			end
		end
		error(id)
	end
	eq(Commerce.maxCraftable(stock, r("r_dawnsteel")), 1, "9 ingots / 6")
	eq(Commerce.maxCraftable(stock, r("r_ingot")), 13, "40 ore / 3")
	eq(Commerce.maxCraftable(stock, r("r_mana")), 0, "no tidestone")
	local miss = Commerce.missing(stock, r("r_plate"), 1)
	eq(#miss, 1)
	eq(miss[1].id, "steel_ingot")
	eq(miss[1].short, 3)
end)

test("Character.derive reacts to gear and attributes", function()
	local ch = CharData.example()
	local base = CharData.derive(ch)
	ch.equipped.mainhand = "galeheart_bow"
	local bow = CharData.derive(ch)
	-- weapon power 58 vs 42, minus the blade's +6 Might (2 power each)
	eq(bow.power - base.power, (58 - 42) - 6 * 2, "power delta from weapon swap")
	ch.attributes.vigor += 2
	eq(CharData.derive(ch).health - bow.health, 30, "+15 health per vigor")
end)

lib:Destroy()
return `{#results - failed}/{#results} passed\n` .. table.concat(results, "\n")
