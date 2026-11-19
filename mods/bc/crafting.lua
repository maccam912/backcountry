-- Recipes, and what each player knows about them.
-- A recipe is known from the start (basic), or once the player has handled
-- every item in `unlock`, or once they have learned the journal note
-- named by `secret`. The Crafting tab of the journal only lists known ones;
-- the craft grid itself always works, so experimenting pays off.
--
-- Making things is also practised. A recipe made once by hand can be laid
-- out in the craft grid from the journal; made five times it is second
-- nature, and is made on the way whenever another recipe needs its output.
bc.recipes = {}
bc.recipe_by_id = {}

local function craft(id, cat, output, items, opts)
	opts = opts or {}
	core.register_craft({type = "shapeless", output = output, recipe = items, replacements = opts.replacements})
	local r = {id = id, cat = cat, output = output, output_name = ItemStack(output):get_name(), items = items, replacements = opts.replacements,
		unlock = opts.unlock, secret = opts.secret, note = opts.note}
	bc.recipes[#bc.recipes + 1] = r
	bc.recipe_by_id[id] = r
end
bc.register_recipe = craft

local function n(item, count)
	local t = {}
	for i = 1, count do t[i] = item end
	return t
end
local function join(...)
	local out = {}
	for _, part in ipairs({...}) do
		if type(part) == "table" then
			for _, v in ipairs(part) do out[#out + 1] = v end
		else
			out[#out + 1] = part
		end
	end
	return out
end

local KNIFE = "group:bc_knife"

-- Tools ---------------------------------------------------------------
craft("sharp_stone", "Tools", "bc:sharp_stone", n("bc:rock", 2),
	{note = "Strike one rock against another until a flake with a keen edge comes away."})
craft("cordage", "Tools", "bc:cordage", n("bc:grass", 3),
	{note = "Twist green grass fibres into cord. Everything else is lashed together with it."})
craft("cordage_nettle", "Tools", "bc:cordage 2", n("bc:nettle", 2),
	{unlock = {"bc:nettle"}, note = "Nettle stems hold long, strong fibres."})
craft("cordage_sinew", "Tools", "bc:cordage 2", {"bc:sinew"},
	{unlock = {"bc:sinew"}, note = "Dried sinew splits into the strongest thread there is."})
craft("hatchet", "Tools", "bc:hatchet", {"bc:rock", "bc:stick", "bc:cordage"},
	{note = "A stone head lashed to a handle. Slow, but it will fell a tree."})
craft("digging_stick", "Tools", "bc:digging_stick", {"bc:stick", "bc:stick", KNIFE},
	{note = "A stout stick whittled to a chisel point. Digs soil far faster than hands."})
craft("knife_flint", "Tools", "bc:knife_flint", {"bc:flint", "bc:stick", "bc:cordage"},
	{unlock = {"bc:flint"}, note = "Flint takes a far better edge than common rock, and keeps it."})
craft("pick_antler", "Tools", "bc:pick_antler", {"bc:antler", "bc:stick", "bc:cordage"},
	{unlock = {"bc:antler"}, note = "Antler is tough enough to pry rock apart."})
craft("bark", "Tools", "bc:bark 4", {"bc:birch_trunk", KNIFE},
	{unlock = {"bc:birch_trunk"}, note = "Peel the papery bark from a birch log. It burns even when damp."})
craft("basket", "Tools", "bc:basket", n("bc:grass", 6),
	{note = "A woven basket to keep supplies in at camp."})

-- Fire ----------------------------------------------------------------
craft("fire_lay", "Fire", "bc:campfire_unlit", n("bc:stick", 3),
	{note = "A small teepee of sticks. Light it with a bow drill and tinder, then feed it."})
craft("fire_drill", "Fire", "bc:fire_drill", {"bc:stick", "bc:stick", "bc:stick", "bc:cordage"},
	{note = "Bow, spindle and hearth board. Hard work, and it fails often until you learn the knack."})
craft("striker", "Fire", "bc:striker", {"bc:flint", "bc:pyrite"},
	{unlock = {"bc:pyrite"}, note = "Flint struck on pyrite throws hot sparks. Far easier than a drill."})
craft("torch", "Fire", "bc:torch_unlit", {"bc:stick", "bc:bark"},
	{unlock = {"bc:bark"}, note = "Birch bark wound round a stick. Light it at a fire."})
craft("torch_fat", "Fire", "bc:torch_unlit 2", {"bc:stick", "bc:stick", "bc:dry_grass", "bc:fat"},
	{unlock = {"bc:fat"}, note = "Dry grass soaked in fat burns long and bright."})

-- Shelter -------------------------------------------------------------
craft("thatch", "Shelter", "bc:thatch 3", n("group:bc_thatch", 4),
	{note = "Bundled grass or leafy boughs. Light, quick to make, and good insulation against heat and cold."})
craft("wattle", "Shelter", "bc:wattle 2", n("bc:stick", 6),
	{note = "Woven sticks. A fast wall, but draughty until it is daubed with clay."})
craft("daub", "Shelter", "bc:daub", {"bc:wattle", "bc:clay_lump", "bc:grass"},
	{unlock = {"bc:clay_lump"}, note = "Bind clay with grass to insulate the wall. You can also use clay on a standing wattle panel with green grass in your pack."})
craft("door", "Shelter", "bc:door", {"bc:wattle", "bc:stick", "bc:cordage"},
	{note = "A hinged panel. Stack two for a doorway. Shut the door to keep out summer heat and winter cold."})
craft("drystone", "Shelter", "bc:drystone", n("bc:rock", 4),
	{note = "Rocks fitted without mortar. The wall blocks wind but gives little insulation."})
craft("snow_block", "Shelter", "bc:snow_block", n("bc:snowball", 4),
	{unlock = {"bc:snowball"}, note = "Packed snow is one of the best insulators there is."})
craft("bed", "Shelter", "bc:bed", join(n("group:leaves", 4), n("bc:stick", 2)),
	{note = "A springy mattress of boughs that keeps you off the cold ground. Right-click to sleep."})
craft("bedroll", "Shelter", "bc:bedroll", join(n("bc:hide_cured", 4), "bc:cordage"),
	{unlock = {"bc:hide_cured"}, note = "Furs to sleep in. Warmer than boughs, and you can carry it."})
craft("cairn", "Shelter", "bc:cairn", n("bc:rock", 5),
	{note = "A stack of stones marking camp. Your journal will show the way back to it."})
craft("rack", "Shelter", "bc:rack", join(n("bc:stick", 5), n("bc:cordage", 2)),
	{note = "Hang meat, fish and hides here to dry. Dried food keeps indefinitely."})

-- Food and water --------------------------------------------------------
craft("pot_unfired", "Food and Water", "bc:pot_unfired", n("bc:clay_lump", 3),
	{unlock = {"bc:clay_lump"}, note = "Shape a pot from clay, then bake it hard in a fire."})
craft("pot_snow", "Food and Water", "bc:pot_water_raw", join("bc:pot", n("bc:snowball", 4)),
	{unlock = {"bc:pot", "bc:snowball"}, note = "Pack a pot with snow, then melt and boil it at the fire."})
craft("waterskin", "Food and Water", "bc:waterskin", {"bc:hide_cured", "bc:sinew"},
	{unlock = {"bc:hide_cured"}, note = "A stitched hide bag that carries a good drink."})
craft("waterskin_fill", "Food and Water", "bc:waterskin_clean", {"bc:waterskin", "bc:pot_water_boiled"},
	{unlock = {"bc:waterskin", "bc:pot"}, replacements = {{"bc:pot_water_boiled", "bc:pot"}},
		note = "Decant boiled water into the skin for the trail."})
craft("acorn_mash", "Food and Water", "bc:acorn_mash", join(n("bc:acorn", 4), "bc:pot_water_boiled"),
	{secret = "acorn", replacements = {{"bc:pot_water_boiled", "bc:pot"}},
		note = "Soaking crushed acorns in hot water draws the bitterness out."})

-- Hunting and fishing ---------------------------------------------------
craft("spear_wood", "Hunting", "bc:spear_wood", {"bc:stick", "bc:stick", "bc:stick", KNIFE},
	{note = "A long pole with a fire-hardened point. Stab with it, or right-click to throw."})
craft("spear_flint", "Hunting", "bc:spear_flint", {"bc:flint", "bc:stick", "bc:stick", "bc:cordage"},
	{unlock = {"bc:flint"}, note = "A flint head makes a spear that kills."})
craft("snare", "Hunting", "bc:snare", {"bc:stick", "bc:stick", "bc:cordage"},
	{note = "A noose on a bent stick. Set several on open ground, then go away: nothing comes near a person."})
craft("hook_wood", "Hunting", "bc:hook", {"bc:stick", KNIFE},
	{note = "A gorge hook carved from hardwood."})
craft("hook_bone", "Hunting", "bc:hook 3", {"bc:bone", KNIFE},
	{unlock = {"bc:bone"}, note = "Bone carves into fine, strong hooks."})
craft("fishing_rod", "Hunting", "bc:fishing_rod", {"bc:stick", "bc:cordage", "bc:hook"},
	{note = "Use on water to cast. When the float dips, use again at once. Bait in your pack helps."})
craft("fish_trap", "Hunting", "bc:fish_trap", join(n("bc:stick", 6), n("bc:cordage", 2)),
	{unlock = {"bc:fish_raw"}, note = "A funnel basket. Sink it in water and it fishes while you do other things."})
craft("bow", "Hunting", "bc:bow", {"bc:stick", "bc:stick", "bc:cordage", "bc:cordage"},
	{note = "Left-click to shoot an arrow from your pack."})
craft("arrow", "Hunting", "bc:arrow 6", {"bc:stick"},
	{note = "One stick supplies six arrows. Pick up misses where they land and recover hits when you butcher."})
craft("arrow_fletched", "Hunting", "bc:arrow 12", {"bc:stick", "bc:flint", "bc:feather"},
	{unlock = {"bc:feather", "bc:flint"}, note = "Use spare feathers and flint for a double batch."})

-- Clothing --------------------------------------------------------------
craft("grass_cape", "Clothing", "bc:grass_cape", join(n("bc:grass", 6), n("bc:cordage", 2)),
	{note = "Layered grass sheds rain like a thatched roof."})
craft("fur_hat", "Clothing", "bc:fur_hat", {"bc:hide_cured", "bc:cordage"},
	{unlock = {"bc:hide_cured"}, note = "A great deal of heat is lost from the head."})
craft("fur_mittens", "Clothing", "bc:fur_mittens", {"bc:hide_cured", "bc:cordage", "bc:cordage"},
	{unlock = {"bc:hide_cured"}})
craft("hide_boots", "Clothing", "bc:hide_boots", {"bc:hide_cured", "bc:hide_cured", "bc:cordage"},
	{unlock = {"bc:hide_cured"}})
craft("fur_leggings", "Clothing", "bc:fur_leggings", join(n("bc:hide_cured", 3), n("bc:cordage", 2)),
	{unlock = {"bc:hide_cured"}})
craft("fur_coat", "Clothing", "bc:fur_coat", join(n("bc:hide_cured", 5), n("bc:cordage", 2)),
	{unlock = {"bc:hide_cured"}, note = "The one garment that makes winter survivable."})

-- Medicine --------------------------------------------------------------
craft("bandage", "Medicine", "bc:bandage", n("bc:cordage", 2),
	{note = "Woven fibre to bind a wound. Stops bleeding; does nothing against infection."})
craft("poultice", "Medicine", "bc:poultice", n("bc:yarrow", 2),
	{unlock = {"bc:yarrow"}, note = "Crushed yarrow leaves. You suspect they are good for something."})
craft("lichen_dressing", "Medicine", "bc:lichen_dressing", {"bc:lichen", "bc:bandage"},
	{unlock = {"bc:lichen"}, note = "Beard lichen packed into a bandage. Folk medicine, perhaps."})

function bc.recipe_known(st, r)
	-- A successful experiment belongs in the book, even if the player has
	-- never seen the material or field note that normally gives the idea.
	if (st.p.crafted[r.id] or 0) > 0 then return true end
	if r.secret then return st.p.notes[r.secret] ~= nil end
	if r.unlock then
		for _, name in ipairs(r.unlock) do
			if not st.p.items[name] then return false end
		end
	end
	return true
end

-- Called when a player handles a new kind of item: returns recipes that
-- just became known because of it.
function bc.recipes_unlocked_by(st, item)
	local out = {}
	for _, r in ipairs(bc.recipes) do
		if r.unlock and not r.secret and (st.p.crafted[r.id] or 0) == 0 then
			local uses = false
			for _, name in ipairs(r.unlock) do if name == item then uses = true end end
			if uses and bc.recipe_known(st, r) then out[#out + 1] = r end
		end
	end
	return out
end

function bc.item_label(name)
	if name:sub(1, 6) == "group:" then
		local g = name:sub(7)
		return ({bc_knife = "Any knife", bc_thatch = "Grass or leaves", leaves = "Any leaves",
			bc_pot_water = "Pot of water", bc_berry = "Any berries"})[g] or g
	end
	local def = core.registered_items[ItemStack(name):get_name()]
	local desc = def and def.description or name
	return (desc:match("^[^\n]*"))
end

-- ---------------------------------------------------------------------
-- Practice
-- ---------------------------------------------------------------------
bc.CRAFT_LAYOUT = 1   -- times made before the journal will lay a recipe out
bc.CRAFT_AUTO = 5     -- times made before it is made for you along the way

function bc.times_crafted(st, r)
	return st.p.crafted[r.id] or 0
end

local function is_group(ingredient)
	return ingredient:sub(1, 6) == "group:"
end

local function fits(ingredient, name)
	if is_group(ingredient) then return core.get_item_group(name, ingredient:sub(7)) > 0 end
	return ingredient == name
end

local function keeps(name)
	return core.get_item_group(name, "bc_keep") > 0
end

-- The recipe a craft grid was laid out for, given what it produced.
function bc.recipe_for_grid(grid, output)
	local names = {}
	for _, stack in ipairs(grid) do
		if not stack:is_empty() then names[#names + 1] = stack:get_name() end
	end
	local out_name = ItemStack(output):get_name()
	for _, r in ipairs(bc.recipes) do
		if #r.items == #names and r.output_name == out_name then
			local left, ok = table.copy(names), true
			for pass = 1, 2 do   -- named ingredients claim theirs before "any knife" ones
				for _, ingredient in ipairs(r.items) do
					if is_group(ingredient) == (pass == 2) then
						local found
						for i, name in ipairs(left) do
							if fits(ingredient, name) then found = i break end
						end
						if found then table.remove(left, found) else ok = false end
					end
				end
			end
			if ok then return r end
		end
	end
end

local function practise(player, st, r)
	if not bc.recipe_known(st, r) then
		bc.toast(player, "Recipe discovered: " .. bc.item_label(r.output))
	end
	local n = bc.times_crafted(st, r) + 1
	st.p.crafted[r.id] = n
	st.pack_note = nil
	if n == bc.CRAFT_LAYOUT then
		bc.hint(player, "craft_layout")
	elseif n == bc.CRAFT_AUTO then
		bc.toast(player, "Second nature: " .. bc.item_label(r.output))
		bc.hint(player, "craft_auto")
	end
	st.fs_dirty = true
end

core.register_on_craft(function(itemstack, player, old_grid)
	local st = player and bc.state(player)
	if not st then return end
	local r = bc.recipe_for_grid(old_grid, itemstack)
	if r then practise(player, st, r) end
end)

-- What a player has to craft with: item name -> count, over pack and grid.
function bc.craft_pool(player)
	local inv, pool = player:get_inventory(), {}
	for _, list in ipairs({"craft", "main"}) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			if not stack:is_empty() then
				pool[stack:get_name()] = (pool[stack:get_name()] or 0) + stack:get_count()
			end
		end
	end
	return pool
end

-- How many of an ingredient are in a pool.
function bc.pool_count(pool, ingredient)
	if not is_group(ingredient) then return pool[ingredient] or 0 end
	local total = 0
	for name, count in pairs(pool) do
		if fits(ingredient, name) then total = total + count end
	end
	return total
end

-- Take one of an ingredient out of a pool; returns the item taken. For a
-- group that is the humblest member (a sharp stone before the flint knife),
-- then whichever there is most of.
local function take_from_pool(pool, ingredient)
	local best
	if not is_group(ingredient) then
		best = (pool[ingredient] or 0) > 0 and ingredient or nil
	else
		local group, best_rating, best_count = ingredient:sub(7)
		for name, count in pairs(pool) do
			local rating = count > 0 and core.get_item_group(name, group) or 0
			if rating > 0 and (not best or rating < best_rating
					or (rating == best_rating and (count > best_count or (count == best_count and name < best)))) then
				best, best_rating, best_count = name, rating, count
			end
		end
	end
	if best then pool[best] = pool[best] - 1 end
	return best
end

local gather

-- Make one of a missing ingredient from a recipe that is second nature,
-- adding the crafts needed to `steps`. Returns the item made, or nil.
local function make(st, pool, ingredient, steps, busy)
	for _, r in ipairs(bc.recipes) do
		if not busy[r.id] and fits(ingredient, r.output_name) and bc.recipe_known(st, r)
				and bc.times_crafted(st, r) >= bc.CRAFT_AUTO then
			local trial, trial_steps = table.copy(pool), {}
			busy[r.id] = true
			local items, missing = gather(st, trial, r, trial_steps, busy)
			busy[r.id] = nil
			if #missing == 0 then
				local out = ItemStack(r.output)
				for name in pairs(pool) do pool[name] = nil end
				for name, count in pairs(trial) do pool[name] = count end
				for _, step in ipairs(trial_steps) do steps[#steps + 1] = step end
				steps[#steps + 1] = {recipe = r, items = items}
				local function back(name, count) pool[name] = (pool[name] or 0) + count end
				for _, name in ipairs(items) do
					if keeps(name) then back(name, 1) end
				end
				for _, pair in ipairs(r.replacements or {}) do back(pair[2], 1) end
				back(out:get_name(), out:get_count() - 1)
				return out:get_name()
			end
		end
	end
end

-- Claim everything recipe `r` needs from `pool`: first what is to hand,
-- then what can be made. Returns the item chosen for each ingredient and
-- the ingredients that could not be had.
function gather(st, pool, r, steps, busy)
	local items, missing = {}, {}
	for pass = 1, 2 do
		for i, ingredient in ipairs(r.items) do
			if is_group(ingredient) == (pass == 2) then items[i] = take_from_pool(pool, ingredient) end
		end
	end
	for i, ingredient in ipairs(r.items) do
		if not items[i] then
			-- Another missing slot may have just yielded surplus (e.g. two
			-- lengths of nettle cordage), or returned the required tool.
			items[i] = take_from_pool(pool, ingredient) or (steps and make(st, pool, ingredient, steps, busy))
			if not items[i] then missing[#missing + 1] = ingredient end
		end
	end
	return items, missing
end

-- Work out how to lay recipe `r` out from a pool (which is left untouched).
-- Returns {items = one item name per grid slot, steps = crafts to do first},
-- or nil and the list of ingredients the player is short of.
function bc.plan_craft(st, pool, r)
	local steps = {}
	local practised = bc.times_crafted(st, r) >= bc.CRAFT_LAYOUT
	local items, missing = gather(st, table.copy(pool), r, practised and steps or nil, {[r.id] = true})
	if #missing > 0 then return nil, missing end
	return {items = items, steps = steps}
end

-- "2 x Stick, 1 x Cordage" for a list of item or ingredient names.
function bc.count_labels(names)
	local order, counts = {}, {}
	for _, name in ipairs(names) do
		if not counts[name] then order[#order + 1] = name end
		counts[name] = (counts[name] or 0) + 1
	end
	local parts = {}
	for i, name in ipairs(order) do parts[i] = counts[name] .. " x " .. bc.item_label(name) end
	return table.concat(parts, ", ")
end

local function take_one(lists, name)
	for _, list in ipairs(lists) do
		for _, stack in ipairs(list) do
			if not stack:is_empty() and stack:get_name() == name then return stack:take_item(1) end
		end
	end
end

local function put(list, stack)
	stack = ItemStack(stack)
	for pass = 1, 2 do   -- top up existing stacks before using an empty slot
		for _, slot in ipairs(list) do
			if slot:is_empty() == (pass == 2) then
				stack = slot:add_item(stack)
				if stack:is_empty() then return true end
			end
		end
	end
	return false
end

-- Return a whole layout, including worn tools and item metadata. Try it
-- against copies first so a full pack leaves the player's grid intact.
function bc.clear_craft_grid(player)
	local inv = player:get_inventory()
	local main = inv:get_list("main")
	for _, stack in ipairs(inv:get_list("craft")) do
		if not stack:is_empty() and not put(main, stack) then
			return false, "Make some space in your pack first."
		end
	end
	inv:set_list("main", main)
	inv:set_list("craft", {})
	return true, "Crafting materials returned to your pack."
end

-- Lay recipe `r` out in the player's craft grid, first making whatever is
-- missing from recipes that are second nature. Everything is worked out on
-- copies of the pack and grid, so nothing changes unless all of it fits.
-- Returns true and the items made along the way, or false and why not.
function bc.lay_out(player, st, r)
	if bc.times_crafted(st, r) < bc.CRAFT_LAYOUT then
		return false, "Make it once by hand first."
	end
	local plan, missing = bc.plan_craft(st, bc.craft_pool(player), r)
	if not plan then return false, "You are short of " .. bc.count_labels(missing) .. "." end
	local inv = player:get_inventory()
	local main, grid, spare = inv:get_list("main"), inv:get_list("craft"), {}
	local from = {grid, spare, main}
	local made = {}

	for _, step in ipairs(plan.steps) do
		local input = {}
		for i = 1, 9 do
			input[i] = step.items[i] and take_one(from, step.items[i]) or ItemStack("")
		end
		local out, left = core.get_craft_result({method = "normal", width = 3, items = input})
		if out.item:get_name() ~= ItemStack(step.recipe.output):get_name() then
			return false, "That did not come together."
		end
		spare[#spare + 1] = out.item
		for _ = 1, out.item:get_count() do made[#made + 1] = out.item:get_name() end
		for i, stack in ipairs(left.items) do
			if keeps(input[i]:get_name()) then   -- a tool comes back, a little worn
				stack = input[i]
				stack:add_wear(bc.CRAFT_WEAR)
			end
			if not stack:is_empty() then spare[#spare + 1] = stack end
		end
		for _, stack in ipairs(out.replacements or {}) do spare[#spare + 1] = stack end
	end

	local laid = {}
	for i, name in ipairs(plan.items) do
		laid[i] = take_one(from, name)
		if not laid[i] then return false, "A tool would wear out along the way. Bring a spare." end
	end
	for _, list in ipairs({grid, spare}) do
		for _, stack in ipairs(list) do
			if not stack:is_empty() and not put(main, stack) then
				return false, "Your pack is too full to make room for that."
			end
		end
	end
	for i = 1, #grid do grid[i] = laid[i] or ItemStack("") end
	inv:set_list("main", main)
	inv:set_list("craft", grid)
	for _, step in ipairs(plan.steps) do
		practise(player, st, step.recipe)
		bc.exert(player, bc.CRAFT_EFFORT[1], bc.CRAFT_EFFORT[2])
	end
	return true, made
end
