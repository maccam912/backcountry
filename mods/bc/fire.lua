-- Campfires: lighting, fuel, cooking, and the heat they give a shelter.
local sim = bc.sim

-- input item -> {out, time in game hours}
bc.cooking = {
	["bc:meat_raw"] = {out = "bc:meat_cooked", time = 0.4},
	["bc:fish_raw"] = {out = "bc:fish_cooked", time = 0.3},
	["bc:cattail_root"] = {out = "bc:cattail_root_roasted", time = 0.25, embers = true},
	["bc:pot_water_raw"] = {out = "bc:pot_water_boiled", time = 0.35},
	["bc:pot_unfired"] = {out = "bc:pot", time = 1.5},
	["bc:pot_stew_raw"] = {out = "bc:pot_stew", time = 0.65},
	["bc:pot_chowder_raw"] = {out = "bc:pot_chowder", time = 0.55},
	["bc:berry_dough"] = {out = "bc:berry_griddlecake", time = 0.3, embers = true},
}

bc.register_recipe("stew", "Camp cookery", "bc:pot_stew_raw", {"group:bc_pot_water", "bc:meat_raw", "bc:onion"},
	{unlock = {"bc:pot", "bc:onion"}, note = "Simmer meat and wild onion in a pot of water. One pot feeds two."})
bc.register_recipe("chowder", "Camp cookery", "bc:pot_chowder_raw", {"group:bc_pot_water", "bc:fish_raw", "bc:cattail_root"},
	{unlock = {"bc:pot", "bc:fish_raw"}, note = "Slice a cattail root into a pot of water with a fish. Simmer it for two helpings."})
bc.register_recipe("berry_dough", "Camp cookery", "bc:berry_dough", {"bc:acorn_mash", "group:bc_berry", "group:bc_berry"},
	{unlock = {"bc:acorn_mash"}, note = "Press berries into leached acorn mash. Bake the dough into a travel cake that keeps for days."})

-- Game hours one of an item burns for: its _bc_fuel, stretched or cut short
-- by the bc_fuel_life setting.
local FUEL_LIFE = sim.clamp(tonumber(core.settings:get("bc_fuel_life")) or 1, 0.25, 4)
local function fuel_hours(name)
	local def = core.registered_items[name]
	return (def and def._bc_fuel or 0) * FUEL_LIFE
end
bc.fuel_hours = fuel_hours

local function fuel_total(inv)
	local total = 0
	for _, stack in ipairs(inv:get_list("fuel")) do
		total = total + fuel_hours(stack:get_name()) * stack:get_count()
	end
	return total
end

local function take_fuel(inv)
	for i, stack in ipairs(inv:get_list("fuel")) do
		local hours = fuel_hours(stack:get_name())
		if hours > 0 and not stack:is_empty() then
			local name = stack:get_name()
			stack:take_item()
			inv:set_stack("fuel", i, stack)
			return hours, name
		end
	end
	return 0
end

local function hours_text(h)
	if h < 0.1 then return "a few minutes" end
	if h < 1 then return string.format("about %d minutes", math.floor(h * 60 / 5 + 0.5) * 5) end
	return string.format("about %.1f hours", h)
end

local STATE = {["bc:campfire_unlit"] = "unlit", ["bc:campfire"] = "lit", ["bc:campfire_embers"] = "embers"}

local function cooking_status(meta, inv, i)
	local rec = bc.cooking[inv:get_stack("src", i):get_name()]
	if not rec then return "" end
	local progress = meta:get_float("cook" .. i)
	if progress >= rec.time and not inv:room_for_item("dst", rec.out) then
		return "Tray full"
	end
	return math.min(100, math.floor(progress / rec.time * 100)) .. "%"
end

local function formspec(pos)
	local meta = core.get_meta(pos)
	local state = STATE[core.get_node(pos).name] or "unlit"
	local inv = meta:get_inventory()
	local status
	if state == "lit" then
		local rain = meta:get_float("rain_rate")
		status = "Burning - " .. hours_text((meta:get_float("burn") + fuel_total(inv)) / (1 + rain * 0.7)) .. " of fuel"
		if meta:get_int("rained") == 1 then status = status .. " (rain is eating it)" end
	elseif state == "embers" then
		status = "Embers for " .. hours_text(meta:get_float("ember")) .. " - add fuel to rekindle"
	elseif meta:get_int("used") == 1 then
		status = "Cold ashes - add fuel, then light it"
	else
		status = "Laid and ready - punch it with a bow drill or striker"
	end
	local name = state == "unlit" and "Fire lay" or "Campfire"
	meta:set_string("infotext", name .. " • " .. status)
	return "formspec_version[6]size[10.25,9.4]bgcolor[#222b26;false]"
		.. "label[0.3,0.45;" .. core.formspec_escape(status) .. "]"
		.. "label[0.3,1.1;Fuel]list[context;fuel;0.3,1.4;3,1]"
		.. "label[4.35,1.1;On the fire]list[context;src;4.35,1.4;2,1]"
		.. "label[4.35,2.63;" .. core.formspec_escape(cooking_status(meta, inv, 1)) .. "]"
		.. "label[5.6,2.63;" .. core.formspec_escape(cooking_status(meta, inv, 2)) .. "]"
		.. "label[0.3,3.05;Ready]list[context;dst;0.3,3.35;4,1]"
		.. (state == "embers" and "label[5.45,3.8;Coals still roast roots and cakes.]" or "")
		.. "label[0.3,4.92;Pack]list[current_player;main;0.3,5.2;8,3]"
		.. "listring[context;dst]listring[current_player;main]"
		.. "listring[context;src]listring[current_player;main]"
		.. "listring[context;fuel]listring[current_player;main]"
end

local function refresh(pos)
	core.get_meta(pos):set_string("formspec", formspec(pos))
end

local function set_state(pos, name)
	local node = core.get_node(pos)
	if node.name ~= name then
		node.name = name
		core.swap_node(pos, node)
	end
end

-- Is the sky open above this spot?
local function rained_on(pos)
	local air, _, humidity = bc.climate.air(pos)
	local kind, amount = bc.climate.precip(pos, air, humidity or 50)
	if not kind then return 0 end
	-- Direct skylight also catches a cave ceiling beyond the short roof scan.
	local above = vector.offset(pos, 0, 1, 0)
	if (core.get_natural_light(above, 0.5) or 0) < 15 then return 0 end
	for dy = 1, 12 do
		local name = core.get_node({x = pos.x, y = pos.y + dy, z = pos.z}).name
		local def = core.registered_nodes[name]
		if def and def.walkable then return 0 end
	end
	return amount, kind
end
bc.rained_on = rained_on

local function cook(meta, inv, dt, embers)
	for i = 1, 2 do
		local stack = inv:get_stack("src", i)
		local rec = bc.cooking[stack:get_name()]
		local key = "cook" .. i
		if rec then
			local prev = meta:get_string("ingredient" .. i)
			local progress = (prev == "" or prev == stack:get_name()) and meta:get_float(key) or 0
			-- Roots and flat cakes can bake on the coals at half speed.
			if not embers or rec.embers then progress = progress + dt end
			while progress >= rec.time and not stack:is_empty() do
				if inv:room_for_item("dst", rec.out) then
					inv:add_item("dst", rec.out)
					stack:take_item()
					progress = progress - rec.time
				else
					progress = rec.time
					break
				end
			end
			inv:set_stack("src", i, stack)
			meta:set_string("ingredient" .. i, stack:get_name())
			meta:set_float(key, stack:is_empty() and 0 or progress)
		else
			meta:set_float(key, 0)
			meta:set_string("ingredient" .. i, "")
		end
	end
end

local function on_timer(pos)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	local state = STATE[core.get_node(pos).name]
	local last = meta:get_float("last")
	local dt = sim.clamp(bc.clock - last, 0, 3)
	if meta:get_string("last") == "" then dt = 0 end
	meta:set_float("last", bc.clock)
	local heat = meta:get_float("heat")

	-- how well the space around the fire holds its warmth
	local tick = meta:get_int("tick") + 1
	meta:set_int("tick", tick)
	if tick % 8 == 1 then
		local sh = bc.climate.analyze(pos)
		meta:set_int("encl", sh.enclosed and 1 or 0)
		meta:set_float("insul", sh.insulation)
	end
	local decay = meta:get_int("encl") == 1 and 0.15 * (1.4 - meta:get_float("insul")) or 3

	if state == "lit" then
		local rain = rained_on(pos)
		meta:set_int("rained", rain > 0 and 1 or 0)
		meta:set_float("rain_rate", rain)
		local rate = 1 + rain * 0.7
		local burn = meta:get_float("burn") - dt * rate
		local out = false
		if rain >= 2 and math.random() < 1 - math.exp(-1.2 * dt) then
			out = true          -- a downpour can drown an open fire
		end
		while burn <= 0 and not out do
			local hours, name = take_fuel(inv)
			if hours <= 0 then out = true; break end
			burn = burn + hours
			if core.get_item_group(name, "tree") > 0 and math.random() < 0.5 then
				if inv:room_for_item("dst", "bc:charcoal") then inv:add_item("dst", "bc:charcoal") end
			end
		end
		-- A large sleep tick can cover several batches, or outlast the fuel.
		local burning_time = math.max(0, dt + math.min(0, burn) / rate)
		heat = math.min(1, heat + burning_time * 5)
		cook(meta, inv, burning_time)
		if out then
			meta:set_float("burn", 0)
			local lifetime = rain >= 2 and 0.5 or 3
			local smoulder = math.min(lifetime, dt - burning_time)
			if smoulder > 0 then cook(meta, inv, smoulder * 0.5, true) end
			meta:set_float("ember", lifetime - smoulder)
			set_state(pos, smoulder < lifetime and "bc:campfire_embers" or "bc:campfire_unlit")
		else
			meta:set_float("burn", burn)
			if math.random() < 0.6 then bc.sound("bc_fire", pos, 0.35, {max_hear_distance = 14}) end
			core.add_particlespawner({
				amount = 3, time = 2,
				minpos = {x = pos.x - 0.15, y = pos.y + 0.2, z = pos.z - 0.15},
				maxpos = {x = pos.x + 0.15, y = pos.y + 0.4, z = pos.z + 0.15},
				minvel = {x = -0.1, y = 0.6, z = -0.1}, maxvel = {x = 0.1, y = 1.1, z = 0.1},
				minexptime = 2, maxexptime = 3.5, minsize = 2, maxsize = 5,
				texture = "bc_smoke.png",
			})
		end
	elseif state == "embers" then
		local left = meta:get_float("ember")
		local ember = left - dt
		cook(meta, inv, math.max(0, math.min(dt, left)) * 0.5, true)
		heat = math.max(0.45, heat - decay * dt)
		local hours = take_fuel(inv)
		if hours > 0 then
			meta:set_float("burn", hours)
			set_state(pos, "bc:campfire")
		elseif ember <= 0 then
			set_state(pos, "bc:campfire_unlit")
		end
		meta:set_float("ember", ember)
	else
		heat = math.max(0, heat - decay * dt)
	end

	meta:set_float("heat", heat)
	refresh(pos)
	return state ~= "unlit" or heat > 0.01
end

local function ignite(pos)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	if meta:get_int("used") == 1 then
		local hours = take_fuel(inv)
		if hours <= 0 then return false end
		meta:set_float("burn", hours)
	else
		meta:set_float("burn", 0.6 * FUEL_LIFE)   -- the lay itself
	end
	meta:set_int("used", 1)
	meta:set_float("last", bc.clock)
	set_state(pos, "bc:campfire")
	core.get_node_timer(pos):start(2)
	refresh(pos)
	bc.sound("bc_ignite", pos, 0.7)
	return true
end
bc.ignite_fire = ignite

local FAILS = {
	"The spindle squeals and smokes, but no ember forms.",
	"A wisp of smoke, then nothing. Your arms ache.",
	"The dust glows for a moment and dies.",
	"The tinder smoulders and goes out.",
}

local function try_light(pos, puncher)
	local st = bc.state(puncher)
	if not st then return end
	local stack = puncher:get_wielded_item()
	local def = stack:get_definition()
	local meta = core.get_meta(pos)
	if meta:get_int("used") == 1 and fuel_total(meta:get_inventory()) <= 0 then
		bc.toast(puncher, "There is nothing left here to burn. Add fuel first.")
		return
	end
	if stack:get_name() == "bc:torch" then
		if ignite(pos) then
			bc.toast(puncher, "The fire catches from your torch.")
			bc.objective(puncher, "fire")
		end
		return
	end
	local fs = def and def._bc_fire
	if not fs then
		bc.hint(puncher, "fire_lay")
		return
	end
	local now = core.get_us_time()
	if st.fire_cd and now - st.fire_cd < 1300000 then return end
	st.fire_cd = now

	-- best tinder in the pack
	local best_i, best_q, best_stack
	for i, s in ipairs(puncher:get_inventory():get_list("main")) do
		local q = core.get_item_group(s:get_name(), "bc_tinder")
		if q > 0 and (not best_q or q > best_q) then best_i, best_q, best_stack = i, q, s end
	end
	if not best_i then
		bc.toast(puncher, "You have no tinder. Dry grass, birch bark or beard lichen will take a spark.")
		return
	end
	local tinder = best_stack:get_definition()._bc_tinder
	local sh = bc.climate.analyze(pos)
	local rain = (sh.roof or sh.enclosed) and 0 or rained_on(pos)
	local chance = sim.fire_chance({
		method = fs.method, tinder = tinder, precip = rain,
		wind = bc.weather.wind * (1 - sh.wind_block),
		skill = st.p.fire_skill, core = st.v.core,
	})
	bc.exert(puncher, fs.kcal, fs.rest)
	stack:add_wear(65535 / fs.uses)
	puncher:set_wielded_item(stack)
	st.p.fire_skill = math.min(1, st.p.fire_skill + 0.05)
	bc.sound("bc_dig_wood", pos, 0.3)

	if math.random() < chance then
		best_stack:take_item()
		puncher:get_inventory():set_stack("main", best_i, best_stack)
		ignite(pos)
		bc.toast(puncher, "An ember takes. You breathe it into flame.")
		bc.objective(puncher, "fire")
		if rain > 0 and tinder == "bark" then bc.learn(puncher, "bark_wet") end
		if fs.method == "striker" then bc.learn(puncher, "striker") end
	else
		if math.random() < 0.5 then
			best_stack:take_item()
			puncher:get_inventory():set_stack("main", best_i, best_stack)
		end
		local msg = FAILS[math.random(#FAILS)]
		if rain > 0 then msg = msg .. " Everything is wet." end
		bc.toast(puncher, msg)
		bc.hint(puncher, rain > 0 and "fire_rain" or "fire_fail")
	end
end

local function allow_put(pos, listname, _, stack)
	if listname == "fuel" then
		return fuel_hours(stack:get_name()) > 0 and stack:get_count() or 0
	elseif listname == "src" then
		return bc.cooking[stack:get_name()] and stack:get_count() or 0
	end
	return 0
end

local function inventory_changed(pos)
	local meta = core.get_meta(pos)
	cook(meta, meta:get_inventory(), 0)
	refresh(pos)
end

local function campfire(name, desc, tiles, extra)
	local def = {
		description = desc,
		drawtype = "plantlike",
		tiles = tiles,
		inventory_image = "bc_campfire_unlit.png",
		wield_image = "bc_campfire_unlit.png",
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		is_ground_content = false,
		selection_box = {type = "fixed", fixed = {-0.4, -0.5, -0.4, 0.4, 0.0, 0.4}},
		groups = {oddly_breakable_by_hand = 2, attached_node = 1, bc_fire = 1},
		drop = "",
		sounds = bc.snd.wood,
		on_construct = function(pos)
			local meta = core.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size("fuel", 3)
			inv:set_size("src", 2)
			inv:set_size("dst", 4)
			refresh(pos)
		end,
		allow_metadata_inventory_put = allow_put,
		allow_metadata_inventory_move = function(_, from_list, _, to_list, _, count)
			-- only tidying within one list; anything else must pass allow_put
			return from_list == to_list and count or 0
		end,
		on_metadata_inventory_put = function(pos)
			inventory_changed(pos)
			if not core.get_node_timer(pos):is_started() then core.get_node_timer(pos):start(2) end
		end,
		on_metadata_inventory_take = inventory_changed,
		on_metadata_inventory_move = inventory_changed,
		on_timer = on_timer,
		on_punch = function(pos, node, puncher)
			if not puncher or not puncher:is_player() then return end
			if node.name == "bc:campfire" then
				local stack = puncher:get_wielded_item()
				if stack:get_name() == "bc:torch_unlit" then
					stack:take_item()
					puncher:set_wielded_item(stack)
					bc.give(puncher, "bc:torch")
					bc.sound("bc_ignite", pos, 0.5)
				end
			else
				try_light(pos, puncher)
			end
		end,
		after_dig_node = function(pos, _, oldmeta, digger)
			local fields = oldmeta.fields or {}
			for _, list in pairs(oldmeta.inventory or {}) do
				for _, stack in ipairs(list) do
					if not stack:is_empty() then core.add_item(pos, stack) end
				end
			end
			core.add_item(pos, fields.used == "1" and "bc:charcoal" or "bc:campfire_unlit")
			if digger then bc.exert(digger, 1, 0) end
		end,
		_bc_weight = 1.0,
	}
	for k, v in pairs(extra or {}) do def[k] = v end
	core.register_node("bc:" .. name, def)
end

campfire("campfire_unlit", "Fire Lay\nPlace it, then punch it with a bow drill or striker.", {"bc_campfire_unlit.png"})
campfire("campfire", "Campfire", {{name = "bc_campfire_anim.png",
	animation = {type = "vertical_frames", aspect_w = 32, aspect_h = 32, length = 1.05}}}, {
	light_source = 12,
	damage_per_second = 3,
	groups = {attached_node = 1, bc_fire = 1, not_in_creative_inventory = 1},
	can_dig = function() return false end,
})
campfire("campfire_embers", "Embers", {"bc_campfire_embers.png"}, {
	light_source = 5,
	groups = {oddly_breakable_by_hand = 2, attached_node = 1, bc_fire = 1, not_in_creative_inventory = 1},
})

-- Torches: light to carry, and something wolves respect.
core.register_node("bc:torch", {
	description = "Burning Torch\nPlace it for light. Keeps wolves wary while held.",
	drawtype = "plantlike",
	tiles = {{name = "bc_torch_anim.png", animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 0.8}}},
	inventory_image = "bc_torch.png",
	wield_image = "bc_torch.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	is_ground_content = false,
	light_source = 11,
	selection_box = {type = "fixed", fixed = {-0.15, -0.5, -0.15, 0.15, 0.3, 0.15}},
	groups = {dig_immediate = 3, attached_node = 1},
	sounds = bc.snd.wood,
	on_construct = function(pos) core.get_node_timer(pos):start(bc.real_seconds(6)) end,
	on_timer = function(pos)
		core.remove_node(pos)
		return false
	end,
	_bc_weight = 0.4,
})
