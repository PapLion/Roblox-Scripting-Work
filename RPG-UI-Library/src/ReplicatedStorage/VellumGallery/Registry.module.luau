--!strict
-- Registry: every specimen in the gallery, grouped by family. A specimen is a standalone component (or a
-- small family of states) with its natural canvas size, a build function, optional actions to drive its
-- states and a reset (rebuilding from the example data).
export type Action = { label: string, run: () -> () }
export type Built = { actions: { Action }?, onReset: (() -> ())? }
export type Specimen = {
	id: string,
	family: string,
	title: string,
	blurb: string,
	size: Vector2, -- natural canvas size in px (before stage scaling)
	build: (scope: any, parent: Frame, ctx: { [string]: any }) -> Built?,
}

local Registry = {}

Registry.families = {
	{ id = "controls", title = "Buttons & Controls" },
	{ id = "inventory", title = "Inventory" },
	{ id = "character", title = "Character & Equipment" },
	{ id = "skills", title = "Skills & Abilities" },
	{ id = "quests", title = "Quests & Progression" },
	{ id = "commerce", title = "Crafting & Commerce" },
	{ id = "feedback", title = "Feedback & Overlays" },
}

local list: { Specimen } = {}
local byId: { [string]: Specimen } = {}

for _, m in script.Parent.Specimens:GetChildren() do
	if m:IsA("ModuleScript") then
		for _, s in require(m) :: { Specimen } do
			assert(not byId[s.id], "duplicate specimen " .. s.id)
			byId[s.id] = s
			table.insert(list, s);
			(s :: any).order = #list
		end
	end
end

local famIndex = {}
for i, f in Registry.families do
	famIndex[f.id] = i
end
table.sort(list, function(a, b)
	local fa, fb = famIndex[a.family] or 99, famIndex[b.family] or 99
	if fa ~= fb then
		return fa < fb
	end
	return (a :: any).order < (b :: any).order
end)

Registry.list = list
function Registry.get(id: string): Specimen?
	return byId[id]
end
function Registry.inFamily(fid: string): { Specimen }
	local out = {}
	for _, s in list do
		if s.family == fid then
			table.insert(out, s)
		end
	end
	return out
end

return Registry
