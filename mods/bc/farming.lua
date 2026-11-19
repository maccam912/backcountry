-- Foraged bulbs and rhizomes double as planting stock.
local bed = "bc:tilled_soil"
local tick_hours = 0.5
local crops = {
	["bc:onion"] = {id = "onion", name = "Onions", hours = 18, yield = 4, ripe = "bc_onion_plant.png"},
	["bc:cattail_root"] = {id = "cattail", name = "Cattails", hours = 24, yield = 4, ripe = "bc_cattail.png"},
}

local function can_tend(player, pos)
	local name = player:get_player_name()
	if not core.is_protected(pos, name) then return true end
	core.record_protection_violation(pos, name)
	return false
end

function bc.till_soil(stack, player, pt)
	if not player or not pt or pt.type ~= "node" then return stack end
	local ground = core.get_node(pt.under).name
	if ground == bed or core.get_item_group(ground, "soil") == 0 then
		return core.item_place(stack, player, pt)
	end
	local above = vector.offset(pt.under, 0, 1, 0)
	if not vector.equals(above, pt.above) or core.get_node(above).name ~= "air" then
		bc.toast(player, "Clear the ground, then till its top face.")
		return stack
	end
	if not can_tend(player, pt.under) then return stack end
	core.set_node(pt.under, {name = bed})
	bc.sound("bc_dig_soft", pt.under, 0.6)
	bc.exert(player, 3, 0.05)
	stack:add_wear(65535 / 50)
	return stack
end

local function irrigated(soil)
	return core.find_node_near(soil, 2, {"group:bc_water"}) ~= nil
end

local function crop_node(crop, stage)
	return "bc:crop_" .. crop.id .. "_" .. stage
end

local function grow(pos, crop)
	local soil = vector.offset(pos, 0, -1, 0)
	local ground = core.get_node(soil).name
	if ground == "ignore" then return true end
	if ground ~= bed then
		core.dig_node(pos)
		return false
	end

	local roots, plot = core.get_meta(pos), core.get_meta(soil)
	local now = bc.clock
	local last = math.min(roots:get_float("last_growth"), now)
	local watered_until = plot:get_float("watered_until")
	local wet_hours = math.max(0, math.min(now, watered_until) - last)
	local wet = watered_until > now
	if irrigated(soil) then
		wet_hours, wet = now - last, true
	else
		local _, precip = bc.rained_on(pos)
		if precip == "rain" then
			-- A shower on return from a long absence only waters the current tick.
			wet_hours = math.max(wet_hours, math.min(tick_hours, now - last))
			wet = true
			plot:set_float("watered_until", now + 24)
		end
	end

	local light = (core.get_natural_light(pos, 0.5) or 0) >= 10
	local growth = roots:get_float("growth") + (light and wet_hours or 0)
	roots:set_float("last_growth", now)
	roots:set_float("growth", growth)
	local stage = growth >= crop.hours and "ripe" or (growth >= crop.hours / 2 and "growing" or "shoots")
	local name = crop_node(crop, stage)
	if core.get_node(pos).name ~= name then core.swap_node(pos, {name = name}) end
	local status = (stage == "ripe" and "Ripe • Right-click to harvest") or
		(not light and "Needs daylight") or (not wet and "Dry soil • Needs water") or "Growing"
	roots:set_string("infotext", crop.name .. " • " .. status)
	return stage ~= "ripe"
end

local function water(soil, player, stack)
	if core.get_node(soil).name ~= bed then return end
	local held = stack:get_name()
	local empty
	if held == "bc:waterskin_raw" or held == "bc:waterskin_clean" then
		empty = "bc:waterskin"
	elseif core.get_item_group(held, "bc_pot_water") > 0 then
		empty = "bc:pot"
	else
		return
	end
	local pos = vector.offset(soil, 0, 1, 0)
	if not can_tend(player, soil) or not can_tend(player, pos) then return stack end
	local meta = core.get_meta(soil)
	local def = core.registered_nodes[core.get_node(pos).name]
	local crop = def and def._bc_growing_crop
	if crop then grow(pos, crop) end -- settle the elapsed dry time before watering
	if irrigated(soil) or meta:get_float("watered_until") > bc.clock + 23 then
		bc.toast(player, "The soil is already watered.")
		return stack
	end
	meta:set_float("watered_until", bc.clock + 24)
	if crop then grow(pos, crop) end
	bc.sound("bc_splash", pos, 0.5)
	bc.toast(player, "The furrows soak up the water.")
	stack:take_item()
	if stack:is_empty() then return ItemStack(empty) end
	bc.give(player, empty)
	return stack
end

core.register_node(bed, {
	description = "Tilled Soil",
	tiles = {"bc_furrows.png", "bc_dirt.png", "bc_dirt.png"},
	groups = {crumbly = 2, soil = 1, bc_insul = 3, not_in_creative_inventory = 1},
	drop = "bc:dirt",
	sounds = bc.snd.dirt,
	is_ground_content = false,
	_bc_weight = 10,
	on_construct = function(pos)
		core.get_meta(pos):set_string("infotext", "Tilled soil • Plant an onion bulb or cattail root")
	end,
	on_rightclick = function(soil, _, player, stack, pt)
		local crop = crops[stack:get_name()]
		if not crop then
			local result = water(soil, player, stack)
			if result then return result end
			if pt and stack:get_definition().type == "node" then return core.item_place_node(stack, player, pt) end
			return stack
		end
		local pos = vector.offset(soil, 0, 1, 0)
		if not can_tend(player, soil) or not can_tend(player, pos) then return stack end
		if core.get_node(pos).name ~= "air" then
			bc.toast(player, "This bed has no room for another plant.")
			return stack
		end
		core.set_node(pos, {name = crop_node(crop, "shoots")})
		stack:take_item()
		bc.sound("bc_dig_soft", pos, 0.4)
		return stack
	end,
})

for seed, crop in pairs(crops) do
	for stage, height in pairs({shoots = -0.16, growing = 0.15, ripe = 0.45}) do
		local ripe = stage == "ripe"
		bc.register_plant("crop_" .. crop.id .. "_" .. stage, {
			description = crop.name .. (ripe and " (ripe)" or " (" .. stage .. ")"),
			texture = ripe and crop.ripe or ("bc_" .. crop.id .. "_" .. stage .. ".png"),
			height = height,
			drop = ripe and (seed .. " " .. crop.yield) or seed,
			groups = {not_in_creative_inventory = 1},
			is_ground_content = false,
			_bc_growing_crop = not ripe and crop or nil,
			on_construct = function(pos)
				core.get_meta(pos):set_float("last_growth", bc.clock)
				if not ripe then
					grow(pos, crop)
					core.get_node_timer(pos):start(bc.real_seconds(tick_hours))
				end
			end,
			on_timer = function(pos) return grow(pos, crop) end,
			can_dig = function(pos, player)
				return not player or can_tend(player, vector.offset(pos, 0, -1, 0))
			end,
			on_rightclick = function(pos, _, player, stack)
				if ripe then
					if not can_tend(player, pos) or not can_tend(player, vector.offset(pos, 0, -1, 0)) then return stack end
					core.remove_node(pos)
					bc.give(player, seed .. " " .. crop.yield)
					bc.sound("bc_dig_leaves", pos, 0.6)
					return player:get_wielded_item()
				end
				return water(vector.offset(pos, 0, -1, 0), player, stack) or stack
			end,
		})
	end
end
