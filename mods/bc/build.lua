-- Shelter parts and camp furniture.
-- A shelter works by physics, not by recipe: any sealed air space holds
-- warmth, and holds it better the smaller it is and the better its walls
-- insulate (group bc_insul 1..3). See climate.lua.
local S = bc.snd

core.register_node("bc:thatch", {
	description = "Thatch\nLight and very warm. Good for roofs and walls.",
	tiles = {"bc_thatch.png"},
	is_ground_content = false,
	groups = {snappy = 2, oddly_breakable_by_hand = 2, flammable = 3, bc_insul = 3},
	sounds = S.leaves,
	_bc_weight = 1.5, _bc_effort = {3, 0.08}, _bc_fuel = 0.18,
})

-- Each narrow course laps over the next. Rotate the high edge when placing
-- a panel to make a lean-to or meet a second slope along a ridge.
local courses = {}
for i = 0, 7 do
	local z = -0.5 + i / 8
	local h = -0.5 + i * 0.10
	courses[#courses + 1] = {-0.5, h, z, 0.5, h + 0.25, z + 0.125}
end
core.register_node("bc:thatch_roof", {
	description = "Pitched Thatch\nThe roof rises in the direction you face.",
	drawtype = "nodebox",
	tiles = {"bc_thatch.png"},
	node_box = {type = "fixed", fixed = courses},
	paramtype = "light", paramtype2 = "facedir", is_ground_content = false,
	on_place = function(stack, user, pt)
		return core.item_place(stack, user, pt, user and core.dir_to_facedir(user:get_look_dir()))
	end,
	groups = {snappy = 2, oddly_breakable_by_hand = 2, flammable = 3, bc_insul = 3},
	sounds = S.leaves, _bc_weight = 1.6, _bc_effort = {3, 0.08}, _bc_fuel = 0.25,
})
bc.register_recipe("thatch_roof", "Shelter", "bc:thatch_roof 2", {"bc:thatch", "bc:thatch", "bc:stick"},
	{unlock = {"bc:thatch"}, note = "Bind two thatch panels to a pole. Face uphill as you lay each course of roof."})

core.register_node("bc:wattle", {
	description = "Wattle Panel\nA quick wall of woven sticks. Draughty until daubed.",
	tiles = {"bc_wattle.png"},
	is_ground_content = false,
	groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 2, bc_insul = 1},
	sounds = S.wood,
	_bc_weight = 2, _bc_effort = {3, 0.08}, _bc_fuel = 0.7,
})

core.register_node("bc:daub", {
	description = "Wattle and Daub\nA solid, warm wall.",
	tiles = {"bc_daub.png"},
	is_ground_content = false,
	groups = {crumbly = 1, oddly_breakable_by_hand = 1, bc_insul = 3},
	sounds = S.dirt,
	_bc_weight = 6, _bc_effort = {6, 0.15},
})

-- Daub an existing wall without opening up a finished shelter.
core.override_item("bc:clay_lump", {
	on_place = function(stack, player, pt)
		if not player or not pt or pt.type ~= "node" or core.get_node(pt.under).name ~= "bc:wattle" then
			return core.item_place(stack, player, pt)
		end
		local pos, name = pt.under, player:get_player_name()
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return stack
		end
		if bc.take_item(player, "bc:grass") == 0 then
			bc.toast(player, "Mix a bundle of green grass into the clay to bind this wall.")
			return stack
		end
		core.swap_node(pos, {name = "bc:daub"})
		stack:take_item()
		bc.exert(player, 6, 0.15)
		bc.sound("bc_dig_soft", pos, 0.45)
		bc.toast(player, "You press the clay into the gaps. The wall holds the wind now.")
		return stack
	end,
})

core.register_node("bc:drystone", {
	description = "Dry-stone Wall\nStops wind; holds little heat.",
	tiles = {"bc_drystone.png"},
	is_ground_content = false,
	groups = {cracky = 3, oddly_breakable_by_hand = 1, bc_insul = 1},
	drop = "bc:rock 4",
	sounds = S.stone,
	_bc_weight = 5, _bc_effort = {10, 0.3},
})

-- Door panels. Stack two for a doorway; they swing together.
do
	local function toggle(pos, node, clicker)
		local to = node.name == "bc:door" and "bc:door_open" or "bc:door"
		local from = node.name
		for dy = -1, 1 do
			local p = {x = pos.x, y = pos.y + dy, z = pos.z}
			local n = core.get_node(p)
			if n.name == from then
				n.name = to
				core.swap_node(p, n)
			end
		end
		bc.sound("bc_door", pos, 0.5)
		return clicker and clicker:get_wielded_item()
	end
	local base = {
		drawtype = "nodebox",
		tiles = {"bc_wattle.png"},
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		is_ground_content = false,
		sounds = S.wood,
		on_rightclick = toggle,
		_bc_weight = 2.5,
	}
	local closed = table.copy(base)
	closed.description = "Door Panel\nRight-click to open or shut. Stack two for a doorway."
	closed.node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.08, 0.5, 0.5, 0.08}}
	closed.groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 2, bc_insul = 2}
	core.register_node("bc:door", closed)
	local opened = table.copy(base)
	opened.description = "Door Panel (open)"
	opened.node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, -0.34, 0.5, 0.08}}
	opened.groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 2, bc_open = 1, not_in_creative_inventory = 1}
	opened.drop = "bc:door"
	core.register_node("bc:door_open", opened)
end

-- Beds --------------------------------------------------------------------
local function bed(name, desc, tiles, boxes, quality, warmth, weight)
	core.register_node("bc:" .. name, {
		description = desc,
		drawtype = "nodebox",
		tiles = tiles,
		node_box = {type = "fixed", fixed = boxes},
		paramtype2 = "facedir",
		paramtype = "light",
		sunlight_propagates = true,
		is_ground_content = false,
		groups = {oddly_breakable_by_hand = 3, flammable = 3, bc_bed = 1},
		sounds = S.leaves,
		on_rightclick = function(pos, _, clicker, stack)
			bc.sleep.start(clicker, pos, quality, warmth)
			return stack
		end,
		_bc_weight = weight, _bc_effort = {2, 0.05},
	})
end
bc.register_bed = bed
bed("bed", "Bough Bed\nRight-click to sleep. Keeps you off the cold ground.",
	{"bc_bed.png", "bc_bed.png", "bc_bed_side.png"}, {
		{-0.45, -0.5, -0.49, 0.45, -0.32, 0.49}, {-0.4, -0.32, -0.44, 0.4, -0.23, 0.42},
		{-0.36, -0.23, 0.19, 0.36, -0.14, 0.42},
	}, 0.85, 3, 3)
bed("bedroll", "Fur Bedroll\nRight-click to sleep. Warm, and it travels with you.",
	{"bc_bedroll.png", "bc_bedroll.png", "bc_bedroll_side.png"}, {
		{-0.39, -0.5, -0.48, 0.39, -0.35, 0.48}, {-0.41, -0.35, 0.20, 0.41, -0.16, 0.48},
		{-0.36, -0.16, 0.24, 0.36, -0.11, 0.44},
	}, 1.0, 8, 4)

-- Storage -----------------------------------------------------------------
local function drop_contents(pos, oldmeta)
	for _, list in pairs(oldmeta.inventory or {}) do
		for _, stack in ipairs(list) do
			if not ItemStack(stack):is_empty() then core.add_item(pos, stack) end
		end
	end
end

core.register_node("bc:basket", {
	description = "Storage Basket\nFood kept here spoils with the weather: cold keeps it.",
	tiles = {"bc_basket_top.png", "bc_basket.png", "bc_basket.png"},
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {
		{-0.3, -0.5, -0.28, 0.3, -0.36, 0.28}, {-0.36, -0.36, -0.34, 0.36, 0.07, 0.34},
		{-0.39, 0.07, -0.37, 0.39, 0.15, 0.37},
		{-0.34, 0.15, -0.035, -0.28, 0.38, 0.035}, {0.28, 0.15, -0.035, 0.34, 0.38, 0.035},
		{-0.28, 0.32, -0.035, 0.28, 0.39, 0.035},
	}},
	selection_box = {type = "fixed", fixed = {-0.4, -0.5, -0.38, 0.4, 0.39, 0.38}},
	paramtype = "light",
	is_ground_content = false,
	groups = {oddly_breakable_by_hand = 2, flammable = 2},
	sounds = S.leaves,
	on_construct = function(pos)
		local meta = core.get_meta(pos)
		meta:get_inventory():set_size("main", 12)
		meta:set_string("infotext", "Storage basket")
		meta:set_string("formspec", "formspec_version[6]size[10.25,8.2]"
			.. "label[0.25,0.45;Storage basket]list[context;main;0.25,0.8;6,2]"
			.. "list[current_player;main;0.25,4.0;8,3]listring[]")
		meta:set_float("last", bc.clock)
		core.get_node_timer(pos):start(20)
	end,
	on_timer = function(pos)
		local meta = core.get_meta(pos)
		local hours = bc.clock - meta:get_float("last")
		meta:set_float("last", bc.clock)
		if hours > 0 then
			local _, overflow = bc.spoil_list(meta:get_inventory(), "main", (bc.climate.air(pos)), hours)
			for _, stack in ipairs(overflow) do core.add_item(pos, stack) end
		end
		return true
	end,
	after_dig_node = function(pos, _, oldmeta) drop_contents(pos, oldmeta) end,
	_bc_weight = 1,
})

-- Drying rack ---------------------------------------------------------------
-- input -> {out, game hours}. Smoke from a fire close by more than halves it.
bc.drying = {
	["bc:meat_raw"] = {out = "bc:meat_dried", time = 18},
	["bc:fish_raw"] = {out = "bc:fish_dried", time = 14},
	["bc:hide_raw"] = {out = "bc:hide_cured", time = 22},
	["bc:grass"] = {out = "bc:dry_grass", time = 5},
}

-- The inventory is authoritative. These four small, unsaved sprites let
-- someone approaching camp see which lines are occupied and what is ready.
core.register_entity("bc:rack_food", {
	initial_properties = {
		visual = "sprite", textures = {"bc_grass.png"}, visual_size = {x = 0.42, y = 0.42},
		pointable = false, physical = false, static_save = false,
	},
})

local function rack_display(pos, clear)
	local inv = core.get_meta(pos):get_inventory()
	for i = 1, 4 do
		local p = vector.offset(pos, (i % 2 == 1) and -0.24 or 0.24, 0.13, i <= 2 and -0.28 or 0.28)
		local wanted = not clear and inv:get_stack("main", i):get_name() or ""
		local exists = false
		for _, obj in ipairs(core.get_objects_inside_radius(p, 0.1)) do
			local e = obj:get_luaentity()
			if e and e.name == "bc:rack_food" then
				if e.item == wanted and not exists then exists = true else obj:remove() end
			end
		end
		if wanted ~= "" and not exists then
			local def = core.registered_items[wanted]
			local obj = def and core.add_entity(p, "bc:rack_food")
			if obj then
				obj:get_luaentity().item = wanted
				obj:set_properties({textures = {def.inventory_image}})
			end
		end
	end
end

core.register_lbm({
	name = "bc:rack_display", nodenames = {"bc:rack"}, run_at_every_load = true,
	action = function(pos) rack_display(pos) end,
})

local function rack_info(pos, note)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	local parts = {}
	for i = 1, 4 do
		local stack = inv:get_stack("main", i)
		local rec = bc.drying[stack:get_name()]
		if rec then
			parts[#parts + 1] = string.format("%s %d%%", bc.item_label(stack:get_name()),
				math.floor(meta:get_float("p" .. i) / rec.time * 100))
		elseif not stack:is_empty() then
			parts[#parts + 1] = bc.item_label(stack:get_name()) .. " (done)"
		end
	end
	local text = "Drying rack" .. (note and (" - " .. note) or "")
	if #parts > 0 then text = text .. "\n" .. table.concat(parts, "\n") end
	meta:set_string("infotext", text)
end

core.register_node("bc:rack", {
	description = "Drying Rack\nDries meat, fish, hides and grass. Smoke from a nearby fire speeds it; rain stops it.",
	tiles = {"bc_oak_trunk.png"},
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {
		{-0.5, -0.5, -0.45, -0.4, 0.5, -0.35}, {0.4, -0.5, -0.45, 0.5, 0.5, -0.35},
		{-0.5, -0.5, 0.35, -0.4, 0.5, 0.45}, {0.4, -0.5, 0.35, 0.5, 0.5, 0.45},
		{-0.5, 0.38, -0.45, 0.5, 0.46, -0.37}, {-0.5, 0.38, 0.37, 0.5, 0.46, 0.45},
		{-0.3, 0.3, -0.45, -0.24, 0.36, 0.45}, {0.0, 0.3, -0.45, 0.06, 0.36, 0.45}, {0.26, 0.3, -0.45, 0.32, 0.36, 0.45},
	}},
	selection_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}},
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 2, bc_open = 1},
	sounds = S.wood,
	on_construct = function(pos)
		local meta = core.get_meta(pos)
		meta:get_inventory():set_size("main", 4)
		meta:set_string("formspec", "formspec_version[6]size[10.25,7.6]"
			.. "label[0.25,0.45;Drying rack: hang meat, fish, raw hides or green grass]"
			.. "list[context;main;0.25,0.9;4,1]"
			.. "list[current_player;main;0.25,3.4;8,3]listring[]")
		meta:set_float("last", bc.clock)
		rack_info(pos)
	end,
	allow_metadata_inventory_put = function(pos, list, index, stack)
		local empty = core.get_meta(pos):get_inventory():get_stack(list, index):is_empty()
		return empty and bc.drying[stack:get_name()] and 1 or 0
	end,
	allow_metadata_inventory_move = function() return 0 end,
	on_metadata_inventory_put = function(pos, _, index)
		local meta = core.get_meta(pos)
		meta:set_float("p" .. index, 0)
		meta:set_float("since" .. index, bc.clock)
		rack_info(pos)
		rack_display(pos)
		local timer = core.get_node_timer(pos)
		if not timer:is_started() then timer:start(5) end
	end,
	on_metadata_inventory_take = function(pos, _, index)
		core.get_meta(pos):set_float("p" .. index, 0)
		rack_info(pos)
		rack_display(pos)
	end,
	on_timer = function(pos)
		local meta = core.get_meta(pos)
		local inv = meta:get_inventory()
		local last = meta:get_float("last")
		meta:set_float("last", bc.clock)
		local wet = bc.rained_on(pos) > 0
		local smoke = false
		for _, fire in ipairs(core.find_nodes_in_area(vector.subtract(pos, 3), vector.add(pos, 3), {"bc:campfire"})) do
			if vector.distance(fire, pos) <= 3.5 and bc.clear_line(vector.offset(pos, 0, 0.6, 0), fire) then
				smoke = true
				break
			end
		end
		local rate = wet and 0 or (smoke and 2.4 or 1)
		local busy, changed = false, false
		for i = 1, 4 do
			local stack = inv:get_stack("main", i)
			local rec = bc.drying[stack:get_name()]
			if rec then
				busy = true
				local hours = bc.sim.clamp(bc.clock - math.max(last, meta:get_float("since" .. i)), 0, 6)
				local p = meta:get_float("p" .. i) + hours * rate
				if p >= rec.time then
					-- Preserve any stacked input left by an older rack.
					local result = ItemStack(rec.out)
					result:set_count(stack:get_count())
					inv:set_stack("main", i, result)
					changed = true
					p = 0
					if smoke then
						for _, player in ipairs(core.get_connected_players()) do
							if vector.distance(player:get_pos(), pos) < 12 then bc.learn(player, "smoke") end
						end
					end
				end
				meta:set_float("p" .. i, p)
			end
		end
		rack_info(pos, wet and "too wet to dry" or (smoke and "smoking nicely" or nil))
		if changed then rack_display(pos) end
		return busy
	end,
	on_destruct = function(pos) rack_display(pos, true) end,
	after_dig_node = function(pos, _, oldmeta) drop_contents(pos, oldmeta) end,
	_bc_weight = 3,
})

-- Cairn: marks camp -------------------------------------------------------------
local function adopt(pos, player)
	local st = bc.state(player)
	if not st then return end
	st.p.home = {x = pos.x, y = pos.y, z = pos.z}
	bc.toast(player, "This cairn now marks your camp. Your journal shows the way back.")
end

core.register_node("bc:cairn", {
	description = "Cairn\nMarks your camp. Right-click another's cairn to share it.",
	tiles = {"bc_stone.png"},
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {
		{-0.43, -0.5, -0.30, 0.04, -0.29, 0.30}, {0.05, -0.5, -0.32, 0.40, -0.29, 0.24},
		{-0.32, -0.29, -0.24, 0.30, -0.11, 0.24}, {-0.21, -0.11, -0.18, 0.24, 0.09, 0.19},
		{-0.21, 0.09, -0.13, 0.17, 0.22, 0.13}, {-0.08, 0.22, -0.09, 0.09, 0.35, 0.09},
	}},
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {oddly_breakable_by_hand = 2},
	drop = "bc:rock 5",
	sounds = S.stone,
	after_place_node = function(pos, placer)
		if placer and placer:is_player() then
			core.get_meta(pos):set_string("infotext", "Camp cairn raised by " .. placer:get_player_name())
			adopt(pos, placer)
		end
	end,
	on_rightclick = function(pos, _, clicker, stack)
		adopt(pos, clicker)
		return stack
	end,
	_bc_weight = 6, _bc_effort = {8, 0.2},
})

-- What is left where someone died: their pack, for whoever finds it. -------------
core.register_node("bc:remains", {
	description = "Remains",
	tiles = {"bc_pack_top.png", "bc_remains.png", "bc_pack_side.png"},
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {
		{-0.32, -0.5, -0.25, 0.32, -0.13, 0.25}, {-0.25, -0.13, -0.2, 0.25, -0.05, 0.18},
		{-0.20, -0.42, -0.32, 0.19, -0.20, -0.25},
	}},
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {oddly_breakable_by_hand = 2, not_in_creative_inventory = 1},
	drop = "",
	sounds = S.leaves,
	on_construct = function(pos)
		local meta = core.get_meta(pos)
		meta:get_inventory():set_size("main", 40)
		meta:set_string("formspec", "formspec_version[6]size[10.25,10.6]"
			.. "label[0.25,0.45;What they carried]list[context;main;0.25,0.8;8,5]"
			.. "list[current_player;main;0.25,7.3;8,3]listring[]")
	end,
	allow_metadata_inventory_put = function() return 0 end,
	on_metadata_inventory_take = bc.trail.check_pack,
	after_dig_node = function(pos, _, oldmeta)
		local water = oldmeta.fields.water
		if water and core.get_item_group(water, "bc_water") > 0 then
			core.set_node(pos, {name = water, param2 = tonumber(oldmeta.fields.water_level) or 0})
		end
	end,
	can_dig = function(pos)
		return core.get_meta(pos):get_inventory():is_empty("main")
	end,
})
