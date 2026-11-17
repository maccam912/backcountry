-- A bearing to a known place. The journal remembers the most recent pack
-- left behind, even when a campmate finds it while its owner is offline.
bc.trail = {}

local function forget_pack(st)
	st.p.lost_pack = nil
	if st.p.bearing == "pack" then st.p.bearing = nil end
	st.fs_dirty = true
end

function bc.trail.mark_pack(st, pos)
	st.p.lost_pack = vector.new(pos)
	core.get_meta(pos):set_string("pack_owner", st.name)
	st.fs_dirty = true
end

function bc.trail.check_pack(pos)
	local meta = core.get_meta(pos)
	local st = bc.state(meta:get_string("pack_owner"))
	if st and st.p.lost_pack and vector.equals(pos, st.p.lost_pack)
			and meta:get_inventory():is_empty("main") then
		forget_pack(st)
	end
end

function bc.trail.update(st)
	-- Only inspect loaded nodes. A distant, unloaded camp is still there.
	local pack = st.p.lost_pack
	local n = pack and core.get_node_or_nil(pack)
	if n then
		local meta = core.get_meta(pack)
		if n.name ~= "bc:remains" or meta:get_string("pack_owner") ~= st.name
				or meta:get_inventory():is_empty("main") then forget_pack(st) end
	end
	local home = st.p.home and core.get_node_or_nil(st.p.home)
	if home and home.name ~= "bc:cairn" then
		st.p.home = nil
		if st.p.bearing == "camp" then st.p.bearing = nil end
		st.fs_dirty = true
	end
end

function bc.trail.reading(st, from)
	local pack = st.p.bearing == "pack"
	local target = pack and st.p.lost_pack or (st.p.bearing == "camp" and st.p.home)
	if not target then return "" end
	local label = pack and "Lost pack" or "Camp"
	local delta = vector.subtract(target, from)
	local distance = bc.hdist(target, from)
	local level = math.floor(math.abs(delta.y) + 0.5)
	local vertical = level >= 4 and ("  /  " .. level .. " m " .. (delta.y > 0 and "above" or "below")) or ""
	if distance < 3 then return label .. " nearby" .. vertical end
	return string.format("%s  /  %s  %d m%s", label, bc.compass(delta), math.floor(distance + 0.5), vertical)
end

function bc.trail.controls(st, x, y)
	local out = {}
	local function button(id, label)
		local selected = st.p.bearing == id
		out[#out + 1] = string.format("button[%.2f,%.2f;3.6,0.8;trail_%s;%s]",
			x, y, id, (selected and "Hide " or "Track ") .. label)
		x = x + 3.8
	end
	if st.p.home then button("camp", "camp") end
	if st.p.lost_pack then button("pack", "lost pack") end
	return table.concat(out)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "" then return end
	local st = bc.state(player)
	if not st or st.tab ~= 2 then return end
	local id = fields.trail_pack and st.p.lost_pack and "pack" or (fields.trail_camp and st.p.home and "camp")
	if not id then return end
	if st.p.bearing == id then st.p.bearing = nil else st.p.bearing = id end
	bc.hud.update(player, st)
	bc.journal.refresh(player, st)
	return true
end)

function bc.trail.camp_spawn(st)
	local home = st.p.home
	if not home then return end
	core.load_area(vector.subtract(home, 2), vector.add(home, 3))
	if core.get_node(home).name ~= "bc:cairn" then return end
	local function clear(pos)
		local node = core.registered_nodes[core.get_node(pos).name]
		return node and not node.walkable and node.liquidtype == "none"
			and (node.damage_per_second or 0) == 0 and not node.groups.bc_fire
	end
	for _, off in ipairs({{0, 1}, {1, 0}, {0, -1}, {-1, 0}, {0, 0}}) do
		for dy = -1, 1 do
			local floor = {x = home.x + off[1], y = home.y + dy, z = home.z + off[2]}
			local ground = core.registered_nodes[core.get_node(floor).name]
			if ground and ground.walkable and (ground.damage_per_second or 0) == 0
					and clear(vector.offset(floor, 0, 1, 0)) and clear(vector.offset(floor, 0, 2, 0)) then
				return vector.offset(floor, 0, 0.51, 0)
			end
		end
	end
end
