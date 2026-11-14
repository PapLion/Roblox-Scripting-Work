-- Session state for the showcase (client only, simulated data, no DataStore).
-- Every change goes through Store.dispatch(action): it validates the action, mutates the state and fires
-- Store.changed(action, info). Screens only read the state and dispatch; they never edit it directly.
-- Rules that matter for the demo flows are enforced here, not in the buttons:
--   * a purchase can't happen twice, without funds, below the level or while offline;
--   * a mission reward can be claimed exactly once;
--   * match rewards are paid once per match (MATCH_END only works while a match is running).

local PivotUI = script.Parent
local Util = require(PivotUI.Util)
local Catalog = require(PivotUI.Data.Catalog)
local World = require(PivotUI.Data.World)

local Store = {}
Store.changed = Util.signal()

Store.defaultSettings = {
	audio = { master = 70, effects = 80, music = 50 },
	graphics = { quality = "high", fov = 80, fpsLimit = "60" },
	controls = { sensitivity = 1.0, invertY = false, touch = "auto" },
	interface = { hudScale = 100, crosshair = "cross", crosshairSize = 100, crosshairColor = "white", killfeed = true, damageNumbers = true },
	accessibility = { reducedMotion = false, colorblind = false, screenShake = true },
}

function Store.xpToNext(level: number): number
	return 800 + level * 200
end

function Store.addXp(level: number, xp: number, gained: number)
	local l, x, levels = level, xp + gained, 0
	while x >= Store.xpToNext(l) do
		x -= Store.xpToNext(l)
		l += 1
		levels += 1
	end
	return l, x, levels
end

local function freshState()
	local owned = {}
	for _, id in Catalog.startingOwned do
		owned[id] = true
	end
	local missions = {}
	for _, m in World.missions do
		missions[m.id] = { progress = m.start, claimed = false }
	end
	return {
		phase = "boot", -- boot | title | lobby | match | results
		tab = "home", -- home | play | armory | shop | missions | profile | settings
		introSeen = false,
		profile = {
			name = "Nova_Pivot",
			level = 6,
			xp = 1350,
			credits = 3200,
			banner = "grid",
			emblem = "pivot",
			stats = { matches = 41, wins = 19, kills = 612, deaths = 571, assists = 233, damage = 98450, shots = 9820, hits = 4120, weaponKills = { kite = 498, tern = 114 } },
			history = Util.deepCopy(World.seedHistory),
		},
		owned = owned,
		loadout = Util.deepCopy(Catalog.startingLoadout),
		finishes = {}, -- weaponId -> finishId
		missions = missions,
		purchases = {},
		settings = Util.deepCopy(Store.defaultSettings),
		play = { mode = "teams", map = "dock9" },
		party = Util.deepCopy(World.startingParty),
		meReady = false,
		invites = {}, -- friendId -> pending | accepted | declined
		network = "online", -- online | reconnecting | offline
		mm = { status = "idle", id = 0 }, -- idle | searching | failed | found | accepted | loading
		match = nil,
		matchCount = 0,
		lastResult = nil,
		demo = { nextSearchFails = false, persistentDrop = false },
	}
end

Store.state = freshState()

---------------------------------------------------------------- selectors
function Store.owns(id: string): boolean
	return Store.state.owned[id] == true
end

function Store.isEquipped(id: string): boolean
	local s = Store.state
	local item = Catalog.get(id)
	if not item then
		return false
	end
	if item.kind == "weapon" or item.kind == "support" then
		return s.loadout[item.slot] == id
	elseif item.kind == "banner" then
		return s.profile.banner == id
	elseif item.kind == "emblem" then
		return s.profile.emblem == id
	elseif item.kind == "finish" then
		for _, f in s.finishes do
			if f == id then
				return true
			end
		end
		return id == "factory"
	end
	return false
end

function Store.finishOf(weaponId: string): string
	return Store.state.finishes[weaponId] or "factory"
end

function Store.isLocked(item): boolean
	return (item.unlockLevel or 1) > Store.state.profile.level
end

-- Why an item can or can't be bought right now. The shop uses it for its states; PURCHASE enforces it again.
function Store.canBuy(item)
	local s = Store.state
	if not item or not item.price or item.price <= 0 then
		return false, "unavailable"
	end
	if Store.owns(item.id) then
		return false, "owned"
	end
	if item.unlockLevel and s.profile.level < item.unlockLevel then
		return false, "level", item.unlockLevel
	end
	if s.profile.credits < item.price then
		return false, "funds", item.price - s.profile.credits
	end
	if s.network ~= "online" then
		return false, "offline"
	end
	return true
end

function Store.missionState(m)
	local cur = Store.state.missions[m.id]
	local progress = math.min(cur.progress, m.target)
	local done = progress >= m.target
	return {
		progress = progress,
		claimed = cur.claimed,
		done = done,
		claimable = done and not cur.claimed,
		status = cur.claimed and "claimed" or (done and "completed" or "progress"),
	}
end

function Store.claimableCount(): number
	local n = 0
	for _, m in World.missions do
		if Store.missionState(m).claimable then
			n += 1
		end
	end
	return n
end

function Store.rewardText(m): string
	local parts = {}
	if m.reward.xp then
		table.insert(parts, Util.num(m.reward.xp) .. " XP")
	end
	if m.reward.credits then
		table.insert(parts, Util.num(m.reward.credits) .. " créditos")
	end
	if m.reward.item then
		local item = Catalog.get(m.reward.item)
		table.insert(parts, Catalog.kindName[item.kind] .. " «" .. item.name .. "»")
	end
	return table.concat(parts, " · ")
end

function Store.partyAllReady(): boolean
	local s = Store.state
	if not s.meReady then
		return false
	end
	if World.mode(s.play.mode).maxParty == 1 then
		return true -- solo modes: the party waits in the lobby
	end
	for _, p in s.party do
		if not p.ready then
			return false
		end
	end
	return true
end

function Store.mmBusy(): boolean
	local st = Store.state.mm.status
	return st == "searching" or st == "found" or st == "accepted" or st == "loading"
end

-- XP / credits for a finished match summary.
function Store.matchRewards(summary)
	local mode = World.mode(summary.mode)
	if not mode.counts then
		return { xp = 0, credits = 0, lines = {} }
	end
	local lines = { { label = "Partida completada", xp = mode.rewards.xp, credits = mode.rewards.credits } }
	if summary.result == "victory" then
		table.insert(lines, { label = "Victoria", xp = mode.rewards.winXp, credits = mode.rewards.winCredits })
	end
	if summary.kills > 0 then
		table.insert(lines, { label = "Eliminaciones ×" .. summary.kills, xp = summary.kills * 25, credits = summary.kills * 5 })
	end
	if summary.assists > 0 then
		table.insert(lines, { label = "Asistencias ×" .. summary.assists, xp = summary.assists * 10, credits = 0 })
	end
	local xp, credits = 0, 0
	for _, l in lines do
		xp += l.xp
		credits += l.credits
	end
	return { xp = xp, credits = credits, lines = lines }
end

local function missionDelta(m, summary): number
	if m.mode and m.mode ~= summary.mode then
		return 0
	end
	if m.stat == "matches" then
		return 1
	elseif m.stat == "wins" then
		return summary.result == "victory" and 1 or 0
	elseif m.stat == "kills" then
		if m.weapon then
			return summary.weaponKills[m.weapon] or 0
		end
		return summary.kills
	end
	return 0
end

local function bumpFinishMission(s)
	for _, m in World.missions do
		if m.stat == "finishEquipped" then
			local cur = s.missions[m.id]
			if cur.progress < m.target then
				cur.progress += 1
				return m
			end
		end
	end
	return nil
end

local function setFinish(s, weaponId, finishId)
	local weapon = Catalog.get(weaponId)
	if not weapon or weapon.kind ~= "weapon" or not s.owned[weaponId] or not s.owned[finishId] then
		return false
	end
	if (s.finishes[weaponId] or "factory") == finishId then
		return false
	end
	s.finishes[weaponId] = finishId ~= "factory" and finishId or nil
	local mission = finishId ~= "factory" and bumpFinishMission(s) or nil
	return true, { weapon = weaponId, finish = finishId, mission = mission and mission.id }
end

---------------------------------------------------------------- reducer
local handlers = {}

function handlers.BOOT_DONE(s)
	if s.phase ~= "boot" then
		return false
	end
	s.phase = "title"
	return true
end

function handlers.ENTER_LOBBY(s)
	if s.phase ~= "title" then
		return false
	end
	s.phase = "lobby"
	s.tab = "home"
	return true
end

function handlers.DISMISS_INTRO(s)
	if s.introSeen then
		return false
	end
	s.introSeen = true
	return true
end

function handlers.NAV(s, a)
	if s.phase ~= "lobby" or s.tab == a.tab then
		return false
	end
	s.tab = a.tab
	return true
end

function handlers.SET_MODE(s, a)
	if Store.mmBusy() or s.play.mode == a.mode then
		return false
	end
	local maps = World.mapsFor(a.mode)
	local keep = false
	for _, m in maps do
		if m.id == s.play.map then
			keep = true
		end
	end
	s.play.mode = a.mode
	if not keep then
		s.play.map = maps[1].id
	end
	if s.mm.status == "failed" then
		s.mm = { status = "idle", id = s.mm.id }
	end
	return true
end

function handlers.SET_MAP(s, a)
	if Store.mmBusy() or s.play.map == a.map then
		return false
	end
	for _, m in World.mapsFor(s.play.mode) do
		if m.id == a.map then
			s.play.map = a.map
			return true
		end
	end
	return false
end

-- party (simulated) -------------------------------------------------
function handlers.INVITE(s, a)
	local f = World.friend(a.id)
	if not f or f.status ~= "online" or #s.party >= 3 or s.invites[a.id] == "pending" then
		return false
	end
	for _, p in s.party do
		if p.id == a.id then
			return false
		end
	end
	s.invites[a.id] = "pending"
	return true, { name = f.name }
end

function handlers.INVITE_RESOLVE(s, a)
	if s.invites[a.id] ~= "pending" then
		return false
	end
	local f = World.friend(a.id)
	if f.accepts and #s.party < 3 then
		s.invites[a.id] = "accepted"
		table.insert(s.party, { id = f.id, ready = false })
		return true, { accepted = true, name = f.name }
	end
	s.invites[a.id] = "declined"
	return true, { accepted = false, name = f.name }
end

function handlers.KICK(s, a)
	if Store.mmBusy() then
		return false
	end
	for i, p in s.party do
		if p.id == a.id then
			table.remove(s.party, i)
			s.invites[a.id] = nil
			return true, { name = World.friend(a.id).name }
		end
	end
	return false
end

-- "Salir del grupo": you leave and keep playing solo.
function handlers.LEAVE_PARTY(s)
	if #s.party == 0 or Store.mmBusy() then
		return false
	end
	s.party = {}
	s.invites = {}
	return true
end

function handlers.SET_READY(s, a)
	for _, p in s.party do
		if p.id == a.id and p.ready ~= a.ready then
			p.ready = a.ready
			return true
		end
	end
	return false
end

function handlers.ME_READY(s, a)
	if s.meReady == a.ready or (not a.ready and Store.mmBusy()) then
		return false
	end
	s.meReady = a.ready
	return true
end

-- matchmaking (timers live in Sim; here only valid transitions are accepted) ----------
function handlers.MM_START(s)
	if Store.mmBusy() or s.network ~= "online" or s.phase ~= "lobby" or not Store.partyAllReady() then
		return false
	end
	if s.play.mode == "training" then
		return false
	end
	local fails = s.demo.nextSearchFails
	s.demo.nextSearchFails = false
	s.mm = { status = "searching", id = s.mm.id + 1, startedAt = os.clock(), mode = s.play.mode, map = s.play.map, fails = fails }
	return true
end

function handlers.MM_CANCEL(s)
	local st = s.mm.status
	if st ~= "searching" and st ~= "failed" then
		return false
	end
	s.mm = { status = "idle", id = s.mm.id }
	return true, { was = st }
end

function handlers.MM_FOUND(s, a)
	if s.mm.status ~= "searching" or s.mm.id ~= a.id then
		return false
	end
	s.mm.status = "found"
	s.mm.foundAt = os.clock()
	return true
end

function handlers.MM_FAIL(s, a)
	if s.mm.status ~= "searching" or s.mm.id ~= a.id then
		return false
	end
	s.mm.status = "failed"
	return true
end

function handlers.MM_ACCEPT(s)
	if s.mm.status ~= "found" then
		return false
	end
	s.mm.status = "accepted"
	return true
end

function handlers.MM_DECLINE(s, a)
	if s.mm.status ~= "found" then
		return false
	end
	s.mm = { status = "idle", id = s.mm.id }
	return true, { expired = a.expired == true }
end

function handlers.MM_LOADING(s, a)
	if s.mm.status ~= "accepted" or s.mm.id ~= a.id then
		return false
	end
	s.mm.status = "loading"
	return true
end

function handlers.TRAINING_START(s)
	if s.phase ~= "lobby" or Store.mmBusy() or s.network ~= "online" then
		return false
	end
	s.mm = { status = "loading", id = s.mm.id + 1, mode = "training", map = "range" }
	return true
end

function handlers.MATCH_START(s, a)
	if s.phase ~= "lobby" or s.mm.status ~= "loading" then
		return false
	end
	s.phase = "match"
	s.match = a.config
	s.mm = { status = "idle", id = s.mm.id }
	s.matchCount += 1
	s.lastResult = nil
	return true
end

function handlers.MATCH_ABANDON(s)
	if s.phase ~= "match" then
		return false
	end
	s.phase = "lobby"
	s.tab = "home"
	s.match = nil
	s.meReady = false
	return true
end

function handlers.MATCH_END(s, a)
	if s.phase ~= "match" then
		return false -- never pay out twice
	end
	local sum = a.summary
	local mode = World.mode(sum.mode)
	local rewards = Store.matchRewards(sum)
	local p = s.profile
	local before = { level = p.level, xp = p.xp, credits = p.credits }
	local level, xp, levels = Store.addXp(p.level, p.xp, rewards.xp)
	local changes = {}
	if mode.counts then
		for _, m in World.missions do
			local cur = s.missions[m.id]
			local delta = missionDelta(m, sum)
			if delta > 0 and not cur.claimed and cur.progress < m.target then
				local nextValue = math.min(m.target, cur.progress + delta)
				table.insert(changes, { id = m.id, title = m.title, from = cur.progress, to = nextValue, target = m.target, completed = nextValue >= m.target })
				cur.progress = nextValue
			end
		end
		local st = p.stats
		st.matches += 1
		st.wins += sum.result == "victory" and 1 or 0
		st.kills += sum.kills
		st.deaths += sum.deaths
		st.assists += sum.assists
		st.damage += sum.damage
		st.shots += sum.shots
		st.hits += sum.hits
		for w, k in sum.weaponKills do
			st.weaponKills[w] = (st.weaponKills[w] or 0) + k
		end
		table.insert(p.history, 1, { mode = sum.mode, map = sum.map, result = sum.result, k = sum.kills, d = sum.deaths, a = sum.assists, score = sum.score, scores = sum.scores, when = "Ahora" })
		while #p.history > 8 do
			table.remove(p.history)
		end
	end
	-- unlocks reached by levelling up in this match
	local unlocks = {}
	if levels > 0 then
		for _, item in Catalog.gear() do
			if item.unlockLevel and item.unlockLevel > before.level and item.unlockLevel <= level then
				table.insert(unlocks, item.id)
			end
		end
	end
	p.level, p.xp, p.credits = level, xp, p.credits + rewards.credits
	s.phase = "results"
	s.match = nil
	s.meReady = false
	s.lastResult = {
		summary = sum,
		rewards = rewards,
		before = before,
		after = { level = level, xp = xp, credits = p.credits },
		levels = levels,
		missionChanges = changes,
		unlocks = unlocks,
	}
	return true
end

function handlers.RESULTS_CONTINUE(s)
	if s.phase ~= "results" then
		return false
	end
	s.phase = "lobby"
	s.tab = "home"
	return true
end

-- economy -------------------------------------------------------------
function handlers.PURCHASE(s, a)
	local item = Catalog.get(a.id)
	local ok, reason, extra = Store.canBuy(item)
	if not ok then
		return false, { reason = reason, extra = extra }
	end
	local receipt = {
		code = string.format("PV-%04d", 1001 + #s.purchases),
		item = item.id,
		price = item.price,
		before = s.profile.credits,
		after = s.profile.credits - item.price,
		when = os.date("%d/%m %H:%M"),
	}
	s.profile.credits = receipt.after
	s.owned[item.id] = true
	table.insert(s.purchases, 1, receipt)
	return true, { receipt = receipt }
end

function handlers.EQUIP(s, a)
	local item = Catalog.get(a.id)
	if not item or not s.owned[item.id] then
		return false, { reason = "notOwned" }
	end
	if item.kind == "weapon" or item.kind == "support" then
		if s.loadout[item.slot] == item.id then
			return false, { reason = "already" }
		end
		s.loadout[item.slot] = item.id
		return true, { slot = item.slot }
	elseif item.kind == "banner" then
		if s.profile.banner == item.id then
			return false, { reason = "already" }
		end
		s.profile.banner = item.id
		return true
	elseif item.kind == "emblem" then
		if s.profile.emblem == item.id then
			return false, { reason = "already" }
		end
		s.profile.emblem = item.id
		return true
	elseif item.kind == "finish" then
		return setFinish(s, a.weapon or s.loadout.primary, item.id)
	end
	return false
end

function handlers.SET_FINISH(s, a)
	return setFinish(s, a.weapon, a.finish)
end

function handlers.CLAIM_MISSION(s, a)
	local m
	for _, x in World.missions do
		if x.id == a.id then
			m = x
		end
	end
	if not m then
		return false
	end
	if s.network ~= "online" then
		return false, { reason = "offline" }
	end
	if not Store.missionState(m).claimable then
		return false, { reason = "notClaimable" } -- a claimed reward can never be claimed again
	end
	local p = s.profile
	local level, xp, levels = Store.addXp(p.level, p.xp, m.reward.xp or 0)
	s.missions[m.id].claimed = true
	p.level, p.xp = level, xp
	p.credits += m.reward.credits or 0
	if m.reward.item then
		s.owned[m.reward.item] = true
	end
	return true, { mission = m, levels = levels, level = level }
end

-- settings --------------------------------------------------------------
function handlers.SETTINGS_APPLY(s, a)
	if Util.equal(s.settings, a.settings) then
		return false
	end
	s.settings = Util.deepCopy(a.settings)
	return true
end

-- network + showcase controls ------------------------------------------
function handlers.NET(s, a)
	if s.network == a.status then
		return false
	end
	local cancelled = a.status ~= "online" and s.mm.status == "searching"
	s.network = a.status
	if cancelled then
		s.mm = { status = "idle", id = s.mm.id }
	end
	return true, { cancelledSearch = cancelled }
end

function handlers.DEMO(s, a)
	for k, v in a.patch do
		s.demo[k] = v
	end
	return true
end

function handlers.DEMO_CREDITS(s, a)
	s.profile.credits = math.max(0, s.profile.credits + a.amount)
	return true
end

function handlers.DEMO_COMPLETE_MISSIONS(s)
	for _, m in World.missions do
		local cur = s.missions[m.id]
		if not cur.claimed then
			cur.progress = m.target
		end
	end
	return true
end

-- Full reset of the demo data, keeping the player in the lobby (or title) so the showcase continues.
function handlers.RESET(s)
	local keepPhase = s.phase
	local fresh = freshState()
	for k in s do
		s[k] = nil
	end
	for k, v in fresh do
		s[k] = v
	end
	s.phase = (keepPhase == "boot" or keepPhase == "title") and keepPhase or "lobby"
	return true
end

function Store.dispatch(action)
	local handler = handlers[action.type]
	if not handler then
		warn("[PIVOT] unknown action", action.type)
		return false
	end
	local ok, info = handler(Store.state, action)
	if ok then
		Store.changed:Fire(action, info or {})
	end
	return ok, info or {}
end

return Store
