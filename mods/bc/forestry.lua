-- Tree schematics have a single vertical stem. Keep standing timber distinct
-- from carried building logs and from the sections that land on the ground.
local forest = {}
local directions = {
	{x = 1, y = 0, z = 0}, {x = -1, y = 0, z = 0},
	{x = 0, y = 0, z = 1}, {x = 0, y = 0, z = -1},
	{x = 0, y = 1, z = 0}, {x = 0, y = -1, z = 0},
}

-- Check face-to-face connections. A neighboring crown can support a branch
-- where they touch; an air gap breaks the connection. Reuse proven paths
-- during one batch of leaf checks in a dense forest.
local supported = {}
local function attached(start)
	if supported[core.hash_node_position(start)] then return true end
	local queue = {start}
	local seen = {[core.hash_node_position(start)] = true}
	local unknown = false
	local i = 1
	while i <= #queue do
		local pos = queue[i]
		i = i + 1
		for _, dir in ipairs(directions) do
			local next_pos = vector.add(pos, dir)
			local key = core.hash_node_position(next_pos)
			if not seen[key] then
				seen[key] = true
				local node = core.get_node_or_nil(next_pos)
				if not node or node.name == "ignore" then
					unknown = true
				elseif core.get_item_group(node.name, "tree") > 0
						or (supported[key] and core.get_item_group(node.name, "leaves") > 0) then
					if not next(supported) then core.after(0, function() supported = {} end) end
					for _, leaf in ipairs(queue) do supported[core.hash_node_position(leaf)] = true end
					return true
				elseif core.get_item_group(node.name, "leaves") > 0 then
					queue[#queue + 1] = next_pos
				end
			end
		end
	end
	return unknown -- A path might continue across an unloaded mapblock.
end

function forest.decay(pos)
	local node = core.get_node(pos)
	if attached(pos) then return end
	core.remove_node(pos)
	local roll = math.random(30)
	if roll <= 5 then
		core.add_item(pos, "bc:stick")
	elseif roll == 6 then
		core.add_item(pos, (node.name:gsub("_leaves$", "_sapling")))
	end
end

local function wake_leaves(base, top)
	supported = {}
	local leaves = core.find_nodes_in_area(vector.offset(base, -4, -3, -4),
		vector.offset(top, 4, 4, 4), {"group:leaves"})
	for _, leaf in ipairs(leaves) do
		core.get_node_timer(leaf):start(math.random(3, 12))
	end
end

function forest.leaf_dug(pos) wake_leaves(pos, pos) end

core.register_abm({
	label = "bc leaf decay",
	nodenames = {"group:leaves"},
	interval = 11, chance = 6, catch_up = false,
	action = forest.decay,
})

-- Before standing trees had a separate node, both buildings and growing
-- trees used the log item. Recognise an old tree by its upright stem ending
-- in its own wild crown. New player placements are explicitly marked.
local function upright_log(pos, name)
	local n = core.get_node(pos)
	return n.name == name and n.param2 < 4 and core.get_meta(pos):get_int("placed") == 0
end

local function legacy_tree(top, leaves)
	for _, dir in ipairs(directions) do
		local n = core.get_node(vector.add(top, dir))
		if n.name == leaves and n.param2 == 0 then return true end
	end
	return false
end

local soft = {air = true, ["bc:snow"] = true, ["bc:grass_tuft"] = true, ["bc:dry_grass_tuft"] = true}
local function ground(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	return def and def.name ~= "ignore" and def.walkable and def.is_ground_content
end

local function open_landing(name)
	return soft[name] or core.get_item_group(name, "bc_water") > 0
end

-- An old severed crown may be several nodes above terrain. Follow the
-- column past vegetation or water until there is solid support for the log.
local function foot_of_fall(start, base, owner)
	local p = start
	while true do
		local below = vector.offset(p, 0, -1, 0)
		local n = core.get_node_or_nil(below)
		if not n or n.name == "ignore" then return end
		local def = core.registered_nodes[n.name]
		if not def then return end
		if def.walkable then
			if core.get_item_group(n.name, "leaves") > 0 or core.get_item_group(n.name, "tree") > 0 then return end
			if (vector.equals(p, base) or open_landing(core.get_node(p).name)) and not core.is_protected(p, owner) then
				return p
			end
			return
		end
		p = below
	end
end

local function landing(base, count, facing, owner)
	-- Set each section on the local surface of a gentle slope. Prefer the
	-- player's heading, then the clearest side. Never replace camp property.
	local best, best_dir = {base}, facing
	for _, turn in ipairs({0, 1, -1, 2}) do
		local dir = (facing + turn) % 4
		local step = core.facedir_to_dir(dir)
		local line = {base}
		for i = 2, count do
			local p = vector.add(line[#line], step)
			local found
			for _, dy in ipairs({0, -1, 1}) do
				local q = vector.offset(p, 0, dy, 0)
				if open_landing(core.get_node(q).name) and ground(vector.offset(q, 0, -1, 0))
						and not core.is_protected(q, owner) then
					found = q
					break
				end
			end
			if not found then break end
			line[#line + 1] = found
		end
		if #line > #best then best, best_dir = line, dir end
		if #best == count then break end
	end
	return best, best_dir
end

local function set_section(pos, node, count)
	core.set_node(pos, node)
	if count > 1 then
		local meta = core.get_meta(pos)
		meta:set_int("sections", count)
		meta:set_string("infotext", core.registered_nodes[node.name].description:match("^[^\n]+")
			.. " · " .. count .. " sections piled here")
	end
end

function forest.register(id, name, logdef)
	local log = "bc:" .. id .. "_trunk"
	local standing = "bc:" .. id .. "_tree"
	local fallen = "bc:" .. id .. "_fallen_trunk"
	local leaves = "bc:" .. id .. "_leaves"

	local function fell(pos, node, digger, undermined)
		if core.get_node(pos).name ~= node.name then return end
		local legacy = node.name == log
		local function stem(p)
			if legacy then return upright_log(p, log) end
			return core.get_node(p).name == standing
		end
		if not stem(pos) then return core.node_dig(pos, node, digger) end
		local base, top = pos, pos
		while stem(vector.offset(base, 0, -1, 0)) do base = vector.offset(base, 0, -1, 0) end
		while stem(vector.offset(top, 0, 1, 0)) do top = vector.offset(top, 0, 1, 0) end
		if core.get_node(vector.offset(top, 0, 1, 0)).name == "ignore"
				or core.get_node(vector.offset(base, 0, -1, 0)).name == "ignore" then return end
		local count = top.y - base.y + 1
		local below = core.registered_nodes[core.get_node(vector.offset(base, 0, -1, 0)).name]
		if legacy and ((count < 4 and below and below.walkable) or not legacy_tree(top, leaves)) then
			if not undermined then return core.node_dig(pos, node, digger) end
			return
		end
		local owner = digger and digger:get_player_name() or ""
		for y = base.y, top.y do
			local p = {x = pos.x, y = y, z = pos.z}
			if core.is_protected(p, owner) then
				if digger then core.record_protection_violation(p, owner) end
				return
			end
		end
		local facing = digger and core.dir_to_facedir(digger:get_look_dir()) or 0
		local foot = foot_of_fall(base, base, owner)
		for turn = 0, 3 do
			if foot then break end
			local neighbor = vector.add(base, core.facedir_to_dir((facing + turn) % 4))
			foot = foot_of_fall(vector.offset(neighbor, 0, 1, 0), base, owner)
		end
		if not foot then
			if digger then bc.toast(digger, "Clear a landing place at the foot of the tree.") end
			return
		end
		local line, rotation = landing(foot, count, facing, owner)
		if not undermined then
			-- The regular dig charges wear and effort once. Standing timber
			-- drops nothing until its grounded sections are chopped.
			if legacy then core.swap_node(pos, {name = standing}) end
			if not core.node_dig(pos, {name = standing, param1 = node.param1, param2 = node.param2}, digger) then
				if legacy then core.swap_node(pos, node) end
				return
			end
		end
		for y = base.y, top.y do
			if undermined or y ~= pos.y then core.remove_node({x = pos.x, y = y, z = pos.z}) end
		end
		local section = {name = fallen, param2 = rotation}
		for i, p in ipairs(line) do
			-- In tight quarters the end breaks into a pile. Every section
			-- still takes one chop and yields one log.
			set_section(p, section, i == #line and count - i + 1 or 1)
		end
		wake_leaves(base, top)
		bc.sound("bc_dig_wood", foot, 1, {pitch = 0.65})
		return true
	end

	local tree = table.copy(logdef)
	tree.description = name .. " Tree"
	tree.groups.not_in_creative_inventory = 1
	tree.drop = ""
	tree.on_dig = fell
	core.register_node(standing, tree)

	logdef.on_dig = fell
	logdef.after_dig_node = forest.leaf_dug
	logdef.after_place_node = function(pos) core.get_meta(pos):set_int("placed", 1) end
	core.register_node(log, logdef)

	local bark, endgrain = "bc_" .. id .. "_trunk.png", "bc_" .. id .. "_trunk_top.png"
	core.register_node(fallen, {
		description = "Fallen " .. name .. " Trunk\nChop into logs with a hatchet.",
		drawtype = "nodebox",
		tiles = {bark, bark, bark .. "^[transformR90", bark .. "^[transformR90", endgrain, endgrain},
		node_box = {type = "fixed", fixed = {
			{-0.27, -0.50, -0.5, 0.27, 0.30, 0.5},
			{-0.39, -0.38, -0.5, 0.39, 0.18, 0.5},
		}},
		paramtype = "light", paramtype2 = "facedir", sunlight_propagates = true,
		is_ground_content = false,
		groups = {choppy = 2, flammable = 2, falling_node = 1, not_in_creative_inventory = 1},
		sounds = bc.snd.wood, drop = log,
		after_dig_node = function(pos, node, oldmeta)
			local remaining = tonumber(oldmeta.fields.sections) or 1
			if remaining > 1 then set_section(pos, node, remaining - 1) end
		end,
	})

	-- Also bring down old severed crowns, or a tree undermined by digging.
	core.register_abm({
		label = "bc unsupported " .. id,
		nodenames = {standing, log}, interval = 12, chance = 1, catch_up = false,
		action = function(pos, node)
			local below = core.registered_nodes[core.get_node(vector.offset(pos, 0, -1, 0)).name]
			if below and below.name ~= "ignore" and not below.walkable then
				if node.name == log and not upright_log(pos, log) then return end
				fell(pos, node, nil, true)
			end
		end,
	})
	return standing
end

return forest
