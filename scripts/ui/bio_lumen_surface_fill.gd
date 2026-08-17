class_name BioLumenSurfaceFill
extends ColorRect

## Shared, input-transparent Bio-Lumen wash for semantic UI surfaces.
## Borders, focus, padding and elevation remain owned by AlveolusVisualTheme;
## this child contributes only the living membrane depth behind the content.

const SHADER_CODE := BioLumenMaterialCache.SURFACE_SHADER_CODE

var left_color := Color("0b3b3d")
var right_color := Color("061f26")
var corner_radii := Vector4(6.0, 6.0, 6.0, 6.0)
var energy := 1.0


static func attach(
	host: Control,
	left: Color,
	right: Color,
	radii: Vector4 = Vector4(6.0, 6.0, 6.0, 6.0),
	fill_energy: float = 1.0
) -> BioLumenSurfaceFill:
	if host == null:
		return null
	var fill := host.get_node_or_null("BioLumenSurface") as BioLumenSurfaceFill
	if fill == null:
		fill = BioLumenSurfaceFill.new()
		fill.name = "BioLumenSurface"
		host.add_child(fill)
		host.move_child(fill, 0)
	fill.configure(left, right, radii, fill_energy)
	return fill


func configure(left: Color, right: Color, radii: Vector4, fill_energy: float = 1.0) -> void:
	left_color = left
	right_color = right
	corner_radii = radii
	energy = clampf(fill_energy, 0.5, 1.35)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 1.0
	offset_top = 1.0
	offset_right = -1.0
	offset_bottom = -1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	show_behind_parent = false
	if not material is ShaderMaterial:
		material = BioLumenMaterialCache.material(&"planning_surface", SHADER_CODE)
	if not resized.is_connected(_refresh_instance_uniforms):
		resized.connect(_refresh_instance_uniforms)
	set_process(false)
	set_physics_process(false)
	_refresh_instance_uniforms()


func set_palette(left: Color, right: Color, fill_energy: float = 1.0) -> void:
	left_color = left
	right_color = right
	energy = clampf(fill_energy, 0.5, 1.35)
	_refresh_instance_uniforms()


func _refresh_instance_uniforms() -> void:
	var surface_material := material as ShaderMaterial
	if surface_material == null:
		return
	surface_material.set_shader_parameter(&"left_color", left_color)
	surface_material.set_shader_parameter(&"right_color", right_color)
	surface_material.set_shader_parameter(&"panel_size", Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)))
	surface_material.set_shader_parameter(&"corner_radii", corner_radii)
	surface_material.set_shader_parameter(&"energy", energy)
