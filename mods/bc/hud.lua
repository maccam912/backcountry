-- On-screen readouts: five vitals bottom-left, surroundings and problems
-- top-right, and short messages ("toasts") top-centre.
local sim = bc.sim
bc.hud = {}

local BAR_W, BAR_H = 120, 8
local ROWS = {
	{key = "condition", icon = "bc_hud_health.png", color = "#c94a3d"},
	{key = "core", icon = "bc_hud_temp.png", color = "#e08a2e"},
	{key = "kcal", icon = "bc_hud_food.png", color = "#d2b13a"},
	{key = "water", icon = "bc_hud_water.png", color = "#4a9bd8"},
	{key = "rest", icon = "bc_hud_rest.png", color = "#9a78c8"},
}
local SEV_COLOR = {0xcfcfcf, 0xf0b040, 0xff5a4a}

local function fill_texture(color)
	return "bc_white.png^[multiply:" .. color
end

function bc.hud.init(player, st)
	local ids = {rows = {}}
	for i, row in ipairs(ROWS) do
		local y = -(#ROWS - i) * 24 - 96
		ids.rows[i] = {
			icon = player:hud_add({type = "image", position = {x = 0, y = 1}, offset = {x = 26, y = y},
				text = row.icon, scale = {x = 1.25, y = 1.25}, alignment = {x = 0, y = 0}}),
			bg = player:hud_add({type = "image", position = {x = 0, y = 1}, offset = {x = 44, y = y},
				text = "bc_white.png^[multiply:#101010^[opacity:150", scale = {x = BAR_W + 4, y = BAR_H + 4},
				alignment = {x = 1, y = 0}}),
			fill = player:hud_add({type = "image", position = {x = 0, y = 1}, offset = {x = 46, y = y},
				text = fill_texture(row.color), scale = {x = BAR_W, y = BAR_H}, alignment = {x = 1, y = 0}}),
			text = player:hud_add({type = "text", position = {x = 0, y = 1}, offset = {x = 58 + BAR_W, y = y},
				text = "", number = 0xe8e8e8, alignment = {x = 1, y = 0}}),
		}
	end
	-- dark backing so the readout stays legible against a bright sky
	ids.back = player:hud_add({type = "image", position = {x = 1, y = 0}, offset = {x = -6, y = 6},
		text = "bc_white.png^[multiply:#101410^[opacity:120", scale = {x = 330, y = 76}, alignment = {x = -1, y = 1}})
	ids.where = player:hud_add({type = "text", position = {x = 1, y = 0}, offset = {x = -16, y = 14},
		text = "", number = 0xe8e8e8, alignment = {x = -1, y = 1}})
	ids.status = player:hud_add({type = "text", position = {x = 1, y = 0}, offset = {x = -16, y = 88},
		text = "", number = 0xffffff, alignment = {x = -1, y = 1}})
	ids.toast = player:hud_add({type = "text", position = {x = 0.5, y = 0.16}, offset = {x = 0, y = 0},
		text = "", number = 0xfff2c8, alignment = {x = 0, y = 0}, size = {x = 1.2, y = 0}})
	ids.goal = player:hud_add({type = "text", position = {x = 0, y = 1}, offset = {x = 16, y = -(#ROWS * 24 + 96)},
		text = "", number = 0xc8d8b0, alignment = {x = 1, y = 0}})
	st.hud = ids
	st.hud_cache = {}
	st.toasts = {}
end

local function change(player, st, id, field, value)
	local key = id .. field
	if st.hud_cache[key] == value then return end
	st.hud_cache[key] = value
	player:hud_change(id, field, value)
end

local function trend(rate, eps)
	if rate > eps then return " rising" end
	if rate < -eps then return " falling" end
	return ""
end

function bc.hud.update(player, st)
	local ids, v, info = st.hud, st.v, st.info
	if not ids or not info then return end
	local values = {
		condition = {v.condition / 100, string.format("%d%%", math.ceil(v.condition))},
		kcal = {v.kcal / sim.MAX_KCAL, string.format("%d kcal", math.floor(v.kcal))},
		water = {v.water / 100, string.format("%d%%", math.ceil(v.water))},
		rest = {v.rest / 100, string.format("%d%%", math.ceil(v.rest))},
	}
	local hot = v.core > 38.2
	values.core = {hot and 1 or sim.clamp((v.core - 31) / 6, 0, 1),
		bc.temp(st, v.core, 1) .. trend(info.rates.core, 0.08)}
	for i, row in ipairs(ROWS) do
		local frac, text = values[row.key][1], values[row.key][2]
		local color = row.color
		if frac < 0.2 or (row.key == "core" and (hot or v.core < 35)) then color = "#ff4a3a" end
		local r = ids.rows[i]
		change(player, st, r.fill, "text", fill_texture(color))
		player:hud_change(r.fill, "scale", {x = math.max(0.01, frac * BAR_W), y = BAR_H})
		change(player, st, r.text, "text", text)
	end

	local c = st.clim
	local w = bc.weather
	local sky = sim.WEATHER[w.state].label
	if c.precip_kind == "snow" then sky = w.state == "storm" and "Blizzard" or "Snow" end
	if (c.humidity or 50) < 22 and c.precip_kind == nil and sim.WEATHER[w.state].precip > 0 then sky = "Overcast" end
	local wind_from = bc.compass(vector.multiply(bc.climate.wind_vector(), -1))
	local wind = bc.climate.wind_name(w.wind)
	if w.wind >= 1 then wind = wind .. " from the " .. wind_from end
	local where = string.format("Day %d, %s - %s\nAir %s, feels %s\n%s. %s",
		bc.day(), (bc.season()), bc.time_name(), bc.temp(st, c.air or 0), bc.temp(st, info.felt or 0), sky, wind)
	change(player, st, ids.where, "text", where)

	local list = sim.statuses(v, info, st.load)
	local lines, worst = {}, 1
	for i, s in ipairs(list) do
		if i > 6 then break end
		lines[#lines + 1] = s.label
		if s.sev > worst then worst = s.sev end
	end
	change(player, st, ids.status, "text", table.concat(lines, "\n"))
	local back_h = 76 + (#lines > 0 and (#lines * 22 + 12) or 0)
	if st.hud_cache.back_h ~= back_h then
		st.hud_cache.back_h = back_h
		player:hud_change(ids.back, "scale", {x = 330, y = back_h})
	end
	change(player, st, ids.status, "number", SEV_COLOR[worst])
	st.statuses = list
end

-- Short message near the top of the screen. Messages queue.
function bc.toast(player, text)
	local st = bc.state(player)
	if not st or not st.hud then
		bc.tell(player, text)
		return
	end
	if st.toast_text == text or st.toasts[#st.toasts] == text then return end
	st.toasts[#st.toasts + 1] = text
end

local t = 0
core.register_globalstep(function(dtime)
	t = t + dtime
	if t < 0.25 then return end
	local step = t
	t = 0
	for _, player in ipairs(core.get_connected_players()) do
		local st = bc.state(player)
		if st and st.hud then
			if st.toast_left then
				st.toast_left = st.toast_left - step
				if st.toast_left <= 0 then
					st.toast_left, st.toast_text = nil, nil
					player:hud_change(st.hud.toast, "text", "")
				end
			end
			if not st.toast_left and #st.toasts > 0 then
				local text = table.remove(st.toasts, 1)
				st.toast_text = text
				st.toast_left = math.max(3.5, math.min(9, #text * 0.07))
				if #st.toasts > 2 then st.toast_left = 2.5 end
				player:hud_change(st.hud.toast, "text", text)
			end
		end
	end
end)

-- Darken the screen while asleep.
function bc.hud.sleep(player, st, text)
	if text then
		if not st.hud_sleep then
			st.hud_sleep = {
				shade = player:hud_add({type = "image", position = {x = 0.5, y = 0.5}, scale = {x = -100, y = -100},
					text = "bc_white.png^[multiply:#000000^[opacity:215", alignment = {x = 0, y = 0}, z_index = -200}),
				text = player:hud_add({type = "text", position = {x = 0.5, y = 0.45}, text = "", number = 0xd8d8e8,
					alignment = {x = 0, y = 0}, size = {x = 1.3, y = 0}, z_index = -199}),
			}
		end
		player:hud_change(st.hud_sleep.text, "text", text)
	elseif st.hud_sleep then
		player:hud_remove(st.hud_sleep.shade)
		player:hud_remove(st.hud_sleep.text)
		st.hud_sleep = nil
	end
end

-- Brief red flash when hurt.
function bc.hud.flash(player, st)
	if st.hud_flash then return end
	st.hud_flash = player:hud_add({type = "image", position = {x = 0.5, y = 0.5}, scale = {x = -100, y = -100},
		text = "bc_white.png^[multiply:#a00000^[opacity:70", alignment = {x = 0, y = 0}, z_index = -150})
	core.after(0.35, function()
		if player:is_player() and st.hud_flash then
			player:hud_remove(st.hud_flash)
			st.hud_flash = nil
		end
	end)
end
