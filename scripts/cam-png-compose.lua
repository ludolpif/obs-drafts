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
  -- data.params.width = obs.gs_effect_get_param_by_name(data.effect, "width")
  -- data.params.height = obs.gs_effect_get_param_by_name(data.effect, "height")
  data.params.mode = obs.gs_effect_get_param_by_name(data.effect, "mode")
  data.params.bg_key_color = obs.gs_effect_get_param_by_name(data.effect, "bg_key_color")
  data.params.bg_saturation = obs.gs_effect_get_param_by_name(data.effect, "bg_saturation")
  data.params.bg_blur = obs.gs_effect_get_param_by_name(data.effect, "bg_blur")
  data.params.bg_mul_enable = obs.gs_effect_get_param_by_name(data.effect, "bg_mul_enable")
  data.params.bg_mul_color = obs.gs_effect_get_param_by_name(data.effect, "bg_mul_color")
  data.params.similarity = obs.gs_effect_get_param_by_name(data.effect, "similarity")
  data.params.smoothness = obs.gs_effect_get_param_by_name(data.effect, "smoothness")
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
  -- obs.gs_effect_set_int(data.params.width, data.width)
  -- obs.gs_effect_set_int(data.params.height, data.height)
  obs.gs_effect_set_int(data.params.mode, data.mode)
  obs.gs_effect_set_color(data.params.bg_key_color, data.bg_key_color)
  obs.gs_effect_set_float(data.params.bg_saturation, data.bg_saturation)
  obs.gs_effect_set_float(data.params.bg_blur, data.bg_blur)
  obs.gs_effect_set_bool(data.params.bg_mul_enable, data.bg_mul_enable)
  obs.gs_effect_set_color(data.params.bg_mul_color, data.bg_mul_color)
  obs.gs_effect_set_float(data.params.similarity, data.similarity)
  obs.gs_effect_set_float(data.params.smoothness, data.smoothness)

  obs.obs_source_process_filter_end(data.source, data.effect, data.width, data.height)
end
-- Give to OBS default settings for this source (UI "Reset to defaults" button)
source_info.get_defaults = function(settings)
  obs.blog(obs.LOG_INFO, "source_info.get_defaults called")
  obs.obs_data_set_default_int(settings, "mode", 1)
  obs.obs_data_set_default_int(settings, "bg_key_color", 0x00ff00)
  obs.obs_data_set_default_double(settings, "bg_saturation", 1.0)
  obs.obs_data_set_default_double(settings, "bg_blur", 1.0)
  obs.obs_data_set_default_bool(settings, "bg_mul_enable", false)
  obs.obs_data_set_default_int(settings, "bg_mul_color", 0x2b2a32)
  obs.obs_data_set_default_int(settings, "similarity", 80)
  obs.obs_data_set_default_int(settings, "smoothness", 50)
end
-- Updates the internal data for this source upon settings change
source_info.update = function(data, settings)
  obs.blog(obs.LOG_INFO, "source_info.update called")
  data.mode = obs.obs_data_get_int(settings, "mode")
  data.bg_key_color = obs.obs_data_get_int(settings, "bg_key_color")
  data.bg_saturation = obs.obs_data_get_double(settings, "bg_saturation")
  data.bg_blur = obs.obs_data_get_double(settings, "bg_blur")
  data.bg_mul_enable = obs.obs_data_get_bool(settings, "bg_mul_enable")
  data.bg_mul_color = obs.obs_data_get_int(settings, "bg_mul_color")
  data.similarity = obs.obs_data_get_int(settings, "similarity") / 1000.0
  data.smoothness = obs.obs_data_get_int(settings, "smoothness") / 1000.0
end
-- Create UI items in the filter config pane
source_info.get_properties = function(data)
  obs.blog(obs.LOG_INFO, "source_info.get_properties called")
  local props = obs.obs_properties_create()
  -- Mode selector
  MY_OPTIONS = {"Re-use cam background", "Remove cam background"}
  local plist = obs.obs_properties_add_list(props, "mode", "Mode", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
  obs.obs_property_list_add_int(plist, "Re-use cam background", 1)
  obs.obs_property_list_add_int(plist, "Remove cam background", 2)
  obs.obs_property_set_modified_callback(plist, on_filter_ui_conditions_changed)
  -- Other controls
  obs.obs_properties_add_color(props, "bg_key_color", "Background key color")
  obs.obs_properties_add_float_slider(props, "bg_saturation", "Background saturation", 0.0, 1.0, 0.01)
  obs.obs_properties_add_float_slider(props, "bg_blur", "Background blur strengh", 0.0, 8.0, 0.01)
  local pbg_mul_enable = obs.obs_properties_add_bool(props, "bg_mul_enable", "Enable background color multiplier")
  obs.obs_property_set_modified_callback(pbg_mul_enable, on_filter_ui_conditions_changed)
  obs.obs_properties_add_color(props, "bg_mul_color", "Background color")
  obs.obs_properties_add_int_slider(props, "similarity", "Key color similarity", 0, 1000, 1)
  obs.obs_properties_add_int_slider(props, "smoothness", "Bg removal smoothness", 0, 1000, 1)
  data.props = props
  return props
end
-- Callback on list or booleans modification
function on_filter_ui_conditions_changed(props, property, settings)
  local mode = obs.obs_data_get_int(settings, "mode")
  local bg_mul_enable = obs.obs_data_get_bool(settings, "bg_mul_enable")
  -- Disable UI items depending on mode and booleans, FIXME it is not refreshed by "Set defaults values" button is pressed
  obs.obs_property_set_enabled(obs.obs_properties_get(props, "bg_saturation"), mode==1)
  obs.obs_property_set_enabled(obs.obs_properties_get(props, "bg_blur"), mode==1)
  obs.obs_property_set_enabled(obs.obs_properties_get(props, "bg_mul_enable"), mode==1)
  obs.obs_property_set_enabled(obs.obs_properties_get(props, "bg_mul_color"), mode==1 and bg_mul_enable)
  return true -- IMPORTANT: returns true to trigger refresh of the properties
end

-- Debug "tools"
function log_globals()
  for key, value in pairs(_G) do
    print("Global " .. type(value) .. ": " .. key .. " = " .. tostring(value))
  end
end
