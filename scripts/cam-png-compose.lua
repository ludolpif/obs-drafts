obs = obslua

-- Good documentations
-- https://obsproject.com/wiki/Scripting-Tutorial-Halftone-Filter
-- https://docs.obsproject.com/reference-sources#c.obs_register_source
-- https://obsproject.com/forum/threads/tips-and-tricks-for-lua-scripts.132256/

-- How to see LOG_DEBUG message from this script from linux obs:
--   $ obs --verbose | grep the-script-filename
-- Others (undocumented ?) command line options in ./UI/obs-app.cpp
--   from obs git https://github.com/obsproject/obs-studio.git
--   search for "arg_is(" calls in the C source

-- How to see the resulting GLSL shader after .effect.hlsl pre-processing:
--   You have to use an obs compiled with $(cc) -D_DEBUG -DDEBUG_SHADERS ...
--   because of libobs/graphics/effect-parser.c:#if defined(_DEBUG) && defined(_DEBUG_SHADERS)
--   then start it with $ obs --verbose

-- Configurable constants you have to change if you duplicate this script to make a custom one
local source_id = 'cam-png-compose'
local source_version = 1
local effect_file_path = script_path()..source_id..'.effect.hlsl'
function source_get_name()
  -- as a function for translation purposes (could call l10n functions)
  return 'Camera PNG Compose'
end

-- Returns the description displayed in the Scripts window
-- OBS will call it "magically" (no registration / function pointer to be passed)
function script_description()
  return [[Video effect filter for camera background compositing using color keying and a static PNG.
  To configure it, please add a filter "]]..source_get_name()..[[" on a source, a group or a nested scene.]]
end

-- Definition of source_info lua table to eventually register this source into OBS
--   Most functions here are anonymously defined and their references are stored in this table
--   This allow OBS to call them as hooks from it's threads
--   Don't try to compile a shader outside video_render(), deadlocks happens *sometimes*
-- See https://docs.obsproject.com/scripting#script-sources-lua-only
local source_info = {}
source_info.id = source_id                      -- Unique string identifier of the source type
source_info.type = obs.OBS_SOURCE_TYPE_FILTER   -- INPUT or FILTER or TRANSITION
source_info.output_flags = obs.OBS_SOURCE_VIDEO -- Combination of VIDEO/AUDIO/ASYNC/etc
source_info.get_name = source_get_name
source_info.get_width = function(filter)
  return filter.width
end
source_info.get_height = function(filter)
  return filter.height
end
source_info.create = function(settings, source)
  obs.script_log(obs.LOG_DEBUG, "source_info.create called")
  -- Creates the implementation data for the source
  -- OBS variable name convention for the result of this: data.
  --   as is not to be confused with obs_data_t settings, here we call it: filter_impl_data.
  local filter_impl_data = {}
  filter_impl_data.source = source      -- Keeps a reference to this filter as a obs_source_t object
  filter_impl_data.width = 1            -- Dummy value during initialization phase
  filter_impl_data.height = 1           -- Dummy value during initialization phase
  filter_impl_data.lua_params = {}      -- lua table of filter's shader parameters values (as primitive lua types)
  filter_impl_data.gs_params = {}       -- lua table of opaque OBS type with graphic shaders parameters pointers to VRAM (uniform variables)
  filter_impl_data.gs_effect = nil      -- Handler of the compiled shader
  filter_impl_data.gs_compiled  = false -- Flag to keep track of last compilation try result
  filter_impl_data.gs_recompile = false -- Flag to trigger a shader recompile from source
  -- shader config data flow:
  --     (a) source settings --(b)--> lua_params (RAM) --(c)--> shaders uniform variables (VRAM)
  --
  -- (a) "settings" are a lua table of obs_data_t (https://docs.obsproject.com/reference-settings)
  --   On filter instance initialization, OBS loads "settings" from it's data_t persistent storage (JSON-like).
  --   OBS will call source_info.get_defaults() to set default values if there is new parameters
  --     or nothing value stored from previous OBS run or no previous run with this source instance.
  --   UI could change settings values through UI "properties" defined in source_info.get_properties()
  --   OBS hotkey system and API could change settings too.
  --   "settings" are already available to this source_info.create() hook.
  -- (b) settings values are copied to lua_params on source_info.update()
  --   The first call of source_info.update() is at end of this source_info.create().
  --   OBS will call source_info.update() on subsequent settings change events.
  -- (c) lua_params are pushed to the shader in VRAM, using gs_params metadata
  --   This is done at each frame, in source_info.video_render().

  source_info.update(filter_impl_data, settings)
  return filter_impl_data
end

source_info.destroy = function (filter_impl_data)
  -- Notes:
  --  calling obs.script_log() from here crashes OBS 29.1 !
  --  calling obs.obs_enter_graphics() from here leads to deadlocks *sometimes*
  --    (try 10 script reload via UI, likely a dead OBS)
  obs.blog(obs.LOG_INFO, "[Lua: "..source_id..".lua] source_info.destroy() called")
  if filter_impl_data.gs_effect ~= nil then
    obs.gs_effect_destroy(filter_impl_data.gs_effect)
  end
end

function compile_shader(filter_impl_data)
  -- Notes:
  --  calling obs.obs_enter_graphics() then obs.gs_effect_destroy(filter_impl_data.gs_effect) in source_info.destroy() crashes OBS 29.1
  --  calling compile_shader() in create() or update() hooks leads to deadlocks on obs_enter_graphics() *sometimes*
  --  obs.gs_effect_create() and obs.gs_effect_create_from_file() : can't find a way to get the char **error_string back to lua
  obs.obs_enter_graphics()

  local gse = nil
  if filter_impl_data.gs_recompile then
    filter_impl_data.gs_recompile = false
    -- gs_effect_create_from_file() use a file_path based cache in OBS, unsuitable for developement purposes
    local effect_source_code = obs.os_quick_read_utf8_file(effect_file_path)
    if effect_source_code then
      gse = obs.gs_effect_create(effect_source_code, effect_file_path, nil)
    end
  else
    gse = obs.gs_effect_create_from_file(effect_file_path, nil)
  end
  if gse == nil then
    obs.script_log(obs.LOG_ERROR, "Effect compilation failed for "..effect_file_path)
    filter_impl_data.gs_compiled = false
  else
    local gsp = {}
    -- Retrieves the shader uniform variables metadata/pointers
    -- gsp.width = obs.gs_effect_get_param_by_name(gse, "width")
    -- gsp.height = obs.gs_effect_get_param_by_name(gse, "height")
    gsp.mode          = obs.gs_effect_get_param_by_name(gse, "mode")
    gsp.draw_config   = obs.gs_effect_get_param_by_name(gse, "draw_config")
    gsp.bg_key_color  = obs.gs_effect_get_param_by_name(gse, "bg_key_color")
    gsp.bg_saturation = obs.gs_effect_get_param_by_name(gse, "bg_saturation")
    gsp.bg_blur       = obs.gs_effect_get_param_by_name(gse, "bg_blur")
    gsp.bg_mul_enable = obs.gs_effect_get_param_by_name(gse, "bg_mul_enable")
    gsp.bg_mul_color  = obs.gs_effect_get_param_by_name(gse, "bg_mul_color")
    gsp.similarity    = obs.gs_effect_get_param_by_name(gse, "similarity")
    gsp.smoothness    = obs.gs_effect_get_param_by_name(gse, "smoothness")
    -- replace the current gs_effect and gs_params by the new ones
    if filter_impl_data.gs_effect ~= nil then
      -- obs.script_log(obs.LOG_INFO, "Calling gs_effect_destroy() for previous "..effect_file_path)
      obs.gs_effect_destroy(filter_impl_data.gs_effect)
    end
    obs.script_log(obs.LOG_INFO, "Using newly compiled shader for "..effect_file_path)
    filter_impl_data.gs_effect = gse
    filter_impl_data.gs_params = gsp
    filter_impl_data.gs_compiled = true
  end
  obs.obs_leave_graphics()
  -- FIXME it seems there is leaks around there
  collectgarbage()
  obs.script_log(obs.LOG_INFO, "Number of memory allocations: "..tostring(obs.bnum_allocs()))
end

-- Called when rendering the source with the graphics subsystem
source_info.video_render = function(filter_impl_data)
  -- Notes:
  --   obs_filter_get_parent() only guaranteed to be valid inside of the
  --     video_render, filter_audio, filter_video, and filter_remove callbacks.

  if filter_impl_data.gs_effect == nil or filter_impl_data.gs_recompile then
    compile_shader(filter_impl_data)
  end
  if filter_impl_data.gs_effect == nil then
    obs.script_log(obs.LOG_ERROR, "video_render(): filter.gs_effect == nil")
    return -- XXX should call https://docs.obsproject.com/reference-sources#c.obs_source_default_render ?
  end
  local parent = obs.obs_filter_get_parent(filter_impl_data.source)
  filter_impl_data.width = obs.obs_source_get_base_width(parent)
  filter_impl_data.height = obs.obs_source_get_base_height(parent)
  local preferred_spaces = { obs.GS_CS_SRGB, obs.GS_CS_SRGB_16F, obs.GS_CS_709_EXTENDED }
  -- FIXME warning: [Lua: cam-png-compose.lua] Failed to call video_render [...] Error in obs_source_get_color_space (arg 3), expected 'enum gs_color_space const *' got 'table'
  -- local source_space = obs.obs_source_get_color_space(
  --   obs.obs_filter_get_target(filter_impl_data.context),
  --  3, -- TODO find count() in lua
  --  preferred_spaces
  -- )
  -- TODO check about GS_CS_709_EXTENDED seen in chroma-key-filter.c, have to understand why
  -- if (source_space == obs.GS_CS_709_EXTENDED) then
  --   if (not filter_impl_data.log_cs_done) then
  --     obs.script_log(obs.LOG_ERROR, "Unsupported color space "..tostring(source_space))
  --    end
  --  obs.obs_source_skip_video_filter(filter_impl_data.context)
  --  return
  -- end
  -- if (not filter_impl_data.log_cs_done) then
  --  obs.script_log(obs.LOG_INFO, "Supported color space "..tostring(source_space))
  -- end
  -- filter_impl_data.log_cs_done = true

  -- TODO Should use obs_source_process_filter_begin_with_color_space() ? See docs/sphinx/reference-sources.rst:1600
  if obs.obs_source_process_filter_begin(filter_impl_data.source, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING) then
    -- Update all needed parameters from RAM (lua_params) to VRAM (shader's uniform variables) at each frame
    -- obs.gs_effect_set_int(filter_impl_data.gs_params.width, filter_impl_data.width)
    -- obs.gs_effect_set_int(filter_impl_data.gs_params.height, filter_impl_data.height)
    obs.gs_effect_set_int  (filter_impl_data.gs_params.mode,          filter_impl_data.lua_params.mode)
    obs.gs_effect_set_bool (filter_impl_data.gs_params.draw_config,   filter_impl_data.lua_params.draw_config)
    obs.gs_effect_set_color(filter_impl_data.gs_params.bg_key_color,  filter_impl_data.lua_params.bg_key_color)
    obs.gs_effect_set_float(filter_impl_data.gs_params.bg_saturation, filter_impl_data.lua_params.bg_saturation)
    obs.gs_effect_set_float(filter_impl_data.gs_params.bg_blur,       filter_impl_data.lua_params.bg_blur)
    obs.gs_effect_set_bool (filter_impl_data.gs_params.bg_mul_enable, filter_impl_data.lua_params.bg_mul_enable)
    obs.gs_effect_set_color(filter_impl_data.gs_params.bg_mul_color,  filter_impl_data.lua_params.bg_mul_color)
    obs.gs_effect_set_float(filter_impl_data.gs_params.similarity,    filter_impl_data.lua_params.similarity)
    obs.gs_effect_set_float(filter_impl_data.gs_params.smoothness,    filter_impl_data.lua_params.smoothness)
    -- Draws the filter using the effect's technique Draw { ... }
    obs.obs_source_process_filter_end(filter_impl_data.source, filter_impl_data.gs_effect, filter_impl_data.width, filter_impl_data.height)
    -- XXX Alternative function:: void obs_source_process_filter_tech_end(obs_source_t *filter, gs_effect_t *effect, uint32_t width, uint32_t height, const char *tech_name)
  end
end
-- "settings" are instance of obs_data_t. Data settings objects are reference-counted objects that store values in a string-table or array. They’re similar to Json objects, but additionally allow additional functionality such as default or auto-selection values. Data is saved/loaded to/from Json text and Json text files.
-- Give to OBS default settings for this source (used in the UI by "Reset to default" button, or at source init if no previously saved value found)
source_info.get_defaults = function(settings)
  obs.script_log(obs.LOG_DEBUG, "source_info.get_defaults called")
  obs.obs_data_set_default_int   (settings, "mode",          1)
  obs.obs_data_set_default_bool  (settings, "draw_config",   false)
  obs.obs_data_set_default_int   (settings, "bg_key_color",  0x00ff00)
  obs.obs_data_set_default_double(settings, "bg_saturation", 1.0)
  obs.obs_data_set_default_double(settings, "bg_blur",       1.0)
  obs.obs_data_set_default_bool  (settings, "bg_mul_enable", false)
  obs.obs_data_set_default_int   (settings, "bg_mul_color",  0x2b2a32)
  obs.obs_data_set_default_int   (settings, "similarity",    80)
  obs.obs_data_set_default_int   (settings, "smoothness",    50)
end
-- Updates the live filter parameters upon settings change (live user change via UI or settings load from json-like OBS storage)
source_info.update = function(filter_impl_data, settings)
  obs.script_log(obs.LOG_DEBUG, "source_info.update called")
  local params = filter_impl_data.lua_params
  params.mode          = obs.obs_data_get_int   (settings, "mode")
  params.draw_config   = obs.obs_data_get_bool  (settings, "draw_config")
  params.bg_key_color  = obs.obs_data_get_int   (settings, "bg_key_color")
  params.bg_saturation = obs.obs_data_get_double(settings, "bg_saturation")
  params.bg_blur       = obs.obs_data_get_double(settings, "bg_blur")
  params.bg_mul_enable = obs.obs_data_get_bool  (settings, "bg_mul_enable")
  params.bg_mul_color  = obs.obs_data_get_int   (settings, "bg_mul_color")
  params.similarity    = obs.obs_data_get_int   (settings, "similarity") / 1000.0
  params.smoothness    = obs.obs_data_get_int   (settings, "smoothness") / 1000.0
end
-- Create UI items in the filter config pane
source_info.get_properties = function(filter_impl_data)
  obs.script_log(obs.LOG_DEBUG, "source_info.get_properties called")
  local props = obs.obs_properties_create()
  -- on-the-fly recompile button (for shader developper)
  obs.obs_properties_add_button(props, "recompile_btn", "Recompile now",
    function (properties, property)
      filter_impl_data.gs_recompile = true
    end
  )
  -- Mode selector
  MY_OPTIONS = {"Re-use cam background", "Remove cam background"}
  local plist = obs.obs_properties_add_list(props, "mode", "Mode", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
  obs.obs_property_list_add_int(plist, "Re-use cam background", 1)
  obs.obs_property_list_add_int(plist, "Remove cam background", 2)
  obs.obs_property_set_modified_callback(plist, on_filter_ui_conditions_changed)
  -- Other shader properties
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
