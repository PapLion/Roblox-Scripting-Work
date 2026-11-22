--!strict
-- Skill tree: three branches of nodes joined by paths. Select a node to inspect it; learn or unlearn ranks
-- with local points; reset the tree (with confirmation). Rules:
--   • a node needs every prerequisite at rank ≥ 1
--   • row gates: points spent in the branch's rows above the node's row must reach Skills.rowGate[row]
--   • a rank can be removed only if no learned node depends on it and no deeper row loses its gate
-- Purely a UI model: nothing is cast or applied.
local Theme = require(script.Parent.Parent.Theme)
local Atlas = require(script.Parent.Parent.Atlas)
local Create = require(script.Parent.Parent.Core.Create)
local Store = require(script.Parent.Parent.Core.Store)
local Motion = require(script.Parent.Parent.Core.Motion)
local Interact = require(script.Parent.Parent.Core.Interact)
local Surface = require(script.Parent.Parent.Components.Surface)
local Button = require(script.Parent.Parent.Components.Button)
local Feedback = require(script.Parent.Parent.Components.Feedback)
local Skills = require(script.Parent.Parent.Data.Skills)

local C = Theme.color
local M = Theme.motion
local SkillTree = {}

---------------------------------------------------------------- rules (pure)
function SkillTree.exampleState()
	return {
		ranks = { kindle = 1, searing = 2, guard = 3, ward = 1, shard = 1 },
		points = 6,
		selected = "meteor",
	}
end

local function rank(st, id: string): number
	return st.ranks[id] or 0
end

function SkillTree.spentAbove(st, branch: string, row: number): number
	local s = 0
	for _, node in Skills.nodes do
		if node.branch == branch and node.row < row then
			s += rank(st, node.id)
		end
	end
	return s
end

function SkillTree.branchSpent(st, branch: string): number
	return SkillTree.spentAbove(st, branch, 99)
end

-- returns ok, list of {text, met}
function SkillTree.requirements(st, node)
	local reqs = {}
	for _, rid in node.requires do
		local r = Skills.get(rid)
		table.insert(reqs, { text = `Learn {r.name}`, met = rank(st, rid) >= 1 })
	end
	local gate = Skills.rowGate[node.row]
	if gate > 0 then
		local bname = ""
		for _, b in Skills.branches do
			if b.id == node.branch then
				bname = b.name
			end
		end
		local have = SkillTree.spentAbove(st, node.branch, node.row)
		table.insert(reqs, { text = `{gate} points in {bname} rows above ({math.min(have, gate)}/{gate})`, met = have >= gate })
	end
	local ok = true
	for _, r in reqs do
		ok = ok and r.met
	end
	return ok, reqs
end

function SkillTree.canLearn(st, node): (boolean, string?)
	if rank(st, node.id) >= node.max then
		return false, "Mastered"
	end
	local ok = SkillTree.requirements(st, node)
	if not ok then
		return false, "Requirements not met"
	end
	if st.points <= 0 then
		return false, "No points left"
	end
	return true, nil
end

function SkillTree.canUnlearn(st, node): (boolean, string?)
	local r = rank(st, node.id)
	if r <= 0 then
		return false, "Not learned"
	end
	if r == 1 then
		for _, other in Skills.nodes do
			if rank(st, other.id) > 0 and table.find(other.requires, node.id) then
				return false, `{other.name} depends on it`
			end
		end
	end
	-- simulate removal and re-check gates of deeper learned nodes
	local sim = { ranks = table.clone(st.ranks), points = st.points }
	sim.ranks[node.id] = r - 1
	for _, other in Skills.nodes do
		if other.branch == node.branch and other.row > node.row and rank(sim, other.id) > 0 then
			if SkillTree.spentAbove(sim, other.branch, other.row) < Skills.rowGate[other.row] then
				return false, `{other.name} would lose its row requirement`
			end
		end
	end
	return true, nil
end

function SkillTree.learn(st, id: string)
	local node = Skills.get(id)
	local ok = SkillTree.canLearn(st, node)
	if not ok then
		return false
	end
	st.ranks = table.clone(st.ranks)
	st.ranks[id] = rank(st, id) + 1
	st.points -= 1
	return true
end

function SkillTree.unlearn(st, id: string)
	local node = Skills.get(id)
	local ok = SkillTree.canUnlearn(st, node)
	if not ok then
		return false
	end
	st.ranks = table.clone(st.ranks)
	st.ranks[id] = rank(st, id) - 1
	st.points += 1
	return true
end

---------------------------------------------------------------- UI
local LANE = 78
local ROW = 90
local BRANCH_W = LANE * 3
local GAP = 34
local NODE = 58

local function nodeCenter(node, bIndex: number): Vector2
	return Vector2.new((bIndex - 1) * (BRANCH_W + GAP) + (node.col - 0.5) * LANE, 56 + (node.row - 1) * ROW + NODE / 2)
end

function SkillTree.new(scope: any, props: { [string]: any }?)
	local _ = props
	local store = Store.new(SkillTree.exampleState())
	scope:add(store)
	local branchIndex = {}
	for i, b in Skills.branches do
		branchIndex[b.id] = i
	end

	local panel, content = Surface.panel({ title = "Skill Tree", size = UDim2.fromOffset(1090, 640), padding = 18 })
	scope:add(panel)

	-- header: unspent points + reset
	local header = Create.box({ Name = "Header", Size = UDim2.new(1, 0, 0, 40), Parent = content })
	local pointsBox = Create.box({ Size = UDim2.fromOffset(240, 40), Parent = header })
	local gem = Create.box({ Size = UDim2.fromOffset(40, 40), Parent = pointsBox })
	Atlas.image("chrome", "diamond", { Size = UDim2.fromScale(1, 1), ImageColor3 = C.arcaneDeep, Parent = gem })
	Atlas.image("chrome", "node_diamond", { Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = gem })
	local pointsNum = Surface.text({ role = "number", text = "", size = 17, color = C.goldPale, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3, Parent = gem })
	local gemPop = Create.scale(1)
	gemPop.Parent = gem
	Surface.text({ role = "heading", text = "Unspent points", size = 17, color = C.text, Position = UDim2.fromOffset(52, 2), Parent = pointsBox })
	local spentText = Surface.text({ role = "caps", text = "", size = 10, color = C.textFaint, Position = UDim2.fromOffset(52, 24), Parent = pointsBox })

	-- tree field
	local field = Create.box({ Name = "Field", Position = UDim2.fromOffset(0, 54), Size = UDim2.fromOffset(3 * BRANCH_W + 2 * GAP, 520), Parent = content })
	local branchHeads = {}
	for i, b in Skills.branches do
		local x = (i - 1) * (BRANCH_W + GAP)
		local col = Create("Frame", { Name = "Branch_" .. b.id, BackgroundColor3 = C.void, BackgroundTransparency = 0.55, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(BRANCH_W, 520), Parent = field }, { Create.corner(8), Create.stroke(C.seam, 1, 0.3) })
		Create("Frame", { BackgroundColor3 = b.color, BackgroundTransparency = 0.88, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40), Parent = col }, { Create.corner(8), Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }) })
		local h = Create.box({ Size = UDim2.new(1, 0, 0, 38), Parent = col }, { Create.list("x", 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
		Atlas.image("glyph", b.glyph, { Size = UDim2.fromOffset(16, 16), ImageColor3 = b.color, LayoutOrder = 1, Parent = h })
		Surface.text({ role = "heading", text = b.name, size = 17, color = b.color:Lerp(Color3.new(1, 1, 1), 0.2), LayoutOrder = 2, Parent = h })
		local cnt = Surface.text({ role = "number", text = "0", size = 12, color = C.textFaint, LayoutOrder = 3, Parent = h })
		branchHeads[b.id] = cnt
		-- row gate markers
		for r = 2, 5 do
			local g = Skills.rowGate[r]
			local mark = Surface.text({ role = "caps", text = `{g}`, size = 9, color = C.textGhost, Position = UDim2.fromOffset(6, 56 + (r - 1) * ROW + NODE / 2 - 18), Parent = col })
			mark.Name = "Gate" .. r
		end
	end

	-- edges
	local edges = {}
	for _, node in Skills.nodes do
		local bi = branchIndex[node.branch]
		for _, rid in node.requires do
			local parentNode = Skills.get(rid)
			local a, b = nodeCenter(parentNode, bi), nodeCenter(node, bi)
			local d = b - a
			local len = d.Magnitude
			local edge = Create.box({
				Name = `Edge_{rid}_{node.id}`,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
				Size = UDim2.fromOffset(len, 8),
				Rotation = math.deg(math.atan2(d.Y, d.X)),
				ZIndex = 1,
				Parent = field,
			})
			Create("Frame", { BackgroundColor3 = C.void, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 7), ZIndex = 1, Parent = edge }, { Create.corner(3) })
			Create("Frame", { BackgroundColor3 = C.seam, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 3), ZIndex = 1, Parent = edge })
			local fill = Create("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 0, 0, 3), ZIndex = 1, Parent = edge }, {
				Create.gradient({ C.goldBright, Skills.branches[bi].color }, 0),
			})
			table.insert(edges, { from = rid, to = node.id, fill = fill, lit = false })
		end
	end

	-- nodes
	local views = {}
	for _, node in Skills.nodes do
		local bi = branchIndex[node.branch]
		local c = nodeCenter(node, bi)
		local big = node.kind == "keystone"
		local size = if big then 72 else NODE
		local btn = Create("ImageButton", {
			Name = "Node_" .. node.id,
			BackgroundTransparency = 1,
			Image = "",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(c.X, c.Y),
			Size = UDim2.fromOffset(size, size),
			ZIndex = 3,
			Parent = field,
		})
		local pulse = Atlas.image("chrome", "glow", { Name = "Pulse", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.9, 1.9), ImageColor3 = C.arcane, ImageTransparency = 1, ZIndex = 2, Parent = btn })
		local bgSprite = if node.kind == "active" then "diamond" else "disc"
		local bg = Atlas.image("chrome", bgSprite, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.84, 0.84), ImageColor3 = C.leather0, ZIndex = 3, Parent = btn })
		local icon = Atlas.image("icon", node.icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(if node.kind == "active" then 0.56 else 0.66, if node.kind == "active" then 0.56 else 0.66), ZIndex = 4, Parent = btn })
		local frameName = if node.kind == "active" then "node_diamond" elseif big then "node_keystone" else "node_round"
		local frame = Atlas.image("chrome", frameName, { Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = btn })
		local lock = Atlas.image("glyph", "lock", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.3), ImageColor3 = C.textSoft, ZIndex = 6, Parent = btn })
		local badge = Create("Frame", { Name = "Rank", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromOffset(34, 17), BackgroundColor3 = C.void, ZIndex = 7, Parent = btn }, { Create.corner(8), Create.stroke(C.goldDeep, 1, 0) })
		local rankText = Surface.text({ role = "number", text = "", size = 11, color = C.goldBright, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = badge })
		local ring = Create("Frame", { Name = "Selected", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.22, 1.22), Visible = false, ZIndex = 2, Parent = btn }, {
			Create.corner(if node.kind == "active" then 8 else 99),
			Create.stroke(C.arcane, 2, 0),
		})
		if node.kind == "active" then
			ring.Rotation = 45
			ring.Size = UDim2.fromScale(0.95, 0.95)
		end
		local pop = Create.scale(1)
		pop.Parent = btn
		local v = { node = node, btn = btn, pulse = pulse, bg = bg, icon = icon, frame = frame, lock = lock, badge = badge, rankText = rankText, ring = ring, pop = pop, hover = false }
		views[node.id] = v
		v.ctl = Interact.attach(btn, scope, function(s)
			v.hover = s.hover or s.focused
			if v.paint then
				v.paint()
			end
		end, function()
			store:set({ selected = node.id })
		end)
		Feedback.tooltip(scope, btn, function()
			local st = store:get()
			local r = rank(st, node.id)
			local ok, why = SkillTree.canLearn(st, node)
			return Feedback.tooltipCard({
				title = node.name,
				body = Skills.describe(node, math.max(1, r)),
				hint = `Rank {r}/{node.max} · {if ok then "Can learn" else why}`,
				width = 230,
			})
		end, { side = "right" })
	end

	-- pulse animation for learnable nodes
	local t0 = os.clock()
	scope:connect(game:GetService("RunService").Heartbeat, function()
		local a = 0.55 + 0.25 * math.sin((os.clock() - t0) * 3.2)
		for _, v in views do
			if v.learnable then
				v.pulse.ImageTransparency = a
			end
		end
	end)

	-- detail pane
	local pane = Surface.well({ Name = "Detail", Position = UDim2.fromOffset(3 * BRANCH_W + 2 * GAP + 18, 54), Size = UDim2.new(1, -(3 * BRANCH_W + 2 * GAP + 18), 0, 520), Parent = content })
	local paneBody = Create.box({ Size = UDim2.fromScale(1, 1), Parent = pane }, { Create.padding(16), Create.list("y", 10, Enum.HorizontalAlignment.Center) })
	local detailIcon = Create.box({ Size = UDim2.fromOffset(84, 84), LayoutOrder = 1, Parent = paneBody })
	local dGlow = Atlas.image("chrome", "glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.6, 1.6), ImageTransparency = 0.6, Parent = detailIcon })
	local dBg = Atlas.image("chrome", "disc", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.84, 0.84), ImageColor3 = C.leather0, ZIndex = 2, Parent = detailIcon })
	local dIcon = Atlas.image("icon", "fireball", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), ZIndex = 3, Parent = detailIcon })
	local dFrame = Atlas.image("chrome", "node_round", { Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = detailIcon })
	local dName = Surface.text({ role = "title", text = "", size = 22, color = C.goldBright, wrap = true, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = paneBody })
	local dKind = Surface.text({ role = "caps", text = "", size = 10, color = C.textFaint, LayoutOrder = 3, Parent = paneBody })
	local pips = Create.box({ Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 4, Parent = paneBody }, { Create.list("x", 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	Surface.divider({ LayoutOrder = 5, Parent = paneBody })
	local dNow = Surface.text({ role = "body", text = "", size = 14, color = C.text, wrap = true, rich = true, LayoutOrder = 6, Parent = paneBody })
	local dNext = Surface.text({ role = "small", text = "", color = C.arcane, wrap = true, rich = true, LayoutOrder = 7, Parent = paneBody })
	local reqBox = Create.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 8, Parent = paneBody }, { Create.list("y", 5) })
	local actions = Create.box({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.new(1, -32, 0, 88), Parent = pane }, { Create.list("y", 8) })
	local learnBtn = Button.new(scope, { text = "Learn", variant = "arcane", icon = "plus", fill = true, layoutOrder = 1, onClick = function()
		local st = Store.copy(store:get())
		local id = st.selected
		if SkillTree.learn(st, id) then
			store:set(st)
			Motion.pop(views[id].pop, 0.25)
			Motion.pop(gemPop, 0.2)
		end
	end })
	learnBtn.Instance.Parent = actions
	local row2 = Create.box({ Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 2, Parent = actions }, { Create.list("x", 8) })
	local unlearnBtn = Button.new(scope, { text = "Unlearn", variant = "ghost", size = "small", icon = "minus", width = 110, layoutOrder = 1, onClick = function()
		local st = Store.copy(store:get())
		if SkillTree.unlearn(st, st.selected) then
			store:set(st)
		end
	end })
	unlearnBtn.Instance.Parent = row2
	local resetBtn = Button.new(scope, { text = "Reset tree", variant = "secondary", size = "small", icon = "refresh", width = 118, layoutOrder = 2, onClick = function()
		local st = store:get()
		local spent = 0
		for _, r in st.ranks do
			spent += r
		end
		Feedback.modal(scope, {
			title = "Reset skill tree",
			tone = "danger",
			icon = "arcane_orb",
			glow = C.arcane,
			body = `Unlearn every skill and refund <b>{spent}</b> point{if spent == 1 then "" else "s"}?`,
			confirm = { text = "Reset", variant = "danger" },
			onConfirm = function()
				store:set({ ranks = {}, points = st.points + spent })
			end,
		})
	end })
	resetBtn.Instance.Parent = row2
	local reason = Surface.text({ role = "lore", text = "", size = 12, color = C.textFaint, wrap = true, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 9, Parent = paneBody })
	local reqScope: any = nil

	local function render(st)
		pointsNum.Text = tostring(st.points)
		local total = 0
		for _, b in Skills.branches do
			local s = SkillTree.branchSpent(st, b.id)
			total += s
			branchHeads[b.id].Text = tostring(s)
		end
		spentText.Text = `{total} spent across three branches`
		for _, v in views do
			local node = v.node
			local r = rank(st, node.id)
			local reqOk = SkillTree.requirements(st, node)
			local learnable = SkillTree.canLearn(st, node)
			v.learnable = learnable and r == 0
			local color = Skills.branches[branchIndex[node.branch]].color
			local locked = not reqOk and r == 0
			v.paint = function()
				v.lock.Visible = locked
				v.icon.ImageColor3 = if locked then Color3.fromRGB(95, 88, 80) elseif r == 0 then Color3.fromRGB(175, 168, 158) else Color3.new(1, 1, 1)
				v.icon.ImageTransparency = if locked then 0.35 else 0
				v.frame.ImageColor3 = if r >= node.max then Color3.new(1, 1, 1) elseif r > 0 then Color3.fromRGB(235, 225, 210) elseif locked then Color3.fromRGB(110, 100, 90) else Color3.fromRGB(190, 180, 165)
				v.bg.ImageColor3 = if r > 0 then color:Lerp(C.void, 0.72) else C.leather0
				v.badge.Visible = node.max > 1 or r > 0
				v.rankText.Text = `{r}/{node.max}`
				v.rankText.TextColor3 = if r >= node.max then C.goldBright elseif r > 0 then C.text else C.textFaint
				v.ring.Visible = st.selected == node.id or v.hover
				v.ring:FindFirstChildOfClass("UIStroke").Color = if st.selected == node.id then C.goldBright else C.arcane
				if not v.learnable then
					v.pulse.ImageTransparency = if r >= node.max then 0.62 else 1
					v.pulse.ImageColor3 = color
				else
					v.pulse.ImageColor3 = C.arcane
				end
			end
			v.paint()
		end
		for _, e in edges do
			local lit = rank(st, e.to) > 0
			if lit ~= e.lit then
				e.lit = lit
				Motion.tween(e.fill, { Size = UDim2.new(if lit then 1 else 0, 0, 0, 3) }, if lit then 0.45 else 0.2, Enum.EasingStyle.Quad, nil, "fill")
			end
		end
		-- detail pane
		local node = Skills.get(st.selected)
		local r = rank(st, node.id)
		local color = Skills.branches[branchIndex[node.branch]].color
		for k, val in Atlas.icon(node.icon) do
			(dIcon :: any)[k] = val
		end
		Atlas.set(dFrame, "chrome", if node.kind == "active" then "node_diamond" elseif node.kind == "keystone" then "node_keystone" else "node_round")
		Atlas.set(dBg, "chrome", if node.kind == "active" then "diamond" else "disc")
		dGlow.ImageColor3 = color
		dName.Text = node.name
		dKind.Text = string.upper(`{node.kind} · {Skills.branches[branchIndex[node.branch]].name}`) .. (if node.cost then ` · {node.cost} mana · {node.cooldown}s` else "")
		for _, ch in pips:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		for i = 1, node.max do
			Atlas.image("chrome", "pip", { Size = UDim2.fromOffset(13, 13), ImageColor3 = if i <= r then Color3.new(1, 1, 1) else Color3.fromRGB(70, 60, 50), LayoutOrder = i, Parent = pips })
		end
		dNow.Text = if r > 0 then `<b>Rank {r}:</b> {Skills.describe(node, r)}` else Skills.describe(node, 1)
		dNow.TextColor3 = if r > 0 then C.text else C.textSoft
		dNext.Visible = r > 0 and r < node.max
		dNext.Text = `<b>Next rank:</b> {Skills.describe(node, r + 1)}`
		if reqScope then
			reqScope:Destroy()
		end
		reqScope = scope:child()
		local _, reqs = SkillTree.requirements(st, node)
		for i, q in reqs do
			local row = reqScope:add(Create.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = reqBox }, { Create.list("x", 6) }))
			Atlas.image("glyph", if q.met then "check" else "close", { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(0, 2), ImageColor3 = if q.met then C.good else C.bad, LayoutOrder = 1, Parent = row })
			local t = Surface.text({ role = "small", text = q.text, color = if q.met then C.textSoft else C.text, size = 12, wrap = true, LayoutOrder = 2, Parent = row })
			t.Size = UDim2.new(1, -20, 0, 0)
		end
		local canL, why = SkillTree.canLearn(st, node)
		local canU, whyU = SkillTree.canUnlearn(st, node)
		learnBtn:setDisabled(not canL)
		learnBtn:setText(if r >= node.max then "Mastered" elseif r > 0 then "Learn next rank" else "Learn")
		unlearnBtn:setDisabled(not canU)
		local spent = 0
		for _, rr in st.ranks do
			spent += rr
		end
		resetBtn:setDisabled(spent == 0)
		reason.Text = if canL then "Costs 1 point" elseif r > 0 and not canU and whyU and whyU ~= "Not learned" then `Can't unlearn: {whyU}` else (why or "")
		reason.TextColor3 = if canL then C.textFaint else C.warn
	end
	scope:add(store:subscribe(render))
	render(store:get())

	return {
		Instance = panel,
		store = store,
		views = views,
		reset = function()
			store:reset()
		end,
		select = function(_, id: string)
			store:set({ selected = id })
		end,
		learn = function(_, id: string)
			local st = Store.copy(store:get())
			st.selected = id
			local ok = SkillTree.learn(st, id)
			store:set(st)
			if ok then
				Motion.pop(views[id].pop, 0.25)
			end
			return ok
		end,
	}
end

return SkillTree
