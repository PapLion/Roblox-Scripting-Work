--!strict
-- Scope: owns everything a component creates (connections, instances, tweens, threads, child scopes)
-- and releases it all with one :Destroy(). Every component gets one; the gallery destroys the
-- specimen's scope when it switches, so nothing leaks between specimens.

export type Scope = {
	add: <T>(self: Scope, item: T) -> T,
	connect: (self: Scope, signal: RBXScriptSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	child: (self: Scope) -> Scope,
	defer: (self: Scope, fn: () -> ()) -> (),
	delay: (self: Scope, t: number, fn: () -> ()) -> thread,
	Destroy: (self: Scope) -> (),
	alive: boolean,
}

local Scope = {}
Scope.__index = Scope

local live = 0 -- diagnostic: number of scopes alive (read by the gallery's leak check)

function Scope.new(): Scope
	live += 1
	return setmetatable({ _items = {}, alive = true }, Scope) :: any
end

function Scope.liveCount(): number
	return live
end

local function release(item: any)
	local t = typeof(item)
	if t == "RBXScriptConnection" then
		item:Disconnect()
	elseif t == "Instance" then
		if item:IsA("Tween") then
			item:Cancel()
		end
		item:Destroy()
	elseif t == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
	elseif t == "function" then
		item()
	elseif t == "table" then
		local d = item.Destroy or item.destroy or item.Disconnect
		if d then
			d(item)
		end
	end
end

function Scope:add(item)
	if not self.alive then
		release(item)
		return item
	end
	table.insert(self._items, item)
	return item
end

function Scope:connect(signal, fn)
	return self:add(signal:Connect(fn))
end

function Scope:child()
	local c = Scope.new()
	self:add(c)
	return c
end

function Scope:defer(fn)
	self:add(fn)
end

function Scope:delay(t, fn)
	return self:add(task.delay(t, fn))
end

function Scope:Destroy()
	if not self.alive then
		return
	end
	self.alive = false
	live -= 1
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		release(items[i])
	end
end

return Scope
