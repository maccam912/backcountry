-- Raw materials and tools. Everything here is something a person could
-- make from what the land offers: stone, wood, fibre, bone, hide and clay.

local function item(name, desc, weight, extra)
	local def = {
		description = desc,
		inventory_image = "bc_" .. name .. ".png",
		_bc_weight = weight,
	}
	for k, v in pairs(extra or {}) do def[k] = v end
	core.register_craftitem("bc:" .. name, def)
end

-- ---------------------------------------------------------------------
-- Materials
-- ---------------------------------------------------------------------
item("stick", "Stick", 0.3, {groups = {stick = 1, bc_fuel = 1}, _bc_fuel = 0.35})
item("rock", "Rock\nLeft-click to throw.", 1.2, {
	on_use = function(stack, user) return bc.hunt.throw(stack, user, {damage = 2, speed = 20, drop = 1}) end,
})
item("flint", "Flint", 0.3)
item("pyrite", "Pyrite Nodule", 0.3)
item("grass", "Green Grass", 0.05, {groups = {bc_thatch = 1}})
item("dry_grass", "Dry Grass", 0.03, {groups = {bc_thatch = 1, bc_tinder = 1, bc_fuel = 1}, _bc_tinder = "grass", _bc_fuel = 0.07})
item("cordage", "Cordage", 0.05)
item("bark", "Birch Bark", 0.1, {groups = {bc_tinder = 3, bc_fuel = 1}, _bc_tinder = "bark", _bc_fuel = 0.14})
item("lichen", "Beard Lichen", 0.02, {groups = {bc_tinder = 2}, _bc_tinder = "lichen"})
item("clay_lump", "Clay", 0.8)
item("charcoal", "Charcoal", 0.1, {groups = {bc_fuel = 1}, _bc_fuel = 1.75,
	on_use = function(stack, user) return bc.eat(stack, user) end,
	_bc_food = {kcal = 0, water = -1, verb = "choke down", cure = {food_poisoning = 0.4, nausea = 0}, note = "charcoal"},
})
item("bone", "Bone", 0.3)
item("sinew", "Sinew", 0.05)
item("hide_raw", "Raw Hide", 2.0, {_bc_spoil = {rate = 0.35}})
item("hide_cured", "Cured Hide", 1.2)
item("feather", "Feather", 0.01)
item("antler", "Antler", 1.0)
item("hook", "Fish Hook", 0.01)
item("worm", "Earthworm", 0.01, {groups = {bc_bait = 1},
	on_use = function(stack, user) return bc.eat(stack, user) end,
	_bc_food = {kcal = 12, water = 0, verb = "swallow"},
})
item("arrow", "Arrow", 0.05)
item("torch_unlit", "Unlit Torch\nPunch a burning fire to light it.", 0.4)

-- ---------------------------------------------------------------------
-- Tools
-- ---------------------------------------------------------------------
local function tool(name, desc, weight, caps, extra)
	local def = {
		description = desc,
		inventory_image = "bc_" .. name .. ".png",
		tool_capabilities = caps,
		_bc_weight = weight,
		sound = {breaks = "bc_break"},
	}
	for k, v in pairs(extra or {}) do def[k] = v end
	core.register_tool("bc:" .. name, def)
end

tool("sharp_stone", "Sharp Stone\nA crude edge: cuts plants, cordage and carcasses.", 0.5, {
	full_punch_interval = 1.0, max_drop_level = 0,
	groupcaps = {snappy = {times = {[2] = 1.2, [3] = 0.4}, uses = 25, maxlevel = 0}},
	damage_groups = {fleshy = 2},
}, {groups = {bc_knife = 1, bc_keep = 1}})

tool("knife_flint", "Flint Knife", 0.3, {
	full_punch_interval = 0.8, max_drop_level = 0,
	groupcaps = {snappy = {times = {[2] = 0.8, [3] = 0.3}, uses = 70, maxlevel = 0}},
	damage_groups = {fleshy = 3},
}, {groups = {bc_knife = 2, bc_keep = 1}})

tool("hatchet", "Stone Hatchet\nChop a standing tree, then cut the fallen trunk into logs.", 1.2, {
	full_punch_interval = 1.2, max_drop_level = 0,
	groupcaps = {choppy = {times = {[1] = 4.2, [2] = 2.4, [3] = 1.4}, uses = 30, maxlevel = 0}},
	damage_groups = {fleshy = 4},
})

tool("digging_stick", "Digging Stick\nRight-click the top of bare soil to till a garden bed.", 0.6, {
	full_punch_interval = 1.0, max_drop_level = 0,
	groupcaps = {crumbly = {times = {[1] = 2.6, [2] = 1.4, [3] = 0.7}, uses = 50, maxlevel = 0}},
	damage_groups = {fleshy = 2},
}, {on_place = function(stack, user, pt) return bc.till_soil(stack, user, pt) end})

tool("pick_antler", "Antler Pick\nPries rock apart.", 1.4, {
	full_punch_interval = 1.3, max_drop_level = 0,
	groupcaps = {
		cracky = {times = {[1] = 8.0, [2] = 4.5, [3] = 2.2}, uses = 20, maxlevel = 0},
		crumbly = {times = {[1] = 2.2, [2] = 1.2, [3] = 0.6}, uses = 40, maxlevel = 0},
	},
	damage_groups = {fleshy = 3},
})

local function spear(name, desc, dmg, thrown)
	local function throw(stack, user)
		return bc.hunt.throw(stack, user, {damage = thrown, speed = 24, drop = 1, wear = 65535 / 40})
	end
	tool(name, desc .. "\nRight-click to throw.", 1.0, {
		full_punch_interval = 1.2, max_drop_level = 0,
		groupcaps = {},
		damage_groups = {fleshy = dmg},
	}, {range = 5, on_secondary_use = throw, on_place = throw, groups = {bc_spear = 1}})
end
spear("spear_wood", "Sharpened Spear", 4, 5)
spear("spear_flint", "Flint Spear", 7, 9)

tool("bow", "Bow\nLeft-click to shoot an arrow from your pack.", 0.7, nil, {
	on_use = function(stack, user) return bc.hunt.shoot(stack, user) end,
})

tool("fishing_rod", "Fishing Pole\nUse on water to cast; use again when the float dips.", 0.5, nil, {
	liquids_pointable = true,
	range = 8,
	on_use = function(stack, user, pt) return bc.hunt.fish(stack, user, pt) end,
	on_secondary_use = function(stack, user, pt) return bc.hunt.fish(stack, user, pt) end,
	on_place = function(stack, user, pt) return bc.hunt.fish(stack, user, pt) end,
})

tool("fire_drill", "Bow Drill\nPunch a fire lay to work up an ember. Needs tinder in your pack.", 0.5, nil, {
	groups = {bc_firestarter = 1}, _bc_fire = {method = "drill", kcal = 14, rest = 0.5, uses = 25},
})
tool("striker", "Flint and Pyrite\nPunch a fire lay to throw sparks. Needs tinder in your pack.", 0.5, nil, {
	groups = {bc_firestarter = 1}, _bc_fire = {method = "striker", kcal = 2, rest = 0.05, uses = 60},
})

-- ---------------------------------------------------------------------
-- Medicine
-- ---------------------------------------------------------------------
-- Use on yourself, or punch another player with it to treat them.
local function treatment(name, desc, apply)
	local function use(stack, user, pt)
		local target = user
		if pt and pt.type == "object" and pt.ref and pt.ref:is_player() then target = pt.ref end
		local st = bc.state(target)
		if not st then return stack end
		local ok, msg = apply(st.v, target)
		if not ok then
			bc.toast(user, msg or "That would not help right now.")
			return stack
		end
		bc.sound("bc_cloth", user, 0.6)
		if target ~= user then
			bc.toast(target, user:get_player_name() .. " treats you. " .. (msg or ""))
			bc.toast(user, "You treat " .. target:get_player_name() .. ".")
		elseif msg then
			bc.toast(user, msg)
		end
		stack:take_item()
		return stack
	end
	item(name, desc, 0.05, {on_use = use})
end

local sim = bc.sim
treatment("bandage", "Fibre Bandage\nStops bleeding. Use on yourself or punch a companion.", function(v)
	if v.aff.bleeding then
		v.aff.bleeding = nil
		sim.add_affliction(v, "wound")
		return true, "The bleeding stops."
	end
	return false, "There is no bleeding to stop."
end)
treatment("poultice", "Yarrow Poultice", function(v, target)
	if v.aff.bleeding or v.aff.wound then
		v.aff.bleeding, v.aff.wound = nil, nil
		sim.add_affliction(v, "wound_dressed")
		bc.learn(target, "yarrow")
		return true, "The bleeding slows and stops. The wound is clean."
	end
	return false, "There is no wound to dress."
end)
treatment("lichen_dressing", "Lichen Dressing", function(v, target)
	if v.aff.infection or v.aff.wound or v.aff.bleeding then
		local had = v.aff.infection
		v.aff.infection, v.aff.wound, v.aff.bleeding = nil, nil, nil
		sim.add_affliction(v, "wound_dressed")
		bc.learn(target, "lichen")
		return true, had and "The angry redness begins to fade." or "The wound is dressed and clean."
	end
	return false, "There is no wound to dress."
end)

-- Tools used as part of a recipe (a knife, say) come back a little worn
-- instead of being consumed. Crafting itself takes a little effort.
bc.CRAFT_WEAR = 65535 / 60
bc.CRAFT_EFFORT = {3, 0.05}   -- kcal, rest
core.register_on_craft(function(_, player, old_grid, craft_inv)
	for i, stack in ipairs(old_grid) do
		if core.get_item_group(stack:get_name(), "bc_keep") > 0 then
			stack:add_wear(bc.CRAFT_WEAR)
			craft_inv:set_stack("craft", i, stack)
		end
	end
	if player then bc.exert(player, bc.CRAFT_EFFORT[1], bc.CRAFT_EFFORT[2]) end
end)
