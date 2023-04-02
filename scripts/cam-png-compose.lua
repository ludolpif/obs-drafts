obs = obslua

-- Good documentations
-- https://obsproject.com/wiki/Scripting-Tutorial-Halftone-Filter
-- https://docs.obsproject.com/reference-sources#c.obs_register_source
-- https://obsproject.com/forum/threads/tips-and-tricks-for-lua-scripts.132256/

-- Things to change if you duplicate this script to make a custom one
source_id = 'cam-png-compose'
filter_name = 'Camera PNG Compose'
effect_file_path = script_path()..source_id..'.effect.hlsl'

-- Returns the description displayed in the Scripts window
function script_description()
  return [[Video effect filter for camera background compositing using color keying and png.
  To configure it, please add a filter "]]..filter_name..[[" on a source, a group or a nested scene.]]
end
-- Called on script startup
function script_load(settings)
  local logline = string.format("Registering source %s (%s)", source_info.id, source_info.get_name())
  obs.script_log(obs.LOG_INFO, logline)
  obs.obs_register_source(source_info)
end

-- Definition of the global variable containing the source_info structure
source_info = {}
source_info.id = source_id                      -- Unique string identifier of the source type
source_info.type = obs.OBS_SOURCE_TYPE_FILTER   -- INPUT or FILTER or TRANSITION
source_info.output_flags = obs.OBS_SOURCE_VIDEO -- Combination of VIDEO/AUDIO/ASYNC/etc
source_info.get_name = function()
  return filter_name -- name displayed in the list of filters
end
source_info.get_width = function(data)
  return data.width
end
source_info.get_height = function(data)
  return data.height
end
source_info.destroy = function(data)
  if data.effect ~= nil then
    obs.obs_enter_graphics()
    obs.gs_effect_destroy(data.effect)
    data.effect = nil
    obs.obs_leave_graphics()
  end
end
-- Creates the implementation data for the source
source_info.create = function(settings, source)
  -- Initializes the custom data table
  local data = {}
  data.source = source -- Keeps a reference to this filter as a source object
  data.width = 1       -- Dummy value during initialization phase
  data.height = 1      -- Dummy value during initialization phase
  -- Compiles the effect
  obs.obs_enter_graphics()
  data.effect = obs.gs_effect_create_from_file(effect_file_path, nil)
  obs.obs_leave_graphics()
  -- Calls the destroy function if the effect was not compiled properly
  if data.effect == nil then
    obs.blog(obs.LOG_ERROR, "Effect compilation failed for " .. effect_file_path)
    source_info.destroy(data)
    return nil
  end
  obs.blog(obs.LOG_INFO, "Effect compilation success for " .. effect_file_path)
  -- Retrieves the shader uniform variables
  data.params = {}
  data.params.width = obs.gs_effect_get_param_by_name(data.effect, "width")
  data.params.height = obs.gs_effect_get_param_by_name(data.effect, "height")
  data.params.gamma = obs.gs_effect_get_param_by_name(data.effect, "gamma")
  data.params.gamma_shift = obs.gs_effect_get_param_by_name(data.effect, "gamma_shift")
  data.params.amplitude = obs.gs_effect_get_param_by_name(data.effect, "amplitude")
  data.params.scale = obs.gs_effect_get_param_by_name(data.effect, "scale")
  data.params.number_of_color_levels = obs.gs_effect_get_param_by_name(data.effect, "number_of_color_levels")
  -- Calls update to initialize the rest of the properties-managed settings
  source_info.update(data, settings)
  return data
end
-- Called when rendering the source with the graphics subsystem
source_info.video_render = function(data)
  local parent = obs.obs_filter_get_parent(data.source)
  data.width = obs.obs_source_get_base_width(parent)
  data.height = obs.obs_source_get_base_height(parent)

  obs.obs_source_process_filter_begin(data.source, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

  -- Effect parameters initialization goes here
  obs.gs_effect_set_int(data.params.width, data.width)
  obs.gs_effect_set_int(data.params.height, data.height)
  obs.gs_effect_set_float(data.params.gamma, data.gamma)
  obs.gs_effect_set_float(data.params.gamma_shift, data.gamma_shift)
  obs.gs_effect_set_float(data.params.amplitude, data.amplitude)
  obs.gs_effect_set_float(data.params.scale, data.scale)
  obs.gs_effect_set_int(data.params.number_of_color_levels, data.number_of_color_levels)

  obs.obs_source_process_filter_end(data.source, data.effect, data.width, data.height)
end
-- Create UI items in the filter config pane
source_info.get_properties = function(data)
  local props = obs.obs_properties_create()
  obs.obs_properties_add_float_slider(props, "gamma", "Gamma encoding exponent", 1.0, 2.2, 0.2)
  obs.obs_properties_add_float_slider(props, "gamma_shift", "Gamma shift", -2.0, 2.0, 0.01)
  obs.obs_properties_add_float_slider(props, "scale", "Pattern scale", 0.01, 10.0, 0.01)
  obs.obs_properties_add_float_slider(props, "amplitude", "Perturbation amplitude", 0.0, 2.0, 0.01)
  obs.obs_properties_add_int_slider(props, "number_of_color_levels", "Number of color levels", 2, 10, 1)
  return props
end
-- Give to OBS default settings for this source
source_info.get_defaults = function(settings)
  obs.obs_data_set_default_double(settings, "gamma", 1.0)
  obs.obs_data_set_default_double(settings, "gamma_shift", 0.0)
  obs.obs_data_set_default_double(settings, "scale", 1.0)
  obs.obs_data_set_default_double(settings, "amplitude", 0.2)
  obs.obs_data_set_default_int(settings, "number_of_color_levels", 4)
end
-- Updates the internal data for this source upon settings change
source_info.update = function(data, settings)
  data.gamma = obs.obs_data_get_double(settings, "gamma")
  data.gamma_shift = obs.obs_data_get_double(settings, "gamma_shift")
  data.scale = obs.obs_data_get_double(settings, "scale")
  data.amplitude = obs.obs_data_get_double(settings, "amplitude")
  data.number_of_color_levels = obs.obs_data_get_int(settings, "number_of_color_levels")
end






















-- Debug tools
function log_globals()
  for key, value in pairs(_G) do
    print("Global " .. type(value) .. ": " .. key .. " = " .. tostring(value))
  end
end


-- UI items to let the user choose settings
function disabled_script_properties()
  local properties = obs.obs_properties_create()

  -- Combo list filled with the options from MY_OPTIONS
  local plist = obs.obs_properties_add_list(properties, "mode", "Mode",
              obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
  MY_OPTIONS = {"Mode 1", "Mode 2"}
  for i,v in ipairs(MY_OPTIONS) do
    obs.obs_property_list_add_int(plist, v, i)
  end
  -- Sets callback upon modification of the list
  obs.obs_property_set_modified_callback(plist, ui_mode_changed_callback)

  obs.obs_properties_add_int(properties, "mynumber", "My number in Mode 1", 1, 10, 1)
  obs.obs_properties_add_color(properties, "mycolor", "My color in Mode 2")

  -- Calls the callback once to set-up current visibility
  obs.obs_properties_apply_settings(properties, my_settings)
  
  return properties
end
-- Callback on UI list modification
function ui_mode_changed_callback(props, property, settings)
  -- counter = counter + 1
  -- obs.script_log(obs.LOG_INFO, string.format("hello %d", counter))
  local mode = obs.obs_data_get_int(settings, "mode")
  obs.obs_property_set_visible(obs.obs_properties_get(props, "mynumber"), mode==1)
  obs.obs_property_set_visible(obs.obs_properties_get(props, "mycolor"), mode==2)
  return true  -- IMPORTANT: returns true to trigger refresh of the properties
end
