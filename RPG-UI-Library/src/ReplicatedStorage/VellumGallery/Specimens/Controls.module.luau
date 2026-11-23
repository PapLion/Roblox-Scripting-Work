--!strict
-- Buttons & Controls specimens.
local Lib = require(script.Parent.Parent.Lib)
local Theme = require(Lib.Theme)
local Create = require(Lib.Core.Create)
local Button = require(Lib.Components.Button)
local Controls = require(Lib.Components.Controls)
local Surface = require(Lib.Components.Surface)

local C = Theme.color

local function row(parent: Instance, order: number, h: number?, gap: number?): Frame
	return Create.box({ Size = UDim2.new(1, 0, 0, h or 40), LayoutOrder = order, Parent = parent }, { Create.list("x", gap or 14, nil, Enum.VerticalAlignment.Center) })
end

local STATES = {
	{ "Default", nil },
	{ "Hover", { hover = true } },
	{ "Pressed", { pressed = true, hover = true } },
	{ "Focused", { focused = true } },
	{ "Selected", { selected = true } },
	{ "Disabled", { disabled = true } },
	{ "Loading", { loading = true } },
}

return {
	{
		id = "buttons",
		family = "controls",
		title = "Button variants × states",
		blurb = "Gilded primary, leather secondary, ghost, danger and arcane buttons in every interaction state.",
		size = Vector2.new(1180, 400),
		build = function(scope, parent)
			local grid = Create.box({ Size = UDim2.fromScale(1, 1), Parent = parent }, { Create.list("y", 14) })
			-- column header
			local head = row(grid, 0, 18, 14)
			Create.box({ Size = UDim2.fromOffset(104, 18), LayoutOrder = 0, Parent = head })
			for i, st in STATES do
				Surface.text({ role = "caps", text = st[1], color = C.textFaint, Size = UDim2.fromOffset(140, 18), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = i, Parent = head })
			end
			local handles = {}
			for r, variant in { "primary", "secondary", "ghost", "danger", "arcane" } do
				local line = row(grid, r, 52, 14)
				Surface.text({ role = "caps", text = variant, color = C.gold, Size = UDim2.fromOffset(104, 40), LayoutOrder = 0, Parent = line })
				for i, st in STATES do
					local cell = Create.box({ Size = UDim2.fromOffset(140, 52), LayoutOrder = i, Parent = line })
					local label = if variant == "danger" then "Abandon" elseif variant == "arcane" then "Enchant" elseif variant == "ghost" then "Details" elseif variant == "secondary" then "Inspect" else "Embark"
					local b = Button.new(scope, {
						text = label,
						variant = variant :: any,
						width = 132,
						icon = if variant == "primary" then "sword_small" elseif variant == "arcane" then "sparkle" elseif variant == "danger" then "trash" else nil,
						parent = cell,
					})
					b.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
					b.Instance.Position = UDim2.fromScale(0.5, 0.5)
					if st[2] then
						b:force(st[2])
					end
					table.insert(handles, b)
				end
			end
			-- sizes + key hint row
			local sizes = row(grid, 9, 56, 18)
			Surface.text({ role = "caps", text = "sizes", color = C.gold, Size = UDim2.fromOffset(104, 40), LayoutOrder = 0, Parent = sizes })
			Button.new(scope, { text = "Small", size = "small", variant = "secondary", parent = sizes, layoutOrder = 1 })
			Button.new(scope, { text = "Medium", size = "medium", variant = "secondary", parent = sizes, layoutOrder = 2 })
			Button.new(scope, { text = "Large action", size = "large", variant = "primary", icon = "crown", parent = sizes, layoutOrder = 3 })
			Button.new(scope, { text = "Confirm", variant = "primary", keyHint = "Enter", parent = sizes, layoutOrder = 4 })
			Button.new(scope, { text = "Back", variant = "ghost", keyHint = "Bksp", parent = sizes, layoutOrder = 5 })
			return {
				actions = {
					{ label = "Live input", run = function()
						for _, h in handles do
							h:force(nil)
						end
					end },
				},
			}
		end,
	},
	{
		id = "controls",
		family = "controls",
		title = "Controls",
		blurb = "Icon buttons, toggles, checkboxes, radios, segmented control, slider, dropdown and search, with their states.",
		size = Vector2.new(980, 430),
		build = function(scope, parent)
			local cols = Create.box({ Size = UDim2.fromScale(1, 1), Parent = parent }, { Create.list("x", 28) })
			local function column(order: number, w: number, title: string): Frame
				local _, content = Surface.panel({ title = title, size = UDim2.fromOffset(w, 430), parent = cols, padding = 16 })
				content.Parent.LayoutOrder = order
				Create.list("y", 12).Parent = content
				return content
			end
			-- column 1: icon buttons + selection controls
			local a = column(1, 300, "Selection")
			Surface.caption("Icon buttons", { LayoutOrder = 1, Parent = a })
			local ib = row(a, 2, 50, 10)
			Controls.iconButton(scope, { icon = "bag", badge = 3, layoutOrder = 1 }).Instance.Parent = ib
			local h = Controls.iconButton(scope, { icon = "scroll_small", layoutOrder = 2 })
			h.Instance.Parent = ib
			h:force({ hover = true })
			Controls.iconButton(scope, { icon = "gear", selected = true, layoutOrder = 3 }).Instance.Parent = ib
			Controls.iconButton(scope, { icon = "lock", disabled = true, layoutOrder = 4 }).Instance.Parent = ib
			Surface.caption("Toggles", { LayoutOrder = 3, Parent = a })
			Controls.toggle(scope, { label = "Show damage numbers", value = true, layoutOrder = 4 }).Instance.Parent = a
			Controls.toggle(scope, { label = "Auto-loot", value = false, layoutOrder = 5 }).Instance.Parent = a
			Controls.toggle(scope, { label = "Hardcore (locked)", value = false, disabled = true, layoutOrder = 6 }).Instance.Parent = a
			Surface.caption("Checks & radios", { LayoutOrder = 7, Parent = a })
			Controls.checkbox(scope, { label = "Track quest", value = true, layoutOrder = 8 }).Instance.Parent = a
			local grp = {}
			local rr = row(a, 9, 28, 18)
			Controls.checkbox(scope, { label = "Melee", radio = true, value = true, group = grp, layoutOrder = 1 }).Instance.Parent = rr
			Controls.checkbox(scope, { label = "Ranged", radio = true, group = grp, layoutOrder = 2 }).Instance.Parent = rr

			-- column 2: value controls
			local b = column(2, 300, "Values")
			Surface.caption("Segmented", { LayoutOrder = 1, Parent = b })
			Controls.segmented(scope, { options = { "Easy", "Normal", "Heroic" }, index = 2, width = 268, layoutOrder = 2 }).Instance.Parent = b
			Surface.caption("Sliders", { LayoutOrder = 3, Parent = b })
			Controls.slider(scope, { label = "Music", value = 70, format = function(v)
				return v .. "%"
			end, layoutOrder = 4 }).Instance.Parent = b
			local sf = Controls.slider(scope, { label = "Field of view", min = 60, max = 110, step = 5, value = 85, format = function(v)
				return v .. "°"
			end, layoutOrder = 5 })
			sf.Instance.Parent = b
			sf.controller:force({ focused = true })
			Controls.slider(scope, { label = "Locked", value = 30, disabled = true, layoutOrder = 6 }).Instance.Parent = b

			-- column 3: dropdown + search
			local c = column(3, 324, "Choices")
			Surface.caption("Dropdown", { LayoutOrder = 1, Parent = c })
			local dd = Controls.dropdown(scope, { width = 290, index = 2, options = { { text = "Common", icon = "star_outline" }, { text = "Rare and above", icon = "star" }, { text = "Legendary only", icon = "crown" } }, layoutOrder = 2 })
			dd.Instance.Parent = c
			Controls.dropdown(scope, { width = 290, label = "Choose a class…", options = { "Warden", "Arcanist", "Ranger" }, layoutOrder = 3 }).Instance.Parent = c
			Controls.dropdown(scope, { width = 290, label = "Region (locked)", options = { "—" }, disabled = true, layoutOrder = 4 }).Instance.Parent = c
			Surface.caption("Search", { LayoutOrder = 5, Parent = c })
			Controls.search(scope, { placeholder = "Search the satchel…", layoutOrder = 6 }).Instance.Parent = c
			local s2 = Controls.search(scope, { layoutOrder = 7 })
			s2.Instance.Parent = c
			s2:set("moonpetal")
			return {
				actions = {
					{ label = "Open dropdown", run = function()
						dd.open()
					end },
				},
			}
		end,
	},
}
