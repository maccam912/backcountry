-- Real-engine checks. Copied into a throwaway world as a world mod by
-- tools/run_engine_tests.py. Phase 1 needs no player; phase 2 runs when a
-- client joins (the runner starts one if it can).
local results = {checks = 0, failures = {}, notes = {}}
local function fail(msg) results.failures[#results.failures + 1] = msg end
local function check(cond, msg)
	results.checks = results.checks + 1
	if not cond then fail(msg) end
	return cond
end
local function note(k, v) results.notes[k] = v end
local function finish()
	local f = io.open(core.get_worldpath() .. "/results.json", "w")
	f:write(core.write_json(results, true))
	f:close()
	core.request_shutdown("probe finished")
end
local function guarded(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then
		local message = name .. ": " .. tostring(err)
		fail(message)
		core.log("error", message)
		finish()
	end
end

local wait_player = core.settings:get_bool("bc_probe_player", false)
-- Pretend this world was made by an older version that picked a start
-- point without checking for water: it should be moved on first load.
local old_spawn = core.settings:get("bc_probe_old_spawn")
if old_spawn and old_spawn ~= "" then bc.storage:set_string("spawn", old_spawn) end
local tex_dir = core.get_modpath("bc") .. "/textures/"
local snd_dir = core.get_modpath("bc") .. "/sounds/"
local mdl_dir = core.get_modpath("bc") .. "/models/"
local function exists(path)
	local f = io.open(path, "rb")
	if f then f:close() return true end
	return false
end

-- ------------------------------------------------------------------ static
local function textures_in(v, out)
	if type(v) == "string" then
		for part in v:gmatch("[^%^]+") do
			local file = part:match("([%w_%.]+%.png)")
			if file and not part:find("^%[") then out[file] = true end
		end
	elseif type(v) == "table" then
		for _, w in pairs(v) do
			if type(w) == "string" or type(w) == "table" then textures_in(w, out) end
		end
	end
end

local function static_checks()
	local tex, snd, n_items = {}, {}, 0
	for name, def in pairs(core.registered_items) do
		if name:sub(1, 3) == "bc:" then
			n_items = n_items + 1
			textures_in(def.inventory_image, tex)
			textures_in(def.wield_image, tex)
			textures_in(def.tiles, tex)
			textures_in(def.special_tiles, tex)
			for _, s in pairs(def.sounds or {}) do
				if type(s) == "table" and s.name then snd[s.name] = true end
			end
			-- drops must exist
			local drops = {}
			if type(def.drop) == "string" and def.drop ~= "" then drops[#drops + 1] = def.drop end
			if type(def.drop) == "table" then
				for _, d in ipairs(def.drop.items or {}) do
					for _, it in ipairs(d.items or {}) do drops[#drops + 1] = it end
				end
			end
			for _, d in ipairs(drops) do
				check(core.registered_items[ItemStack(d):get_name()], name .. " drops unknown item " .. d)
			end
			check(def.description and def.description ~= "", name .. " has no description")
		end
	end
	note("items", n_items)
	for _, e in pairs(core.registered_entities) do
		if e.name and e.name:sub(1, 3) == "bc:" then
			local p = e.initial_properties or {}
			textures_in(p.textures, tex)
			if p.mesh then check(exists(mdl_dir .. p.mesh), "missing model " .. p.mesh) end
		end
	end
	for _, extra in ipairs({"bc_white.png", "bc_rain.png", "bc_snowflake.png", "bc_smoke.png", "bc_player.png",
			"bc_hud_health.png", "bc_hud_temp.png", "bc_hud_food.png", "bc_hud_water.png", "bc_hud_rest.png"}) do
		tex[extra] = true
	end
	local n_tex = 0
	for file in pairs(tex) do
		n_tex = n_tex + 1
		check(exists(tex_dir .. file), "missing texture " .. file)
	end
	note("textures_referenced", n_tex)
	check(exists(mdl_dir .. "bc_player.obj") and exists(mdl_dir .. "bc_player_lying.obj"), "missing player models")
	for _, s in ipairs({"bc_eat", "bc_drink", "bc_fire", "bc_rain", "bc_wind", "bc_page", "bc_butcher", "bc_bow",
			"bc_woosh", "bc_splash", "bc_howl", "bc_growl", "bc_hurt", "bc_hit", "bc_ignite", "bc_break", "bc_door", "bc_cloth"}) do
		snd[s] = true
	end
	for name in pairs(snd) do
		check(exists(snd_dir .. name .. ".ogg") or exists(snd_dir .. name .. ".0.ogg"), "missing sound " .. name)
	end

	-- every recipe must be craftable in the grid and give what the journal says
	local function member(group)
		local names = {}
		for name in pairs(core.registered_items) do
			if core.get_item_group(name, group) > 0 then names[#names + 1] = name end
		end
		table.sort(names)
		return names[1]
	end
	for _, r in ipairs(bc.recipes) do
		local grid = {}
		for i, item in ipairs(r.items) do
			if item:sub(1, 6) == "group:" then
				grid[i] = member(item:sub(7))
				check(grid[i], r.id .. ": empty group " .. item)
			else
				check(core.registered_items[item], r.id .. ": unknown ingredient " .. item)
				grid[i] = item
			end
		end
		for i = #grid + 1, 9 do grid[i] = "" end
		local out = core.get_craft_result({method = "normal", width = 3, items = grid})
		check(out.item:to_string() == ItemStack(r.output):to_string(),
			r.id .. ": grid gives '" .. out.item:to_string() .. "', expected '" .. r.output .. "'")
		local stacks = {}
		for i, item in ipairs(grid) do stacks[i] = ItemStack(item) end
		check(bc.recipe_for_grid(stacks, out.item) == r, r.id .. ": not recognised from its own grid")
		for _, u in ipairs(r.unlock or {}) do
			check(core.registered_items[u], r.id .. ": unlock item unknown " .. u)
		end
		if r.secret then check(bc.lore[r.secret], r.id .. ": secret has no lore " .. r.secret) end
	end
	note("recipes", #bc.recipes)
	for input, rec in pairs(bc.cooking) do
		check(core.registered_items[input] and core.registered_items[rec.out], "cooking: bad pair " .. input)
	end
	for input, rec in pairs(bc.drying) do
		check(core.registered_items[input] and core.registered_items[rec.out], "drying: bad pair " .. input)
	end
	for name, def in pairs(bc.animals) do
		for _, part in ipairs(def.butcher) do
			check(core.registered_items[part[1]], name .. " yields unknown item " .. part[1])
		end
		for biome in pairs(def.biomes) do check(bc.biomes[biome], name .. " lives in unknown biome " .. biome) end
	end
	local kinds = {}
	for _, kind in pairs(bc.mushrooms) do kinds[kind] = (kinds[kind] or 0) + 1 end
	check(kinds.good == 2 and kinds.sick == 1 and kinds.deadly == 1, "mushroom kinds not assigned")
end

-- ------------------------------------------------------------------ world
local base

local function clear_box(p1, p2)
	for x = p1.x, p2.x do for y = p1.y, p2.y do for z = p1.z, p2.z do
		core.set_node({x = x, y = y, z = z}, {name = "air"})
	end end end
end

local function world_checks()
	-- what the mapgen made
	local counts = {}
	local area = core.find_nodes_in_area(vector.subtract(base, {x = 60, y = 30, z = 60}), vector.add(base, {x = 60, y = 40, z = 60}),
		{"group:tree", "group:leaves", "group:flora", "bc:loose_rock", "bc:branch", "group:bc_water", "bc:clay", "bc:gravel"}, true)
	local trees, flora, water = 0, 0, 0
	for name, list in pairs(area) do
		counts[name] = #list
		if core.get_item_group(name, "tree") > 0 then trees = trees + #list end
		if core.get_item_group(name, "flora") > 0 then flora = flora + #list end
		if core.get_item_group(name, "bc_water") > 0 then water = water + #list end
	end
	note("mapgen_counts", counts)
	note("spawn_biome", (bc.biome_at(base)))
	check(trees > 20, "few or no trees near spawn: " .. trees)
	check(flora > 50, "few or no plants near spawn: " .. flora)
	check((counts["bc:loose_rock"] or 0) > 3, "no loose rocks near spawn")
	check((counts["bc:branch"] or 0) > 3, "no fallen branches near spawn")
	note("water_nodes_near_spawn", water)

	-- a flat stone platform to test on, well above the ground
	local o = {x = base.x, y = base.y + 40, z = base.z}
	for x = -6, 6 do for z = -6, 6 do
		core.set_node({x = o.x + x, y = o.y, z = o.z + z}, {name = "bc:dirt"})
	end end
	clear_box({x = o.x - 6, y = o.y + 1, z = o.z - 6}, {x = o.x + 6, y = o.y + 6, z = o.z + 6})
	local floor = o.y + 1

	-- climate
	local saved_clock = bc.clock
	local summer = bc.climate.air(base, {seasonal_only = true})
	bc.clock = saved_clock + bc.year_len * 0.5 * 24
	local winter = bc.climate.air(base, {seasonal_only = true})
	bc.clock = saved_clock
	check(summer - winter > 8, string.format("summer %.1f not much warmer than winter %.1f", summer, winter))
	note("spawn_summer_winter", {summer, winter})

	-- shelter: open ground, then a sealed thatch hut, then a hole in it
	local c = {x = o.x, y = floor, z = o.z}
	local open = bc.climate.analyze(c)
	check(not open.enclosed and not open.roof, "open platform reported as shelter")
	for x = -1, 1 do for z = -1, 1 do for y = 0, 2 do
		local p = {x = c.x + x, y = c.y + y, z = c.z + z}
		local wall = x ~= 0 or z ~= 0 or y == 2
		core.set_node(p, {name = wall and "bc:thatch" or "air"})
	end end end
	local hut = bc.climate.analyze(c)
	check(hut.enclosed and hut.volume == 2 and hut.insulation > 0.9 and hut.roof and hut.wind_block == 1,
		"sealed hut not recognised: " .. dump(hut))
	check(hut.interior[core.hash_node_position(c)] and not hut.interior[core.hash_node_position(vector.offset(c, 1, 0, 0))],
		"shelter contents include a wall or omit the sleeper")
	core.set_node({x = c.x + 1, y = c.y, z = c.z}, {name = "bc:door_open"})
	check(not bc.climate.analyze(c).enclosed, "hut with an open door still counts as sealed")
	core.set_node({x = c.x + 1, y = c.y, z = c.z}, {name = "bc:door"})
	check(bc.climate.analyze(c).enclosed, "hut with a shut door is not sealed")

	-- fire inside the hut: lights, burns fuel, cooks, heats, dies to embers, cools slowly
	local fp = {x = c.x, y = c.y, z = c.z}
	core.set_node(fp, {name = "bc:campfire_unlit"})
	local meta = core.get_meta(fp)
	local inv = meta:get_inventory()
	check(inv:get_size("fuel") == 3, "campfire inventory not set up")
	inv:add_item("fuel", "bc:stick 4")
	inv:add_item("src", "bc:meat_raw")
	check(bc.ignite_fire(fp), "ignite failed")
	check(core.get_node(fp).name == "bc:campfire", "fire lay did not become a campfire")
	local on_timer = core.registered_nodes["bc:campfire"].on_timer
	local t0 = bc.clock
	for _ = 1, 30 do
		bc.clock = bc.clock + 0.03
		on_timer(fp)
	end
	check(meta:get_float("heat") > 0.9, "fire did not heat up: " .. meta:get_float("heat"))
	check(inv:contains_item("dst", "bc:meat_cooked"), "meat did not cook")
	check(meta:get_int("encl") == 1, "fire did not notice it is enclosed")
	for _ = 1, 60 do
		bc.clock = bc.clock + 0.05
		on_timer(fp)
	end
	check(core.get_node(fp).name ~= "bc:campfire", "fire never ran out of fuel")
	local heat_after = meta:get_float("heat")
	check(heat_after > 0.3, "insulated hut lost its heat too fast: " .. heat_after)
	-- same fire in the open loses heat fast
	clear_box({x = c.x - 1, y = c.y, z = c.z - 1}, {x = c.x + 1, y = c.y + 2, z = c.z + 1})
	core.set_node(fp, {name = "bc:campfire_unlit"})
	meta = core.get_meta(fp)
	meta:set_float("heat", 1)
	meta:set_float("last", bc.clock)
	for _ = 1, 20 do
		bc.clock = bc.clock + 0.05
		core.registered_nodes["bc:campfire_unlit"].on_timer(fp)
	end
	check(meta:get_float("heat") < 0.1, "open fire kept its heat: " .. meta:get_float("heat"))
	core.remove_node(fp)

	-- drying rack
	local rp = {x = c.x + 3, y = floor, z = c.z}
	core.set_node(rp, {name = "bc:rack"})
	local rmeta = core.get_meta(rp)
	rmeta:get_inventory():set_stack("main", 1, "bc:meat_raw")
	core.registered_nodes["bc:rack"].on_metadata_inventory_put(rp, "main", 1)
	check(core.registered_nodes["bc:rack"].allow_metadata_inventory_put(rp, "main", 1, ItemStack("bc:meat_raw")) == 0,
		"rack accepted two cuts on a single line")
	bc.clock = bc.clock + 1
	rmeta:get_inventory():set_stack("main", 2, "bc:grass")
	core.registered_nodes["bc:rack"].on_metadata_inventory_put(rp, "main", 2)
	core.registered_nodes["bc:rack"].on_timer(rp)
	check(rmeta:get_float("p1") > 0 and rmeta:get_float("p2") == 0, "freshly hung food reset the other line")
	for _ = 1, 8 do
		bc.clock = bc.clock + 3
		core.registered_nodes["bc:rack"].on_timer(rp)
	end
	check(rmeta:get_inventory():get_stack("main", 1):get_name() == "bc:meat_dried", "rack did not dry meat")

	-- snare: with nobody near, it catches something within a few days
	local sp = {x = c.x - 3, y = floor, z = c.z}
	core.set_node(sp, {name = "bc:snare"})
	local caught = false
	for _ = 1, 200 do
		bc.clock = bc.clock + 1
		core.registered_nodes["bc:snare"].on_timer(sp)
		if core.get_node(sp).name == "bc:snare_caught" then caught = true break end
	end
	check(caught, "snare never caught anything in 200 hours")

	-- spoilage in a basket inventory
	local bp = {x = c.x, y = floor, z = c.z + 3}
	core.set_node(bp, {name = "bc:basket"})
	local binv = core.get_meta(bp):get_inventory()
	binv:add_item("main", "bc:meat_raw 20")
	bc.spoil_list(binv, "main", 25, 48)
	check(binv:contains_item("main", "bc:meat_spoiled 10"), "meat did not spoil in two warm days")
	binv:set_list("main", {})
	binv:add_item("main", "bc:meat_raw 20")
	bc.spoil_list(binv, "main", -8, 48)
	check(binv:contains_item("main", "bc:meat_raw 18"), "meat spoiled while frozen")
	bc.clock = t0

	-- trees grow from saplings
	local tp = {x = c.x + 4, y = floor, z = c.z + 4}
	core.set_node(tp, {name = "bc:pine_sapling"})
	core.registered_nodes["bc:pine_sapling"].on_timer(tp)
	check(core.find_node_near(tp, 3, {"bc:pine_trunk"}), "sapling did not grow")

	note("phase1", "done")
	if not wait_player then finish() end
end

-- ------------------------------------------------------------------ player
local function player_checks(player)
	local name = player:get_player_name()
	local st = bc.state(player)
	if not check(st, "no state for joined player") then return finish() end
	local inv = player:get_inventory()
	check(st.hud and st.hud.rows and #st.hud.rows == 5, "HUD not built")
	check(inv:get_size("clothing") == 6 and inv:get_stack("clothing", 2):get_name() == "bc:shirt", "new player not dressed")
	note("player_spawn", core.pos_to_string(vector.round(player:get_pos())))
	note("player_biome", st.clim.biome)
	check(st.info and st.info.felt, "vitals loop has not produced info")
	note("felt", st.info and st.info.felt)

	-- which way is water, and temperatures in either unit
	st.water_near_t = nil
	bc.water_sense(player, st)
	check(bc.temp(st, 37, 1) == "37.0°C" and bc.temp_delta(st, 5, true) == "+5°C", "celsius formatting: " .. bc.temp(st, 37, 1))
	st.p.fahrenheit = true
	check(bc.temp(st, 37, 1) == "98.6°F" and bc.temp(st, -40) == "-40°F" and bc.temp_delta(st, 5, true) == "+9°F",
		"fahrenheit formatting: " .. bc.temp(st, 37, 1) .. " " .. bc.temp_delta(st, 5, true))
	bc.hud.update(player, st)
	for tab = 2, 4, 2 do
		st.tab = tab
		st.sel_topic = 2
		bc.journal.refresh(player, st)
		check(player:get_inventory_formspec():find("°F", 1, true), "tab " .. tab .. " does not show Fahrenheit")
	end
	st.p.fahrenheit = false

	-- every journal tab builds
	for tab = 1, 5 do
		st.tab = tab
		bc.journal.refresh(player, st)
		check(#player:get_inventory_formspec() > 200, "journal tab " .. tab .. " is empty")
	end
	st.tab = 1

	-- handling items teaches recipes and ticks goals
	inv:add_item("main", "bc:stick 10")
	inv:add_item("main", "bc:rock 4")
	inv:add_item("main", "bc:flint 2")
	inv:add_item("main", "bc:sharp_stone")
	inv:add_item("main", "bc:meat_raw 3")
	inv:add_item("main", "bc:dry_grass 5")
	inv:add_item("main", "bc:fire_drill")
	local knife_known_before = bc.recipe_known(st, bc.recipe_by_id.knife_flint)
	core.after(2.5, function() guarded("player phase 2", function()
		check(not knife_known_before and bc.recipe_known(st, bc.recipe_by_id.knife_flint), "flint did not unlock the flint knife")
		check(st.p.obj.gather and st.p.obj.knife, "gather/knife goals not ticked")
		check(st.load > 5, "pack weight not counted: " .. st.load)
		check(st.water and (st.water.near or st.water.pos ~= nil or st.water.from), "water sense produced nothing")
		note("water_text", bc.water_text(player, st))
		-- the long-range reading, as if nothing were in sight
		st.water, st.water_near_t = nil, core.get_us_time() / 1e6
		bc.water_sense(player, st)
		check(st.water and st.water.pos and not st.water.near, "long-range water reading gave nothing")
		note("water_text_far", bc.water_text(player, st))
		st.water, st.water_near_t = nil, nil
		check(st.scent, "raw meat scent not noticed")

		-- eating and drinking
		local kcal = st.v.kcal
		st.v.kcal = 500
		local stack = ItemStack("bc:meat_cooked")
		core.registered_items["bc:meat_cooked"].on_use(stack, player, {type = "nothing"})
		check(st.v.kcal == 1000 and stack:is_empty(), "eating cooked meat gave " .. (st.v.kcal - 500))
		st.v.water = 40
		check(bc.drink_from_node(player, "bc:river_water_source") and st.v.water > 50, "drinking from a river failed")
		st.v.water = 40
		stack = ItemStack("bc:pot_water_boiled")
		stack = core.registered_items["bc:pot_water_boiled"].on_use(stack, player, {type = "nothing"})
		check(st.v.water == 85 and stack:get_name() == "bc:pot", "boiled water: water " .. st.v.water .. " left " .. stack:get_name())
		check(st.p.obj.water, "safe water goal not ticked")
		-- mushrooms: taste then eat
		for color, kind in pairs(bc.mushrooms) do
			local def = core.registered_items["bc:mushroom_" .. color]
			def.on_use(ItemStack("bc:mushroom_" .. color), player, {type = "nothing"})
			check(type(st.p.notes["mushroom_" .. color]) == "string", "mushroom note missing for " .. color)
			if kind == "deadly" then check(st.v.aff.toxin, "deadly mushroom did not poison") end
		end
		st.v.aff = {}

		-- injury and treatment
		bc.sim.add_affliction(st.v, "bleeding")
		core.registered_items["bc:bandage"].on_use(ItemStack("bc:bandage"), player, {type = "nothing"})
		check(not st.v.aff.bleeding and st.v.aff.wound, "bandage did not stop bleeding")
		core.registered_items["bc:lichen_dressing"].on_use(ItemStack("bc:lichen_dressing"), player, {type = "nothing"})
		check(st.v.aff.wound_dressed and not st.v.aff.wound and st.p.notes.lichen, "lichen dressing did not work")
		local cond = st.v.condition
		bc.damage(player, 10, "wolf")
		check(math.abs(st.v.condition - (cond - 10)) < 0.5, "bc.damage did not reduce condition")

		-- fire by friction: keep trying until it lights
		local pos = vector.round(player:get_pos())
		local fp = {x = pos.x + 1, y = pos.y, z = pos.z}
		local under = {x = fp.x, y = fp.y - 1, z = fp.z}
		if core.get_node(under).name == "air" then core.set_node(under, {name = "bc:dirt"}) end
		core.set_node(fp, {name = "bc:campfire_unlit"})
		inv:add_item("main", "bc:dry_grass 40")
		for i = 1, 8 do if inv:get_stack("main", i):get_name() == "bc:fire_drill" then player:hud_set_hotbar_itemcount(8) end end
		local lit = false
		for _ = 1, 60 do
			st.fire_cd = nil
			local idx
			for i, s in ipairs(inv:get_list("main")) do if s:get_name() == "bc:fire_drill" then idx = i end end
			if not idx then inv:add_item("main", "bc:fire_drill") else
				local wield = player:get_wield_index()
				local a, b = inv:get_stack("main", wield), inv:get_stack("main", idx)
				inv:set_stack("main", wield, b)
				inv:set_stack("main", idx, a)
				core.registered_nodes["bc:campfire_unlit"].on_punch(fp, core.get_node(fp), player, {type = "node", under = fp, above = fp})
			end
			if core.get_node(fp).name == "bc:campfire" then lit = true break end
		end
		check(lit, "sixty tries with a bow drill never lit the fire")
		core.get_meta(fp):get_inventory():add_item("fuel", "bc:pine_trunk 3")   -- enough to last the night
		check(st.p.obj.fire, "fire goal not ticked")
		note("fire_skill", st.p.fire_skill)

		-- every edible thing can be eaten without error
		local eaten = 0
		for iname, idef in pairs(core.registered_items) do
			if idef._bc_food then
				st.v.kcal, st.v.water = 800, 50
				local left = idef.on_use(ItemStack(iname), player, {type = "nothing"})
				check(left and (left:is_empty() or left:get_name() ~= iname), "eating " .. iname .. " did not consume it")
				eaten = eaten + 1
			end
		end
		note("foods_eaten", eaten)
		st.v.aff = {}
		st.v.condition = 100

		-- camp furniture and tools: call each interaction the way the engine would
		local function wield(item)
			inv:set_stack("main", player:get_wield_index(), item)
			return player:get_wielded_item()
		end
		local q = {x = pos.x + 3, y = pos.y, z = pos.z + 2}
		local function ground(p)
			core.set_node({x = p.x, y = p.y - 1, z = p.z}, {name = "bc:dirt"})
			core.set_node({x = p.x, y = p.y + 1, z = p.z}, {name = "air"})
		end
		ground(q)
		core.set_node(q, {name = "bc:wattle"})
		local clay = ItemStack("bc:clay_lump 2")
		inv:add_item("main", "bc:grass")
		clay = clay:get_definition().on_place(clay, player, {type = "node", under = q, above = vector.offset(q, 0, 1, 0)})
		check(core.get_node(q).name == "bc:daub" and clay:get_count() == 1, "did not daub the wall in place")
		core.set_node(q, {name = "bc:door"})
		core.registered_nodes["bc:door"].on_rightclick(q, core.get_node(q), player, ItemStack(""))
		check(core.get_node(q).name == "bc:door_open", "door did not open")
		core.set_node(q, {name = "bc:cairn"})
		core.registered_nodes["bc:cairn"].after_place_node(q, player)
		check(st.p.home and st.p.home.x == q.x, "cairn did not mark camp")
		local at_camp = bc.trail.camp_spawn(st)
		check(at_camp and vector.distance(at_camp, q) < 3, "no safe standing place at the cairn")
		st.p.bearing = "camp"
		check(bc.trail.reading(st, vector.offset(q, 0, 0, -13)):find("north  13 m", 1, true), "camp bearing points away")
		st.p.bearing = nil
		core.set_node(q, {name = "bc:snare_caught"})
		core.registered_nodes["bc:snare_caught"].on_rightclick(q, core.get_node(q), player)
		check(inv:contains_item("main", "bc:rabbit_dead"), "snare gave no rabbit")
		inv:add_item("main", "bc:sharp_stone")
		local left = core.registered_items["bc:rabbit_dead"].on_use(ItemStack("bc:rabbit_dead"), player, {type = "nothing"})
		check(left:is_empty() and inv:contains_item("main", "bc:hide_raw"), "could not skin the rabbit")
		core.set_node(q, {name = "bc:bush_blue_ripe"})
		core.registered_nodes["bc:bush_blue_ripe"].on_rightclick(q, core.get_node(q), player)
		check(core.get_node(q).name == "bc:bush_blue" and inv:contains_item("main", "bc:berries_blue 3"), "berry picking failed")
		core.registered_nodes["bc:bush_blue"].on_timer(q)
		core.set_node(q, {name = "bc:fish_trap"})
		core.registered_nodes["bc:fish_trap"].on_timer(q)
		core.set_node(q, {name = "bc:basket"})
		core.registered_nodes["bc:basket"].on_timer(q)
		core.set_node(q, {name = "bc:torch"})
		core.registered_nodes["bc:torch"].on_timer(q)
		check(core.get_node(q).name == "air", "torch did not burn out")

		-- water: fill a pot and a skin at a pool, drink from a placed pot, fish
		core.set_node(q, {name = "bc:water_source"})
		local pt = {type = "node", under = q, above = {x = q.x, y = q.y + 1, z = q.z}}
		local filled = core.registered_items["bc:pot"].on_place(ItemStack("bc:pot"), player, pt)
		check(filled:get_name() == "bc:pot_water_raw", "pot did not fill")
		filled = core.registered_items["bc:waterskin"].on_place(ItemStack("bc:waterskin"), player, pt)
		check(filled:get_name() == "bc:waterskin_raw", "waterskin did not fill")
		local rod = wield("bc:fishing_rod")
		st.fish_at = nil
		bc.hunt.fish(rod, player, pt)
		if check(st.fishing, "casting did not put a float on the water") then
			st.fishing.bite = 2
			st.fish_at = nil
			bc.hunt.fish(rod, player, pt)
			check(inv:contains_item("main", "bc:fish_raw") and not st.fishing and st.p.obj.fish, "striking a bite caught nothing")
		end
		core.set_node(q, {name = "bc:pot_water_boiled"})
		st.v.water = 30
		core.registered_nodes["bc:pot_water_boiled"].on_rightclick(q, core.get_node(q), player)
		check(st.v.water == 75 and core.get_node(q).name == "bc:pot", "drinking from a placed pot failed")
		core.remove_node(q)

		-- torch lit at the fire; spear thrown; bow shot
		wield("bc:torch_unlit")
		core.registered_nodes["bc:campfire"].on_punch(fp, core.get_node(fp), player, {type = "node", under = fp, above = fp})
		check(inv:contains_item("main", "bc:torch"), "torch did not light at the fire")
		st.throw_at = nil
		local spear = core.registered_items["bc:spear_flint"].on_secondary_use(ItemStack("bc:spear_flint"), player, {type = "nothing"})
		check(spear:is_empty(), "spear was not thrown")
		inv:add_item("main", "bc:arrow 2")
		st.throw_at = nil
		core.registered_items["bc:bow"].on_use(ItemStack("bc:bow"), player, {type = "nothing"})
		check(not inv:contains_item("main", "bc:arrow 2"), "bow did not use an arrow")

		-- clothing slots only take the right garment; crafting returns the knife
		local allow = core.registered_allow_player_inventory_actions[1]
		check(allow(player, "put", inv, {listname = "clothing", index = 1, stack = ItemStack("bc:fur_hat")}) == 1, "hat refused on head")
		check(allow(player, "put", inv, {listname = "clothing", index = 4, stack = ItemStack("bc:fur_hat")}) == 0, "hat allowed on hands")
		inv:set_stack("clothing", 1, "bc:fur_hat")
		check(bc.clothing_stats(player) == 8, "clothing warmth wrong: " .. bc.clothing_stats(player))
		local coat = ItemStack("bc:fur_coat")
		coat:get_meta():set_string("owner_mark", "birch")
		local old = coat:get_definition().on_use(coat, player)
		check(old:get_name() == "bc:shirt" and inv:get_stack("clothing", 2):get_meta():get_string("owner_mark") == "birch",
			"quick equip lost a garment or its metadata")
		inv:set_stack("clothing", 2, old)
		inv:set_list("craft", {})
		local grid = {ItemStack("bc:stick"), ItemStack("bc:sharp_stone")}
		for _, cb in ipairs(core.registered_on_crafts) do cb(ItemStack("bc:hook"), player, grid, inv) end
		check(inv:get_stack("craft", 2):get_name() == "bc:sharp_stone" and inv:get_stack("craft", 2):get_wear() > 0,
			"knife not returned worn after crafting")
		inv:set_list("craft", {})

		-- practice: made once, a recipe can be laid out; made five times it is made on the way
		local saved_main, saved_crafted = inv:get_list("main"), st.p.crafted
		local hatchet, cordage = bc.recipe_by_id.hatchet, bc.recipe_by_id.cordage
		local function have(list, item) return inv:contains_item(list, item, true) end
		local function count(name)
			local n = 0
			for _, stack in ipairs(inv:get_list("main")) do
				if stack:get_name() == name then n = n + stack:get_count() end
			end
			return n
		end
		local function by_hand(r, times)
			for _ = 1, times do
				local hand = {}
				for i, item in ipairs(r.items) do hand[i] = ItemStack(item) end
				for _, cb in ipairs(core.registered_on_crafts) do cb(ItemStack(r.output), player, hand, inv) end
			end
		end
		local function grid_makes()
			return core.get_craft_result({method = "normal", width = 3, items = inv:get_list("craft")}).item:get_name()
		end
		st.p.crafted = {}
		inv:set_list("main", {})
		inv:add_item("main", "bc:rock 2")
		inv:add_item("main", "bc:stick 3")
		inv:add_item("main", "bc:grass 7")
		check(not bc.lay_out(player, st, hatchet), "a recipe never made by hand was laid out")
		by_hand(hatchet, 1)
		check(st.p.crafted.hatchet == 1, "a craft by hand was not counted")
		local ok, why = bc.lay_out(player, st, hatchet)
		check(not ok and why:find("1 x Cordage", 1, true), "missing cordage not reported: " .. tostring(why))
		by_hand(cordage, 4)
		check(not bc.plan_craft(st, bc.craft_pool(player), hatchet), "cordage made on the way before it was second nature")
		check(count("bc:grass") == 7 and inv:is_empty("craft"), "a refused lay-out changed the pack")
		by_hand(cordage, 1)
		local made
		ok, made = bc.lay_out(player, st, hatchet)
		check(ok and #made == 1 and made[1] == "bc:cordage", "cordage not made on the way: " .. dump(made))
		check(grid_makes() == "bc:hatchet", "laid-out grid gives '" .. grid_makes() .. "'")
		check(count("bc:grass") == 4 and count("bc:rock") == 1 and count("bc:stick") == 2 and count("bc:cordage") == 0,
			"materials not taken correctly: " .. dump(bc.craft_pool(player)))
		check(st.p.crafted.cordage == 6, "a craft made on the way was not counted")
		ok, made = bc.lay_out(player, st, hatchet)
		check(ok and #made == 0 and count("bc:grass") == 4 and count("bc:stick") == 2 and grid_makes() == "bc:hatchet",
			"laying the same recipe out again was not a no-op")

		-- two things made on the way, one of them with a knife that must come back
		st.p.crafted.fishing_rod, st.p.crafted.hook_wood = 1, 5
		inv:set_list("craft", {})
		inv:add_item("main", "bc:sharp_stone")
		ok, made = bc.lay_out(player, st, bc.recipe_by_id.fishing_rod)
		check(ok and #made == 2, "rod: " .. dump(made))
		check(grid_makes() == "bc:fishing_rod", "rod grid gives '" .. grid_makes() .. "'")
		check(count("bc:stick") == 0 and count("bc:grass") == 1 and count("bc:rock") == 1, "rod materials: " .. dump(bc.craft_pool(player)))
		local _, knife = bc.find_group(player, "bc_knife")
		check(knife and knife:get_wear() > 0, "knife not returned worn from a craft made on the way")

		-- the journal's own button, and the green list rows
		inv:set_list("craft", {})
		inv:set_list("main", {})
		inv:add_item("main", "bc:rock")
		inv:add_item("main", "bc:stick")
		inv:add_item("main", "bc:grass 3")
		st.tab = 3
		bc.journal.refresh(player, st)
		for i, e in ipairs(st.recipe_list) do
			if e.recipe == hatchet then st.sel_recipe = i end
		end
		bc.journal.refresh(player, st)
		local fs = player:get_inventory_formspec()
		check(fs:find("button[", 1, true) and fs:find("lay_out", 1, true), "no lay-out button for a practised recipe")
		check(fs:find("You will first make 1 x Cordage", 1, true), "journal does not say what will be made first")
		for _, cb in ipairs(core.registered_on_player_receive_fields) do cb(player, "", {lay_out = "x"}) end
		check(st.tab == 1 and grid_makes() == "bc:hatchet" and inv:is_empty("main"), "button did not lay the hatchet out")
		check(player:get_inventory_formspec():find("Made 1 x Cordage", 1, true), "pack tab does not say what was made")

		-- a pack too full for what is left over: nothing at all changes
		inv:set_list("craft", {"bc:flint"})
		inv:set_list("main", {})
		inv:add_item("main", "bc:rock 2")
		inv:add_item("main", "bc:stick 2")
		inv:add_item("main", "bc:grass 4")
		for _ = 1, 21 do inv:add_item("main", "bc:digging_stick") end
		local practised = st.p.crafted.cordage
		ok, why = bc.lay_out(player, st, hatchet)
		check(not ok and why:find("too full", 1, true), "full pack: " .. tostring(why))
		check(count("bc:grass") == 4 and count("bc:rock") == 2 and count("bc:stick") == 2 and have("craft", "bc:flint")
			and st.p.crafted.cordage == practised, "a lay-out that did not fit still changed things")
		-- ...but it is no obstacle when the grid only holds what the recipe uses
		inv:set_list("craft", {"bc:stick"})
		ok = bc.lay_out(player, st, hatchet)
		check(ok and grid_makes() == "bc:hatchet" and count("bc:stick") == 2, "full pack with a useful grid was refused")

		inv:set_list("craft", {})
		inv:set_list("main", saved_main)
		st.p.crafted = saved_crafted

		local probe = core.get_modpath("bc_probe")
		dofile(probe .. "/camp.lua")(check, player, q)
		dofile(probe .. "/ecology.lua")(player, check, q)
		dofile(probe .. "/campcraft.lua")(player, check)

		-- operator commands
		local cmd = core.registered_chatcommands.bc.func
		for _, c in ipairs({"info", "set water 50", "weather rain", "wind 3", "afflict sprain", "cure", "weather clear"}) do
			check(cmd(name, c), "/bc " .. c .. " failed")
		end

		-- animals near a player: they live, and die into a butcherable carcass
		local spawned = {}
		for aname in pairs(bc.animals) do
			local obj = bc.spawn_animal(aname, {x = pos.x + math.random(-3, 3), y = pos.y + 2, z = pos.z + math.random(-3, 3)})
			if check(obj, "could not spawn " .. aname) then spawned[aname] = obj end
		end
		core.after(3, function() guarded("animals", function()
			for aname, obj in pairs(spawned) do
				if check(obj:get_pos(), aname .. " vanished within seconds") then
					local e = obj:get_luaentity()
					note("state_" .. aname, e.state)
					obj:punch(player, 1.0, {full_punch_interval = 1.0, damage_groups = {fleshy = 500}}, {x = 0, y = 0, z = 1})
					check(e.dead and e.parts and #e.parts > 0, aname .. " did not become a carcass")
					note("carcass_" .. aname, #(e.parts or {}))
					if aname == "rabbit" then
						-- butcher it with the sharp stone
						local n0 = #e.parts
						for i, s in ipairs(inv:get_list("main")) do
							if s:get_name() == "bc:sharp_stone" then
								local w = player:get_wield_index()
								local sw = inv:get_stack("main", w)
								inv:set_stack("main", w, s)
								inv:set_stack("main", i, sw)
								break
							end
						end
						st.butcher_at = nil
						e:on_rightclick(player)
						check(#(e.parts or {}) == n0 - 1, "butchering took nothing")
					end
					obj:remove()
				end
			end
			check(st.p.obj.hunt, "hunt goal not ticked")
		end) end)

		-- thrown rock becomes a projectile and lands
		st.throw_at = nil
		core.registered_items["bc:rock"].on_use(ItemStack("bc:rock"), player, {type = "nothing"})

		core.after(3.5, function() guarded("sleep", function()
		-- bed and sleep: the night should fast-forward
		local bed = {x = pos.x - 1, y = pos.y, z = pos.z}
		if core.get_node({x = bed.x, y = bed.y - 1, z = bed.z}).name == "air" then
			core.set_node({x = bed.x, y = bed.y - 1, z = bed.z}, {name = "bc:dirt"})
		end
		core.set_node(bed, {name = "bc:bed"})
		st.v.rest = 30
		st.v.core = 37
		local clock0 = bc.clock
		core.registered_nodes["bc:bed"].on_rightclick(bed, core.get_node(bed), player, ItemStack(""))
		check(st.sleeping, "could not get into bed")
		core.after(4, function() guarded("player phase 3", function()
			local passed = bc.clock - clock0
			note("hours_passed_in_4s_asleep", passed)
			note("still_sleeping", st.sleeping ~= nil)
			note("rest_core_cond", {st.v.rest, st.v.core, st.v.condition})
			note("tod", core.get_timeofday())
			check(passed > 0.8, "time did not fast-forward while asleep: " .. passed)
			check(st.v.rest > 35 or not st.sleeping, "sleep did not restore rest")
			note("fire_warmth_near_campfire", st.clim.fire)
			check((st.clim.fire or 0) > 5, "no warmth felt next to a burning fire")
			if st.sleeping then bc.sleep.stop(player, "up") end
			check(not st.sleeping, "could not wake")

			-- death: pack is left behind, body resets
			inv:add_item("main", "bc:hatchet")
			local where = vector.round(player:get_pos())
			bc.die(player, "hypothermia")
			check(st.v.condition == 100 and inv:is_empty("main"), "death did not reset the player")
			local remains = core.find_node_near(where, 5, {"bc:remains"}, true)
			note("death_where", core.pos_to_string(where))
			note("node_at_where", core.get_node(where).name)
			local ents = 0
			for _, o in ipairs(core.get_objects_inside_radius(where, 6)) do
				local e = o:get_luaentity()
				if e and e.name == "__builtin:item" then ents = ents + 1 end
			end
			note("dropped_item_entities", ents)
			check(remains and not core.get_meta(remains):get_inventory():is_empty("main"), "no remains left behind")
			check(st.p.lost_pack and vector.equals(st.p.lost_pack, remains), "lost pack was not marked")
			if remains then
				st.p.bearing = "pack"
				core.get_meta(remains):get_inventory():set_list("main", {})
				bc.trail.check_pack(remains)
				check(not st.p.lost_pack and not st.p.bearing, "empty pack still has a bearing")
			end
			check(st.p.deaths == 1, "death not counted")
			check(inv:get_stack("clothing", 2):get_name() == "bc:shirt", "not re-dressed after death")
			note("phase2", "done")
			core.after(1, finish)
		end) end)
		end) end)
	end) end)
end

core.register_on_mods_loaded(function()
	guarded("static", static_checks)
end)

-- The starting point is confirmed a moment after start-up (water.lua
-- generates and checks the country round it); wait for that.
local started = core.get_us_time()
local function when_spawn_settled(fn, tries)
	local pos, confirmed = bc.world_spawn()
	if confirmed or (tries or 0) > 160 then return fn(pos, confirmed) end
	core.after(0.5, function() when_spawn_settled(fn, (tries or 0) + 1) end)
end

core.after(0.5, function()
	when_spawn_settled(function(pos, confirmed)
		guarded("spawn", function()
			base = pos
			if not check(base, "no spawn point found") then return finish() end
			check(confirmed, "starting point was never confirmed")
			note("spawn", core.pos_to_string(base))
			if old_spawn and old_spawn ~= "" then
				check(core.pos_to_string(base) ~= old_spawn, "an old dry start point was not replaced")
			end
			note("spawn_settled_after_s", (core.get_us_time() - started) / 1e6)
			local water = core.string_to_pos(bc.storage:get_string("spawn_water"))
			if check(water, "no water recorded near the starting point") then
				local d = bc.hdist(base, water)
				note("spawn_to_water_m", d)
				check(d <= 100, "starting point is " .. math.floor(d) .. " m from water")
				check(core.get_item_group(core.get_node(water).name, "bc_water") > 0, "recorded spawn water is not water")
			end
			-- guesses about far-off water must be confirmed, never taken on trust
			local inland = {x = base.x + 700, y = 0, z = base.z + 700}
			bc.find_water(inland, 480, function(found)
				guarded("find_water", function()
					note("inland_water_m", found and bc.hdist(inland, found) or "none")
					if found then
						check(core.get_item_group(core.get_node(found).name, "bc_water") > 0, "find_water returned a dry spot")
					end
				end)
				core.emerge_area(vector.subtract(base, {x = 64, y = 32, z = 64}), vector.add(base, {x = 64, y = 48, z = 64}),
					function(_, _, remaining)
						if remaining == 0 then core.after(0.5, function() guarded("world", world_checks) end) end
					end)
			end)
		end)
	end)
end)

if wait_player then
	core.register_on_joinplayer(function(player)
		core.after(4, function() guarded("player", function() player_checks(player) end) end)
	end)
	-- never hang forever if no client shows up
	core.after(150, function()
		fail("no player joined within 150 s")
		finish()
	end)
else
	core.after(120, function()
		fail("phase 1 did not finish within 120 s")
		finish()
	end)
end
