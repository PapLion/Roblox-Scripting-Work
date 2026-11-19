-- Small helpers shared by every module: cleanup scopes, signals, tweens and number formatting.
local TweenService = game:GetService("TweenService")

local Util = {}

-- Set by the settings (Accessibility > Reduced motion). Tweens become instant changes.
Util.reducedMotion = false

---------------------------------------------------------------- Scope
-- A scope owns connections, threads, instances and callbacks and releases them in reverse order.
-- Every screen gets one; leaving the screen cleans it, so nothing keeps listening in the background.
local Scope = {}
Scope.__index = Scope

function Util.scope()
	return setmetatable({ items = {}, alive = true }, Scope)
end

function Scope:add(item)
	if not self.alive then
		-- Adding to a dead scope releases the item straight away (late callbacks after a screen change).
		local tmp = Util.scope()
		tmp:add(item)
		tmp:clean()
		return item
	end
	table.insert(self.items, item)
	return item
end

function Scope:connect(signal, fn)
	return self:add(signal:Connect(fn))
end

function Scope:delay(seconds, fn, ...)
	return self:add(task.delay(seconds, fn, ...))
end

function Scope:spawn(fn, ...)
	return self:add(task.spawn(fn, ...))
end

function Scope:child()
	local s = Util.scope()
	self:add(s)
	return s
end

local function release(item)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" and item ~= coroutine.running() then
			pcall(task.cancel, item)
		end
	elseif kind == "Instance" then
		if item:IsA("Tween") then
			item:Cancel()
		end
		item:Destroy()
	elseif kind == "function" then
		local ok, err = pcall(item)
		if not ok then
			warn("[PIVOT] cleanup error:", err)
		end
	elseif kind == "table" then
		if item.clean then
			item:clean()
		elseif item.Disconnect then
			item:Disconnect()
		end
	end
end

function Scope:clean()
	local items = self.items
	self.items = {}
	for i = #items, 1, -1 do
		release(items[i])
	end
end

function Scope:destroy()
	self:clean()
	self.alive = false
end

---------------------------------------------------------------- Signal
-- Synchronous signal: handlers run in connection order, an error in one does not stop the rest.
function Util.signal()
	local handlers = {}
	local signal = {}
	function signal:Connect(fn)
		local handle = { fn = fn, Connected = true }
		table.insert(handlers, handle)
		function handle:Disconnect()
			if not handle.Connected then
				return
			end
			handle.Connected = false
			local i = table.find(handlers, handle)
			if i then
				table.remove(handlers, i)
			end
		end
		return handle
	end
	function signal:Fire(...)
		for _, handle in table.clone(handlers) do
			if handle.Connected then
				local ok, err = pcall(handle.fn, ...)
				if not ok then
					warn("[PIVOT] handler error:", err)
				end
			end
		end
	end
	function signal:count()
		return #handlers
	end
	return signal
end

---------------------------------------------------------------- Tweens
function Util.tween(inst: Instance, seconds: number, props, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	if Util.reducedMotion or seconds <= 0 then
		for k, v in props do
			(inst :: any)[k] = v
		end
		return nil
	end
	local tw = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Animates a number shown in a TextLabel (credits, XP) from its previous value.
function Util.countTo(label: TextLabel, from: number, to: number, seconds: number, format)
	format = format or Util.num
	if Util.reducedMotion or from == to then
		label.Text = format(to)
		return nil
	end
	return task.spawn(function()
		local t0 = os.clock()
		while label.Parent do
			local p = math.min(1, (os.clock() - t0) / seconds)
			local e = 1 - (1 - p) ^ 3
			label.Text = format(math.round(from + (to - from) * e))
			if p >= 1 then
				break
			end
			task.wait()
		end
	end)
end

---------------------------------------------------------------- Formatting
-- Spanish grouping: 3.200 · 1.000.000
function Util.num(n: number): string
	local neg = n < 0
	local s = tostring(math.floor(math.abs(n) + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return (neg and "-" or "") .. out
end

function Util.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Util.plural(n: number, one: string, many: string): string
	return (n == 1 and one or many):gsub("{n}", Util.num(n))
end

-- Replaces {key} with values from vars.
function Util.fmt(text: string, vars): string
	return (text:gsub("{(%w+)}", function(k)
		local v = vars[k]
		if v == nil then
			return "{" .. k .. "}"
		end
		return tostring(v)
	end))
end

---------------------------------------------------------------- Tables
function Util.deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = Util.deepCopy(v)
	end
	return out
end

function Util.equal(a, b): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not Util.equal(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- Seeded generator so a simulated match plays the same way every time (mulberry32).
function Util.rng(seed: number)
	local s = seed % 4294967296
	return function(): number
		s = (s + 0x6D2B79F5) % 4294967296
		local t = s
		t = bit32.bxor(t, bit32.rshift(t, 15))
		t = (t * bit32.bor(t, 1)) % 4294967296
		local u = bit32.bxor(t, bit32.rshift(t, 7))
		t = bit32.bxor(t, (t + (u * bit32.bor(t, 61)) % 4294967296) % 4294967296)
		return bit32.bxor(t, bit32.rshift(t, 14)) / 4294967296
	end
end

return Util
