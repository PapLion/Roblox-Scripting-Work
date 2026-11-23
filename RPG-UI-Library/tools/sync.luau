--!strict
-- Live sync for development: applies src/ (served by `python tools/build_place.py --serve`) to the open place.
-- Run from the Studio command bar or a plugin context. Creates or updates every script, removes scripts and
-- folders under the managed roots that no longer exist in src/. Prints a summary.
local HttpService = game:GetService("HttpService")
local PORT = 34873

local ok, body = pcall(function()
	return HttpService:GetAsync(`http://127.0.0.1:{PORT}/manifest.json`, true)
end)
if not ok then
	error(`sync: manifest unreachable ({body}). Start: python tools/build_place.py --serve`)
end
local manifest = HttpService:JSONDecode(body)

local function resolve(path: string, create: boolean, class: string?): Instance?
	local parts = string.split(path, "/")
	local node: Instance = game:GetService(parts[1] :: any)
	for i = 2, #parts do
		local child = node:FindFirstChild(parts[i])
		if not child then
			if not create then
				return nil
			end
			child = Instance.new(if i == #parts then (class :: string) else "Folder")
			child.Name = parts[i]
			child.Parent = node
		end
		node = child :: Instance
	end
	return node
end

local wanted: { [string]: boolean } = {}
local created, updated, same = 0, 0, 0
for _, e in manifest.entries do
	wanted[e.path] = true
	local inst = resolve(e.path, false)
	-- containers (services, StarterPlayerScripts, folders) are kept whatever their class
	if inst and e.class ~= "Folder" and inst.ClassName ~= e.class then
		inst:Destroy()
		inst = nil
	end
	if not inst then
		inst = resolve(e.path, true, e.class)
		created += 1
	end
	if e.source then
		local s = inst :: any
		if s.Source ~= e.source then
			s.Source = e.source
			if created == 0 or s.Source ~= "" then
				updated += 1
			end
		else
			same += 1
		end
	end
end

local removed = 0
for _, root in manifest.managed do
	local base = resolve(root, false)
	if base then
		local prefix = root
		local function prune(node: Instance, path: string)
			for _, child in node:GetChildren() do
				local p = path .. "/" .. child.Name
				if not wanted[p] then
					child:Destroy()
					removed += 1
				else
					prune(child, p)
				end
			end
		end
		prune(base, prefix)
	end
end
print(`sync {manifest.hash}: {created} created, {updated} updated, {same} unchanged, {removed} removed`)
return manifest.hash
