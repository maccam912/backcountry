-- Clothing: six slots, each garment adds warmth (degrees of felt
-- temperature). Wet clothes lose most of it; in heat it works against you.
bc.CLOTHING_SLOTS = {"Head", "Body", "Legs", "Hands", "Feet", "Cape"}

local function garment(name, desc, slot, warmth, weight, rain)
	core.register_craftitem("bc:" .. name, {
		description = desc .. "\n" .. bc.CLOTHING_SLOTS[slot] .. " - warmth +" .. warmth .. "°C (+" .. math.floor(warmth * 1.8 + 0.5) .. "°F)"
			.. (rain and "\nSheds rain" or "") .. "\nUse to wear or swap.",
		inventory_image = "bc_" .. name .. ".png",
		stack_max = 1,
		groups = {bc_clothing = slot},
		_bc_cloth = {slot = slot, warmth = warmth, rain = rain or 0},
		_bc_weight = weight,
		on_use = function(stack, player)
			local st = bc.state(player)
			if not st then return stack end
			local inv = player:get_inventory()
			local previous = inv:get_stack("clothing", slot)
			inv:set_stack("clothing", slot, stack)
			if not st.p.items[stack:get_name()] then bc.journal.discover(player, st, stack:get_name()) end
			st.fs_dirty = true
			bc.sound("bc_cloth", player, 0.5)
			bc.toast(player, "You put on the " .. desc:lower() .. ".")
			return previous
		end,
	})
end

garment("shirt", "Worn Shirt", 2, 2, 0.3)
garment("trousers", "Worn Trousers", 3, 2, 0.5)
garment("shoes", "Worn Shoes", 5, 1, 0.6)
garment("fur_hat", "Fur Hat", 1, 3, 0.4)
garment("fur_coat", "Fur Coat", 2, 11, 2.5)
garment("fur_leggings", "Fur Leggings", 3, 7, 1.6)
garment("fur_mittens", "Fur Mittens", 4, 2, 0.3)
garment("hide_boots", "Hide Boots", 5, 3, 0.9)
garment("grass_cape", "Grass Cape", 6, 2, 0.8, 0.6)

-- Total warmth and rain cover of what a player is wearing.
function bc.clothing_stats(player)
	local warmth, rain = 0, 0
	for _, stack in ipairs(player:get_inventory():get_list("clothing") or {}) do
		local def = not stack:is_empty() and stack:get_definition()
		local c = def and def._bc_cloth
		if c then
			warmth = warmth + c.warmth
			rain = math.max(rain, c.rain)
		end
	end
	return warmth, rain
end

-- Only the right kind of garment fits each slot.
core.register_allow_player_inventory_action(function(player, action, inventory, info)
	if action == "move" and info.to_list == "clothing" then
		local stack = inventory:get_stack(info.from_list, info.from_index)
		local def = stack:get_definition()
		local c = def and def._bc_cloth
		if not c or c.slot ~= info.to_index then return 0 end
		local there = inventory:get_stack("clothing", info.to_index)
		if not there:is_empty() then return 0 end
		return 1
	elseif action == "put" and info.listname == "clothing" then
		local def = info.stack:get_definition()
		local c = def and def._bc_cloth
		if not c or c.slot ~= info.index then return 0 end
		return 1
	end
end)

function bc.dress_new_player(player)
	local inv = player:get_inventory()
	inv:set_size("clothing", #bc.CLOTHING_SLOTS)
	inv:set_stack("clothing", 2, "bc:shirt")
	inv:set_stack("clothing", 3, "bc:trousers")
	inv:set_stack("clothing", 5, "bc:shoes")
end
