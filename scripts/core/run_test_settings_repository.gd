class_name RunTestSettingsRepository
extends RefCounted

## Dedicated test-tool persistence. This repository deliberately owns a
## separate ConfigFile and has no dependency on regular settings or meta saves.

const DEFAULT_PATH := "user://alveolus_test_tools.cfg"
const SECTION := "test_values"
const DAMAGE_IMMUNITY_KEY := "damage_immunity"
const OUTGOING_DAMAGE_BONUS_KEY := "outgoing_damage_bonus_percent"
const MOVEMENT_SPEED_KEY := "movement_speed_percent"

var _path: String


func _init(path_value: String = DEFAULT_PATH) -> void:
	_path = path_value if not path_value.strip_edges().is_empty() else DEFAULT_PATH


func path() -> String:
	return _path


func load_settings() -> RunTestSettings:
	var config := ConfigFile.new()
	if config.load(_path) != OK:
		return RunTestSettings.new()
	return RunTestSettings.new(
		_bool_value(config, DAMAGE_IMMUNITY_KEY, RunTestSettings.DEFAULT_DAMAGE_IMMUNITY),
		_int_value(
			config,
			OUTGOING_DAMAGE_BONUS_KEY,
			RunTestSettings.DEFAULT_OUTGOING_DAMAGE_BONUS_PERCENT
		),
		_int_value(
			config,
			MOVEMENT_SPEED_KEY,
			RunTestSettings.DEFAULT_MOVEMENT_SPEED_PERCENT
		)
	)


func save(settings: RunTestSettings) -> bool:
	if settings == null:
		return false
	var config := ConfigFile.new()
	config.load(_path)
	config.set_value(SECTION, DAMAGE_IMMUNITY_KEY, settings.damage_immunity_enabled())
	config.set_value(
		SECTION,
		OUTGOING_DAMAGE_BONUS_KEY,
		settings.outgoing_damage_bonus_percent()
	)
	config.set_value(SECTION, MOVEMENT_SPEED_KEY, settings.movement_speed_percent())
	return config.save(_path) == OK


func reset_to_defaults() -> RunTestSettings:
	var defaults := RunTestSettings.new()
	save(defaults)
	return defaults


func _bool_value(config: ConfigFile, key: String, fallback: bool) -> bool:
	var value: Variant = config.get_value(SECTION, key, fallback)
	return bool(value) if typeof(value) == TYPE_BOOL else fallback


func _int_value(config: ConfigFile, key: String, fallback: int) -> int:
	var value: Variant = config.get_value(SECTION, key, fallback)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	return int(value)
