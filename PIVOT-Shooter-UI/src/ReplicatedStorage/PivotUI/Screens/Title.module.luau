-- Title / cover: the lobby hangar behind a dark gradient, wordmark and the way in.

local UserInputService = game:GetService("UserInputService")

local PivotUI = script.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local Stage = require(PivotUI.Match.Stage)

local C, F = UI.C, UI.F
local Title = {}

function Title.build(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	local phone = UI.isPhone()
	Stage.title()

	-- backdrop: left-to-right darkening so the type always sits on a calm area
	local shade = UI.fill(C.ink950, { Name = "Shade", Parent = ctx.backdrop })
	UI.new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(0.45, 0.35), NumberSequenceKeypoint.new(1, 0.9) }),
		Parent = shade,
	})
	local bottom = UI.fill(C.ink950, { Name = "Bottom", Size = UDim2.fromScale(1, 0.35), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = ctx.backdrop })
	UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.1), Parent = bottom })

	local col = UI.box({ Name = "Hero", Size = UDim2.new(phone and 0.8 or 0.5, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, m.pad * (phone and 1.5 or 3), 0.47, 0), Parent = root })
	UI.list("v", phone and 6 or 12).Parent = col
	local eyebrow = UI.box({ Size = UDim2.new(1, 0, 0, m.small + 6), LayoutOrder = 1, Parent = col })
	UI.list("h", 8).Parent = eyebrow
	UI.icon("logo", m.small + 4, C.signal, { LayoutOrder = 1, Parent = eyebrow })
	UI.label("eyebrow", "Shooter competitivo por equipos", { TextColor3 = C.signal, TextSize = m.small, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = eyebrow })
	-- TextSize is capped at 100 in Roblox, so the wordmark scales to its box instead
	local wordH = math.floor(math.min(root.AbsoluteSize.Y * (phone and 0.26 or 0.27), 210))
	local word = UI.label("h1", "PIVOT", { TextScaled = true, Size = UDim2.new(1, 0, 0, wordH), LayoutOrder = 2, LineHeight = 0.9, Parent = col })
	word.TextTransparency = Util.reducedMotion and 0 or 1
	UI.para("Cuatro contra cuatro en mapas compactos.\nElige equipo, ajusta tu arsenal y gana antes de que se acabe el tiempo.", { LayoutOrder = 3, Size = UDim2.new(phone and 1 or 0.86, 0, 0, 0), TextSize = m.body + (phone and 0 or 1), Parent = col })

	local enterRow = UI.box({ Size = UDim2.new(1, 0, 0, m.btnLg), LayoutOrder = 4, Parent = col })
	UI.pad(phone and 6 or 14, 0, 0, 0).Parent = enterRow
	UI.list("h", m.gap).Parent = enterRow
	local entered = false
	local function enter()
		if entered then
			return
		end
		entered = true
		UI.sfx("confirm")
		Store.dispatch({ type = "ENTER_LOBBY" })
	end
	local btn = UI.button({ text = "Entrar", icon = "play", variant = "primary", size = "lg", order = 1, onClick = enter, sound = "none" })
	btn.inst.Parent = enterRow
	local hint = UI.label("small", UI.touch and "o toca en cualquier parte" or "o pulsa cualquier tecla", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = C.steel, LayoutOrder = 2, Parent = enterRow })

	-- footer: season + build tag
	local foot = UI.box({ Name = "Footer", Size = UDim2.new(1, -2 * m.pad, 0, m.small + 8), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, m.pad, 1, -m.pad), Parent = root })
	UI.label("mono", "Temporada 1: Muelle 9  ·  v1.0.0", { TextSize = m.micro, TextColor3 = C.steel, Parent = foot })

	-- entrance motion
	if not Util.reducedMotion then
		Util.tween(word, 0.6, { TextTransparency = 0 })
		scope:spawn(function()
			while hint.Parent do
				Util.tween(hint, 0.9, { TextTransparency = 0.55 }, Enum.EasingStyle.Sine)
				task.wait(0.9)
				Util.tween(hint, 0.9, { TextTransparency = 0 }, Enum.EasingStyle.Sine)
				task.wait(0.9)
			end
		end)
	end

	scope:connect(UserInputService.InputBegan, function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.Keyboard then
			local k = input.KeyCode
			-- leave Roblox-reserved and navigation keys alone
			if k == Enum.KeyCode.Escape or k == Enum.KeyCode.Backquote or k == Enum.KeyCode.F9 or k == Enum.KeyCode.Tab or k == Enum.KeyCode.Slash then
				return
			end
			enter()
		elseif t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			enter()
		end
	end)
end

return Title
