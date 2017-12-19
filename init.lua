----------------------------------------------------
-- GLOVES FOR STEALING, (C) rnd 2016

local stealt = {};
local thiefxp = {};

minetest.register_tool("thief:gloves", {
	description = "thief gloves",
	inventory_image = "stealgloves.png",
	tool_capabilities = {
		full_punch_interval = 2,
	},
	
	
	on_use = function(itemstack, user, pointed_thing)
		
		local player1 = user;
		local name = player1:get_player_name();
		if not pointed_thing.type == "object" then return end
		local player2 = pointed_thing.ref;
		
		thiefxp[name] = thiefxp[name] or 0
		
		local pjump = player1:get_player_control().jump
		
		
		if not player2 then
		if not pjump then -- CLOAK
			local t = minetest.get_gametime();
			if not stealt[name] then stealt[name]={t,0,"",{},t-20}; end -- time, state, target name, target position, cloak time
			local data = stealt[name];
			if (t - data[5])<20 then
				minetest.chat_send_player(name,"#THIEF: wait " .. 20 -(t-data[5]) .. " s before cloaking ");
				return
			end
			data[5]=t;
			
			
			local ncolor = player1:get_nametag_attributes().color;
			player1:set_nametag_attributes({color = "0x0"});
			local cloaktime =  7+14*thiefxp[name]/10;
			if cloaktime>19 then cloaktime = 19 end
			minetest.chat_send_player(name,"#THIEF: cloak engaged for " .. math.floor(10*cloaktime)/10 .. " s");
			
			minetest.after(cloaktime, function() -- decloak
				player1:set_nametag_attributes({color = ncolor})
				minetest.chat_send_player(name,"#THIEF: decloaking");
			end)
				
			
		end
		return 
		end
		
		if not player2:is_player() then return end

		if pjump then -- SLOW
			local speed0 = player2:get_physics_override().speed;
			if speed0<0.8 then return end -- normal player speed
			player2:set_physics_override({speed=0.33*speed0});
			minetest.chat_send_player(name,"#THIEF: target slowed down for 10 s");
			minetest.after(10, function() player2:set_physics_override({speed=speed0}); end)
			return 
		end
		
		local pos1 = player1:getpos();
		local pos2 = player2:getpos();
		
		local t = minetest.get_gametime();
		if not stealt[name] then stealt[name]={t,0,"",{},t}; end -- time, state, target name, target position, cloak time
		
		local data = stealt[name];

		local v = {x=pos2.x-pos1.x,y=pos2.y-pos1.y,z=pos2.z-pos1.z};
		local vm = math.sqrt(v.x^2+v.y^2+v.z^2);
		if vm~=0 then v.x=v.x/vm; v.y=v.y/vm; v.z=v.z/vm end
		
		local caught = false;
		if data[2]==0 then -- init
			local dir2 = player2:get_look_dir();
			if v.x*dir2.x+v.z*dir2.z<=0.5 then caught = true end
			if not caught then
				minetest.chat_send_player(name,"#STEALING: attempting to steal. Stand behind player, wait for 5s and then use gloves again.") 
				data[3] = player2:get_player_name();
				data[4] = pos2;
				data[1] = t;
				data[2]=1;
			end
			
		elseif data[2] == 1 then -- stealing second step
		
			local pos20 = data[4];
			if (pos20.x-pos2.x)^2 +(pos20.z-pos2.z)^2>4 then
			--if pos20.x~=pos2.x or pos20.z~=pos2.z then 
				minetest.chat_send_player(name,"#STEALING: aborting. target moved.") 
				data[2]=0
				return 
			end
			
			if t-data[1]<5 then return end -- too soon
			if t-data[1]>10 then data[2]=0 return end -- timeout
			
			data[2]=0
			local dir2 = player2:get_look_dir();
			if v.x*dir2.x+v.z*dir2.z<=0.5 then caught = true end
			if not caught then -- display inventory of items from target hands
				
				local selected = 1;
				local inv = player2:get_inventory();
				local textlist = "";
				for i = 1,8 do
					textlist = textlist .. inv:get_stack("main", i):get_name() ..",";
				end
			
				local form = "size [3,2.5]"..
				"label[0,-0.4;Select item to steal]"..
				"textlist[0,0;2.8,2.6;craft;" .. textlist .. ";" .. selected .."]";
				
				minetest.show_formspec(name, "stealform", form)
				
				--local sel = tonumber(string.sub(fields.craft,5)) or 1
			else
				local xp = thiefxp[name];
				xp=xp-0.5; if xp<0 then xp = 0 end
				thiefxp[name]=xp;
				minetest.chat_send_all("#THIEF "..name .. " tried to steal from " .. data[3] .. " but was caught. Lost -0.5 xp.")
			end
		end
	
	end,
	
	
	on_rightclick = function(self, clicker)
		local name = clicker:get_player_name() or "";
		minetest.chat_send_player(name, "#THIEF: you have " .. thiefxp[name] .. " thief experience. Cloaktime can be 19s when xp = 8.5 ")		
	 end,
	
})

-- STEALING: final step
minetest.register_on_player_receive_fields(
	function(player, formname, fields)
	
		if formname == "stealform" then
			if fields.craft then
				if string.sub(fields.craft,1,3)=="DCL" then
					local sel = tonumber(string.sub(fields.craft,5));
					if not sel then return end
					local name = player:get_player_name();
					local data= stealt[name];
					if not data then return end
					data[2]=0
					local tname = data[3];
					local player2 = minetest.get_player_by_name(tname);
					if not player2 then return end
					
					local pos1 = player:getpos();
					local pos2 = player2:getpos();
					local v = {x=pos2.x-pos1.x,y=pos2.y-pos1.y,z=pos2.z-pos1.z};
					
					local pos20 = data[4];
					if (pos20.x-pos2.x)^2 +(pos20.z-pos2.z)^2>4 then 
						local text = "stealing aborted. target moved too far";
						local form = "size [6,2] textarea[0,0;6.5,3.5;stealform1;THIEF;".. text.."]"
						minetest.show_formspec(name, "stealfom1", form)
						return 
					end
					
					local privs = minetest.get_player_privs(tname);
					if privs.privs then return end -- no stealing from admin
					
					local tinv = player2:get_inventory();
					local inv = player:get_inventory();
					
					
					local txp = thiefxp[tname]; -- steal xp from victim
					if not txp then txp = 0.1 elseif txp<0.1 then txp = 0.1 end
					thiefxp[tname] = txp - 0.1;
					
					local item = tinv:get_stack("main", sel):get_name();
					if item == "" then return end
					
					local dir2 = player2:get_look_dir();
					if v.x*dir2.x+v.z*dir2.z<=0.5 then 
						minetest.chat_send_all("#THIEF: " .. name .. " has been caught trying to steal " .. item .. " from " .. tname) 
						local xp = thiefxp[name];
						xp=xp-0.5; if xp<0 then xp = 0 end
						thiefxp[name]=xp;
						return 
					end
					
					tinv:remove_item("main", ItemStack(item));
					inv:add_item("main",ItemStack(item));

					thiefxp[name] = thiefxp[name] + 0.1;
					
					local text = "#THIEF: successfuly stole " .. item;
					minetest.after(15, function() minetest.chat_send_all("#THIEF: someone has been robbed of " .. item .. " +0.1 xp for thief. ") end);
					local form = "size [6,2] textarea[0,0;6.5,3.5;stealform1;THIEF;".. text.."]"
					minetest.show_formspec(name, "stealfom1", form)
					
				end
			
			end
		end
	end
)


minetest.register_craft({
	output = "thief:gloves",
	recipe = {
		{"default:diamondblock","default:goldblock","wool:white"},
	}
})
---------------------------------------------