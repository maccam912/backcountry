-- Stages a scene for screenshots. Used by tools/run_engine_tests.py --show.
local function at(t, fn) core.after(t, fn) end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local st = bc.state(player)
	core.set_timeofday(0.42)
	bc.weather.state, bc.weather.left, bc.weather.wind = "clear", 50, 2
	st.p.show_hints = false
	player:hud_set_flags({chat = false})   -- keep the screenshot clean

	at(2, function() core.close_formspec(name, "bc:welcome") end)
	at(3, function()
		local pos = vector.round(player:get_pos())
		-- level a patch in front of the player (towards +z)
		local gy = pos.y - 1
		for x = -7, 7 do for z = 2, 14 do
			for y = 0, 6 do core.set_node({x = pos.x + x, y = gy + 1 + y, z = pos.z + z}, {name = "air"}) end
			core.set_node({x = pos.x + x, y = gy, z = pos.z + z}, {name = "bc:dirt_grass"})
		end end
		local function put(dx, dy, dz, node, p2) core.set_node({x = pos.x + dx, y = gy + 1 + dy, z = pos.z + dz}, {name = node, param2 = p2 or 0}) end
		-- a small thatch hut with a door, bed inside
		for x = -6, -3 do for z = 8, 11 do for y = 0, 2 do
			local edge = x == -6 or x == -3 or z == 8 or z == 11 or y == 2
			if edge then put(x, y, z, y == 2 and "bc:thatch" or (z == 11 and "bc:daub" or "bc:wattle")) end
		end end end
		put(-4, 0, 8, "bc:door_open"); put(-4, 1, 8, "bc:door_open")
		put(-5, 0, 10, "bc:bed")
		-- log wall section and drystone
		put(-1, 0, 11, "bc:pine_trunk"); put(-1, 1, 11, "bc:pine_trunk"); put(0, 0, 11, "bc:birch_trunk"); put(1, 0, 11, "bc:oak_trunk")
		put(2, 0, 11, "bc:drystone"); put(3, 0, 11, "bc:drystone"); put(2, 1, 11, "bc:drystone")
		-- fire, pot, rack, basket, cairn, snare, torch
		put(0, 0, 6, "bc:campfire_unlit")
		local fp = {x = pos.x, y = gy + 1, z = pos.z + 6}
		core.get_meta(fp):get_inventory():add_item("fuel", "bc:pine_trunk 3")
		bc.ignite_fire(fp)
		put(1, 0, 6, "bc:pot_water_raw")
		put(2, 0, 7, "bc:rack")
		put(3, 0, 6, "bc:basket")
		put(-2, 0, 6, "bc:cairn")
		put(4, 0, 4, "bc:snare_caught")
		put(-2, 0, 4, "bc:torch")
		put(5, 0, 8, "bc:bedroll")
		-- plants in a row
		for i, n in ipairs({"bc:bush_blue_ripe", "bc:bush_red_ripe", "bc:mushroom_red", "bc:mushroom_brown", "bc:yarrow", "bc:nettle",
				"bc:cattail", "bc:onion_plant", "bc:cactus_ripe", "bc:grass_tuft", "bc:dry_grass_tuft", "bc:loose_rock", "bc:branch"}) do
			put(-7 + i, 0, 3, n)
		end
		-- animals, held still so they can be seen
		local spots = {deer = {3, 9}, wolf = {5, 6}, rabbit = {-1, 5}, grouse = {1, 4}, bear = {6, 11}}
		for animal, s in pairs(spots) do
			local obj = bc.spawn_animal(animal, {x = pos.x + s[1], y = gy + 1.6, z = pos.z + s[2]})
			if obj then
				local e = obj:get_luaentity()
				e.on_step = function(self) self.object:set_yaw(math.pi * 0.75) end
			end
		end
		player:set_look_horizontal(0)
		player:set_look_vertical(0.25)
		local inv = player:get_inventory()
		for _, item in ipairs({"bc:knife_flint", "bc:hatchet", "bc:spear_flint", "bc:bow", "bc:fishing_rod", "bc:fire_drill",
				"bc:torch", "bc:waterskin_clean", "bc:meat_cooked 3", "bc:berries_blue 6", "bc:stick 8", "bc:rock 3", "bc:cordage 4",
				"bc:hide_cured 2", "bc:flint", "bc:clay_lump 3", "bc:arrow 5", "bc:bark 2", "bc:yarrow 2", "bc:feather 3"}) do
			inv:add_item("main", item)
		end
		inv:set_stack("clothing", 1, "bc:fur_hat")
		st.v.kcal, st.v.water, st.v.rest, st.v.condition = 1350, 46, 62, 88
		bc.sim.add_affliction(st.v, "sprain")
	end)

	local function show_tab(tab)
		st.tab = tab
		st.sel_recipe = 6
		bc.journal.refresh(player, st)
		core.show_formspec(name, "bc:showcase", player:get_inventory_formspec())
	end
	at(13, function() show_tab(2) end)
	at(19, function() show_tab(3) end)
	at(25, function() show_tab(1) end)
	at(31, function() show_tab(4) end)
	at(37, function() show_tab(5) end)
	at(43, function()
		core.close_formspec(name, "bc:showcase")
		st.tab = 1
		core.set_timeofday(0.79)
		bc.weather.state, bc.weather.wind = "storm", 10
		st.sky_key = nil
	end)
	at(52, function()
		core.set_timeofday(0.5)
		bc.clock = bc.clock + bc.year_len * 0.5 * 24   -- midwinter
		bc.weather.state, bc.weather.wind = "rain", 5
		player:set_look_horizontal(math.pi)
		player:set_look_vertical(0.2)
		if player.set_camera then player:set_camera({mode = "third_front"}) end
	end)
end)
