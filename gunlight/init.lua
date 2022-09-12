-- license:BSD-3-Clause
-- copyright-holders:Jack Li
local exports = {
	name = 'gunlight',
	version = '0.0.4',
	description = 'Gunlight plugin',
	license = 'BSD-3-Clause',
	author = { name = 'Jack Li / Psakhis' } }

local gunlight = exports

local init_user_set = nil
local gunlight_user_set = nil
local num_frames = 0

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
	--   'button' - reference to ioport_field
	--   'counter' - position in gunlight cycle
	local buttons = {}

	local menu_handler
               
	local function process_frame()
		local input = manager.machine.input
		local gunlight_user_set = manager.machine.screens[":screen"].container.user_settings	
		local gunlight_brightness_gain = 0.0
		local gunlight_contrast_gain = 0.0
		local gunlight_gamma_gain = 0.0
		local gunlight_frames = 1
		num_frames = num_frames + 1
                --local COLOR_WHITE = 0xffffffff

		local function process_button(button)
			local pressed = input:seq_pressed(button.key)			
			if pressed then					         								
				button.counter = button.counter + 1	
				gunlight_brightness_gain = button.brightness_gain
				gunlight_contrast_gain = button.contrast_gain
				gunlight_gamma_gain = button.gamma_gain
				num_frames = 0								
				return 1
			else	
			        if num_frames < button.off_frames and (init_user_set.brightness < gunlight_user_set.brightness or 
			                                               init_user_set.contrast < gunlight_user_set.contrast or
			                                               init_user_set.gamma < gunlight_user_set.gamma) then			              
			        	gunlight_frames	= 1
			        	gunlight_brightness_gain = button.brightness_gain
			        	gunlight_contrast_gain = button.contrast_gain
				        gunlight_gamma_gain = button.gamma_gain
			        else
			        	gunlight_frames = 0
			        	num_frames = 0
			        end		
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
		for i, state in pairs(button_states) do		        	        		       
		        if state[1] == 1 or gunlight_frames == 1 then		           			           
		           gunlight_user_set.brightness = gunlight_brightness_gain + init_user_set.brightness
		           gunlight_user_set.contrast = gunlight_contrast_gain + init_user_set.contrast
		           gunlight_user_set.gamma = gunlight_gamma_gain + init_user_set.gamma
		         --manager.machine.screens[":screen"]:draw_box(0, 0,  manager.machine.screens[":screen"].width, manager.machine.screens[":screen"].height, COLOR_WHITE,COLOR_WHITE)			                  		         	                		           		          		       	 		          
		        else
		           gunlight_user_set.brightness = init_user_set.brightness
		           gunlight_user_set.contrast = init_user_set.contrast
		           gunlight_user_set.gamma = init_user_set.gamma
		        end		       
		        manager.machine.screens[":screen"].container.user_settings = gunlight_user_set		        
			state[2]:set_value(state[1])						
		end
	end

	local function load_settings()	
	        init_user_set = manager.machine.screens[":screen"].container.user_settings	        
		local loader = require('gunlight/gunlight_save')
		if loader then
			buttons = loader:load_settings()
		end
	end

	local function save_settings()
	        manager.machine.screens[":screen"].container.user_settings = init_user_set
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
