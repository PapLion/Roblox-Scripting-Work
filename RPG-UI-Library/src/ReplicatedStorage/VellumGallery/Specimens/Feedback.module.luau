--!strict
-- Feedback & Overlays specimens.
local Lib = require(script.Parent.Parent.Lib)
local Theme = require(Lib.Theme)
local Create = require(Lib.Core.Create)
local Layers = require(Lib.Core.Layers)
local Surface = require(Lib.Components.Surface)
local Feedback = require(Lib.Components.Feedback)
local Button = require(Lib.Components.Button)
local Progression = require(Lib.Widgets.Progression)

local C = Theme.color

return {
	{
		id = "toasts",
		family = "feedback",
		title = "Toast notifications",
		blurb = "Reward, quest, success, info, warning and error toasts with item badges and a draining timer; live toasts stack and expire.",
		size = Vector2.new(360, 456),
		build = function(scope, parent)
			local col = Create.box({ Size = UDim2.fromScale(1, 1), Parent = parent }, { Create.list("y", 12) })
			local defs = {
				{ tone = "reward", title = "Legendary drop", text = "<b>Galeheart Bow</b> added to your satchel.", icon = "bow" },
				{ tone = "quest", title = "Quest updated", text = "The Ashen Gate · journals 4/4" },
				{ tone = "success", title = "Attributes committed", text = "3 points spent." },
				{ tone = "info", title = "New recipe learned", text = "Elixir of Valour", icon = "elixir" },
				{ tone = "warning", title = "Satchel almost full", text = "38 of 40 slots used." },
				{ tone = "error", title = "Not enough mana", text = "Falling Star needs 90 mana." },
			}
			for i, d in defs do
				local t = Feedback.toastCard({ tone = d.tone, title = d.title, text = d.text, icon = d.icon, width = 360 })
				t.LayoutOrder = i
				t.Parent = col
				scope:add(t)
			end
			local n = 0
			return {
				actions = {
					{ label = "Push live toast", run = function()
						n += 1
						local d = defs[(n - 1) % #defs + 1]
						Feedback.toast(scope, { tone = d.tone, title = d.title, text = d.text, icon = d.icon, duration = 3.5, width = 340 })
					end },
				},
			}
		end,
	},
	{
		id = "dialogs",
		family = "feedback",
		title = "Modal dialog",
		blurb = "A destructive confirmation: dimmed backdrop, item medallion, focus starting on the safe choice, Escape to cancel.",
		size = Vector2.new(540, 300),
		build = function(scope, _parent)
			local function open()
				return Feedback.modal(scope, {
					title = "Discard item",
					icon = "amulet",
					glow = Theme.rarity.mythic.color,
					tone = "danger",
					body = "Discard <b>Amulet of the Seventh Star</b>? Mythic items can't be recovered once they're gone.",
					confirm = { text = "Discard", variant = "danger" },
					cancel = { text = "Keep it" },
				})
			end
			local m = open()
			task.defer(function()
				m.cancel:force({ focused = true })
			end)
			return {
				onReset = function()
					local mm = open()
					task.defer(function()
						mm.cancel:force({ focused = true })
					end)
				end,
				actions = {
					{ label = "Open again", run = open },
				},
			}
		end,
	},
	{
		id = "loot-reveal",
		family = "feedback",
		title = "Reward popup",
		blurb = "Loot reveal: turning rays, the coffer, and rewards popping in by rarity with tooltips.",
		size = Vector2.new(540, 360),
		build = function(scope, parent)
			local l = Progression.lootReveal(scope, {
				{ id = "galeheart_bow", count = 1 },
				{ id = "aether_crystal", count = 2 },
				{ id = "potion_health", count = 5 },
				{ id = "griffon_feather", count = 3 },
				{ id = "emberstone", count = 2 },
			}, { width = 540 })
			l.Instance.Parent = parent
			task.defer(l.play)
			return { onReset = l.play, actions = { { label = "Replay", run = l.play } } }
		end,
	},
	{
		id = "feedback-kit",
		family = "feedback",
		title = "Indicators & overlays",
		blurb = "Progress rings, loading runes, rarity and status tags, currency counters, a tooltip and a context menu.",
		size = Vector2.new(940, 360),
		build = function(scope, parent)
			local root = Create.box({ Size = UDim2.fromScale(1, 1), Parent = parent })
			-- rings
			local rings = Create.box({ Size = UDim2.fromOffset(420, 120), Parent = root }, { Create.list("x", 22, nil, Enum.VerticalAlignment.Center) })
			local r1 = Feedback.ring(scope, { size = 86, value = 0.72, color = C.xp, caption = "XP", layoutOrder = 1 })
			r1.Instance.Parent = rings
			local r2 = Feedback.ring(scope, { size = 86, value = 0.35, color = C.arcane, caption = "Crafting", layoutOrder = 2 })
			r2.Instance.Parent = rings
			local r3 = Feedback.ring(scope, { size = 86, value = 1, color = C.goldBright, caption = "Done", layoutOrder = 3 })
			r3.Instance.Parent = rings
			Feedback.spinner(scope, { size = 56, text = "Loading…", layoutOrder = 4 }).Instance.Parent = rings
			-- tags
			Surface.caption("Rarity & status tags", { Position = UDim2.fromOffset(0, 140), Size = UDim2.fromOffset(420, 18), Parent = root })
			local tagRows = Create.box({ Position = UDim2.fromOffset(0, 168), Size = UDim2.fromOffset(420, 64), Parent = root }, { Create.list("y", 10) })
			local tr1 = Create.box({ Size = UDim2.new(1, 0, 0, 24), Parent = tagRows }, { Create.list("x", 6) })
			for i, r in Theme.rarityOrder do
				Feedback.tag({ text = Theme.rarity[r].name, color = Theme.rarity[r].color, layoutOrder = i, parent = tr1 })
			end
			local tr2 = Create.box({ Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 2, Parent = tagRows }, { Create.list("x", 6) })
			Feedback.tag({ text = "New", color = C.arcane, solid = true, layoutOrder = 1, parent = tr2 })
			Feedback.tag({ text = "Equipped", color = C.goldBright, glyph = "check", layoutOrder = 2, parent = tr2 })
			Feedback.tag({ text = "Bound", color = C.textSoft, glyph = "lock", layoutOrder = 3, parent = tr2 })
			Feedback.tag({ text = "−20%", color = C.good, solid = true, layoutOrder = 4, parent = tr2 })
			Feedback.tag({ text = "Cursed", color = C.bad, glyph = "skull", layoutOrder = 5, parent = tr2 })
			-- currency
			Surface.caption("Currency", { Position = UDim2.fromOffset(0, 256), Size = UDim2.fromOffset(420, 18), Parent = root })
			local cur = Create.box({ Position = UDim2.fromOffset(0, 284), Size = UDim2.fromOffset(420, 30), Parent = root }, { Create.list("x", 26, nil, Enum.VerticalAlignment.Center) })
			local g = Feedback.currency(scope, { amount = 12480, kind = "gold", size = 18, layoutOrder = 1 })
			g.Instance.Parent = cur
			Feedback.currency(scope, { amount = 36, kind = "gem", size = 18, layoutOrder = 2 }).Instance.Parent = cur
			Feedback.currency(scope, { amount = 215, kind = "shard", size = 18, layoutOrder = 3 }).Instance.Parent = cur
			local poor = Feedback.currency(scope, { amount = 40, kind = "gold", size = 18, layoutOrder = 4 })
			poor.Instance.Parent = cur
			poor:setInsufficient(true)
			-- bars
			local bars = Create.box({ Position = UDim2.fromOffset(0, 330), Size = UDim2.fromOffset(420, 64), Parent = root }, { Create.list("y", 8) })
			Feedback.bar(scope, { label = "Reputation · Wardens' Guild", glyph = "shield_small", color = C.good, max = 3000, value = 2140, height = 12, layoutOrder = 1 }).Instance.Parent = bars
			-- tooltip + context menu (right half)
			local tip = Feedback.tooltipCard({ title = "Arcane Ward", body = "Absorbs the next <b>220</b> damage. Breaks on a critical hit.", hint = "Right-click to dismiss", width = 240 })
			tip.Position = UDim2.fromOffset(470, 0)
			tip.Parent = root
			scope:add(tip)
			local anchor = Button.new(scope, { text = "Right-click me", variant = "secondary", size = "small" })
			anchor.Instance.Position = UDim2.fromOffset(740, 0)
			anchor.Instance.Parent = root
			local function menu()
				local pos = Layers.toLocal(anchor.Instance.AbsolutePosition + Vector2.new(0, anchor.Instance.AbsoluteSize.Y + 6))
				return Feedback.contextMenu(scope, pos, {
					{ text = "Use", icon = "heart", hint = "E" },
					{ text = "Equip", icon = "shield_small" },
					{ text = "Split stack", icon = "swap" },
					{ text = "Link in chat", icon = "scroll_small", disabled = true },
					"-",
					{ text = "Discard…", icon = "trash", danger = true },
				}, "Mana Tonic")
			end
			scope:connect(anchor.Instance.MouseButton2Click, menu)
			task.delay(0.1, menu)
			return {
				actions = {
					{ label = "Animate rings", run = function()
						r1:set(0)
						r1:animate(0.72, 1.2)
						r2:set(0)
						r2:animate(0.35, 1.2)
					end },
					{ label = "Gold +2,500", run = function()
						g:set(g:get() + 2500)
					end },
					{ label = "Open menu", run = menu },
				},
			}
		end,
	},
}
