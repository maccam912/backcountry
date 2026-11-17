-- Small places and signs that reward a second look in the woods.
bc.lore.berry_cuttings = {"A berry patch of your own",
	"A picked bush gives one cutting before its next crop. A trimmed bush takes longer to fruit. Plant the tip in sunlit soil and give it a mild day to root."}
bc.lore.nurse_log = {"Under the moss",
	"Worms shelter under mossy logs. Warm rain brings more of them to the surface. Leave a turned log alone for two days and its little colony returns."}
bc.lore.bracket_tinder = {"Shelf tinder",
	"A blade lifts the dry inner layer from the shelves on a mossy log. The soft brown fibres catch a spark about as readily as beard lichen."}

core.register_craftitem("bc:tinder_conk", {
	description = "Bracket Tinder\nSoft fibres from inside a woody fungus. Takes a spark.",
	inventory_image = "bc_tinder_conk.png",
	groups = {bc_tinder = 2},
	_bc_tinder = "lichen",
	_bc_weight = 0.04,
})

local log_box = {
	{-0.48, -0.5, -0.16, 0.46, -0.18, 0.16},
	{-0.43, -0.46, -0.20, 0.39, -0.25, 0.20},
	{-0.31, -0.20, -0.11, 0.34, -0.14, 0.12},
	{0.10, -0.40, 0.10, 0.22, -0.25, 0.29},
}

for _, spent in ipairs({false, true}) do
	local id = spent and "bc:nurse_log_turned" or "bc:nurse_log"
	local boxes = table.copy(log_box)
	if not spent then
		-- The pale ledges on the shadowed face are the pickable brackets.
		boxes[#boxes + 1] = {-0.36, -0.32, -0.29, -0.12, -0.26, -0.13}
		boxes[#boxes + 1] = {-0.15, -0.38, -0.26, 0.06, -0.33, -0.14}
	end
	local moss = spent and "bc_log_bark.png" or "bc_log_moss.png"
	core.register_node(id, {
		description = spent and "Turned Log" or "Mossy Log\nLook underneath, or use a knife on the bracket fungus.",
		drawtype = "nodebox",
		tiles = {moss, "bc_log_bark.png", "bc_oak_trunk_top.png", "bc_oak_trunk_top.png",
			"bc_log_bark.png", spent and "bc_log_bark.png" or "bc_log_brackets.png"},
		node_box = {type = "fixed", fixed = boxes},
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		is_ground_content = false,
		groups = {choppy = 2, attached_node = 1, flammable = 2, not_in_creative_inventory = 1},
		sounds = bc.snd.wood,
		drop = "bc:stick 3",
		on_rightclick = function(pos, node, player, stack)
			if not player or not player:is_player() then return stack end
			if spent then
				bc.toast(player, "Pale wood shows where it was turned. Give it a couple of days.")
				return stack
			end
			if core.is_protected(pos, player:get_player_name()) then
				core.record_protection_violation(pos, player:get_player_name())
				return stack
			end
			if core.get_node(pos).name ~= id then return stack end
			core.swap_node(pos, {name = "bc:nurse_log_turned", param2 = node.param2})
			core.get_meta(pos):set_float("ready", bc.clock + 48)
			core.get_node_timer(pos):start(bc.real_seconds(2))
			if core.get_item_group(stack:get_name(), "bc_knife") > 0 then
				stack:add_wear(bc.CRAFT_WEAR)
				player:set_wielded_item(stack)
				bc.give(player, "bc:tinder_conk 2")
				bc.learn(player, "bracket_tinder")
			else
				local air, _, humidity = bc.climate.air(pos)
				local rainy = bc.climate.precip(pos, air, humidity) == "rain"
				bc.give(player, rainy and "bc:worm 3" or "bc:worm")
				bc.toast(player, rainy and "Three earthworms wriggle through the wet moss." or "An earthworm curls under the log.")
				bc.learn(player, "nurse_log")
			end
			bc.sound("bc_dig_wood", pos, 0.4)
			return player:get_wielded_item()
		end,
		on_timer = spent and function(pos)
			if bc.clock < core.get_meta(pos):get_float("ready") then return true end
			local node = core.get_node(pos)
			core.swap_node(pos, {name = "bc:nurse_log", param2 = node.param2})
			return false
		end or nil,
	})
end

-- Prints belong to animals that actually crossed this patch of ground.
-- They are short-lived objects so snow, plants and players' builds keep
-- their nodes and metadata. A creature can leave at most eight at once.
local tracks = {
	rabbit = {"Rabbit bounds", "The long hind feet land ahead of two small forefeet."},
	deer = {"Deer slots", "Two pointed halves press together in each print."},
	grouse = {"Grouse steps", "Three long toes spread from a light, narrow heel."},
	wolf = {"Wolf pads", "Four toes and a compact pad leave a straight trail."},
	bear = {"Bear prints", "Five toes spread across the edge of a broad, heavy pad."},
}
for animal, sign in pairs(tracks) do
	bc.lore["track_" .. animal] = {sign[1], sign[2] .. " The sharpest edges are the freshest."}
end
bc.lore.all_tracks = {"An eye for tracks",
	"Rabbit, grouse, deer, wolf and bear. You have read the tracks of every animal in this country."}

local ring, occupied, next_slot = {}, {}, 1
local MAX_PRINTS = 160

local function still_visible(self)
	if bc.clock - self.born > self.life then return false end
	local floor = core.get_node_or_nil(self.ground)
	local surface = core.get_node_or_nil(vector.offset(self.ground, 0, 1, 0))
	return floor and floor.name == self.floor and surface and surface.name == self.surface
end

local function inspect(self, player)
	if not player or not player:is_player() then return end
	if not still_visible(self) then self.object:remove() return end
	local age = bc.clock - self.born
	local edge = age < self.life / 3 and "Sharp edges" or "Softening edges"
	bc.toast(player, tracks[self.animal][1] .. ". " .. edge .. ", heading " .. self.direction .. ".")
	if not bc.learn(player, "track_" .. self.animal) then return end
	local notes = bc.state(player).p.notes
	for animal in pairs(tracks) do
		if not notes["track_" .. animal] then return end
	end
	bc.learn(player, "all_tracks")
end

core.register_entity("bc:trail_print", {
	initial_properties = {
		physical = false, collide_with_objects = false, static_save = false,
		visual = "mesh", mesh = "bc_trail_print.obj", textures = {"bc_track_deer.png"},
		selectionbox = {-0.34, 0, -0.42, 0.34, 0.09, 0.42},
		pointable = true,
	},
	on_activate = function(self, data)
		local d = core.deserialize(data)
		if not d or not tracks[d.animal] then self.object:remove() return end
		self.animal, self.direction, self.life, self.ground = d.animal, d.direction, d.life, d.ground
		self.born, self.floor, self.surface = bc.clock, d.floor, d.surface
		self.object:set_yaw(d.yaw)
		self.object:set_properties({textures = {"bc_track_" .. d.animal .. ".png"},
			infotext = "Animal tracks\nInspect the prints"})
		self.object:set_armor_groups({immortal = 1})
		self.key = core.hash_node_position(self.ground)
		occupied[self.key] = self.object
		-- Distance between settlements cannot multiply the server-wide budget.
		-- New trails take the oldest slot, even when every slot is in use.
		local old = ring[next_slot]
		if old and old:get_pos() then old:remove() end
		ring[next_slot] = self.object
		next_slot = next_slot % MAX_PRINTS + 1
	end,
	on_deactivate = function(self)
		if self.key and occupied[self.key] == self.object then occupied[self.key] = nil end
	end,
	on_punch = function(self, player) inspect(self, player) return true end,
	on_rightclick = inspect,
})

-- Age signs together instead of giving each footprint a per-frame callback.
local sweep = 0
core.register_globalstep(function(dt)
	sweep = sweep + dt
	if sweep < 3 then return end
	sweep = 0
	for i, ref in pairs(ring) do
		local sign = ref:get_luaentity()
		if not sign then ring[i] = nil
		elseif not still_visible(sign) then ref:remove() end
	end
end)

function bc.leave_print(self, previous, pos)
	-- Read the movement the physics engine allowed. The velocity an animal
	-- asks for may point straight into a wall, and cannot establish a trail.
	local dx, dz = pos.x - previous.x, pos.z - previous.z
	local moved = dx * dx + dz * dz
	if moved < 0.09 or moved > 20 * 20 then return end
	if self.last_print and bc.hdist(self.last_print, pos) < self.print_spacing then return end
	local ground = vector.round(vector.offset(pos, 0, -0.4, 0))
	local other = occupied[core.hash_node_position(ground)]
	if other and other:get_pos() then return end
	local floor = core.get_node(ground).name
	if core.get_item_group(floor, "soil") == 0 and floor ~= "bc:sand"
			and floor ~= "bc:gravel" and floor ~= "bc:snow_block" then return end
	local surface = core.get_node(vector.offset(ground, 0, 1, 0)).name
	if surface ~= "air" and surface ~= "bc:snow" then return end
	local height = ground.y + (surface == "bc:snow" and 0.77 or 0.52)
	local snow = surface == "bc:snow" or floor == "bc:snow_block" or floor == "bc:dirt_snow"
	local heading = {x = dx, y = 0, z = dz}
	local obj = core.add_entity({x = ground.x, y = height, z = ground.z}, "bc:trail_print",
		core.serialize({animal = self.def.name, direction = bc.compass(heading),
			yaw = core.dir_to_yaw(heading), life = snow and 2.5 or 1.5,
			ground = ground, floor = floor, surface = surface}))
	if not obj then return end
	self.last_print = vector.new(pos)
	self.print_spacing = 4 + math.random() * 2
	self.prints = self.prints or {}
	self.prints[#self.prints + 1] = obj
	if #self.prints > 8 then
		local old = table.remove(self.prints, 1)
		if old:get_pos() then old:remove() end
	end
end
