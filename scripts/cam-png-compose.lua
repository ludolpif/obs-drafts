obs = obslua

-- Good documentations
-- https://obsproject.com/wiki/Scripting-Tutorial-Halftone-Filter
-- https://docs.obsproject.com/reference-sources#c.obs_register_source
-- https://obsproject.com/forum/threads/tips-and-tricks-for-lua-scripts.132256/

-- How to see LOG_DEBUG message from this script from linux obs ?
-- $ obs --verbose | grep the-script-name-here
-- Others (undocumented ?) command line options in ./UI/obs-app.cpp
-- from obs git https://github.com/obsproject/obs-studio.git
-- search for "arg_is(" calls in the C source

-- How to see the resulting GLSL shader after .effect (HLSL variant) pre-processing ?
-- You have to use an obs compiled with $(cc) -D_DEBUG -DDEBUG_SHADERS ...
-- libobs/graphics/effect-parser.c:#if defined(_DEBUG) && defined(_DEBUG_SHADERS)
-- then start it with $ obs --verbose

-- Things to change if you duplicate this script to make a custom one
local source_id = 'cam-png-compose'
local source_version = 1
local filter_name = 'Camera PNG Compose'
local effect_file_path = script_path()..source_id..'.effect.hlsl'

-- Returns the description displayed in the Scripts window
function script_description()
  return [[Video effect filter for camera background compositing using color keying and png.
  To configure it, please add a filter "]]..filter_name..[[" on a source, a group or a nested scene.]]
end

-- Definition of the global variable containing the source_info structure
-- See https://docs.obsproject.com/scripting#script-sources-lua-only
local source_info = {}
source_info.id = source_id                      -- Unique string identifier of the source type
source_info.type = obs.OBS_SOURCE_TYPE_FILTER   -- INPUT or FILTER or TRANSITION
source_info.output_flags = obs.OBS_SOURCE_VIDEO -- Combination of VIDEO/AUDIO/ASYNC/etc
source_info.get_name = function()
  return filter_name                            -- name displayed in the list of filters
end
source_info.get_width = function(filter)
  return filter.width
end
source_info.get_height = function(filter)
  return filter.height
end
-- Creates the implementation data for the source
source_info.create = function(settings, source)
  obs.script_log(obs.LOG_DEBUG, "source_info.create called")
  -- Initializes the custom data table
  local filter = {}
  filter.source = source -- Keeps a reference to this filter as a source object
  filter.width = 1       -- Dummy value during initialization phase
  filter.height = 1      -- Dummy value during initialization phase
  filter.log_cs_done = false
  filter.params = {}

  obs.obs_enter_graphics()
  -- Compiles the effect
  filter.effect = obs.gs_effect_create_from_file(effect_file_path, nil)
  -- Note: calling obs.obs_enter_graphics() then obs.gs_effect_destroy(filter.effect) in source_info.destroy crashes OBS
  -- Retrieves the shader uniform variables (if compiled)
  if filter.effect then
    -- filter.params.width = obs.gs_effect_get_param_by_name(filter.effect, "width")
    -- filter.params.height = obs.gs_effect_get_param_by_name(filter.effect, "height")
    filter.params.mode          = obs.gs_effect_get_param_by_name(filter.effect, "mode")
    filter.params.draw_config   = obs.gs_effect_get_param_by_name(filter.effect, "draw_config")
    filter.params.bg_key_color  = obs.gs_effect_get_param_by_name(filter.effect, "bg_key_color")
    filter.params.bg_saturation = obs.gs_effect_get_param_by_name(filter.effect, "bg_saturation")
    filter.params.bg_blur       = obs.gs_effect_get_param_by_name(filter.effect, "bg_blur")
    filter.params.bg_mul_enable = obs.gs_effect_get_param_by_name(filter.effect, "bg_mul_enable")
    filter.params.bg_mul_color  = obs.gs_effect_get_param_by_name(filter.effect, "bg_mul_color")
    filter.params.similarity    = obs.gs_effect_get_param_by_name(filter.effect, "similarity")
    filter.params.smoothness    = obs.gs_effect_get_param_by_name(filter.effect, "smoothness")
  end
  obs.obs_leave_graphics()

  if filter.effect == nil then
    obs.script_log(obs.LOG_ERROR, "Effect compilation failed for "..effect_file_path)
    return nil
  end
  obs.script_log(obs.LOG_INFO, "Effect compilation success for "..effect_file_path)
  -- Calls update to initialize the rest of the properties-managed settings
  -- XXX note threading issue prevention in https://docs.obsproject.com/reference-sources#c.obs_source_update
  source_info.update(filter, settings)
  return filter
end
-- Called when rendering the source with the graphics subsystem
source_info.video_render = function(filter)
  -- FIXME should bail out if effect destroyed ?
  if filter.effect == nil then
    obs.script_log(obs.LOG_ERROR, "video_render() called on filter.effect == nil")
    return -- XXX should call https://docs.obsproject.com/reference-sources#c.obs_source_default_render ?
  end
  -- obs_filter_get_parent() only guaranteed to be valid inside of the
  --  video_render, filter_audio, filter_video, and filter_remove callbacks.
  local parent = obs.obs_filter_get_parent(filter.source)
  filter.width = obs.obs_source_get_base_width(parent)
  filter.height = obs.obs_source_get_base_height(parent)
  local preferred_spaces = { obs.GS_CS_SRGB, obs.GS_CS_SRGB_16F, obs.GS_CS_709_EXTENDED }
  -- FIXME warning: [Lua: cam-png-compose.lua] Failed to call video_render [...] Error in obs_source_get_color_space (arg 3), expected 'enum gs_color_space const *' got 'table'
  -- local source_space = obs.obs_source_get_color_space(
  --   obs.obs_filter_get_target(filter.context),
  --  3, -- TODO find count() in lua
  --  preferred_spaces
  -- )
  -- TODO check about GS_CS_709_EXTENDED seen in chroma-key-filter.c, have to understand why
  -- if (source_space == obs.GS_CS_709_EXTENDED) then
  --   if (not filter.log_cs_done) then
  --     obs.script_log(obs.LOG_ERROR, "Unsupported color space "..tostring(source_space))
  --    end
  --  obs.obs_source_skip_video_filter(filter.context)
  --  return
  -- end
  -- if (not filter.log_cs_done) then
  --  obs.script_log(obs.LOG_INFO, "Supported color space "..tostring(source_space))
  -- end
  -- filter.log_cs_done = true

  -- TODO Should use obs_source_process_filter_begin_with_color_space() ? See docs/sphinx/reference-sources.rst:1600
  if obs.obs_source_process_filter_begin(filter.source, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING) then
    -- Effect parameters initialization goes here
    -- obs.gs_effect_set_int(filter.params.width, filter.width)
    -- obs.gs_effect_set_int(filter.params.height, filter.height)
    obs.gs_effect_set_int  (filter.params.mode,          filter.mode)
    obs.gs_effect_set_bool (filter.params.draw_config,   filter.draw_config)
    obs.gs_effect_set_color(filter.params.bg_key_color,  filter.bg_key_color)
    obs.gs_effect_set_float(filter.params.bg_saturation, filter.bg_saturation)
    obs.gs_effect_set_float(filter.params.bg_blur,       filter.bg_blur)
    obs.gs_effect_set_bool (filter.params.bg_mul_enable, filter.bg_mul_enable)
    obs.gs_effect_set_color(filter.params.bg_mul_color,  filter.bg_mul_color)
    obs.gs_effect_set_float(filter.params.similarity,    filter.similarity)
    obs.gs_effect_set_float(filter.params.smoothness,    filter.smoothness)
    -- Draws the filter using the effect's "Draw" technique
    obs.obs_source_process_filter_end(filter.source, filter.effect, filter.width, filter.height)
    -- XXX Alternative function:: void obs_source_process_filter_tech_end(obs_source_t *filter, gs_effect_t *effect, uint32_t width, uint32_t height, const char *tech_name)
  end
end
-- "settings" are instance of obs_data_t. Data settings objects are reference-counted objects that store values in a string-table or array. They’re similar to Json objects, but additionally allow additional functionality such as default or auto-selection values. Data is saved/loaded to/from Json text and Json text files.
-- Give to OBS default settings for this source (UI "Reset to defaults" button)
source_info.get_defaults = function(settings)
  obs.script_log(obs.LOG_DEBUG, "source_info.get_defaults called")
  obs.obs_data_set_default_int   (settings, "mode",          1)
  obs.obs_data_set_default_bool  (settings, "draw_config", false)
  obs.obs_data_set_default_int   (settings, "bg_key_color",  0x00ff00)
  obs.obs_data_set_default_double(settings, "bg_saturation", 1.0)
  obs.obs_data_set_default_double(settings, "bg_blur",       1.0)
  obs.obs_data_set_default_bool  (settings, "bg_mul_enable", false)
  obs.obs_data_set_default_int   (settings, "bg_mul_color",  0x2b2a32)
  obs.obs_data_set_default_int   (settings, "similarity",    80)
  obs.obs_data_set_default_int   (settings, "smoothness",    50)
end
-- Updates the internal data for this source upon settings change
source_info.update = function(data, settings)
  obs.script_log(obs.LOG_DEBUG, "source_info.update called")
  data.mode          = obs.obs_data_get_int   (settings, "mode")
  data.draw_config   = obs.obs_data_get_bool(settings, "draw_config")
  data.bg_key_color  = obs.obs_data_get_int   (settings, "bg_key_color")
  data.bg_saturation = obs.obs_data_get_double(settings, "bg_saturation")
  data.bg_blur       = obs.obs_data_get_double(settings, "bg_blur")
  data.bg_mul_enable = obs.obs_data_get_bool  (settings, "bg_mul_enable")
  data.bg_mul_color  = obs.obs_data_get_int   (settings, "bg_mul_color")
  data.similarity    = obs.obs_data_get_int   (settings, "similarity") / 1000.0
  data.smoothness    = obs.obs_data_get_int   (settings, "smoothness") / 1000.0
end
-- Create UI items in the filter config pane
source_info.get_properties = function(data)
  obs.script_log(obs.LOG_DEBUG, "source_info.get_properties called")
  local props = obs.obs_properties_create()
  -- Mode selector
  MY_OPTIONS = {"Re-use cam background", "Remove cam background"}
  local plist = obs.obs_properties_add_list(props, "mode", "Mode", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
  obs.obs_property_list_add_int(plist, "Re-use cam background", 1)
  obs.obs_property_list_add_int(plist, "Remove cam background", 2)
  obs.obs_property_set_modified_callback(plist, on_filter_ui_conditions_changed)
  -- Other controls
  obs.obs_properties_add_bool         (props, "draw_config",   "Draw configuration visuals")
  obs.obs_properties_add_color        (props, "bg_key_color",  "Background key color")
  obs.obs_properties_add_float_slider (props, "bg_saturation", "Background saturation", 0.0, 1.0, 0.01)
  obs.obs_properties_add_float_slider (props, "bg_blur",       "Background blur strengh", 0.0, 8.0, 0.01)
  local pbg_mul_enable =
    obs.obs_properties_add_bool       (props, "bg_mul_enable", "Enable background color multiplier")
  obs.obs_property_set_modified_callback(pbg_mul_enable, on_filter_ui_conditions_changed)
  obs.obs_properties_add_color        (props, "bg_mul_color", "Background color")
  obs.obs_properties_add_int_slider   (props, "similarity",   "Key color similarity", 0, 1000, 1)
  obs.obs_properties_add_int_slider   (props, "smoothness",   "Bg removal smoothness", 0, 1000, 1)
  return props
end
-- Callback on list or booleans modification
function on_filter_ui_conditions_changed(props, property, settings)
  local mode = obs.obs_data_get_int(settings, "mode")
  local bg_mul_enable = obs.obs_data_get_bool(settings, "bg_mul_enable")
  -- Disable UI items depending on mode and booleans,
  -- FIXME it is not refreshed by "Set defaults values" button is pressed, it happens also on obs-filter c plugins
  obs.obs_property_set_enabled(obs.obs_properties_get(props, "bg_saturation"), mode==1)
  obs.obs_property_set_enabled(obs.obs_properties_get(props, "bg_blur"),       mode==1)
  obs.obs_property_set_enabled(obs.obs_properties_get(props, "bg_mul_enable"), mode==1)
  obs.obs_property_set_enabled(obs.obs_properties_get(props, "bg_mul_color"),  mode==1 and bg_mul_enable)
  return true -- IMPORTANT: returns true to trigger refresh of the properties
end

-- Debug "tools"
function log_globals()
  for key, value in pairs(_G) do
    print("Global "..type(value)..": "..key.." = "..tostring(value))
  end
end
-- https://gist.github.com/lunixbochs/5b0bb27861a396ab7a86
local function _var_dump(o, indent)
    if indent == nil then indent = '' end
    local indent2 = indent..'  '
    if type(o) == 'table' then
        local s = indent..'{'..'\n'
        local first = true
        for k,v in pairs(o) do
            if first == false then s = s..', \n' end
            if type(k) ~= 'number' then k = '"'..string(k)..'"' end
            s = s..indent2..'['..k..'] = '.._var_dump(v, indent2)
            first = false
        end
        return s..'\n'..indent..'}'
    else
        return '"('..type(o)..') '..tostring(o)..'"'
    end
end

function var_dump(...)
    local args = {...}
    if #args > 1 then
        var_dump(args)
    else
        print(_var_dump(args[1]))
    end
end

obs.obs_register_source(source_info)
