-- Start on the probe's elevated, open-air platform.
return function(check, pos)
	local start, weather, front = bc.clock, bc.weather.state, bc.weather.front
	local roof = vector.offset(pos, 0, 2, 0)
	local function tick(hours)
		bc.clock = bc.clock + hours
		core.registered_nodes[core.get_node(pos).name].on_timer(pos)
	end
	bc.weather.state, bc.weather.front = "rain", 30
	core.set_node(pos, {name = "bc:campfire_unlit"})
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	inv:set_stack("fuel", 1, "bc:stick 12")
	bc.ignite_fire(pos)
	local amount, kind = bc.rained_on(pos)
	check(amount == 1 and kind == "rain", "open test hearth was not exposed to rain")
	tick(0.1)
	check(core.get_node(pos).name == "bc:campfire" and meta:get_float("soaking") > 0,
		"ordinary rain did not begin soaking the fire")
	core.set_node(roof, {name = "bc:thatch"})
	tick(0.25)
	check(core.get_node(pos).name == "bc:campfire" and meta:get_float("soaking") == 0,
		"a roof failed to interrupt the soaking")
	core.remove_node(roof)
	inv:set_stack("src", 1, "bc:meat_raw")
	meta:set_float("burn", 1)
	tick(0.26)
	check(core.get_node(pos).name == "bc:campfire_unlit" and meta:get_float("heat") == 0
		and meta:get_float("ember") == 0, "rain left a live fire or hot coals")
	check(inv:contains_item("fuel", "bc:stick 12") and inv:contains_item("src", "bc:meat_raw"),
		"rain discarded spare fuel or cooked ingredients after extinguishing the fire")
	bc.weather.state = "storm"
	bc.ignite_fire(pos)
	meta:set_float("burn", 1)
	tick(0.14)
	check(core.get_node(pos).name == "bc:campfire_unlit", "downpour failed to douse the open fire faster")
	tick(1)
	check(core.get_node(pos).name == "bc:campfire_unlit", "cold wet fire rekindled itself")

	bc.weather.state = "clear"
	bc.ignite_fire(pos)
	inv:set_list("fuel", {})
	meta:set_float("burn", 0.02)
	tick(0.05)
	check(core.get_node(pos).name == "bc:campfire_embers", "could not relight doused ashes in dry weather")
	inv:set_stack("fuel", 1, "bc:stick 3")
	bc.weather.state = "rain"
	tick(12)
	check(core.get_node(pos).name == "bc:campfire_unlit" and inv:contains_item("fuel", "bc:stick 3"),
		"a long wet tick rekindled doused coals or used up spare fuel")
	core.remove_node(pos)
	bc.clock, bc.weather.state, bc.weather.front = start, weather, front
end
