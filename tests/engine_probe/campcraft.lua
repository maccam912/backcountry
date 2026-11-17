return function(player, check)
	local inv, st = player:get_inventory(), bc.state(player)
	local saved_grid, saved_main = inv:get_list("craft"), inv:get_list("main")
	local saved_crafted = st.p.crafted
	st.p.crafted = {}
	local function fields(values)
		for _, cb in ipairs(core.registered_on_player_receive_fields) do cb(player, "", values) end
	end

	inv:set_list("craft", {})
	inv:set_list("main", {"bc:rock 2"})
	st.tab = 3
	bc.journal.refresh(player, st)
	fields({filter_recipes = "true"})
	local index
	for i, row in ipairs(st.recipe_list) do
		if row.recipe == bc.recipe_by_id.sharp_stone then index = i end
		check(not row.recipe or row.plan, "recipe filter included a recipe missing materials")
	end
	if check(index, "the two rocks did not show the unpractised sharp stone") then
		fields({recipes = "CHG:" .. index})
		fields({pin_recipe = "true"})
		check(st.p.pinned_recipe == "sharp_stone", "pin did not track the selected recipe")
		inv:set_list("main", {"bc:rock"})
		for _ = 1, 3 do bc.journal.tick(player, st) end
		check((st.goal_text or ""):find("1 x Rock", 1, true), "gathering list did not count the missing rock")
		check(#st.recipe_list == 0 and player:get_inventory_formspec():find("show_pin", 1, true),
			"the recipe filter was stale, or a hidden pinned recipe could not be opened")
		fields({show_pin = "true"})
		check(st.recipe_list[st.sel_recipe].key == "sharp_stone" and not st.recipes_ready,
			"the book did not return to the pinned recipe")
		inv:set_list("main", {"bc:rock 2"})
		bc.journal.tick(player, st)
		check((st.goal_text or ""):find("Materials ready", 1, true), "the pin did not update after finding the last rock")
	end
	st.p.pinned_recipe = nil
	fields({filter_recipes = "false"})
	local roll_recipe = bc.recipe_by_id.ember_roll
	local knew_bark = st.p.items["bc:bark"]
	st.p.items["bc:bark"] = nil
	check(not bc.recipe_known(st, roll_recipe), "ember roll was already known with a missing prerequisite")
	local grid = {}
	for i, name in ipairs(roll_recipe.items) do grid[i] = ItemStack(name) end
	for _, cb in ipairs(core.registered_on_crafts) do cb(ItemStack(roll_recipe.output), player, grid, inv) end
	check(bc.recipe_known(st, roll_recipe) and bc.times_crafted(st, roll_recipe) == 1,
		"handmade experimental recipe did not appear in the journal")
	st.p.items["bc:bark"] = knew_bark

	st.p.crafted.cordage_nettle, st.p.crafted.bandage = 5, 1
	inv:set_list("main", {"bc:nettle 2"})
	local laid = bc.lay_out(player, st, bc.recipe_by_id.bandage)
	check(laid and inv:contains_item("craft", "bc:cordage 2") and inv:is_empty("main"),
		"a two-cordage nettle craft did not supply both bandage ingredients")
	local worn = ItemStack("bc:knife_flint")
	worn:set_wear(41000)
	worn:get_meta():set_string("description", "My knife")
	inv:set_list("craft", {worn})
	inv:set_list("main", {})
	for i = 1, inv:get_size("main") do inv:set_stack("main", i, "bc:hatchet") end
	check(not bc.clear_craft_grid(player) and inv:get_stack("craft", 1):to_string() == worn:to_string(), "full pack lost the craft grid")
	inv:set_stack("main", 4, "")
	st.tab = 1
	fields({clear_grid = "true"})
	check(inv:is_empty("craft") and inv:get_stack("main", 4):to_string() == worn:to_string(), "return materials lost tool wear or metadata")

	local pos = vector.offset(vector.round(player:get_pos()), 0, 4, 0)
	local old = core.get_node(pos)
	local saved_meta = core.get_meta(pos):to_table()
	local pt = {type = "node", under = pos, above = vector.offset(pos, 0, 1, 0)}
	-- From a freshly picked dry grass tuft and the sticks in a dead shrub:
	-- no leaves, cord, tool, or animal material has to be found first.
	local pallet = bc.recipe_by_id.grass_pallet
	local newcomer = {p = {crafted = {}, items = {["bc:dry_grass"] = true}, notes = {}}}
	local materials = {["bc:dry_grass"] = 4, ["bc:stick"] = 2}
	check(core.registered_nodes["bc:dry_grass_tuft"].drop == "bc:dry_grass"
		and bc.recipe_known(newcomer, pallet) and bc.plan_craft(newcomer, materials, pallet),
		"local grass and sticks did not make the pallet available")
	local rest = st.v.rest
	st.v.rest = 30
	local quality, warmth
	for _, id in ipairs({"bc:bed", "bc:grass_pallet"}) do
		core.set_node(pos, {name = id})
		core.item_place(ItemStack(""), player, pt)
		if check(st.sleeping, "could not lie down on " .. id) then
			if quality then
				check(st.sleeping.quality > 0 and st.sleeping.quality < quality and st.sleeping.warmth > 0
					and st.sleeping.warmth < warmth, "grass pallet rest or insulation is out of balance")
			end
			quality, warmth = st.sleeping.quality, st.sleeping.warmth
			bc.sleep.stop(player, "up", true)
		end
	end
	st.v.rest = rest
	core.set_node(pos, {name = "bc:trail_marker", param2 = 1})
	for _, pair in ipairs({{"bc:waterskin", "water"}, {"bc:berries_blue", "berries"}, {"bc:pot", "water"},
			{"bc:hook", "fish"}, {"bc:pot_water_boiled", "water"}, {"bc:bed", "camp"}, {"bc:pot_rainwater", "water"}}) do
		local stack = ItemStack(pair[1])
		local held = stack:get_definition().on_place(stack, player, pt)
		check(core.get_node(pos).name == "bc:trail_marker_" .. pair[2] and core.get_node(pos).param2 == 1
			and held:get_name() == pair[1], pair[1] .. " could not mark the existing trail direction")
	end
	check(core.get_meta(pos):get_string("infotext") == "Water to the east", "painted sign points in the wrong direction")
	core.item_place(ItemStack("bc:charcoal"), player, pt)
	check(core.get_node(pos).param2 == core.dir_to_facedir(player:get_look_dir()), "trail marker did not turn")
	core.set_node(pos, {name = "bc:honing_slab"})
	inv:set_list("main", {"bc:sand"})
	local honed = core.item_place(ItemStack(worn), player, pt)
	check(honed:get_wear() == 41000 - 21845 and honed:get_meta():get_string("description") == "My knife"
		and inv:is_empty("main"), "honing failed to preserve the knife or spend its grit")
	local no_grit = core.item_place(ItemStack(honed), player, pt)
	check(no_grit:to_string() == honed:to_string(), "honing without grit changed the blade")

	core.set_node(pos, {name = "bc:campfire_embers"})
	local roll = ItemStack("bc:ember_roll")
	local use = roll:get_definition().on_use
	roll = use(roll, player, pt)
	check(roll:get_name() == "bc:ember_roll_lit", "ember roll could not load a coal from embers")
	core.set_node(pos, {name = "bc:campfire_unlit"})
	local cold = ItemStack(roll)
	cold:get_meta():set_float("until", bc.clock - 1)
	check(use(cold, player, pt):get_name() == "bc:ember_roll" and core.get_node(pos).name == "bc:campfire_unlit",
		"a cold roll lit a fire")
	check(use(roll, player, pt):is_empty() and core.get_node(pos).name == "bc:campfire" and st.p.notes.carried_fire,
		"fresh roll failed to light the lay, spend the roll, or teach its field note")
	core.set_node(pos, old)
	core.get_meta(pos):from_table(saved_meta)
	inv:set_list("main", saved_main)
	inv:set_list("craft", saved_grid)
	st.p.crafted = saved_crafted
end
