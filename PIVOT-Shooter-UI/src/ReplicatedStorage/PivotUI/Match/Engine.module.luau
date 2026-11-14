-- Simulated match: a seeded state machine. No real networking or ballistics; the HUD and the 3D stage
-- react to its state and to the events it queues (m.events). Same seed + same inputs = same match.
-- Time is in seconds. Engine.step(m, action) mutates the match table.

local PivotUI = script.Parent.Parent
local Catalog = require(PivotUI.Data.Catalog)
local World = require(PivotUI.Data.World)
local Util = require(PivotUI.Util)

local Engine = {}
Engine.INTRO = 3.0
local RESPAWN = { duel = 3, teams = 5, training = 2 }
local BOT_WEAPONS = { "kite", "anvil", "wasp", "lance" }

Engine.noticeText = {
	go = "¡Adelante!", trainingGo = "Campo de tiro abierto", firstBlood = "Primera sangre", double = "Doble eliminación",
	triple = "Triple eliminación", streak5 = "Racha de 5", leadTaken = "Tu equipo va en cabeza", leadLost = "Los rivales toman la delantera",
	matchPointUs = "Una eliminación para ganar", matchPointThem = "Una eliminación para perder", lowAmmo = "Munición baja",
	armorBroken = "Armadura rota", ammoRefilled = "Munición repuesta", healed = "+50 de vida", assist = "Asistencia",
	oneMinute = "Queda 1 minuto", scriptStart = "Guion de demostración en marcha", noReserve = "Sin munición en reserva",
	supportUsed = "Apoyo ya usado en esta vida",
}
Engine.noticeTone = {
	go = "info", trainingGo = "info", firstBlood = "good", double = "good", triple = "good", streak5 = "good", leadTaken = "good",
	leadLost = "bad", matchPointUs = "warn", matchPointThem = "warn", lowAmmo = "warn", armorBroken = "bad", ammoRefilled = "good",
	healed = "good", assist = "good", oneMinute = "warn", scriptStart = "info", noReserve = "bad", supportUsed = "info",
}

function Engine.pickNames(seed: number, count: number, exclude)
	local r = Util.rng(seed)
	local pool = {}
	for _, n in World.names do
		if not (exclude and table.find(exclude, n)) then
			table.insert(pool, n)
		end
	end
	local out = {}
	while #out < count and #pool > 0 do
		table.insert(out, table.remove(pool, math.floor(r() * #pool) + 1))
	end
	return out
end

-- Builds the match config from the session state (party friends become teammates in Equipos).
function Engine.configFromState(s)
	local mode = World.mode(s.mm.mode or s.play.mode)
	local seed = 1000 + s.matchCount * 7919
	local allies, enemies = {}, {}
	if mode.id == "teams" then
		for _, p in s.party do
			local f = World.friend(p.id)
			if f then
				table.insert(allies, f.name)
			end
		end
		local fill = Engine.pickNames(seed, 3 - #allies + 4)
		for i = 1, 3 - #allies do
			table.insert(allies, fill[i])
		end
		for i = #fill - 3, #fill do
			table.insert(enemies, fill[i])
		end
	elseif mode.id == "duel" then
		enemies = Engine.pickNames(seed, 1)
	end
	return {
		seed = seed,
		mode = mode.id,
		map = s.mm.map or s.play.map,
		me = { name = s.profile.name, banner = s.profile.banner, emblem = s.profile.emblem, level = s.profile.level },
		loadout = table.clone(s.loadout),
		finishes = table.clone(s.finishes),
		allies = allies,
		enemies = enemies,
	}
end

local function slotFor(weaponId)
	local w = Catalog.get(weaponId)
	return { weapon = weaponId, mag = w.stats.mag, reserve = w.stats.reserve }
end

function Engine.new(config)
	local mode = World.mode(config.mode)
	local r = Util.rng(config.seed)
	local function pick(list)
		return list[math.floor(r() * #list) + 1]
	end
	local roster = { { id = "me", name = config.me.name, team = "ally", k = 0, d = 0, a = 0, me = true, weapon = config.loadout.primary, level = config.me.level } }
	if mode.id == "training" then
		for i = 1, 3 do
			table.insert(roster, { id = "t" .. i, name = "Diana " .. ({ "10 m", "25 m", "50 m" })[i], team = "enemy", k = 0, d = 0, a = 0, bot = true })
		end
	else
		for i, name in config.allies do
			table.insert(roster, { id = "a" .. i, name = name, team = "ally", k = 0, d = 0, a = 0, weapon = pick(BOT_WEAPONS) })
		end
		for i, name in config.enemies do
			table.insert(roster, { id = "e" .. i, name = name, team = "enemy", k = 0, d = 0, a = 0, weapon = pick(BOT_WEAPONS) })
		end
	end
	local firstEnemy
	for _, p in roster do
		if p.team == "enemy" then
			firstEnemy = p
			break
		end
	end
	return {
		mode = mode.id,
		map = config.map,
		rng = r,
		t = 0,
		duration = mode.duration,
		limit = mode.scoreLimit,
		phase = "intro", -- intro | live | ended
		paused = false,
		scores = { ally = 0, enemy = 0 },
		roster = roster,
		me = { hp = 100, armor = 50, alive = true, respawnAt = 0, streak = 0, kills = 0, deaths = 0, assists = 0, damage = 0, shots = 0, hits = 0, weaponKills = {}, supportUsed = false, killedBy = nil },
		slots = { slotFor(config.loadout.primary), slotFor(config.loadout.secondary) },
		support = config.loadout.support,
		finishes = config.finishes or {},
		active = 1,
		reload = nil,
		switchUntil = 0,
		nextShotAt = 0,
		trigger = false,
		aiming = false,
		target = { id = firstEnemy and firstEnemy.id, hp = 100 },
		feed = {},
		notices = {},
		events = {},
		nextAmbientAt = Engine.INTRO + 4,
		nextThreatAt = Engine.INTRO + 7,
		ambient = true,
		spectate = nil,
		uid = 1,
		flags = { minute = false, leader = nil, firstBlood = false, lowAmmoWarned = false, matchPoint = false },
		script = nil,
		result = nil,
		pick = pick,
	}
end

local function remaining(d)
	return math.max(0, d.duration - d.t)
end
Engine.timeLeft = remaining

local function person(d, id)
	for _, p in d.roster do
		if p.id == id then
			return p
		end
	end
	return nil
end
Engine.person = person

local function event(d, kind, data)
	data = data or {}
	data.kind = kind
	data.t = d.t
	table.insert(d.events, data)
end

local function notice(d, key)
	for i = #d.notices, 1, -1 do
		if d.notices[i].key == key then
			table.remove(d.notices, i)
		end
	end
	d.uid += 1
	table.insert(d.notices, { id = d.uid, key = key, text = Engine.noticeText[key] or key, tone = Engine.noticeTone[key] or "info", at = d.t })
	while #d.notices > 3 do
		table.remove(d.notices, 1)
	end
end

local function feed(d, killer, victim, weapon)
	d.uid += 1
	table.insert(d.feed, { id = d.uid, killer = killer.name, kt = killer.team, victim = victim.name, vt = victim.team, weapon = weapon, me = killer.me or victim.me, at = d.t })
	while #d.feed > 5 do
		table.remove(d.feed, 1)
	end
end

local function finish(d, forced)
	if d.phase == "ended" then
		return
	end
	d.phase = "ended"
	d.trigger = false
	if d.mode == "training" then
		d.result = "complete"
	elseif forced then
		d.result = forced
	elseif d.scores.ally > d.scores.enemy then
		d.result = "victory"
	elseif d.scores.ally < d.scores.enemy then
		d.result = "defeat"
	else
		d.result = "draw"
	end
	event(d, "ended", { result = d.result })
end

local function checkLeader(d)
	if d.mode ~= "teams" then
		return
	end
	local leader = d.scores.ally > d.scores.enemy and "ally" or (d.scores.enemy > d.scores.ally and "enemy" or nil)
	if leader and leader ~= d.flags.leader then
		notice(d, leader == "ally" and "leadTaken" or "leadLost")
	end
	if leader then
		d.flags.leader = leader
	end
	local top = math.max(d.scores.ally, d.scores.enemy)
	if d.limit > 0 and top == d.limit - 1 and not d.flags.matchPoint then
		d.flags.matchPoint = true
		notice(d, d.scores.ally >= d.scores.enemy and "matchPointUs" or "matchPointThem")
	end
end

local function checkEnd(d)
	if d.limit > 0 and (d.scores.ally >= d.limit or d.scores.enemy >= d.limit) then
		finish(d)
	end
end

local function retarget(d)
	local enemies, others = {}, {}
	for _, p in d.roster do
		if p.team == "enemy" then
			table.insert(enemies, p)
			if p.id ~= d.target.id then
				table.insert(others, p)
			end
		end
	end
	local nextTarget = #others > 0 and d.pick(others) or enemies[1]
	d.target = { id = nextTarget and nextTarget.id, hp = 100 }
	event(d, "retarget", { id = d.target.id })
end

local function killTarget(d)
	local me = person(d, "me")
	local victim = person(d, d.target.id)
	local weapon = d.slots[d.active].weapon
	d.me.kills += 1
	d.me.streak += 1
	d.me.weaponKills[weapon] = (d.me.weaponKills[weapon] or 0) + 1
	me.k += 1
	if victim then
		victim.d += 1
		feed(d, me, victim, weapon)
	end
	if d.mode ~= "training" then
		d.scores.ally += 1
	end
	event(d, "kill", { victim = victim and victim.name, weapon = weapon, streak = d.me.streak })
	if not d.flags.firstBlood and d.mode ~= "training" then
		d.flags.firstBlood = true
		notice(d, "firstBlood")
	end
	if d.me.streak == 2 then
		notice(d, "double")
	elseif d.me.streak == 3 then
		notice(d, "triple")
	elseif d.me.streak == 5 then
		notice(d, "streak5")
	end
	retarget(d)
	checkLeader(d)
	checkEnd(d)
end

function Engine.canShoot(d)
	return d.phase == "live" and d.me.alive and not d.reload and d.t >= d.switchUntil and d.t >= d.nextShotAt and not d.paused
end

local function shoot(d, forceHit)
	if not Engine.canShoot(d) then
		return
	end
	local slot = d.slots[d.active]
	local w = Catalog.get(slot.weapon)
	if slot.mag <= 0 then
		event(d, "dry")
		d.trigger = false
		return
	end
	slot.mag -= 1
	d.me.shots += 1
	d.nextShotAt = d.t + 60 / w.stats.rpm
	event(d, "shot", { weapon = slot.weapon })
	if slot.mag > 0 and slot.mag <= math.ceil(w.stats.mag * 0.25) and not d.flags.lowAmmoWarned then
		d.flags.lowAmmoWarned = true
		notice(d, "lowAmmo")
	end
	local accuracy = w.accuracy + (d.aiming and 0.12 or 0)
	local hit = forceHit or d.rng() < accuracy
	if not hit then
		return
	end
	local pellets = 1
	if w.stats.pellets > 1 then
		pellets = math.max(3, math.round(3 + d.rng() * (w.stats.pellets - 3)))
	end
	local dmg = w.stats.damage * pellets
	d.me.hits += 1
	d.me.damage += dmg
	d.target.hp -= dmg
	event(d, "hit", { damage = dmg, lethal = d.target.hp <= 0 })
	if d.target.hp <= 0 then
		killTarget(d)
	end
end

local function startReload(d)
	local slot = d.slots[d.active]
	local w = Catalog.get(slot.weapon)
	if not d.me.alive or d.reload or slot.mag >= w.stats.mag or d.phase == "ended" then
		return
	end
	if slot.reserve <= 0 then
		notice(d, "noReserve")
		return
	end
	d.reload = { slot = d.active, start = d.t, untilT = d.t + w.stats.reload }
	d.trigger = false
	event(d, "reload")
end

local function finishReload(d)
	local slot = d.slots[d.reload.slot]
	local w = Catalog.get(slot.weapon)
	local take = math.min(w.stats.mag - slot.mag, slot.reserve)
	slot.mag += take
	slot.reserve -= take
	d.reload = nil
	d.flags.lowAmmoWarned = false
	event(d, "reloaded")
end

local function switchTo(d, idx)
	if not d.me.alive or idx == d.active or not d.slots[idx] or d.phase == "ended" then
		return
	end
	d.active = idx
	d.reload = nil
	d.trigger = false
	d.switchUntil = d.t + 0.45
	d.flags.lowAmmoWarned = false
	event(d, "switch", { weapon = d.slots[idx].weapon })
end

local function useSupport(d)
	if not d.me.alive or d.phase ~= "live" then
		return
	end
	if d.me.supportUsed then
		notice(d, "supportUsed")
		return
	end
	local item = Catalog.get(d.support)
	d.me.supportUsed = true
	if item.effect == "ammo" then
		for _, s in d.slots do
			s.reserve = Catalog.get(s.weapon).stats.reserve
		end
		notice(d, "ammoRefilled")
	else
		d.me.hp = math.min(100, d.me.hp + 50)
		notice(d, "healed")
	end
	event(d, "support", { item = item.id })
end

local function firstRealEnemy(d)
	for _, p in d.roster do
		if p.team == "enemy" and not p.bot then
			return p
		end
	end
	return nil
end

local function die(d, attackerId)
	local me = person(d, "me")
	local killer = (attackerId and person(d, attackerId)) or firstRealEnemy(d)
	d.me.alive = false
	d.me.hp = 0
	d.me.deaths += 1
	d.me.streak = 0
	d.me.killedBy = killer and { name = killer.name, weapon = killer.weapon, id = killer.id } or nil
	me.d += 1
	d.reload = nil
	d.trigger = false
	d.aiming = false
	d.me.respawnAt = d.t + RESPAWN[d.mode]
	if killer then
		killer.k += 1
		if d.mode ~= "training" then
			d.scores.enemy += 1
		end
		feed(d, killer, me, killer.weapon)
	end
	event(d, "death", { killer = killer and killer.name })
	checkLeader(d)
	checkEnd(d)
end

local function damageMe(d, amount, angle, attackerId)
	if not d.me.alive or d.phase ~= "live" then
		return
	end
	local absorbed = math.min(d.me.armor, amount * 0.6)
	local hadArmor = d.me.armor > 0
	d.me.armor = math.round(d.me.armor - absorbed)
	d.me.hp = math.max(0, math.round(d.me.hp - (amount - absorbed)))
	event(d, "damage", { angle = angle, amount = amount })
	if hadArmor and d.me.armor <= 0 then
		notice(d, "armorBroken")
	end
	if d.me.hp <= 0 then
		die(d, attackerId)
	end
end

local function respawn(d)
	d.me.alive = true
	d.me.hp = 100
	d.me.armor = 50
	d.me.supportUsed = false
	d.me.killedBy = nil
	for i, s in d.slots do
		d.slots[i] = slotFor(s.weapon)
	end
	d.active = 1
	d.spectate = nil
	d.switchUntil = d.t + 0.45
	d.flags.lowAmmoWarned = false
	event(d, "respawn")
end

local function ambientKill(d, forcedTeam)
	if d.mode ~= "teams" then
		return
	end
	local team = forcedTeam or (d.rng() < 0.5 and "ally" or "enemy")
	local killers, victims = {}, {}
	for _, p in d.roster do
		if not p.me then
			if p.team == team then
				table.insert(killers, p)
			else
				table.insert(victims, p)
			end
		end
	end
	if #killers == 0 or #victims == 0 then
		return
	end
	local killer, victim = d.pick(killers), d.pick(victims)
	killer.k += 1
	victim.d += 1
	d.scores[team] += 1
	if team == "ally" and d.me.alive and d.rng() < 0.3 then
		d.me.assists += 1
		person(d, "me").a += 1
		notice(d, "assist")
	end
	feed(d, killer, victim, killer.weapon)
	checkLeader(d)
	checkEnd(d)
end

function Engine.spectatable(d)
	local out = {}
	for _, p in d.roster do
		if p.team == "ally" and not p.me then
			table.insert(out, p)
		end
	end
	return out
end

-- Reproducible sequence that goes through every HUD state (showcase panel -> "Reproducir guion").
Engine.SCRIPT = {
	{ 0.0, { type = "NOTICE", key = "scriptStart" } },
	{ 0.6, { type = "DEMO_HIT" } },
	{ 0.9, { type = "DEMO_HIT" } },
	{ 1.3, { type = "DEMO_KILL" } },
	{ 2.3, { type = "DEMO_TEAM_KILL", team = "ally" } },
	{ 3.2, { type = "DEMO_DAMAGE", angle = -70, amount = 30 } },
	{ 4.3, { type = "DEMO_LOW_AMMO" } },
	{ 5.2, { type = "RELOAD" } },
	{ 7.8, { type = "SWITCH", slot = 2 } },
	{ 8.6, { type = "DEMO_HIT" } },
	{ 9.0, { type = "DEMO_KILL" } },
	{ 9.8, { type = "SWITCH", slot = 1 } },
	{ 10.6, { type = "DEMO_TEAM_KILL", team = "enemy" } },
	{ 11.4, { type = "DEMO_DAMAGE", angle = 160, amount = 40 } },
	{ 12.2, { type = "DEMO_DAMAGE", angle = 40, amount = 45 } },
	{ 13.0, { type = "DEMO_DEATH" } },
	{ 14.2, { type = "SPECTATE_START" } },
	{ 15.4, { type = "SPECTATE_NEXT", dir = 1 } },
	{ 16.6, { type = "SPECTATE_NEXT", dir = 1 } },
	{ 19.2, { type = "DEMO_KILL" } },
	{ 19.8, { type = "DEMO_KILL" } },
	{ 20.4, { type = "DEMO_KILL" } },
	{ 21.4, { type = "SUPPORT" } },
	{ 22.4, { type = "SET_TIME_LEFT", seconds = 61 } },
	{ 25.5, { type = "END" } },
}

local step

local function tick(d, dt)
	if d.paused or d.phase == "ended" then
		return
	end
	d.t += dt
	if d.phase == "intro" and d.t >= Engine.INTRO then
		d.phase = "live"
		notice(d, d.mode == "training" and "trainingGo" or "go")
		event(d, "live")
	end
	if d.script then
		local elapsed = d.t - d.script.start
		while d.script and d.script.idx <= #Engine.SCRIPT and Engine.SCRIPT[d.script.idx][1] <= elapsed do
			local a = Engine.SCRIPT[d.script.idx][2]
			d.script.idx += 1
			step(d, a)
			if d.phase == "ended" then
				break
			end
		end
		if d.script and d.script.idx > #Engine.SCRIPT then
			d.script = nil
		end
	end
	if d.phase ~= "live" then
		return
	end
	if d.reload and d.t >= d.reload.untilT then
		finishReload(d)
	end
	local w = Catalog.get(d.slots[d.active].weapon)
	if d.trigger and w.auto then
		shoot(d)
	end
	if not d.me.alive and d.t >= d.me.respawnAt then
		respawn(d)
	end
	if d.ambient and not d.script then
		if d.t >= d.nextAmbientAt then
			ambientKill(d)
			d.nextAmbientAt = d.t + 3.5 + d.rng() * 3
		end
		if d.mode ~= "training" and d.t >= d.nextThreatAt then
			local enemies = {}
			for _, p in d.roster do
				if p.team == "enemy" then
					table.insert(enemies, p)
				end
			end
			damageMe(d, math.round(14 + d.rng() * 18), math.round(-180 + d.rng() * 360), d.pick(enemies).id)
			local lo, hi = 4.5, 8.5
			if d.mode == "duel" then
				lo, hi = 3.5, 6.5
			end
			d.nextThreatAt = d.t + lo + d.rng() * (hi - lo)
		end
	end
	if not d.flags.minute and remaining(d) <= 60 and d.duration > 60 then
		d.flags.minute = true
		notice(d, "oneMinute")
	end
	if d.t >= d.duration then
		finish(d)
	end
	for i = #d.notices, 1, -1 do
		if d.t - d.notices[i].at > 2.8 then
			table.remove(d.notices, i)
		end
	end
end

step = function(d, a)
	local t = a.type
	if t == "PAUSE" then
		d.paused = a.paused
		d.trigger = false
		return d
	end
	if d.phase == "ended" then
		return d
	end
	if t == "TICK" then
		tick(d, a.dt)
	elseif t == "FIRE_DOWN" then
		d.trigger = true
		shoot(d)
	elseif t == "FIRE_UP" then
		d.trigger = false
	elseif t == "AIM" then
		d.aiming = a.on and d.me.alive and d.phase ~= "ended"
	elseif t == "RELOAD" then
		startReload(d)
	elseif t == "SWITCH" then
		switchTo(d, a.slot)
	elseif t == "SWAP" then
		switchTo(d, d.active == 1 and 2 or 1)
	elseif t == "SUPPORT" then
		useSupport(d)
	elseif t == "NOTICE" then
		notice(d, a.key)
	elseif t == "SPECTATE_START" then
		if not d.me.alive and #Engine.spectatable(d) > 0 then
			d.spectate = 1
			event(d, "spectate")
		end
	elseif t == "SPECTATE_STOP" then
		d.spectate = nil
		event(d, "spectate")
	elseif t == "SPECTATE_NEXT" then
		local list = Engine.spectatable(d)
		if d.spectate and #list > 0 then
			d.spectate = ((d.spectate - 1 + (a.dir or 1)) % #list) + 1
			event(d, "spectate")
		end
	elseif t == "SET_AMBIENT" then
		d.ambient = a.on
	elseif t == "PLAY_SCRIPT" then
		if d.phase == "intro" then
			d.t = Engine.INTRO
			d.phase = "live"
			event(d, "live")
		end
		d.script = { start = d.t, idx = 1 }
	elseif t == "DEMO_HIT" then
		if d.phase == "live" and d.me.alive then
			d.nextShotAt = 0
			d.reload = nil
			d.switchUntil = 0
			if d.slots[d.active].mag <= 0 then
				d.slots[d.active].mag = 1
			end
			shoot(d, true)
		end
	elseif t == "DEMO_KILL" then
		if d.phase == "live" and d.me.alive then
			d.target.hp = 1
			step(d, { type = "DEMO_HIT" })
		end
	elseif t == "DEMO_TEAM_KILL" then
		ambientKill(d, a.team)
	elseif t == "DEMO_DAMAGE" then
		local e = firstRealEnemy(d)
		damageMe(d, a.amount or 25, a.angle or 0, e and e.id)
	elseif t == "DEMO_DEATH" then
		if d.me.alive and d.phase == "live" then
			d.me.armor = 0
			local e = firstRealEnemy(d)
			damageMe(d, d.me.hp + 1, 180, e and e.id)
			if d.me.alive then
				die(d)
			end
		end
	elseif t == "DEMO_RESPAWN" then
		if not d.me.alive and d.phase == "live" then
			d.me.respawnAt = d.t
		end
	elseif t == "DEMO_LOW_AMMO" then
		local s = d.slots[d.active]
		s.mag = math.min(s.mag, math.max(1, math.ceil(Catalog.get(s.weapon).stats.mag * 0.15)))
		d.flags.lowAmmoWarned = true
		notice(d, "lowAmmo")
	elseif t == "SET_TIME_LEFT" then
		d.t = math.max(d.t, d.duration - a.seconds)
	elseif t == "END" then
		finish(d, a.result)
	end
	return d
end
Engine.step = step

-- Pops the queued events (the HUD and the stage consume them once per frame).
function Engine.drain(d)
	local ev = d.events
	d.events = {}
	return ev
end

function Engine.summarize(d)
	local function scoreOf(p)
		return p.k * 100 + p.a * 40
	end
	local roster = {}
	for _, p in d.roster do
		local c = table.clone(p)
		c.score = scoreOf(p)
		table.insert(roster, c)
	end
	table.sort(roster, function(a, b)
		return a.score > b.score
	end)
	local mvp = false
	for _, p in roster do
		if p.team == "ally" then
			mvp = p.me == true
			break
		end
	end
	local myScore = 0
	for _, p in roster do
		if p.me then
			myScore = p.score
		end
	end
	return {
		mode = d.mode,
		map = d.map,
		result = d.result,
		scores = { d.scores.ally, d.scores.enemy },
		kills = d.me.kills,
		deaths = d.me.deaths,
		assists = d.me.assists,
		damage = d.me.damage,
		shots = d.me.shots,
		hits = d.me.hits,
		score = myScore,
		weaponKills = table.clone(d.me.weaponKills),
		duration = math.min(d.t, d.duration),
		roster = roster,
		mvp = mvp,
	}
end

return Engine
