class_name PreparationBioLumenSurfaceFill
extends ColorRect

## Planning-only membrane wash for slot and candidate cards. The Button styles
## keep ownership of borders/focus while this child supplies the approved
## left-teal-to-right-petrol material below the card content.

const SHADER_CODE := BioLumenMaterialCache.SURFACE_SHADER_CODE

const NORMAL_LEFT := Color("18585a")
const NORMAL_RIGHT := Color("082d34")
const HOVER_LEFT := Color("216764")
const HOVER_RIGHT := Color("0a363d")
const PREVIEW_LEFT := Color("26736e")
const PREVIEW_RIGHT := Color("0a353d")
const PRESSED_LEFT := Color("0c393d")
const PRESSED_RIGHT := Color("061f25")
const LOCKED_LEFT := Color("0b2b30")
const LOCKED_RIGHT := Color("061f25")
const ASSIGNED_LEFT := Color("103b40")
const ASSIGNED_RIGHT := Color("07252c")
const CURRENT_LEFT := Color("123b3f")
const CURRENT_RIGHT := Color("07262c")
const PANEL_LEFT := Color("0b3b3d")
const PANEL_RIGHT := Color("061f26")

var host: Control
var button_host: BaseButton
var static_surface := false
var static_left := PANEL_LEFT
var static_right := PANEL_RIGHT
var normal_left := NORMAL_LEFT
var normal_right := NORMAL_RIGHT
var surface_corner_radii := Vector4(15.0, 5.0, 15.0, 5.0)
var hovered := false
var focused := false
var pressed := false
var _signals_connected := false

func _enter_tree() -> void:
	_connect_button_host()

func _exit_tree() -> void:
	_disconnect_button_host()

static func attach(
	button: BaseButton,
	left: Color = NORMAL_LEFT,
	right: Color = NORMAL_RIGHT,
	large_radius: float = 15.0,
	small_radius: float = 5.0
) -> PreparationBioLumenSurfaceFill:
	var fill := button.get_node_or_null("MembraneFill") as PreparationBioLumenSurfaceFill
	if fill == null:
		fill = PreparationBioLumenSurfaceFill.new()
		fill.name = "MembraneFill"
		button.add_child(fill)
		button.move_child(fill, 0)
	fill.configure(button, left, right, large_radius, small_radius)
	return fill

static func attach_static(control: Control, left: Color = PANEL_LEFT, right: Color = PANEL_RIGHT, large_radius: float = 17.0, small_radius: float = 5.0) -> PreparationBioLumenSurfaceFill:
	var fill := control.get_node_or_null("MembraneSurface") as PreparationBioLumenSurfaceFill
	if fill == null:
		fill = PreparationBioLumenSurfaceFill.new()
		fill.name = "MembraneSurface"
		control.add_child(fill)
		control.move_child(fill, 0)
	fill.configure_static(control, left, right, large_radius, small_radius)
	return fill

func configure(
	button: BaseButton,
	_left: Color,
	_right: Color,
	large_radius: float = 15.0,
	small_radius: float = 5.0
) -> void:
	if button_host != null and button_host != button:
		_disconnect_button_host()
	host = button
	button_host = button
	static_surface = false
	surface_corner_radii = Vector4(large_radius, small_radius, large_radius, small_radius)
	normal_left = _left
	normal_right = _right
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 1.0
	offset_top = 1.0
	offset_right = -1.0
	offset_bottom = -1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	_ensure_material()
	if not resized.is_connected(_update_size):
		resized.connect(_update_size)
	_connect_button_host()
	set_process(false)
	_update_shader()
	_update_size()

func configure_static(control: Control, left: Color, right: Color, large_radius: float = 17.0, small_radius: float = 5.0) -> void:
	if button_host != null:
		_disconnect_button_host()
	host = control
	button_host = null
	static_surface = true
	static_left = left
	static_right = right
	surface_corner_radii = Vector4(large_radius, small_radius, large_radius, small_radius)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 1.0
	offset_top = 1.0
	offset_right = -1.0
	offset_bottom = -1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Static panel fills sit above the flat fallback and below the content nodes.
	show_behind_parent = false
	_ensure_material()
	if not resized.is_connected(_update_size):
		resized.connect(_update_size)
	set_process(false)
	_update_shader()
	_update_size()

func _ensure_material() -> void:
	if material is ShaderMaterial:
		return
	material = BioLumenMaterialCache.material(&"planning_surface", SHADER_CODE)

## Synchronizes programmatic meta or disabled changes without a process loop.
## Prefer `set_selected()` and `set_catalog_state()` in new callers.
func refresh_state() -> void:
	_update_shader()

func set_selected(value: bool) -> void:
	if button_host == null:
		return
	button_host.set_meta(&"selected_slot", value)
	_update_shader()

func set_catalog_state(state: StringName, available: bool = false) -> void:
	if button_host == null:
		return
	button_host.set_meta(&"catalog_state", state)
	button_host.set_meta(&"catalog_available", available)
	_update_shader()

func _connect_button_host() -> void:
	if button_host == null or _signals_connected:
		return
	button_host.mouse_entered.connect(_on_mouse_entered)
	button_host.mouse_exited.connect(_on_mouse_exited)
	button_host.focus_entered.connect(_on_focus_entered)
	button_host.focus_exited.connect(_on_focus_exited)
	button_host.button_down.connect(_on_button_down)
	button_host.button_up.connect(_on_button_up)
	button_host.visibility_changed.connect(refresh_state)
	_signals_connected = true

func _disconnect_button_host() -> void:
	if button_host == null or not _signals_connected or not is_instance_valid(button_host):
		_signals_connected = false
		return
	for signal_and_callable in [
		[button_host.mouse_entered, Callable(self, "_on_mouse_entered")],
		[button_host.mouse_exited, Callable(self, "_on_mouse_exited")],
		[button_host.focus_entered, Callable(self, "_on_focus_entered")],
		[button_host.focus_exited, Callable(self, "_on_focus_exited")],
		[button_host.button_down, Callable(self, "_on_button_down")],
		[button_host.button_up, Callable(self, "_on_button_up")],
		[button_host.visibility_changed, Callable(self, "refresh_state")],
	]:
		var host_signal: Signal = signal_and_callable[0]
		var callback: Callable = signal_and_callable[1]
		if host_signal.is_connected(callback):
			host_signal.disconnect(callback)
	_signals_connected = false

func _on_mouse_entered() -> void:
	hovered = true
	_update_shader()

func _on_mouse_exited() -> void:
	hovered = false
	_update_shader()

func _on_focus_entered() -> void:
	focused = true
	_update_shader()

func _on_focus_exited() -> void:
	focused = false
	_update_shader()

func _on_button_down() -> void:
	pressed = true
	_update_shader()

func _on_button_up() -> void:
	pressed = false
	_update_shader()

func _update_size() -> void:
	if material is ShaderMaterial:
		set_instance_shader_parameter(&"panel_size", Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)))
		set_instance_shader_parameter(&"corner_radii", surface_corner_radii)

func _update_shader() -> void:
	if not material is ShaderMaterial:
		return
	var left := static_left if static_surface else normal_left
	var right := static_right if static_surface else normal_right
	var energy := 1.0
	var catalog_state := StringName(button_host.get_meta(&"catalog_state", &"available")) if button_host != null else &"available"
	if not static_surface and catalog_state == &"current":
		left = CURRENT_LEFT
		right = CURRENT_RIGHT
	elif not static_surface and button_host != null and (button_host.disabled or catalog_state == &"locked"):
		left = LOCKED_LEFT
		right = LOCKED_RIGHT
	elif not static_surface and catalog_state == &"assigned":
		left = ASSIGNED_LEFT
		right = ASSIGNED_RIGHT
	elif not static_surface and pressed:
		left = PRESSED_LEFT
		right = PRESSED_RIGHT
	elif not static_surface and (hovered or focused) and button_host != null and button_host.has_meta(&"catalog_available") and bool(button_host.get_meta(&"catalog_available", false)):
		left = PREVIEW_LEFT
		right = PREVIEW_RIGHT
	elif not static_surface and button_host != null and bool(button_host.get_meta(&"selected_slot", false)):
		# Selection is communicated by the gold outline and contextual height.
		# Keeping the neutral membrane avoids the former green slab effect.
		left = NORMAL_LEFT
		right = NORMAL_RIGHT
	elif not static_surface and (hovered or focused):
		left = HOVER_LEFT
		right = HOVER_RIGHT
	set_instance_shader_parameter(&"left_color", left)
	set_instance_shader_parameter(&"right_color", right)
	set_instance_shader_parameter(&"energy", energy)
