class_name BioLumenButtonFill
extends ColorRect

## Subtle, role-pure Bio-Lumen fill for primary actions.
##
## The theme still owns borders, focus and content insets. This child only adds
## a restrained teal membrane gradient behind the parent button, so primary
## actions feel alive without turning gold (focus/reward) into decoration.

const SHADER_CODE := """
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.34, 0.82, 0.79, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.18, 0.68, 0.67, 1.0);
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
var _last_disabled := false

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
	host_button = button
	accent = color
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 1.0
	offset_top = 1.0
	offset_right = -1.0
	offset_bottom = -1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	material = shader_material
	if not host_button.mouse_entered.is_connected(_on_hovered.bind(true)):
		host_button.mouse_entered.connect(_on_hovered.bind(true))
		host_button.mouse_exited.connect(_on_hovered.bind(false))
		host_button.button_down.connect(_on_pressed.bind(true))
		host_button.button_up.connect(_on_pressed.bind(false))
	_last_disabled = host_button.disabled
	_update_colors()
	set_process(true)

func _process(_delta: float) -> void:
	if host_button == null or not is_instance_valid(host_button):
		set_process(false)
		return
	if _last_disabled != host_button.disabled:
		_last_disabled = host_button.disabled
		_update_colors()

func _on_hovered(value: bool) -> void:
	_hovered = value
	_update_colors()

func _on_pressed(value: bool) -> void:
	_pressed = value
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
	elif _hovered:
		top = accent.lightened(0.31)
		bottom = accent.lightened(0.22)
	(material as ShaderMaterial).set_shader_parameter("top_color", Color(top, alpha))
	(material as ShaderMaterial).set_shader_parameter("bottom_color", Color(bottom, alpha))
