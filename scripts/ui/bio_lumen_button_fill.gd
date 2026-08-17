class_name BioLumenButtonFill
extends ColorRect

## Subtle, role-pure Bio-Lumen fill for primary actions.
##
## The theme still owns borders, focus and content insets. This child only adds
## a restrained teal membrane gradient behind the parent button, so primary
## actions feel alive without turning gold (focus/reward) into decoration.

const SHADER_CODE := """
shader_type canvas_item;

instance uniform vec4 top_color : source_color = vec4(0.34, 0.82, 0.79, 1.0);
instance uniform vec4 bottom_color : source_color = vec4(0.18, 0.68, 0.67, 1.0);
uniform float edge_fade = 0.018;

void fragment() {
	vec2 p = UV;
	float membrane = smoothstep(0.0, edge_fade, p.x)
		* smoothstep(0.0, edge_fade, 1.0 - p.x)
		* smoothstep(0.0, edge_fade, p.y)
		* smoothstep(0.0, edge_fade, 1.0 - p.y);
	float soft_pulse = sin((p.x * 1.7 + p.y) * 3.14159265) * 0.018;
	vec4 color = mix(top_color, bottom_color, clamp(p.y + soft_pulse, 0.0, 1.0));
	COLOR = vec4(color.rgb, color.a * membrane);
}
"""

var accent: Color = AlveolusVisualTheme.TURQUOISE
var host_button: BaseButton
var _hovered := false
var _pressed := false
var _focused := false
var _signals_connected := false

func _enter_tree() -> void:
	_connect_host()

func _exit_tree() -> void:
	_disconnect_host()

static func attach(button: BaseButton, color: Color) -> BioLumenButtonFill:
	if button == null:
		return null
	var existing := button.get_node_or_null("BioLumenFill") as BioLumenButtonFill
	if existing != null:
		existing.configure(button, color)
		return existing
	var fill := BioLumenButtonFill.new()
	fill.name = "BioLumenFill"
	button.add_child(fill)
	button.move_child(fill, 0)
	fill.configure(button, color)
	return fill

func configure(button: BaseButton, color: Color) -> void:
	if host_button != null and host_button != button:
		_disconnect_host()
	host_button = button
	accent = color
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 1.0
	offset_top = 1.0
	offset_right = -1.0
	offset_bottom = -1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	if not material is ShaderMaterial:
		material = BioLumenMaterialCache.material(&"global_button", SHADER_CODE)
	_connect_host()
	set_process(false)
	_update_colors()

## Call after changing `disabled` programmatically. Pointer, press and focus
## changes are already signal-driven and never require per-frame polling.
func refresh_state() -> void:
	_update_colors()

func set_accent(color: Color) -> void:
	accent = color
	_update_colors()

func _connect_host() -> void:
	if host_button == null or _signals_connected:
		return
	host_button.mouse_entered.connect(_on_mouse_entered)
	host_button.mouse_exited.connect(_on_mouse_exited)
	host_button.button_down.connect(_on_button_down)
	host_button.button_up.connect(_on_button_up)
	host_button.focus_entered.connect(_on_focus_entered)
	host_button.focus_exited.connect(_on_focus_exited)
	host_button.visibility_changed.connect(refresh_state)
	_signals_connected = true

func _disconnect_host() -> void:
	if host_button == null or not _signals_connected or not is_instance_valid(host_button):
		_signals_connected = false
		return
	for signal_and_callable in [
		[host_button.mouse_entered, Callable(self, "_on_mouse_entered")],
		[host_button.mouse_exited, Callable(self, "_on_mouse_exited")],
		[host_button.button_down, Callable(self, "_on_button_down")],
		[host_button.button_up, Callable(self, "_on_button_up")],
		[host_button.focus_entered, Callable(self, "_on_focus_entered")],
		[host_button.focus_exited, Callable(self, "_on_focus_exited")],
		[host_button.visibility_changed, Callable(self, "refresh_state")],
	]:
		var host_signal: Signal = signal_and_callable[0]
		var callback: Callable = signal_and_callable[1]
		if host_signal.is_connected(callback):
			host_signal.disconnect(callback)
	_signals_connected = false

func _on_mouse_entered() -> void:
	_hovered = true
	_update_colors()

func _on_mouse_exited() -> void:
	_hovered = false
	_update_colors()

func _on_button_down() -> void:
	_pressed = true
	_update_colors()

func _on_button_up() -> void:
	_pressed = false
	_update_colors()

func _on_focus_entered() -> void:
	_focused = true
	_update_colors()

func _on_focus_exited() -> void:
	_focused = false
	_update_colors()

func _update_colors() -> void:
	if not material is ShaderMaterial:
		return
	var top := accent.lightened(0.27)
	var bottom := accent.lightened(0.18)
	var alpha := 0.96
	if host_button != null and host_button.disabled:
		top = AlveolusVisualTheme.MUTED.lightened(0.08)
		bottom = AlveolusVisualTheme.MUTED.darkened(0.06)
		alpha = 0.42
	elif _pressed:
		top = accent.lightened(0.18)
		bottom = accent.lightened(0.10)
	elif _hovered or _focused:
		top = accent.lightened(0.31)
		bottom = accent.lightened(0.22)
	set_instance_shader_parameter(&"top_color", Color(top, alpha))
	set_instance_shader_parameter(&"bottom_color", Color(bottom, alpha))
