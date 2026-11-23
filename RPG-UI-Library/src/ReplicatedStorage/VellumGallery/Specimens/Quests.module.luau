--!strict
-- Quests & Progression specimens.
local Lib = require(script.Parent.Parent.Lib)
local Create = require(Lib.Core.Create)
local Store = require(Lib.Core.Store)
local Progression = require(Lib.Widgets.Progression)
local Quests = require(Lib.Data.Quests)

return {
	{
		id = "quest-log",
		family = "quests",
		title = "Quest journal",
		blurb = "Active and completed tabs, quest cards, a parchment detail page with objectives and rewards, tracking, abandon confirmation and turn-in.",
		size = Vector2.new(940, 620),
		build = function(scope, parent)
			local log = Progression.questLog(scope)
			log.Instance.Parent = parent
			return {
				onReset = log.reset,
				actions = {
					{ label = "Advance Ashen Gate", run = function()
						log:advance("ashen_gate")
					end },
					{ label = "Select bounty (ready)", run = function()
						log:select("bounty")
					end },
					{ label = "Turn in bounty", run = function()
						log:select("bounty")
						task.wait(0.2)
						log.showComplete(Quests.get("bounty"))
					end },
					{ label = "Completed tab", run = function()
						log.store:set({ tab = 2, selected = "lighthouse" })
					end },
				},
			}
		end,
	},
	{
		id = "quest-cards",
		family = "quests",
		title = "Quest cards",
		blurb = "One card in five states: tracked, in progress, ready to turn in, completed and locked, plus hover and selection.",
		size = Vector2.new(700, 300),
		build = function(scope, parent)
			local grid = Create.box({ Size = UDim2.fromScale(1, 1), Parent = parent }, {
				Create.new("UIGridLayout", { CellSize = UDim2.fromOffset(340, 88), CellPadding = UDim2.fromOffset(20, 18), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			local defs = {
				{ "ashen_gate", true, nil },
				{ "moonpetal", false, { hover = true } },
				{ "bounty", false, nil },
				{ "daily_forge", false, nil },
				{ "lighthouse", false, nil },
				{ "drowned_vault", false, nil },
			}
			for i, d in defs do
				local c = Progression.questCard(scope, { quest = Store.copy(Quests.get(d[1])), selected = d[2], width = 340, layoutOrder = i })
				c.Instance.Parent = grid
				if d[3] then
					c:force(d[3])
				end
			end
			return nil
		end,
	},
	{
		id = "quest-tracker",
		family = "quests",
		title = "Quest tracker",
		blurb = "A compact tracking widget: objectives tick off with an animated check and the quest flags itself ready to turn in.",
		size = Vector2.new(340, 330),
		build = function(scope, parent)
			local t = Progression.tracker(scope, { width = 340 })
			t.Instance.Parent = parent
			return {
				onReset = t.reset,
				actions = {
					{ label = "Advance Ashen Gate", run = function()
						t:advance(1)
					end },
					{ label = "Advance Moonpetal", run = function()
						t:advance(2)
					end },
					{ label = "Complete Moonpetal", run = function()
						for _ = 1, 4 do
							t:advance(2)
							task.wait(0.15)
						end
					end },
				},
			}
		end,
	},
	{
		id = "achievements",
		family = "quests",
		title = "Achievement cards",
		blurb = "Unlocked with a wax seal, in progress with a bar, locked and hidden, each with its point value.",
		size = Vector2.new(830, 330),
		build = function(scope, parent)
			local grid = Create.box({ Size = UDim2.fromScale(1, 1), Parent = parent }, {
				Create.new("UIGridLayout", { CellSize = UDim2.fromOffset(405, 96), CellPadding = UDim2.fromOffset(20, 18), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			for i, a in Quests.achievements do
				Progression.achievement(scope, a, { width = 405, layoutOrder = i }).Instance.Parent = grid
			end
			return nil
		end,
	},
	{
		id = "level-up",
		family = "quests",
		title = "Level-up presentation",
		blurb = "Rotating rays, the level counting up in its keystone frame, a ribbon banner and staggered gains.",
		size = Vector2.new(560, 380),
		build = function(scope, parent)
			local l = Progression.levelUp(scope)
			l.Instance.Parent = parent
			task.defer(l.play)
			return {
				onReset = l.play,
				actions = {
					{ label = "Replay", run = function()
						l.play()
					end },
				},
			}
		end,
	},
	{
		id = "quest-complete",
		family = "quests",
		title = "Quest complete notice",
		blurb = "A parchment notice: the wax seal stamps down and the rewards arrive one by one.",
		size = Vector2.new(470, 340),
		build = function(scope, parent)
			local n = Progression.completeNotice(scope, Quests.get("bounty"), { width = 470 })
			n.Instance.Parent = parent
			task.defer(n.play)
			return {
				onReset = n.play,
				actions = {
					{ label = "Replay", run = function()
						n.play()
					end },
				},
			}
		end,
	},
}
