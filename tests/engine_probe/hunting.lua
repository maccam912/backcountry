-- Fire at a live deer, then give the engine time to move the animal and
-- projectile. The stone clearing also exercises blood on hard ground.
return function(player, check, note, guarded, finish)
	local floor = vector.offset(vector.round(player:get_pos()), 0, 20, 0)
	local ground = {}
	for x = -24, 24 do for z = -2, 49 do
		ground[#ground + 1] = vector.offset(floor, x, 0, z)
	end end
	core.bulk_set_node(ground, {name = "bc:stone"})
	player:set_pos(vector.offset(floor, 0, 0.5, 0))
	player:set_look_horizontal(0)
	player:set_look_vertical(0.14)
	local here = vector.offset(floor, 0, 0.5, 6)
	local deer = bc.spawn_animal("deer", here)
	local animal = deer:get_luaentity()
	local st = bc.state(player)
	local inv = player:get_inventory()
	local starter = {p = {crafted = {}, notes = {}, items = {}}}
	check(bc.recipe_known(starter, bc.recipe_by_id.bow) and bc.recipe_known(starter, bc.recipe_by_id.arrow),
		"bow and arrows hidden from a new player")
	local bundle = core.get_craft_result({method = "normal", width = 1, items = {"bc:stick"}}).item
	check(bundle:get_name() == "bc:arrow" and bundle:get_count() == 6, "a stick did not supply six arrows")
	player:set_wielded_item(ItemStack("bc:bow"))
	inv:add_item("main", bundle)
	st.p.obj.hunt, st.throw_at = nil, nil
	local bow = player:get_wielded_item()
	player:set_wielded_item(bow:get_definition().on_use(bow, player, {type = "nothing"}))
	check(inv:contains_item("main", "bc:arrow 5") and not inv:contains_item("main", "bc:arrow 6"), "shot spent wrong arrow count")

	local function blood_near(at, dist)
		local found = {}
		for _, obj in ipairs(core.get_objects_inside_radius(at, dist)) do
			local e = obj:get_luaentity()
			if e and e.name == "bc:trail_print" and e.blood then found[#found + 1] = e end
		end
		return found
	end
	core.after(1.5, function() guarded("arrow impact", function()
		check(animal.wounded and not animal.dead and animal.state == "flee", "arrow did not wound a fleeing deer")
		local hit = blood_near(here, 3)
		if check(#hit > 0, "no blood where the arrow hit stone") then
			local sign = hit[1]
			local data, at, born = sign:get_staticdata(), sign.object:get_pos(), sign.born
			check(sign.object:get_properties().static_save, "blood trail is lost when its mapblock unloads")
			sign.object:remove()
			local restored = core.add_entity(at, "bc:trail_print", data):get_luaentity()
			check(restored.born == born and restored.blood and restored.direction
				and restored.object:get_properties().textures[1]:find("bc_track_blood.png", 1, true),
				"bloody print did not retain its age, direction and art")
		end
		local state, at = animal:get_staticdata(), deer:get_pos()
		deer:remove()
		deer = core.add_entity(at, "bc:deer", state)
		animal = deer:get_luaentity()
		check(animal.wounded and animal.arrows == 1 and animal.hunter == player:get_player_name(),
			"restored animal lost its wound, arrow or hunter")
	end) end)
	core.after(8.5, function() guarded("follow and butcher", function()
		if check(deer:get_pos() and animal.dead and animal.parts, "deer never went down after one arrow") then
			local down = deer:get_pos()
			local marks, distance, nearest = blood_near(here, 60), bc.hdist(here, down), 100
			for _, mark in ipairs(marks) do
				nearest = math.min(nearest, vector.distance(mark.object:get_pos(), down))
			end
			note("deer_trail", {blood_marks = #marks, metres = distance, last_mark_metres = nearest, down = down, start = here})
			check(distance > 5 and #marks >= 3 and nearest <= 3, "blood trail did not reach the carcass")
			check(st.p.obj.hunt, "delayed kill lost hunting credit")
			player:set_pos(vector.offset(down, 1, 0, 0))
			player:set_wielded_item(ItemStack("bc:sharp_stone"))
			st.butcher_at = nil
			animal:on_rightclick(player)
			check(inv:contains_item("main", "bc:arrow 6") and inv:contains_item("main", "bc:meat_raw"),
				"first cut did not return meat and the embedded arrow")
			st.butcher_at = nil
			animal:on_rightclick(player)
			check(not inv:contains_item("main", "bc:arrow 7"), "butchering duplicated an arrow")
		end
		player:set_pos(vector.offset(floor, 0, 0.5, 0))
		player:set_look_horizontal(0)
		player:set_look_vertical(0)
		local wall = vector.offset(floor, 0, 2, 5)
		core.set_node(wall, {name = "bc:stone"})
		player:set_wielded_item(ItemStack("bc:bow"))
		local spare = player:get_wielded_item()
		player:set_wielded_item(spare:get_definition().on_use(spare, player, {type = "nothing"}))
		core.after(0.8, function() guarded("missed arrow", function()
			local found = false
			for _, obj in ipairs(core.get_objects_inside_radius(wall, 3)) do
				local e = obj:get_luaentity()
				if e and e.name == "__builtin:item" and ItemStack(e.itemstring):get_name() == "bc:arrow" then found = true end
			end
			check(found, "missed arrow was not recoverable at the wall")
			finish()
		end) end)
	end) end)
end
