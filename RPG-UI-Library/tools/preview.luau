-- Edit-mode preview (development): syncs src/, then renders one gallery specimen into
-- StarterGui.VellumPreview on the neutral stage so the Studio viewport shows it without a playtest.
-- Usage from MCP / command bar:
--   _G.VELLUM_PREVIEW = { id = "buttons", state = "default", width = 1280 }
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:34873/f/tools/preview.luau"))()
local HttpService = game:GetService("HttpService")
local hash = loadstring(HttpService:GetAsync("http://127.0.0.1:34873/sync.luau", true))()
local opts = _G.VELLUM_PREVIEW or {}

local SG = game:GetService("StarterGui")
local old = SG:FindFirstChild("VellumPreview")
if old then
	old:Destroy()
end
if _G.VELLUM_PREVIEW_SCOPE then
	_G.VELLUM_PREVIEW_SCOPE:Destroy()
end
for _, n in { "VellumTmp", "VellumGalleryTmp" } do
	local o = game.ReplicatedStorage:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end

-- fresh copies so require() sees the synced source (require caches by instance)
local lib = game.ReplicatedStorage.Vellum:Clone()
lib.Name = "VellumTmp"
lib.Parent = game.ReplicatedStorage
local gal = game.ReplicatedStorage.VellumGallery:Clone()
gal.Name = "VellumGalleryTmp"
gal.Parent = game.ReplicatedStorage
gal:SetAttribute("LibraryName", "VellumTmp")

local Stage = require(gal.Stage)
local gui = Instance.new("ScreenGui")
gui.Name = "VellumPreview"
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local scope, info = Stage.preview(gui, opts)
_G.VELLUM_PREVIEW_SCOPE = scope
gui.Parent = SG
return `{hash} {info}`
