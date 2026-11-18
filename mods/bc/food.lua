-- Eating, drinking, water containers, mushrooms and spoilage.
local sim = bc.sim

-- _bc_food = {kcal, water, risk = {aff, chance}, cure = {aff = factor},
--             core = delta, note = journal key, verb, returns = item}
function bc.eat(stack, user)
	local st = bc.state(user)
	local def = stack:get_definition()
	local f = def and def._bc_food
	if not st or not f then return stack end
	local v = st.v
	if st.sleeping then return stack end
	if (f.kcal or 0) > 0 and v.kcal >= sim.MAX_KCAL - 30
			and ((f.water or 0) <= 2 or v.water >= 99.5) then
		bc.toast(user, "You cannot eat another bite.")
		return stack
	end
	if (f.kcal or 0) <= 0 and (f.water or 0) > 0 and v.water >= 99.5 then
		bc.toast(user, "You are not thirsty.")
		return stack
	end
	v.kcal = sim.clamp(v.kcal + (f.kcal or 0), 0, sim.MAX_KCAL)
	v.water = sim.clamp(v.water + (f.water or 0), 0, 100)
	if f.core then v.core = v.core + f.core end
	if f.cure then
		for aff, factor in pairs(f.cure) do
			if v.aff[aff] then
				if factor <= 0 then v.aff[aff] = nil else v.aff[aff] = v.aff[aff] * factor end
				if f.note then bc.learn(user, f.note) end
			end
		end
	elseif f.note then
		bc.learn(user, f.note)
	end
	if f.risk and math.random() < f.risk.chance then
		sim.add_affliction(v, f.risk.aff)
		bc.toast(user, f.risk.msg or "Your gut twists. That was a mistake.")
		if f.risk.note then bc.learn(user, f.risk.note) end
	end
	bc.sound((f.water or 0) > 5 and (f.kcal or 0) < 60 and "bc_drink" or "bc_eat", user, 0.6)
	if f.cooked then bc.objective(user, "cook") end
	if f.safe_water then bc.objective(user, "water") end
	stack:take_item()
	if f.returns then
		if stack:is_empty() then return ItemStack(f.returns) end
		bc.give(user, f.returns)
	end
	return stack
end

local function food(name, desc, weight, f, extra)
	local def = {
		description = desc,
		inventory_image = "bc_" .. name .. ".png",
		on_use = bc.eat,
		_bc_food = f,
		_bc_weight = weight,
	}
	for k, v in pairs(extra or {}) do def[k] = v end
	core.register_craftitem("bc:" .. name, def)
end

local RAW = {aff = "food_poisoning", chance = 0.35, note = "raw_meat",
	msg = "Your stomach turns. Raw meat was a gamble."}

food("meat_raw", "Raw Meat", 0.5, {kcal = 220, water = 2, risk = RAW},
	{_bc_spoil = {rate = 0.7, into = "bc:meat_spoiled"}, groups = {bc_raw_meat = 1, bc_bait = 1}})
food("meat_cooked", "Cooked Meat", 0.4, {kcal = 500, water = 0, cooked = true},
	{_bc_spoil = {rate = 0.22, into = "bc:meat_spoiled"}})
food("meat_dried", "Dried Meat", 0.2, {kcal = 420, water = -4, cooked = true})
food("meat_spoiled", "Spoiled Meat", 0.5, {kcal = 90, water = 0,
	risk = {aff = "food_poisoning", chance = 0.9, msg = "It was rotten. You are going to regret that."}},
	{groups = {bc_bait = 1}})
food("fish_raw", "Raw Fish", 0.4, {kcal = 160, water = 3, risk = {aff = "food_poisoning", chance = 0.2, note = "raw_meat",
	msg = "Your stomach turns. Raw fish was a gamble."}},
	{_bc_spoil = {rate = 1.0, into = "bc:meat_spoiled"}, groups = {bc_raw_meat = 1, bc_bait = 1}})
food("fish_cooked", "Cooked Fish", 0.3, {kcal = 350, water = 1, cooked = true},
	{_bc_spoil = {rate = 0.3, into = "bc:meat_spoiled"}})
food("fish_dried", "Dried Fish", 0.15, {kcal = 300, water = -3, cooked = true})
food("fat", "Fat", 0.4, {kcal = 380, water = 0, risk = {aff = "nausea", chance = 0.3, msg = "Raw fat sits heavily."}},
	{_bc_spoil = {rate = 0.2, into = "bc:meat_spoiled"}, groups = {bc_fuel = 1}, _bc_fuel = 0.9})

food("berries_blue", "Blueberries", 0.03, {kcal = 40, water = 2}, {_bc_spoil = {rate = 0.3}, groups = {bc_berry = 1}})
food("berries_red", "Raspberries", 0.03, {kcal = 35, water = 2}, {_bc_spoil = {rate = 0.4}, groups = {bc_berry = 1}})
food("cactus_fruit", "Prickly Pear Fruit", 0.1, {kcal = 45, water = 7}, {_bc_spoil = {rate = 0.2}})
food("onion", "Wild Onion", 0.05, {kcal = 30, water = 1})
food("cattail_root", "Cattail Root", 0.2, {kcal = 60, water = 1})
food("cattail_root_roasted", "Roasted Cattail Root", 0.15, {kcal = 130, water = 0, cooked = true})
food("acorn", "Acorn", 0.02, {kcal = 30, water = -1,
	risk = {aff = "nausea", chance = 0.5, note = "acorn", msg = "Bitter as bark. Your mouth puckers and your stomach complains."}})
food("acorn_mash", "Leached Acorn Mash", 0.3, {kcal = 260, water = 2, note = "acorn_mash"})
food("snowball", "Snow", 0.3, {kcal = 0, water = 5, core = -0.12, note = "snow", verb = "eat"})

core.register_craftitem("bc:berry_dough", {
	description = "Berry and Acorn Dough\nBake on a campfire.",
	inventory_image = "bc_berry_dough.png", _bc_weight = 0.36,
	_bc_spoil = {rate = 0.4},
})
food("berry_griddlecake", "Berry Griddlecake\nKeeps well on the trail.", 0.2,
	{kcal = 335, water = -1, cooked = true}, {_bc_spoil = {rate = 0.035}})

-- ---------------------------------------------------------------------
-- Mushrooms. Which caps are wholesome differs from world to world, so no
-- wiki can tell you: taste carefully (sneak + use) before you trust one.
-- ---------------------------------------------------------------------
local kinds = {"good", "good", "sick", "deadly"}
do
	local seed = tostring(core.get_mapgen_setting("seed") or "0")
	local h = 7
	for i = 1, #seed do h = (h * 31 + seed:byte(i)) % 2147483647 end
	local rng = PcgRandom(h)
	for i = #kinds, 2, -1 do
		local j = rng:next(1, i)
		kinds[i], kinds[j] = kinds[j], kinds[i]
	end
end

local MUSH = {
	good = {
		taste = "Mild and earthy. You wait a while; nothing troubles you.",
		eat = "A decent mouthful.",
		note = "wholesome. Mild and earthy; safe to eat.",
	},
	sick = {
		taste = "Bitter and peppery. Your stomach turns over at even a nibble.",
		eat = "Within minutes your gut is cramping.",
		note = "sickening. Bitter and peppery; it brings on cramps and vomiting.",
	},
	deadly = {
		taste = "Pleasant, almost sweet - but your lips tingle and go numb.",
		eat = "It tasted fine. Then the cold sweat began.",
		note = "DEADLY. Pleasant-tasting, but it numbs the lips. Never eat it.",
	},
}

bc.mushrooms = {}
for i, color in ipairs({"brown", "red", "yellow", "white"}) do
	local kind = kinds[i]
	local label = color:gsub("^%l", string.upper) .. "-capped Mushroom"
	bc.mushrooms[color] = kind
	bc.register_plant("mushroom_" .. color, {
		description = label .. "\nSneak + use to taste a little first.",
		height = -0.1,
		waving = 0,
		groups = {bc_mushroom = 1},
		on_use = function(stack, user)
			local st = bc.state(user)
			if not st then return stack end
			local m, v = MUSH[kind], st.v
			if user:get_player_control().sneak then
				bc.toast(user, "You nibble the edge. " .. m.taste)
				if kind == "sick" then sim.add_affliction(v, "nausea", 1) end
				if kind == "deadly" then
					sim.add_affliction(v, "nausea", 2)
					bc.damage(user, 3, "poison")
				end
			else
				bc.toast(user, m.eat)
				v.kcal = sim.clamp(v.kcal + 25, 0, sim.MAX_KCAL)
				if kind == "sick" then
					sim.add_affliction(v, "food_poisoning", 5)
					sim.add_affliction(v, "nausea", 3)
				elseif kind == "deadly" then
					sim.add_affliction(v, "toxin")
				end
			end
			bc.learn(user, "mushroom_" .. color, "The " .. color .. "-capped mushroom is " .. m.note)
			bc.sound("bc_eat", user, 0.5)
			stack:take_item()
			return stack
		end,
	})
end

-- ---------------------------------------------------------------------
-- Drinking
-- ---------------------------------------------------------------------
local function drink_risk(user, chance)
	if math.random() < chance then
		local st = bc.state(user)
		sim.add_affliction(st.v, "dysentery")
		bc.learn(user, "bad_water")
		core.after(8, function()
			if user:is_player() and bc.state(user) then
				bc.toast(user, "Your guts are cramping. That water was not clean.")
			end
		end)
	end
end

-- Straight from the source, on hands and knees.
function bc.drink_from_node(user, node_name)
	local st = bc.state(user)
	local kind = core.get_item_group(node_name, "bc_water")
	if not st or kind == 0 or st.sleeping then return false end
	local now = core.get_us_time()
	if st.last_drink and now - st.last_drink < 700000 then return true end
	st.last_drink = now
	if st.v.water >= 99.5 then
		bc.toast(user, "You are not thirsty.")
		return true
	end
	st.v.water = sim.clamp(st.v.water + 14, 0, 100)
	bc.sound("bc_drink", user, 0.6)
	drink_risk(user, kind == 2 and 0.04 or 0.10)
	bc.hint(user, "raw_water")
	return true
end

-- Right-click with an empty hand while looking at water to drink.
-- Placement may empty the wield slot before the next control poll.
core.register_on_placenode(function(_, _, placer)
	local st = bc.state(placer)
	if st then st.place_prev = true end
end)

function bc.poll_drink(player, st, place)
	local pressed = place and not st.place_prev
	st.place_prev = place
	if not pressed or not player:get_wielded_item():is_empty() then return end
	local eye = vector.add(player:get_pos(), {x = 0, y = player:get_properties().eye_height or 1.6, z = 0})
	local to = vector.add(eye, vector.multiply(player:get_look_dir(), 3.5))
	for pt in core.raycast(eye, to, false, true) do
		if pt.type == "node" then
			bc.drink_from_node(player, core.get_node(pt.under).name)
			break
		end
	end
end

local poll = 0
core.register_globalstep(function(dtime)
	poll = poll + dtime
	if poll < 0.12 then return end
	poll = 0
	for _, player in ipairs(core.get_connected_players()) do
		local st = bc.state(player)
		if st then bc.poll_drink(player, st, player:get_player_control().place) end
	end
end)

local function pointed_water(pt)
	if not pt or pt.type ~= "node" then return nil end
	local name = core.get_node(pt.under).name
	local kind = core.get_item_group(name, "bc_water")
	if kind > 0 then return kind end
	name = core.get_node(pt.above).name
	kind = core.get_item_group(name, "bc_water")
	return kind > 0 and kind or nil
end

-- Waterskin: carries one good drink.
local function fill_skin(stack, user, pt)
	if pt and pt.type == "node" then
		local node = core.get_node(pt.under)
		local def = core.registered_nodes[node.name]
		if def and def.on_rightclick then
			return core.item_place(stack, user, pt)
		end
	end
	if pointed_water(pt) then
		bc.sound("bc_drink", user, 0.4)
		return ItemStack("bc:waterskin_raw")
	end
	return stack
end
core.register_craftitem("bc:waterskin", {
	description = "Waterskin (empty)\nRight-click water or a placed pot of water to fill.",
	inventory_image = "bc_waterskin.png",
	stack_max = 1,
	liquids_pointable = true,
	on_place = fill_skin,
	on_secondary_use = fill_skin,
	_bc_weight = 0.3,
})
food("waterskin_raw", "Waterskin (untreated water)", 1.3,
	{kcal = 0, water = 34, returns = "bc:waterskin",
		risk = {aff = "dysentery", chance = 0.12, note = "bad_water", msg = "Your guts are cramping. That water was not clean."}},
	{stack_max = 1})
food("waterskin_clean", "Waterskin (clean water)", 1.3,
	{kcal = 0, water = 34, returns = "bc:waterskin", safe_water = true},
	{stack_max = 1})

-- Clay pot: boil water in it at a fire.
local pot_box = {type = "fixed", fixed = {
	{-0.18, -0.5, -0.18, 0.18, -0.42, 0.18},
	{-0.26, -0.42, -0.26, 0.26, -0.35, 0.26},
	{-0.30, -0.35, -0.30, 0.30, -0.10, 0.30},
	{-0.25, -0.10, -0.25, 0.25, -0.02, 0.25},
	{-0.28, -0.02, -0.28, 0.28, 0.045, 0.28},
	{-0.39, -0.15, -0.07, -0.27, -0.08, 0.07},
	{0.27, -0.15, -0.07, 0.39, -0.08, 0.07},
}}
local function pot(name, desc, top, extra)
	local def = {
		description = desc,
		drawtype = "nodebox",
		node_box = pot_box,
		tiles = {top, "bc_pot_side.png", "bc_pot_side.png"},
		paramtype = "light",
		sunlight_propagates = true,
		is_ground_content = false,
		stack_max = 1,
		groups = {oddly_breakable_by_hand = 3, attached_node = 1},
		sounds = bc.snd.stone,
		_bc_weight = 1.5,
	}
	for k, v in pairs(extra or {}) do def[k] = v end
	if def._bc_spoil then
		def.on_construct = function(pos)
			core.get_meta(pos):set_float("food_last", bc.clock)
			core.get_node_timer(pos):start(30)
		end
		def.on_timer = function(pos)
			local meta = core.get_meta(pos)
			local hours = math.max(0, bc.clock - meta:get_float("food_last"))
			meta:set_float("food_last", bc.clock)
			local chance = sim.spoil_chance(def._bc_spoil.rate, bc.climate.local_air(pos), hours)
			if math.random() < chance then
				core.set_node(pos, {name = def._bc_spoil.into})
				core.get_meta(pos):set_string("infotext", "Empty clay pot • The food spoiled")
				return false
			end
			return true
		end
	end
	core.register_node("bc:" .. name, def)
end

pot("pot_unfired", "Unfired Clay Pot\nBake it in a fire before use.", "bc_pot_top.png",
	{tiles = {"bc_pot_unfired.png"}, _bc_weight = 2.4})
local function start_collecting(pos)
	local meta = core.get_meta(pos)
	meta:set_float("rain_last", bc.clock)
	meta:set_string("infotext", "Empty clay pot • Collects rain under open sky")
	core.get_node_timer(pos):start(20)
end

pot("pot", "Clay Pot\nRight-click water to fill, or leave it out in the rain.", "bc_pot_top.png", {
	liquids_pointable = true,
	on_construct = start_collecting,
	on_timer = function(pos)
		local meta = core.get_meta(pos)
		local dt = sim.clamp(bc.clock - meta:get_float("rain_last"), 0, 1)
		meta:set_float("rain_last", bc.clock)
		local amount, kind = bc.rained_on(pos)
		if kind == "rain" then
			local fill = meta:get_float("rain_fill") + dt * amount / 2
			if fill >= 1 then
				core.set_node(pos, {name = "bc:pot_rainwater"})
				return false
			end
			meta:set_float("rain_fill", fill)
			meta:set_string("infotext", ("Rainwater • %d%% full"):format(math.floor(fill * 100)))
		end
		return true
	end,
	on_place = function(stack, user, pt)
		if pt.type == "node" and core.get_item_group(core.get_node(pt.under).name, "bc_water") > 0 then
			bc.sound("bc_drink", user, 0.4)
			return ItemStack("bc:pot_water_raw")
		end
		return core.item_place(stack, user, pt)
	end,
})

-- Pots placed before rain collection existed have no node timer.
core.register_lbm({
	label = "Set out old clay pots to catch rain",
	name = "bc:rainwater_pots",
	nodenames = {"bc:pot"},
	action = function(pos)
		if not core.get_node_timer(pos):is_started() then start_collecting(pos) end
	end,
})

local function filled_pot(f, skin)
	return {
		_bc_food = f,
		groups = {oddly_breakable_by_hand = 3, attached_node = 1, bc_pot_water = skin and 1 or nil},
		on_use = bc.eat,
		on_rightclick = function(pos, node, clicker, held)
			local st = bc.state(clicker)
			if not st or st.sleeping then return held end
			if core.is_protected(pos, clicker:get_player_name()) then return held end
			if skin and held and held:get_name() == "bc:waterskin" then
				core.set_node(pos, {name = "bc:pot"})
				bc.sound("bc_drink", clicker, 0.4)
				if node.name == "bc:pot_rainwater" then bc.learn(clicker, "rainwater") end
				bc.toast(clicker, skin == "bc:waterskin_clean" and "You fill your skin with clean water."
					or "You fill your skin with untreated water.")
				return ItemStack(skin)
			end
			local leftover = bc.eat(ItemStack(node.name), clicker)
			if leftover:get_name() ~= node.name then
				core.set_node(pos, {name = leftover:get_name()})
			end
			return held
		end,
		_bc_weight = 3.0,
	}
end
pot("pot_water_raw", "Pot of Untreated Water\nBoil it at a fire to make it safe.", "bc_pot_water.png",
	filled_pot({kcal = 0, water = 45, returns = "bc:pot",
		risk = {aff = "dysentery", chance = 0.12, note = "bad_water", msg = "Your guts are cramping. That water was not clean."}}, "bc:waterskin_raw"))
pot("pot_water_boiled", "Pot of Boiled Water\nSafe to drink.", "bc_pot_water.png",
	filled_pot({kcal = 0, water = 45, returns = "bc:pot", safe_water = true, note = "boiled"}, "bc:waterskin_clean"))
pot("pot_rainwater", "Fresh Rainwater\nDrink or fill a waterskin.", "bc_pot_rainwater.png",
	filled_pot({kcal = 0, water = 45, returns = "bc:pot", safe_water = true, note = "rainwater"}, "bc:waterskin_clean"))

-- A pot makes two portions. Placed at camp, anyone can serve themselves.
local function meal(id, label, kcal, water)
	local name = "pot_" .. id
	pot(name .. "_raw", label .. " Ingredients\nSimmer on a campfire for two portions.", "bc_" .. name .. "_raw.png", {
		_bc_weight = 3.5, _bc_spoil = {rate = 0.65, into = "bc:pot"},
		inventory_image = "bc_" .. name .. "_raw_icon.png",
	})
	for servings = 1, 2 do
		local next_pot = servings == 1 and "bc:pot" or "bc:" .. name .. "_last"
		local def = filled_pot({kcal = kcal, water = water, cooked = true, returns = next_pot,
			note = "camp_supper"})
		def._bc_weight = servings == 1 and 2.3 or 3.2
		def._bc_spoil = {rate = 0.22, into = "bc:pot"}
		local portion = servings == 1 and "Last portion" or "Two portions"
		local variant = name .. (servings == 1 and "_last" or "")
		def.inventory_image = "bc_" .. variant .. "_icon.png"
		pot(variant, label .. "\n" .. portion .. ". Use to eat or set down to share.", "bc_" .. variant .. ".png", def)
	end
end
meal("stew", "Wild Onion Stew", 305, 17)
meal("chowder", "Cattail Fish Chowder", 280, 16)

-- ---------------------------------------------------------------------
-- Spoilage. Each perishable has a chance to go off as time passes: fast
-- in the heat, slowly in the cool, barely at all when frozen.
-- ---------------------------------------------------------------------
function bc.spoil_list(inv, listname, temp, hours)
	local changed = false
	local spoiled_into = {}
	for i, stack in ipairs(inv:get_list(listname) or {}) do
		if not stack:is_empty() then
			local def = stack:get_definition()
			local sp = def and def._bc_spoil
			if sp then
				local chance = sim.spoil_chance(sp.rate, temp, hours)
				local lost = 0
				for _ = 1, stack:get_count() do
					if math.random() < chance then lost = lost + 1 end
				end
				if lost > 0 then
					stack:take_item(lost)
					inv:set_stack(listname, i, stack)
					if sp.into then spoiled_into[sp.into] = (spoiled_into[sp.into] or 0) + lost end
					changed = true
				end
			end
		end
	end
	local overflow = {}
	for name, count in pairs(spoiled_into) do
		local left = inv:add_item(listname, ItemStack(name .. " " .. count))
		if not left:is_empty() then overflow[#overflow + 1] = left end
	end
	return changed, overflow
end

local spoil_timer, spoil_clock = 0, nil
core.register_globalstep(function(dtime)
	spoil_timer = spoil_timer + dtime
	if spoil_timer < 15 then return end
	spoil_timer = 0
	local hours = spoil_clock and (bc.clock - spoil_clock) or 0
	spoil_clock = bc.clock
	if hours <= 0 then return end
	for _, player in ipairs(core.get_connected_players()) do
		local st = bc.state(player)
		if st then
			local temp = st.clim.air or 15
			local changed, overflow = bc.spoil_list(player:get_inventory(), "main", temp, hours)
			for _, stack in ipairs(overflow) do core.add_item(player:get_pos(), stack) end
			if changed then bc.hint(player, "spoilage") end
			-- carrying fresh food through real cold teaches its own lesson
			if not changed and temp < 1 and hours > 0.05 and math.random() < 0.04 then
				for _, stack in ipairs(player:get_inventory():get_list("main")) do
					local def = stack:get_definition()
					if def and def._bc_spoil and def._bc_spoil.into then
						bc.learn(player, "cold_keeps")
						break
					end
				end
			end
		end
	end
end)
