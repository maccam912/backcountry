-- Extra player-phase checks for rain collection, shared meals and queued cooking.
return function(check, player, pos)
	local st = bc.state(player)
	local kcal, water = st.v.kcal, st.v.water
	local clock, weather = bc.clock, bc.weather.state
	bc.clock, bc.weather.state = 20, "clear"
	local function tick(hours)
		bc.clock = bc.clock + hours
		return core.registered_nodes[core.get_node(pos).name].on_timer(pos)
	end

	core.set_node(pos, {name = "bc:pot"})
	local rain = bc.rained_on
	bc.rained_on = function() return 0 end
	tick(1)
	bc.rained_on = function() return 2, "snow" end
	tick(1)
	check(core.get_meta(pos):get_float("rain_fill") == 0, "shelter or snow filled a water pot")
	bc.rained_on = function() return 1, "rain" end
	tick(1)
	check(core.get_meta(pos):get_float("rain_fill") == 0.5, "one hour of rain did not half-fill a pot")
	tick(1)
	bc.rained_on = rain
	check(core.get_node(pos).name == "bc:pot_rainwater", "rain did not fill a pot")
	local pt = {type = "node", under = pos, above = vector.offset(pos, 0, 1, 0)}
	for source, skin in pairs({pot_rainwater = "waterskin_clean", pot_water_raw = "waterskin_raw",
			pot_water_boiled = "waterskin_clean"}) do
		core.set_node(pos, {name = "bc:" .. source})
		local filled = core.registered_items["bc:waterskin"].on_place(ItemStack("bc:waterskin"), player, pt)
		check(filled:get_name() == "bc:" .. skin and core.get_node(pos).name == "bc:pot", "wrong transfer from " .. source)
		check(core.get_node_timer(pos):is_started(), "emptied " .. source .. " stopped collecting rain")
	end

	core.set_node(pos, {name = "bc:campfire_unlit"})
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	inv:add_item("fuel", "bc:stick 8")
	check(bc.ignite_fire(pos) and inv:contains_item("fuel", "bc:stick 8"), "lighting consumed the lay and its first fuel")
	inv:set_stack("src", 1, "bc:fish_raw 6")
	inv:set_stack("src", 2, "bc:pot_stew_raw")
	tick(1)
	check(inv:contains_item("dst", "bc:pot_stew") and inv:contains_item("dst", "bc:fish_cooked 3"),
		"a one-hour tick left cooked food behind")
	check(meta:get_float("cook1") > 0.09 and meta:get_float("cook1") < 0.11, "batch cooking lost leftover heat")
	inv:set_stack("src", 1, "bc:berry_dough")
	core.registered_nodes["bc:campfire"].on_metadata_inventory_move(pos, "src", 1, "src", 2, 1, player)
	check(meta:get_float("cook1") == 0, "new ingredient inherited old cook progress")
	for i = 1, 4 do inv:set_stack("dst", i, "bc:rock 99") end
	tick(0.5)
	check(inv:contains_item("src", "bc:berry_dough"), "full tray lost its input")
	inv:set_stack("dst", 1, "")
	core.registered_nodes["bc:campfire"].on_metadata_inventory_take(pos, "dst", 1, ItemStack("bc:rock 99"), player)
	check(inv:contains_item("dst", "bc:berry_griddlecake") and inv:is_empty("src"), "clearing tray lost a finished cake")
	inv:set_stack("src", 1, "bc:pot_unfired")
	inv:set_list("fuel", {})
	meta:set_float("burn", 0.1)
	tick(2)
	check(core.get_node(pos).name == "bc:campfire_embers" and meta:get_float("cook1") < 0.11,
		"food cooked after fuel ran out")
	inv:set_stack("src", 2, "bc:cattail_root")
	inv:set_stack("dst", 1, "")
	tick(0.6)
	check(inv:contains_item("dst", "bc:cattail_root_roasted") and meta:get_float("cook1") < 0.11,
		"embers should roast a root while the clay pot waits for flame")

	st.v.kcal, st.v.water = 500, 20
	for _, dish in ipairs({"stew", "chowder"}) do
		local name = "bc:pot_" .. dish
		core.set_node(pos, {name = name})
		core.registered_nodes[name].on_rightclick(pos, core.get_node(pos), player, ItemStack(""))
		check(core.get_node(pos).name == name .. "_last", dish .. " lost its second portion")
		core.registered_nodes[name .. "_last"].on_rightclick(pos, core.get_node(pos), player, ItemStack(""))
		check(core.get_node(pos).name == "bc:pot", "last serving of " .. dish .. " lost the pot")
	end
	check(st.v.kcal == 1670 and st.v.water == 86, "shared meals gave the wrong nutrition")
	core.set_node(pos, {name = "bc:pot_chowder_raw"})
	core.get_meta(pos):set_float("food_last", bc.clock - 24 * 365 * 100)
	tick(1)
	check(core.get_node(pos).name == "bc:pot" and core.get_node_timer(pos):is_started(),
		"placed chowder did not spoil back into a reusable pot")
	st.v.kcal, st.v.water = kcal, water
	bc.clock, bc.weather.state = clock, weather
	core.remove_node(pos)
end
