-- PIVOT client entry point: creates the ScreenGuis, picks the layout (desktop / tablet / phone),
-- routes between screens by game phase, applies the settings and owns the global input.
-- All data is simulated and local to this client (see ReplicatedStorage.PivotUI.State).

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local PivotUI = game:GetService("ReplicatedStorage"):WaitForChild("PivotUI")
local Util = require(PivotUI.Util)
local UI = require(PivotUI.UI)
local Store = require(PivotUI.State)
local Sim = require(PivotUI.Sim)
local Engine = require(PivotUI.Match.Engine)
local Stage = require(PivotUI.Match.Stage)
local Theme = require(PivotUI.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Roblox core UI that a menu-driven showcase doesn't use. The top bar and the Roblox menu stay.
local function setCore()
	for _, t in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Chat } do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, false)
	end
	pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false)
end
task.spawn(function()
	for _ = 1, 10 do
		if pcall(setCore) then
			break
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- screen guis
local function screenGui(name: string, order: number, insets: Enum.ScreenInsets)
	local old = playerGui:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	return UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = insets == Enum.ScreenInsets.None,
		ScreenInsets = insets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		Parent = playerGui,
	})
end

-- Backdrop layer (full bleed, under the Roblox top bar) and the main UI inside the safe area.
local backdropGui = screenGui("PivotBackdrop", 5, Enum.ScreenInsets.None)
local mainGui = screenGui("PivotUI", 10, Enum.ScreenInsets.CoreUISafeInsets)
local overlayGui = screenGui("PivotOverlay", 20, Enum.ScreenInsets.CoreUISafeInsets)
local showcaseGui = screenGui("PivotShowcase", 30, Enum.ScreenInsets.CoreUISafeInsets)

-- keyboard focus ring used by Roblox UI navigation (arrow keys / Enter once a control is selected)
local ring = UI.new("ImageLabel", { Name = "PivotFocus", BackgroundTransparency = 1, ImageColor3 = Theme.color.paper, Size = UDim2.fromScale(1, 1) })
require(PivotUI.Icons).apply(ring, "roundedStroke")
ring.SliceScale = 0.25
playerGui.SelectionImageObject = ring

UI.initOverlay(overlayGui)

---------------------------------------------------------------- layout
local layoutChanged = Util.signal()
local app = { layoutChanged = layoutChanged, backdrop = backdropGui, main = mainGui, overlay = overlayGui, showcase = showcaseGui }

local function touchMode(): boolean
	local pref = Store.state.settings.controls.touch
	if pref == "always" then
		return true
	elseif pref == "never" then
		return false
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function classify(size: Vector2): string
	if size.X >= 1100 and size.Y >= 620 then
		return "desktop"
	elseif size.X >= 820 and size.Y >= 540 then
		return "tablet"
	end
	return "phone"
end

local currentLayout, currentTouch
local function updateLayout(force: boolean?)
	local size = mainGui.AbsoluteSize
	if size.X <= 1 then
		return
	end
	local layout = classify(size)
	local touch = touchMode()
	if force or layout ~= currentLayout or touch ~= currentTouch then
		currentLayout, currentTouch = layout, touch
		UI.setLayout(layout, touch)
		UI.setToastAnchor(Store.state.phase == "match" and "match" or "menu")
		layoutChanged:Fire(layout)
	end
end
local pending = false
mainGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if pending then
		return
	end
	pending = true
	task.delay(0.15, function()
		pending = false
		updateLayout(false)
	end)
end)
UserInputService.LastInputTypeChanged:Connect(function()
	if touchMode() ~= currentTouch then
		updateLayout(true)
	end
end)

---------------------------------------------------------------- settings
local function applySettings()
	local s = Store.state.settings
	UI.sfxGroup.Volume = (s.audio.master / 100) * (s.audio.effects / 100) * 1.4
	Util.reducedMotion = s.accessibility.reducedMotion
	Stage.applyQuality(s.graphics.quality)
end
app.applySettings = applySettings

---------------------------------------------------------------- router
local Screens = PivotUI.Screens
local SCREEN_FOR_PHASE = { boot = "Boot", title = "Title", lobby = "Lobby", match = "Match", results = "Results" }
local screenScope = Util.scope()
local currentScreen = nil
local screenRoot = nil

local function mount(force: boolean?)
	local name = SCREEN_FOR_PHASE[Store.state.phase]
	if name == currentScreen and not force then
		return
	end
	UI.closeModalSilently()
	screenScope:clean()
	if screenRoot then
		screenRoot:Destroy()
	end
	GuiService.SelectedObject = nil
	currentScreen = name
	screenRoot = UI.box({ Name = name, Parent = mainGui })
	local backdrop = UI.box({ Name = name .. "Backdrop", Parent = backdropGui })
	screenScope:add(backdrop)
	UI.setToastAnchor(Store.state.phase == "match" and "match" or "menu")
	local ok, err = pcall(function()
		require(Screens:WaitForChild(name)).build({
			root = screenRoot,
			backdrop = backdrop,
			scope = screenScope,
			app = app,
		})
	end)
	if not ok then
		warn("[PIVOT] screen " .. name .. " failed: " .. tostring(err))
		UI.toast("No se pudo abrir la pantalla " .. name .. ". Revisa Output.", "bad", 6)
	end
end
app.remount = function()
	mount(true)
end

Store.changed:Connect(function(action)
	if action.type == "SETTINGS_APPLY" or action.type == "RESET" then
		applySettings()
		if action.type == "SETTINGS_APPLY" and touchMode() ~= currentTouch then
			updateLayout(true)
		end
	end
	if action.type == "RESET" then
		mount(true)
		return
	end
	mount(false)
end)

-- rebuild the visible screen when the layout class changes (reorganise, not just shrink)
layoutChanged:Connect(function()
	if currentScreen then
		mount(true)
	end
end)

---------------------------------------------------------------- network banner + simulated backend notices
local banner
local function showNet(status, attempt)
	if banner then
		banner:Destroy()
		banner = nil
	end
	if status == "online" then
		return
	end
	local m = UI.m
	banner = UI.surface({
		Name = "NetworkBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, m.topbar + 6),
		Size = UDim2.fromOffset(0, m.btnSm + 16),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 70,
		Parent = overlayGui,
	}, { edge = (status == "offline" and Theme.color.bad or Theme.color.warn):Lerp(Theme.color.ink600, 0.55), pad = 8, cut = 0.3 })
	UI.list("h", 10).Parent = banner
	if status == "reconnecting" then
		UI.spinner(18, Theme.color.warn).Parent = banner
		UI.label("strong", "Conexión perdida. Reconectando…  Intento " .. tostring(attempt or 1) .. " de 3", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = banner })
	else
		UI.icon("wifiOff", 18, Theme.color.bad, { LayoutOrder = 1, Parent = banner })
		UI.label("strong", "Sin conexión con los servidores", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = banner })
		local retry = UI.button({ text = "Reintentar", icon = "refresh", size = "sm", variant = "secondary", order = 3, onClick = function()
			Sim.retryConnection()
		end })
		retry.inst.Parent = banner
	end
end

Sim.events:Connect(function(kind, data)
	if kind == "net" then
		showNet(data.status, data.attempt)
		if data.status == "online" then
			UI.toast("Conexión restablecida", "ok")
		end
	elseif kind == "invite-accepted" then
		UI.toast(data.name .. " se ha unido al grupo", "ok")
	elseif kind == "invite-declined" then
		UI.toast(data.name .. " ha rechazado la invitación", "warn")
	elseif kind == "mm-expired" then
		UI.toast("No aceptaste a tiempo. Puedes volver a buscar cuando quieras.", "warn", 4.5)
	elseif kind == "mm-declined" then
		UI.toast("Has rechazado la partida.", "info")
	elseif kind == "mm-offline" then
		UI.toast("Sin conexión: la búsqueda se ha cancelado.", "bad", 4.5)
	end
end)

---------------------------------------------------------------- global input
-- Escape is reserved by Roblox (its own menu), so dialogs close with Backspace or their X button.
UserInputService.InputBegan:Connect(function(input, processed)
	if UserInputService:GetFocusedTextBox() then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Backspace then
		if not UI.closeModal() then
			app.back = app.back or nil
			if app.onBack then
				app.onBack()
			end
		end
	elseif (key == Enum.KeyCode.Up or key == Enum.KeyCode.Down or key == Enum.KeyCode.Left or key == Enum.KeyCode.Right) and not GuiService.SelectedObject and Store.state.phase ~= "match" then
		-- first arrow press enters keyboard navigation on the current screen (or the open dialog)
		local scopeRoot = overlayGui:FindFirstChild("Modal") or screenRoot
		if scopeRoot then
			pcall(GuiService.Select, GuiService, scopeRoot)
		end
	elseif key == Enum.KeyCode.Backquote then
		if app.toggleShowcase then
			app.toggleShowcase()
		end
	end
end)

---------------------------------------------------------------- boot
Sim.buildMatchConfig = Engine.configFromState
Sim.start()
applySettings()
RunService.RenderStepped:Wait()
updateLayout(true)
mount(true)

-- Development bridge for automated checks and reproducible captures from Studio tools (client only,
-- lives in PlayerGui, never replicated). Invoke("state") / ("dispatch", action) / ("match", action).
local bridge = Instance.new("BindableFunction")
bridge.Name = "PivotDevBridge"
bridge.OnInvoke = function(cmd, arg)
	local s = Store.state
	if cmd == "dispatch" then
		local ok, info = Store.dispatch(arg)
		return { ok = ok, info = info }
	elseif cmd == "match" then
		if app.match then
			app.match.step(arg)
			return true
		end
		return false
	elseif cmd == "closeModal" then
		UI.closeModalSilently()
		return true
	elseif cmd == "capture" then
		workspace:SetAttribute("PivotCapture", arg == true)
		return true
	elseif cmd == "modal" then
		return UI.modalOpen()
	end
	local missions = {}
	for id, mm in s.missions do
		missions[id] = mm.progress .. (mm.claimed and "C" or "")
	end
	local m = app.match and app.match.state
	return {
		phase = s.phase, tab = s.tab, mm = s.mm.status, network = s.network, credits = s.profile.credits,
		level = s.profile.level, xp = s.profile.xp, loadout = s.loadout, finishes = s.finishes, meReady = s.meReady,
		party = #s.party, purchases = #s.purchases, missions = missions, matchCount = s.matchCount, layout = UI.layout,
		touch = UI.touch, settings = s.settings,
		match = m and { phase = m.phase, t = m.t, hp = m.me.hp, alive = m.me.alive, kills = m.me.kills, scores = m.scores, active = m.active, mag = m.slots[m.active].mag, weapon = m.slots[m.active].weapon, spectate = m.spectate } or nil,
		connections = Store.changed:count(),
	}
end
bridge.Parent = playerGui

-- showcase panel (separate ScreenGui, hidden in capture mode)
local okShowcase, errShowcase = pcall(function()
	require(PivotUI.Showcase).init(app)
end)
if not okShowcase then
	warn("[PIVOT] showcase failed: " .. tostring(errShowcase))
end
