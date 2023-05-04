function script_description()
  return [[Crash test script. Please add a filter on a source, a group or a nested scene.]]
end
function script_load()
  -- obslua.script_log(obslua.LOG_DEBUG, "script_load() called")
end
function script_unload()
  -- obslua.script_log(obslua.LOG_DEBUG, "script_unload() called")
end
-- See https://docs.obsproject.com/scripting#script-sources-lua-only
local info = {}
info.id = 'crashtest'
info.type = obslua.OBS_SOURCE_TYPE_FILTER
info.output_flags = obslua.OBS_SOURCE_VIDEO
info.get_name = function()
  return 'Crash test filter'
end
info.create = function(settings, source)
  -- obslua.script_log(obslua.LOG_DEBUG, "info.create called")
  local my_source_data = {}
  my_source_data.width = 320
  my_source_data.height = 200
  return my_source_data
end
info.destroy = function()
  -- obslua.script_log(obslua.LOG_DEBUG, "info.destroy called")
end
info.video_render = function(my_source_data, effect)
  -- obslua.script_log(obslua.LOG_DEBUG, "info.video_render called")
  return nil
end
info.get_width = function(my_source_data)
  return my_source_data.width
end
info.get_height = function(my_source_data)
  return my_source_data.height
end
-- obslua.script_log(obslua.LOG_DEBUG, "registering source "..info.id)
obslua.obs_register_source(info)
