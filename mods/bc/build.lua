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
	_bc_weight = 1.5, _bc_effort = {3, 0.08}, _bc_fuel = 0.1,
})

core.register_node("bc:wattle", {
	description = "Wattle Panel\nA quick wall of woven sticks. Draughty until daubed.",
	tiles = {"bc_wattle.png"},
	is_ground_content = false,
	groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 2, bc_insul = 1},
	sounds = S.wood,
	_bc_weight = 2, _bc_effort = {3, 0.08}, _bc_fuel = 0.4,
})

core.register_node("bc:daub", {
	description = "Wattle and Daub\nA solid, warm wall.",
	tiles = {"bc_daub.png"},
	is_ground_content = false,
	groups = {crumbly = 1, oddly_breakable_by_hand = 1, bc_insul = 3},
	sounds = S.dirt,
	_bc_weight = 6, _bc_effort = {6, 0.15},
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
local function bed(name, desc, tiles, quality, warmth, weight)
	core.register_node("bc:" .. name, {
		description = desc,
		drawtype = "nodebox",
		tiles = tiles,
		node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -0.22, 0.5}},
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
bed("bed", "Bough Bed\nRight-click to sleep. Keeps you off the cold ground.",
	{"bc_bed.png", "bc_bed.png", "bc_bed_side.png"}, 0.85, 3, 3)
bed("bedroll", "Fur Bedroll\nRight-click to sleep. Warm, and it travels with you.",
	{"bc_bedroll.png", "bc_bedroll.png", "bc_bedroll_side.png"}, 1.0, 8, 4)

-- Storage -----------------------------------------------------------------
local function drop_contents(pos, oldmeta)
	for _, list in pairs(oldmeta.inventory or {}) do
		for _, stack in ipairs(list) do
			if not stack:is_empty() then core.add_item(pos, stack) end
		end
	end
end

core.register_node("bc:basket", {
	description = "Storage Basket\nFood kept here spoils with the weather: cold keeps it.",
	tiles = {"bc_basket_top.png", "bc_basket.png", "bc_basket.png"},
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {-0.4, -0.5, -0.4, 0.4, 0.2, 0.4}},
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
		if hours > 0 and hours < 48 then
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
	allow_metadata_inventory_put = function(_, _, _, stack)
		return bc.drying[stack:get_name()] and 1 or 0
	end,
	allow_metadata_inventory_move = function() return 0 end,
	on_metadata_inventory_put = function(pos, _, index)
		local meta = core.get_meta(pos)
		meta:set_float("p" .. index, 0)
		meta:set_float("last", bc.clock)
		rack_info(pos)
		local timer = core.get_node_timer(pos)
		if not timer:is_started() then timer:start(5) end
	end,
	on_metadata_inventory_take = function(pos, _, index)
		core.get_meta(pos):set_float("p" .. index, 0)
		rack_info(pos)
	end,
	on_timer = function(pos)
		local meta = core.get_meta(pos)
		local inv = meta:get_inventory()
		local hours = bc.sim.clamp(bc.clock - meta:get_float("last"), 0, 6)
		meta:set_float("last", bc.clock)
		local wet = bc.rained_on(pos) > 0
		local smoke = core.find_node_near(pos, 3, {"bc:campfire"}) ~= nil
		local rate = wet and 0 or (smoke and 2.4 or 1)
		local busy = false
		for i = 1, 4 do
			local stack = inv:get_stack("main", i)
			local rec = bc.drying[stack:get_name()]
			if rec then
				busy = true
				local p = meta:get_float("p" .. i) + hours * rate
				if p >= rec.time then
					inv:set_stack("main", i, ItemStack(rec.out))
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
		return busy
	end,
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
		{-0.35, -0.5, -0.35, 0.35, -0.2, 0.35},
		{-0.25, -0.2, -0.25, 0.25, 0.1, 0.25},
		{-0.15, 0.1, -0.15, 0.15, 0.35, 0.15},
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
	tiles = {"bc_remains.png"},
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {-0.35, -0.5, -0.3, 0.35, -0.1, 0.3}},
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
	can_dig = function(pos)
		return core.get_meta(pos):get_inventory():is_empty("main")
	end,
})
