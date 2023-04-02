import obspython as obs
#import urllib.request
#import urllib.error
#
#url         = ""
#interval    = 30
source_name = ""
#
## ------------------------------------------------------------
#
# def obs_source_set_muted(source: "obs_source_t *", muted: "bool") -> "void":
# def obs_source_muted(source: "obs_source_t const *") -> "bool":
# def os_quick_read_utf8_file(path: "char const *") -> "char *":
# def os_safe_replace(target_path: "char const *", from_path: "char const *", backup_path: "char const *") -> "int":
# def obs_frontend_set_preview_enabled(enable: "bool") -> "void":
# def obs_frontend_set_current_preview_scene(scene: "obs_source_t *") -> "void":
# def obs_frontend_replay_buffer_start() -> "void":
# def obs_frontend_replay_buffer_save() -> "void":
# def obs_frontend_replay_buffer_stop() -> "void":
# def obs_frontend_replay_buffer_active() -> "bool":
# def obs_frontend_take_screenshot() -> "void":
# def obs_frontend_take_source_screenshot(source: "obs_source_t *") -> "void":



def do_something(props, prop):
    global source_name
    obs_ver = obs.obs_get_version_string()
    obs.script_log(obs.LOG_INFO, f"do_something() fired on OBS {obs_ver}")
    master_vol = obs.obs_get_master_volume()
    obs.script_log(obs.LOG_INFO, f"master_vol == {master_vol}")
    obs.obs_set_master_volume(0.5)

    source = obs.obs_get_source_by_name(source_name)
    if source is not None:
        obs.script_log(obs.LOG_INFO, "source is not None")
        is_hidden = obs.obs_source_is_hidden(source)
        obs.script_log(obs.LOG_INFO, f"source is_hidden {is_hidden}")
        obs.obs_source_set_hidden(source, not is_hidden)
        is_hidden = obs.obs_source_is_hidden(source)
        obs.script_log(obs.LOG_INFO, f"source is_hidden {is_hidden}")
        obs.obs_source_release(source)
#def update_text():
#    global url
#    global interval
#    global source_name
#
#    source = obs.obs_get_source_by_name(source_name)
#    if source is not None:
#        try:
#            with urllib.request.urlopen(url) as response:
#                data = response.read()
#                text = data.decode('utf-8')
#
#                settings = obs.obs_data_create()
#                obs.obs_data_set_string(settings, "text", text)
#                obs.obs_source_update(source, settings)
#                obs.obs_data_release(settings)
#
#        except urllib.error.URLError as err:
#            obs.script_log(obs.LOG_WARNING, "Error opening URL '" + url + "': " + err.reason)
#            obs.remove_current_callback()
#
#        obs.obs_source_release(source)
#
#class obs_transform_info(object):
#    r"""Proxy of C obs_transform_info struct."""
#
#    thisown = property(lambda x: x.this.own(), lambda x, v: x.this.own(v), doc="The membership flag")
#    __repr__ = _swig_repr
#    pos: "struct vec2" = property(_obspython.obs_transform_info_pos_get, _obspython.obs_transform_info_pos_set, doc=r"""pos""")
#    rot: "float" = property(_obspython.obs_transform_info_rot_get, _obspython.obs_transform_info_rot_set, doc=r"""rot""")
#    scale: "struct vec2" = property(_obspython.obs_transform_info_scale_get, _obspython.obs_transform_info_scale_set, doc=r"""scale""")
#    alignment: "uint32_t" = property(_obspython.obs_transform_info_alignment_get, _obspython.obs_transform_info_alignment_set, doc=r"""alignment""")
#    bounds_type: "enum obs_bounds_type" = property(_obspython.obs_transform_info_bounds_type_get, _obspython.obs_transform_info_bounds_type_set, doc=r"""bounds_type""")
#    bounds_alignment: "uint32_t" = property(_obspython.obs_transform_info_bounds_alignment_get, _obspython.obs_transform_info_bounds_alignment_set, doc=r"""bounds_alignment""")
#    bounds: "struct vec2" = property(_obspython.obs_transform_info_bounds_get, _obspython.obs_transform_info_bounds_set, doc=r"""bounds""")

# ------------------------------------------------------------

def script_description():
    return """Contrôle d'OBS avec un Novatim LaunchKey Mini II.
    Copyright 2023, Ludolpif
    Licence: GPL3"""

def script_update(settings):
#    global url
#    global interval
    global source_name
#
#    url         = obs.obs_data_get_string(settings, "url")
#    interval    = obs.obs_data_get_int(settings, "interval")
    source_name = obs.obs_data_get_string(settings, "source")
#
#    obs.timer_remove(update_text)
#
#    if url != "" and source_name != "":
#        obs.timer_add(update_text, interval * 1000)

#def script_defaults(settings):
#    obs.obs_data_set_default_int(settings, "interval", 30)

def script_properties():
    props = obs.obs_properties_create()

#    obs.obs_properties_add_text(props, "url", "URL", obs.OBS_TEXT_DEFAULT)
#    obs.obs_properties_add_int(props, "interval", "Update Interval (seconds)", 5, 3600, 1)

    p = obs.obs_properties_add_list(props, "source", "Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    sources = obs.obs_enum_sources()
    if sources is not None:
        for source in sources:
            source_id = obs.obs_source_get_unversioned_id(source)
            #if source_id == "text_gdiplus" or source_id == "text_ft2_source":
            name = obs.obs_source_get_name(source)
            obs.obs_property_list_add_string(p, name, name)

        obs.source_list_release(sources)

    p = obs.obs_properties_add_list(props, "scene", "Scene", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
#    scenes = obs.obs_enum_scenes()
#    if scenes is not None:
#        for scene in scenes:
#            scene_id = obs.obs_scene_get_unversioned_id(scene)
#            #if scene_id == "text_gdiplus" or scene_id == "text_ft2_scene":
#            name = obs.obs_scene_get_name(scene)
#            obs.obs_property_list_add_string(p, f"{name} ({scene_id})", name)
#
#        obs.scene_list_release(scenes)

    obs.obs_properties_add_button(props, "button", "Do something", do_something)
    return props
