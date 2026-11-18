-- The survival loop: once a second every player's body is advanced by the
-- game time that has passed, in the conditions where they stand.
local sim = bc.sim
bc.sleep = {}

local CAUSE = {
	starvation = "starvation", dehydration = "thirst", exhaustion = "exhaustion",
	hypothermia = "the cold", hyperthermia = "heat stroke", bleeding = "blood loss",
	infection = "an infected wound", food_poisoning = "food poisoning", dysentery = "dysentery",
	toxin = "poisoning", poison = "poisoning", wolf = "a wolf", bear = "a bear", fall = "a fall",
	drowning = "drowning", burns = "burns", nettles = "nettles, somehow", violence = "violence",
}

local PLAYER_PROPS = {
	visual = "mesh",
	mesh = "bc_player.obj",
	textures = {"bc_player.png"},
	visual_size = {x = 1, y = 1, z = 1},
	collisionbox = {-0.3, 0, -0.3, 0.3, 1.75, 0.3},
	selectionbox = {-0.3, 0, -0.3, 0.3, 1.75, 0.3},
	stepheight = 0.6,
	eye_height = 1.6,
}

-- ---------------------------------------------------------------------
-- Joining and leaving
-- ---------------------------------------------------------------------
core.register_on_joinplayer(function(player)
	local st, fresh = bc.load_player(player)
	local inv = player:get_inventory()
	inv:set_size("main", 24)
	inv:set_size("craft", 9)
	inv:set_size("clothing", #bc.CLOTHING_SLOTS)
	player:hud_set_hotbar_itemcount(8)
	player:hud_set_flags({healthbar = false, minimap = false, minimap_radar = false})
	player:set_properties(PLAYER_PROPS)
	player:set_armor_groups({fleshy = 100, fall_damage_add_percent = -100})
	if fresh then
		bc.dress_new_player(player)
		bc.place_at_spawn(player)
	end
	bc.hud.init(player, st)
	bc.journal.on_join(player, st, fresh)
end)

core.register_on_leaveplayer(function(player)
	local st = bc.state(player)
	if st then
		if st.sleeping then bc.sleep.stop(player, nil, true) end
		bc.save_player(player)
		bc.players[player:get_player_name()] = nil
	end
end)

-- ---------------------------------------------------------------------
-- Harm and death
-- ---------------------------------------------------------------------
function bc.damage(player, amount, cause)
	local st = bc.state(player)
	if not st or st.dying or amount <= 0 then return end
	local v = st.v
	v.condition = v.condition - amount
	v.cause = cause or v.cause
	if amount >= 2 then
		bc.hud.flash(player, st)
		bc.sound("bc_hurt", player, 0.6)
	end
	if st.sleeping then bc.sleep.stop(player, "hurt") end
	if v.condition <= 0 then bc.die(player, cause) end
end

function bc.die(player, cause, by_engine)
	local st = bc.state(player)
	if not st or st.dying then return end
	st.dying = true
	if st.sleeping then bc.sleep.stop(player, nil, true) end
	local name = player:get_player_name()
	local pos = vector.round(player:get_pos())
	local inv = player:get_inventory()

	-- what they carried stays where they fell
	local items = {}
	for _, list in ipairs({"main", "craft", "clothing"}) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			if not stack:is_empty() then items[#items + 1] = stack end
		end
		inv:set_list(list, {})
	end
	local days = (bc.clock - st.p.born) / 24
	local why = CAUSE[cause or ""] or cause or "exposure"
	if #items > 0 then
		local spot, submerged
		for _, off in ipairs({{0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			for dy = 0, 4 do
				local p = {x = pos.x + off[1], y = pos.y + dy, z = pos.z + off[2]}
				local def = core.registered_nodes[core.get_node(p).name]
				if def and def.buildable_to then
					if def.liquidtype == "none" then spot = p; break end
					if not submerged and (def.groups.bc_water or 0) > 0 then submerged = p end
				end
			end
			if spot then break end
		end
		spot = spot or submerged
		if spot then
			local water = core.get_node(spot)
			core.set_node(spot, {name = "bc:remains"})
			local meta = core.get_meta(spot)
			if core.get_item_group(water.name, "bc_water") > 0 then
				meta:set_string("water", water.name)
				meta:set_int("water_level", water.param2)
			end
			local rinv = meta:get_inventory()
			for _, stack in ipairs(items) do
				local left = rinv:add_item("main", stack)
				if not left:is_empty() then core.add_item(spot, left) end
			end
			bc.trail.mark_pack(st, spot)
			meta:set_string("infotext", string.format("Remains of %s\nDied of %s on day %d", name, why, bc.day()))
		else
			for _, stack in ipairs(items) do core.add_item(pos, stack) end
		end
	end

	st.p.best = math.max(st.p.best or 0, days)
	st.p.deaths = (st.p.deaths or 0) + 1
	st.p.v = bc.new_life()
	st.v = st.p.v
	st.p.born = bc.clock
	st.p.saw_winter = nil
	st.last_clock = nil
	st.vy = nil
	bc.dress_new_player(player)
	core.chat_send_all(core.colorize("#d0a060",
		string.format("%s died of %s after %.1f days in the backcountry.", name, why, days)))

	if not by_engine then
		local to = bc.trail.camp_spawn(st)
		if to then player:set_pos(to) else bc.place_at_spawn(player) end
	end
	bc.journal.death_screen(player, st, why, days)
	bc.save_player(player)
	st.dying = nil
end

-- The engine's own health is not used: every hazard is converted into
-- condition so there is a single measure of how alive you are.
core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change >= 0 then return hp_change end
	local kind = reason and reason.type
	if kind == "set_hp" or kind == "respawn" then return hp_change end
	local amount, cause = -hp_change * 4, "violence"
	if kind == "fall" then return 0 end
	if kind == "drown" then cause = "drowning"
	elseif kind == "node_damage" then cause, amount = "burns", -hp_change * 3 end
	core.after(0, function()
		if player:is_player() then bc.damage(player, amount, cause) end
	end)
	return 0
end, true)

core.register_on_dieplayer(function(player)
	bc.die(player, "misadventure", true)
end)

core.register_on_respawnplayer(function(player)
	local st = bc.state(player)
	local to = st and bc.trail.camp_spawn(st)
	if to then
		player:set_pos(to)
		return true
	end
	return bc.place_at_spawn(player)
end)

-- ---------------------------------------------------------------------
-- Sleep
-- ---------------------------------------------------------------------
function bc.sleep.start(player, pos, quality, warmth)
	local st = bc.state(player)
	if not st or st.sleeping then return end
	if st.v.rest > 92 and not bc.is_night() then
		bc.toast(player, "You are not tired enough to sleep.")
		return
	end
	for _, other in pairs(bc.players) do
		if other.sleeping and vector.equals(other.sleeping.pos, pos) then
			bc.toast(player, "Someone is already sleeping there.")
			return
		end
	end
	st.sleeping = {pos = vector.new(pos), quality = quality, warmth = warmth,
		from = player:get_pos(), started = bc.clock, grace = 1.0}
	player:set_pos({x = pos.x, y = pos.y - 0.2, z = pos.z})
	player:set_properties({mesh = "bc_player_lying.obj", collisionbox = {-0.3, 0, -0.3, 0.3, 0.4, 0.3}})
	player:set_eye_offset({x = 0, y = -12, z = 0})
	st.clim.air = nil   -- resample from the bed
	bc.hud.sleep(player, st, "You settle down to sleep.")
	bc.hint(player, "sleep")
end

local WAKE = {
	rested = "You wake rested.",
	cold = "You wake shivering. It is too cold to sleep like this.",
	hot = "You wake drenched in sweat. You need a cooler place to sleep.",
	hurt = "You are jolted awake.",
	up = "You get up.",
}

function bc.sleep.stop(player, reason, silent)
	local st = bc.state(player)
	if not st or not st.sleeping then return end
	local s = st.sleeping
	st.sleeping = nil
	player:set_properties({mesh = "bc_player.obj", collisionbox = PLAYER_PROPS.collisionbox})
	player:set_eye_offset({x = 0, y = 0, z = 0})
	player:set_pos(s.from)
	bc.hud.sleep(player, st, nil)
	st.phys_key = nil
	if not silent and WAKE[reason or ""] then bc.toast(player, WAKE[reason]) end
	if reason == "rested" or (bc.clock - s.started) > 4 then
		bc.objective(player, "sleep")
		if st.clim.shelter and st.clim.shelter.enclosed then bc.objective(player, "shelter") end
	end
end

local function everyone_asleep()
	local total, asleep = 0, 0
	for _, st in pairs(bc.players) do
		total = total + 1
		if st.sleeping then asleep = asleep + 1 end
	end
	return total > 0 and asleep == total, asleep, total
end

-- ---------------------------------------------------------------------
-- Pack weight and discovering items
-- ---------------------------------------------------------------------
local function scan_pack(player, st)
	local inv = player:get_inventory()
	local load, scent = 0, false
	for _, list in ipairs({"main", "craft"}) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			if not stack:is_empty() then
				local name = stack:get_name()
				load = load + bc.item_weight(name) * stack:get_count()
				if not st.p.items[name] then bc.journal.discover(player, st, name) end
				if core.get_item_group(name, "bc_raw_meat") > 0 then scent = true end
			end
		end
	end
	st.load, st.scent = load, scent
end

-- ---------------------------------------------------------------------
-- Movement: sprinting, slowing when hurt or loaded, and falls
-- ---------------------------------------------------------------------
local function fast_step(player, st, dtime)
	local ctrl = player:get_player_control()
	local vel = player:get_velocity()

	-- falls: engine fall damage is off; hard landings hurt and can sprain
	local vy = st.vy
	st.vy = vel.y
	if vy and vy < -13 and vel.y > -2 and not st.sleeping then
		local pos = player:get_pos()
		local feet = core.get_node({x = pos.x, y = pos.y + 0.1, z = pos.z}).name
		if core.get_item_group(feet, "liquid") == 0 then
			local speed = -vy
			bc.damage(player, (speed - 13) * 6, "fall")
			if st.vy and math.random() < 0.6 then
				sim.add_affliction(st.v, "sprain")
				bc.toast(player, "You land badly and twist your ankle.")
			end
		end
	end

	if st.sleeping then
		local s = st.sleeping
		s.grace = s.grace - dtime
		if s.grace <= 0 and (ctrl.jump or ctrl.sneak) then bc.sleep.stop(player, "up") end
	end

	local base = st.base_speed or 1
	local sprinting = false
	if not st.sleeping and ctrl.aux1 and ctrl.up and not ctrl.sneak and st.v.rest > 5
			and not st.v.aff.sprain and st.load < sim.CARRY_COMFORT + 15 then
		sprinting = true
	end
	st.sprinting = sprinting
	local speed = st.sleeping and 0 or base * (sprinting and 1.55 or 1)
	-- Keep enough jump height to clear a full node even with a heavy pack and a sprain.
	local jump = st.sleeping and 0 or 1
	local key = speed .. "/" .. jump
	if st.phys_key ~= key then
		st.phys_key = key
		player:set_physics_override({speed = speed, jump = jump})
	end
end

-- ---------------------------------------------------------------------
-- The once-a-second update
-- ---------------------------------------------------------------------
local function update(player, st)
	local now = bc.clock
	local dt = st.last_clock and sim.clamp(now - st.last_clock, 0, 1) or 0
	st.last_clock = now
	local v = st.v
	local pos = player:get_pos()

	st.n = (st.n or 0) + 1
	if st.n % 2 == 1 or not st.clim.air then
		bc.climate.sample(player, st)
		scan_pack(player, st)
		bc.trail.update(st)
	end

	local vel = player:get_velocity()
	local hspeed = math.sqrt(vel.x * vel.x + vel.z * vel.z)
	local feet = core.get_item_group(core.get_node({x = pos.x, y = pos.y + 0.2, z = pos.z}).name, "water") > 0
	local waist = core.get_item_group(core.get_node({x = pos.x, y = pos.y + 0.9, z = pos.z}).name, "water") > 0
	local activity = "rest"
	if st.sleeping then activity = "sleep"
	elseif waist then activity = "swim"
	elseif hspeed > 0.6 then activity = (st.sprinting and hspeed > 4.4) and "sprint" or "walk" end
	if feet and not waist then v.wet = math.max(v.wet, 0.3) end

	local c = st.clim
	local warmth, rain_cover = bc.clothing_stats(player)
	local env = {
		activity = activity,
		air = c.air, wind = c.wind, wind_block = c.wind_block,
		insulation = warmth, fire = c.fire, sun = c.sun,
		precip = c.precip, rain_cover = rain_cover, in_water = waist,
		load = st.load,
		bed = st.sleeping and st.sleeping.warmth or 0,
		bed_quality = st.sleeping and st.sleeping.quality or 0.5,
	}
	local info, events = sim.step(v, dt, env, math.random)
	st.info, st.env, st.activity = info, env, activity

	for _, ev in ipairs(events) do
		if ev.type == "death" then
			bc.die(player, ev.cause)
			return
		elseif ev.type == "wake" then
			bc.sleep.stop(player, ev.reason)
		elseif ev.type == "aff_start" and ev.name == "infection" then
			bc.toast(player, "The wound is hot and swollen. It has become infected.")
			bc.hint(player, "infection")
		elseif ev.type == "aff_end" then
			local def = sim.AFF[ev.name]
			if def and def.bad then bc.toast(player, def.name .. " has passed.") end
		end
	end

	local speed = info.speed * sim.load_speed(st.load)
	if v.rest <= 0 then speed = speed * 0.75 end
	if v.core < 33 then speed = speed * 0.8 end
	st.base_speed = bc.round(speed, 2)

	if st.sleeping then
		local all, asleep, total = everyone_asleep()
		local text = "Sleeping... (jump to get up)"
		if not all then
			text = text .. string.format("\n%d of %d asleep. The night passes quickly once everyone rests.", asleep, total)
		end
		if info.cold_stress > 0 then text = text .. "\nYou are cold. Sleep comes badly." end
		bc.hud.sleep(player, st, text)
	end

	bc.hud.update(player, st)
	bc.journal.tick(player, st)
end

local acc = 0
core.register_globalstep(function(dtime)
	local players = core.get_connected_players()
	for _, player in ipairs(players) do
		local st = bc.state(player)
		if st and not st.dying then fast_step(player, st, dtime) end
	end

	-- when the whole group sleeps, the night goes by in moments
	if everyone_asleep() then
		core.set_timeofday((core.get_timeofday() + dtime * 0.4 / 24) % 1)
	end

	acc = acc + dtime
	if acc < 1 then return end
	acc = 0
	for _, player in ipairs(players) do
		local st = bc.state(player)
		if st and not st.dying then update(player, st) end
	end
end)
