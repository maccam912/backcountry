-- Terrain and water.
-- Dig groups: crumbly (soil, by hand or digging stick), cracky (rock, needs
-- a pick), choppy (wood, needs a hatchet), snappy (plants).
-- bc_insul 1..3 says how well a node holds heat when it is part of a shelter.
local S = bc.snd

local function reg(name, def)
	def.is_ground_content = def.is_ground_content ~= false
	core.register_node("bc:" .. name, def)
end

reg("stone", {
	description = "Rock",
	tiles = {"bc_stone.png"},
	groups = {cracky = 1, bc_insul = 1},
	drop = {max_items = 2, items = {
		{items = {"bc:pyrite"}, rarity = 30},
		{items = {"bc:rock 2"}},
	}},
	sounds = S.stone,
	_bc_weight = 25,
})

reg("gravel", {
	description = "Gravel",
	tiles = {"bc_gravel.png"},
	groups = {crumbly = 1, falling_node = 1, bc_insul = 1},
	drop = {max_items = 1, items = {
		{items = {"bc:flint"}, rarity = 5},
		{items = {"bc:pyrite"}, rarity = 40},
		{items = {"bc:gravel"}},
	}},
	sounds = S.sand,
	_bc_weight = 12,
})

local dirt_drop = {max_items = 2, items = {
	{items = {"bc:worm"}, rarity = 9},
	{items = {"bc:dirt"}},
}}

reg("dirt", {
	description = "Dirt",
	tiles = {"bc_dirt.png"},
	groups = {crumbly = 2, soil = 1, bc_insul = 3},
	drop = dirt_drop,
	sounds = S.dirt,
	_bc_weight = 10,
})

local function topped(name, desc, top, side, sounds)
	reg(name, {
		description = desc,
		tiles = {top, "bc_dirt.png", {name = "bc_dirt.png^" .. side, tileable_vertical = false}},
		groups = {crumbly = 2, soil = 1, bc_insul = 3},
		drop = dirt_drop,
		sounds = sounds,
		_bc_weight = 10,
	})
end
topped("dirt_grass", "Grassy Soil", "bc_grass_top.png", "bc_grass_side.png", S.grass)
topped("dirt_dry_grass", "Dry Grassy Soil", "bc_dry_grass_top.png", "bc_dry_grass_side.png", S.grass)
topped("dirt_needles", "Forest Floor", "bc_needles_top.png", "bc_needles_side.png", S.grass)
topped("dirt_snow", "Snowy Soil", "bc_snow.png", "bc_snow_side.png", S.snow)

reg("sand", {
	description = "Sand",
	tiles = {"bc_sand.png"},
	groups = {crumbly = 3, falling_node = 1, bc_insul = 2},
	sounds = S.sand,
	_bc_weight = 12,
})

reg("clay", {
	description = "Clay Bed",
	tiles = {"bc_clay.png"},
	groups = {crumbly = 1, bc_insul = 3},
	drop = "bc:clay_lump 4",
	sounds = S.dirt,
	_bc_weight = 12,
})

reg("snow", {
	description = "Snow",
	tiles = {"bc_snow.png"},
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -0.25, 0.5}},
	collision_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -0.45, 0.5}},
	paramtype = "light",
	sunlight_propagates = true,
	buildable_to = true,
	floodable = true,
	walkable = false,
	groups = {crumbly = 3, falling_node = 1, bc_snow = 1},
	drop = "bc:snowball",
	sounds = S.snow,
})

reg("snow_block", {
	description = "Packed Snow",
	tiles = {"bc_snow.png"},
	groups = {crumbly = 3, bc_snow = 1, bc_insul = 3},
	drop = "bc:snowball 4",
	sounds = S.snow,
	_bc_weight = 6,
	_bc_effort = {4, 0.1},
})

reg("ice", {
	description = "Ice",
	tiles = {"bc_ice.png"},
	paramtype = "light",
	use_texture_alpha = "blend",
	drawtype = "glasslike",
	groups = {cracky = 3, choppy = 2, slippery = 3, bc_insul = 2},
	drop = "",
	sounds = S.stone,
})

-- Water. Still water (lakes, ponds, sea) is riskier to drink than running
-- river water; both are safest boiled. Group bc_water: 1 still, 2 running.
local function water(name, desc, tex, kind, color, range, renew)
	local anim = function(file, len)
		return {name = file, backface_culling = false,
			animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = len}}
	end
	local common = {
		description = desc,
		waving = 3,
		use_texture_alpha = "blend",
		paramtype = "light",
		walkable = false,
		pointable = false,
		diggable = false,
		buildable_to = true,
		is_ground_content = false,
		drop = "",
		drowning = 1,
		liquid_alternative_flowing = "bc:" .. name .. "_flowing",
		liquid_alternative_source = "bc:" .. name .. "_source",
		liquid_viscosity = 1,
		liquid_range = range,
		liquid_renewable = renew,
		post_effect_color = color,
		sounds = S.water,
	}
	local src = table.copy(common)
	src.drawtype = "liquid"
	src.tiles = {anim("bc_" .. tex .. "_anim.png", 3.0)}
	src.liquidtype = "source"
	src.groups = {water = 3, liquid = 3, bc_water = kind}
	reg(name .. "_source", src)

	local flow = table.copy(common)
	flow.drawtype = "flowingliquid"
	flow.tiles = {"bc_" .. tex .. ".png"}
	flow.special_tiles = {anim("bc_" .. tex .. "_flow_anim.png", 1.2), anim("bc_" .. tex .. "_flow_anim.png", 1.2)}
	flow.special_tiles[2].backface_culling = true
	flow.paramtype2 = "flowingliquid"
	flow.liquidtype = "flowing"
	flow.groups = {water = 3, liquid = 3, bc_water = kind, not_in_creative_inventory = 1}
	reg(name .. "_flowing", flow)
end
water("water", "Still Water", "water", 1, {a = 110, r = 24, g = 58, b = 84}, 8, true)
water("river_water", "River Water", "river", 2, {a = 90, r = 36, g = 86, b = 100}, 2, false)

-- Loose things lying on the ground: the first materials anyone finds.
reg("loose_rock", {
	description = "Loose Rock",
	tiles = {"bc_stone.png"},
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {
		{-0.22, -0.5, -0.2, 0.2, -0.3, 0.16},
		{-0.12, -0.3, -0.12, 0.12, -0.24, 0.1},
	}},
	selection_box = {type = "fixed", fixed = {-0.3, -0.5, -0.3, 0.3, -0.2, 0.3}},
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	walkable = false,
	floodable = true,
	groups = {dig_immediate = 3, attached_node = 1, not_in_creative_inventory = 1},
	drop = {max_items = 1, items = {
		{items = {"bc:flint"}, rarity = 6},
		{items = {"bc:rock"}},
	}},
	sounds = S.stone,
})

reg("branch", {
	description = "Fallen Branch",
	tiles = {"bc_oak_trunk.png"},
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {
		{-0.45, -0.5, -0.08, 0.42, -0.4, 0.04},
		{-0.1, -0.5, -0.3, 0.0, -0.42, 0.3},
	}},
	selection_box = {type = "fixed", fixed = {-0.45, -0.5, -0.3, 0.45, -0.3, 0.3}},
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	walkable = false,
	floodable = true,
	groups = {dig_immediate = 3, attached_node = 1, flammable = 1, not_in_creative_inventory = 1},
	drop = "bc:stick 2",
	sounds = S.wood,
})

-- Mapgen needs to know which nodes are the world's rock and water.
core.register_alias("mapgen_stone", "bc:stone")
core.register_alias("mapgen_water_source", "bc:water_source")
core.register_alias("mapgen_river_water_source", "bc:river_water_source")

-- The bare hand: slow at soil, fine for plants, useless on wood and rock.
core.override_item("", {
	wield_image = "bc_hand.png",
	wield_scale = {x = 1, y = 1, z = 2.5},
	range = 4,
	tool_capabilities = {
		full_punch_interval = 0.9,
		max_drop_level = 0,
		groupcaps = {
			crumbly = {times = {[1] = 5.0, [2] = 3.0, [3] = 1.4}, uses = 0, maxlevel = 1},
			snappy = {times = {[2] = 2.0, [3] = 0.7}, uses = 0, maxlevel = 1},
			oddly_breakable_by_hand = {times = {[1] = 3.5, [2] = 1.8, [3] = 0.7}, uses = 0, maxlevel = 1},
		},
		damage_groups = {fleshy = 1},
	},
})

-- Work costs energy. Nodes may set _bc_effort = {kcal, rest}; otherwise the
-- cost comes from how hard the material is to work.
local function effort_of(name, placing)
	local def = core.registered_nodes[name]
	if not def then return 1, 0.02 end
	if def._bc_effort then return def._bc_effort[1], def._bc_effort[2] end
	local g = def.groups or {}
	if g.cracky then return 18, 0.6 end
	if g.tree then return placing and 9 or 14, placing and 0.3 or 0.5 end
	if g.choppy then return 6, 0.2 end
	if g.crumbly then return 5, 0.15 end
	return 1, 0.02
end
bc.effort_of = effort_of

core.register_on_dignode(function(_, oldnode, digger)
	if digger and digger:is_player() then
		bc.exert(digger, effort_of(oldnode.name, false))
	end
end)
core.register_on_placenode(function(_, newnode, placer)
	if placer and placer:is_player() then
		bc.exert(placer, effort_of(newnode.name, true))
	end
end)
