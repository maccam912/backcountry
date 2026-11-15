-- Wildlife. Prey notices you by sight, sound and scent (so the wind and
-- how you move matter); predators weigh up whether you are worth the risk.
local sim = bc.sim
bc.animals = {}

local DENSITY = tonumber(core.settings:get("bc_wildlife")) or 1.0
local GRAVITY = {x = 0, y = -9.81, z = 0}

local function yaw_dir(yaw) return {x = -math.sin(yaw), y = 0, z = math.cos(yaw)} end

-- Is the ground a few steps ahead safe to walk onto?
local function ahead_ok(pos, yaw, dist)
	local d = yaw_dir(yaw)
	local p = {x = pos.x + d.x * dist, y = pos.y + 0.5, z = pos.z + d.z * dist}
	local node = core.get_node_or_nil(p)
	if not node then return false end
	if core.get_item_group(node.name, "liquid") > 0 then return false end
	for dy = 0, 4 do
		local below = core.get_node_or_nil({x = p.x, y = p.y - dy, z = p.z})
		if not below then return false end
		local def = core.registered_nodes[below.name]
		if def and def.liquidtype ~= "none" then return false end
		if def and def.walkable then return true end
	end
	return false
end

local function pick_yaw(pos, want, dist)
	for _, off in ipairs({0, 0.6, -0.6, 1.2, -1.2, 2.0, -2.0, 3.1}) do
		if ahead_ok(pos, want + off, dist) then return want + off end
	end
	return want
end

local function nearest_player(pos, range)
	local best, best_d
	for _, player in ipairs(core.get_connected_players()) do
		local st = bc.state(player)
		if st and not st.dying then
			local d = vector.distance(pos, player:get_pos())
			if d <= range and (not best_d or d < best_d) then best, best_d = player, d end
		end
	end
	return best, best_d
end

-- Does this animal notice that player? Returns noticed, by_scent_alone.
local function perceives(def, pos, player, dist)
	local st = bc.state(player)
	local ctrl = player:get_player_control()
	local ppos = player:get_pos()
	local pv = player:get_velocity()
	local moving = (pv.x * pv.x + pv.z * pv.z) > 0.3
	local upwind, downwind = false, false
	if bc.weather.wind >= 1.5 and dist > 0.5 then
		local to = vector.direction({x = ppos.x, y = 0, z = ppos.z}, {x = pos.x, y = 0, z = pos.z})
		local w = vector.normalize(bc.climate.wind_vector())
		local dot = to.x * w.x + to.z * w.z
		upwind, downwind = dot > 0.5, dot < -0.5
	end
	local o = {sneaking = ctrl.sneak, moving = moving, sprinting = st and st.sprinting,
		night = bc.is_night(), scent = def.predator and st and st.scent}
	local plain = sim.detect_multiplier(o)
	o.upwind, o.downwind = upwind, downwind
	local m = sim.detect_multiplier(o)
	if dist > def.sight * m then return false end
	local eye = {x = pos.x, y = pos.y + (def.box[5] or 1) * 0.8, z = pos.z}
	local seen = dist < 3 or bc.clear_line(eye, {x = ppos.x, y = ppos.y + 1.3, z = ppos.z})
	if not seen then
		-- scent still carries round a tree
		if upwind and dist < def.sight * 0.6 then return true, true end
		return false
	end
	return true, upwind and dist > def.sight * plain
end

local function become_carcass(self)
	local obj = self.object
	local def = self.def
	self.dead = true
	self.speed = 0
	obj:set_velocity({x = 0, y = 0, z = 0})
	obj:set_acceleration(GRAVITY)
	local half = (def.box[4] or 0.3)
	obj:set_properties({
		collisionbox = {-0.3, -half, -0.3, 0.3, 0.1, 0.3},
		selectionbox = {-half * 1.6, -half, -half * 1.6, half * 1.6, half * 0.6, half * 1.6},
		makes_footstep_sound = false,
		infotext = def.label .. " carcass\nRight-click with a knife to butcher",
	})
	obj:set_rotation({x = 0, y = self.yaw or 0, z = math.pi / 2})
end

local function die(self, killer)
	local def = self.def
	self.died = bc.clock
	self.parts = {}
	for _, part in ipairs(def.butcher) do
		local item, count, chance = part[1], part[2] or 1, part[3] or 1
		if math.random() <= chance then
			for _ = 1, count do self.parts[#self.parts + 1] = item end
		end
	end
	become_carcass(self)
	if killer and killer:is_player() then
		bc.objective(killer, "hunt")
		bc.hint(killer, "butcher")
	end
end

local function attack(self, def, target, pos)
	local now = core.get_us_time()
	if self.attack_at and now - self.attack_at < def.cooldown * 1000000 then return end
	self.attack_at = now
	local st = bc.state(target)
	if not st then return end
	bc.damage(target, def.damage * (0.8 + math.random() * 0.4), def.cause)
	bc.sound("bc_growl", pos, 0.8)
	local dir = vector.direction(pos, target:get_pos())
	target:add_velocity({x = dir.x * 5, y = 3, z = dir.z * 5})
	if bc.state(target) and not st.dying and math.random() < 0.35 and not st.v.aff.bleeding then
		sim.add_affliction(st.v, "bleeding")
		bc.toast(target, "Teeth tear through to the flesh. You are bleeding.")
		bc.hint(target, "bleeding")
	end
end

local function wander(self, pos)
	self.timer = (self.timer or 0) - 0.45
	if self.timer > 0 then return end
	if self.state == "walk" then
		self.state, self.speed = "idle", 0
		self.timer = 2 + math.random() * 5
	else
		self.state = "walk"
		self.yaw = pick_yaw(pos, math.random() * math.pi * 2, 2)
		self.speed = self.def.walk
		self.timer = 2 + math.random() * 4
	end
end

local function flee_from(self, pos, from, seconds)
	local away = vector.direction(from, pos)
	local want = core.dir_to_yaw({x = away.x, y = 0, z = away.z}) + (math.random() - 0.5) * 0.6
	self.yaw = pick_yaw(pos, want, 2.5)
	self.speed = self.def.run
	if self.state ~= "flee" and self.def.flush then
		self.object:add_velocity({x = 0, y = self.def.flush, z = 0})
	end
	self.state = "flee"
	self.flee_until = core.get_us_time() + (seconds or 6) * 1000000
end

local function brain(self, def, pos)
	local now = core.get_us_time()
	local player, dist = nearest_player(pos, def.sight * 1.8)

	if not player then
		-- nobody anywhere near for a while: stop existing rather than wander forever
		self.far_check = (self.far_check or 0) + 1
		if self.far_check >= 12 then
			self.far_check = 0
			if nearest_player(pos, 110) then
				self.lonely = 0
			else
				self.lonely = (self.lonely or 0) + 1
				if self.lonely > 5 then self.object:remove() return end
			end
		end
		if self.state == "flee" and now < (self.flee_until or 0) then return end
		if self.state == "flee" or self.state == "chase" or self.state == "wary" then self.state = "idle"; self.timer = 0 end
		wander(self, pos)
		return
	end
	self.lonely = 0
	local noticed, by_scent = perceives(def, pos, player, dist)
	local ppos = player:get_pos()

	if not def.predator then
		if noticed then
			if self.state ~= "flee" and by_scent and player:get_player_control().sneak then
				bc.learn(player, "wind_scent")
			end
			flee_from(self, pos, ppos, 5 + math.random() * 3)
		elseif self.state == "flee" then
			if now >= (self.flee_until or 0) then
				self.state, self.speed, self.timer = "idle", 0, 2
			elseif not ahead_ok(pos, self.yaw, 2.5) then
				self.yaw = pick_yaw(pos, self.yaw, 2.5)
			end
		else
			wander(self, pos)
		end
		return
	end

	-- predators
	if self.state == "flee" then
		if now < (self.flee_until or 0) then
			if not ahead_ok(pos, self.yaw, 2.5) then self.yaw = pick_yaw(pos, self.yaw, 2.5) end
			return
		end
		self.state = "idle"
	end
	if not noticed and not self.provoked then
		if self.state == "chase" or self.state == "wary" then self.state, self.timer = "idle", 0 end
		wander(self, pos)
		if def.howl and bc.is_night() and math.random() < 0.006 then
			bc.sound("bc_howl", pos, 1.0, {max_hear_distance = 90})
		end
		return
	end

	local st = bc.state(player)
	local toward = core.dir_to_yaw(vector.direction(pos, {x = ppos.x, y = pos.y, z = ppos.z}))
	local deterred = (st.clim.near_fire or player:get_wielded_item():get_name() == "bc:torch") and not def.fearless
	local bold
	if def.territorial then
		bold = dist < def.territorial or self.provoked
	else
		bold = bc.is_night() or st.v.condition < 50 or st.scent or self.provoked or dist < 5 or st.sleeping
	end

	if self.hp < def.hp * 0.4 then
		flee_from(self, pos, ppos, 10)
	elseif deterred and bold then
		-- wants to, but will not come near the flame
		self.state = "wary"
		if dist < 9 then
			self.yaw = pick_yaw(pos, toward + math.pi, 2)
			self.speed = def.walk * 1.6
		else
			self.yaw, self.speed = toward, 0
		end
		bc.learn(player, "fire_wolves")
	elseif bold then
		self.state = "chase"
		self.yaw = toward
		if dist <= def.reach then
			self.speed = 0
			attack(self, def, player, pos)
		else
			self.speed = def.run
		end
		bc.hint(player, "predator")
	else
		-- watching from a distance
		self.state = "wary"
		self.yaw = toward
		self.speed = 0
		if dist < 8 then
			self.yaw = pick_yaw(pos, toward + math.pi, 2)
			self.speed = def.walk
		end
	end
end

local function on_step(self, dtime, moveresult)
	local obj = self.object
	local pos = obj:get_pos()
	if not pos then return end
	if self.dead then
		self.check = (self.check or 0) + dtime
		if self.check > 5 then
			self.check = 0
			if bc.clock - (self.died or bc.clock) > 24 then obj:remove() end
		end
		return
	end
	local def = self.def

	self.think = (self.think or 0) - dtime
	if self.think <= 0 then
		self.think = 0.35 + math.random() * 0.2
		brain(self, def, pos)
		if not obj:get_pos() then return end
	end

	-- A one-block rise in the ground is hopped; anything taller, and trees
	-- (so nothing scrambles up into the canopy), is turned away from.
	local hop = false
	if (self.speed or 0) > 0 and moveresult and moveresult.collides then
		for _, col in ipairs(moveresult.collisions) do
			if col.type == "node" and col.axis ~= "y" then
				local np = col.node_pos
				local name = core.get_node(np).name
				local above = core.registered_nodes[core.get_node({x = np.x, y = np.y + 1, z = np.z}).name]
				if moveresult.touching_ground and np.y == math.floor(pos.y + 0.5)
						and core.get_item_group(name, "leaves") == 0 and core.get_item_group(name, "tree") == 0
						and above and not above.walkable then
					hop = true
				else
					self.blocked = (self.blocked or 0) + 1
				end
				break
			end
		end
		if (self.blocked or 0) > 3 then
			self.blocked = 0
			self.yaw = self.yaw + (math.random() < 0.5 and 1 or -1) * (1.2 + math.random())
		end
	end

	local vel = obj:get_velocity()
	local node = core.get_node_or_nil({x = pos.x, y = pos.y + 0.2, z = pos.z})
	local swimming = node and core.get_item_group(node.name, "liquid") > 0
	if swimming ~= self.swimming then
		self.swimming = swimming
		obj:set_acceleration(swimming and {x = 0, y = 4, z = 0} or GRAVITY)
	end
	local vy = vel.y
	if swimming then vy = sim.clamp(vy, -1, 1.2) end
	if hop and not swimming then vy = 5.4 end
	local speed, yaw = self.speed or 0, self.yaw or 0
	obj:set_velocity({x = -math.sin(yaw) * speed, y = vy, z = math.cos(yaw) * speed})
	obj:set_yaw(yaw)
end

local function on_punch(self, puncher, _, _, dir, damage)
	if self.dead then return true end
	local def = self.def
	self.hp = self.hp - (damage or 0)
	bc.sound("bc_hurt", self.object:get_pos(), 0.5)
	if self.hp <= 0 then
		die(self, puncher)
		return true
	end
	if dir then self.object:add_velocity({x = dir.x * 3, y = 2, z = dir.z * 3}) end
	local from = puncher and puncher:get_pos()
	if def.predator then
		self.provoked = true
		if self.hp < def.hp * 0.4 and from then flee_from(self, self.object:get_pos(), from, 10) end
	elseif from then
		flee_from(self, self.object:get_pos(), from, 9)
	end
	return true
end

local function on_rightclick(self, clicker)
	if not self.dead or not clicker or not clicker:is_player() then return end
	local st = bc.state(clicker)
	if not st then return end
	local stack = clicker:get_wielded_item()
	if core.get_item_group(stack:get_name(), "bc_knife") == 0 then
		bc.toast(clicker, "You need a knife or a sharp stone in hand to butcher this.")
		return
	end
	local now = core.get_us_time()
	if st.butcher_at and now - st.butcher_at < 450000 then return end
	st.butcher_at = now
	local item = table.remove(self.parts or {}, 1)
	if item then
		bc.give(clicker, item)
		bc.exert(clicker, 5, 0.1)
		stack:add_wear(65535 / 140)
		clicker:set_wielded_item(stack)
		bc.sound("bc_butcher", self.object:get_pos(), 0.5)
	end
	if not self.parts or #self.parts == 0 then
		bc.toast(clicker, "There is nothing more worth taking.")
		self.object:remove()
	end
end

local function register_animal(name, def)
	def.name = name
	bc.animals[name] = def
	core.register_entity("bc:" .. name, {
		initial_properties = {
			physical = true,
			collide_with_objects = false,
			collisionbox = def.box,
			selectionbox = def.box,
			visual = "mesh",
			mesh = "bc_" .. name .. ".obj",
			textures = {"bc_" .. name .. ".png"},
			visual_size = {x = 1, y = 1, z = 1},
			stepheight = 0.55,
			hp_max = 1000,
			damage_texture_modifier = "^[brighten",
		},
		def = def,
		on_activate = function(self, staticdata, dtime_s)
			local data = staticdata ~= "" and core.deserialize(staticdata) or {}
			if (dtime_s or 0) > 900 and not data.dead then
				self.object:remove()
				return
			end
			self.hp = data.hp or def.hp
			self.dead, self.parts, self.died = data.dead, data.parts, data.died
			self.yaw = math.random() * math.pi * 2
			self.state, self.speed, self.timer = "idle", 0, math.random() * 3
			self.object:set_armor_groups({fleshy = 100})
			self.object:set_acceleration(GRAVITY)
			if self.dead then become_carcass(self) end
		end,
		get_staticdata = function(self)
			return core.serialize({hp = self.hp, dead = self.dead, parts = self.parts, died = self.died})
		end,
		on_step = on_step,
		on_punch = on_punch,
		on_rightclick = on_rightclick,
	})
end

register_animal("rabbit", {
	label = "Rabbit", hp = 4, walk = 1.2, run = 6.5, sight = 14,
	box = {-0.2, 0, -0.2, 0.2, 0.4, 0.2},
	butcher = {{"bc:meat_raw", 2}, {"bc:hide_raw", 1}, {"bc:bone", 1}},
	biomes = {forest = 1, grassland = 1.2, taiga = 0.8, snowy_taiga = 0.5, tundra = 0.4, scrubland = 0.6, desert = 0.2},
	group = {1, 2}, max = 4,
})
register_animal("grouse", {
	label = "Grouse", hp = 2, walk = 1.0, run = 5.5, sight = 9, flush = 6,
	box = {-0.15, 0, -0.15, 0.15, 0.35, 0.15},
	butcher = {{"bc:meat_raw", 1}, {"bc:feather", 4}},
	biomes = {taiga = 1, forest = 0.8, snowy_taiga = 0.8, tundra = 0.8, grassland = 0.6, scrubland = 0.4},
	group = {1, 3}, max = 4,
})
register_animal("deer", {
	label = "Deer", hp = 22, walk = 1.3, run = 8.5, sight = 22,
	box = {-0.4, 0, -0.4, 0.4, 1.3, 0.4},
	butcher = {{"bc:meat_raw", 10}, {"bc:hide_raw", 3}, {"bc:fat", 2}, {"bc:sinew", 2}, {"bc:bone", 3}, {"bc:antler", 1, 0.5}},
	biomes = {forest = 1, taiga = 1, grassland = 0.8, snowy_taiga = 0.5, scrubland = 0.3},
	group = {1, 3}, max = 3,
})
register_animal("wolf", {
	label = "Wolf", hp = 18, walk = 1.6, run = 7.2, sight = 20, predator = true, howl = true,
	damage = 10, reach = 1.9, cooldown = 1.4, cause = "wolf",
	box = {-0.33, 0, -0.33, 0.33, 0.85, 0.33},
	butcher = {{"bc:meat_raw", 4}, {"bc:hide_raw", 2}, {"bc:bone", 2}, {"bc:sinew", 1}},
	biomes = {taiga = 0.45, snowy_taiga = 0.7, tundra = 0.6, forest = 0.2},
	group = {1, 3}, max = 3, night = 3,
})
register_animal("bear", {
	label = "Bear", hp = 45, walk = 1.2, run = 7.0, sight = 12, predator = true, territorial = 7,
	damage = 22, reach = 2.3, cooldown = 1.8, cause = "bear",
	box = {-0.55, 0, -0.55, 0.55, 1.25, 0.55},
	butcher = {{"bc:meat_raw", 14}, {"bc:hide_raw", 5}, {"bc:fat", 5}, {"bc:bone", 4}, {"bc:sinew", 2}},
	biomes = {taiga = 0.1, forest = 0.08, snowy_taiga = 0.07},
	group = {1, 1}, max = 1,
})

-- ---------------------------------------------------------------------
-- Spawning: animals appear out of sight, in country that suits them.
-- ---------------------------------------------------------------------
local function count_near(pos, radius)
	local total, by = 0, {}
	for _, obj in ipairs(core.get_objects_inside_radius(pos, radius)) do
		local e = obj:get_luaentity()
		if e and e.def and bc.animals[e.def.name] and not e.dead then
			total = total + 1
			by[e.def.name] = (by[e.def.name] or 0) + 1
		end
	end
	return total, by
end

local function ground_at(x, z, y0)
	for y = y0 + 16, y0 - 24, -1 do
		local node = core.get_node_or_nil({x = x, y = y, z = z})
		if not node then return nil end
		local def = core.registered_nodes[node.name]
		if def and def.liquidtype ~= "none" then return nil end
		if def and def.walkable then
			if core.get_item_group(node.name, "soil") == 0 and node.name ~= "bc:sand"
					and node.name ~= "bc:snow_block" and node.name ~= "bc:gravel" then
				return nil
			end
			local a1 = core.get_node_or_nil({x = x, y = y + 1, z = z})
			local a2 = core.get_node_or_nil({x = x, y = y + 2, z = z})
			local function clear(n)
				local d = n and core.registered_nodes[n.name]
				return d and not d.walkable and d.liquidtype == "none"
			end
			if clear(a1) and clear(a2) then return {x = x, y = y + 0.6, z = z} end
			return nil
		end
	end
end

function bc.spawn_animal(name, pos)
	return core.add_entity(pos, "bc:" .. name)
end

local spawn_timer = 0
core.register_globalstep(function(dtime)
	spawn_timer = spawn_timer + dtime
	if spawn_timer < 9 then return end
	spawn_timer = 0
	if DENSITY <= 0 then return end
	local players = core.get_connected_players()
	for _, player in ipairs(players) do
		local ppos = player:get_pos()
		local total, by = count_near(ppos, 75)
		if total < 7 * DENSITY and math.random() < 0.6 * DENSITY then
			local a = math.random() * math.pi * 2
			local d = 30 + math.random() * 25
			local x, z = math.floor(ppos.x + math.cos(a) * d), math.floor(ppos.z + math.sin(a) * d)
			local spot = ground_at(x, z, math.floor(ppos.y))
			local clear_of_people = spot ~= nil
			if spot then
				for _, other in ipairs(players) do
					if vector.distance(other:get_pos(), spot) < 26 then clear_of_people = false end
				end
			end
			if clear_of_people then
				local biome = bc.biome_at(spot)
				local night = bc.is_night()
				-- new arrivals get two days to find their feet before predators take an interest
				local st = bc.state(player)
				local grace = st and (bc.clock - st.p.born) < 48
				local pool, sum = {}, 0
				for name, def in pairs(bc.animals) do
					local w = def.biomes[biome] or 0
					if def.night then w = w * (night and def.night or 0.4) end
					if (by[name] or 0) >= def.max or (grace and def.predator) then w = 0 end
					if w > 0 then
						pool[#pool + 1] = {name, w}
						sum = sum + w
					end
				end
				table.sort(pool, function(p, q) return p[1] < q[1] end)
				local r = math.random() * math.max(sum, 1.5)
				for _, entry in ipairs(pool) do
					r = r - entry[2]
					if r <= 0 then
						local def = bc.animals[entry[1]]
						for _ = 1, math.random(def.group[1], def.group[2]) do
							bc.spawn_animal(entry[1], {x = spot.x + math.random(-2, 2), y = spot.y + 0.5, z = spot.z + math.random(-2, 2)})
						end
						break
					end
				end
			end
		end
	end
end)
