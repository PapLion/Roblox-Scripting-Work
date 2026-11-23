# Vellum RPG UI Library — checkpoint

Scope: UI component library only (no game, no world, no 3D, no backend). Local example state.

## Environment
- Worktree: `S:\Dev\Roblox-Scripting-Work\worktrees\rpg-ui-library` (branch `rpg-ui-library`, from origin/main, no upstream set; push with `-u origin rpg-ui-library`).
- PIVOT lives on branch `pivot-ui-and-3d-models` (PR #1, open) in `../../main`. Untouched.
- Studio: opened on `RPG-UI-Library/place/Vellum_RPG_UI_Library.rbxlx` (local file, not cloud).
- Dev sync: `python tools/build_place.py --serve` (port 34873), then in Studio (MCP execute_luau, Edit):
  `loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:34873/sync.luau", true))()`
  Preview a specimen in Edit mode: set `_G.VELLUM_PREVIEW = {id=...}` then load `/f/tools/preview.luau`.
- Art: `art/build_atlas.py` (needs resvg_py + Pillow; venv in session scratchpad) → `art/out/*`, `AtlasMap.module.luau`;
  `python art/install_local.py` copies hashed PNGs into Studio content (rbxasset://textures/vellum/...).

## Gotchas learned
- AutomaticSize measures nested scale-sized descendants: a visible child with `scale 1 + positive offset` inflates the
  auto-sized ancestor to its parent's bounds. Rule: no positive overhang under auto-sized frames; buttons use Create.fitWidth.
- UIGradient multiplies BackgroundColor3: use white background with gradient colours.
- Studio caches rbxasset textures by path → hashed filenames.
- AutomaticSize also counts deep descendants' overflow and UIStrokes → auto-height panels size from their
  UIListLayout.AbsoluteContentSize instead (Surface.panel autoSize).
- Patch tables can't carry nil → Store.NONE removes a key; Slot flags use false.
- Engine culls large 9-slice/gradient frames crossing a ClipsDescendants edge → tiled capture uses matte masks.
- Mouse tool coordinates = GuiObject.AbsolutePosition (viewport px), not screenshot px.

## Progress
- [x] Theme tokens, Core (Scope, Signal, Store, Motion, Create, Interact, Layers), Atlas + art pipeline, 56 icons + 44 glyphs + chrome
- [x] Button (5 variants × 7 states), Controls (icon button, toggle, checkbox/radio, segmented, tabs, slider, dropdown, search)
- [x] Feedback (tooltip, context menu, modal, toast, bar, radial/ring, tag, spinner, currency)
- [x] Slot + ItemCard, Inventory, Equipment/Character, SkillTree/Abilities, Quests, Crafting/Vendor, Loot/LevelUp (24 specimens)
- [x] Gallery app (browse, actions, reset, widths, capture) + VellumBridge; unit tests 12/12 (tools/tests.luau)
- [x] Play verification: drag/drop, context menu, modal+Esc, skill learn, vendor buy+slider, crafting, keyboard nav; no leaks over 72 switches
- [x] Capture pipeline (tiled 2x, batch.py) + 24 captures in captures/ (2026-11-22)
- [ ] Upload atlases for portability (optional), README
- [ ] Website /ui integration (Portafolio-Panda), PRs, merge, deploy verify
