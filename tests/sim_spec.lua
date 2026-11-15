-- Unit tests for the pure survival simulation. Run from the game folder:
--   luajit tests/sim_spec.lua
local sim = dofile("mods/bc_sim/sim.lua")

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("  ok   " .. name)
	else
		failed = failed + 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end
local function check(cond, msg) if not cond then error(msg or "check failed", 2) end end

-- deterministic RNG so every run is identical
local function make_rng(seed)
	local s = seed or 12345
	return function()
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648
	end
end

local function env(t)
	local e = {activity = "rest", air = 20, wind = 0, wind_block = 0, insulation = 5,
		fire = 0, shelter = 0, sun = 0, precip = 0, load = 5}
	for k, v in pairs(t or {}) do e[k] = v end
	return e
end

-- Run until dead or `hours` pass; returns hours survived.
local function run(v, hours, e, rng, hook)
	local t = 0
	while t < hours do
		local _, events = sim.step(v, 0.5, e, rng)
		t = t + 0.5
		if hook then hook(v, t, e) end
		for _, ev in ipairs(events) do
			if ev.type == "death" then return t, ev.cause end
		end
	end
	return t
end

print("metabolism")
test("a comfortable idle day costs about a day's food and no health", function()
	local v = sim.new_vitals(); v.kcal = 2500; v.water = 100; v.rest = 100
	local rng = make_rng()
	run(v, 16, env(), rng)
	run(v, 8, env{activity = "sleep", bed_quality = 0.85, bed = 3}, rng)
	local burned = 2500 - v.kcal
	check(burned > 1200 and burned < 2200, "burned " .. burned)
	check(v.condition == 100, "condition " .. v.condition)
	check(v.water < 80 and v.water > 40, "water " .. v.water)
end)

test("sprinting burns far more than walking, walking more than resting", function()
	local function burn(act)
		local v = sim.new_vitals(); v.kcal = 2500
		sim.step(v, 1, env{activity = act}, make_rng())
		return 2500 - v.kcal
	end
	check(burn("sprint") > burn("walk") * 2)
	check(burn("walk") > burn("rest") * 1.8)
end)

test("a heavy pack makes walking cost more and slows you", function()
	local light, heavy = sim.new_vitals(), sim.new_vitals()
	sim.step(light, 2, env{activity = "walk", load = 10}, make_rng())
	sim.step(heavy, 2, env{activity = "walk", load = 45}, make_rng())
	check(heavy.kcal < light.kcal - 50)
	check(heavy.rest < light.rest)
	check(sim.load_speed(10) == 1 and sim.load_speed(45) < 0.6 and sim.load_speed(80) >= 0.15)
end)

test("eight hours in a good bed restores rest; a bad bed does not", function()
	local a, b = sim.new_vitals(), sim.new_vitals()
	a.rest, b.rest = 10, 10
	run(a, 8, env{activity = "sleep", bed_quality = 1.0, bed = 6}, make_rng())
	run(b, 8, env{activity = "sleep", bed_quality = 0.4, bed = 0}, make_rng())
	check(a.rest >= 95, "good bed " .. a.rest)
	check(b.rest < 60, "bad bed " .. b.rest)
end)

print("water and food")
test("no water kills in 3 to 7 days at rest", function()
	local v = sim.new_vitals(); v.water = 100
	local rng = make_rng()
	local t = run(v, 24 * 12, env(), rng, function(vv) vv.kcal = 2000; vv.rest = 80 end)
	check(t > 72 and t < 168, "died after " .. t .. " h")
	check(v.cause == "dehydration", tostring(v.cause))
end)

test("no food but water kills slowly: more than 6 days, less than 16", function()
	local v = sim.new_vitals(); v.kcal = 2500
	local t = run(v, 24 * 30, env(), make_rng(), function(vv) vv.water = 90; vv.rest = 80 end)
	check(t > 144 and t < 384, "died after " .. t .. " h")
	check(v.cause == "starvation", tostring(v.cause))
end)

test("health recovers only when fed, watered and warm", function()
	local a = sim.new_vitals(); a.condition = 50
	run(a, 10, env(), make_rng(), function(vv) vv.kcal = 2000; vv.water = 90; vv.rest = 80 end)
	check(a.condition > 58, "fed " .. a.condition)
	local b = sim.new_vitals(); b.condition = 50; b.kcal = 100
	run(b, 10, env(), make_rng(), function(vv) vv.water = 90; vv.rest = 80; vv.kcal = 100 end)
	check(b.condition <= 50, "hungry " .. b.condition)
end)

print("cold")
test("lightly dressed at -10 C in wind: hypothermia within hours, death within a day", function()
	local v = sim.new_vitals(); v.kcal = 2500; v.water = 100
	local e = env{air = -10, wind = 8, insulation = 5}
	local t_hypo
	local t, cause = run(v, 48, e, make_rng(), function(vv, t)
		if not t_hypo and vv.core < 35 then t_hypo = t end
	end)
	check(t_hypo and t_hypo <= 4, "hypothermia at " .. tostring(t_hypo))
	check(t < 24 and cause == "hypothermia", t .. " " .. tostring(cause))
end)

test("the same night is survivable with furs, a shelter and a fire", function()
	local v = sim.new_vitals(); v.kcal = 2500; v.water = 100
	local e = env{air = -10, wind = 8, wind_block = 1, insulation = 24, shelter = 6, fire = 10}
	run(v, 12, e, make_rng())
	check(v.core > 36.5 and v.condition == 100, v.core .. " / " .. v.condition)
end)

test("shivering spends calories before the core cools", function()
	local warm, cool = sim.new_vitals(), sim.new_vitals()
	warm.kcal, cool.kcal = 2500, 2500
	sim.step(warm, 4, env{air = 20}, make_rng())
	local info = sim.step(cool, 4, env{air = 8}, make_rng())   -- felt 13: mild
	check(cool.kcal < warm.kcal - 100, "no extra burn")
	check(cool.core >= 36.9, "core fell " .. cool.core)
	check(info.flags.shivering)
end)

test("being soaked makes cold much worse; wind protection helps", function()
	local dry = sim.felt_temperature(env{air = 5, wind = 6}, {wet = 0})
	local wet = sim.felt_temperature(env{air = 5, wind = 6}, {wet = 1})
	local sheltered = sim.felt_temperature(env{air = 5, wind = 6, wind_block = 1}, {wet = 0})
	check(wet < dry - 8, "wet " .. wet .. " dry " .. dry)
	check(sheltered > dry + 3)
end)

test("rain soaks you unless covered; a fire dries you", function()
	local v = sim.new_vitals()
	sim.step(v, 1.5, env{precip = 1}, make_rng())
	check(v.wet > 0.6, "wet " .. v.wet)
	local c = sim.new_vitals()
	sim.step(c, 1.5, env{precip = 1, rain_cover = 1}, make_rng())
	check(c.wet == 0)
	local before = v.wet
	sim.step(v, 1, env{fire = 10}, make_rng())
	check(v.wet < before - 0.5, "did not dry: " .. v.wet)
end)

test("a cold sleeper wakes before freezing", function()
	local v = sim.new_vitals(); v.rest = 20
	local _, events = sim.step(v, 10, env{activity = "sleep", air = -15, insulation = 5, bed_quality = 0.8, bed = 3}, make_rng())
	local woke
	for _, ev in ipairs(events) do if ev.type == "wake" and ev.reason == "cold" then woke = true end end
	check(woke, "never woke")
	check(v.core > 34.5, "core " .. v.core)
end)

print("heat")
test("desert sun drains water fast; without water you overheat", function()
	local shade, sun = sim.new_vitals(), sim.new_vitals()
	shade.water, sun.water = 100, 100
	sim.step(shade, 4, env{air = 24}, make_rng())
	sim.step(sun, 4, env{air = 40, sun = 1, activity = "walk"}, make_rng())
	check((100 - sun.water) > (100 - shade.water) * 2.5, "sun " .. sun.water .. " shade " .. shade.water)
	local v = sim.new_vitals(); v.water = 0
	local t, cause = run(v, 72, env{air = 42, sun = 1}, make_rng(), function(vv) vv.kcal = 2000; vv.rest = 80 end)
	check(t < 30, "survived " .. t)
	check(cause == "hyperthermia" or cause == "dehydration", tostring(cause))
end)

test("furs in the heat are a liability", function()
	local a = sim.felt_temperature(env{air = 34, insulation = 4}, {wet = 0})
	local b = sim.felt_temperature(env{air = 34, insulation = 26}, {wet = 0})
	check(b > a + 15)
end)

print("afflictions")
test("untreated bleeding costs health and leaves a wound that can infect", function()
	local infected = 0
	for seed = 1, 40 do
		local v = sim.new_vitals(); v.kcal = 2500; v.water = 100
		sim.add_affliction(v, "bleeding")
		local rng = make_rng(seed * 7919)
		sim.step(v, 3.5, env(), rng)
		check(v.condition < 90, "bleeding did no harm")
		check(not v.aff.bleeding and v.aff.wound, "no wound left behind")
		sim.step(v, 30, env(), rng)
		if v.aff.infection then infected = infected + 1 end
	end
	check(infected > 8 and infected < 36, "infected " .. infected .. "/40")
end)

test("a dressed wound never infects; a sprain heals faster at rest", function()
	for seed = 1, 20 do
		local v = sim.new_vitals()
		sim.add_affliction(v, "wound_dressed")
		sim.step(v, 30, env(), make_rng(seed))
		check(not v.aff.infection)
	end
	local a, b = sim.new_vitals(), sim.new_vitals()
	sim.add_affliction(a, "sprain"); sim.add_affliction(b, "sprain")
	local ia = sim.step(a, 5, env{activity = "walk"}, make_rng())
	sim.step(b, 5, env{activity = "rest"}, make_rng())
	check(b.aff.sprain < a.aff.sprain)
	check(ia.speed < 0.7)
end)

test("statuses report the worst problem first", function()
	local v = sim.new_vitals(); v.water = 0; v.kcal = 700; v.core = 34.5
	local info = sim.step(v, 0, env{air = 0}, make_rng())
	local list = sim.statuses(v, info, 10)
	check(list[1].sev == 3 and list[1].key == "thirst", list[1].label)
	local seen = {}
	for _, s in ipairs(list) do seen[s.key] = true end
	check(seen.hypothermia and seen.hunger)
end)

print("climate and weather")
test("seasons, time of day, altitude and caves all move the air temperature", function()
	local function t(o)
		local p = {heat = 50, humidity = 50, y = 10, day = 5, year_len = 40, tod = 0.625}
		for k, val in pairs(o or {}) do p[k] = val end
		return sim.air_temperature(p)
	end
	check(t{day = 5} > t{day = 25} + 12, "summer vs winter")
	check(t{tod = 0.625} > t{tod = 0.125} + 6, "afternoon vs before dawn")
	check(t{y = 150} < t{y = 10} - 6, "altitude")
	check(t{heat = 90} > t{heat = 10} + 25, "biome")
	check(t{day = 25, tod = 0.125, underground = 1} > t{day = 25, tod = 0.125} + 5, "caves are milder on a winter night")
	check(t{day = 5, underground = 1} < t{day = 5} - 3, "caves are cooler in summer")
	check(sim.season(0, 40) == "Summer" and sim.season(12, 40) == "Autumn"
		and sim.season(22, 40) == "Winter" and sim.season(32, 40) == "Spring")
end)

test("weather visits every state and stays in bounds over a long run", function()
	local w, rng, seen, rain = sim.new_weather(), make_rng(99), {}, 0
	for _ = 1, 4000 do
		sim.step_weather(w, 0.5, 0.5, rng)
		seen[w.state] = true
		if sim.WEATHER[w.state].precip > 0 then rain = rain + 1 end
		check(w.wind >= 0 and w.wind <= 18 and math.abs(w.front) <= 7)
	end
	for name in pairs(sim.WEATHER) do check(seen[name], "never saw " .. name) end
	local frac = rain / 4000
	check(frac > 0.05 and frac < 0.45, "precipitation fraction " .. frac)
end)

test("a wet season rains more than a dry one", function()
	local function frac(wetness)
		local w, rng, n = sim.new_weather(), make_rng(5), 0
		for _ = 1, 6000 do
			sim.step_weather(w, 0.5, wetness, rng)
			if sim.WEATHER[w.state].precip > 0 then n = n + 1 end
		end
		return n / 6000
	end
	check(frac(0.9) > frac(0.1) * 1.5)
end)

print("small rules")
test("food keeps in the cold and rots in the heat", function()
	check(sim.spoil_chance(0.7, -5, 24) < 0.03)
	check(sim.spoil_chance(0.7, 15, 24) > 0.4)
	check(sim.spoil_chance(0.7, 32, 24) > sim.spoil_chance(0.7, 15, 24))
end)

test("fish bite best at dawn with bait, worst in an overfished spot", function()
	local dawn = sim.fish_bite_chance{tod = 0.25, bait = true}
	local noon = sim.fish_bite_chance{tod = 0.5}
	local spent = sim.fish_bite_chance{tod = 0.25, bait = true, depletion = 6}
	check(dawn > noon * 3 and spent < dawn * 0.4)
end)

test("fire is hard in the rain, easier with birch bark, a striker and practice", function()
	local base = sim.fire_chance{method = "drill", tinder = "grass"}
	check(sim.fire_chance{method = "drill", tinder = "grass", precip = 1} < base * 0.5)
	check(sim.fire_chance{method = "drill", tinder = "bark", precip = 1} > sim.fire_chance{method = "drill", tinder = "grass", precip = 1} * 2)
	check(sim.fire_chance{method = "striker", tinder = "grass"} > base * 2)
	check(sim.fire_chance{method = "drill", tinder = "grass", skill = 1} > base + 0.3)
end)

test("sneaking downwind gets you far closer to game than sprinting upwind", function()
	local stalk = sim.detect_multiplier{sneaking = true, downwind = true}
	local blunder = sim.detect_multiplier{sprinting = true, upwind = true, moving = true}
	check(stalk < 0.4 and blunder > 1.7)
end)

print("whole runs")
-- A scripted survivor: a full "match" played through the rules with no engine.
local function survivor(days, careful, seed)
	local v, rng = sim.new_vitals(), make_rng(seed)
	local year = 40
	for hour = 0, days * 24 - 1 do
		local tod = (hour % 24) / 24
		local air = sim.air_temperature{heat = 45, humidity = 60, y = 12, day = hour / 24, year_len = year, tod = tod}
		local night = tod < 0.25 or tod > 0.8
		-- the careful one dresses for the weather and only lights a fire when it is needed
		local e = env{air = air, wind = 4, insulation = careful and sim.clamp(20 - air, 3, 26) or 5}
		if night then
			e.activity = "sleep"
			if careful then
				e.wind_block, e.bed_quality, e.bed = 1, 0.85, 3
				e.shelter = air < 14 and 8 or 0
				e.fire = air < 2 and 8 or 0
			else
				e.bed_quality, e.bed = 0.4, 0
			end
		else
			e.activity = (hour % 3 == 0) and "rest" or "walk"
		end
		local _, events = sim.step(v, 1, e, rng)
		for _, ev in ipairs(events) do
			if ev.type == "death" then return false, hour / 24, ev.cause end
		end
		if careful and not night then
			if v.water < 60 then v.water = math.min(100, v.water + 35) end            -- boiled water
			if v.kcal < 1200 then v.kcal = math.min(sim.MAX_KCAL, v.kcal + 900) end   -- a cooked meal
		elseif not careful and not night and hour % 24 == 12 then
			v.water = math.min(100, v.water + 20)                                     -- a gulp of pond water
			if rng() < 0.3 then sim.add_affliction(v, "dysentery") end
		end
	end
	return true, days, nil, v
end

test("a careful survivor lasts a full year, winter included", function()
	local ok, d, cause, v = survivor(40, true, 1)
	check(ok, "died on day " .. tostring(d) .. " of " .. tostring(cause))
	check(v.condition > 80, "condition " .. v.condition)
end)

test("a careless one does not see the winter out", function()
	for seed = 1, 5 do
		local ok, d = survivor(40, false, seed)
		check(not ok, "careless survivor lived")
		check(d > 1, "died implausibly fast: day " .. d)
	end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
