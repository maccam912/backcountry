-- Operator tools, mostly for testing and for rescuing a stuck game.
local sim = bc.sim

core.register_chatcommand("bc", {
	params = "info | set <condition|kcal|water|rest|core|wet> <n> | weather <clear|cloudy|overcast|rain|storm> | wind <m/s> | day <n> | afflict <name> | cure | spawn <animal> | reset",
	description = "Backcountry operator commands",
	privs = {server = true},
	func = function(name, param)
		local player = core.get_player_by_name(name)
		local st = bc.state(name)
		if not player or not st then return false, "Not in game." end
		local args = param:split(" ")
		local cmd = args[1]
		if cmd == "info" or not cmd then
			local c = st.clim
			return true, string.format("day %.2f (%s)  weather %s wind %.1f front %.1f  air %.1f felt %.1f  shelter %s vol %d insul %.2f  fire %.1f  biome %s",
				bc.clock / 24, (bc.season()), bc.weather.state, bc.weather.wind, bc.weather.front, c.air or 0, st.info and st.info.felt or 0,
				tostring(c.shelter and c.shelter.enclosed), c.shelter and c.shelter.volume or 0, c.shelter and c.shelter.insulation or 0,
				c.fire or 0, tostring(c.biome))
		elseif cmd == "set" and st.v[args[2] or ""] ~= nil and tonumber(args[3]) then
			st.v[args[2]] = tonumber(args[3])
			return true, args[2] .. " = " .. args[3]
		elseif cmd == "weather" and sim.WEATHER[args[2] or ""] then
			bc.weather.state = args[2]
			bc.weather.left = 6
			bc.weather.wind = sim.WEATHER[args[2]].wind
			return true, "Weather: " .. args[2]
		elseif cmd == "wind" and tonumber(args[2]) then
			bc.weather.wind = tonumber(args[2])
			return true, "Wind set."
		elseif cmd == "day" and tonumber(args[2]) then
			bc.clock = (tonumber(args[2]) - 1) * 24 + core.get_timeofday() * 24
			return true, "It is now day " .. bc.day() .. ", " .. (bc.season())
		elseif cmd == "afflict" and sim.AFF[args[2] or ""] then
			sim.add_affliction(st.v, args[2])
			return true, "Afflicted with " .. args[2]
		elseif cmd == "cure" then
			st.v.aff = {}
			return true, "Cured."
		elseif cmd == "spawn" and bc.animals[args[2] or ""] then
			local pos = vector.add(player:get_pos(), vector.multiply(player:get_look_dir(), 6))
			pos.y = player:get_pos().y + 1
			bc.spawn_animal(args[2], pos)
			return true, "Spawned " .. args[2]
		elseif cmd == "reset" then
			st.p.v = bc.new_life()
			st.v = st.p.v
			return true, "Vitals reset."
		end
		return false, "Usage: /bc " .. "info | set <vital> <n> | weather <state> | wind <n> | day <n> | afflict <name> | cure | spawn <animal> | reset"
	end,
})
