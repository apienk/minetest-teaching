-- check if node at pos is a digit
local function node_is_digit(pos)
	local node = minetest.get_node(pos)
	local nd = minetest.registered_nodes[node.name]
	if nd == nil then
		return false
	end
	if nd.groups == nil then
		return false
	end
	if nd.groups.teaching_util == nil then
		return false
	end
	return true
end

-- check if node at pos is the digit dg
local function node_is_spec_digit(pos, dg)
	if not node_is_digit(pos) then
		return false
	end
	local node = minetest.get_node(pos)
	local nd = minetest.registered_nodes[node.name]
	if type(nd.teaching_digit) == 'table' then
		for _, digit in ipairs(nd.teaching_digit) do
			if digit == dg then
				return true
			end
		end
	elseif type(nd.teaching_digit) == 'string' then
		if nd.teaching_digit == dg then
			return true
		end
	end
	return false
end

-- check a solution placed by player (checker node at pos) and give prizes if correct
local function check_solution(pos, player)
	local meta = minetest.get_meta(pos)
	local sol = meta:get_string('solution')
	if node_is_spec_digit({x=pos.x, y=pos.y+1, z=pos.z}, sol) then
		if meta:get_string('b_saytext') == 'true' then
			minetest.chat_send_player(player:get_player_name(), meta:get_string('s_saytext'))
		end
		if meta:get_string('b_dispense') == 'true' then
			minetest.add_item({x=pos.x, y=pos.y+2, z=pos.z}, meta:get_inventory():get_list('dispense')[1])
		end
		if meta:get_string('b_lock') == 'true' then
			-- Place a lab block (indestructible for students) where the solution was
			minetest.set_node({x=pos.x, y=pos.y+1, z=pos.z}, {name="teaching:lab"})
		end
	end
end

-- can_dig callback that only allows teachers or freebuild to destroy the node
local function only_dig_teacher_or_freebuild(pos, player)
	if minetest.check_player_privs(player:get_player_name(), {teacher=true}) then
		return true
	elseif minetest.check_player_privs(player:get_player_name(), {freebuild=true}) then
		return true
	else
		return false
	end
end

local function register_util_node(name, digit, humanname)
	minetest.register_node('teaching:util_' .. name, {
		drawtype = 'normal',
		tiles = {'teaching_lab.png', 'teaching_lab.png', 'teaching_lab.png', 
			'teaching_lab.png', 'teaching_lab.png', 'teaching_lab_util_' .. name .. '.png'},
		paramtype2 = 'facedir',
		description = humanname,
		groups = {teaching_util=1, snappy=3},
		teaching_digit = digit,
		can_dig = function(pos, player)
			if minetest.check_player_privs(player:get_player_name(), {teacher=true}) then
				return true
			--Enable students with freebuild to dig util nodes they (and you) placed
			elseif minetest.check_player_privs(player:get_player_name(), {freebuild=true}) then
				return true
			else
				local node = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z})
				if node.name == 'teaching:lab_checker' or node.name == 'teaching:lab_allowdig' then
					return true
				else
					return false
				end
			end
		end,
		on_punch = function(pos, node, puncher)
			if minetest.check_player_privs(puncher:get_player_name(), {teacher=true}) then
				--set to respective glow node
				minetest.set_node(pos, {name=node.name .. "_glow", param2=minetest.dir_to_facedir(puncher:get_look_dir())})
			end
		end,
	})
end

local function register_util_glow_node(name, digit, humanname)
	minetest.register_node('teaching:util_' .. name .. "_glow", {
		drawtype = 'normal',
		tiles = {'teaching_lab.png', 'teaching_lab.png', 'teaching_lab.png', 
			'teaching_lab.png', 'teaching_lab.png', 'teaching_lab_util_' .. name .. '.png'},
		paramtype2 = 'facedir',
		paramtype = "light",
		light_source = 10,
		post_effect_color = {a=255, r=128, g=128, b=128},
		description = humanname,
		groups = {teaching_util=1, snappy=3},
		drop = 'teaching:util_' .. name,
		teaching_digit = digit,
		can_dig = function(pos, player)
			if minetest.check_player_privs(player:get_player_name(), {teacher=true}) then
				return true
			elseif minetest.check_player_privs(player:get_player_name(), {freebuild=true}) then
				return true
			else
				local node = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z})
				if node.name == 'teaching:lab_checker' then
					return true
				else
					return false
				end
			end
		end,
		on_punch = function(pos, node, puncher)
			if minetest.check_player_privs(puncher:get_player_name(), {teacher=true}) then
				--set to respective dark node
				minetest.set_node(pos, {name=string.gsub(node.name, "_glow", ""), param2=minetest.dir_to_facedir(puncher:get_look_dir())})
			end
		end,
	})
end

minetest.register_privilege('teacher', {
      description = "Teacher privilege",
      give_to_singleplayer = false,
})

minetest.register_privilege('freebuild', {
      description = "Free-building privilege",
      give_to_singleplayer = false,
})

minetest.register_node('teaching:lab', {
		drawtype = 'normal',
		tiles = {'teaching_lab.png'},
		description = 'Lab block',
		groups = {oddly_breakable_by_hand=2},
		can_dig = only_dig_teacher_or_freebuild,
})

minetest.register_node('teaching:lab_allowdig', {
		drawtype = 'normal',
		tiles = {'teaching_lab_allowdig.png'},
		description = 'Allow-dig block (allows students to break block above)',
		groups = {oddly_breakable_by_hand=2},
		can_dig = only_dig_teacher_or_freebuild,
})

local checker_formspec = 
	'size[8,9]'..
	'field[0.5,0.5;2,1;solution;Correct solution:;${solution}]'..
	'checkbox[2.5,0.2;b_lock;Lock once solved?;${b_lock}]'..
	'label[0.25,1;Action if right:]'..
	'checkbox[0.5,1.5;b_saytext;Say text:;${b_saytext}]'..
	'field[2.4,1.9;3,0.75;s_saytext;;${s_saytext}]'..
	'checkbox[0.5,2.25;b_dispense;Dispense item:;${b_dispense}]'..
	'list[nodemeta:${x},${y},${z};dispense;1,2.9;1,1;]'..
	'list[current_player;main;0,5;8,4;]'..
	'button_exit[0.3,4;2,1;save;Save]'

minetest.register_on_player_receive_fields(function(sender, formname, fields)
	if formname:find('teaching:lab_checker_') == 1 then
		local x, y, z = formname:match('teaching:lab_checker_(.-)_(.-)_(.*)')
		local pos = {x=tonumber(x), y=tonumber(y), z=tonumber(z)}
		--print("Checker at " .. minetest.pos_to_string(pos) .. " got " .. dump(fields))
		local meta = minetest.get_meta(pos)
		if fields.b_saytext ~= nil then -- If we get a checkbox value we need to save that immediately because they are not sent on clicking 'Save' (due to a bug in minetest)
			meta:set_string('b_saytext', fields.b_saytext)
		end
		if fields.b_dispense ~= nil then -- ditto
			meta:set_string('b_dispense', fields.b_dispense)
		end
		if fields.b_lock ~= nil then -- ditto
			meta:set_string('b_lock', fields.b_lock)
		end
		if fields.save ~= nil then
			meta:set_string('solution', fields.solution)
			if meta:get_string('b_saytext') == 'true' then
				meta:set_string('s_saytext', fields.s_saytext)
			end
		end
	end
end)

minetest.register_node('teaching:lab_checker', {
		drawtype = 'normal',
		tiles = {'teaching_lab_checker.png'},
		description = 'Checking block',
		groups = {oddly_breakable_by_hand=1},
		can_dig = only_dig_teacher_or_freebuild,
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size("dispense", 1)
		end,
		on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
			if minetest.check_player_privs(clicker:get_player_name(), {teacher=true}) then
				local meta = minetest.get_meta(pos)
				local formspec = checker_formspec
				formspec = formspec:gsub('${x}', pos.x)
				formspec = formspec:gsub('${y}', pos.y)
				formspec = formspec:gsub('${z}', pos.z)
				formspec = formspec:gsub('${(.-)}', function(name) return meta:get_string(name) end)
				minetest.show_formspec(clicker:get_player_name(), 'teaching:lab_checker_'..pos.x..'_'..pos.y..'_'..pos.z, formspec)
				-- We need to ue this complicated way because MT does not allow us to deny showing the formspec to some people
			else
				if not itemstack:is_empty() then
					if minetest.registered_nodes[itemstack:get_name()] ~= nil then
						if minetest.registered_nodes[itemstack:get_name()].teaching_digit ~= nil then
							-- Someone wants to place a utility node, we can do that
							local newpos = {x=pos.x, y=pos.y+1, z=pos.z} -- FIXME: This assumes said person wants to place node on top
							minetest.set_node(newpos, {name=itemstack:get_name(), param2=minetest.dir_to_facedir(clicker:get_look_dir())})
							itemstack:take_item()
							minetest.log('action', clicker:get_player_name() .. ' places ' .. node.name .. ' at ' .. minetest.pos_to_string(newpos))
							check_solution(pos, clicker)
						end -- We don't have way to pass on_rightclick along
					end
				end
				return false
			end
		end,
})

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	if not minetest.check_player_privs(placer:get_player_name(), {teacher=true}) then
		if minetest.registered_nodes[newnode.name].teaching_digit ~= nil then
			local below = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z})
			if below.name == 'teaching:lab_checker' then
				if not placer:get_player_name() then
					return minetest.log('warning', 'placenode event triggered without valid player')
				end
				check_solution(pos, placer)
			else
				if minetest.check_player_privs(placer:get_player_name(), {freebuild=true}) then
					return false
				else
					minetest.set_node(pos, oldnode)
					return true -- Don't take item
				end
			end
		end
	end
end)

minetest.register_chatcommand("alphabetize", {
	params = "<text string in caps>",
	description = "Give all letters blocks in a phrase",
	privs = {teacher = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found"
		end
		if param == nil then
			return true, "Alphabetize invoked without parameter"
		end
		local letternodes = {}
		local uni
		for c in param:gmatch(".") do
			local h = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
			for i in h:gmatch(".") do
				if i == c then
					table.insert(letternodes, "teaching:util_" .. string.upper(i))
				end
			end
			if c == "=" then table.insert(letternodes, "teaching:util_equals") end
			if c == "<" then table.insert(letternodes, "teaching:util_less") end
			if c == ">" then table.insert(letternodes, "teaching:util_more") end
			if c == "/" or c == ":" then table.insert(letternodes, "teaching:util_divide") end
			if c == "*" then table.insert(letternodes, "teaching:util_multiplicate") end
			if c == "+" then table.insert(letternodes, "teaching:util_plus") end
			if c == "-" then table.insert(letternodes, "teaching:util_minus") end
			if c == "." or c == "," then table.insert(letternodes, "teaching:util_decimalpoint") end
			-- detect Polish characters
			if uni then
				if uni == 0xc4 and (c:byte() == 0x84 or c:byte() == 0x85) then table.insert(letternodes, "teaching:util_A_") end
				if uni == 0xc4 and (c:byte() == 0x86 or c:byte() == 0x87) then table.insert(letternodes, "teaching:util_C_") end
				if uni == 0xc4 and (c:byte() == 0x98 or c:byte() == 0x99) then table.insert(letternodes, "teaching:util_E_") end
				if uni == 0xc5 and (c:byte() == 0x81 or c:byte() == 0x82) then table.insert(letternodes, "teaching:util_L_") end
				if uni == 0xc5 and (c:byte() == 0x83 or c:byte() == 0x84) then table.insert(letternodes, "teaching:util_N_") end
				if uni == 0xc3 and (c:byte() == 0x93 or c:byte() == 0xb3) then table.insert(letternodes, "teaching:util_O_") end
				if uni == 0xc5 and (c:byte() == 0x9a or c:byte() == 0x9b) then table.insert(letternodes, "teaching:util_S_") end
				if uni == 0xc5 and (c:byte() == 0xbb or c:byte() == 0xbc) then table.insert(letternodes, "teaching:util_Z_") end
				if uni == 0xc5 and (c:byte() == 0xb9 or c:byte() == 0xba) then table.insert(letternodes, "teaching:util_Y_") end
			end
			-- detect unicode
			uni = nil
			if c:byte() == 0xc3 then
				uni = c:byte()
			end
			if c:byte() == 0xc4 then
				uni = c:byte()
			end
			if c:byte() == 0xc5 then
				uni = c:byte()
			end
		end
		local inv = player:get_inventory()
		local full = false
		for _, l in ipairs(letternodes) do
			if inv:room_for_item("main", l) then
				inv:add_item("main", l)
			else
				full = true
			end
		end
		if full then minetest.chat_send_player(player:get_player_name(), "Your inventory is full. Some letters were not added.") end
		return true
	end,
})

local s = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
for i in s:gmatch('.') do
	register_util_node(i, i, i)
	register_util_glow_node(i, i, i)
end

--Polish
register_util_node('A_', 'Ą', 'Ą')
register_util_node('C_', 'Ć', 'Ć')
register_util_node('E_', 'Ę', 'Ę')
register_util_node('L_', 'Ł', 'Ł')
register_util_node('N_', 'Ń', 'Ń')
register_util_node('O_', 'Ó', 'Ó')
register_util_node('S_', 'Ś', 'Ś')
register_util_node('Z_', 'Ż', 'Ż')
register_util_node('Y_', 'Ź', 'Ź')

register_util_glow_node('A_', 'Ą', 'Ą')
register_util_glow_node('C_', 'Ć', 'Ć')
register_util_glow_node('E_', 'Ę', 'Ę')
register_util_glow_node('L_', 'Ł', 'Ł')
register_util_glow_node('N_', 'Ń', 'Ń')
register_util_glow_node('O_', 'Ó', 'Ó')
register_util_glow_node('S_', 'Ś', 'Ś')
register_util_glow_node('Z_', 'Ż', 'Ż')
register_util_glow_node('Y_', 'Ź', 'Ź')

--Operators
register_util_node('decimalpoint', '.', '. (Decimal point)')
register_util_node('divide', {':', '/'}, ': (Divide)')
register_util_node('equals', '=', '= (Equals)')
register_util_node('less', '<', '< (Less than)')
register_util_node('minus', '-', '- (Minus)')
register_util_node('more', '>', '> (More than)')
register_util_node('multiply', {'*', 'x'}, '* (Multiply)')
register_util_node('plus', '+', '+ (Plus)')
register_util_node('question', '?', '? (Question mark)')

--Infobox
minetest.register_node("teaching:infobox", {
	description = "Infobox",
	range = 12,
	stack_max = 99,
	tiles = {"infobox_cap.png", "infobox_cap.png", "infobox_side.png", "infobox_side.png", "infobox_side.png", "infobox_side.png"},
	drop = "",
	paramtype = "light",
	light_source = 8,
	post_effect_color = {a=255, r=64, g=64, b=192},
	groups = {unbreakable = 1, not_in_creative_inventory = 1},
})
