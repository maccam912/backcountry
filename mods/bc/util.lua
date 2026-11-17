bc = {}
bc.sim = bc_sim
bc.modpath = core.get_modpath("bc")
bc.storage = core.get_mod_storage()
bc.players = {}   -- name -> state table (see bc.load_player)
bc.year_len = tonumber(core.settings:get("bc_year_length")) or 40
bc.sim.ENERGY_USE = bc.sim.clamp(tonumber(core.settings:get("bc_energy_use")) or 1, 0.25, 3)

function bc.time_speed()
	local ts = tonumber(core.settings:get("time_speed")) or 72
	return ts > 0 and ts or 72
end

-- Real seconds that a span of game hours takes at the current time speed.
function bc.real_seconds(game_hours)
	return game_hours * 3600 / bc.time_speed()
end

-- ---------------------------------------------------------------------
-- Game clock: hours of game time since the world began. It follows the
-- engine's time of day, so sleeping through a night (which fast-forwards
-- the engine clock) advances hunger, weather and fires with it. Manual
-- time jumps (/time) are ignored rather than starving everyone.
-- ---------------------------------------------------------------------
bc.clock = bc.storage:get_float("clock")
local last_tod
core.register_globalstep(function()
	local tod = core.get_timeofday()
	if last_tod then
		local d = tod - last_tod
		if d < -0.5 then d = d + 1 end
		if d > 0 and d < 0.1 then bc.clock = bc.clock + d * 24 end
	end
	last_tod = tod
end)

function bc.day() return math.floor(bc.clock / 24) + 1 end
function bc.season() return bc.sim.season(bc.clock / 24, bc.year_len) end

local TIMES = {
	{0.00, "Dead of night"}, {0.19, "Before dawn"}, {0.23, "Dawn"}, {0.29, "Morning"},
	{0.44, "Midday"}, {0.56, "Afternoon"}, {0.69, "Evening"}, {0.77, "Dusk"}, {0.81, "Night"},
	{0.94, "Dead of night"},
}
function bc.time_name(tod)
	tod = tod or core.get_timeofday()
	local name = TIMES[1][2]
	for _, t in ipairs(TIMES) do if tod >= t[1] then name = t[2] end end
	return name
end
function bc.is_night(tod)
	tod = tod or core.get_timeofday()
	return tod < 0.22 or tod > 0.79
end

-- ---------------------------------------------------------------------
-- Per-player state. st.p is persisted in player metadata; everything
-- else on st is rebuilt at runtime.
-- ---------------------------------------------------------------------
function bc.state(player)
	if not player then return nil end
	local name = type(player) == "string" and player or player:get_player_name()
	return bc.players[name]
end

function bc.new_life()
	return bc.sim.new_vitals()
end

function bc.load_player(player)
	local name = player:get_player_name()
	local raw = player:get_meta():get_string("bc:state")
	local p = raw ~= "" and core.deserialize(raw) or nil
	local fresh = false
	if type(p) ~= "table" or type(p.v) ~= "table" then
		p = {v = bc.new_life(), born = bc.clock}
		fresh = true
	end
	p.v.aff = p.v.aff or {}
	p.items = p.items or {}      -- item names this player has handled
	p.notes = p.notes or {}      -- journal discoveries
	p.hints = p.hints or {}      -- tips already shown
	p.obj = p.obj or {}          -- completed objectives
	p.fire_skill = p.fire_skill or 0
	p.crafted = p.crafted or {}  -- recipe id -> times made
	p.born = p.born or bc.clock
	p.deaths = p.deaths or 0
	p.best = p.best or 0
	if p.show_hints == nil then p.show_hints = true end
	if p.fahrenheit == nil then p.fahrenheit = core.settings:get_bool("bc_fahrenheit", false) end
	local st = {p = p, v = p.v, name = name, load = 0, clim = {}, tab = 1}
	bc.players[name] = st
	return st, fresh
end

function bc.save_player(player)
	local st = bc.state(player)
	if not st then return end
	player:get_meta():set_string("bc:state", core.serialize(st.p))
end

local save_timer = 0
core.register_globalstep(function(dtime)
	save_timer = save_timer + dtime
	if save_timer < 20 then return end
	save_timer = 0
	bc.storage:set_float("clock", bc.clock)
	for _, player in ipairs(core.get_connected_players()) do bc.save_player(player) end
end)
core.register_on_shutdown(function()
	bc.storage:set_float("clock", bc.clock)
	for _, player in ipairs(core.get_connected_players()) do bc.save_player(player) end
end)

-- ---------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------
function bc.round(x, places)
	local m = 10 ^ (places or 0)
	return math.floor(x * m + 0.5) / m
end

function bc.tell(player, text, color)
	local name = type(player) == "string" and player or player:get_player_name()
	core.chat_send_player(name, color and core.colorize(color, text) or text)
end

-- Give an item, dropping it at the player's feet if the pack is full.
function bc.give(player, stack)
	stack = ItemStack(stack)
	local left = player:get_inventory():add_item("main", stack)
	if not left:is_empty() then
		core.add_item(vector.add(player:get_pos(), {x = 0, y = 1, z = 0}), left)
	end
end

-- First stack in the pack belonging to a group. Returns index, stack.
function bc.find_group(player, group)
	local inv = player:get_inventory()
	for i, stack in ipairs(inv:get_list("main")) do
		if not stack:is_empty() and core.get_item_group(stack:get_name(), group) > 0 then
			return i, stack
		end
	end
end

function bc.take_item(player, name, count)
	return player:get_inventory():remove_item("main", ItemStack(name .. " " .. (count or 1))):get_count()
end

-- Physical work: spends calories and rest. Heavier packs make it worse.
function bc.exert(player, kcal, rest)
	local st = bc.state(player)
	if not st then return end
	local v = st.v
	v.kcal = math.max(0, v.kcal - (kcal or 0) * bc.sim.ENERGY_USE)
	v.rest = math.max(0, v.rest - (rest or 0))
end

function bc.item_weight(name)
	local def = core.registered_items[name]
	if not def then return 0 end
	if def._bc_weight then return def._bc_weight end
	if def.type == "node" then return 3 end
	if def.type == "tool" then return 0.8 end
	return 0.1
end

function bc.sound(name, where, gain, extra)
	local spec = {gain = gain or 1}
	if type(where) == "userdata" then
		if where:is_player() then spec.to_player = where:get_player_name() else spec.object = where end
	elseif type(where) == "table" then
		spec.pos = where
		spec.max_hear_distance = 20
	end
	if extra then for k, v in pairs(extra) do spec[k] = v end end
	return core.sound_play(name, spec, not (extra and extra.loop))
end

-- True if nothing solid lies between two points. Unlike the engine's
-- line_of_sight this ignores grass, fires and other things you can see past.
function bc.clear_line(a, b)
	for pt in core.raycast(a, b, false, false) do
		if pt.type == "node" then
			local def = core.registered_nodes[core.get_node(pt.under).name]
			if not def or def.walkable then return false end
		end
	end
	return true
end

-- Everything is simulated in Celsius; each player chooses how to read it.
function bc.temp(st, celsius, places)
	local f = st and st.p and st.p.fahrenheit
	return string.format("%." .. (places or 0) .. "f°%s", f and (celsius * 1.8 + 32) or celsius, f and "F" or "C")
end

-- A difference in temperature ("+5 degrees of warmth"), which has no offset.
function bc.temp_delta(st, celsius, signed)
	local f = st and st.p and st.p.fahrenheit
	return string.format(signed and "%+.0f°%s" or "%.0f°%s", bc.round(f and celsius * 1.8 or celsius), f and "F" or "C")
end

function bc.pos_key(pos)
	return pos.x .. "," .. pos.y .. "," .. pos.z
end

-- These are filled in by later files; defined here so load order never bites.
function bc.toast(player, text) bc.tell(player, text) end
function bc.learn() end
function bc.objective() end
function bc.damage() end
function bc.hint() end
