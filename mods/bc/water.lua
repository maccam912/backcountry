-- Finding water.
-- Water is the first thing that kills, and in some map generators it only
-- lies at sea level, which can be a long walk inland. Two things use the
-- search here: the starting point (a new group always begins within easy
-- reach of water) and the journal, which reads the lay of the land for a
-- thirsty player.
--
-- The map generator can be asked where rivers and low ground *should* be
-- without generating anything, but it is wrong about one time in five (dry
-- channels, hills mistaken for shore). So every guess is confirmed: the
-- spot is generated and searched for real water before anyone is told.
local WL = tonumber(core.get_mapgen_setting("water_level")) or 1
local MG = core.get_mapgen_setting("mg_name")

local river_np, river_width, river_scale
if MG == "valleys" then
	river_np = core.get_mapgen_setting_noiseparams("mgvalleys_np_rivers")
	river_width = (tonumber(core.get_mapgen_setting("mgvalleys_river_size")) or 5) / 100
	river_scale = 1
elseif MG == "v7" and not (core.get_mapgen_setting("mgv7_spflags") or ""):find("noridges", 1, true) then
	river_np = core.get_mapgen_setting_noiseparams("mgv7_np_ridge_uwater")
	river_width, river_scale = 0.2, 2
end

local river_noise
local function in_river(x, z)
	if not river_np then return false end
	river_noise = river_noise or core.get_perlin(river_np)
	return math.abs(river_noise:get_2d({x = x, y = z}) * river_scale) < river_width
end

-- Water confirmed this session, reused for everyone.
bc.known_water = {}

local function hdist(a, b)
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end
bc.hdist = hdist

-- Places within max_dist where the map generator suggests water, nearest first.
function bc.water_guesses(pos, max_dist)
	local out = {}
	local x0, z0 = math.floor(pos.x), math.floor(pos.z)
	for i = 0, 15 do
		local a = i * math.pi / 8
		local dx, dz = math.cos(a), math.sin(a)
		local last = core.get_spawn_level(x0, z0)
		local got_river, got_low = false, false
		local d = 8
		while d <= max_dist and not (got_river and got_low) do
			local x, z = math.floor(x0 + dx * d), math.floor(z0 + dz * d)
			if not got_river and in_river(x, z) then
				got_river = true
				out[#out + 1] = {x = x, z = z, dist = d, river = true}
			end
			if not got_low then
				-- ground near sea level giving way to somewhere nobody could stand
				local y = core.get_spawn_level(x, z)
				if not y and last and last <= WL + 5 then
					got_low = true
					out[#out + 1] = {x = x, z = z, dist = d}
				end
				last = y
			end
			d = d + (d < 96 and 8 or 16)
		end
	end
	table.sort(out, function(p, q)
		if p.dist ~= q.dist then return p.dist < q.dist end
		if p.x ~= q.x then return p.x < q.x end
		return p.z < q.z
	end)
	return out
end

-- Find real water within max_dist of pos. Asynchronous: calls
-- callback(water_pos or nil) once guesses have been generated and checked.
function bc.find_water(pos, max_dist, callback, max_checks)
	local best, best_d
	for _, w in ipairs(bc.known_water) do
		local d = hdist(pos, w)
		if d <= max_dist and (not best_d or d < best_d) then best, best_d = w, d end
	end
	if best then return callback(best) end

	local guesses = bc.water_guesses(pos, max_dist)
	local left = max_checks or 6
	local function try(i)
		local g = guesses[i]
		if not g or left <= 0 then return callback(nil) end
		left = left - 1
		-- sea-level water is at a known height; a valley river could be anywhere up the hillside
		local y1 = (g.river and MG == "valleys") and 110 or WL + 2
		local p1, p2 = {x = g.x - 10, y = WL - 4, z = g.z - 10}, {x = g.x + 10, y = y1, z = g.z + 10}
		core.emerge_area(p1, p2, function(_, _, remaining)
			if remaining ~= 0 then return end
			local found = core.find_nodes_in_area(p1, p2, {"group:bc_water"})
			local near, near_d
			for _, w in ipairs(found) do
				-- only water open to the air above counts: not a flooded cave
				local d = hdist(pos, w)
				if not near_d or d < near_d then
					local above = core.get_node({x = w.x, y = w.y + 1, z = w.z}).name
					if above == "air" or above == "bc:ice" or core.get_item_group(above, "flora") > 0 then
						near, near_d = w, d
					end
				end
			end
			if near then
				bc.known_water[#bc.known_water + 1] = near
				callback(near)
			else
				try(i + 1)
			end
		end)
	end
	try(1)
end

-- ---------------------------------------------------------------------
-- The starting point: liveable country with water within easy reach.
-- ---------------------------------------------------------------------
local SPAWN_WATER = 90
local provisional = {}   -- names of new players placed before the spot was confirmed

local function settle(pos, water)
	bc.set_world_spawn(pos)
	if water then bc.storage:set_string("spawn_water", core.pos_to_string(water)) end
	core.log("action", "[bc] starting point " .. core.pos_to_string(vector.round(pos))
		.. (water and (", water " .. math.floor(hdist(pos, water)) .. " m away") or ", no water found nearby"))
	for name in pairs(provisional) do
		local player = core.get_player_by_name(name)
		if player then bc.place_at_spawn(player) end
	end
	provisional = {}
end

-- A dry spot a short way back from the water, towards where we were looking.
-- Liveable country if there is any; otherwise any firm ground by the water.
local function beside(water, from)
	local dir = vector.direction({x = water.x, y = 0, z = water.z}, {x = from.x, y = 0, z = from.z})
	local fallback
	for _, d in ipairs({14, 20, 26, 34, 10, 44}) do
		for _, turn in ipairs({0, 0.6, -0.6, 1.3, -1.3}) do
			local c, s = math.cos(turn), math.sin(turn)
			local x = math.floor(water.x + (dir.x * c - dir.z * s) * d)
			local z = math.floor(water.z + (dir.x * s + dir.z * c) * d)
			local y = core.get_spawn_level(x, z)
			if y and y > WL + 1 and y < 60 then
				local pos = {x = x, y = y, z = z}
				if bc.GOOD_SPAWN_BIOMES[(bc.biome_at(pos))] then return pos, true end
				fallback = fallback or pos
			end
		end
	end
	return fallback, false
end

-- Work outward through liveable country until a place with confirmed water
-- close by turns up. Done a few candidates per server step so a new world
-- never stalls; anyone who joins meanwhile is moved once it is settled.
local function choose_spawn()
	local stored, confirmed = bc.world_spawn()
	if confirmed and (bc.storage:get_string("spawn_water") ~= "" or bc.storage:get_string("spawn_checked") ~= "") then
		return   -- already chosen with water in mind
	end
	local list = bc.spawn_candidates()
	local fallback = (confirmed and stored) or list[1]
	if not fallback then return end
	local i, verified = 0, 0

	local function give_up()
		bc.storage:set_string("spawn_checked", "1")
		settle(fallback, nil)
	end

	-- last resort: the nearest water of any kind, whatever the country round it
	local function nearest_water_anywhere()
		bc.find_water(fallback, 2400, function(water)
			local pos = water and beside(water, fallback)
			if pos then settle(pos, water) else give_up() end
		end, 12)
	end

	local function step()
		local budget = 25
		while budget > 0 do
			i = i + 1
			local c = list[i]
			if not c or verified >= 30 then return nearest_water_anywhere() end
			budget = budget - 1
			if #bc.water_guesses(c, SPAWN_WATER) > 0 then
				verified = verified + 1
				bc.find_water(c, SPAWN_WATER, function(water)
					local pos, good = nil, false
					if water then pos, good = beside(water, c) end
					if pos and good then settle(pos, water) else core.after(0, step) end
				end, 2)
				return
			end
		end
		core.after(0.05, step)
	end
	step()
end
core.after(0, choose_spawn)

-- Put someone near the group's starting point, a few steps apart.
function bc.place_at_spawn(player)
	local base, confirmed = bc.world_spawn()
	if not base then return false end
	if not confirmed then provisional[player:get_player_name()] = true end
	for _ = 1, 12 do
		local x, z = base.x + math.random(-5, 5), base.z + math.random(-5, 5)
		local y = core.get_spawn_level(x, z)
		if y then
			player:set_pos({x = x, y = y + 0.5, z = z})
			return true
		end
	end
	player:set_pos({x = base.x, y = base.y + 0.5, z = base.z})
	return true
end

-- ---------------------------------------------------------------------
-- Reading the land for a player: st.water = {near = bool, pos, from}
-- ---------------------------------------------------------------------
local FAR = 480

function bc.water_sense(player, st)
	local pos = player:get_pos()
	local now = core.get_us_time() / 1e6
	local w = st.water

	-- water you can simply see
	if not st.water_near_t or now - st.water_near_t > 5 then
		st.water_near_t = now
		local near = core.find_node_near(pos, 20, {"group:bc_water"}, true)
		if near then
			st.water = {near = true, pos = near}
			return st.water
		elseif w and w.near then
			st.water, w = nil, nil
		end
	end
	if w and w.near then return w end

	-- beyond that, read the terrain; keep a confirmed answer until we walk well past it
	local stale = not w or (w.pos and hdist(pos, w.pos) > math.max(60, w.first * 1.5))
		or (not w.pos and (hdist(pos, w.from) > 80 or now - w.t > 300))
	if stale and not st.water_busy then
		st.water_busy = true
		local from = vector.new(pos)
		bc.find_water(from, FAR, function(found)
			st.water_busy = false
			if not bc.state(st.name) then return end
			st.water = {pos = found, from = from, t = core.get_us_time() / 1e6, first = found and hdist(from, found) or 0}
			st.fs_dirty = true
			if found and st.v.water < 55 then
				local p = core.get_player_by_name(st.name)
				if p then bc.toast(p, bc.water_text(p, st)) end
			end
		end)
	end
	return st.water
end

-- One plain sentence about where water is.
function bc.water_text(player, st)
	local w = st.water
	local pos = player:get_pos()
	if not w then return "You are still getting the lie of the land." end
	if w.pos then
		local d = hdist(pos, w.pos)
		local dir = bc.compass(vector.subtract(w.pos, pos))
		if w.near or d < 24 then
			return d < 6 and "Water is right here." or string.format("Water is close by, to the %s.", dir)
		end
		return string.format("The land falls away to the %s. Water lies about %d m that way.", dir, math.floor(d / 10 + 0.5) * 10)
	end
	return string.format("No open water within %d m in any direction. Keep to low ground and valleys; rain, snow and fruit will have to do meanwhile.", FAR)
end
