-- The journal: the inventory screen and everything that helps a player
-- understand what their body needs. Guidance is layered:
--   * Condition tab  - exactly what is helping and hurting right now
--   * Field Guide    - the basics, written down
--   * Crafting       - recipes you know (more appear as you find things)
--   * Notes          - goals, and discoveries you made the hard way
local sim = bc.sim
bc.journal = {}

local W, H = 13.5, 10.9
local TABS = {"Pack", "Condition", "Crafting", "Field Guide", "Notes"}

local function hesc(s)
	return (tostring(s):gsub("\\", "\\\\"):gsub("<", "\\<"))
end
local function hyper(x, y, w, h, name, text)
	return string.format("hypertext[%s,%s;%s,%s;%s;%s]", x, y, w, h, name,
		core.formspec_escape("<global valign=top color=#e4e2d6 size=15>" .. text))
end
local function col(color, text) return "<style color=" .. color .. ">" .. text .. "</style>" end
local GOOD, WARN, BAD, DIM = "#9fd08a", "#f0b040", "#ff6a55", "#a8a698"
local MAKE = "#c8b070"   -- something that will be made on the way

-- ---------------------------------------------------------------------
-- Goals: a suggested order of business for someone new to the woods
-- ---------------------------------------------------------------------
bc.objectives = {
	{"gather", "Gather sticks and rocks", "Fallen branches and loose rocks lie on the ground. Punch them to pick them up; leaves give sticks too."},
	{"knife", "Make a cutting edge", "Put two rocks in the craft grid to knap a sharp stone."},
	{"cordage", "Twist some cordage", "Pick tall grass, then craft three bundles into cord."},
	{"forage", "Forage something to eat", "Berry bushes, cattails by the water, wild onions. Be wary of mushrooms."},
	{"fire", "Light a fire", "Craft a fire lay and a bow drill, carry tinder, and punch the lay with the drill. Keep trying."},
	{"water", "Drink safe water", "Raw water can make you ill. Boil it in a clay pot at a fire. Clay lies in beds near water."},
	{"sleep", "Sleep through a night", "Make a bed from boughs or a pallet from dry grass. Choose a warm spot to sleep."},
	{"shelter", "Sleep in a sealed shelter", "Wall in a small space, add a roof and shut the door. Well-insulated walls keep out heat and cold."},
	{"cook", "Eat a cooked meal", "Put raw meat or fish on a burning fire."},
	{"hatchet", "Make a hatchet", "Rock, stick and cordage. Chop a tree to fell it, then chop the fallen trunk for logs."},
	{"fish", "Catch a fish", "Carve a hook, tie a pole, cast onto water and strike when the float dips."},
	{"trap", "Snare a rabbit", "Set snares on open ground well away from camp and check them next morning."},
	{"hunt", "Bring down an animal", "Stalk low and slow with the wind in your face. A spear or a bow does the rest."},
	{"clothing", "Make something warm to wear", "Dry hides on a rack, then stitch them with cordage."},
	{"day3", "Survive three days"},
	{"day10", "Survive ten days"},
	{"winter", "See a winter through"},
}
local OBJ = {}
for i, o in ipairs(bc.objectives) do OBJ[o[1]] = i end

local function next_objective(st)
	for _, o in ipairs(bc.objectives) do
		if not st.p.obj[o[1]] then return o end
	end
end

function bc.objective(player, id)
	local st = bc.state(player)
	if not st or not OBJ[id] or st.p.obj[id] then return end
	st.p.obj[id] = bc.day()
	bc.toast(player, "Done: " .. bc.objectives[OBJ[id]][2])
	bc.sound("bc_page", player, 0.6)
	st.fs_dirty = true
end

-- ---------------------------------------------------------------------
-- Discoveries: things the journal only records once you find them out
-- ---------------------------------------------------------------------
bc.lore = {
	raw_meat = {"Raw flesh", "Raw meat and fish can make you badly ill. Cooked over a fire they are safe, and give far more."},
	bad_water = {"Bad water", "Water straight from the ground made you ill. Still water is worse than running water; boiled water is safe."},
	boiled = {"Boiled water", "Water boiled in a pot at the fire has never made you ill."},
	snow = {"Eating snow", "Snow quenches thirst a little but chills you from the inside. Better to melt it in a pot."},
	acorn = {"Bitter acorns", "Raw acorns are full of bitter tannin. Soaking them in hot water might draw it out: try acorns with a pot of boiled water."},
	acorn_mash = {"Acorn mash", "Leached in hot water, acorns become a filling, starchy meal."},
	charcoal = {"Charcoal for the gut", "Charcoal from a dead fire, choked down, eases food poisoning."},
	yarrow = {"Yarrow", "A poultice of crushed yarrow stops bleeding and leaves a wound clean."},
	lichen = {"Beard lichen", "The grey lichen that hangs from pines draws infection out of a wound. It also takes a spark well."},
	bark_wet = {"Birch bark in the rain", "Birch bark is full of oil. It lit when everything else was too wet to burn."},
	striker = {"Flint and pyrite", "Sparks from flint on pyrite light tinder far more easily than a drill."},
	wind_scent = {"Scent on the wind", "The animal bolted before it could have seen you. The wind was at your back, carrying your scent. Approach with the wind in your face."},
	fire_wolves = {"Wolves and fire", "The wolf wanted to come closer and would not. They fear flame: a campfire, or a burning torch in the hand."},
	small_shelter = {"A snug shelter", "You slept in a small room where the air stayed milder than it was outside."},
	smoke = {"Smoking", "Meat on a rack near a burning fire dried in less than half the time."},
	cold_keeps = {"Cold keeps food", "Food barely spoils when the air is near freezing, and rots within a day in the heat."},
	warm_stones = {"A warm room", "A fire inside a sealed, well-insulated shelter left it warm for hours after the flames died."},
	trail_signs = {"Signs along the trail", "The arrow shows the way. A pot marks water, a berry marks a patch, a hook marks fishing and a bed marks camp. Use charcoal to turn it, or a stick to clear the symbol."},
	honing = {"A second edge", "A handful of sand or gravel at a honing slab brings back a third of a hatchet or flint knife's working life."},
	carried_fire = {"Fire from yesterday", "An ember tucked into a roll at a fire or its glowing remains lasts six game hours. One coal can start the next camp's fire."},
	rainwater = {"Catching the rain", "An empty clay pot left under open sky catches a clean drink in about two hours of steady rain. A downpour fills it twice as fast."},
	camp_supper = {"Supper for two", "A pot of stew or chowder holds two helpings. Set it down and anyone at camp can take a portion. The last serving leaves the pot."},
}

function bc.learn(player, key, text)
	local st = bc.state(player)
	if not st or st.p.notes[key] then return false end
	local lore = bc.lore[key]
	st.p.notes[key] = text or true
	st.p.note_order = st.p.note_order or {}
	table.insert(st.p.note_order, key)
	bc.toast(player, "Journal: " .. (lore and lore[1] or "a discovery"))
	bc.sound("bc_page", player, 0.6)
	for _, r in ipairs(bc.recipes) do
		if r.secret == key then bc.toast(player, "New idea: " .. bc.item_label(r.output)) end
	end
	st.fs_dirty = true
	return true
end

-- ---------------------------------------------------------------------
-- Tips: shown once each, in chat, when they first become relevant
-- ---------------------------------------------------------------------
local HINTS = {
	thirst = "You are getting thirsty. Right-click water with an empty hand to drink. Untreated water is a gamble; boiled water is safe. Your journal's Condition tab says which way the nearest water lies.",
	hunger = "You are hungry. Forage berries and roots, fish, set snares, or hunt. Cooked food gives far more than raw.",
	cold = "You are losing body heat. Get out of the wind, get dry, build a fire, or put on more clothing. The Condition tab of your journal shows exactly what is costing you warmth.",
	wet = "You are wet. Wet clothes lose most of their warmth. Dry off by a fire or get under a roof.",
	tired = "You are tired. Four handfuls of dry grass or leaves and two sticks make bedding. Put it in a warm spot and right-click to sleep.",
	night = "Night is coming and it will get colder. A fire and a shelter are what get people through the dark.",
	hot = "You are overheating. Cool off in a sealed shelter or in the shade. Rest, take off warm clothing and drink.",
	heavy = "Your pack is heavy. Over 20 kg slows you and costs extra energy. Store things at camp in a basket.",
	raw_water = "That water was untreated. It may be fine; it may not. Still water is riskier than a running river.",
	fire_lay = "To light a fire lay, hold a bow drill and punch the lay. You need tinder in your pack: dry grass, birch bark or beard lichen.",
	fire_fail = "Fire by friction fails often at first. It gets easier with practice; better tinder and shelter from wind help.",
	fire_rain = "Rain makes fire-lighting very hard. Lay the fire under a roof, or find tinder that burns wet.",
	sleep = "While everyone in the group sleeps, the night passes in moments. Jump to get up early.",
	infection = "An infected wound drains you for days. Dress wounds promptly. Something in the forest fights infection.",
	spoilage = "Some of your food has spoiled. Raw meat keeps about two days on average in mild weather. Cook it for a longer trip or dry it on a rack to keep it indefinitely.",
	bleeding = "You are bleeding. Use a bandage (two cordage) on yourself, or have a companion punch you with one.",
	predator = "A predator is coming for you. Fire keeps wolves back; a spear makes them think again. You cannot outrun them.",
	blood_trail = "The animal is bleeding. Look for red drops beside its tracks. Right-click a print to read its direction.",
	butcher = "Right-click the carcass with a knife or sharp stone in hand to butcher it, one cut at a time.",
	fishing = "Watch the float. When it dips you get a moment to use the pole again and set the hook. Dawn and dusk fish best.",
	dark = "It is very dark. A torch (stick and birch bark) lit at a fire gives light you can carry.",
	craft_layout = "Now that you have made that once, your hands know it. Double-click it in the journal's Crafting tab (or press Lay it out) and the materials are set out in the craft grid for you.",
	craft_auto = "Anything you have made five times is second nature. When another recipe needs it and you only have the raw materials, it is made for you on the way.",
}

function bc.hint(player, key)
	local st = bc.state(player)
	if not st or st.p.hints[key] or not st.p.show_hints or not HINTS[key] then return end
	if core.settings:get_bool("bc_hints", true) == false then return end
	st.p.hints[key] = true
	bc.tell(player, "Tip: " .. HINTS[key], "#b8d8a0")
end

local FIRST_FIND = {
	["bc:flint"] = "Flint. It flakes to a far keener edge than common rock.",
	["bc:clay_lump"] = "Clay. Shaped and baked in a fire it will hold water.",
	["bc:pyrite"] = "A heavy brassy nodule. It smells of sulphur when struck.",
	["bc:lichen"] = "Grey beard lichen. Dry, wiry, faintly medicinal.",
	["bc:yarrow"] = "Yarrow. The crushed leaves have a sharp, clean smell.",
	["bc:bark"] = "Birch bark. Papery and oily.",
	["bc:hide_raw"] = "A raw hide. It will rot unless it is dried on a rack.",
	["bc:acorn"] = "Acorns. Plentiful, but they taste of tannin.",
	["bc:charcoal"] = "Charcoal from the fire. Light, clean-burning fuel.",
}

local ITEM_GOAL = {
	["bc:sharp_stone"] = "knife", ["bc:knife_flint"] = "knife", ["bc:cordage"] = "cordage",
	["bc:hatchet"] = "hatchet", ["bc:fur_hat"] = "clothing", ["bc:fur_coat"] = "clothing",
	["bc:fur_leggings"] = "clothing", ["bc:fur_mittens"] = "clothing", ["bc:hide_boots"] = "clothing",
	["bc:grass_cape"] = "clothing",
}

function bc.journal.discover(player, st, name)
	st.p.items[name] = true
	if FIRST_FIND[name] then bc.toast(player, FIRST_FIND[name]) end
	local unlocked = bc.recipes_unlocked_by(st, name)
	for i, r in ipairs(unlocked) do
		if i > 2 then
			bc.toast(player, "...and more. See the Crafting tab.")
			break
		end
		bc.toast(player, "New idea: " .. bc.item_label(r.output))
	end
	if ITEM_GOAL[name] then bc.objective(player, ITEM_GOAL[name]) end
	if st.p.items["bc:stick"] and st.p.items["bc:rock"] then bc.objective(player, "gather") end
	st.fs_dirty = true
end

-- ---------------------------------------------------------------------
-- Field guide
-- ---------------------------------------------------------------------
local GUIDE = {
	{"The first day", [[
<big><b>The first day</b></big>

You have the clothes you stand in and nothing else. In rough order, you need:

<b>1. A cutting edge.</b> Pick up loose rocks and fallen branches (punch them). Two rocks in the craft grid make a sharp stone.
<b>2. Cordage.</b> Three bundles of tall grass twist into cord. Nearly every tool is lashed with it.
<b>3. Water.</b> Find it before you are desperate. Right-click water with an empty hand to drink. It may make you ill; boiled never will.
<b>4. Fire.</b> A fire lay (3 sticks), a bow drill (3 sticks, cordage) and tinder in your pack. Punch the lay with the drill until it catches.
<b>5. A bed, then walls.</b> Four leaves and two sticks make a bough bed. On treeless ground, gather dry grass for a thinner sleeping pallet. Put it out of the wind.
<b>6. Food.</b> You can go days without it, but you weaken. Forage first; fish, trap and hunt when you have tools.

Hands learn. Anything you have made once can be laid out in the craft grid from the <b>Crafting</b> tab: double-click it there. Make a thing five times and it is second nature, made for you on the way whenever another recipe needs it.

Pin a recipe to see what you still need while gathering. In the recipe book, <b>Have materials</b> shows what you can make with the pack you have now.

The <b>Notes</b> tab tracks these as goals. The <b>Condition</b> tab tells you what your body needs right now.]]},
	{"Reading your body", [[
<big><b>Reading your body</b></big>

Five bars sit at the lower left of the screen:

<b>Condition</b> - how alive you are. Nothing harms it directly except injury; it falls when another need is at zero or your body temperature is wrong. It recovers slowly when you are fed, watered, rested and warm.
<b>Body temperature</b> - 37 C is normal. Below 35 C you are hypothermic; above 39 C you are in trouble from heat.
<b>Energy</b> - calories in the tank. Walking burns about three times what resting does, sprinting far more. Hard work costs extra: chopping, digging, building.
<b>Water</b> - falls steadily, faster when you work or sweat.
<b>Rest</b> - falls while awake. Only sleep restores it.

The top right shows the temperature of the air around you. In a sealed shelter, that is the indoor air. What it <b>feels like</b> also depends on wind, wetness, sun, clothing, fire and activity. Below about 16 C your body burns extra energy to stay warm.]]},
	{"Water", [[
<big><b>Water</b></big>

You will be thirsty long before you are hungry, and thirst kills in days.

<b>Finding it.</b> Water gathers in low ground: follow the land downhill and along valleys. Cattails only grow at the water's edge. The <b>Condition</b> tab of this journal reads the lie of the land for you and says which way the nearest open water is and roughly how far; when you are thirsty it will tell you unasked.

Drinking straight from a pond or river (right-click with an empty hand) works, but any mouthful may carry sickness. Still water is the worse risk. Illness costs far more water than the drink gave you.

<b>Boiling makes water safe.</b> Dig clay from beds near the waterline, shape a pot (3 clay) and bake it in a campfire. Fill the pot by right-clicking water, set it on the fire, and it boils. Drink from it by using it, or place it and right-click.

Snow can be eaten, at a cost in body heat. Better to pack a pot with it and melt it.

A waterskin of cured hide carries a drink with you. Right-click a placed full pot with an empty skin to fill it for the trail. Leave a spare clay pot outside when the weather turns wet.]]},
	{"Fire", [[
<big><b>Fire</b></big>

Fire is warmth, safe water, cooked food, light, and a reason for wolves to stay away.

<b>Lay it:</b> three sticks make a fire lay. Place it on the ground.
<b>Light it:</b> hold a bow drill and punch the lay. You need tinder in your pack: dry grass is the common kind, and green grass dries on a rack. It will often fail. Each try teaches you something, and each costs effort. Wind and rain work against you; a roof and walls help.
<b>Feed it:</b> right-click the fire and add fuel. Sticks burn in minutes, logs for hours. When the fuel is gone it sinks to embers, which will catch again if fed in time.

Steady rain soaks an open fire through in about fifteen game minutes. A downpour takes half that time. Cover the hearth to keep the flames and coals alive. Spare fuel stays in the fire lay when the fire goes out.

Not all tinder is equal, and a drill is not the only way to make a spark. Keep your eyes open.

Put raw food or a pot of water on the fire to cook it. Cattail roots and berry cakes can finish slowly in the coals after the flames die.]]},
	{"Shelter and warmth", [[
<big><b>Shelter and warmth</b></big>

<b>Wind</b> strips heat. Anything solid between you and it helps: a wall, a rock face, thick trees.
<b>A roof</b> keeps you dry. Four handfuls of grass or leafy boughs make three thatch panels. Loose leaves decay when cut off from a trunk.
<b>A sealed space</b> softens the swing from day to night. Earth around the floor and walls keeps a dugout closer to the local ground temperature. A cave in cold high country can stay cold even in summer. Thatch and daub insulate well. Bare stone loses heat faster, though its mass takes longer to warm and cool.
<b>A fire inside</b> gradually raises the room's air temperature. A small hut warms faster, and good insulation keeps warmth in after the flames die. Open the door to let heat out. You can also feel the fire directly when you stand in sight of it.
<b>Company</b> adds a little warmth when you share a shelter.

Building is work. Every block placed costs energy, and heavy materials cost more.

Use a garment in your hand to put it on. The old one comes back into your hand. Furs help in deep cold and become a burden in the heat. A bed keeps the ground from stealing your warmth while you sleep.]]},
	{"Foraging", [[
<big><b>Foraging</b></big>

Plants will not make you fat, but they keep you going while you learn to hunt.

<b>Berries</b> - blue in the conifer woods, red in the broadleaf. Right-click a ripe bush. They fruit again in warm weather.
<b>Cattails</b> stand at the water's edge. The roots are starchy, better roasted.
<b>Wild onions</b> grow in grassland.
<b>Prickly pear</b> in dry country gives sweet fruit full of water.
<b>Acorns</b> drop from oaks in plenty. They are bitter. There may be a way round that.
<b>Mushrooms</b> are a gamble. The kinds here are not the kinds anywhere else, and one of them can kill. Sneak and use one to <b>taste a small piece first</b>, and write down what happens.

Before leaving a picked berry bush, look at its new growth. Fallen mossy logs are worth a closer look too.

Some plants are worth more as medicine or tinder than as food. Pick things up; your journal notes what you learn.]]},
	{"Farming", [[
<big><b>Farming</b></big>

Dig up a <b>wild onion</b> in a meadow or a <b>cattail root</b> on a riverbank. Save one to plant.

Clear a patch of soil with daylight overhead. Right-click its top with a <b>digging stick</b> to cut furrows. Right-click the furrows with the bulb or root to plant it.

Water within two blocks irrigates the bed. Farther inland, right-click the bed or the crop with a full waterskin or pot of water. Untreated water works. A watering lasts a game day, and rain wets exposed beds too. A dry or shaded crop waits for better conditions.

Onions flower after about <b>18 game hours</b> of growth. Cattails grow brown heads after <b>one game day</b>. Right-click the ripe crop to lift a clump. Keep one bulb or root to start the next crop.]]},
	{"Fishing and trapping", [[
<big><b>Fishing and trapping</b></big>

These feed you while you do something else, or nothing at all.

<b>Fishing pole:</b> stick, cordage and a hook (carve one from a stick; bone makes better ones). Use it on water to cast. Watch the float: when it dips, use the pole again at once. Bait in your pack - a worm dug from the soil, a scrap of meat - is put on the hook automatically and more than doubles your luck. Fish feed at dawn and dusk and under grey skies. A hard-fished spot goes quiet for a while.

<b>Snares:</b> two sticks and cordage. Set them on open ground and go away. Nothing comes near a snare while people are about. Check them in the morning; a catch left too long gets eaten by something else.

<b>Fish traps</b> sit in the water and fill slowly on their own. You will work out how to make one once you have handled a fish.

Through ice, chop a hole with a hatchet first.]]},
	{"Hunting", [[
<big><b>Hunting</b></big>

Meat is the food that actually sustains you. Getting it is a skill.

Animals notice movement, noise and scent. <b>Sneak</b> and they notice you from less than half as far. Sprint and the whole wood knows. Stand still and you fade.

A <b>thrown rock</b> will take a grouse. Right-click to throw a <b>spear</b> or left-click to shoot a <b>bow</b>. Find both the bow and arrows in the Crafting tab under Hunting. One stick makes six arrows.

An animal wounded by an arrow or spear bleeds until it goes down. Look for red drops beside the tracks. Right-click them to read which way it went, even over bare stone. If an arrow misses, you can pick it up where it lands.

Right-click the carcass with a knife or sharp stone. The first cut returns meat and any arrows. Keep cutting for hide and the rest.

<b>Wolves</b> hunt at night, and by day if you are weak or smell of fresh meat. <b>Bears</b> want to be left alone: give them room.

Raw meat spoils. Cook it, dry it on a rack, or let the cold keep it.]]},
	{"Injury and illness", [[
<big><b>Injury and illness</b></big>

<b>Bleeding</b> drains you quickly. Bind it with a bandage (two cordage). You can treat a companion by punching them with the dressing.
<b>Wounds</b> stay open for a day and may turn septic. An <b>infection</b> burns for days.
<b>Sprains</b> come from hard landings. Rest heals them twice as fast as walking on them.
<b>Food poisoning</b> comes from raw or spoiled food; <b>dysentery</b> from bad water. Both empty you of water. Drink clean water and rest.
<b>Hypothermia</b> begins below 35 C: get warm before you do anything else. <b>Heat stroke</b> wants shade, rest and water.

The country grows its own medicine. A plant of the open meadows and a lichen of the old pines are both worth trying on a wound. Even a dead fire has its use.]]},
	{"Weather and seasons", [[
<big><b>Weather and seasons</b></big>

A new world begins on the first day of summer. The year turns through autumn into winter and round again. Cold country has hard winters; hot country barely notices.

Nights are colder than days, more so under clear skies and in dry country. High ground is colder. Deep caves hold near the yearly average: cool in summer, mild in winter.

Weather comes through in fronts: cloud, then rain or snow, sometimes storm. Storms bring wind, and wind is what makes cold dangerous.

The top right of the screen names the sky and the wind, and where the wind is from. Hunters and fire-makers both care about that.

Food spoils fast in heat and hardly at all near freezing.]]},
	{"Surviving together", [[
<big><b>Surviving together</b></big>

Everything here works for a group, and most of it works better.

Everyone starts in the same place. A <b>cairn</b> (five rocks) marks a camp. Right-click someone else's cairn to share it. Choose <b>Track camp</b> in Condition for a bearing home. When there is room to stand there, you wake at your cairn after death.

One fire warms everyone near it. Every body in a sealed shelter warms it for the rest. One person can tend the fire and the drying racks while others hunt.

Dressings can be applied to a companion: hold the bandage or poultice and punch them.

When <b>everyone</b> is asleep the night passes in moments. If someone stays up, it does not.

If you die, your pack stays where you fell for whoever reaches it. Choose <b>Track lost pack</b> in Condition to follow its bearing.]]},
	{"Controls", [[
<big><b>Controls</b></big>

<b>Punch (left click)</b> - gather, dig, strike, use a held item (eat, drink, treat, light a fire lay with a drill).
<b>Place (right click)</b> - place blocks, open fires and baskets, pick berries, sleep in a bed, butcher a carcass, throw a spear, fill a pot or waterskin at water.
<b>Right click water with an empty hand</b> - drink.
<b>Aux1 (E by default) while moving forward</b> - sprint. Costly.
<b>Sneak</b> - move quietly; with a mushroom in hand, taste rather than eat.
<b>Inventory (I)</b> - this journal.

Hard ground cannot be dug by hand: soil yields slowly to hands and quickly to a digging stick, wood needs a hatchet, rock needs a pick.]]},
}

-- ---------------------------------------------------------------------
-- Condition tab
-- ---------------------------------------------------------------------
local ADVICE = {
	thirst = "Find water. Running water is safer than still; boiled is safe.",
	hunger = "Eat. Cooked meat and fish give the most.",
	tired = "Sleep in a bed, somewhere warm enough to stay asleep.",
	wet = "Get under a roof or beside a fire to dry out.",
	load = "Leave some of your load at camp.",
	heat = "Cool off in a sealed shelter or in the shade. Rest, shed warm clothing and drink.",
}

local function cold_advice(st)
	local info, c = st.info, st.clim
	local tips = {}
	for _, part in ipairs(info.parts or {}) do
		if part[1] == "Wind" and part[2] < -1.5 then tips[#tips + 1] = "get out of the wind" end
		if part[1] == "Wet" and part[2] < -1.5 then tips[#tips + 1] = "get dry" end
	end
	if (c.fire or 0) < 3 then tips[#tips + 1] = "light or sit closer to a fire" end
	if not (c.shelter and c.shelter.enclosed) then tips[#tips + 1] = "get into a sealed shelter" end
	tips[#tips + 1] = "wear more"
	return "To warm up: " .. table.concat(tips, ", ") .. "."
end

local function rate_text(rate, unit, eps)
	if math.abs(rate) < (eps or 0.05) then return col(DIM, "steady") end
	return col(rate > 0 and GOOD or WARN, string.format("%+.1f %s/h", rate, unit))
end

local function condition_text(player, st)
	local v, info, c = st.v, st.info, st.clim
	if not info then return "..." end
	local t = {}
	local function add(s) t[#t + 1] = s end
	local season = bc.season()
	add(string.format("<big><b>Day %d, %s</b></big>   %s. You have survived %.1f days.",
		bc.day(), season, bc.time_name(), (bc.clock - st.p.born) / 24))
	add("")
	local act = ({sleep = "sleeping", rest = "resting", walk = "walking", sprint = "sprinting", swim = "swimming"})[st.activity or "rest"]
	add(string.format("<b>Condition</b>  %d%%   %s", math.ceil(v.condition), rate_text(info.rates.condition, "%")))
	local k = st.p.fahrenheit and 1.8 or 1
	add(string.format("<b>Body temperature</b>  %s   %s", bc.temp(st, v.core, 1),
		rate_text(info.rates.core * k, st.p.fahrenheit and "°F" or "°C", 0.03)))
	add(string.format("<b>Energy</b>  %d of %d kcal   %s  (%s)", math.floor(v.kcal), sim.MAX_KCAL,
		col(WARN, string.format("%d kcal/h", math.floor(info.rates.kcal))), act))
	add(string.format("<b>Water</b>  %d%%   %s", math.ceil(v.water), rate_text(info.rates.water, "%")))
	add(string.format("<b>Rest</b>  %d%%   %s", math.ceil(v.rest), rate_text(info.rates.rest, "%")))
	add("")

	-- felt temperature and why
	local felt = info.felt or 0
	local verdict
	if felt < sim.COMFORT_LOW - 6 then verdict = col(BAD, "dangerously cold: you are losing body heat")
	elseif felt < sim.COMFORT_LOW then verdict = col(WARN, "cold: you are burning extra energy to stay warm")
	elseif felt > sim.COMFORT_HIGH + 8 then verdict = col(BAD, "dangerously hot")
	elseif felt > sim.COMFORT_HIGH then verdict = col(WARN, "hot: you are sweating water away")
	else verdict = col(GOOD, "comfortable") end
	add(string.format("<b>It feels like %s</b> - %s", bc.temp(st, felt), verdict))
	local parts = {}
	for i, part in ipairs(info.parts or {}) do
		if i == 1 then
			parts[#parts + 1] = "air " .. bc.temp(st, part[2])
		else
			parts[#parts + 1] = col(part[2] >= 0 and GOOD or WARN, string.format("%s %+d", part[1]:lower(), bc.round(part[2] * k)))
		end
	end
	add(col(DIM, "   = ") .. table.concat(parts, col(DIM, ",  ")))
	add(col(DIM, string.format("   Comfortable between %s and %s.", bc.temp(st, sim.COMFORT_LOW), bc.temp(st, sim.COMFORT_HIGH))))
	add("")

	-- surroundings
	local sh = c.shelter or {}
	local where
	if sh.enclosed then
		local q = sh.insulation > 0.85 and "very well insulated" or sh.insulation > 0.6 and "fairly well insulated" or "poorly insulated"
		where = string.format("You are in a sealed space of about %d cubic metres, %s.", sh.volume, q)
		if c.air and c.outdoor_air then
			where = where .. string.format(" The air is %s inside and %s outside.", bc.temp(st, c.air), bc.temp(st, c.outdoor_air))
			if (c.fire_rise or 0) >= 0.5 then
				where = where .. " The hearth has warmed the indoor air by " .. bc.temp_delta(st, c.fire_rise) .. "."
			end
		end
	elseif sh.roof then
		where = string.format("You are under cover but the space is open to the air. About %d%% of the wind is blocked.", math.floor((sh.wind_block or 0) * 100))
	else
		where = string.format("You are in the open. About %d%% of the wind is blocked by what is around you.", math.floor((sh.wind_block or 0) * 100))
	end
	add("<b>Where you are</b>  " .. ((bc.biomes[c.biome] or {}).label or "Wild country") .. ". " .. where)
	local wind = bc.climate.wind_name(bc.weather.wind)
	if bc.weather.wind >= 1 then
		wind = wind .. " from the " .. bc.compass(vector.multiply(bc.climate.wind_vector(), -1))
	end
	add("<b>Weather</b>  " .. sim.WEATHER[bc.weather.state].label .. ". " .. wind .. ".")
	add("<b>Water</b>  " .. hesc(bc.water_text(player, st)))
	local warmth, rain = bc.clothing_stats(player)
	add(string.format("<b>Clothing</b>  %s when dry%s. You are %s.", bc.temp_delta(st, warmth, true), rain > 0 and ", sheds rain" or "",
		v.wet > 0.6 and col(WARN, "soaked") or v.wet > 0.2 and col(WARN, "damp") or "dry"))
	local load_note = st.load > sim.CARRY_COMFORT and col(WARN, " - slowing you down") or ""
	add(string.format("<b>Pack</b>  %.1f kg (comfortable up to %d kg)%s", st.load, sim.CARRY_COMFORT, load_note))
	if st.p.home then
		local pos = player:get_pos()
		local d = vector.distance(pos, st.p.home)
		if d < 12 then
			add("<b>Camp</b>  You are at your cairn.")
		else
			add(string.format("<b>Camp</b>  Your cairn is about %d m to the %s.", math.floor(d / 10 + 0.5) * 10,
				bc.compass(vector.subtract(st.p.home, pos))))
		end
	else
		add(col(DIM, "<b>Camp</b>  No cairn raised yet. Five rocks make one; it marks the way home."))
	end
	add("")

	-- problems
	local list = st.statuses or {}
	if #list == 0 then
		add(col(GOOD, "<b>Nothing is wrong.</b> Enjoy it."))
	else
		add("<b>What needs attention</b>")
		for _, s in ipairs(list) do
			local color = s.sev == 3 and BAD or s.sev == 2 and WARN or DIM
			local help = ADVICE[s.key]
			if s.key == "cold" or s.key == "hypothermia" then help = cold_advice(st) end
			if sim.AFF[s.key] then
				help = sim.AFF[s.key].help .. string.format(" (%d h left)", math.ceil(v.aff[s.key] or 0))
			end
			add(col(color, "<b>" .. s.label .. "</b>") .. (help and ("  " .. hesc(help)) or ""))
		end
	end
	return table.concat(t, "\n")
end

-- ---------------------------------------------------------------------
-- Crafting tab
-- ---------------------------------------------------------------------
local GROUP_ICON = {["group:bc_knife"] = "bc:sharp_stone", ["group:bc_thatch"] = "bc:grass",
	["group:leaves"] = "bc:pine_leaves", ["group:bc_berry"] = "bc:berries_blue", ["group:bc_pot_water"] = "bc:pot_water_raw"}

local function build_recipe_list(st, pool)
	local list, sections, categories = {}, {}, {}
	for _, r in ipairs(bc.recipes) do
		if bc.recipe_known(st, r) then
			local plan, missing = bc.plan_craft(st, pool, r)
			if plan or not st.recipes_ready then
				if not sections[r.cat] then
					categories[#categories + 1] = r.cat
					sections[r.cat] = {}
				end
				local section = sections[r.cat]
				section[#section + 1] = {key = r.id, recipe = r, label = bc.item_label(r.output),
					plan = plan, missing = missing}
			end
		end
	end
	for _, cat in ipairs(categories) do
		list[#list + 1] = {header = cat}
		for _, row in ipairs(sections[cat]) do list[#list + 1] = row end
	end
	local function processes(title, tbl, how)
		local names = {}
		for input in pairs(tbl) do
			if st.p.items[input] and (not st.recipes_ready or (pool[input] or 0) > 0) then names[#names + 1] = input end
		end
		table.sort(names)
		if #names > 0 then list[#list + 1] = {header = title} end
		for _, input in ipairs(names) do
			list[#list + 1] = {key = title .. input, process = {input = input, out = tbl[input].out, time = tbl[input].time, how = how},
				label = bc.item_label(tbl[input].out)}
		end
	end
	processes("At the fire", bc.cooking, "Put it on a burning campfire.")
	processes("On the drying rack", bc.drying, "Hang it on a drying rack. Smoke from a fire close by speeds it; rain stops it.")
	return list
end

local function crafting_tab(player, st)
	local previous = st.recipe_list and st.recipe_list[st.sel_recipe or 2]
	local selected_key = st.select_recipe_key or (previous and previous.key)
	st.select_recipe_key = nil
	local pool = bc.craft_pool(player)
	local list = build_recipe_list(st, pool)
	st.recipe_list, st.recipe_pool = list, pool
	local rows, sel = {}, 2
	for i, e in ipairs(list) do
		if e.header then
			rows[i] = "#c8b070" .. core.formspec_escape("- " .. e.header .. " -")
		else
			if e.key == selected_key then sel = i end
			-- green: practised, and the materials are there to lay it out now
			local ready = e.recipe and bc.times_crafted(st, e.recipe) >= bc.CRAFT_LAYOUT and e.plan
			local prefix = st.p.pinned_recipe == e.key and "* " or "   "
			rows[i] = (ready and GOOD or "") .. core.formspec_escape(prefix .. e.label)
		end
	end
	st.sel_recipe = sel
	local fs = "checkbox[0.4,0.8;filter_recipes;Have materials;" .. (st.recipes_ready and "true" or "false") .. "]"
		.. "tooltip[filter_recipes;Only show recipes with ingredients in your pack and craft grid.]"
	if bc.recipe_by_id[st.p.pinned_recipe] then
		fs = fs .. "button[3.1,0.45;1.8,0.65;show_pin;Pinned]"
			.. "tooltip[show_pin;Open your pinned recipe.]"
	end
	if #list == 0 then
		return fs .. hyper(0.45,1.4,8.7,2.5,"empty","No recipes match what you carry. Clear <b>Have materials</b> to see the rest of the book.")
	end
	fs = fs .. "textlist[0.3,1.25;4.6,9.25;recipes;" .. table.concat(rows, ",") .. ";" .. sel .. ";false]"
	local e = list[sel]
	if not e then return fs end
	local x = 5.3
	if e.recipe then
		local r = e.recipe
		local out = ItemStack(r.output)
		fs = fs .. "item_image[" .. x .. ",0.5;1.3,1.3;" .. out:get_name() .. "]"
			.. "label[" .. (x + 1.6) .. ",0.9;" .. core.formspec_escape(e.label .. (out:get_count() > 1 and (" x" .. out:get_count()) or "")) .. "]"
			.. "label[" .. (x + 1.6) .. ",1.4;" .. core.formspec_escape(r.cat) .. "]"
			.. "label[" .. x .. ",2.4;You need:]"
		local order, counts = {}, {}
		for _, item in ipairs(r.items) do
			if not counts[item] then order[#order + 1] = item end
			counts[item] = (counts[item] or 0) + 1
		end
		local made = bc.times_crafted(st, r)
		local plan, missing = e.plan, e.missing
		for i, item in ipairs(order) do
			local y = 2.7 + (i - 1) * 0.95
			local have = bc.pool_count(pool, item)
			local color = have >= counts[item] and GOOD or plan and MAKE or WARN
			fs = fs .. "item_image[" .. x .. "," .. y .. ";0.8,0.8;" .. (GROUP_ICON[item] or item) .. "]"
				.. "label[" .. (x + 1.1) .. "," .. (y + 0.4) .. ";" .. core.formspec_escape(counts[item] .. " x " .. bc.item_label(item))
				.. core.colorize(color, core.formspec_escape("   (you have " .. have .. ")")) .. "]"
		end
		local y = 2.9 + #order * 0.95
		local t = {hesc(r.note or ""), ""}
		if made < bc.CRAFT_LAYOUT then
			t[#t + 1] = col(DIM, "Arrange these anywhere in the craft grid on the Pack tab. A knife used in crafting is kept, a little more worn.")
			t[#t + 1] = col(DIM, "Once you have made this by hand, it can be laid out for you from here.")
		else
			if made >= bc.CRAFT_AUTO then
				t[#t + 1] = col(GOOD, "Second nature.") .. " It is made for you on the way whenever another recipe needs it and you carry the materials."
			else
				t[#t + 1] = string.format("Made %d of the %d times it takes to become second nature. After that it is made for you on the way whenever another recipe needs it.", made, bc.CRAFT_AUTO)
			end
			if plan then
				local first = {}
				for _, step in ipairs(plan.steps) do
					local out = ItemStack(step.recipe.output)
					for _ = 1, out:get_count() do first[#first + 1] = out:get_name() end
				end
				if #first > 0 then
					t[#t + 1] = col(MAKE, "You will first make " .. hesc(bc.count_labels(first)) .. " from what you carry.")
				end
			else
				t[#t + 1] = col(WARN, "You are short of " .. hesc(bc.count_labels(missing)) .. ".")
			end
			if st.craft_note then t[#t + 1] = col(BAD, hesc(st.craft_note)) end
		end
		local bottom = H - 1.4
		fs = fs .. "button[10.2," .. (H - 1.2) .. ";2.95,0.8;pin_recipe;" .. (st.p.pinned_recipe == r.id and "Unpin recipe" or "Pin recipe") .. "]"
			.. "tooltip[pin_recipe;Track missing materials on screen while gathering.]"
		if made >= bc.CRAFT_LAYOUT and plan then
			fs = fs .. "button[" .. x .. "," .. (H - 1.2) .. ";4.6,0.8;lay_out;Lay it out in the craft grid]"
				.. "tooltip[lay_out;Or double-click the recipe in the list.]"
		end
		fs = fs .. hyper(x, y, W - x - 0.4, bottom - y, "rnote", table.concat(t, "\n"))
	else
		local p = e.process
		fs = fs .. "item_image[" .. x .. ",0.5;1.3,1.3;" .. p.out .. "]"
			.. "label[" .. (x + 1.6) .. ",0.9;" .. core.formspec_escape(e.label) .. "]"
			.. "label[" .. x .. ",2.4;From:]"
			.. "item_image[" .. x .. ",2.7;0.8,0.8;" .. p.input .. "]"
			.. "label[" .. (x + 1.1) .. ",3.1;" .. core.formspec_escape(bc.item_label(p.input)) .. "]"
			.. hyper(x, 3.9, W - x - 0.4, 4, "rnote", hesc(p.how) .. string.format("\nTakes about %s of game time.",
				p.time < 1 and (math.floor(p.time * 60) .. " minutes") or (p.time .. " hours")))
	end
	return fs
end

-- ---------------------------------------------------------------------
-- Notes tab
-- ---------------------------------------------------------------------
local function notes_text(st)
	local t = {"<big><b>Goals</b></big>"}
	local nxt = next_objective(st)
	for _, o in ipairs(bc.objectives) do
		local done = st.p.obj[o[1]]
		if done then
			t[#t + 1] = col(GOOD, "[x] " .. o[2]) .. col(DIM, "  (day " .. tostring(done) .. ")")
		elseif nxt and o[1] == nxt[1] then
			t[#t + 1] = "<b>[  ] " .. o[2] .. "</b>" .. (o[3] and ("\n" .. col(DIM, "       " .. hesc(o[3]))) or "")
		else
			t[#t + 1] = col(DIM, "[  ] " .. o[2])
		end
	end
	t[#t + 1] = ""
	t[#t + 1] = "<big><b>Discoveries</b></big>"
	local order = st.p.note_order or {}
	if #order == 0 then
		t[#t + 1] = col(DIM, "Nothing yet. The guide does not tell you everything: try things, taste carefully, and watch what happens.")
	end
	for _, key in ipairs(order) do
		local lore = bc.lore[key]
		local custom = st.p.notes[key]
		if type(custom) == "string" then
			t[#t + 1] = "<b>" .. hesc(lore and lore[1] or "Field note") .. "</b>  " .. hesc(custom)
		elseif lore then
			t[#t + 1] = "<b>" .. hesc(lore[1]) .. "</b>  " .. hesc(lore[2])
		end
	end
	local total = 0
	for _ in pairs(bc.lore) do total = total + 1 end
	t[#t + 1] = ""
	t[#t + 1] = col(DIM, string.format("%d discoveries made. There are more than %d to find.", #order, total))
	t[#t + 1] = ""
	t[#t + 1] = string.format("<b>This life</b>  %.1f days.   <b>Longest</b>  %.1f days.   <b>Deaths</b>  %d.",
		(bc.clock - st.p.born) / 24, math.max(st.p.best or 0, (bc.clock - st.p.born) / 24), st.p.deaths or 0)
	return table.concat(t, "\n")
end

-- ---------------------------------------------------------------------
-- Assembling the inventory screen
-- ---------------------------------------------------------------------
local function pack_tab(player, st)
	local fs = "label[0.4,0.5;Worn]"
	for i, slot in ipairs(bc.CLOTHING_SLOTS) do
		local cx = 0.4 + ((i - 1) % 2) * 1.9
		local cy = 1.1 + math.floor((i - 1) / 2) * 1.5
		fs = fs .. "label[" .. cx .. "," .. (cy - 0.18) .. ";" .. slot .. "]"
			.. "list[current_player;clothing;" .. cx .. "," .. cy .. ";1,1;" .. (i - 1) .. "]"
	end
	local warmth, rain = bc.clothing_stats(player)
	fs = fs .. "label[0.4,5.55;" .. core.formspec_escape(string.format("Warmth %s%s", bc.temp_delta(st, warmth, true), rain > 0 and ", sheds rain" or "")) .. "]"
		.. "label[5.2,0.5;Craft]"
		.. "list[current_player;craft;5.2,0.9;3,3]"
		.. "label[9.15,2.75;=]"
		.. "list[current_player;craftpreview;9.7,2.15;1,1]"
		.. "label[5.2,5.0;" .. core.formspec_escape(string.format("Pack %.1f kg  (comfortable to %d kg)", st.load or 0, sim.CARRY_COMFORT)) .. "]"
		.. "label[5.2,5.55;" .. core.formspec_escape(st.pack_note or "Recipes you know are in the Crafting tab.") .. "]"
		.. "list[current_player;main;1.875,6.6;8,3]"
		.. "listring[current_player;main]listring[current_player;craft]"
		.. "listring[current_player;main]listring[current_player;clothing]"
	if not player:get_inventory():is_empty("craft") then
		fs = fs .. "button[9.45,3.55;3.35,0.7;clear_grid;Return materials]"
			.. "tooltip[clear_grid;Move the whole craft grid back into your pack.]"
	end
	return fs
end

local function build(player, st)
	local tab = st.tab or 1
	local fs = "formspec_version[6]size[" .. W .. "," .. H .. "]bgcolor[#171b17f4;false]"
		.. "tabheader[0,0;tabs;" .. table.concat(TABS, ",") .. ";" .. tab .. ";false;true]"
	if tab == 1 then
		fs = fs .. pack_tab(player, st)
	elseif tab == 2 then
		fs = fs .. hyper(0.4, 0.4, W - 0.8, H - 1.85, "cond", condition_text(player, st))
			.. bc.trail.controls(st, 0.4, H - 1.2)
	elseif tab == 3 then
		fs = fs .. crafting_tab(player, st)
	elseif tab == 4 then
		local rows = {}
		for i, g in ipairs(GUIDE) do rows[i] = core.formspec_escape(g[1]) end
		local sel = st.sel_topic or 1
		fs = fs .. "textlist[0.3,0.4;3.6,10.1;topics;" .. table.concat(rows, ",") .. ";" .. sel .. ";false]"
			.. hyper(4.2, 0.4, W - 4.6, H - 0.8, "guide", (GUIDE[sel][2]:gsub("(%d+) C(%W)", function(n, after)
				return bc.temp(st, tonumber(n)) .. after
			end)))
	else
		fs = fs .. hyper(0.4, 0.4, W - 0.8, H - 1.9, "notes", notes_text(st))
			.. "button[0.3," .. (H - 1.2) .. ";4.2,0.8;toggle_hints;" .. (st.p.show_hints and "Tips: on" or "Tips: off") .. "]"
			.. "button[4.6," .. (H - 1.2) .. ";4.2,0.8;toggle_goal;" .. (st.p.hide_goal and "Next goal on screen: off" or "Next goal on screen: on") .. "]"
			.. "button[8.9," .. (H - 1.2) .. ";4.2,0.8;toggle_units;" .. (st.p.fahrenheit and "Temperatures: Fahrenheit" or "Temperatures: Celsius") .. "]"
	end
	return fs
end

function bc.journal.refresh(player, st)
	local fs = build(player, st)
	if fs ~= st.fs_last then
		st.fs_last = fs
		player:set_inventory_formspec(fs)
	end
	st.fs_dirty = false
end

core.register_on_player_inventory_action(function(player)
	local st = bc.state(player)
	if st then st.fs_dirty = true end
end)

-- Lay the selected recipe out in the craft grid and turn to the Pack tab,
-- where the grid is. If it cannot be done the Crafting tab says why.
local function lay_out_selected(player, st)
	local e = st.recipe_list and st.recipe_list[st.sel_recipe or 2]
	if not e or not e.recipe then return end
	local ok, result = bc.lay_out(player, st, e.recipe)
	if not ok then
		st.craft_note = result
		return
	end
	st.pack_note = "Laid out: " .. e.label .. "."
	if #result > 0 then
		st.pack_note = "Made " .. bc.count_labels(result) .. ", then laid out: " .. e.label .. "."
	end
	st.tab = 1
	bc.sound("bc_page", player, 0.4)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "bc:death" or formname == "bc:welcome" then return true end
	if formname ~= "" then return end
	local st = bc.state(player)
	if not st then return end
	st.craft_note = nil
	if fields.tabs then
		st.tab = tonumber(fields.tabs) or 1
		st.pack_note = nil
		bc.sound("bc_page", player, 0.4)
	elseif fields.clear_grid and st.tab == 1 then
		local _, message = bc.clear_craft_grid(player)
		st.pack_note = message
	elseif fields.filter_recipes and st.tab == 3 then
		st.recipes_ready = fields.filter_recipes == "true"
	elseif fields.show_pin and st.tab == 3 then
		st.select_recipe_key = st.p.pinned_recipe
		st.recipes_ready = false
	elseif fields.pin_recipe and st.tab == 3 then
		local selected = st.recipe_list and st.recipe_list[st.sel_recipe or 2]
		if selected and selected.recipe then
			if st.p.pinned_recipe == selected.recipe.id then st.p.pinned_recipe = nil
			else st.p.pinned_recipe = selected.recipe.id end
		end
	elseif fields.recipes then
		local ev = core.explode_textlist_event(fields.recipes)
		if ev.type == "CHG" or ev.type == "DCL" then st.sel_recipe = ev.index end
		if ev.type == "DCL" then lay_out_selected(player, st) end
	elseif fields.lay_out then
		lay_out_selected(player, st)
	elseif fields.topics then
		local ev = core.explode_textlist_event(fields.topics)
		if ev.type == "CHG" or ev.type == "DCL" then st.sel_topic = sim.clamp(ev.index, 1, #GUIDE) end
	elseif fields.toggle_hints then
		st.p.show_hints = not st.p.show_hints
	elseif fields.toggle_goal then
		st.p.hide_goal = not st.p.hide_goal
	elseif fields.toggle_units then
		st.p.fahrenheit = not st.p.fahrenheit
		bc.hud.update(player, st)
	else
		return
	end
	bc.journal.refresh(player, st)
	return true
end)

function bc.journal.on_join(player, st, fresh)
	bc.journal.refresh(player, st)
	if fresh then
		local text = "<center><big><b>Backcountry</b></big></center>\n"
			.. "You are a long way from anywhere, with the clothes you stand in.\n\n"
			.. "Your body is the game. It needs <b>water</b>, <b>food</b>, <b>rest</b> and above all a steady <b>temperature</b>. "
			.. "The bars at the lower left show them; the top right shows the weather and what it feels like.\n\n"
			.. "Open your <b>inventory</b> for your journal: what your body needs right now, a field guide, the recipes you know, and your goals. "
			.. "The next goal is always shown above the bars.\n\n"
			.. "The guide teaches the basics. It does not tell you everything. Some of what keeps people alive out here you will have to find out.\n\n"
			.. col(DIM, "Start by picking up sticks and loose rocks from the ground.")
		core.show_formspec(st.name, "bc:welcome", "formspec_version[6]size[10,8.4]bgcolor[#171b17f4;false]"
			.. hyper(0.5, 0.5, 9, 6.4, "welcome", text) .. "button_exit[3.5,7.2;3,0.8;ok;Begin]")
	end
end

function bc.journal.death_screen(player, st, why, days)
	local text = string.format("<center><big><b>You died of %s.</b></big>\n\nYou lasted %.1f days. Your longest is %.1f.\n\n"
		.. "What you learned, you keep.", hesc(why), days, st.p.best or days)
	if st.p.lost_pack then
		text = text .. "\n\nChoose <b>Track lost pack</b> in your journal's Condition tab to find your belongings."
	end
	core.show_formspec(st.name, "bc:death", "formspec_version[6]size[9,6]bgcolor[#171b17f4;false]"
		.. hyper(0.5, 0.5, 8, 4.25, "death", text .. "</center>") .. "button_exit[3,4.9;3,0.8;ok;Begin again]")
end

-- Once a second from the vitals loop: tips, time-based goals, live refresh.
function bc.journal.tick(player, st)
	local v, info, c = st.v, st.info, st.clim
	if v.water < 45 then bc.hint(player, "thirst") end
	if v.kcal < sim.MAX_KCAL * 0.4 then bc.hint(player, "hunger") end
	if v.rest < 35 then bc.hint(player, "tired") end
	if (info.cold_stress or 0) > 0 or v.core < 36 then bc.hint(player, "cold") end
	if v.wet > 0.4 then bc.hint(player, "wet") end
	if v.core > 38.3 then bc.hint(player, "hot") end
	if st.load > sim.CARRY_COMFORT + 5 then bc.hint(player, "heavy") end
	local tod = core.get_timeofday()
	if tod > 0.7 and tod < 0.78 then bc.hint(player, "night") end
	if bc.is_night(tod) and not st.sleeping and (core.get_node_light(vector.round(vector.add(player:get_pos(), {x = 0, y = 1, z = 0}))) or 15) < 3 then
		bc.hint(player, "dark")
	end

	-- which way is water? Looked for when the journal is open on it, and
	-- pressed on the player once thirst is becoming a problem
	if st.tab == 2 or v.water < 70 then
		local w = bc.water_sense(player, st)
		if v.water < 35 and w and w.pos and not w.near then
			local now = core.get_us_time() / 1e6
			if not st.water_nag or now - st.water_nag > 100 then
				st.water_nag = now
				bc.toast(player, bc.water_text(player, st))
			end
		end
	end

	local days = (bc.clock - st.p.born) / 24
	if days >= 3 then bc.objective(player, "day3") end
	if days >= 10 then bc.objective(player, "day10") end
	local season = bc.season()
	if season == "Winter" and days > 1 then st.p.saw_winter = true end
	if season == "Spring" and st.p.saw_winter then bc.objective(player, "winter") end

	-- discoveries that come from simply living through something
	if st.sleeping and c.shelter and c.shelter.enclosed and c.shelter.volume <= 8
			and c.air and c.outdoor_air and math.abs(c.air - c.outdoor_air) >= 8 then
		bc.learn(player, "small_shelter")
	end
	if c.shelter and c.shelter.enclosed and (c.fire_rise or 0) > 6 and c.shelter.insulation > 0.8 then
		local lit = false
		for _, fp in ipairs(c.shelter.hearths) do
			if core.get_node(fp).name == "bc:campfire" then lit = true; break end
		end
		if not lit then bc.learn(player, "warm_stones") end
	end

	local pinned = bc.recipe_by_id[st.p.pinned_recipe]
	local pool = (pinned or st.tab == 3) and bc.craft_pool(player)
	if st.hud and st.hud.goal then
		local nxt = next_objective(st)
		local text = (nxt and not st.p.hide_goal) and ("Next: " .. nxt[2]) or ""
		if pinned then
			local plan, missing = bc.plan_craft(st, pool, pinned)
			text = bc.item_label(pinned.output) .. "\n" .. (plan and "Materials ready" or ("Gather " .. bc.count_labels(missing)))
		end
		if st.goal_text ~= text then
			st.goal_text = text
			player:hud_change(st.hud.goal, "text", text)
		end
	end

	st.fs_n = (st.fs_n or 0) + 1
	if st.tab == 3 then
		local last = st.recipe_pool or {}
		for item, count in pairs(pool) do if last[item] ~= count then st.fs_dirty = true break end end
		for item in pairs(last) do if not pool[item] then st.fs_dirty = true break end end
	end
	if st.fs_dirty or (st.tab == 2 and st.fs_n % 2 == 0) or (st.tab == 1 and st.fs_n % 3 == 0) then
		bc.journal.refresh(player, st)
	end
end
