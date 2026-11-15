-- Recipes, and what each player knows about them.
-- A recipe is known from the start (basic), or once the player has handled
-- every item in `unlock`, or once they have learned the journal note
-- named by `secret`. The Crafting tab of the journal only lists known ones;
-- the craft grid itself always works, so experimenting pays off.
bc.recipes = {}
bc.recipe_by_id = {}

local function craft(id, cat, output, items, opts)
	opts = opts or {}
	core.register_craft({type = "shapeless", output = output, recipe = items, replacements = opts.replacements})
	local r = {id = id, cat = cat, output = output, items = items,
		unlock = opts.unlock, secret = opts.secret, note = opts.note}
	bc.recipes[#bc.recipes + 1] = r
	bc.recipe_by_id[id] = r
end

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
	{note = "Bundled grass or leafy boughs. Light, quick to make, and it holds warmth very well."})
craft("wattle", "Shelter", "bc:wattle 2", n("bc:stick", 6),
	{note = "Woven sticks. A fast wall, but draughty until it is daubed with clay."})
craft("daub", "Shelter", "bc:daub", {"bc:wattle", "bc:clay_lump", "bc:grass"},
	{unlock = {"bc:clay_lump"}, note = "Wattle plastered with clay and grass: a solid, warm wall."})
craft("door", "Shelter", "bc:door", {"bc:wattle", "bc:stick", "bc:cordage"},
	{note = "A hinged panel. Stack two for a doorway. A shelter only holds heat with the door shut."})
craft("drystone", "Shelter", "bc:drystone", n("bc:rock", 4),
	{note = "Rocks fitted without mortar. Blocks wind; holds heat poorly."})
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
	{unlock = {"bc:feather"}, note = "A bent stave and a cord. Needs arrows."})
craft("arrow", "Hunting", "bc:arrow 2", {"bc:stick", "bc:flint", "bc:feather"},
	{unlock = {"bc:feather", "bc:flint"}, note = "Flint point, feather fletching. Most can be recovered."})

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
		if r.unlock and not r.secret then
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
		return ({bc_knife = "Any knife", bc_thatch = "Grass or leaves", leaves = "Any leaves"})[g] or g
	end
	local def = core.registered_items[ItemStack(name):get_name()]
	local desc = def and def.description or name
	return (desc:match("^[^\n]*"))
end
