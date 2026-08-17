class_name UISoundService
extends Node

const NONE := &"none"
const FOCUS := &"focus"
const PRESS := &"press"
const CONFIRM := &"confirm"
const BACK := &"back"
const ERROR := &"error"
const OPEN := &"open"
const REWARD := &"reward"
const RUN_START := &"run_start"
const ABILITY_READY := &"ability_ready"

const SOUND_ROLE_META := &"ui_sound_role"
const LEGACY_SOUND_CUE_META := &"ui_sound_cue"
const SOUND_ROLES := [NONE, PRESS, CONFIRM, BACK, ERROR, OPEN, REWARD, RUN_START, ABILITY_READY]
const FOCUS_NAVIGATION_ACTIONS := [&"ui_focus_next", &"ui_focus_prev", &"ui_left", &"ui_right", &"ui_up", &"ui_down"]

const SOUND_PATHS := {
	FOCUS: "res://assets/vendor/kenney_interface_sounds/select_003.wav",
	PRESS: "res://assets/vendor/kenney_interface_sounds/click_003.wav",
	CONFIRM: "res://assets/vendor/kenney_interface_sounds/confirmation_002.wav",
	BACK: "res://assets/vendor/kenney_interface_sounds/back_003.wav",
	ERROR: "res://assets/vendor/kenney_interface_sounds/error_006.wav",
	OPEN: "res://assets/vendor/kenney_interface_sounds/open_003.wav",
	REWARD: "res://assets/vendor/kenney_interface_sounds/maximize_003.wav",
	RUN_START: "res://assets/vendor/kenney_interface_sounds/confirmation_004.wav",
	ABILITY_READY: "res://assets/vendor/kenney_interface_sounds/maximize_003.wav",
}

const PLAYER_COUNT := 8
# Kept for source compatibility. Focus feedback is no longer time-debounced:
# one intentional navigation step produces one cue for its resulting focus
# change, even when the player navigates quickly.
const FOCUS_DEBOUNCE_MSEC := 90

var players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var next_player: int = 0
var last_focus_tick: int = -FOCUS_DEBOUNCE_MSEC
var last_focus_control_id: int = 0
var focus_navigation_armed: bool = false
var focus_navigation_generation: int = 0
var interaction_unlocked: bool = false
var reduce_motion: bool = false
var output_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output_enabled = DisplayServer.get_name() != "headless"
	add_to_group(&"alveolus_ui_sound_service")
	_ensure_audio_buses()
	for cue in SOUND_PATHS:
		var stream := load(String(SOUND_PATHS[cue])) as AudioStream
		if stream != null:
			streams[cue] = stream
	for index in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.name = "UISoundPlayer%d" % index
		player.bus = &"UI"
		players.append(player)
		add_child(player)

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed():
			interaction_unlocked = true
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag:
		_disarm_focus_navigation()
		return
	if _is_focus_navigation_event(event):
		_arm_focus_navigation()
	elif (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction) and event.is_pressed():
		# Accept, cancel and gameplay buttons must never prime a later focus cue.
		_disarm_focus_navigation()

func _exit_tree() -> void:
	for player in players:
		if not is_instance_valid(player):
			continue
		player.stop()
		player.stream = null
	streams.clear()

func configure(settings: UISettingsState) -> void:
	if settings == null:
		return
	reduce_motion = settings.reduce_motion
	settings.apply_audio()

func play(cue: StringName) -> void:
	if cue == NONE:
		return
	if OS.has_feature("web") and not interaction_unlocked:
		return
	if not streams.has(cue) or players.is_empty():
		return
	var player := players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stream = streams[cue]
	player.volume_db = -8.0 if cue == FOCUS else 0.0
	if output_enabled:
		player.play()

func wire_tree(control_root: Node) -> void:
	if control_root == null:
		return
	_wire_recursive(control_root)

func _on_child_entered(child: Node) -> void:
	# Wire newly mounted screen controls in the same frame. The handler only
	# connects signals and does not mutate the tree, while its recursive
	# child-entered connection still covers descendants added afterwards.
	_wire_recursive(child)

func _wire_recursive(node: Node) -> void:
	_wire_control(node)
	if not node.child_entered_tree.is_connected(_on_child_entered):
		node.child_entered_tree.connect(_on_child_entered)
	for child in node.get_children():
		_wire_recursive(child)

func _wire_control(node: Node) -> void:
	if bool(node.get_meta(&"alveolus_sound_wired", false)):
		return
	if node is CampusBuildingCard:
		var campus_card := node as CampusBuildingCard
		campus_card.set_meta(&"alveolus_sound_wired", true)
		if not campus_card.has_meta(SOUND_ROLE_META) and not campus_card.has_meta(LEGACY_SOUND_CUE_META):
			set_sound_role(campus_card, OPEN)
		campus_card.focus_entered.connect(_play_focus_for_control.bind(campus_card))
		campus_card.selected.connect(_play_activation_for_control.bind(campus_card, OPEN))
		return
	if node is BaseButton:
		var button := node as BaseButton
		button.set_meta(&"alveolus_sound_wired", true)
		button.focus_entered.connect(_play_focus_for.bind(button))
		button.pressed.connect(_play_button_cue.bind(button))
		return
	if node is Control:
		var control := node as Control
		control.set_meta(&"alveolus_sound_wired", true)
		control.focus_entered.connect(_play_focus_for_control.bind(control))

func _play_focus_for(button: BaseButton) -> void:
	if is_instance_valid(button) and button.visible and not button.disabled:
		_play_navigation_focus(button)

func _play_focus_for_control(control: Control) -> void:
	if is_instance_valid(control) and control.visible:
		_play_navigation_focus(control)

func _play_navigation_focus(control: Control) -> void:
	var control_id := control.get_instance_id()
	var changed := control_id != last_focus_control_id
	last_focus_control_id = control_id
	if not focus_navigation_armed:
		return
	focus_navigation_armed = false
	if changed:
		play(FOCUS)

func _play_button_cue(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	_play_activation_for_control(button, PRESS)

func _play_activation_for_control(control: Object, fallback: StringName = PRESS) -> void:
	var role := sound_role(control, fallback)
	if role != NONE:
		play(role)

func _cue_for_button(button: BaseButton) -> StringName:
	return sound_role(button, PRESS)

static func set_sound_role(control: Object, role: StringName) -> bool:
	if control == null or not is_instance_valid(control) or not is_sound_role(role):
		return false
	control.set_meta(SOUND_ROLE_META, role)
	return true

static func clear_sound_role(control: Object) -> void:
	if control != null and is_instance_valid(control) and control.has_meta(SOUND_ROLE_META):
		control.remove_meta(SOUND_ROLE_META)

static func sound_role(control: Object, fallback: StringName = PRESS) -> StringName:
	if control != null and is_instance_valid(control):
		if control.has_meta(SOUND_ROLE_META):
			var explicit_role := StringName(control.get_meta(SOUND_ROLE_META))
			if is_sound_role(explicit_role):
				return explicit_role
		# Existing callers using ui_sound_cue remain valid while new code can use
		# the explicit role API above.
		if control.has_meta(LEGACY_SOUND_CUE_META):
			var legacy_role := StringName(control.get_meta(LEGACY_SOUND_CUE_META))
			if is_sound_role(legacy_role):
				return legacy_role
	return fallback if is_sound_role(fallback) else PRESS

static func is_sound_role(role: StringName) -> bool:
	return SOUND_ROLES.has(role)

func _arm_focus_navigation() -> void:
	focus_navigation_generation += 1
	focus_navigation_armed = true
	_expire_focus_navigation.call_deferred(focus_navigation_generation)

func _disarm_focus_navigation() -> void:
	focus_navigation_generation += 1
	focus_navigation_armed = false

func _expire_focus_navigation(generation: int) -> void:
	if generation == focus_navigation_generation:
		focus_navigation_armed = false

func _is_focus_navigation_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		if key_event.physical_keycode in [KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			return true
	elif event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if not button_event.pressed:
			return false
		if button_event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			return true
	elif event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		return motion_event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] and absf(motion_event.axis_value) >= 0.55
	elif event is InputEventAction:
		var action_event := event as InputEventAction
		return action_event.pressed and StringName(action_event.action) in FOCUS_NAVIGATION_ACTIONS
	for action in FOCUS_NAVIGATION_ACTIONS:
		if event.is_action_pressed(action):
			return true
	return false

func _ensure_audio_buses() -> void:
	for bus_name in [&"UI", &"Effects", &"Music"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
