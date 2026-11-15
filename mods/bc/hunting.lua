-- Thrown and shot weapons, snares, and fishing.
local sim = bc.sim
bc.hunt = {}

local PVP = core.settings:get_bool("enable_pvp", false)

-- ---------------------------------------------------------------------
-- Projectiles: rocks, spears, arrows
-- ---------------------------------------------------------------------
core.register_entity("bc:projectile", {
	initial_properties = {
		physical = false,
		pointable = false,
		visual = "wielditem",
		wield_item = "bc:rock",
		visual_size = {x = 0.4, y = 0.4, z = 0.4},
		collisionbox = {0, 0, 0, 0, 0, 0},
		static_save = false,
	},
	on_step = function(self, dtime)
		local obj = self.object
		local pos = obj:get_pos()
		if not pos then return end
		self.life = (self.life or 0) + dtime
		if not self.item or self.life > 10 then obj:remove() return end
		local from = self.last or pos
		self.last = pos
		if vector.distance(from, pos) < 0.01 then return end
		local owner = self.owner and core.get_player_by_name(self.owner)
		for pt in core.raycast(from, pos, true, false) do
			if pt.type == "object" then
				local ref = pt.ref
				local e = ref:get_luaentity()
				local skip = ref == obj or ref == owner or (e and (e.name == "bc:projectile" or e.name == "bc:bobber"
					or e.name == "__builtin:item")) or (ref:is_player() and not PVP)
				if not skip then
					local vel = obj:get_velocity()
					ref:punch(owner or obj, 1.0,
						{full_punch_interval = 1.0, damage_groups = {fleshy = self.damage}}, vector.normalize(vel))
					bc.sound("bc_hit", pos, 0.6)
					if self.drop and math.random() <= self.drop then core.add_item(pos, self.drop_stack or self.item) end
					obj:remove()
					return
				end
			elseif pt.type == "node" then
				local def = core.registered_nodes[core.get_node(pt.under).name]
				if def and def.walkable then
					local at = pt.intersection_point or pt.above
					bc.sound("bc_hit", at, 0.4)
					if self.drop and math.random() <= self.drop then
						core.add_item(vector.add(at, vector.multiply(pt.intersection_normal or {x = 0, y = 1, z = 0}, 0.2)),
							self.drop_stack or self.item)
					end
					obj:remove()
					return
				end
			end
		end
	end,
})

local function launch(user, item, opts)
	local pos = user:get_pos()
	pos.y = pos.y + (user:get_properties().eye_height or 1.6) - 0.1
	local dir = user:get_look_dir()
	local obj = core.add_entity(vector.add(pos, vector.multiply(dir, 0.5)), "bc:projectile")
	if not obj then return end
	local e = obj:get_luaentity()
	e.owner = user:get_player_name()
	e.item = item
	e.damage = opts.damage
	e.drop = opts.drop
	e.drop_stack = opts.drop_stack
	obj:set_properties({wield_item = item})
	obj:set_velocity(vector.multiply(dir, opts.speed))
	obj:set_acceleration({x = 0, y = -9.81, z = 0})
	obj:set_yaw(user:get_look_horizontal())
	return obj
end

-- Throw the wielded thing (rock, spear).
function bc.hunt.throw(stack, user, opts)
	local st = bc.state(user)
	if not st or st.sleeping then return stack end
	local now = core.get_us_time()
	if st.throw_at and now - st.throw_at < 600000 then return stack end
	st.throw_at = now
	local thrown = stack:take_item(1)
	if opts.wear then
		thrown:add_wear(opts.wear)
		if thrown:is_empty() then
			bc.sound("bc_break", user, 0.6)
			return stack
		end
	end
	launch(user, thrown:get_name(), {damage = opts.damage, speed = opts.speed, drop = opts.drop, drop_stack = thrown})
	bc.sound("bc_woosh", user, 0.5)
	bc.exert(user, 2, 0.03)
	return stack
end

function bc.hunt.shoot(stack, user)
	local st = bc.state(user)
	if not st or st.sleeping then return stack end
	local now = core.get_us_time()
	if st.throw_at and now - st.throw_at < 1100000 then return stack end
	if bc.take_item(user, "bc:arrow", 1) < 1 then
		bc.toast(user, "You have no arrows.")
		return stack
	end
	st.throw_at = now
	launch(user, "bc:arrow", {damage = 9, speed = 40, drop = 0.75})
	bc.sound("bc_bow", user, 0.6)
	bc.exert(user, 2, 0.03)
	stack:add_wear(65535 / 120)
	return stack
end

-- ---------------------------------------------------------------------
-- Snares
-- ---------------------------------------------------------------------
local function snare_timer(pos)
	core.get_node_timer(pos):start(bc.real_seconds(1))
end

core.register_node("bc:snare", {
	description = "Snare\nSet it on open ground and leave. Check it in the morning.",
	drawtype = "plantlike",
	tiles = {"bc_snare.png"},
	inventory_image = "bc_snare.png",
	wield_image = "bc_snare.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	is_ground_content = false,
	selection_box = {type = "fixed", fixed = {-0.3, -0.5, -0.3, 0.3, 0.0, 0.3}},
	groups = {dig_immediate = 3, attached_node = 1},
	sounds = bc.snd.wood,
	on_construct = function(pos)
		core.get_meta(pos):set_float("last", bc.clock)
		snare_timer(pos)
	end,
	on_timer = function(pos)
		local meta = core.get_meta(pos)
		local hours = sim.clamp(bc.clock - meta:get_float("last"), 0, 12)
		meta:set_float("last", bc.clock)
		local below = core.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name
		local biome = bc.biomes[(bc.biome_at(pos))]
		local rate = 0.035 * (biome and biome.snares or 1)
		if core.get_item_group(below, "soil") == 0 and below ~= "bc:sand" then rate = 0 end
		local tod = core.get_timeofday()
		if tod < 0.3 or tod > 0.72 then rate = rate * 1.6 end
		-- nothing comes near while people are about
		for _, player in ipairs(core.get_connected_players()) do
			if vector.distance(player:get_pos(), pos) < 14 then rate = 0 end
		end
		if rate > 0 and math.random() < 1 - math.exp(-rate * hours) then
			core.swap_node(pos, {name = "bc:snare_caught"})
			meta:set_float("caught", bc.clock)
		end
		snare_timer(pos)
		return false
	end,
	_bc_weight = 0.3,
})

do
	local function collect(pos, _, player)
		if not player or not player:is_player() then return end
		bc.give(player, "bc:rabbit_dead")
		bc.objective(player, "trap")
		if math.random() < 0.25 then
			core.remove_node(pos)
			bc.give(player, "bc:stick")
			bc.toast(player, "A rabbit. The snare is chewed through and ruined.")
		else
			core.swap_node(pos, {name = "bc:snare"})
			core.get_meta(pos):set_float("last", bc.clock)
			snare_timer(pos)
			bc.toast(player, "A rabbit. You reset the snare.")
		end
	end
	core.register_node("bc:snare_caught", {
		description = "Snare (rabbit)",
		drawtype = "plantlike",
		tiles = {"bc_snare_caught.png"},
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		is_ground_content = false,
		selection_box = {type = "fixed", fixed = {-0.3, -0.5, -0.3, 0.3, 0.0, 0.3}},
		groups = {attached_node = 1, not_in_creative_inventory = 1},
		drop = "bc:snare",
		on_rightclick = collect,
		on_punch = collect,
		on_timer = function(pos)
			-- left too long, something else eats it
			if bc.clock - core.get_meta(pos):get_float("caught") > 20 then
				core.swap_node(pos, {name = "bc:snare"})
				core.get_meta(pos):set_float("last", bc.clock)
			end
			snare_timer(pos)
			return false
		end,
	})
end

core.register_craftitem("bc:rabbit_dead", {
	description = "Rabbit\nUse it with a knife in your pack to skin and joint it.",
	inventory_image = "bc_rabbit_dead.png",
	stack_max = 4,
	_bc_weight = 1.5,
	_bc_spoil = {rate = 0.6, into = "bc:meat_spoiled"},
	on_use = function(stack, user)
		local i, knife = bc.find_group(user, "bc_knife")
		if not i then
			bc.toast(user, "You need a knife or a sharp stone to skin it.")
			return stack
		end
		knife:add_wear(65535 / 70)
		user:get_inventory():set_stack("main", i, knife)
		stack:take_item()
		bc.give(user, "bc:meat_raw 2")
		bc.give(user, "bc:hide_raw")
		bc.give(user, "bc:bone")
		bc.exert(user, 10, 0.2)
		bc.sound("bc_butcher", user, 0.5)
		return stack
	end,
})

-- ---------------------------------------------------------------------
-- Fishing
-- ---------------------------------------------------------------------
bc.fish_depletion = {}

local function depletion_key(pos)
	return math.floor(pos.x / 24) .. "," .. math.floor(pos.z / 24)
end
local function depletion(pos)
	local d = bc.fish_depletion[depletion_key(pos)]
	if not d then return 0 end
	return d.n * math.exp(-(bc.clock - d.t) / 12)
end
local function deplete(pos)
	bc.fish_depletion[depletion_key(pos)] = {n = depletion(pos) + 1, t = bc.clock}
end

local function bite_chance(pos, bait)
	local node = core.get_node(pos).name
	return sim.fish_bite_chance({
		tod = core.get_timeofday(), weather = bc.weather.state, bait = bait,
		depletion = depletion(pos), river = core.get_item_group(node, "bc_water") == 2,
		season = (bc.season()),
	})
end

core.register_entity("bc:bobber", {
	initial_properties = {
		physical = false,
		pointable = false,
		visual = "sprite",
		textures = {"bc_bobber.png"},
		visual_size = {x = 0.3, y = 0.3},
		collisionbox = {0, 0, 0, 0, 0, 0},
		static_save = false,
	},
	on_step = function(self, dtime)
		local obj = self.object
		local owner = self.owner and core.get_player_by_name(self.owner)
		local st = owner and bc.state(owner)
		if not st or st.fishing ~= self or owner:get_wielded_item():get_name() ~= "bc:fishing_rod"
				or vector.distance(owner:get_pos(), obj:get_pos()) > 14 then
			if st and st.fishing == self then st.fishing = nil end
			obj:remove()
			return
		end
		self.t = (self.t or 0) + dtime
		if self.bite then
			self.bite = self.bite - dtime
			if self.bite <= 0 then
				self.bite = nil
				self.bait = false
				obj:set_pos(self.home)
				bc.toast(owner, "It got away, and took the bait if there was any.")
			end
			return
		end
		if self.t < 3 then return end
		self.t = 0
		if math.random() < bite_chance(self.water, self.bait) then
			self.bite = 2.5
			obj:set_pos({x = self.home.x, y = self.home.y - 0.25, z = self.home.z})
			bc.sound("bc_splash", owner, 0.7)
			bc.toast(owner, "A bite!")
		end
	end,
})

function bc.hunt.fish(stack, user, pt)
	local st = bc.state(user)
	if not st or st.sleeping then return stack end
	local now = core.get_us_time()
	if st.fish_at and now - st.fish_at < 400000 then return stack end
	st.fish_at = now

	local bobber = st.fishing
	if bobber and bobber.object:get_pos() then
		if bobber.bite then
			local count = math.random() < 0.15 and 2 or 1
			bc.give(user, "bc:fish_raw " .. count)
			bc.toast(user, count == 2 and "A fine big fish." or "You land a fish.")
			deplete(bobber.water)
			bc.objective(user, "fish")
			bc.exert(user, 4, 0.05)
			stack:add_wear(65535 / 60)
		else
			bc.toast(user, "You pull the line in. Nothing on it.")
		end
		bobber.object:remove()
		st.fishing = nil
		return stack
	end
	st.fishing = nil

	if not pt or pt.type ~= "node" then return stack end
	local name = core.get_node(pt.under).name
	if name == "bc:ice" then
		bc.toast(user, "The ice is solid. Chop a hole through it first.")
		return stack
	end
	if core.get_item_group(name, "bc_water") == 0 then
		bc.toast(user, "Cast onto water.")
		return stack
	end
	local home = {x = pt.under.x, y = pt.under.y + 0.45, z = pt.under.z}
	local obj = core.add_entity(home, "bc:bobber")
	if not obj then return stack end
	local e = obj:get_luaentity()
	e.owner = user:get_player_name()
	e.home = home
	e.water = vector.new(pt.under)
	local i, bait = bc.find_group(user, "bc_bait")
	if i then
		bait:take_item()
		user:get_inventory():set_stack("main", i, bait)
		e.bait = true
	end
	st.fishing = e
	bc.sound("bc_woosh", user, 0.4)
	bc.toast(user, e.bait and "You bait the hook and cast." or "You cast a bare hook. Bait would help.")
	bc.hint(user, "fishing")
	return stack
end

-- Fish trap: slow, but it works while you sleep.
core.register_node("bc:fish_trap", {
	description = "Fish Trap\nSink it in water. Check it now and then.",
	tiles = {"bc_basket.png"},
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {
		{-0.42, -0.5, -0.3, 0.42, -0.42, 0.3}, {-0.42, 0.0, -0.3, 0.42, 0.08, 0.3},
		{-0.42, -0.5, -0.3, 0.42, 0.08, -0.22}, {-0.42, -0.5, 0.22, 0.42, 0.08, 0.3},
		{0.34, -0.5, -0.3, 0.42, 0.08, 0.3},
	}},
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	liquids_pointable = true,
	groups = {oddly_breakable_by_hand = 2, choppy = 3},
	sounds = bc.snd.wood,
	on_construct = function(pos)
		local meta = core.get_meta(pos)
		meta:get_inventory():set_size("main", 2)
		meta:set_string("formspec", "formspec_version[6]size[10.25,7.4]"
			.. "label[0.25,0.45;Fish trap]list[context;main;0.25,0.8;2,1]"
			.. "list[current_player;main;0.25,3.2;8,3]listring[]")
		meta:set_string("infotext", "Fish trap")
		meta:set_float("last", bc.clock)
		core.get_node_timer(pos):start(bc.real_seconds(1))
	end,
	allow_metadata_inventory_put = function() return 0 end,
	on_timer = function(pos)
		local meta = core.get_meta(pos)
		local inv = meta:get_inventory()
		local hours = sim.clamp(bc.clock - meta:get_float("last"), 0, 12)
		meta:set_float("last", bc.clock)
		local water = core.find_node_near(pos, 1, {"group:bc_water"})
		local text = "Fish trap"
		if not water then
			text = "Fish trap (it needs to sit in water)"
		else
			local rate = (core.get_item_group(core.get_node(water).name, "bc_water") == 2 and 0.1 or 0.07)
				/ (1 + depletion(pos) * 0.6)
			if math.random() < 1 - math.exp(-rate * hours) and inv:room_for_item("main", "bc:fish_raw") then
				inv:add_item("main", "bc:fish_raw")
				deplete(pos)
			end
			-- fish left in the trap too long go off
			bc.spoil_list(inv, "main", (bc.climate.air(pos)) - 6, hours)
			local n = 0
			for _, s in ipairs(inv:get_list("main")) do n = n + s:get_count() end
			if n > 0 then text = "Fish trap (something in it)" end
		end
		meta:set_string("infotext", text)
		core.get_node_timer(pos):start(bc.real_seconds(1))
		return false
	end,
	after_dig_node = function(pos, _, oldmeta)
		for _, list in pairs(oldmeta.inventory or {}) do
			for _, stack in ipairs(list) do
				if not stack:is_empty() then core.add_item(pos, stack) end
			end
		end
	end,
	_bc_weight = 2.5,
})
