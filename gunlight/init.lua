-- license:BSD-3-Clause
-- copyright-holders:Jack Li
local exports = {
	name = 'gunlight',
	version = '0.0.4',
	description = 'Gunlight plugin',
	license = 'BSD-3-Clause',
	author = { name = 'Jack Li / Psakhis' } }

local gunlight = exports

local machine_screen = nil
local user_set_brightness = nil
local user_set_contrast = nil
local user_set_gamma = nil
local gain_set_brightness = 0.0
local gain_set_contrast = 0.0
local gain_set_gamma = 0.0
local num_frames_gain = 0
local gain_applied = false
local lag_stack = {}
local lag_key = {}
local lag_offset = {}
local only_gain = {}

function gunlight.startplugin()

	-- List of gunlight buttons, each being a table with keys:
	--   'port' - port name of the button being gunlightd
	--   'mask' - mask of the button field being gunlightd
	--   'type' - input type of the button being gunlightd
	--   'key' - input_seq of the keybinding
	--   'key_cfg' - configuration string for the keybinding
	--   'guncode_offset' - Only apply if shoot out of screen
	--   'brightness_gain' - increase brightness for gun button
	--   'contrast_gain' - increase contrast for gun button
	--   'gamma_gain' - increase gamma for gun button
	--   'off_frames' - frames to apply gain
	--   'method' - until release or fixed frames gain
	--   'lag' - frames to apply button
	--   'only_gain' - apply only with gain active
	--   'button' - reference to ioport_field
	--   'counter' - position in gunlight cycle
	local buttons = {}

	local menu_handler
        
        local function save_user_settings()
                local user_set = manager.machine.screens[machine_screen].container.user_settings                    	        	
		user_set_brightness = user_set.brightness 
	        user_set_contrast = user_set.contrast
	        user_set_gamma = user_set.gamma	        	        
        end
        
        local function restore_user_settings()
         	--local COLOR_WHITE = 0xffffffff
		--manager.machine.screens[":screen"]:draw_box(0, 0,  manager.machine.screens[":screen"].width, manager.machine.screens[":screen"].height, COLOR_WHITE,COLOR_WHITE)
		
        	if gain_applied then         	
	        	local user_set = manager.machine.screens[machine_screen].container.user_settings	        	
	        	user_set.brightness = user_set_brightness 
	        	user_set.contrast = user_set_contrast 
	        	user_set.gamma = user_set_gamma
	               	manager.machine.screens[machine_screen].container.user_settings = user_set
	               	gain_applied = false
	               	gain_set_brightness = 0.0
	        	gain_set_contrast = 0.0
	        	gain_set_gamma = 0.0		        		        	        	
	        end	
        end
        
        local function restore_gain_settings()
        	local user_set = manager.machine.screens[machine_screen].container.user_settings        	
		user_set.brightness = user_set_brightness + gain_set_brightness 
	        user_set.contrast = user_set_contrast + gain_set_contrast
	        user_set.gamma = user_set_gamma + gain_set_gamma
	        manager.machine.screens[machine_screen].container.user_settings = user_set
	        gain_applied = true		                       	      
        end
        
        local function guncode_offset()        
        	local guncode_xaxis = manager.machine.input:code_from_token("GUNCODE_1_XAXIS")	
		local guncode_yaxis = manager.machine.input:code_from_token("GUNCODE_1_YAXIS")
		local guncode_x = manager.machine.input:code_value(guncode_xaxis)
	 	local guncode_y = manager.machine.input:code_value(guncode_yaxis)
	 	--emu.print_verbose("guncode X ".. guncode_x)
		--emu.print_verbose("guncode Y ".. guncode_y)
		if (guncode_x == -65536 and guncode_y == -65536) then					       
			return 1
		else						       
			return 0
		end		
        end
               
	local function process_frame()
		local input = manager.machine.input						
					
		local function process_button(button)
			local pressed = input:seq_pressed(button.key)							
			
			if pressed then							
				button.counter = button.counter + 1																	
				if button.method == "last" then
					if button.off_frames > num_frames_gain then
						num_frames_gain = button.off_frames
					end
				end				
				if button.method == "first" then					
					if button.counter == 1 and not gain_applied then
						num_frames_gain = button.off_frames
					end
				end																				   				
				if  button.brightness_gain > gain_set_brightness then
					gain_set_brightness = button.brightness_gain
				end									
				if  button.contrast_gain > gain_set_contrast then
					gain_set_contrast = button.contrast_gain
				end									
				if  button.gamma_gain > gain_set_gamma then
					gain_set_gamma = button.gamma_gain
				end	
				
				-- Frames to apply button
				if button.lag > 0 then
				        table.insert(lag_stack,button.lag)
				        table.insert(lag_key,button.port .. '\0' .. button.mask .. '.' .. button.type)	
				        table.insert(lag_offset,button.guncode_offset)			        
				        table.insert(only_gain,button.only_gain)			        
				        return 0
				else      
					if button.guncode_only_gain == "yes" then
						if button.guncode_offset == "yes" then				        
				        		return 8
				        	else
				        		return 2
				        	end		
				        else
				        	if button.guncode_offset == "yes" then				        
				        		return 9
				        	else
				        		return 1
				        	end				     
				        end		
				end        
			else						        
				button.counter = 0											
				return 0
			end
		end
                                                
		-- Resolves conflicts between multiple gunlight keybindings for the same button.
		local button_states = {} 			  		                          	
               		
		for i, button in ipairs(buttons) do
			if button.button then			        
				local key = button.port .. '\0' .. button.mask .. '.' .. button.type									
				local state = button_states[key] or {0, button.button}
				state[1] = process_button(button) | state[1]									
				button_states[key] = state														
			end
		end						 			 								
			
		local i = 1					
		while i <= table.maxn(lag_stack) do		
		        --emu.print_verbose("ELEMENT " .. lag_stack[i])
		        lag_stack[i] = lag_stack[i] - 1
		        --emu.print_verbose("NEW ELEMENT " .. lag_stack[i])
		        if lag_stack[i] <= 0 then
		                local key = lag_key[i] 
		                local state = button_states[key]
		                if only_gain[i] == "yes" then		                
		                	if lag_offset[i] == "yes" then
		                		state[1] = 8
		                	else
		                		state[i] = 2
		                	end		
		                else
		                	if lag_offset[i] == "yes" then
		                		state[1] = 9
		                	else
		                		state[i] = 1
		                	end	
		                end	
		                button_states[key] = state
		                table.remove(lag_stack,i)
		                table.remove(lag_key,i)
		                table.remove(lag_offset,i)
		                --emu.print_verbose("removed " .. i)
		        else
		                i = i + 1        
		        end
		end
						
		
		if num_frames_gain == 0 then
			if gain_applied then
				restore_user_settings()
			end
		else				
			if not gain_applied then
				save_user_settings()
				restore_gain_settings()			
			end	
			num_frames_gain = num_frames_gain - 1
		end								
		
			
		for i, state in pairs(button_states) do
			if (state[1] == 2 or state[1] == 8) and not gain_applied then				
				state[1] = 0
			end			        	        		       		       	           			           	        
			if state[1] == 9 then
				state[1] = guncode_offset()
			end			        	        		       		       	           			           	        
			state[2]:set_value(state[1])					
		end					
								
	end

	local function load_settings()	
	        --:screen or :mainpcb:screen
	        for i,v in pairs(manager.machine.screens) do 
		      machine_screen = i		         	         
		      break
		end		
	        --emu.print_verbose("machine_screen " .. machine_screen)	
	        save_user_settings()
		local loader = require('gunlight/gunlight_save')
		if loader then
			buttons = loader:load_settings()
		end
	end

	local function save_settings()
		restore_user_settings()	 		
		local saver = require('gunlight/gunlight_save')
		if saver then
			saver:save_settings(buttons)
		end

		menu_handler = nil
		buttons = {}
	end

	local function menu_callback(index, event)
		if menu_handler then
			return menu_handler:handle_menu_event(index, event, buttons)
		else
			return false
		end
	end

	local function menu_populate()
		if not menu_handler then
			menu_handler = require('gunlight/gunlight_menu')
			if menu_handler then
				menu_handler:init_menu(buttons)
			end
		end
		if menu_handler then
			return menu_handler:populate_menu(buttons)
		else
			return {{_p('plugin-gunlight', 'Failed to load gunlight menu'), '', 'off'}}
		end
	end
       
       
        emu.register_frame(process_frame)	
	emu.register_prestart(load_settings)
	emu.register_stop(save_settings)
	emu.register_menu(menu_callback, menu_populate, _p('plugin-gunlight', 'GunLight'))
end

return exports
