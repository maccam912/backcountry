-- Small pieces of kit for a camp that has become a home.
local craft = bc.register_recipe

bc.register_bed("grass_pallet", "Grass Sleeping Pallet\nRight-click to sleep. A thin layer of straw against the ground.",
	{"bc_grass_pallet.png", "bc_grass_pallet.png", "bc_grass_pallet_side.png"}, {
		{-0.42, -0.5, -0.48, 0.42, -0.43, 0.48}, {-0.38, -0.43, -0.46, 0.38, -0.39, 0.46},
	}, 0.6, 1, 0.75)
craft("grass_pallet", "Shelter", "bc:grass_pallet",
	{"bc:dry_grass", "bc:dry_grass", "bc:dry_grass", "bc:dry_grass", "bc:stick", "bc:stick"},
	{unlock = {"bc:dry_grass"}, note = "Spread the straw across two sticks. It takes the edge off hard ground. A thick bed of boughs gives better sleep."})

-- The painted face is horizontal. Its arrow points toward local +Z at
-- facedir 0, so a newly placed marker points the way the walker was going.
local marker_signs = {
	{key = "trail", title = "Trail", items = {"bc:stick"}},
	{key = "camp", title = "Camp", items = {"bc:bed", "bc:bedroll", "bc:grass_pallet", "bc:campfire_unlit"}},
	{key = "water", title = "Water", items = {"bc:pot", "bc:pot_water_raw", "bc:pot_water_boiled", "bc:pot_rainwater",
		"bc:waterskin", "bc:waterskin_raw", "bc:waterskin_clean"}},
	{key = "berries", title = "Berry patch", items = {"bc:berries_red", "bc:berries_blue"}},
	{key = "fish", title = "Fishing spot", items = {"bc:fish_raw", "bc:fish_cooked", "bc:fish_dried", "bc:hook"}},
}
local sign_for = {}
for _, sign in ipairs(marker_signs) do
	for _, item in ipairs(sign.items) do sign_for[item] = sign end
end

local function marker_name(sign)
	return sign.key == "trail" and "bc:trail_marker" or ("bc:trail_marker_" .. sign.key)
end

local function marker_info(pos, node, sign)
	local direction = core.facedir_to_dir(node.param2 % 4)
	core.get_meta(pos):set_string("infotext", sign.title .. " to the " .. bc.compass(direction))
end

local function protected(pos, user)
	local name = user:get_player_name()
	if not core.is_protected(pos, name) then return false end
	core.record_protection_violation(pos, name)
	return true
end

for _, sign in ipairs(marker_signs) do
	local groups = {oddly_breakable_by_hand = 3, choppy = 3, attached_node = 1, flammable = 2, bc_open = 1}
	if sign.key ~= "trail" then groups.not_in_creative_inventory = 1 end
	core.register_node(marker_name(sign), {
		description = "Trail Marker\nPoints the way you face when placed. Right-click with charcoal to turn the arrow.",
		drawtype = "nodebox",
		tiles = {"bc_marker_" .. sign.key .. ".png", "bc_oak_trunk_top.png", "bc_oak_trunk.png"},
		node_box = {type = "fixed", fixed = {
			{-0.09, -0.5, -0.09, 0.09, -0.13, 0.09},
			{-0.37, -0.13, -0.40, 0.37, -0.01, 0.40},
		}},
		paramtype = "light", paramtype2 = "facedir", walkable = false,
		sunlight_propagates = true, is_ground_content = false,
		groups = groups, sounds = bc.snd.wood, drop = "bc:trail_marker", _bc_weight = 0.6,
		on_place = function(stack, user, pt)
			return core.item_place(stack, user, pt, user and core.dir_to_facedir(user:get_look_dir()))
		end,
		after_place_node = function(pos)
			marker_info(pos, core.get_node(pos), sign)
		end,
		on_rightclick = function(pos, node, user, stack)
			if protected(pos, user) then return stack end
			local item = stack:get_name()
			local new_sign = sign_for[item]
			if item == "bc:charcoal" then
				node.param2 = core.dir_to_facedir(user:get_look_dir())
			elseif new_sign then
				node.name = marker_name(new_sign)
			else
				bc.toast(user, "Show the marker a water vessel, berry, fish hook or bed to mark a destination. Charcoal turns it.")
				return stack
			end
			core.swap_node(pos, node)
			marker_info(pos, node, new_sign or sign)
			bc.learn(user, "trail_signs")
			return stack
		end,
	})
end

craft("trail_marker", "Shelter", "bc:trail_marker 3", {"bc:bark", "bc:stick", "bc:stick", "bc:charcoal"},
	{unlock = {"bc:bark", "bc:charcoal"},
		note = "Leave a charcoal arrow along a trail. Right-click it with a stick to restore the plain trail sign, or try a keepsake from the place it leads."})

-- Only tools that take an edge can be honed. Fresh tools and unsuitable
-- tools cost nothing. Each handful of grit restores up to a third.
local edges = {["bc:knife_flint"] = true, ["bc:hatchet"] = true}
core.register_node("bc:honing_slab", {
	description = "Honing Slab\nRight-click with a worn flint knife or hatchet. Uses sand or gravel from your pack.",
	tiles = {"bc_honing_slab.png", "bc_stone.png", "bc_stone.png"},
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {
		{-0.42, -0.5, -0.32, 0.42, -0.31, 0.32},
		{-0.46, -0.31, -0.36, 0.46, -0.19, 0.36},
	}},
	paramtype = "light", paramtype2 = "facedir", sunlight_propagates = true,
	is_ground_content = false, groups = {oddly_breakable_by_hand = 2, cracky = 3, bc_open = 1},
	sounds = bc.snd.stone, _bc_weight = 4.8,
	on_construct = function(pos)
		core.get_meta(pos):set_string("infotext", "Honing slab · Bring a worn hatchet or flint knife and a handful of grit.")
	end,
	on_rightclick = function(_, _, user, stack)
		if not edges[stack:get_name()] then
			bc.toast(user, "Flint knives and hatchets take an edge on this stone.")
		elseif stack:get_wear() == 0 then
			bc.toast(user, "That edge is already keen.")
		elseif bc.take_item(user, "bc:sand") == 0 and bc.take_item(user, "bc:gravel") == 0 then
			bc.toast(user, "Bring sand or gravel to use as grit.")
		else
			stack:set_wear(math.max(0, stack:get_wear() - 21845))
			bc.exert(user, 8, 0.2)
			bc.sound("bc_dig_stone", user, 0.4)
			bc.toast(user, "You work a fresh edge onto the stone.")
			bc.learn(user, "honing")
		end
		return stack
	end,
})
craft("honing_slab", "Tools", "bc:honing_slab", {"bc:rock", "bc:rock", "bc:rock", "bc:gravel"},
	{unlock = {"bc:gravel", "bc:hatchet"}, note = "Bed a flat stone in gravel. With fresh grit it will put an edge back on a hatchet or a flint knife."})

core.register_craftitem("bc:feather_stick", {
	description = "Feather Stick\nThe curled shavings catch a spark. Keep it in your pack when lighting a fire.",
	inventory_image = "bc_feather_stick.png", _bc_weight = 0.14,
	groups = {bc_tinder = 2, bc_fuel = 1}, _bc_tinder = "lichen", _bc_fuel = 0.22,
})
craft("feather_stick", "Fire", "bc:feather_stick 3",
	{"bc:stick", "bc:stick", "bc:stick", "bc:stick", "group:bc_knife"},
	{unlock = {"bc:fire_drill", "bc:stick"}, note = "Carve fine curls into dry wood and leave them on the stick. Three will fit in a pocket."})

-- Time lives on this individual roll and advances with the world clock,
-- including skipped nights and time spent in a basket.
local EMBER_HOURS = 6
local function use_roll(stack, user, pt)
	if not bc.state(user) then return stack end
	local lit = stack:get_name() == "bc:ember_roll_lit"
	local left = lit and (stack:get_meta():get_float("until") - bc.clock) or 0
	local pos = pt and pt.type == "node" and pt.under
	local node = pos and core.get_node(pos).name
	if node == "bc:campfire" or node == "bc:campfire_embers" then
		if protected(pos, user) then return stack end
		local roll = ItemStack("bc:ember_roll_lit")
		roll:get_meta():set_float("until", bc.clock + EMBER_HOURS)
		bc.toast(user, "A coal glows under the wrapping. It should travel for six hours.")
		bc.sound("bc_fire", user, 0.4)
		return roll
	end
	if lit and left <= 0 then
		bc.toast(user, "The coal is cold. You can load the roll at another fire.")
		return ItemStack("bc:ember_roll")
	end
	if lit and node == "bc:campfire_unlit" then
		if protected(pos, user) then return stack end
		if not bc.ignite_fire(pos) then
			bc.toast(user, "Put fuel on the cold ashes first.")
			return stack
		end
		bc.learn(user, "carried_fire")
		bc.objective(user, "fire")
		return ItemStack("")
	end
	bc.toast(user, lit and string.format("Still glowing. About %d game minutes left.", math.ceil(left * 60))
		or "Use the roll on a burning fire or glowing embers to load a coal.")
	return stack
end

for _, lit in ipairs({false, true}) do
	core.register_craftitem(lit and "bc:ember_roll_lit" or "bc:ember_roll", {
		description = lit and "Glowing Ember Roll\nUse on a fire lay to light it. Use in air to check the coal."
			or "Ember Roll\nUse on a fire or glowing embers to load a coal for the trail.",
		inventory_image = lit and "bc_ember_roll_lit.png" or "bc_ember_roll.png",
		stack_max = 1, _bc_weight = 0.3, on_use = use_roll,
		groups = lit and {not_in_creative_inventory = 1} or {},
	})
end
craft("ember_roll", "Fire", "bc:ember_roll", {"bc:bark", "bc:dry_grass", "bc:cordage", "bc:charcoal"},
	{unlock = {"bc:bark", "bc:charcoal"}, note = "Lift a coal from a fire into this bark roll. Unwrap it at your next fire lay before it cools."})
