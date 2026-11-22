#!/usr/bin/env python3
"""Re-applies the edits made in Studio after the 12:05 autosave (recovery of 2026-11-13).
Each edit is an exact old -> new replacement; the script stops if any old text is missing."""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "src"
RS = ROOT / "ReplicatedStorage" / "PivotUI"
CLIENT = ROOT / "StarterPlayer" / "StarterPlayerScripts" / "PivotClient.client.luau"

EDITS = []


def edit(path, old, new):
    EDITS.append((path, old, new))


# ---------------------------------------------------------------- UI
UI = RS / "UI.module.luau"
edit(UI, """\t\tif opts.fill then
\t\t\tUI.flex("fill").Parent = b
\t\t\tinner.AnchorPoint = Vector2.new(0.5, 0)
\t\t\tinner.Position = UDim2.fromScale(0.5, 0)
\t\tend""", """\t\tif opts.fill then
\t\t\t-- equal columns; the label never truncates inside its own column
\t\t\tb.AutomaticSize = Enum.AutomaticSize.None
\t\t\tb.Size = UDim2.new(1 / #opts.options, -2, 1, 0)
\t\t\tinner.AnchorPoint = Vector2.new(0.5, 0)
\t\t\tinner.Position = UDim2.fromScale(0.5, 0)
\t\t\ttext.TextTruncate = Enum.TextTruncate.None
\t\tend""")
edit(UI, """\tUI.list("h", 2, opts.fill and { HorizontalFlex = Enum.UIFlexAlignment.Fill } or nil).Parent = track""",
     """\tUI.list("h", 2).Parent = track""")
edit(UI, """\t\tfor i, b in list or {} do
\t\t\tb.order = i""", """\t\tfor i, b in list or {} do
\t\t\tb.order = i
\t\t\tb.name = b.name or ("Action" .. i)""")
edit(UI, """\tlocal body = UI.box({ Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card })
\tapi.body = body""", """\t-- the body scrolls when its content is taller than the screen allows; header and actions stay visible
\tlocal headH = headRow.Size.Y.Offset
\tlocal maxBody = math.max(120, maxH - m.pad * 2 - headH - m.btn - m.gap * 2)
\tlocal body = UI.scroll({ Name = "Body", Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, ScrollBarThickness = 3, Parent = card })
\tapi.body = body
\t-- height follows the content (measured from the body's list layout) up to maxBody, then it scrolls
\tlocal fitConn
\tlocal function fit()
\t\tlocal layout = body:FindFirstChildOfClass("UIListLayout")
\t\tlocal h = layout and layout.AbsoluteContentSize.Y or 0
\t\tif not layout then
\t\t\tfor _, c in body:GetChildren() do
\t\t\t\tif c:IsA("GuiObject") then
\t\t\t\t\th = math.max(h, c.AbsoluteSize.Y)
\t\t\t\tend
\t\t\tend
\t\tend
\t\tbody.Size = UDim2.new(1, 0, 0, math.min(h + 2, maxBody))
\tend
\tbody.ChildAdded:Connect(function(c)
\t\tif c:IsA("UIListLayout") then
\t\t\tif fitConn then
\t\t\t\tfitConn:Disconnect()
\t\t\tend
\t\t\tfitConn = c:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
\t\tend
\t\ttask.defer(fit)
\tend)
\tapi.fit = fit""")
edit(UI, """\tfunction api.clearBody()
\t\tapi.scope:clean()
\t\tfor _, c in body:GetChildren() do
\t\t\tc:Destroy()
\t\tend
\tend""", """\tfunction api.clearBody()
\t\tapi.scope:clean()
\t\tfor _, c in body:GetChildren() do
\t\t\tc:Destroy()
\t\tend
\t\tbody.CanvasPosition = Vector2.zero
\tend""")
edit(UI, """\tapi.setActions(opts.actions)
\tlayer.Parent = root""", """\tapi.setActions(opts.actions)
\tlayer.Parent = root
\ttask.delay(0.05, fit)""")
edit(UI, """\t\tbuild = function(body)
\t\t\tUI.para(opts.body, { Parent = body })
\t\tend,""", """\t\tbuild = function(body)
\t\t\tUI.list("v", 8).Parent = body
\t\t\tUI.para(opts.body, { Parent = body })
\t\tend,""")
edit(UI, """\telse
\t\ttoastHolder.AnchorPoint = Vector2.new(1, 0)
\t\ttoastHolder.Position = UDim2.new(1, -m.pad, 0, m.topbar + m.gap)
\t\ttoastHolder:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Right
\tend""", """\telse
\t\t-- menus: top centre, below the top bar, over the 3D stand area (no primary actions there)
\t\ttoastHolder.AnchorPoint = Vector2.new(0.5, 0)
\t\ttoastHolder.Position = UDim2.new(0.5, 0, 0, m.topbar + 6)
\t\ttoastHolder:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
\tend""")

# ---------------------------------------------------------------- WeaponView
WV = RS / "WeaponView.module.luau"
edit(WV, "\t\tImageColor3 = C.paperLine,\n\t\tImageTransparency = 0.35,", "\t\tImageColor3 = C.paperLine,\n\t\tImageTransparency = 0.5,")
edit(WV, "\tgrid.TileSize = UDim2.fromOffset(opts.compact and 128 or 192, opts.compact and 64 or 96)",
     "\tgrid.TileSize = UDim2.fromOffset(opts.compact and 64 or 112, opts.compact and 32 or 56)")

# ---------------------------------------------------------------- Lobby
LB = RS / "Screens" / "Lobby.module.luau"
edit(LB, 'Size = UDim2.fromOffset(phone and 86 or 150, m.topbar - 16), LayoutOrder = 3 })',
     'Size = UDim2.fromOffset(phone and 86 or 196, m.topbar - 16), LayoutOrder = 3 })')
edit(LB, """local lvlText = UI.label("eyebrow", "", { TextColor3 = C.paper, TextSize = m.small, Size = UDim2.fromScale(0.5, 1), Parent = lvlRow })
\tlocal xpText = UI.label("mono", "", { TextSize = m.micro, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), Visible = not phone, Parent = lvlRow })""",
     """local lvlText = UI.label("eyebrow", "", { TextColor3 = C.paper, TextSize = m.small, Size = UDim2.fromScale(phone and 1 or 0.38, 1), Parent = lvlRow })
\tlocal xpText = UI.label("mono", "", { TextSize = m.micro, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(0.62, 1), Position = UDim2.fromScale(0.38, 0), Visible = not phone, Parent = lvlRow })""")
edit(LB, """\t\tnav = UI.surface({ Name = "Nav", Size = UDim2.new(0, 62, 1, -(m.topbar + m.pad)), Position = UDim2.fromOffset(m.pad, m.topbar), Parent = root }, { edge = C.ink700, pad = 4, cut = 0.3 })
\t\tUI.list("v", 2, { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly }).Parent = nav""",
     """\t\tnav = UI.surface({ Name = "Nav", Size = UDim2.new(0, 62, 1, -(m.topbar + m.pad)), Position = UDim2.fromOffset(m.pad, m.topbar), Parent = root }, { edge = C.ink700, pad = 3, cut = 0.3 })
\t\tUI.list("v", 0, { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }).Parent = nav""")
edit(LB, "\t\t\t\tSize = phone and UDim2.fromOffset(54, 46) or UDim2.fromOffset(0, m.topbar),",
     "\t\t\t\t-- phone rail: seven items share the rail height so it never overflows short screens\n\t\t\t\tSize = phone and UDim2.new(0, 56, 1 / 7, -1) or UDim2.fromOffset(0, m.topbar),")
edit(LB, "\t\t\tlocal icon = UI.icon(tab.icon, phone and 20 or 18, C.steel, { LayoutOrder = 1, Parent = inner })",
     "\t\t\tlocal icon = UI.icon(tab.icon, phone and 17 or 18, C.steel, { LayoutOrder = 1, Parent = inner })")
edit(LB, "\t\t\t\tSize = phone and UDim2.new(1, 0, 0, 12) or UDim2.fromScale(0, 1),",
     "\t\t\t\tSize = phone and UDim2.new(1, 0, 0, 11) or UDim2.fromScale(0, 1),")
edit(LB, "\t\t\t\tTextSize = phone and 10 or (tablet and m.small + 1 or m.body + 1),",
     "\t\t\t\tTextSize = phone and 9 or (tablet and m.small + 1 or m.body + 1),")

# ---------------------------------------------------------------- Parts
PT = RS / "Screens" / "Parts.module.luau"
edit(PT, "\tlocal txt = UI.box({ Size = UDim2.new(1, -(h - 12) - 10 - (opts.kick and (m.btnSm + 10) or 0) - 86, 1, 0), LayoutOrder = 2, Parent = row })",
     """\t-- phone: compact row (no kick button, status as a coloured dot) so names keep their width
\tif phone then
\t\topts.kick = nil
\tend
\tlocal txt = UI.box({ Size = UDim2.new(1, -(h - 12) - 10 - (opts.kick and (m.btnSm + 10) or 0) - (phone and 22 or 86), 1, 0), LayoutOrder = 2, Parent = row })""")
edit(PT, """\tlocal pillColor = info.ready and C.ok or C.steel
\tlocal pill = UI.tag(info.ready and "Listo" or "No listo", pillColor, { icon = info.ready and "check" or nil, order = 3 })
\tpill.Parent = row""", """\tlocal pillColor = info.ready and C.ok or C.steel
\tif phone then
\t\tUI.icon(info.ready and "ready" or "notReady", 16, pillColor, { LayoutOrder = 3, Parent = row })
\telse
\t\tlocal pill = UI.tag(info.ready and "Listo" or "No listo", pillColor, { icon = info.ready and "check" or nil, order = 3 })
\t\tpill.Parent = row
\tend""")

# ---------------------------------------------------------------- Match / Matchmaking / Stage
MT = RS / "Screens" / "Match.module.luau"
edit(MT, "{ edge = C.bad:Lerp(C.ink600, 0.45), pad = phone and 12 or 18 })", "{ edge = C.bad:Lerp(C.ink600, 0.72), pad = phone and 12 or 18 })")
edit(MT, "{ edge = C.warn:Lerp(C.ink600, 0.4), pad = 18 })", "{ edge = C.warn:Lerp(C.ink600, 0.7), pad = 18 })")
edit(MT, 'local cluster = UI.box({ Name = "TouchControls", Size = UDim2.fromOffset(phone and 210 or 250, phone and 190 or 230), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -pad, 1, -pad), Parent = hud })',
     'local cluster = UI.box({ Name = "TouchControls", Size = UDim2.fromOffset(phone and 210 or 250, phone and 190 or 230), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -(pad + 14), 1, -(pad + 8)), Parent = hud })')
MM = RS / "Screens" / "Matchmaking.module.luau"
edit(MM, "}, { edge = failed and C.bad or C.signal, pad = phone and 10 or 14, cut = 0.35 })",
     "}, { edge = (failed and C.bad or C.signal):Lerp(C.ink600, 0.55), pad = phone and 10 or 14, cut = 0.35 })")
ST = RS / "Match" / "Stage.module.luau"
edit(ST, "\tsetCamera(camMark.CFrame * CFrame.new(0, 2, 6) * CFrame.Angles(math.rad(-4), 0, 0), 60)",
     "\tsetCamera(camMark.CFrame * CFrame.new(3, 7, 16) * CFrame.Angles(math.rad(-6), math.rad(8), 0), 60)")

# ---------------------------------------------------------------- Shop / Missions
SH = RS / "Screens" / "Tabs" / "Shop.module.luau"
edit(SH, "{ edge = C.warn:Lerp(C.ink700, 0.4), pad = 12, cut = 0.3 })", "{ edge = C.warn:Lerp(C.ink700, 0.7), pad = 12, cut = 0.3 })")
edit(SH, "{ edge = C.bad:Lerp(C.ink700, 0.4), pad = 14, cut = 0.3 })", "{ edge = C.bad:Lerp(C.ink700, 0.7), pad = 14, cut = 0.3 })")
edit(SH, "{ edge = C.signal:Lerp(C.ink700, 0.55), pad = 16 })", "{ edge = C.signal:Lerp(C.ink700, 0.72), pad = 16 })")
edit(SH, """\t\t\t\tlocal ok, info = Store.dispatch({ type = "PURCHASE", id = item.id })
\t\t\t\tif ok then
\t\t\t\t\treceipt = info.receipt
\t\t\t\t\tUI.sfx("reward")
\t\t\t\t\tgo("success")
\t\t\t\telse
\t\t\t\t\tgo("error")
\t\t\t\tend""", """\t\t\t\tlocal ok, info = Store.dispatch({ type = "PURCHASE", id = item.id })
\t\t\t\tif ok then
\t\t\t\t\treceipt = info.receipt
\t\t\t\t\tUI.sfx("reward")
\t\t\t\t\tgo("success")
\t\t\t\telseif info.reason == "offline" then
\t\t\t\t\tgo("error")
\t\t\t\telse
\t\t\t\t\t-- owned meanwhile, not enough credits or level: the sheet explains it
\t\t\t\t\tUI.sfx("error")
\t\t\t\t\tgo("detail")
\t\t\t\tend""")
edit(SH, """\tmodal = UI.modal({ title = item.name, eyebrow = "Tienda", width = 620, build = function() end })
\tgo("detail")""", """\tlocal watch
\tmodal = UI.modal({ title = item.name, eyebrow = "Tienda", width = 620, build = function() end, onClose = function()
\t\tif watch then
\t\t\twatch:Disconnect()
\t\tend
\tend })
\tgo("detail")
\t-- keep the sheet truthful if balance, ownership or connection change while it is open
\twatch = Store.changed:Connect(function(a)
\t\tlocal t = a.type
\t\tif t == "PURCHASE" or t == "DEMO_CREDITS" or t == "NET" or t == "EQUIP" or t == "SET_FINISH" or t == "CLAIM_MISSION" or t == "MATCH_END" then
\t\t\tif step == "detail" then
\t\t\t\tgo("detail")
\t\t\telseif step == "confirm" and not Store.canBuy(item) then
\t\t\t\tgo("detail")
\t\t\tend
\t\tend
\tend)""")
MS = RS / "Screens" / "Tabs" / "Missions.module.luau"
edit(MS, "edge = st.claimable and C.brass:Lerp(C.ink700, 0.35) or C.ink700", "edge = st.claimable and C.brass:Lerp(C.ink700, 0.68) or C.ink700")
edit(MS, 'Theme and C.paper or C.paper,', 'C.paper,')

# ---------------------------------------------------------------- client
edit(CLIENT, '}, { edge = status == "offline" and Theme.color.bad or Theme.color.warn, pad = 8, cut = 0.3 })',
     '}, { edge = (status == "offline" and Theme.color.bad or Theme.color.warn):Lerp(Theme.color.ink600, 0.55), pad = 8, cut = 0.3 })')
edit(CLIENT, "-- showcase panel (separate ScreenGui, hidden in capture mode)", """-- Development bridge for automated checks and reproducible captures from Studio tools (client only,
-- lives in PlayerGui, never replicated). Invoke("state") / ("dispatch", action) / ("match", action).
local bridge = Instance.new("BindableFunction")
bridge.Name = "PivotDevBridge"
bridge.OnInvoke = function(cmd, arg)
\tlocal s = Store.state
\tif cmd == "dispatch" then
\t\tlocal ok, info = Store.dispatch(arg)
\t\treturn { ok = ok, info = info }
\telseif cmd == "match" then
\t\tif app.match then
\t\t\tapp.match.step(arg)
\t\t\treturn true
\t\tend
\t\treturn false
\telseif cmd == "closeModal" then
\t\tUI.closeModalSilently()
\t\treturn true
\telseif cmd == "capture" then
\t\tworkspace:SetAttribute("PivotCapture", arg == true)
\t\treturn true
\telseif cmd == "modal" then
\t\treturn UI.modalOpen()
\tend
\tlocal missions = {}
\tfor id, mm in s.missions do
\t\tmissions[id] = mm.progress .. (mm.claimed and "C" or "")
\tend
\tlocal m = app.match and app.match.state
\treturn {
\t\tphase = s.phase, tab = s.tab, mm = s.mm.status, network = s.network, credits = s.profile.credits,
\t\tlevel = s.profile.level, xp = s.profile.xp, loadout = s.loadout, finishes = s.finishes, meReady = s.meReady,
\t\tparty = #s.party, purchases = #s.purchases, missions = missions, matchCount = s.matchCount, layout = UI.layout,
\t\ttouch = UI.touch, settings = s.settings,
\t\tmatch = m and { phase = m.phase, t = m.t, hp = m.me.hp, alive = m.me.alive, kills = m.me.kills, scores = m.scores, active = m.active, mag = m.slots[m.active].mag, weapon = m.slots[m.active].weapon, spectate = m.spectate } or nil,
\t\tconnections = Store.changed:count(),
\t}
end
bridge.Parent = playerGui

-- showcase panel (separate ScreenGui, hidden in capture mode)""")


def main():
    texts = {}
    missing = 0
    for path, old, new in EDITS:
        t = texts.get(path) or path.read_text()
        n = t.count(old)
        if n != 1:
            print(f"!! {path.name}: old text found {n} times: {old[:70]!r}")
            missing += 1
            continue
        texts[path] = t.replace(old, new)
    if missing:
        sys.exit(f"{missing} edits failed; nothing written")
    for path, t in texts.items():
        path.write_text(t)
    print(f"applied {len(EDITS)} edits to {len(texts)} files")


if __name__ == "__main__":
    main()
