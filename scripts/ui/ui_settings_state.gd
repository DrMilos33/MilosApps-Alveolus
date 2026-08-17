class_name UISettingsState
extends RefCounted

const GLYPH_AUTO := &"auto"
const GLYPH_KEYBOARD := &"keyboard"
const GLYPH_GAMEPAD := &"gamepad"

const UI_SCALES: Array[float] = [0.75, 0.90, 1.0, 1.25, 1.5, 2.0]
const CONFIGURABLE_ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"active_ability_1",
	&"active_ability_2",
	&"pause_game",
	&"ui_accept",
	&"ui_cancel",
	&"ui_info",
]

var master_volume: float = 0.80
var ui_volume: float = 0.65
var effects_volume: float = 0.80
var music_volume: float = 0.80
var master_muted: bool = false
var ui_muted: bool = false
var effects_muted: bool = false
var music_muted: bool = false
var ui_scale: float = 1.0
var reduce_motion: bool = false
var glyph_mode: StringName = GLYPH_AUTO
var fullscreen: bool = false
var confirm_run_restart: bool = true
var input_bindings: Dictionary = {}

func duplicate_settings() -> UISettingsState:
	return from_dict(to_dict())

func to_dict() -> Dictionary:
	return {
		"master_volume": master_volume,
		"ui_volume": ui_volume,
		"effects_volume": effects_volume,
		"music_volume": music_volume,
		"master_muted": master_muted,
		"ui_muted": ui_muted,
		"effects_muted": effects_muted,
		"music_muted": music_muted,
		"ui_scale": ui_scale,
		"reduce_motion": reduce_motion,
		"glyph_mode": String(glyph_mode),
		"fullscreen": fullscreen,
		"confirm_run_restart": confirm_run_restart,
		"input_bindings": input_bindings.duplicate(true),
	}

static func from_dict(data: Variant) -> UISettingsState:
	var settings := UISettingsState.new()
	if not data is Dictionary:
		return settings
	settings.master_volume = clampf(float(data.get("master_volume", 0.80)), 0.0, 1.0)
	settings.ui_volume = clampf(float(data.get("ui_volume", 0.65)), 0.0, 1.0)
	settings.effects_volume = clampf(float(data.get("effects_volume", 0.80)), 0.0, 1.0)
	settings.music_volume = clampf(float(data.get("music_volume", 0.80)), 0.0, 1.0)
	settings.master_muted = bool(data.get("master_muted", false))
	settings.ui_muted = bool(data.get("ui_muted", false))
	settings.effects_muted = bool(data.get("effects_muted", false))
	settings.music_muted = bool(data.get("music_muted", false))
	settings.ui_scale = _nearest_supported_scale(float(data.get("ui_scale", 1.0)))
	settings.reduce_motion = bool(data.get("reduce_motion", false))
	var requested_glyph := StringName(str(data.get("glyph_mode", GLYPH_AUTO)))
	settings.glyph_mode = requested_glyph if requested_glyph in [GLYPH_AUTO, GLYPH_KEYBOARD, GLYPH_GAMEPAD] else GLYPH_AUTO
	settings.fullscreen = bool(data.get("fullscreen", false))
	settings.confirm_run_restart = bool(data.get("confirm_run_restart", true))
	var stored_bindings: Variant = data.get("input_bindings", {})
	settings.input_bindings = stored_bindings.duplicate(true) if stored_bindings is Dictionary else {}
	return settings

func apply_audio() -> void:
	_apply_bus(&"Master", master_volume, master_muted)
	_apply_bus(&"UI", ui_volume, ui_muted)
	_apply_bus(&"Effects", effects_volume, effects_muted)
	_apply_bus(&"Music", music_volume, music_muted)

func apply_window() -> void:
	if OS.has_feature("web"):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func apply_saved_bindings() -> void:
	for action_key in input_bindings:
		var action := StringName(str(action_key))
		if not CONFIGURABLE_ACTIONS.has(action) or not InputMap.has_action(action):
			continue
		var serialized_events: Variant = input_bindings[action_key]
		if not serialized_events is Array or (serialized_events as Array).is_empty():
			continue
		var decoded_events: Array[InputEvent] = []
		for serialized_event in serialized_events:
			var decoded := deserialize_input_event(serialized_event)
			if decoded != null:
				# Saved bindings are device-class bindings. A controller may be
				# reconnected under another device index between sessions.
				decoded.device = -1
				decoded_events.append(decoded)
		# A corrupt custom binding must never erase the working project default.
		if decoded_events.is_empty():
			continue
		InputMap.action_erase_events(action)
		for event in decoded_events:
			InputMap.action_add_event(action, event)

func set_single_binding(action: StringName, event: InputEvent) -> bool:
	if action == &"" or event == null or not CONFIGURABLE_ACTIONS.has(action) or not InputMap.has_action(action):
		return false
	var normalized := _normalized_binding_event(event)
	if normalized == null:
		return false
	if is_reserved_quick_restart_binding(normalized):
		return false
	for other_action in CONFIGURABLE_ACTIONS:
		if not InputMap.has_action(other_action):
			continue
		if other_action == action:
			continue
		for existing in InputMap.action_get_events(other_action):
			if _same_binding(existing, normalized):
				return false
	var preserved: Array[InputEvent] = []
	for existing in InputMap.action_get_events(action):
		if not _same_device_class(existing, normalized):
			preserved.append(existing)
	InputMap.action_erase_events(action)
	for existing in preserved:
		InputMap.action_add_event(action, existing)
	InputMap.action_add_event(action, normalized)
	var serialized: Array[Dictionary] = []
	for bound_event in InputMap.action_get_events(action):
		var data := serialize_input_event(bound_event)
		if not data.is_empty():
			serialized.append(data)
	input_bindings[String(action)] = serialized
	return true

static func is_reserved_quick_restart_binding(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key := event as InputEventKey
	var is_r := key.keycode == KEY_R or key.physical_keycode == KEY_R
	return is_r and key.ctrl_pressed and not key.alt_pressed and not key.shift_pressed and not key.meta_pressed

func clear_custom_binding(action: StringName) -> void:
	input_bindings.erase(String(action))

static func serialize_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		return {
			"type": "key",
			"physical_keycode": key.physical_keycode,
			"keycode": key.keycode,
			"shift": key.shift_pressed,
			"alt": key.alt_pressed,
			"ctrl": key.ctrl_pressed,
			"meta": key.meta_pressed,
		}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button_index": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		return {
			"type": "joy_motion",
			"axis": (event as InputEventJoypadMotion).axis,
			"axis_value": (event as InputEventJoypadMotion).axis_value,
		}
	if event is InputEventMouseButton:
		return {"type": "mouse_button", "button_index": (event as InputEventMouseButton).button_index}
	return {}

static func deserialize_input_event(value: Variant) -> InputEvent:
	if not value is Dictionary:
		return null
	var data: Dictionary = value
	match str(data.get("type", "")):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(data.get("physical_keycode", 0))
			key.keycode = int(data.get("keycode", 0))
			key.shift_pressed = bool(data.get("shift", false))
			key.alt_pressed = bool(data.get("alt", false))
			key.ctrl_pressed = bool(data.get("ctrl", false))
			key.meta_pressed = bool(data.get("meta", false))
			return key
		"joy_button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(data.get("button_index", 0))
			return button
		"joy_motion":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(data.get("axis", 0))
			var axis_value := float(data.get("axis_value", 0.0))
			if absf(axis_value) < 0.01:
				return null
			motion.axis_value = signf(axis_value)
			return motion
		"mouse_button":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(data.get("button_index", 0))
			if mouse.button_index <= 0:
				return null
			return mouse
	return null

static func _nearest_supported_scale(value: float) -> float:
	var best := UI_SCALES[0]
	var best_distance := absf(value - best)
	for candidate in UI_SCALES:
		var distance := absf(value - candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

static func _same_device_class(first: InputEvent, second: InputEvent) -> bool:
	return (first is InputEventKey and second is InputEventKey) or (
		(first is InputEventJoypadButton or first is InputEventJoypadMotion) and
		(second is InputEventJoypadButton or second is InputEventJoypadMotion)
	) or (first is InputEventMouseButton and second is InputEventMouseButton)

static func _same_binding(first: InputEvent, second: InputEvent) -> bool:
	if first is InputEventKey and second is InputEventKey:
		var first_key := first as InputEventKey
		var second_key := second as InputEventKey
		var first_code := first_key.physical_keycode if first_key.physical_keycode != 0 else first_key.keycode
		var second_code := second_key.physical_keycode if second_key.physical_keycode != 0 else second_key.keycode
		# Godot action queries are non-exact by default, so Ctrl+R can also fire an
		# action bound to R. Treat the physical key as occupied regardless of its
		# modifiers to prevent two gameplay commands from firing together.
		return first_code == second_code
	if first is InputEventJoypadButton and second is InputEventJoypadButton:
		return (first as InputEventJoypadButton).button_index == (second as InputEventJoypadButton).button_index
	if first is InputEventJoypadMotion and second is InputEventJoypadMotion:
		var first_motion := first as InputEventJoypadMotion
		var second_motion := second as InputEventJoypadMotion
		return first_motion.axis == second_motion.axis and signf(first_motion.axis_value) == signf(second_motion.axis_value)
	if first is InputEventMouseButton and second is InputEventMouseButton:
		return (first as InputEventMouseButton).button_index == (second as InputEventMouseButton).button_index
	return false

static func _normalized_binding_event(event: InputEvent) -> InputEvent:
	var serialized := serialize_input_event(event)
	if serialized.is_empty():
		return null
	var normalized := deserialize_input_event(serialized)
	if normalized != null:
		# Bindings apply to every keyboard, mouse or controller of that class.
		normalized.device = -1
	return normalized

static func _apply_bus(bus_name: StringName, linear_volume: float, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear_volume, 0.0001)))
	AudioServer.set_bus_mute(index, muted or linear_volume <= 0.0)
