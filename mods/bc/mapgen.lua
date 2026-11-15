-- Biomes, decorations and the starting point.
-- The engine's heat/humidity noise decides the biome; the same heat value
-- drives the climate model, so what you see matches what you feel.

-- game: how good the country is for small game (snares) and what lives there.
bc.biomes = {
	tundra = {label = "Tundra", heat = 6, humidity = 40, top = "bc:dirt_snow", dust = "bc:snow",
		shore = "bc:gravel", ice = true, snares = 0.5},
	snowy_taiga = {label = "Snowbound Forest", heat = 16, humidity = 72, top = "bc:dirt_snow", dust = "bc:snow",
		shore = "bc:gravel", ice = true, snares = 0.8},
	taiga = {label = "Boreal Forest", heat = 30, humidity = 68, top = "bc:dirt_needles",
		shore = "bc:gravel", snares = 1.0},
	forest = {label = "Mixed Woodland", heat = 52, humidity = 66, top = "bc:dirt_grass",
		shore = "bc:sand", snares = 1.2},
	grassland = {label = "Grassland", heat = 55, humidity = 34, top = "bc:dirt_grass",
		shore = "bc:sand", snares = 1.3},
	scrubland = {label = "Dry Scrub", heat = 78, humidity = 38, top = "bc:dirt_dry_grass",
		shore = "bc:sand", snares = 0.7},
	desert = {label = "Desert", heat = 92, humidity = 10, top = "bc:sand", filler = "bc:sand", filler_depth = 4,
		shore = "bc:sand", snares = 0.25},
}

local ALPINE = 96
for id, b in pairs(bc.biomes) do
	local common = {
		node_stone = "bc:stone",
		node_riverbed = "bc:gravel",
		depth_riverbed = 2,
		heat_point = b.heat,
		humidity_point = b.humidity,
		vertical_blend = 2,
	}
	local function biome(suffix, def)
		for k, v in pairs(common) do if def[k] == nil then def[k] = v end end
		def.name = id .. suffix
		core.register_biome(def)
	end
	biome("", {
		node_top = b.top, depth_top = 1,
		node_filler = b.filler or "bc:dirt", depth_filler = b.filler_depth or 3,
		node_dust = b.dust,
		node_water_top = b.ice and "bc:ice" or nil, depth_water_top = b.ice and 1 or nil,
		y_min = 3, y_max = ALPINE,
	})
	biome("_shore", {
		node_top = b.shore, depth_top = 1,
		node_filler = b.shore, depth_filler = 2,
		node_dust = b.dust,
		node_water_top = b.ice and "bc:ice" or nil, depth_water_top = b.ice and 1 or nil,
		y_min = -3, y_max = 2,
	})
	biome("_under", {
		node_top = b.shore, depth_top = 1,
		node_filler = b.shore, depth_filler = 2,
		node_water_top = b.ice and "bc:ice" or nil, depth_water_top = b.ice and 1 or nil,
		y_min = -31000, y_max = -4,
	})
	local cold = b.heat < 60
	biome("_alpine", {
		node_top = cold and "bc:snow_block" or "bc:gravel", depth_top = 1,
		node_filler = "bc:stone", depth_filler = 1,
		node_dust = cold and "bc:snow" or nil,
		y_min = ALPINE + 1, y_max = 31000,
	})
end

-- Biome id for a biome name with any vertical suffix stripped.
function bc.biome_at(pos)
	local data = core.get_biome_data(pos)
	if not data then return "forest", 50, 50 end
	local name = core.get_biome_name(data.biome) or "forest"
	name = name:gsub("_shore$", ""):gsub("_under$", ""):gsub("_alpine$", "")
	return name, data.heat, data.humidity
end

-- ---------------------------------------------------------------------
-- Ores: pockets of gravel, clay and sand
-- ---------------------------------------------------------------------
core.register_ore({
	ore_type = "blob", ore = "bc:gravel", wherein = {"bc:stone"},
	clust_scarcity = 16 * 16 * 16, clust_size = 5, y_min = -31000, y_max = 31000,
	noise_threshold = 0.0,
	noise_params = {offset = 0.5, scale = 0.2, spread = {x = 5, y = 5, z = 5}, seed = 766, octaves = 1, persist = 0.0},
})
core.register_ore({
	ore_type = "blob", ore = "bc:gravel", wherein = {"bc:dirt", "bc:dirt_grass", "bc:dirt_needles", "bc:dirt_dry_grass", "bc:sand"},
	clust_scarcity = 24 * 24 * 24, clust_size = 5, y_min = -10, y_max = 120,
	noise_threshold = 0.0,
	noise_params = {offset = 0.5, scale = 0.2, spread = {x = 5, y = 5, z = 5}, seed = 1234, octaves = 1, persist = 0.0},
})
core.register_ore({
	ore_type = "blob", ore = "bc:clay", wherein = {"bc:dirt", "bc:sand", "bc:gravel"},
	clust_scarcity = 18 * 18 * 18, clust_size = 4, y_min = -12, y_max = 6,
	noise_threshold = 0.0,
	noise_params = {offset = 0.5, scale = 0.2, spread = {x = 5, y = 5, z = 5}, seed = -316, octaves = 1, persist = 0.0},
})

-- ---------------------------------------------------------------------
-- Decorations
-- ---------------------------------------------------------------------
local SOILS = {"bc:dirt_grass", "bc:dirt_needles", "bc:dirt_dry_grass", "bc:dirt_snow"}

local function scatter(node, biomes, fill, opts)
	opts = opts or {}
	local def = {
		deco_type = "simple",
		place_on = opts.place_on or SOILS,
		sidelen = 16,
		biomes = biomes,
		y_min = opts.y_min or 1,
		y_max = opts.y_max or ALPINE,
		decoration = node,
		param2 = opts.param2,
		param2_max = opts.param2_max,
		spawn_by = opts.spawn_by,
		num_spawn_by = opts.spawn_by and 1 or nil,
		flags = opts.flags,
	}
	if opts.noise then
		def.noise_params = {offset = fill, scale = opts.noise, spread = {x = 60, y = 60, z = 60},
			seed = opts.seed or 0, octaves = 3, persist = 0.6}
	else
		def.fill_ratio = fill
	end
	core.register_decoration(def)
end

local function trees(id, biomes, density, noise, seed)
	for i, schem in ipairs(bc.trees[id].schems) do
		core.register_decoration({
			deco_type = "schematic",
			place_on = SOILS,
			sidelen = 16,
			noise_params = {offset = density / #bc.trees[id].schems, scale = noise / #bc.trees[id].schems,
				spread = {x = 120, y = 120, z = 120}, seed = seed + i, octaves = 3, persist = 0.6},
			biomes = biomes,
			y_min = 3, y_max = ALPINE - 10,
			schematic = schem,
			flags = "place_center_x, place_center_z",
			rotation = "random",
		})
	end
end

trees("pine", {"taiga"}, 0.028, 0.02, 11)
trees("pine", {"snowy_taiga"}, 0.022, 0.02, 21)
trees("pine", {"forest"}, 0.004, 0.006, 31)
trees("pine", {"tundra"}, 0.0004, 0.001, 41)
trees("birch", {"taiga", "snowy_taiga"}, 0.004, 0.006, 51)
trees("birch", {"forest"}, 0.008, 0.01, 61)
trees("oak", {"forest"}, 0.016, 0.015, 71)
trees("oak", {"grassland"}, 0.0008, 0.002, 81)
trees("oak", {"scrubland"}, 0.0012, 0.002, 91)
trees("birch", {"grassland"}, 0.0005, 0.001, 101)

scatter("bc:grass_tuft", {"forest"}, 0.12)
scatter("bc:grass_tuft", {"grassland"}, 0.3)
scatter("bc:grass_tuft", {"taiga"}, 0.04)
scatter("bc:dry_grass_tuft", {"grassland"}, 0.05)
scatter("bc:dry_grass_tuft", {"scrubland"}, 0.22)
scatter("bc:dry_grass_tuft", {"tundra"}, 0.02)
scatter("bc:dry_grass_tuft", {"forest", "taiga", "snowy_taiga"}, 0.012)
scatter("bc:dry_grass_tuft", {"desert"}, 0.004, {place_on = {"bc:sand"}})
scatter("bc:dead_bush", {"scrubland"}, 0.012)
scatter("bc:dead_bush", {"desert"}, 0.006, {place_on = {"bc:sand"}})
scatter("bc:dead_bush", {"tundra", "grassland"}, 0.004)

scatter("bc:bush_blue_ripe", {"taiga", "snowy_taiga"}, 0.004, {noise = 0.012, seed = 5})
scatter("bc:bush_blue_ripe", {"tundra"}, 0.002, {noise = 0.006, seed = 6})
scatter("bc:bush_red_ripe", {"forest"}, 0.004, {noise = 0.012, seed = 7})
scatter("bc:bush_red_ripe", {"grassland"}, 0.0015, {noise = 0.006, seed = 8})
scatter("bc:cactus_ripe", {"desert"}, 0.003, {place_on = {"bc:sand"}})
scatter("bc:cactus", {"desert"}, 0.003, {place_on = {"bc:sand"}})
scatter("bc:cactus_ripe", {"scrubland"}, 0.0015)

scatter("bc:nettle", {"forest"}, 0.006, {noise = 0.012, seed = 9})
scatter("bc:yarrow", {"grassland", "forest"}, 0.004, {noise = 0.008, seed = 10})
scatter("bc:yarrow", {"taiga", "scrubland"}, 0.0015)
scatter("bc:onion_plant", {"grassland"}, 0.005, {noise = 0.008, seed = 12})
scatter("bc:onion_plant", {"forest"}, 0.002)

scatter("bc:mushroom_brown", {"taiga", "forest", "snowy_taiga"}, 0.0025)
scatter("bc:mushroom_red", {"taiga", "forest", "snowy_taiga"}, 0.002)
scatter("bc:mushroom_yellow", {"taiga", "forest"}, 0.002)
scatter("bc:mushroom_white", {"forest", "grassland", "taiga"}, 0.0018)

-- cattails crowd the water's edge
scatter("bc:cattail", {"taiga_shore", "forest_shore", "grassland_shore", "scrubland_shore", "taiga", "forest", "grassland"},
	0.3, {place_on = {"bc:dirt", "bc:dirt_grass", "bc:dirt_needles", "bc:sand", "bc:gravel"},
	spawn_by = {"bc:water_source", "bc:river_water_source"}, y_min = 1, y_max = 40})

-- loose material: rocks everywhere, dead wood under trees, driftwood on shores
scatter("bc:loose_rock", nil, 0.008, {
	place_on = {"bc:dirt_grass", "bc:dirt_needles", "bc:dirt_dry_grass", "bc:dirt_snow", "bc:sand", "bc:gravel", "bc:stone"},
	y_min = -1, y_max = 31000, param2 = 0, param2_max = 3})
scatter("bc:loose_rock", nil, 0.06, {place_on = {"bc:gravel"}, y_min = -1, y_max = 31000, param2 = 0, param2_max = 3})
scatter("bc:branch", {"taiga", "forest", "snowy_taiga"}, 0.03, {param2 = 0, param2_max = 3})
scatter("bc:branch", {"grassland", "scrubland", "tundra"}, 0.003, {param2 = 0, param2_max = 3})
scatter("bc:branch", {"desert"}, 0.0015, {place_on = {"bc:sand"}, param2 = 0, param2_max = 3})
scatter("bc:branch", nil, 0.012, {place_on = {"bc:sand", "bc:gravel"}, y_min = 1, y_max = 2, param2 = 0, param2_max = 3})

-- ---------------------------------------------------------------------
-- Where a group starts: the nearest liveable country to the origin, so
-- everyone begins together with a fair chance.
-- ---------------------------------------------------------------------
local GOOD = {forest = 1, taiga = 2, grassland = 3}
bc.GOOD_SPAWN_BIOMES = GOOD

-- Liveable places near the origin, best first. Country with real seasons
-- ranks above the hot or frozen fringes; nearer ranks above farther.
local candidates
function bc.spawn_candidates()
	if candidates then return candidates end
	local list = {}
	for ring = 0, 40 do
		local r = ring * 48
		local steps = math.max(1, ring * 6)
		for i = 1, steps do
			local a = (i / steps) * math.pi * 2
			local x, z = math.floor(math.cos(a) * r), math.floor(math.sin(a) * r)
			local y = core.get_spawn_level(x, z)
			if y and y > 3 and y < 60 then
				local pos = {x = x, y = y, z = z}
				local biome, heat = bc.biome_at(pos)
				local rank = GOOD[biome]
				if rank then
					if heat < 36 or heat > 64 then rank = rank + 3 end
					list[#list + 1] = {pos = pos, score = rank * 12 + ring}
				end
			end
		end
	end
	table.sort(list, function(p, q)
		if p.score ~= q.score then return p.score < q.score end
		if p.pos.x ~= q.pos.x then return p.pos.x < q.pos.x end
		return p.pos.z < q.pos.z
	end)
	candidates = {}
	for i = 1, #list do candidates[i] = list[i].pos end
	return candidates
end

-- The group's starting point. Until water.lua has confirmed a spot with
-- water close by (a moment after a new world starts) this is provisional.
function bc.world_spawn()
	local raw = bc.storage:get_string("spawn")
	if raw ~= "" then
		local pos = core.string_to_pos(raw)
		if pos then return pos, true end
	end
	return bc.spawn_candidates()[1], false
end

function bc.set_world_spawn(pos)
	bc.storage:set_string("spawn", core.pos_to_string(vector.round(pos)))
end
