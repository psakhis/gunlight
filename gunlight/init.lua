-- license:BSD-3-Clause
-- copyright-holders:Jack Li
local exports = {
	name = 'gunlight',
	version = '0.0.4',
	description = 'Gunlight plugin',
	license = 'BSD-3-Clause',
	author = { name = 'Jack Li / Psakhis' } }

local gunlight = exports

local user_set_brightness = nil
local user_set_contrast = nil
local user_set_gamma = nil
local gain_set_brightness = 0.0
local gain_set_contrast = 0.0
local gain_set_gamma = 0.0
local num_frames_gain = 0
local gain_applied = false

function gunlight.startplugin()

	-- List of gunlight buttons, each being a table with keys:
	--   'port' - port name of the button being gunlightd
	--   'mask' - mask of the button field being gunlightd
	--   'type' - input type of the button being gunlightd
	--   'key' - input_seq of the keybinding
	--   'key_cfg' - configuration string for the keybinding
	--   'brightness_gain' - increase brightness for gun button
	--   'contrast_gain' - increase contrast for gun button
	--   'gamma_gain' - increase gamma for gun button
	--   'off_frames' - frames to apply gain
	--   'method' - until release or fixed frames gain
	--   'button' - reference to ioport_field
	--   'counter' - position in gunlight cycle
	local buttons = {}

	local menu_handler
        
        local function save_user_settings()
        	local user_set = manager.machine.screens[":screen"].container.user_settings
		user_set_brightness = user_set.brightness 
	        user_set_contrast = user_set.contrast
	        user_set_gamma = user_set.gamma	        	        
        end
        
        local function restore_user_settings()
         	--local COLOR_WHITE = 0xffffffff
		--manager.machine.screens[":screen"]:draw_box(0, 0,  manager.machine.screens[":screen"].width, manager.machine.screens[":screen"].height, COLOR_WHITE,COLOR_WHITE)
		
        	if gain_applied then
	        	local user_set = manager.machine.screens[":screen"].container.user_settings
	        	user_set.brightness = user_set_brightness 
	        	user_set.contrast = user_set_contrast 
	        	user_set.gamma = user_set_gamma
	               	manager.machine.screens[":screen"].container.user_settings = user_set
	               	gain_applied = false
	               	gain_set_brightness = 0.0
	        	gain_set_contrast = 0.0
	        	gain_set_gamma = 0.0		        		        	        	
	        end	
        end
        
        local function restore_gain_settings()
        	local user_set = manager.machine.screens[":screen"].container.user_settings
		user_set.brightness = user_set_brightness + gain_set_brightness 
	        user_set.contrast = user_set_contrast + gain_set_contrast
	        user_set.gamma = user_set_gamma + gain_set_gamma
	        manager.machine.screens[":screen"].container.user_settings = user_set
	        gain_applied = true		                       	      
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
				return 1
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
			state[2]:set_value(state[1])						
		end					
								
	end

	local function load_settings()	
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
