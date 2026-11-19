return function(check, origin, player)
	local function at(x, y, z) return vector.offset(origin, x, y, z) end
	local function put(p, name, param2) core.set_node(p, {name = name, param2 = param2}) end
	local function named(p) return core.get_node(p).name end
	local function dig(p)
		local n = core.get_node(p)
		core.registered_nodes[n.name].on_dig(p, n, player)
	end
	local function clear()
		for x = -5, 5 do for z = -5, 5 do
			put(at(x, -1, z), "bc:dirt")
			for y = 0, 6 do put(at(x, y, z), "air") end
		end end
	end
	local function stem(name)
		for y = 0, 3 do put(at(0, y, 0), name) end
		put(at(0, 4, 0), "bc:oak_leaves")
	end
	local log, tree, fallen = "bc:oak_trunk", bc.trees.oak.trunk, "bc:oak_fallen_trunk"
	local function fallen_count()
		return #core.find_nodes_in_area(at(-5, 0, -5), at(5, 6, 5), {fallen})
	end
	clear()
	if player then
		local inv = player:get_inventory()
		local saved = inv:get_list("main")
		inv:set_list("main", {})
		player:set_wielded_item(ItemStack("bc:hatchet"))
		stem(tree)
		dig(at(0, 2, 0))
		check(player:get_wielded_item():get_wear() > 0 and not inv:contains_item("main", log),
			"standing chop should use the hatchet and keep all timber in the world")
		local sections = core.find_nodes_in_area(at(-4, 0, -4), at(4, 0, 4), {fallen})
		for _, p in ipairs(sections) do dig(p) end
		check(#sections == 4 and inv:contains_item("main", log .. " 4") and fallen_count() == 0,
			"chopping the four fallen sections did not harvest exactly four logs")
		put(origin, log)
		put(at(0, 1, 0), "bc:oak_leaves")
		dig(origin)
		check(named(origin) == "air" and inv:contains_item("main", log .. " 5") and fallen_count() == 0,
			"a legacy upright building log below foliage did not dig as one log")
		inv:set_list("main", saved)
		return
	end

	-- A crown from an older save should fall even if the cut is halfway up.
	stem(log)
	local connected, orphan = at(1, 4, 0), at(0, 3, 2)
	put(connected, "bc:oak_leaves", 1)
	put(orphan, "bc:oak_leaves", 1)
	local check_leaf = core.registered_nodes["bc:oak_leaves"].on_timer
	check_leaf(connected)
	check_leaf(orphan)
	check(named(connected) == "bc:oak_leaves" and named(orphan) == "air",
		"leaf decay should follow connected leaves, including placed ones, with no support across an air gap")
	local block = at(0, 3, 0)
	local protection = core.is_protected
	core.is_protected = function(p, who) return vector.equals(p, block) or protection(p, who) end
	dig(at(0, 2, 0))
	core.is_protected = protection
	check(named(at(0, 0, 0)) == log and named(block) == log and fallen_count() == 0,
		"felling split a protected trunk")
	dig(at(0, 2, 0))
	check(fallen_count() == 4 and named(at(0, 3, 0)) == "air" and named(at(0, 0, 0)) == fallen,
		"mid-stem chop left hanging wood or lost a section of an old oak")
	check(core.get_node_timer(connected):is_started(), "felling did not start decay on the crown")
	check_leaf(connected)
	check(named(connected) == "air", "the horizontal trunk kept an unsupported crown alive")

	clear()
	-- Give the tree only one safe landing cell and verify repeated chopping.
	stem(tree)
	for _, offset in ipairs({{1,0}, {-1,0}, {0,1}, {0,-1}}) do put(at(offset[1], 0, offset[2]), "bc:basket") end
	dig(at(0, 0, 0))
	check(fallen_count() == 1 and core.get_meta(origin):get_int("sections") == 4,
		"a tree with no clear fall line lost unharvested sections")
	for _ = 1, 3 do dig(origin) end
	check(named(origin) == fallen, "a blocked fall yielded less than the whole trunk")
	dig(origin)
	check(named(origin) == "air" and named(at(1, 0, 0)) == "bc:basket", "felling overwrote a neighboring build")

	clear()
	local function windfall(name)
		for _, abm in pairs(core.registered_abms) do
			if abm.label == "bc unsupported oak" then
				abm.action(at(0, 3, 0), core.get_node(at(0, 3, 0)))
				return
			end
		end
		error("unsupported oak check missing for " .. name)
	end
	for _, cover in ipairs({"bc:onion_plant", "bc:water_source"}) do
		clear()
		put(at(0, 0, 0), cover)
		put(at(0, 3, 0), tree)
		put(at(0, 4, 0), tree)
		windfall(cover)
		local all = core.find_nodes_in_area(at(-4, 0, -4), at(4, 6, 4), {fallen})
		local grounded = #all == 2
		for _, p in ipairs(all) do grounded = grounded and named(vector.offset(p, 0, -1, 0)) == "bc:dirt" end
		check(grounded and named(at(0, 4, 0)) == "air", "unsupported tree floated above " .. cover)
	end
	clear()
	stem(tree)
	-- A protected block in the preferred direction should redirect the fall.
	local protected = at(0, 0, 1)
	core.is_protected = function(p, who) return vector.equals(p, protected) or protection(p, who) end
	dig(origin)
	core.is_protected = protection
	check(named(protected) == "air" and fallen_count() == 4, "fall destroyed a protected landing cell")

	clear()
	-- Make one safe lane, running gently downhill and then level again.
	for z = 1, 3 do
		put(at(0, -1, z), "air")
		put(at(0, -2, z), "bc:stone")
	end
	stem(tree)
	dig(origin)
	check(named(at(0, -1, 1)) == fallen and named(at(0, -1, 3)) == fallen,
		"downhill sections did not settle onto the slope")
end
