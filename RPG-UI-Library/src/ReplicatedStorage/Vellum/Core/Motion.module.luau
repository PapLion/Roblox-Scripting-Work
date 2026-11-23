--!strict
-- Motion: tween helpers. One running tween per (instance, channel): starting a new one cancels the old,
-- so rapid hover/press never stacks tweens. Honours a global reduced-motion switch.
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Parent.Theme)

local Motion = {}
Motion.reduced = false
-- Paused: per-frame animations (pulses, rays, spinners, timers) hold still. Used by tiled captures so
-- every tile shows the same instant.
Motion.paused = false

local running: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any

function Motion.tween(inst: Instance, props: { [string]: any }, duration: number?, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, channel: string?): Tween
	local ch = channel or "default"
	local byInst = running[inst]
	if not byInst then
		byInst = {}
		running[inst] = byInst
	end
	local old = byInst[ch]
	if old then
		old:Cancel()
	end
	local d = if Motion.reduced then 0 else (duration or Theme.motion.base)
	local tw = TweenService:Create(inst, TweenInfo.new(d, style or Theme.motion.ease, dir or Enum.EasingDirection.Out), props)
	byInst[ch] = tw
	tw.Completed:Once(function()
		if byInst[ch] == tw then
			byInst[ch] = nil
		end
		tw:Destroy()
	end)
	tw:Play()
	return tw
end

-- Animate a number from a to b, calling fn(value) every frame. Returns a cancel function.
function Motion.number(from: number, to: number, duration: number, fn: (number) -> (), style: Enum.EasingStyle?): () -> ()
	local holder = Instance.new("NumberValue")
	holder.Value = from
	local conn = holder.Changed:Connect(fn)
	fn(from)
	local tw = Motion.tween(holder, { Value = to }, duration, style)
	local done = false
	local function cancel()
		if done then
			return
		end
		done = true
		conn:Disconnect()
		tw:Cancel()
		holder:Destroy()
	end
	tw.Completed:Once(function()
		fn(to)
		cancel()
	end)
	return cancel
end

-- Short punch: scale up then settle (needs a UIScale child).
function Motion.pop(scale: UIScale, amount: number?)
	scale.Scale = 1 + (amount or 0.08)
	Motion.tween(scale, { Scale = 1 }, Theme.motion.slow, Enum.EasingStyle.Back)
end

-- Horizontal shake used for refusals (insufficient gold, locked node...).
function Motion.shake(gui: GuiObject)
	if Motion.reduced then
		return
	end
	local base = gui.Position
	task.spawn(function()
		for _, dx in { 7, -6, 4, -3, 1, 0 } do
			gui.Position = base + UDim2.fromOffset(dx, 0)
			task.wait(0.035)
		end
		gui.Position = base
	end)
end

return Motion
