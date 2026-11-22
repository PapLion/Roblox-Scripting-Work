-- Boot: real preload of the UI atlas, fonts and weapon models with ContentProvider.
-- If something fails the player can retry or continue with the fallbacks (text-only icons / stand-ins).

local ContentProvider = game:GetService("ContentProvider")

local PivotUI = script.Parent.Parent
local UI = require(PivotUI.UI)
local Util = require(PivotUI.Util)
local Store = require(PivotUI.State)
local Icons = require(PivotUI.Icons)
local Theme = require(PivotUI.Theme)
local Stage = require(PivotUI.Match.Stage)

local C = UI.C
local Boot = {}

-- Script-built models (stand-ins, figure) have no remote content; they still count so the bar reflects
-- every resource the lobby needs. Only real fetch failures are reported.

local function groups()
	local list = {}
	-- interface atlas
	local atlas = Instance.new("ImageLabel")
	atlas.Image = Icons.image
	table.insert(list, { label = "Atlas de interfaz", inst = atlas })
	-- fonts are engine-bundled (Oswald, Builder Sans, Builder Mono): no download, nothing to preload
	-- weapon renders for the lobby stand come from the same models below
	-- weapon models (MeshParts and their textures)
	for _, m in PivotUI.Assets.Weapons:GetChildren() do
		table.insert(list, { label = "Modelo " .. m.Name, inst = m })
	end
	return list
end

function Boot.build(ctx)
	local m = UI.m
	local root, scope = ctx.root, ctx.scope
	Stage.title()
	UI.fill(C.ink950, { Name = "Bg", Parent = ctx.backdrop })

	local center = UI.box({ Name = "Center", Size = UDim2.fromOffset(math.min(420, root.AbsoluteSize.X - 2 * m.pad), 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = root })
	UI.list("v", m.gap, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = center
	local brand = UI.box({ Size = UDim2.new(1, 0, 0, m.h1 * 1.5), AutomaticSize = Enum.AutomaticSize.None, LayoutOrder = 1, Parent = center })
	UI.list("h", 12, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = brand
	UI.icon("logo", math.floor(m.h1 * 1.15), C.signal, { LayoutOrder = 1, Parent = brand })
	UI.label("h1", "PIVOT", { TextSize = math.floor(m.h1 * 1.35), Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = brand })

	local bar = UI.bar({ height = 4, order = 2, color = C.signal })
	bar.inst.Parent = center
	local status = UI.label("small", "Preparando recursos…", { TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Parent = center })
	local detail = UI.label("mono", "", { TextXAlignment = Enum.TextXAlignment.Center, TextSize = m.micro, TextColor3 = C.steel, LayoutOrder = 4, Parent = center })
	local actions = UI.box({ Size = UDim2.new(1, 0, 0, m.btn), LayoutOrder = 5, Visible = false, Parent = center })
	UI.list("h", m.gapSm, { HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = actions

	local function run()
		actions.Visible = false
		for _, c in actions:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		status.TextColor3 = C.steel2
		local list = groups()
		local total = #list
		local done, failed = 0, {}
		bar.set(0, total, false)
		bar.color(C.signal)
		for _, g in list do
			detail.Text = g.label
			local okCall = pcall(function()
				ContentProvider:PreloadAsync({ g.inst }, function(_, st)
					-- local fonts report None; only real failures count
					if st == Enum.AssetFetchStatus.Failure or st == Enum.AssetFetchStatus.TimedOut then
						failed[g.label] = true
					end
				end)
			end)
			if not okCall then
				failed[g.label] = true
			end
			done += 1
			bar.set(done, total, true)
			status.Text = string.format("Cargando recursos  ·  %d de %d", done, total)
		end
		local failedList = {}
		for label in failed do
			table.insert(failedList, label)
		end
		table.sort(failedList)
		if #failedList == 0 then
			detail.Text = "Todo listo"
			task.wait(0.35)
			Store.dispatch({ type = "BOOT_DONE" })
			return
		end
		bar.color(C.warn)
		status.TextColor3 = C.warn
		status.Text = Util.plural(#failedList, "No se pudo cargar {n} recurso", "No se pudieron cargar {n} recursos")
		detail.Text = table.concat(failedList, " · ") .. "  —  se usarán sustitutos"
		actions.Visible = true
		local retry = UI.button({ text = "Reintentar", icon = "refresh", variant = "secondary", order = 1, onClick = function()
			scope:spawn(run)
		end })
		retry.inst.Parent = actions
		local go = UI.button({ text = "Continuar", icon = "arrowRight", variant = "primary", order = 2, onClick = function()
			Store.dispatch({ type = "BOOT_DONE" })
		end })
		go.inst.Parent = actions
	end
	scope:spawn(run)
end

return Boot
