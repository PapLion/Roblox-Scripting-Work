--!strict
-- Minimal synchronous signal for component events (onChanged, onSelect, ...).
export type Connection = { Disconnect: (self: Connection) -> (), connected: boolean }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

local live = 0
function Signal.listenerCount(): number
	return live
end

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _fns = {} }, Signal) :: any
end

function Signal:Connect(fn)
	local conn
	conn = {
		connected = true,
		Disconnect = function(c)
			if c.connected then
				c.connected = false
				live -= 1
				local i = table.find(self._fns, fn)
				if i then
					table.remove(self._fns, i)
				end
			end
		end,
	}
	live += 1
	table.insert(self._fns, fn)
	return conn
end

function Signal:Fire(...)
	for _, fn in table.clone(self._fns) do
		fn(...)
	end
end

function Signal:Destroy()
	live -= #self._fns
	table.clear(self._fns)
end

return Signal
