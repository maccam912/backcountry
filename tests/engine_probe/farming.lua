return function(player, check, origin)
	local soil = vector.offset(origin, 0, 10, 0)
	local crop = vector.offset(soil, 0, 1, 0)
	local water = vector.offset(soil, 2, 0, 0)
	local inv = player:get_inventory()
	local saved, clock, weather = inv:get_list("main"), bc.clock, bc.weather.state
	inv:set_list("main", {})
	bc.clock, bc.weather.state = 10, "clear"
	for y = 0, 12 do core.remove_node(vector.offset(crop, 0, y, 0)) end
	core.set_node(soil, {name = "bc:dirt_grass"})
	local function use(pos, stack)
		local pt = {type = "node", under = pos, above = vector.offset(pos, 0, 1, 0)}
		return stack:get_definition().on_place(stack, player, pt)
	end
	local function tick(hours)
		bc.clock = bc.clock + hours
		return core.registered_nodes[core.get_node(crop).name].on_timer(crop)
	end
	local original_protection = core.is_protected
	local function protect(pos)
		core.is_protected = function(p, name)
			if vector.equals(p, pos) then return true end
			return original_protection(p, name)
		end
	end
	protect(soil)
	local stick = use(soil, ItemStack("bc:digging_stick"))
	check(core.get_node(soil).name == "bc:dirt_grass" and stick:get_wear() == 0, "protected soil was tilled")
	core.is_protected = original_protection
	stick = use(soil, stick)
	check(core.get_node(soil).name == "bc:tilled_soil" and stick:get_wear() > 0, "digging stick did not till the bed")

	-- Dig a wild bulb, then use that very item to start the crop.
	core.set_node(crop, {name = "bc:onion_plant"})
	core.node_dig(crop, core.get_node(crop), player)
	local bulb = inv:remove_item("main", "bc:onion")
	protect(crop)
	check(use(soil, bulb):get_count() == 1 and core.get_node(crop).name == "air", "planting bypassed protection")
	core.is_protected = original_protection
	check(not bulb:is_empty() and use(soil, bulb):is_empty(), "wild onion could not be planted")
	check(core.get_node(crop).name == "bc:crop_onion_shoots" and core.get_node_timer(crop):is_started(),
		"planting did not start the crop timer")
	check(use(soil, ItemStack("bc:onion")):get_count() == 1, "planting an occupied bed consumed a bulb")
	bc.clock = bc.clock + 30
	protect(soil)
	check(use(crop, ItemStack("bc:pot_water_raw")):get_name() == "bc:pot_water_raw"
		and core.get_meta(soil):get_float("watered_until") == 0, "watering bypassed protection")
	core.is_protected = original_protection
	-- Legacy or admin-created stacks can exceed the single-vessel stack limit.
	local pots = use(crop, ItemStack("bc:pot_water_raw 2"))
	check(pots:get_name() == "bc:pot_water_raw" and pots:get_count() == 1 and inv:contains_item("main", "bc:pot"),
		"watering lost a vessel or emptied the entire stack")
	check(core.get_meta(crop):get_float("growth") == 0, "watering counted time the crop had spent dry")
	check(use(crop, ItemStack("bc:waterskin_clean")):get_name() == "bc:waterskin_clean", "wet soil wasted a second watering")
	check(tick(9) and core.get_node(crop).name == "bc:crop_onion_growing", "watered onion did not grow leaves")
	check(not tick(9) and core.get_node(crop).name == "bc:crop_onion_ripe", "onion did not ripen")
	protect(soil)
	use(crop, player:get_wielded_item())
	core.node_dig(crop, core.get_node(crop), player)
	check(core.get_node(crop).name == "bc:crop_onion_ripe" and not inv:contains_item("main", "bc:onion"),
		"harvesting crossed the bed's protected boundary")
	core.is_protected = original_protection
	use(crop, player:get_wielded_item())
	check(core.get_node(crop).name == "air" and inv:contains_item("main", "bc:onion 4"), "ripe onion gave no harvest")
	bulb = inv:remove_item("main", "bc:onion")
	use(soil, bulb)
	check(core.get_node(crop).name == "bc:crop_onion_shoots" and inv:contains_item("main", "bc:onion 3"),
		"harvest could not seed a second crop and feed the player")
	core.remove_node(crop)

	core.get_meta(soil):set_float("watered_until", 0)
	core.set_node(crop, {name = "bc:cattail"})
	core.node_dig(crop, core.get_node(crop), player)
	local root = inv:remove_item("main", "bc:cattail_root")
	check(not root:is_empty() and use(soil, root):is_empty(), "wild cattail root could not be planted")
	local rain = bc.rained_on
	bc.rained_on = function() return 1, "rain" end
	tick(0.5)
	bc.rained_on = rain
	check(core.get_meta(soil):get_float("watered_until") >= bc.clock + 23, "rain did not wet the crop bed")
	core.get_meta(soil):set_float("watered_until", 0)
	core.set_node(water, {name = "bc:river_water_source"})
	check(not tick(24) and core.get_node(crop).name == "bc:crop_cattail_ripe", "nearby water did not irrigate the crop")
	for i = 1, inv:get_size("main") do inv:set_stack("main", i, "bc:hatchet") end
	use(crop, player:get_wielded_item())
	use(crop, player:get_wielded_item())
	local dropped = 0
	for _, ref in ipairs(core.get_objects_inside_radius(player:get_pos(), 3)) do
		local e = ref:get_luaentity()
		if e and e.name == "__builtin:item" and ItemStack(e.itemstring):get_name() == "bc:cattail_root" then
			dropped = dropped + ItemStack(e.itemstring):get_count()
			ref:remove()
		end
	end
	check(dropped == 4 and core.get_node(crop).name == "air", "full-pack harvest lost or duplicated produce")
	core.remove_node(water)
	core.remove_node(soil)
	inv:set_list("main", saved)
	bc.clock, bc.weather.state = clock, weather
end
