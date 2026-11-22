--!strict
-- ItemCard: the item tooltip. Rarity header, type and level, stat lines, comparison deltas against an
-- equipped item, special effect, lore, value and weight. Static (returns a Frame), so the same card is
-- used as a hover tooltip, in comparison pairs and on its own.
local Theme = require(script.Parent.Parent.Theme)
local Atlas = require(script.Parent.Parent.Atlas)
local Create = require(script.Parent.Parent.Core.Create)
local Surface = require(script.Parent.Surface)
local Items = require(script.Parent.Parent.Data.Items)

local C = Theme.color
local ItemCard = {}

local function group(n: number): string
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if s:sub(1, 1) == "," then s:sub(2) else s
end

local function line(parent: Instance, order: number, h: number?): Frame
	return Create.box({ Size = UDim2.new(1, 0, 0, h or 20), LayoutOrder = order, Parent = parent })
end

-- opts: compare (Item to compare against), equipped (bool: this card is the equipped one), count, width, price
function ItemCard.new(item: any, opts: { [string]: any }?): Frame
	local o = opts or {}
	local r = Theme.rarityOf(item.rarity)
	local width = o.width or 290
	local card = Create.box({ Name = "ItemCard", Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y })
	-- body
	Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		Parent = card,
	}, { Create.corner(7), Create.gradient({ C.leather1, C.leather0 }, 90) })
	-- rarity wash behind the header
	Create("Frame", {
		Name = "Wash",
		BackgroundColor3 = r.color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 0, 86),
		Parent = card,
	}, { Create.corner(6), Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }) }) })
	Atlas.image("chrome", "frame_thin", { Name = "Frame", Size = UDim2.fromScale(1, 1), SliceScale = 0.6, ImageColor3 = r.color:Lerp(Color3.new(1, 1, 1), 0.25), ZIndex = 4, Parent = card })

	local body = Create.box({ Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2, Parent = card }, {
		Create.padding(14, 16, 14, 16),
		Create.list("y", 8),
	})

	-- header: icon, name, type
	local head = Create.box({ Name = "Head", Size = UDim2.new(1, 0, 0, 58), LayoutOrder = 1, Parent = body })
	local iconBox = Create.box({ Size = UDim2.fromOffset(56, 56), Parent = head })
	Create("Frame", { BackgroundColor3 = C.void, Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), Parent = iconBox }, { Create.corner(6) })
	Atlas.image("chrome", "glow", { Size = UDim2.fromScale(1, 1), ImageColor3 = r.color, ImageTransparency = 0.5, ZIndex = 2, Parent = iconBox })
	Atlas.image("icon", item.icon, { Size = UDim2.fromScale(0.84, 0.84), Position = UDim2.fromScale(0.08, 0.08), ZIndex = 3, Parent = iconBox })
	Atlas.image("chrome", "frame_slot", { Size = UDim2.fromScale(1, 1), SliceScale = 0.35, ImageColor3 = r.color, ZIndex = 4, Parent = iconBox })
	local names = Create.box({ Position = UDim2.fromOffset(68, 0), Size = UDim2.new(1, -68, 1, 0), Parent = head }, { Create.list("y", 3, nil, Enum.VerticalAlignment.Center) })
	Surface.text({ role = "heading", text = item.name, color = r.color:Lerp(Color3.new(1, 1, 1), 0.15), size = 19, wrap = true, LayoutOrder = 1, Parent = names })
	Surface.text({ role = "small", text = `{r.name} {item.type}`, color = C.textSoft, size = 12, LayoutOrder = 2, Parent = names })
	if o.equipped or o.compare then
		local tagRow = Create.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 0, Parent = body })
		local t = Create("Frame", { BackgroundColor3 = if o.equipped then C.goldDeep else C.arcaneDeep, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Parent = tagRow }, { Create.corner(4), Create.padding(0, 8, 0, 8) })
		Surface.text({ role = "caps", text = if o.equipped then "Equipped" else "Compare to equipped", color = C.goldPale, size = 10, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = t })
	end

	-- level / slot line
	local meta = line(body, 2, 16)
	Surface.text({ role = "caps", text = if item.slot then (`{item.slot == "mainhand" and "Main hand" or item.slot == "offhand" and "Off hand" or item.slot}`) else item.kind, color = C.textFaint, size = 10, Parent = meta })
	Surface.text({ role = "caps", text = `Item level {item.level}`, color = C.textFaint, size = 10, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = meta })

	-- stats with comparison
	if item.stats then
		Surface.divider({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 12), Parent = body })
		local stats = Create.box({ Name = "Stats", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = body }, { Create.list("y", 3) })
		local cmp = o.compare and o.compare.stats or nil
		local keys = {}
		for _, k in Items.statOrder do
			if item.stats[k] or (cmp and cmp[k]) then
				table.insert(keys, k)
			end
		end
		for i, k in keys do
			local v = item.stats[k] or 0
			local row = line(stats, i, 20)
			local primary = k == "power" or k == "armor"
			Surface.text({
				role = if primary then "label" else "body",
				text = if v ~= 0 then Items.formatStat(k, v) else `— {Items.statNames[k]}`,
				color = if v == 0 then C.textGhost elseif primary then C.text else C.textSoft,
				size = if primary then 16 else 14,
				Parent = row,
			})
			if cmp then
				local d = v - (cmp[k] or 0)
				if d ~= 0 then
					local up = d > 0
					local dr = Create.box({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Parent = row }, { Create.list("x", 3, nil, Enum.VerticalAlignment.Center) })
					Atlas.image("glyph", if up then "arrow_up" else "arrow_down", { Size = UDim2.fromOffset(12, 12), ImageColor3 = if up then C.good else C.bad, LayoutOrder = 1, Parent = dr })
					Surface.text({ role = "number", text = `{math.abs(d)}{if Items.percentStats[k] then "%" else ""}`, color = if up then C.good else C.bad, size = 13, LayoutOrder = 2, Parent = dr })
				end
			end
		end
	end
	if item.effect then
		local eff = Create.box({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = body }, { Create.list("x", 8) })
		Atlas.image("glyph", "sparkle", { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(0, 3), ImageColor3 = C.arcane, LayoutOrder = 1, Parent = eff })
		local t = Surface.text({ role = "small", text = item.effect, color = C.arcane, wrap = true, LayoutOrder = 2, Parent = eff })
		t.Size = UDim2.new(1, -22, 0, 0)
	end
	if item.lore then
		Surface.text({ role = "lore", text = `“{item.lore}”`, color = C.textFaint, wrap = true, LayoutOrder = 6, Parent = body })
	end
	-- footer
	local foot = line(body, 9, 22)
	Create("Frame", { BackgroundColor3 = C.seam, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Parent = foot })
	local left = Create.box({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(0.5, 0, 0, 16), Parent = foot }, { Create.list("x", 5, nil, Enum.VerticalAlignment.Center) })
	if item.kind == "quest" then
		Surface.text({ role = "caps", text = "Quest item · cannot be sold", color = C.arcane, size = 10, Parent = left })
	else
		local price = o.price or item.value
		Atlas.image("glyph", "coin", { Size = UDim2.fromOffset(14, 14), ImageColor3 = C.goldBright, LayoutOrder = 1, Parent = left })
		Surface.text({ role = "number", text = group(price * (o.count or 1)), color = C.goldBright, size = 13, LayoutOrder = 2, Parent = left })
		if (o.count or 1) > 1 then
			Surface.text({ role = "small", text = `({price} each)`, color = C.textFaint, size = 11, LayoutOrder = 3, Parent = left })
		end
	end
	Surface.text({ role = "small", text = `{item.weight} lb`, color = C.textFaint, size = 12, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), Parent = foot })
	return card
end

return ItemCard
