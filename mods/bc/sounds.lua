-- Node sound sets. Files are generated/copied by tools/make_assets.py.
local function set(step, dig, dug, place)
	return {
		footstep = {name = step, gain = 0.25},
		dig = {name = dig, gain = 0.4},
		dug = {name = dug or dig, gain = 0.6},
		place = {name = place or "bc_place", gain = 0.5},
	}
end

bc.snd = {
	dirt = set("bc_step_dirt", "bc_dig_soft"),
	grass = set("bc_step_grass", "bc_dig_soft"),
	sand = set("bc_step_sand", "bc_dig_soft"),
	snow = set("bc_step_snow", "bc_step_snow", "bc_step_snow", "bc_step_snow"),
	stone = set("bc_step_stone", "bc_dig_stone", "bc_dig_stone", "bc_place_stone"),
	wood = set("bc_step_wood", "bc_dig_wood", "bc_dig_wood", "bc_place_wood"),
	leaves = set("bc_step_grass", "bc_dig_leaves", "bc_dig_leaves", "bc_dig_leaves"),
	water = {footstep = {name = "bc_splash", gain = 0.15}},
}
