-- Backcountry survival simulation. Pure Lua: no engine calls, so every rule
-- here can be exercised from a plain `luajit` test run (see tests/).
-- All rates are per in-game hour. Temperatures are degrees Celsius.

local sim = {}

sim.MAX_KCAL = 2500      -- energy you can hold "in the tank"
sim.COMFORT_LOW = 16     -- felt temperature below which the body must work to stay warm
sim.COMFORT_HIGH = 29    -- felt temperature above which the body must sweat
sim.CARRY_COMFORT = 20   -- kg carried before it starts to cost you
sim.CARRY_MAX = 55       -- kg at which you can barely move

local function clamp(x, lo, hi)
	if x < lo then return lo end
	if x > hi then return hi end
	return x
end
sim.clamp = clamp

-- kcal burned, water lost (% of full), rest change, body heat produced
sim.ACTIVITY = {
	sleep  = {kcal = 50,  water = 1.0, rest = 12.5, heat = -1},
	rest   = {kcal = 70,  water = 1.6, rest = -4.5, heat = 0},
	walk   = {kcal = 170, water = 2.4, rest = -6.0, heat = 3},
	sprint = {kcal = 460, water = 4.6, rest = -15,  heat = 7},
	swim   = {kcal = 400, water = 2.0, rest = -11,  heat = 1},
}

-- cond/water/kcal/rest are per-hour effects while the affliction lasts.
sim.AFF = {
	bleeding = {name = "Bleeding", dur = 3, cond = -6, bad = true,
		help = "Bandage it. A poultice of the right herb also works."},
	wound = {name = "Open wound", dur = 24, infect = 0.035,
		help = "Undressed wounds can turn septic. Keep it clean and dressed."},
	wound_dressed = {name = "Dressed wound", dur = 16,
		help = "Healing cleanly."},
	infection = {name = "Infection", dur = 40, cond = -1.3, rest = -1.5, fever = 1.2, bad = true,
		help = "Rest, drink, eat. The old woods have something that fights rot."},
	sprain = {name = "Sprained ankle", dur = 14, speed = 0.65,
		help = "Stay off it. Rest and sleep heal it faster."},
	food_poisoning = {name = "Food poisoning", dur = 9, cond = -1.2, water = -4, kcal = -50, rest = -2, bad = true,
		help = "Drink clean water and rest. Something from a dead fire can settle it."},
	dysentery = {name = "Dysentery", dur = 16, cond = -0.8, water = -5, rest = -1.5, bad = true,
		help = "Bad water. Drink boiled water and rest until it passes."},
	toxin = {name = "Poisoned", dur = 7, cond = -7, water = -3, rest = -3, bad = true,
		help = "Something you ate was poisonous. Drink, rest and hope."},
	nausea = {name = "Nausea", dur = 2, water = -2,
		help = "It will pass."},
}

function sim.new_vitals()
	return {
		condition = 100,  -- overall health, 0 = dead
		kcal = 1700,
		water = 85,       -- percent hydrated
		rest = 90,        -- percent rested
		core = 37.0,      -- core body temperature
		wet = 0,          -- 0 dry .. 1 soaked
		aff = {},         -- affliction name -> hours remaining
	}
end

function sim.add_affliction(v, name, hours)
	local def = sim.AFF[name]
	if not def then return false end
	local dur = hours or def.dur
	if not v.aff[name] or v.aff[name] < dur then v.aff[name] = dur end
	return true
end

function sim.cure(v, name)
	if v.aff[name] then v.aff[name] = nil; return true end
	return false
end

-- What the air feels like on the skin, with a labelled breakdown for the UI.
-- e: air, wind (m/s), wind_block (0..1), insulation (deg C of clothing),
--    fire, shelter, sun (0..1), bed (deg C, only while sleeping), activity
function sim.felt_temperature(e, v)
	local act = sim.ACTIVITY[e.activity] or sim.ACTIVITY.rest
	local wet = v and v.wet or 0
	local parts = {}
	local total = e.air or 15
	parts[#parts + 1] = {"Air", e.air or 15}
	local function add(label, val)
		if val and math.abs(val) >= 0.05 then
			parts[#parts + 1] = {label, val}
			total = total + val
		end
	end
	local exposed = 1 - clamp(e.wind_block or 0, 0, 1)
	local chill_scale = clamp((30 - (e.air or 15)) / 15, 0, 1)
	add("Wind", -math.min(14, (e.wind or 0) * 0.8) * exposed * chill_scale)
	add("Wet", -wet * 7)
	add("Clothing", (e.insulation or 0) * (1 - 0.6 * wet))
	add("Fire", e.fire)
	add("Shelter", e.shelter)
	add("Sun", (e.sun or 0) * 4)
	add("Exertion", act.heat)
	if e.activity == "sleep" then add("Bedding", e.bed) end
	return total, parts
end

local function step_once(v, h, e, rng, events)
	local act = sim.ACTIVITY[e.activity] or sim.ACTIVITY.rest
	local sleeping = e.activity == "sleep"
	local info = {rates = {}, flags = {}}
	local dmg = {}

	-- afflictions -----------------------------------------------------
	local a_cond, a_water, a_kcal, a_rest, fever, speed = 0, 0, 0, 0, 0, 1
	for name, left in pairs(v.aff) do
		local def = sim.AFF[name]
		if not def then
			v.aff[name] = nil
		else
			if def.cond then a_cond = a_cond + def.cond; dmg[name] = -def.cond end
			a_water = a_water + (def.water or 0)
			a_kcal = a_kcal + (def.kcal or 0)
			a_rest = a_rest + (def.rest or 0)
			fever = fever + (def.fever or 0)
			if def.speed then speed = speed * def.speed end
			local decay = h
			if name == "sprain" and (sleeping or e.activity == "rest") then decay = h * 2 end
			if def.infect and h > 0 and rng() < def.infect * h and not v.aff.infection then
				v.aff.infection = sim.AFF.infection.dur
				events[#events + 1] = {type = "aff_start", name = "infection"}
			end
			left = left - decay
			if left <= 0 then
				v.aff[name] = nil
				events[#events + 1] = {type = "aff_end", name = name}
				if name == "bleeding" then
					-- the bleeding stopped by itself, but the wound is still open
					sim.add_affliction(v, "wound")
				end
			else
				v.aff[name] = left
			end
		end
	end
	info.speed = speed

	-- load ------------------------------------------------------------
	local load = e.load or 0
	local load_mult = 1
	if e.activity == "walk" or e.activity == "sprint" or e.activity == "swim" then
		load_mult = 1 + math.max(0, load - sim.CARRY_COMFORT) / 35
	end

	-- temperature -----------------------------------------------------
	local felt, parts = sim.felt_temperature(e, v)
	info.felt, info.parts = felt, parts
	local kcal_rate = -act.kcal * load_mult + a_kcal
	local water_rate = -act.water + a_water
	local core_rate = 0
	local target = 37 + fever
	local cold_stress = 0

	if felt < sim.COMFORT_LOW then
		local deficit = sim.COMFORT_LOW - felt
		local cap = v.kcal > 0 and 6 or 2      -- shivering needs fuel
		local comp = math.min(deficit, cap)
		kcal_rate = kcal_rate - comp * 16
		cold_stress = deficit - comp
		info.deficit = deficit
		info.flags.shivering = comp > 1.5
		if cold_stress > 0 then
			core_rate = -cold_stress * 0.07
		elseif v.core < target then
			core_rate = 0.25
		end
	elseif felt > sim.COMFORT_HIGH then
		local surplus = felt - sim.COMFORT_HIGH
		local cap = v.water > 0 and 8 or 2     -- sweating needs water
		local comp = math.min(surplus, cap)
		water_rate = water_rate - comp * 0.6
		local over = surplus - comp
		info.surplus = surplus
		info.flags.sweating = comp > 1
		if over > 0 then
			core_rate = over * 0.08
		elseif v.core > target then
			core_rate = -0.25
		end
	end
	if core_rate == 0 then
		if v.core < target then
			core_rate = math.min(2.5, 0.8 + 0.15 * (felt - sim.COMFORT_LOW))
		elseif v.core > target then
			core_rate = -math.min(2.5, 1.0 + 0.1 * (sim.COMFORT_HIGH - felt))
		end
	end

	-- wetness ---------------------------------------------------------
	local wet_rate
	if e.in_water then
		v.wet = 1
		wet_rate = 0
	else
		wet_rate = (e.precip or 0) * 0.6 * (1 - clamp(e.rain_cover or 0, 0, 1))
		if wet_rate <= 0 then
			wet_rate = -(0.25 + (e.fire or 0) * 0.08 + math.max(0, (e.air or 15) - 15) * 0.02 + (e.sun or 0) * 0.2)
		end
	end

	-- rest ------------------------------------------------------------
	local rest_rate
	if sleeping then
		rest_rate = act.rest * (e.bed_quality or 0.5)
		if cold_stress > 0 then rest_rate = rest_rate * 0.5 end
	else
		rest_rate = act.rest * load_mult
		if v.kcal <= 0 then rest_rate = rest_rate * 1.3 end
		if v.core < 35 then rest_rate = rest_rate * 1.5 end
	end
	rest_rate = rest_rate + a_rest

	-- condition -------------------------------------------------------
	if v.kcal <= 0 then dmg.starvation = 0.6 end
	if v.water <= 0 then dmg.dehydration = 2.2 end
	if v.rest <= 0 then dmg.exhaustion = 0.8 end
	local c = v.core
	if c < 29 then dmg.hypothermia = 40
	elseif c < 31 then dmg.hypothermia = 15
	elseif c < 33 then dmg.hypothermia = 5
	elseif c < 35 then dmg.hypothermia = 1.5 end
	if c > 41.5 then dmg.hyperthermia = 50
	elseif c > 40.8 then dmg.hyperthermia = 20
	elseif c > 39.8 then dmg.hyperthermia = 6
	elseif c > 38.8 then dmg.hyperthermia = 1.5 end

	local total_dmg, worst, worst_amt = 0, nil, 0
	for cause, amt in pairs(dmg) do
		total_dmg = total_dmg + amt
		if amt > worst_amt then worst, worst_amt = cause, amt end
	end
	local cond_rate = -total_dmg
	if total_dmg == 0 and v.kcal > sim.MAX_KCAL * 0.25 and v.water > 25
			and (v.rest > 10 or sleeping) and c > 35.5 and c < 38.5 then
		cond_rate = sleeping and 2.0 or 1.0
	end
	if worst then v.cause = worst end

	-- integrate -------------------------------------------------------
	if h > 0 then
		v.kcal = clamp(v.kcal + kcal_rate * h, 0, sim.MAX_KCAL)
		v.water = clamp(v.water + water_rate * h, 0, 100)
		v.rest = clamp(v.rest + rest_rate * h, 0, 100)
		v.wet = clamp(v.wet + wet_rate * h, 0, 1)
		local nc = v.core + core_rate * h
		-- do not overshoot the set point while recovering
		if (v.core < target and nc > target and felt <= sim.COMFORT_HIGH + 8)
				or (v.core > target and nc < target and felt >= sim.COMFORT_LOW - 6) then
			nc = target
		end
		v.core = clamp(nc, 24, 44)
		v.condition = clamp(v.condition + cond_rate * h, 0, 100)
	end

	info.rates.kcal = kcal_rate
	info.rates.water = water_rate
	info.rates.rest = rest_rate
	info.rates.core = core_rate
	info.rates.condition = cond_rate
	info.rates.wet = wet_rate
	info.cold_stress = cold_stress
	info.damage = dmg
	return info
end

-- Advance one person's body by dt hours in environment e.
-- Returns info (rates and the felt-temperature breakdown) and a list of events.
function sim.step(v, dt, e, rng)
	rng = rng or math.random
	local events = {}
	local info
	local left = math.max(0, dt)
	if left == 0 then
		info = step_once(v, 0, e, rng, events)
	end
	while left > 1e-9 do
		local h = math.min(left, 0.1)
		info = step_once(v, h, e, rng, events)
		left = left - h
		if v.condition <= 0 then
			events[#events + 1] = {type = "death", cause = v.cause or "exposure"}
			break
		end
		if e.activity == "sleep" then
			if v.core < 35.2 then
				events[#events + 1] = {type = "wake", reason = "cold"}
				break
			elseif v.rest >= 100 then
				events[#events + 1] = {type = "wake", reason = "rested"}
				break
			end
		end
	end
	return info, events
end

-- Labelled status list for the HUD, worst first. sev: 1 note, 2 warning, 3 danger.
function sim.statuses(v, info, load)
	local out = {}
	local function add(key, label, sev) out[#out + 1] = {key = key, label = label, sev = sev} end
	local c = v.core
	if c < 31 then add("hypothermia", "Severe hypothermia", 3)
	elseif c < 33 then add("hypothermia", "Hypothermia", 3)
	elseif c < 35 then add("hypothermia", "Mild hypothermia", 2)
	elseif info and (info.cold_stress or 0) > 0 then add("cold", "Losing body heat", 2)
	elseif info and info.flags.shivering then add("cold", "Shivering", 1) end
	if c > 40.8 then add("heat", "Heat stroke", 3)
	elseif c > 39.8 then add("heat", "Heat exhaustion", 3)
	elseif c > 38.8 then add("heat", "Overheating", 2)
	elseif info and info.flags.sweating then add("heat", "Sweating", 1) end
	if v.water <= 0 then add("thirst", "Dehydrated", 3)
	elseif v.water < 20 then add("thirst", "Very thirsty", 2)
	elseif v.water < 40 then add("thirst", "Thirsty", 1) end
	if v.kcal <= 0 then add("hunger", "Starving", 3)
	elseif v.kcal < sim.MAX_KCAL * 0.15 then add("hunger", "Very hungry", 2)
	elseif v.kcal < sim.MAX_KCAL * 0.35 then add("hunger", "Hungry", 1) end
	if v.rest <= 0 then add("tired", "Exhausted", 3)
	elseif v.rest < 15 then add("tired", "Very tired", 2)
	elseif v.rest < 35 then add("tired", "Tired", 1) end
	if v.wet > 0.6 then add("wet", "Soaked", 2)
	elseif v.wet > 0.2 then add("wet", "Damp", 1) end
	for name in pairs(v.aff) do
		local def = sim.AFF[name]
		if def then add(name, def.name, def.bad and 3 or 1) end
	end
	if load and load > sim.CARRY_COMFORT + 10 then
		add("load", load > sim.CARRY_MAX - 10 and "Overloaded" or "Heavy pack", load > sim.CARRY_MAX - 10 and 2 or 1)
	end
	table.sort(out, function(a, b)
		if a.sev ~= b.sev then return a.sev > b.sev end
		return a.label < b.label
	end)
	return out
end

-- Movement speed multiplier from carried weight.
function sim.load_speed(load)
	if load <= sim.CARRY_COMFORT then return 1 end
	return clamp(1 - (load - sim.CARRY_COMFORT) / (sim.CARRY_MAX - sim.CARRY_COMFORT) * 0.85, 0.15, 1)
end

-- ---------------------------------------------------------------------
-- Calendar and climate
-- ---------------------------------------------------------------------

local SEASONS = {"Winter", "Spring", "Summer", "Autumn"}

-- day: fractional days since the world began. A new world starts on the
-- first day of summer. Returns season name, year fraction (0 = midwinter).
function sim.season(day, year_len)
	local yf = (day / year_len + 0.375) % 1
	local idx = math.floor(((yf + 0.125) % 1) * 4) + 1
	return SEASONS[idx], yf
end

-- p: heat, humidity (engine biome noise, roughly 0..100), y (altitude),
--    day, year_len, tod (0..1), front (weather offset), cloud (0..1),
--    precip (0..2), underground (0..1)
function sim.air_temperature(p)
	local heat = p.heat or 50
	local humidity = p.humidity or 50
	local mean = -12 + heat * 0.45
	local _, yf = sim.season(p.day or 0, p.year_len or 40)
	local season_amp = 15 - heat * 0.09
	local seasonal = -season_amp * math.cos(2 * math.pi * yf)
	local diurnal_amp = (4 + (100 - clamp(humidity, 0, 100)) * 0.06) * (1 - 0.5 * (p.cloud or 0))
	local diurnal = diurnal_amp * math.cos(2 * math.pi * ((p.tod or 0.5) - 0.625))
	local altitude = -math.max(0, (p.y or 0) - 20) * 0.06
	local surface = mean + seasonal + diurnal + altitude + (p.front or 0) - (p.precip or 0) * 1.5
	local ug = clamp(p.underground or 0, 0, 1)
	-- deep rock holds close to the yearly average
	local deep = mean + altitude + seasonal * 0.25
	return surface * (1 - ug) + deep * ug
end

-- ---------------------------------------------------------------------
-- Weather: one front system for the whole world, a small Markov chain.
-- ---------------------------------------------------------------------

sim.WEATHER = {
	clear    = {label = "Clear",    dur = 14,  wind = 2.0,  cloud = 0.1, precip = 0, next = {cloudy = 1}},
	cloudy   = {label = "Cloudy",   dur = 8,   wind = 3.5,  cloud = 0.5, precip = 0, next = {clear = 1.2, overcast = 1}},
	overcast = {label = "Overcast", dur = 6,   wind = 4.5,  cloud = 0.9, precip = 0, next = {cloudy = 1, rain = {1.2}, storm = {0.25}}},
	rain     = {label = "Rain",     dur = 4,   wind = 5.5,  cloud = 1.0, precip = 1, next = {overcast = 1.5, cloudy = 0.5, storm = {0.4}}},
	storm    = {label = "Storm",    dur = 2.5, wind = 11.0, cloud = 1.0, precip = 2, next = {rain = 1.5, overcast = 1}},
}

function sim.new_weather()
	return {state = "clear", left = 8, wind = 2, wind_dir = 0, front = 0}
end

-- wetness: 0 (arid season) .. 1 (wet season); scales how often it rains.
function sim.step_weather(w, dt, wetness, rng)
	rng = rng or math.random
	wetness = wetness or 0.5
	local left = dt
	while left > 1e-9 do
		local h = math.min(left, 0.25)
		left = left - h
		w.left = w.left - h
		if w.left <= 0 then
			local def = sim.WEATHER[w.state] or sim.WEATHER.clear
			local total, opts = 0, {}
			for name, wt in pairs(def.next) do
				if type(wt) == "table" then wt = wt[1] * (0.3 + 1.4 * wetness) end
				total = total + wt
				opts[#opts + 1] = {name, wt}
			end
			table.sort(opts, function(a, b) return a[1] < b[1] end)
			local r, pick = rng() * total, opts[1][1]
			for _, o in ipairs(opts) do
				r = r - o[2]
				if r <= 0 then pick = o[1]; break end
			end
			w.state = pick
			w.left = sim.WEATHER[pick].dur * (0.5 + rng())
		end
		local def = sim.WEATHER[w.state]
		w.wind = clamp(w.wind + (def.wind - w.wind) * 0.5 * h + (rng() - 0.5) * 2.4 * h, 0, 18)
		w.wind_dir = (w.wind_dir + (rng() - 0.5) * 0.5 * h) % (2 * math.pi)
		w.front = clamp(w.front + (-w.front * 0.02 + (rng() - 0.5) * 1.3) * h, -7, 7)
	end
	return w
end

-- ---------------------------------------------------------------------
-- Small rule helpers shared by several systems
-- ---------------------------------------------------------------------

-- Chance that one item with a spoil rate (per day at mild temperature)
-- goes off during dt hours at the given storage temperature.
function sim.spoil_chance(rate, temp, dt)
	local mult
	if temp <= 0 then mult = 0.02
	elseif temp < 10 then mult = 0.3
	elseif temp < 20 then mult = 1
	elseif temp < 30 then mult = 2
	else mult = 3 end
	return 1 - math.exp(-rate * mult * dt / 24)
end

-- Chance per check (a few seconds of waiting) that a fish takes the hook.
-- o: tod, weather, bait (bool), depletion (recent catches here), river (bool), season
function sim.fish_bite_chance(o)
	local c = 0.07
	local tod = o.tod or 0.5
	if (tod > 0.19 and tod < 0.31) or (tod > 0.72 and tod < 0.84) then c = c * 1.8
	elseif tod > 0.4 and tod < 0.6 then c = c * 0.7
	elseif tod < 0.19 or tod > 0.84 then c = c * 0.5 end
	if o.weather == "overcast" or o.weather == "rain" then c = c * 1.3
	elseif o.weather == "storm" then c = c * 0.6 end
	if o.bait then c = c * 2.2 end
	if o.river then c = c * 1.15 end
	if o.season == "Winter" then c = c * 0.7 end
	c = c / (1 + (o.depletion or 0) * 0.6)
	return clamp(c, 0.004, 0.5)
end

-- Chance one attempt at fire-making takes.
-- o: method ("drill"|"striker"), tinder ("bark"|"lichen"|"grass"),
--    precip (0..2 falling on the fire lay), wind (m/s reaching it),
--    skill (0..1), core (body temperature)
function sim.fire_chance(o)
	local c = o.method == "striker" and 0.5 or 0.2
	if o.tinder == "bark" then c = c * 1.4
	elseif o.tinder == "lichen" then c = c * 1.15 end
	local precip = o.precip or 0
	if precip > 0 then
		local wet = precip >= 2 and 0.12 or 0.3
		if o.tinder == "bark" then wet = wet * 2.2 end   -- birch bark burns wet
		c = c * wet
	end
	if (o.wind or 0) > 6 then c = c * 0.6 end
	c = c + (o.skill or 0) * 0.35
	if (o.core or 37) < 35.5 then c = c * 0.7 end        -- numb hands
	return clamp(c, 0.02, 0.95)
end

-- How far (as a multiplier on its senses) an animal can notice a person.
-- o: sneaking, moving, sprinting, night, upwind (person is upwind of the
--    animal, so their scent carries to it), downwind, scent (carrying raw meat)
function sim.detect_multiplier(o)
	local m = 1
	if o.sneaking then m = m * 0.45
	elseif o.sprinting then m = m * 1.4
	elseif not o.moving then m = m * 0.8 end
	if o.night then m = m * 0.8 end
	if o.upwind then m = m * 1.35 elseif o.downwind then m = m * 0.75 end
	if o.scent then m = m * 1.3 end
	return m
end

return sim
