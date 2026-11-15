-- Weather, air temperature and shelter.
local sim = bc.sim
bc.climate = {}

-- ---------------------------------------------------------------------
-- Weather: one front system for the whole world, saved with the world.
-- ---------------------------------------------------------------------
do
	local raw = bc.storage:get_string("weather")
	local w = raw ~= "" and core.deserialize(raw) or nil
	bc.weather = (type(w) == "table" and sim.WEATHER[w.state or ""]) and w or sim.new_weather()
end

local SEASON_WET = {Winter = 0.45, Spring = 0.65, Summer = 0.4, Autumn = 0.7}
local weather_clock, weather_timer = nil, 0
core.register_globalstep(function(dtime)
	weather_timer = weather_timer + dtime
	if weather_timer < 3 then return end
	weather_timer = 0
	local hours = weather_clock and (bc.clock - weather_clock) or 0
	weather_clock = bc.clock
	if hours > 0 then
		sim.step_weather(bc.weather, hours, SEASON_WET[(bc.season())] or 0.5, math.random)
		bc.storage:set_string("weather", core.serialize(bc.weather))
	end
end)

function bc.climate.wind_vector()
	local w = bc.weather
	return {x = -math.sin(w.wind_dir) * w.wind, y = 0, z = math.cos(w.wind_dir) * w.wind}
end

local COMPASS = {"north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"}
-- Compass name for a horizontal direction vector (+Z is north).
function bc.compass(dir)
	local a = math.atan2(dir.x, dir.z)
	return COMPASS[math.floor((a / (2 * math.pi)) * 8 + 0.5) % 8 + 1]
end

function bc.climate.wind_name(speed)
	if speed < 1 then return "Calm" end
	if speed < 3.5 then return "Light air" end
	if speed < 6 then return "Breeze" end
	if speed < 9 then return "Strong wind" end
	return "Gale"
end

-- ---------------------------------------------------------------------
-- Air temperature
-- ---------------------------------------------------------------------
-- opts.underground 0..1, opts.seasonal_only ignores weather and time of day
function bc.climate.air(pos, opts)
	opts = opts or {}
	local _, heat, humidity = bc.biome_at(pos)
	local w = bc.weather
	local wdef = sim.WEATHER[w.state]
	if opts.seasonal_only then
		return sim.air_temperature({heat = heat, humidity = humidity, y = pos.y, day = bc.clock / 24,
			year_len = bc.year_len, tod = 0.375})
	end
	return sim.air_temperature({
		heat = heat, humidity = humidity, y = pos.y,
		day = bc.clock / 24, year_len = bc.year_len, tod = core.get_timeofday(),
		front = w.front, cloud = wdef.cloud,
		precip = humidity >= 22 and wdef.precip or 0,
		underground = opts.underground,
	}), heat, humidity
end

-- What is falling here: nil, or "rain"/"snow" with an intensity 1..2.
function bc.climate.precip(pos, air, humidity)
	local wdef = sim.WEATHER[bc.weather.state]
	local amount = wdef.precip
	if amount <= 0 then return nil, 0 end
	if humidity < 22 then
		if amount < 2 then return nil, 0 end   -- only real storms reach the desert
		amount = 1
	end
	return air < 0.5 and "snow" or "rain", amount
end

-- ---------------------------------------------------------------------
-- Shelter analysis
-- ---------------------------------------------------------------------
local INSUL = {0.35, 0.65, 1.0}
local DIRS6 = {
	{x = 1, y = 0, z = 0}, {x = -1, y = 0, z = 0}, {x = 0, y = 1, z = 0},
	{x = 0, y = -1, z = 0}, {x = 0, y = 0, z = 1}, {x = 0, y = 0, z = -1},
}
local DIRS8 = {}
for i = 0, 7 do
	local a = i * math.pi / 4
	DIRS8[#DIRS8 + 1] = {x = math.cos(a), z = math.sin(a)}
end

-- true if air (and so wind and warmth) can pass through this node
local function open(name)
	if name == "air" then return true end
	if name == "ignore" then return nil end
	local def = core.registered_nodes[name]
	if not def then return false end
	if def.groups.bc_open then return true end
	if def.liquidtype ~= "none" then return false end
	return not def.walkable
end

local function insulation_of(name)
	local def = core.registered_nodes[name]
	if not def then return 0.5 end
	return INSUL[def.groups.bc_insul or 0] or 0.5
end

local MAX_ROOM = 140

-- Flood-fill the air space around `start`. If it is sealed and small
-- enough it is a shelter: we get its volume and how well its walls
-- insulate. Otherwise we fall back to counting nearby windbreaks.
function bc.climate.analyze(start)
	start = vector.round(start)
	local res = {enclosed = false, volume = 0, insulation = 0, wind_block = 0, roof = false}
	if not open(core.get_node(start).name) then
		start = {x = start.x, y = start.y + 1, z = start.z}
		if not open(core.get_node(start).name) then
			-- buried: as sheltered as it gets
			res.enclosed, res.volume, res.insulation, res.wind_block, res.roof = true, 1, 0.8, 1, true
			return res
		end
	end
	local seen = {[core.hash_node_position(start)] = true}
	local queue, head = {start}, 1
	local walls, wall_sum = 0, 0
	local sealed = true
	while head <= #queue do
		local p = queue[head]
		head = head + 1
		if #queue > MAX_ROOM then sealed = false; break end
		for _, d in ipairs(DIRS6) do
			local q = {x = p.x + d.x, y = p.y + d.y, z = p.z + d.z}
			local h = core.hash_node_position(q)
			if not seen[h] then
				seen[h] = true
				local name = core.get_node(q).name
				local o = open(name)
				if o == nil then
					sealed = false
				elseif o then
					queue[#queue + 1] = q
				else
					walls = walls + 1
					wall_sum = wall_sum + insulation_of(name)
				end
			end
		end
		if not sealed then break end
	end

	-- anything solid overhead keeps the rain off
	local solid_above = 0
	for dy = 1, 16 do
		local name = core.get_node({x = start.x, y = start.y + dy, z = start.z}).name
		local o = open(name)
		if o == false then
			res.roof = true
			if dy <= 12 then solid_above = solid_above + 1 end
		end
	end
	res.underground = sim.clamp((solid_above - 3) / 6, 0, 1)

	if sealed then
		res.enclosed = true
		res.volume = #queue
		res.insulation = walls > 0 and wall_sum / walls or 0.5
		res.wind_block = 1
		return res
	end

	local blocked = 0
	for _, d in ipairs(DIRS8) do
		for dist = 1, 3 do
			local q = {x = math.floor(start.x + d.x * dist + 0.5), y = start.y, z = math.floor(start.z + d.z * dist + 0.5)}
			if open(core.get_node(q).name) == false then
				blocked = blocked + 1
				break
			end
		end
	end
	res.wind_block = blocked / 8 * 0.85 + (res.roof and 0.1 or 0)
	return res
end

-- Warmth a sealed room traps from the bodies inside it.
local function shelter_warmth(sh, occupants)
	if not sh.enclosed then return 0 end
	local body = sh.insulation * sim.clamp(14 - sh.volume * 0.12, 3, 14)
	return body + math.min(3, occupants) * 2 * sh.insulation
end

-- Heat from nearby fires. Radiant heat falls off with distance and needs a
-- line of sight; inside a sealed room the whole air space warms up.
local function fire_warmth(pos, sh)
	local eye = {x = pos.x, y = pos.y + 1, z = pos.z}
	local fires = core.find_nodes_in_area(vector.subtract(pos, 6), vector.add(pos, 6), {"group:bc_fire"})
	local best_room, radiant = 0, 0
	for _, fp in ipairs(fires) do
		local heat = core.get_meta(fp):get_float("heat")
		if heat > 0.02 then
			local d = vector.distance(eye, fp)
			local r = heat * 22 / (1 + (d / 2.2) ^ 2)
			if not bc.clear_line(eye, {x = fp.x, y = fp.y + 0.3, z = fp.z}) then r = r * 0.25 end
			radiant = radiant + r
			if sh.enclosed then
				best_room = math.max(best_room, heat * (10 + 14 * sh.insulation) / (1 + sh.volume / 60))
			end
		end
	end
	return math.max(math.min(radiant, 30), best_room)
end

-- Everything about the place a player is standing that the body cares about.
function bc.climate.sample(player, st)
	local pos = player:get_pos()
	local probe = st.sleeping and vector.add(st.sleeping.pos, {x = 0, y = 1, z = 0})
		or {x = pos.x, y = pos.y + 0.6, z = pos.z}
	local sh = bc.climate.analyze(probe)
	local air, heat, humidity = bc.climate.air(pos, {underground = sh.underground})
	local kind, amount = bc.climate.precip(pos, air, humidity or 50)
	local w = bc.weather
	local tod = core.get_timeofday()

	local occupants = 0
	if sh.enclosed then
		for _, other in ipairs(core.get_connected_players()) do
			if other ~= player and vector.distance(other:get_pos(), pos) < 5 then occupants = occupants + 1 end
		end
	end

	local sun = 0
	if tod > 0.25 and tod < 0.75 and not sh.roof and (core.get_natural_light(vector.round(probe), 0.5) or 0) >= 14 then
		local elevation = math.sin((tod - 0.25) * 2 * math.pi)
		sun = elevation * (1 - sim.WEATHER[w.state].cloud * 0.9)
	end

	local fire = fire_warmth(pos, sh)
	local wield = player:get_wielded_item():get_name()
	if wield == "bc:torch" then fire = fire + 1.5 end

	local c = st.clim
	c.air, c.heat, c.humidity = air, heat or 50, humidity or 50
	c.shelter = sh
	c.shelter_warmth = shelter_warmth(sh, occupants)
	c.fire = fire
	c.sun = sun
	c.wind = w.wind
	c.wind_block = sh.wind_block
	c.precip_kind = kind
	c.precip = (kind and not sh.roof and not sh.enclosed) and amount or 0
	c.precip_sky = kind and amount or 0
	c.biome = bc.biome_at(pos)
	c.near_fire = fire > 3
	return c
end

-- ---------------------------------------------------------------------
-- What the weather looks and sounds like
-- ---------------------------------------------------------------------
local function update_sky(player, st)
	local w = bc.weather
	local wdef = sim.WEATHER[w.state]
	local key = w.state .. math.floor(w.wind_dir * 2) .. math.floor(w.wind / 3)
	if st.sky_key == key then return end
	st.sky_key = key
	local wind = bc.climate.wind_vector()
	local grey = math.floor(255 - wdef.cloud * 110)
	player:set_clouds({
		density = 0.25 + wdef.cloud * 0.55,
		color = {a = 235, r = grey, g = grey, b = math.min(255, grey + 8)},
		thickness = 14 + wdef.cloud * 20,
		speed = {x = wind.x * 1.5, z = wind.z * 1.5},
	})
end

local function loop_sound(player, st, slot, name, gain)
	local cur = st.loops and st.loops[slot]
	st.loops = st.loops or {}
	if gain <= 0.01 then
		if cur then core.sound_fade(cur.handle, 0.5, 0); st.loops[slot] = nil end
		return
	end
	if cur and math.abs(cur.gain - gain) < 0.08 then return end
	if cur then core.sound_fade(cur.handle, 0.5, 0) end
	st.loops[slot] = {gain = gain,
		handle = core.sound_play(name, {to_player = player:get_player_name(), gain = gain, loop = true, fade = 0.4})}
end

local fx_timer = 0
core.register_globalstep(function(dtime)
	fx_timer = fx_timer + dtime
	if fx_timer < 0.5 then return end
	fx_timer = 0
	local wind = bc.climate.wind_vector()
	for _, player in ipairs(core.get_connected_players()) do
		local st = bc.state(player)
		local c = st and st.clim
		if c and c.air then
			update_sky(player, st)
			local kind, amount = c.precip_kind, c.precip_sky
			local deep = c.shelter and (c.shelter.underground or 0) > 0.5
			if kind and amount > 0 and not deep then
				local pos = player:get_pos()
				local snow = kind == "snow"
				core.add_particlespawner({
					amount = (snow and 34 or 90) * amount,
					time = 0.5,
					playername = player:get_player_name(),
					minpos = {x = pos.x - 9, y = pos.y + (snow and 3 or 7), z = pos.z - 9},
					maxpos = {x = pos.x + 9, y = pos.y + (snow and 8 or 11), z = pos.z + 9},
					minvel = {x = wind.x * 0.5, y = snow and -1.6 or -17, z = wind.z * 0.5},
					maxvel = {x = wind.x * 0.7, y = snow and -2.6 or -21, z = wind.z * 0.7},
					minexptime = snow and 3 or 0.5,
					maxexptime = snow and 4.5 or 0.8,
					minsize = snow and 1 or 5,
					maxsize = snow and 2.2 or 8,
					collisiondetection = true,
					collision_removal = true,
					vertical = not snow,
					texture = snow and "bc_snowflake.png" or "bc_rain.png",
				})
			end
			local inside = c.shelter and (c.shelter.enclosed or deep)
			local rain_gain = (kind == "rain" and amount > 0) and (inside and 0.12 or 0.3) * amount or 0
			loop_sound(player, st, "rain", "bc_rain", deep and 0 or rain_gain)
			local wind_gain = bc.weather.wind > 5 and sim.clamp((bc.weather.wind - 4) / 12, 0, 0.6) * (inside and 0.35 or 1) or 0
			loop_sound(player, st, "wind", "bc_wind", deep and 0 or wind_gain)
		end
	end
end)
