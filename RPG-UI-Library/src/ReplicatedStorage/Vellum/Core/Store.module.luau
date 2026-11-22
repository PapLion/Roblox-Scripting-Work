--!strict
-- Store: predictable local state for a widget. One table, immutable-style updates, subscribers called
-- after each commit with (state, previous). Widgets render from state; user input only calls actions.
local Signal = require(script.Parent.Signal)

export type Store<S> = {
	get: (self: Store<S>) -> S,
	set: (self: Store<S>, patch: { [string]: any }) -> (),
	update: (self: Store<S>, fn: (S) -> S) -> (),
	subscribe: (self: Store<S>, fn: (S, S) -> ()) -> { Disconnect: (any) -> () },
	reset: (self: Store<S>) -> (),
	Destroy: (self: Store<S>) -> (),
}

local Store = {}
Store.__index = Store

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in v do
		t[k] = deepCopy(x)
	end
	return t
end
Store.copy = deepCopy

function Store.new<S>(initial: S): Store<S>
	local self = setmetatable({
		_initial = deepCopy(initial),
		_state = deepCopy(initial),
		_changed = Signal.new(),
	}, Store)
	return self :: any
end

function Store:get()
	return self._state
end

function Store:_commit(nextState)
	local prev = self._state
	self._state = nextState
	self._changed:Fire(nextState, prev)
end

function Store:set(patch)
	local nextState = table.clone(self._state)
	for k, v in patch do
		nextState[k] = v
	end
	self:_commit(nextState)
end

function Store:update(fn)
	self:_commit(fn(table.clone(self._state)))
end

function Store:subscribe(fn)
	return self._changed:Connect(fn)
end

function Store:reset()
	self:_commit(deepCopy(self._initial))
end

function Store:Destroy()
	self._changed:Destroy()
end

return Store
