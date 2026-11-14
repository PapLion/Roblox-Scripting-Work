-- Modes, maps, simulated players, missions and news. All of it is sample data for the showcase.

local World = {}

World.modes = {
	{
		id = "teams", name = "Equipos", short = "4v4", teamSize = 4, maxParty = 4, scoreLimit = 20, duration = 180, queue = 6,
		desc = "Dos equipos de cuatro. Gana el primero en llegar a 20 eliminaciones.",
		objective = "Primer equipo en llegar a 20", players = "8 jugadores · 4 contra 4", length = "3 min",
		rewards = { xp = 400, winXp = 250, credits = 150, winCredits = 100 }, counts = true,
	},
	{
		id = "duel", name = "Duelo", short = "1v1", teamSize = 1, maxParty = 1, scoreLimit = 5, duration = 120, queue = 4,
		desc = "Uno contra uno en un mapa reducido. Gana quien consiga 5 eliminaciones.",
		objective = "Primero en llegar a 5", players = "2 jugadores · 1 contra 1", length = "2 min",
		rewards = { xp = 300, winXp = 200, credits = 120, winCredits = 80 }, counts = true,
	},
	{
		id = "training", name = "Entrenamiento", short = "Solo", teamSize = 1, maxParty = 1, scoreLimit = 0, duration = 90, queue = 0,
		desc = "Campo de tiro sin rivales para probar armas y ajustes. No da recompensas ni cuenta para misiones.",
		objective = "Abate todas las dianas que puedas", players = "Solo tú · sin búsqueda", length = "1:30 min",
		rewards = { xp = 0, winXp = 0, credits = 0, winCredits = 0 }, counts = false,
	},
}

World.maps = {
	{ id = "dock9", name = "Muelle 9", modes = { "teams", "duel" }, desc = "Contenedores y grúas. Distancias medias y dos rutas de flanqueo.",
		sky = Color3.fromHex("#E9B27A"), accent = Color3.fromHex("#3D6470"),
		layout = { { 8, 10, 30, 18 }, { 52, 8, 40, 14 }, { 12, 40, 22, 26 }, { 44, 34, 14, 30 }, { 66, 40, 26, 22 }, { 20, 76, 64, 14 } } },
	{ id = "yard", name = "Patio Norte", modes = { "teams" }, desc = "Cuatro esquinas cubiertas y un patio central abierto.",
		sky = Color3.fromHex("#B9D3E8"), accent = Color3.fromHex("#4E5A52"),
		layout = { { 6, 6, 24, 24 }, { 70, 6, 24, 24 }, { 38, 30, 24, 40 }, { 6, 70, 24, 24 }, { 70, 70, 24, 24 } } },
	{ id = "rooftops", name = "Azoteas", modes = { "duel", "teams" }, desc = "Tejados conectados por pasarelas estrechas.",
		sky = Color3.fromHex("#D98E73"), accent = Color3.fromHex("#5C4A44"),
		layout = { { 6, 12, 36, 30 }, { 58, 12, 36, 30 }, { 6, 58, 36, 30 }, { 58, 58, 36, 30 } } },
	{ id = "range", name = "Campo de tiro", modes = { "training" }, desc = "Dianas a 10, 25 y 50 metros.",
		sky = Color3.fromHex("#C7CCC4"), accent = Color3.fromHex("#8B7A5A"),
		layout = { { 10, 10, 80, 12 }, { 14, 34, 10, 10 }, { 44, 34, 10, 10 }, { 74, 34, 10, 10 }, { 10, 70, 80, 16 } } },
}

function World.mode(id: string)
	for _, m in World.modes do
		if m.id == id then
			return m
		end
	end
	return World.modes[1]
end

function World.map(id: string)
	for _, m in World.maps do
		if m.id == id then
			return m
		end
	end
	return World.maps[1]
end

function World.mapsFor(modeId: string)
	local out = {}
	for _, m in World.maps do
		if table.find(m.modes, modeId) then
			table.insert(out, m)
		end
	end
	return out
end

-- Simulated friends. `accepts` decides how an invitation resolves (reproducible).
World.friends = {
	{ id = "lumen", name = "Lumen", level = 14, status = "online", banner = "contour", emblem = "hawk" },
	{ id = "maestro", name = "xX_ElMaestroDelRifleCompacto_Xx", level = 3, status = "online", banner = "tape", emblem = "bolt" },
	{ id = "brisa", name = "Brisa_77", level = 22, status = "online", banner = "ember", emblem = "crown", accepts = true },
	{ id = "marco", name = "MarcoPolo_ES", level = 9, status = "online", banner = "grid", emblem = "pivot", accepts = false },
	{ id = "kaito", name = "Kaito", level = 31, status = "inMatch", banner = "contour", emblem = "bolt" },
	{ id = "nyx", name = "Nyx", level = 17, status = "away", banner = "tape", emblem = "hawk" },
	{ id = "ferro", name = "Ferro", level = 6, status = "offline", banner = "grid", emblem = "pivot" },
}
World.statusName = { online = "Conectado", inMatch = "En partida", away = "Ausente", offline = "Desconectado" }

function World.friend(id: string)
	for _, f in World.friends do
		if f.id == id then
			return f
		end
	end
	return nil
end

World.startingParty = { { id = "lumen", ready = true }, { id = "maestro", ready = false } }

-- Names for simulated opponents and match-made teammates.
World.names = {
	"Tundra", "Rook_11", "Vela", "OxideFox", "Pim", "Quasar_Q", "Saffron", "Delta_Nine", "Mox",
	"Kilo", "Ivy_exe", "Bramble", "Juno", "Static_Sam", "Orchid", "Wren",
}

World.missions = {
	{ id = "d_play", period = "daily", stat = "matches", target = 3, start = 1, title = "Juega 3 partidas", reward = { xp = 300, credits = 150 } },
	{ id = "d_kills", period = "daily", stat = "kills", target = 10, start = 10, title = "Consigue 10 eliminaciones", reward = { xp = 250, credits = 200 } },
	{ id = "d_win", period = "daily", stat = "wins", target = 1, start = 0, title = "Gana una partida", reward = { xp = 400, credits = 250 } },
	{ id = "w_kills", period = "weekly", stat = "kills", target = 60, start = 23, title = "Consigue 60 eliminaciones", reward = { xp = 1200, credits = 600 } },
	{ id = "w_team_wins", period = "weekly", stat = "wins", mode = "teams", target = 5, start = 2, title = "Gana 5 partidas de Equipos", reward = { xp = 1000, credits = 500 } },
	{ id = "w_anvil", period = "weekly", stat = "kills", weapon = "anvil", target = 12, start = 0, title = "Elimina a 12 rivales con la Anvil 12", reward = { xp = 800, item = "ember" } },
	{ id = "w_finish", period = "weekly", stat = "finishEquipped", target = 1, start = 0, title = "Equipa un acabado en cualquier arma", reward = { xp = 300, credits = 100 } },
}

World.news = {
	{ id = "n1", tag = "Mapa", date = "10 nov", title = "Nuevo mapa: Muelle 9", body = "Contenedores, grúas y dos rutas de flanqueo. Disponible en Equipos y Duelo." },
	{ id = "n2", tag = "Tienda", date = "6 nov", title = "Anvil 12 en la tienda", body = "La escopeta de corredera llega a la armería a partir del nivel 5." },
	{ id = "n3", tag = "Equilibrio", date = "1 nov", title = "Ajustes de equilibrio", body = "La Kite C7 recupera antes el retroceso tras la tercera bala." },
}

-- Match history shown in the profile before the first simulated match.
World.seedHistory = {
	{ mode = "teams", map = "dock9", result = "victory", k = 14, d = 9, a = 5, score = 2410, scores = { 20, 16 }, when = "Ayer 19:40" },
	{ mode = "duel", map = "rooftops", result = "defeat", k = 3, d = 5, a = 0, score = 820, scores = { 3, 5 }, when = "Ayer 19:22" },
	{ mode = "teams", map = "yard", result = "defeat", k = 9, d = 12, a = 7, score = 1690, scores = { 17, 20 }, when = "11 nov 21:05" },
}

return World
