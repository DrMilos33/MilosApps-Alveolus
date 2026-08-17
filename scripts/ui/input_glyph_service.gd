class_name InputGlyphService
extends Node

signal input_method_changed(method: StringName)

const KEYBOARD_MOUSE := &"keyboard"
const GAMEPAD := &"gamepad"
const ICON_ROOT := "res://assets/vendor/kenney_input_prompts/"
const ICON_PATHS := {
	"key_q": ICON_ROOT + "keyboard_q.png",
	"key_e": ICON_ROOT + "keyboard_e.png",
	"key_escape": ICON_ROOT + "keyboard_escape.png",
	"key_enter": ICON_ROOT + "keyboard_enter.png",
	"key_space": ICON_ROOT + "keyboard_space.png",
	"joy_lb": ICON_ROOT + "xbox_lb.png",
	"joy_rb": ICON_ROOT + "xbox_rb.png",
	"joy_a": ICON_ROOT + "xbox_button_a.png",
	"joy_b": ICON_ROOT + "xbox_button_b.png",
	"joy_menu": ICON_ROOT + "xbox_button_menu.png",
}

var current_method: StringName = KEYBOARD_MOUSE
var forced_method: StringName = &"auto"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if forced_method != &"auto":
		return
	var next_method := current_method
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.35:
			return
		next_method = GAMEPAD
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		next_method = KEYBOARD_MOUSE
	_set_method(next_method)

func configure(mode: StringName) -> void:
	forced_method = mode if mode in [&"auto", KEYBOARD_MOUSE, GAMEPAD] else &"auto"
	if forced_method != &"auto":
		_set_method(forced_method, true)
	else:
		# Rebinding does not change the input method, but every visible glyph still
		# needs to refresh when the settings object is applied again.
		input_method_changed.emit(current_method)

func method() -> StringName:
	return current_method

func glyph_for_action(action: StringName) -> String:
	if current_method == GAMEPAD:
		return _gamepad_glyph(action)
	return _keyboard_glyph(action)

static func caption_for_action(action: StringName) -> String:
	match action:
		&"move_up": return "Nach oben"
		&"move_down": return "Nach unten"
		&"move_left": return "Nach links"
		&"move_right": return "Nach rechts"
		&"active_ability_1": return "Fähigkeit 1"
		&"active_ability_2": return "Fähigkeit 2"
		&"pause_game": return "Pause"
		&"upgrade_1": return "Ausbau links"
		&"upgrade_2": return "Ausbau mittig"
		&"upgrade_3": return "Ausbau rechts"
		&"reroll_upgrades": return "Ausbauten neu ziehen"
		&"ui_accept": return "Bestätigen"
		&"ui_cancel": return "Zurück"
		&"ui_info": return "Informationen"
	return String(action)

func icon_for_action(action: StringName) -> Texture2D:
	for event in InputMap.action_get_events(action):
		if current_method == GAMEPAD and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			var gamepad_icon := icon_for_event(event)
			if gamepad_icon != null:
				return gamepad_icon
		if current_method == KEYBOARD_MOUSE and (event is InputEventKey or event is InputEventMouseButton):
			var keyboard_icon := icon_for_event(event)
			if keyboard_icon != null:
				return keyboard_icon
	return null

static func text_for_event(event: InputEvent) -> String:
	if event is InputEventKey:
		return _key_text(event as InputEventKey)
	if event is InputEventMouseButton:
		return _mouse_button_text((event as InputEventMouseButton).button_index)
	if event is InputEventJoypadButton:
		return _joy_button_text((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return _joy_axis_text(motion.axis, motion.axis_value)
	return ""

static func icon_for_event(event: InputEvent) -> Texture2D:
	var icon_id := _icon_id_for_event(event)
	if icon_id.is_empty() or not ICON_PATHS.has(icon_id):
		return null
	return load(String(ICON_PATHS[icon_id])) as Texture2D

static func _icon_id_for_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.shift_pressed or key.alt_pressed or key.ctrl_pressed or key.meta_pressed:
			return ""
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		match code:
			KEY_Q: return "key_q"
			KEY_E: return "key_e"
			KEY_ESCAPE: return "key_escape"
			KEY_ENTER: return "key_enter"
			KEY_SPACE: return "key_space"
	if event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_LEFT_SHOULDER: return "joy_lb"
			JOY_BUTTON_RIGHT_SHOULDER: return "joy_rb"
			JOY_BUTTON_A: return "joy_a"
			JOY_BUTTON_B: return "joy_b"
			JOY_BUTTON_START: return "joy_menu"
	return ""

func _set_method(value: StringName, force_notification: bool = false) -> void:
	if current_method == value and not force_notification:
		return
	current_method = value
	input_method_changed.emit(current_method)

func _keyboard_glyph(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return text_for_event(event)
		if event is InputEventMouseButton:
			return text_for_event(event)
	match action:
		&"active_ability_1": return "Q"
		&"active_ability_2": return "E"
		&"pause_game", &"ui_cancel": return "Esc"
		&"ui_accept": return "Enter"
		&"ui_info": return "I"
	return ""

func _gamepad_glyph(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return text_for_event(event)
		if event is InputEventJoypadMotion:
			return text_for_event(event)
	match action:
		&"active_ability_1": return "LB"
		&"active_ability_2": return "RB"
		&"pause_game": return "Menu"
		&"ui_accept": return "A"
		&"ui_cancel": return "B"
		&"ui_info": return "Y"
	return ""

static func _key_text(key: InputEventKey) -> String:
	var parts: Array[String] = []
	if key.ctrl_pressed:
		parts.append("Ctrl")
	if key.alt_pressed:
		parts.append("Alt")
	if key.shift_pressed:
		parts.append("Shift")
	if key.meta_pressed:
		parts.append("Meta")
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	var key_name := OS.get_keycode_string(code)
	if key_name.is_empty():
		key_name = "Taste %d" % int(code)
	parts.append(key_name)
	return "+".join(parts)

static func _mouse_button_text(button_index: int) -> String:
	match button_index:
		MOUSE_BUTTON_LEFT: return "Maus 1"
		MOUSE_BUTTON_RIGHT: return "Maus 2"
		MOUSE_BUTTON_MIDDLE: return "Maus 3"
		MOUSE_BUTTON_WHEEL_UP: return "Mausrad hoch"
		MOUSE_BUTTON_WHEEL_DOWN: return "Mausrad runter"
	return "Maus %d" % button_index

static func _joy_button_text(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_LEFT_STICK: return "LS"
		JOY_BUTTON_RIGHT_STICK: return "RS"
		JOY_BUTTON_START: return "Menu"
		JOY_BUTTON_BACK: return "View"
		JOY_BUTTON_DPAD_UP: return "D-Pad ↑"
		JOY_BUTTON_DPAD_DOWN: return "D-Pad ↓"
		JOY_BUTTON_DPAD_LEFT: return "D-Pad ←"
		JOY_BUTTON_DPAD_RIGHT: return "D-Pad →"
	return "Gamepad %d" % button_index

static func _joy_axis_text(axis: int, value: float) -> String:
	var direction := "+" if value >= 0.0 else "−"
	match axis:
		JOY_AXIS_LEFT_X: return "LS X%s" % direction
		JOY_AXIS_LEFT_Y: return "LS Y%s" % direction
		JOY_AXIS_RIGHT_X: return "RS X%s" % direction
		JOY_AXIS_RIGHT_Y: return "RS Y%s" % direction
		JOY_AXIS_TRIGGER_LEFT: return "LT"
		JOY_AXIS_TRIGGER_RIGHT: return "RT"
	return "Achse %d %s" % [axis, direction]
