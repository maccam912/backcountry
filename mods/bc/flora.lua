-- Trees, plants and how they come back.
local S = bc.snd
bc.trees = {}

-- ---------------------------------------------------------------------
-- Tree shapes, built as schematic tables so no binary files are needed.
-- ---------------------------------------------------------------------
local function build_schem(sx, sy, sz, fn)
	local data = {}
	for z = 0, sz - 1 do
		for y = 0, sy - 1 do
			for x = 0, sx - 1 do
				data[#data + 1] = fn(x, y, z) or {name = "air", prob = 0}
			end
		end
	end
	return {size = {x = sx, y = sy, z = sz}, data = data}
end

local function conifer(trunk, leaves, h)
	local top = h + 1
	return build_schem(5, h + 2, 5, function(x, y, z)
		local dx, dz = math.abs(x - 2), math.abs(z - 2)
		if dx == 0 and dz == 0 and y < h then
			return {name = trunk, prob = 255, force_place = true}
		end
		if y < 3 then return end
		local d = top - y
		local r = (d == 0 and 0) or (d <= 2 and 1) or (d % 2 == 1 and 2) or 1
		if dx + dz <= r or (r == 2 and dx <= 2 and dz <= 2 and dx + dz <= 3) then
			return {name = leaves, prob = (dx + dz >= 2) and 215 or 255}
		end
	end)
end

local function broadleaf(trunk, leaves, h, rh, rv)
	local w = math.floor(rh) * 2 + 1
	local c = math.floor(rh)
	local cy = h
	return build_schem(w, h + math.ceil(rv) + 1, w, function(x, y, z)
		local dx, dz, dy = x - c, z - c, y - cy
		if dx == 0 and dz == 0 and y < h then
			return {name = trunk, prob = 255, force_place = true}
		end
		local d = (dx * dx + dz * dz) / (rh * rh) + (dy * dy) / (rv * rv)
		if d <= 1 then
			return {name = leaves, prob = d > 0.6 and 190 or 255}
		end
	end)
end

local function register_tree(id, def)
	local trunk, leaves, sapling = "bc:" .. id .. "_trunk", "bc:" .. id .. "_leaves", "bc:" .. id .. "_sapling"
	core.register_node(trunk, {
		description = def.name .. " Log",
		tiles = {"bc_" .. id .. "_trunk_top.png", "bc_" .. id .. "_trunk_top.png", "bc_" .. id .. "_trunk.png"},
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = {choppy = 1, tree = 1, flammable = 2, bc_insul = 2, bc_fuel = 1},
		sounds = S.wood,
		on_place = core.rotate_node,
		_bc_weight = 9,
		_bc_fuel = 3.5,
	})
	local drops = {{items = {sapling}, rarity = 25}}
	for _, extra in ipairs(def.leaf_drops or {}) do drops[#drops + 1] = extra end
	drops[#drops + 1] = {items = {"bc:stick"}, rarity = 4}
	drops[#drops + 1] = {items = {leaves}}
	core.register_node(leaves, {
		description = def.leaf_name or (def.name .. " Leaves"),
		drawtype = "allfaces_optional",
		tiles = {"bc_" .. id .. "_leaves.png"},
		waving = 1,
		paramtype = "light",
		is_ground_content = false,
		groups = {snappy = 3, leaves = 1, flammable = 2, bc_insul = 3, bc_thatch = 1},
		drop = {max_items = 1, items = drops},
		sounds = S.leaves,
		-- param2 = 1 marks leaves a person placed, so they never decay
		after_place_node = function(pos)
			local node = core.get_node(pos)
			node.param2 = 1
			core.swap_node(pos, node)
		end,
		_bc_weight = 0.4,
		_bc_fuel = 0.18,
		_bc_effort = {1, 0.03},
	})
	core.register_node(sapling, {
		description = def.name .. " Sapling",
		drawtype = "plantlike",
		tiles = {"bc_" .. id .. "_sapling.png"},
		inventory_image = "bc_" .. id .. "_sapling.png",
		wield_image = "bc_" .. id .. "_sapling.png",
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		selection_box = {type = "fixed", fixed = {-0.25, -0.5, -0.25, 0.25, 0.4, 0.25}},
		groups = {snappy = 3, attached_node = 1, flammable = 2, sapling = 1},
		sounds = S.leaves,
		on_construct = function(pos)
			core.get_node_timer(pos):start(bc.real_seconds(60 + math.random() * 60))
		end,
		on_timer = function(pos)
			local below = core.get_node({x = pos.x, y = pos.y - 1, z = pos.z})
			if core.get_item_group(below.name, "soil") == 0 then return false end
			if (core.get_node_light(pos, 0.5) or 0) < 11 then return true end
			core.remove_node(pos)
			local schems = bc.trees[id].schems
			core.place_schematic(pos, schems[math.random(#schems)], "random", nil, false,
				"place_center_x, place_center_z")
			return false
		end,
		_bc_weight = 0.2,
	})
	bc.trees[id] = {trunk = trunk, leaves = leaves, sapling = sapling, schems = def.schems(trunk, leaves)}
end

register_tree("pine", {
	name = "Pine", leaf_name = "Pine Boughs",
	leaf_drops = {{items = {"bc:lichen"}, rarity = 10}},
	schems = function(t, l) return {conifer(t, l, 7), conifer(t, l, 9), conifer(t, l, 11)} end,
})
register_tree("oak", {
	name = "Oak",
	leaf_drops = {{items = {"bc:acorn"}, rarity = 7}},
	schems = function(t, l) return {broadleaf(t, l, 4, 2.7, 2.1), broadleaf(t, l, 5, 3.2, 2.4)} end,
})
register_tree("birch", {
	name = "Birch",
	schems = function(t, l) return {broadleaf(t, l, 5, 1.9, 2.3), broadleaf(t, l, 6, 2.2, 2.6)} end,
})

-- Leaves with no trunk nearby fall away, sometimes leaving a stick.
core.register_abm({
	label = "bc leaf decay",
	nodenames = {"group:leaves"},
	interval = 7,
	chance = 10,
	action = function(pos, node)
		if node.param2 ~= 0 then return end
		if core.find_node_near(pos, 3, {"group:tree"}) then return end
		core.remove_node(pos)
		local r = math.random(30)
		if r <= 5 then
			core.add_item(pos, "bc:stick")
		elseif r == 6 then
			core.add_item(pos, (node.name:gsub("_leaves$", "_sapling")))
		end
	end,
})

-- Living trees shed dead wood: a renewable trickle of sticks under canopy.
core.register_abm({
	label = "bc branch fall",
	nodenames = {"group:leaves"},
	interval = 240,
	chance = 500,
	action = function(pos, node)
		if node.param2 ~= 0 then return end
		for dy = 1, 12 do
			local p = {x = pos.x, y = pos.y - dy, z = pos.z}
			local name = core.get_node(p).name
			if name ~= "air" then
				if core.get_item_group(name, "soil") > 0 then
					local above = {x = p.x, y = p.y + 1, z = p.z}
					if core.get_node(above).name == "air"
							and not core.find_node_near(above, 3, {"bc:branch"}) then
						core.set_node(above, {name = "bc:branch", param2 = math.random(0, 3)})
					end
				end
				return
			end
		end
	end,
})

-- ---------------------------------------------------------------------
-- Ground plants
-- ---------------------------------------------------------------------
local function plant(name, def)
	local tex = def.texture or ("bc_" .. name .. ".png")
	local base = {
		drawtype = "plantlike",
		tiles = {tex},
		inventory_image = tex,
		wield_image = tex,
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		floodable = true,
		waving = 1,
		is_ground_content = true,
		selection_box = {type = "fixed", fixed = {-0.3, -0.5, -0.3, 0.3, def.height or 0.2, 0.3}},
		sounds = S.leaves,
		_bc_weight = 0.05,
	}
	for k, v in pairs(def) do
		if k ~= "texture" and k ~= "height" then base[k] = v end
	end
	base.groups = base.groups or {}
	base.groups.snappy = base.groups.snappy or 3
	base.groups.attached_node = 1
	base.groups.flora = 1
	core.register_node("bc:" .. name, base)
end
bc.register_plant = plant

plant("grass_tuft", {
	description = "Tall Grass",
	buildable_to = true,
	drop = "bc:grass",
	groups = {flammable = 3, not_in_creative_inventory = 1},
})
plant("dry_grass_tuft", {
	description = "Dry Grass",
	buildable_to = true,
	drop = "bc:dry_grass",
	groups = {flammable = 3, not_in_creative_inventory = 1},
})
plant("dead_bush", {
	description = "Dead Shrub",
	drop = {max_items = 1, items = {{items = {"bc:stick 2"}, rarity = 3}, {items = {"bc:stick"}}}},
	height = 0.4,
	waving = 0,
	groups = {flammable = 3},
	sounds = S.wood,
})
plant("cattail", {
	description = "Cattail",
	drop = {max_items = 2, items = {{items = {"bc:cattail_root"}}, {items = {"bc:grass 2"}}}},
	height = 0.5,
	visual_scale = 1.3,
})
plant("nettle", {
	description = "Stinging Nettle",
	height = 0.4,
	groups = {bc_fiber = 1},
	after_dig_node = function(_, _, _, digger)
		if not digger or not digger:is_player() then return end
		if core.get_item_group(digger:get_wielded_item():get_name(), "bc_knife") == 0 then
			bc.damage(digger, 1.5, "nettles")
			bc.toast(digger, "The nettles sting your bare hands.")
		end
	end,
})
plant("yarrow", {
	description = "Yarrow",
	height = 0.3,
})
plant("onion_plant", {
	description = "Wild Onion",
	drop = "bc:onion",
	groups = {not_in_creative_inventory = 1},
})

-- Berry bushes fruit, are picked clean, and fruit again in the warm months.
-- Keep a game-clock deadline so nights passed asleep count toward regrowth.
local function fruit_in(pos, hours)
	core.get_meta(pos):set_float("fruit_after", bc.clock + hours)
	core.get_node_timer(pos):start(bc.real_seconds(2))
end

local function bush(color, desc, berries)
	local empty, ripe = "bc:bush_" .. color, "bc:bush_" .. color .. "_ripe"
	local cutting = empty .. "_cutting"
	local function regrow_time() return 40 + math.random() * 40 end
	plant("bush_" .. color .. "_cutting", {
		description = desc .. " Cutting\nPlant in sunlit soil. It takes a day to root in mild weather.",
		height = -0.12,
		on_place = function(stack, player, pt)
			if pt.type ~= "node" then return stack end
			local under = core.registered_nodes[core.get_node(pt.under).name]
			if under and under.on_rightclick and not player:get_player_control().sneak then
				return core.item_place(stack, player, pt)
			end
			local at = under and under.buildable_to and pt.under or pt.above
			if core.get_item_group(core.get_node(vector.offset(at, 0, -1, 0)).name, "soil") == 0 then
				bc.toast(player, "The cutting needs a patch of soil.")
				return stack
			end
			return core.item_place(stack, player, pt)
		end,
		on_construct = function(pos)
			core.get_meta(pos):set_float("root_after", bc.clock + 24)
			core.get_node_timer(pos):start(bc.real_seconds(1))
		end,
		on_timer = function(pos)
			if bc.clock < core.get_meta(pos):get_float("root_after")
					or core.get_item_group(core.get_node(vector.offset(pos, 0, -1, 0)).name, "soil") == 0
					or (core.get_natural_light(pos, 0.5) or 0) < 10
					or bc.climate.air(pos, {seasonal_only = true}) < 6 then return true end
			core.set_node(pos, {name = empty})
			return false
		end,
	})
	plant("bush_" .. color, {
		description = desc .. " Bush\nUse a knife on a picked bush to take a cutting.",
		texture = "bc_bush.png",
		height = 0.4,
		waving = 0,
		visual_scale = 1.2,
		drop = "bc:stick",
		on_construct = function(pos) fruit_in(pos, regrow_time()) end,
		on_rightclick = function(pos, _, player, stack)
			if not player or not player:is_player() then return stack end
			if core.get_item_group(stack:get_name(), "bc_knife") == 0 then
				bc.toast(player, "The berries are gone. A knife could take a cutting.")
				return stack
			end
			local name = player:get_player_name()
			if core.is_protected(pos, name) then
				core.record_protection_violation(pos, name)
				return stack
			end
			local meta = core.get_meta(pos)
			if meta:get_int("pruned") == 1 then
				bc.toast(player, "The tips have already been trimmed. Let the bush grow back.")
				return stack
			end
			meta:set_int("pruned", 1)
			local remaining = meta:get_float("fruit_after") - bc.clock
			if meta:get_string("fruit_after") == "" then
				-- Old bushes stored their remaining wait only in a node timer.
				local timer = core.get_node_timer(pos)
				remaining = (timer:get_timeout() - timer:get_elapsed()) / bc.real_seconds(1)
			end
			fruit_in(pos, math.max(0, remaining) + 18)
			-- Commit the tool use first so a last cut can free a pack slot.
			stack:add_wear(bc.CRAFT_WEAR)
			player:set_wielded_item(stack)
			bc.give(player, cutting)
			bc.learn(player, "berry_cuttings")
			return player:get_wielded_item()
		end,
		on_timer = function(pos)
			if bc.clock < core.get_meta(pos):get_float("fruit_after") then return true end
			if bc.climate and bc.climate.air(pos, {seasonal_only = true}) < 6 then
				fruit_in(pos, 6)
				return false
			end
			core.swap_node(pos, {name = ripe})
			return false
		end,
	})
	local function pick(pos, _, player)
		if not player or not player:is_player() then return end
		if core.get_node(pos).name ~= ripe then return end
		local name = player:get_player_name()
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return
		end
		core.swap_node(pos, {name = empty})
		core.get_meta(pos):set_int("pruned", 0)
		fruit_in(pos, regrow_time())
		bc.give(player, berries .. " " .. math.random(3, 5))
		bc.sound("bc_dig_leaves", pos, 0.5)
		bc.objective(player, "forage")
		return player:get_wielded_item()
	end
	plant("bush_" .. color .. "_ripe", {
		description = desc .. " Bush (ripe)\nPick the berries and the bush will bear again.",
		texture = "bc_bush_" .. color .. ".png",
		height = 0.4,
		waving = 0,
		visual_scale = 1.2,
		drop = {max_items = 2, items = {{items = {berries .. " 3"}}, {items = {"bc:stick"}}}},
		on_rightclick = pick,
		on_punch = pick,
		groups = {not_in_creative_inventory = 1},
	})
end
bush("blue", "Blueberry", "bc:berries_blue")
bush("red", "Raspberry", "bc:berries_red")

-- Prickly pear: desert water and sugar, if you find one in fruit.
plant("cactus", {
	description = "Prickly Pear",
	height = 0.4,
	waving = 0,
	visual_scale = 1.2,
	drop = "",
	groups = {snappy = 2},
	on_construct = function(pos) fruit_in(pos, 60 + math.random() * 60) end,
	on_timer = function(pos)
		if bc.clock < core.get_meta(pos):get_float("fruit_after") then return true end
		core.swap_node(pos, {name = "bc:cactus_ripe"})
		return false
	end,
})
do
	local function pick(pos, _, player)
		if not player or not player:is_player() then return end
		if core.get_node(pos).name ~= "bc:cactus_ripe" then return end
		local name = player:get_player_name()
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return
		end
		core.swap_node(pos, {name = "bc:cactus"})
		fruit_in(pos, 60 + math.random() * 60)
		bc.give(player, "bc:cactus_fruit " .. math.random(2, 3))
		bc.objective(player, "forage")
		return player:get_wielded_item()
	end
	plant("cactus_ripe", {
		description = "Prickly Pear (in fruit)",
		height = 0.4,
		waving = 0,
		visual_scale = 1.2,
		drop = "bc:cactus_fruit 2",
		groups = {snappy = 2, not_in_creative_inventory = 1},
		on_rightclick = pick,
		on_punch = pick,
	})
end

-- Decorations placed by mapgen skip on_construct. Start fruiting on the
-- unripe cacti in new chunks and in deserts explored by older saves.
core.register_lbm({
	label = "Start wild prickly pear fruiting",
	name = "bc:cactus_fruit_timer",
	nodenames = {"bc:cactus"},
	run_at_every_load = true,
	action = function(pos)
		local timer = core.get_node_timer(pos)
		if not timer:is_started() then fruit_in(pos, 60 + math.random() * 60) end
	end,
})

-- Grass creeps back over bare-topped soil.
core.register_abm({
	label = "bc grass regrowth",
	nodenames = {"bc:dirt_grass", "bc:dirt_dry_grass"},
	neighbors = {"air"},
	interval = 180,
	chance = 300,
	action = function(pos, node)
		local above = {x = pos.x, y = pos.y + 1, z = pos.z}
		if core.get_node(above).name ~= "air" then return end
		if (core.get_node_light(above, 0.5) or 0) < 12 then return end
		if core.find_node_near(above, 2, {"bc:grass_tuft", "bc:dry_grass_tuft"}) then return end
		core.set_node(above, {name = node.name == "bc:dirt_grass" and "bc:grass_tuft" or "bc:dry_grass_tuft"})
	end,
})
