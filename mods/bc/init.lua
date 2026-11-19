-- Backcountry: a realistic wilderness survival game for Luanti.
-- Each file below owns one system; util.lua must load first.
local path = core.get_modpath("bc")
for _, file in ipairs({
	"util",      -- namespace, game clock, per-player state
	"sounds",
	"nodes",     -- terrain and water
	"flora",     -- trees, plants, regrowth
	"mapgen",    -- biomes, decorations, spawn
	"water",     -- finding water: for the spawn point and for lost players
	"items",     -- materials and tools
	"food",      -- eating, drinking, spoilage
	"clothing",
	"crafting",  -- recipes and what each player knows
	"climate",   -- weather, temperature, shelter analysis
	"fire",      -- campfires, cooking, torches
	"farming",   -- tilled beds, irrigation and root crops
	"trail",     -- bearings to camp and the last lost pack
	"build",     -- shelter parts, beds, storage, racks
	"campcraft", -- field tools and camp utilities
	"hud",
	"vitals",    -- the per-player survival loop, sleep, death
	"animals",
	"hunting",   -- projectiles, snares, fishing
	"journal",   -- inventory screen, field guide, tips
	"ecology",   -- signs of wildlife and woodland discoveries
	"commands",
}) do
	dofile(path .. "/" .. file .. ".lua")
end
