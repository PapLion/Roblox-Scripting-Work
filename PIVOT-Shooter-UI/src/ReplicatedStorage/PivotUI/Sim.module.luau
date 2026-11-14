-- Simulated "backend": party members getting ready, invitations, matchmaking and the connection.
-- Everything is local, deterministic and timer based. Each timer checks the matchmaking id before acting,
-- so a cancelled or repeated search can never fire a stale result (no duplicated screens or rewards).

local PivotUI = script.Parent
local Store = require(PivotUI.State)
local World = require(PivotUI.Data.World)
local Util = require(PivotUI.Util)

local Sim = {}
Sim.events = Util.signal() -- (kind, data) for toasts: "invite", "mm-expired", "net", ...
Sim.ACCEPT_WINDOW = 10
Sim.FAIL_AFTER = 7
Sim.LOADING_TIME = 2.6
Sim.buildMatchConfig = nil -- set by the client (Match.Engine.configFromState)

local started = false
local netToken = 0

-- How many of the other players have accepted, simulated from the time since the match was found.
function Sim.othersAccepted(): (number, number)
	local mm = Store.state.mm
	local mode = World.mode(mm.mode or Store.state.play.mode)
	local total = mode.teamSize * 2
	if mm.status ~= "found" and mm.status ~= "accepted" and mm.status ~= "loading" then
		return 0, total
	end
	local t = os.clock() - (mm.foundAt or os.clock())
	local others = total - 1
	local n = math.clamp(math.floor((t - 0.5) / 0.45) + 1, 0, others)
	local me = (mm.status == "accepted" or mm.status == "loading") and 1 or 0
	return n + me, total
end

local function readyStagger()
	local s = Store.state
	local delayTime = 1.4
	for _, p in s.party do
		if not p.ready then
			local id = p.id
			task.delay(delayTime, function()
				if Store.state.meReady then
					Store.dispatch({ type = "SET_READY", id = id, ready = true })
				end
			end)
			delayTime += 1.1
		end
	end
end

local function onSearch()
	local mm = Store.state.mm
	local id = mm.id
	local mode = World.mode(mm.mode)
	if mm.fails then
		task.delay(Sim.FAIL_AFTER, function()
			Store.dispatch({ type = "MM_FAIL", id = id })
		end)
	else
		task.delay(mode.queue, function()
			Store.dispatch({ type = "MM_FOUND", id = id })
		end)
	end
end

local function onFound()
	local id = Store.state.mm.id
	task.delay(Sim.ACCEPT_WINDOW, function()
		local mm = Store.state.mm
		if mm.id == id and mm.status == "found" then
			Store.dispatch({ type = "MM_DECLINE", expired = true })
		end
	end)
end

local function onAccepted()
	local mm = Store.state.mm
	local id = mm.id
	local _, total = Sim.othersAccepted()
	-- wait until every simulated player has accepted, then load the map
	local elapsed = os.clock() - (mm.foundAt or os.clock())
	local allIn = 0.5 + 0.45 * (total - 1)
	task.delay(math.max(0.6, allIn - elapsed + 0.4), function()
		Store.dispatch({ type = "MM_LOADING", id = id })
	end)
end

local function onLoading()
	local id = Store.state.mm.id
	task.delay(Sim.LOADING_TIME, function()
		local s = Store.state
		if s.mm.status ~= "loading" or s.mm.id ~= id then
			return
		end
		local config = Sim.buildMatchConfig and Sim.buildMatchConfig(s) or {}
		Store.dispatch({ type = "MATCH_START", config = config })
	end)
end

function Sim.start()
	if started then
		return
	end
	started = true
	Store.changed:Connect(function(action, info)
		local t = action.type
		if t == "ME_READY" and action.ready then
			readyStagger()
		elseif t == "INVITE" then
			local id = action.id
			task.delay(1.8, function()
				Store.dispatch({ type = "INVITE_RESOLVE", id = id })
			end)
		elseif t == "INVITE_RESOLVE" then
			Sim.events:Fire(info.accepted and "invite-accepted" or "invite-declined", info)
			if info.accepted then
				local id = action.id
				task.delay(2.2, function()
					Store.dispatch({ type = "SET_READY", id = id, ready = true })
				end)
			end
		elseif t == "MM_START" then
			onSearch()
		elseif t == "MM_FOUND" then
			onFound()
		elseif t == "MM_ACCEPT" then
			onAccepted()
		elseif t == "MM_LOADING" or t == "TRAINING_START" then
			onLoading()
		elseif t == "MM_DECLINE" then
			Sim.events:Fire(info.expired and "mm-expired" or "mm-declined", info)
		elseif t == "NET" and info.cancelledSearch then
			Sim.events:Fire("mm-offline", info)
		end
	end)
end

-- Simulated disconnect: three reconnection attempts; recovers unless `persistent` (then stays offline).
function Sim.dropConnection(persistent: boolean?)
	netToken += 1
	local token = netToken
	Store.dispatch({ type = "DEMO", patch = { persistentDrop = persistent == true } })
	Store.dispatch({ type = "NET", status = "reconnecting" })
	Sim.events:Fire("net", { status = "reconnecting", attempt = 1 })
	task.spawn(function()
		for attempt = 2, 3 do
			task.wait(1.5)
			if token ~= netToken then
				return
			end
			Sim.events:Fire("net", { status = "reconnecting", attempt = attempt })
		end
		task.wait(1.5)
		if token ~= netToken then
			return
		end
		local status = Store.state.demo.persistentDrop and "offline" or "online"
		Store.dispatch({ type = "NET", status = status })
		Sim.events:Fire("net", { status = status })
	end)
end

-- "Reintentar" from the offline banner.
function Sim.retryConnection()
	netToken += 1
	local token = netToken
	Store.dispatch({ type = "DEMO", patch = { persistentDrop = false } })
	Store.dispatch({ type = "NET", status = "reconnecting" })
	Sim.events:Fire("net", { status = "reconnecting", attempt = 1 })
	task.delay(1.6, function()
		if token ~= netToken then
			return
		end
		Store.dispatch({ type = "NET", status = "online" })
		Sim.events:Fire("net", { status = "online" })
	end)
end

function Sim.cancelNetwork()
	netToken += 1
end

return Sim
