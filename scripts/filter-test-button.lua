obs = obslua
function script_description()
  return [[Test button filter.
  Demo of obs.obs_properties_add_button() to modify filter implementation data
  allowing doing action in render thread at next frame.
  It takes a closure to circumvent the lack of userdata in callback arguments.]]
end
function script_load(settings)
  obs.obs_register_source(source_info)
end
source_info = {}
source_info.id = 'filter-test-button'
source_info.type = obs.OBS_SOURCE_TYPE_FILTER
source_info.output_flags = obs.OBS_SOURCE_VIDEO
source_info.get_name = function() return "Test button filter"; end
source_info.create = function(settings, source)
  local filter_impl_data = {}
  filter_impl_data.test_value = false
  -- [...]
  return filter_impl_data
end
source_info.get_properties = function(filter_impl_data)
  local props = obs.obs_properties_create()
  obs.obs_properties_add_button(props, "btn_test", "Test button",
    function(properties, property) filter_impl_data.test_value = true; end)
  return props
end
source_info.video_render = function(filter_impl_data)
  if ( filter_impl_data.test_value ) then
    obs.script_log(obs.LOG_INFO, "video_render: test_value true -> false")
    filter_impl_data.test_value = false
  end
end
