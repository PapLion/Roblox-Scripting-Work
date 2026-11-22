--!strict
-- Interact: one state machine for every pressable control. Tracks hover, press, keyboard focus,
-- selected, disabled and loading, and calls render(state) whenever any of them changes. Controls
-- never wire MouseEnter/InputBegan themselves, so behaviour is identical across the library.
--
-- Keyboard: controls are Selectable; GuiService.SelectedObject drives focus. Each control draws its own
-- focus treatment (SelectionImageObject is an empty frame so Roblox's default ring never overlaps).
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

export type State = {
	hover: boolean,
	pressed: boolean,
	focused: boolean,
	selected: boolean,
	disabled: boolean,
	loading: boolean,
}

export type Controller = {
	state: State,
	set: (self: Controller, patch: { [string]: boolean }) -> (),
	-- force a visual state (gallery state boards); nil returns to live input
	force: (self: Controller, patch: { [string]: boolean }?) -> (),
}

local Interact = {}

local emptySelection: Frame? = nil
function Interact.noRing(): Frame
	if not emptySelection then
		local f = Instance.new("Frame")
		f.Name = "VellumNoRing"
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(0, 0)
		emptySelection = f
	end
	return emptySelection :: Frame
end

local function isPointer(input: InputObject)
	local t = input.UserInputType
	return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end

-- button: the GuiButton receiving input. scope: owner. render: called with the effective state.
-- onActivate: called on click / Enter / tap unless disabled or loading.
function Interact.attach(button: GuiButton, scope: any, render: (State) -> (), onActivate: (() -> ())?): Controller
	local live: State = { hover = false, pressed = false, focused = false, selected = false, disabled = false, loading = false }
	local forced: { [string]: boolean }? = nil

	button.AutoButtonColor = false
	button.Selectable = true
	button.SelectionImageObject = Interact.noRing()

	local ctl = {} :: any
	ctl.state = live

	local function effective(): State
		if not forced then
			return live
		end
		local s = table.clone(live)
		for k, v in forced do
			(s :: any)[k] = v
		end
		return s
	end

	local function refresh()
		render(effective())
	end

	function ctl:set(patch)
		for k, v in patch do
			(live :: any)[k] = v
		end
		if live.disabled then
			live.pressed = false
		end
		button.Selectable = not live.disabled
		refresh()
	end

	function ctl:force(patch)
		forced = patch
		refresh()
	end

	scope:connect(button.MouseEnter, function()
		live.hover = true
		refresh()
	end)
	scope:connect(button.MouseLeave, function()
		live.hover = false
		live.pressed = false
		refresh()
	end)
	scope:connect(button.InputBegan, function(input)
		if isPointer(input) and not live.disabled then
			live.pressed = true
			refresh()
		end
	end)
	scope:connect(button.InputEnded, function(input)
		if isPointer(input) and live.pressed then
			live.pressed = false
			refresh()
		end
	end)
	scope:connect(button.SelectionGained, function()
		live.focused = true
		refresh()
	end)
	scope:connect(button.SelectionLost, function()
		live.focused = false
		live.pressed = false
		refresh()
	end)
	-- keyboard press feedback while focused
	scope:connect(UserInputService.InputBegan, function(input)
		if GuiService.SelectedObject == button and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) and not live.disabled then
			live.pressed = true
			refresh()
		end
	end)
	scope:connect(UserInputService.InputEnded, function(input)
		if live.pressed and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) then
			live.pressed = false
			refresh()
		end
	end)
	scope:connect(button.Activated, function()
		if live.disabled or live.loading then
			return
		end
		if onActivate then
			onActivate()
		end
	end)

	refresh()
	return ctl
end

return Interact
