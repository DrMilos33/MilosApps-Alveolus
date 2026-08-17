class_name CampusBuildingCard
extends Control

const UnitBodyComponent = preload("res://scripts/ui/unit_body_2d.gd")
const OUTLINE_SHADER := preload("res://assets/shaders/campus_building_outline.gdshader")

signal selected

var accent: Color = Color("f2bd68")
var title_text: String = ""
var status_text: String = ""
var unit_body: Variant
var building_sprite: TextureRect
var outline_material: ShaderMaterial
var title_label: Label
var status_label: Label
var hover_amount: float = 0.0
var highlighted_status: bool = false
var mouse_over: bool = false
var reduced_motion: bool = false

func configure(title: String, texture_source: Variant, card_accent: Color, label_width: float, label_y: float = -34.0) -> void:
	title_text = title
	accent = card_accent
	var texture: Texture2D = texture_source as Texture2D if texture_source is Texture2D else load(String(texture_source)) as Texture2D
	building_sprite = TextureRect.new()
	var display_rect := _aspect_fit_rect(texture, Rect2(Vector2.ZERO, size))
	building_sprite.position = display_rect.position
	building_sprite.size = display_rect.size
	building_sprite.texture = texture
	building_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	building_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	building_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	building_sprite.pivot_offset = display_rect.size * 0.5
	outline_material = ShaderMaterial.new()
	outline_material.shader = OUTLINE_SHADER
	outline_material.set_shader_parameter("outline_color", AlveolusVisualTheme.GOLD)
	outline_material.set_shader_parameter("outline_width", 2.0)
	outline_material.set_shader_parameter("outline_strength", 0.0)
	building_sprite.material = outline_material
	add_child(building_sprite)
	unit_body = UnitBodyComponent.new()
	unit_body.configure_alpha_texture(texture, display_rect, 0.12)
	add_child(unit_body)
	_build_labels(label_width, label_y)

func _ready() -> void:
	add_to_group(&"alveolus_reduced_motion")
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_mouse_over.bind(true))
	mouse_exited.connect(_set_mouse_over.bind(false))
	focus_entered.connect(_wake_animation)
	focus_exited.connect(_wake_animation)
	set_process(false)

func _build_labels(label_width: float, label_y: float) -> void:
	if title_label != null:
		return
	var label_panel := Panel.new()
	label_panel.position = Vector2((size.x - label_width) * 0.5, label_y)
	label_panel.size = Vector2(label_width, 30.0)
	label_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE,
		accent,
		AlveolusVisualTheme.CornerTreatment.CARD_6
	)
	label_panel.add_theme_stylebox_override("panel", style)
	add_child(label_panel)
	var title_inset := MarginContainer.new()
	title_inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_inset.add_theme_constant_override("margin_left", 8)
	title_inset.add_theme_constant_override("margin_top", 2)
	title_inset.add_theme_constant_override("margin_right", 8)
	title_inset.add_theme_constant_override("margin_bottom", 2)
	title_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_panel.add_child(title_inset)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", AlveolusVisualTheme.heading_font())
	title_label.add_theme_font_size_override("font_size", AlveolusVisualTheme.TEXT_ACTION)
	title_label.add_theme_color_override("font_color", AlveolusVisualTheme.IVORY)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_inset.add_child(title_label)
	status_label = Label.new()
	status_label.position = Vector2((size.x - label_width) * 0.5, label_y + 32.0)
	status_label.size = Vector2(label_width, 24.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	status_label.add_theme_font_size_override("font_size", AlveolusVisualTheme.TEXT_CAPTION)
	status_label.add_theme_color_override("font_color", AlveolusVisualTheme.SKY_DEEP)
	status_label.add_theme_stylebox_override("normal", AlveolusVisualTheme.with_content_insets(AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET,
		accent,
		AlveolusVisualTheme.CornerTreatment.CONTROL_4
	), 8.0, 3.0))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.modulate.a = 0.0
	add_child(status_label)

func set_status(text: String, highlighted: bool = false) -> void:
	status_text = text
	highlighted_status = highlighted
	if status_label != null:
		status_label.text = text
		status_label.add_theme_color_override("font_color", accent.lightened(0.20) if highlighted else AlveolusVisualTheme.SKY_DEEP)
		status_label.modulate.a = 1.0 if not text.is_empty() else 0.0

func _has_point(point: Vector2) -> bool:
	return unit_body != null and unit_body.contains_parent_point(point)

func get_highlight_body() -> Variant:
	return unit_body

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		selected.emit()
		accept_event()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		selected.emit()
		accept_event()

func _process(delta: float) -> void:
	var target := 1.0 if mouse_over or has_focus() else 0.0
	if reduced_motion:
		hover_amount = target
		_apply_highlight()
		set_process(false)
		return
	hover_amount = move_toward(hover_amount, target, delta * 9.0)
	_apply_highlight()
	if is_equal_approx(hover_amount, target):
		set_process(false)

func _apply_highlight() -> void:
	if outline_material != null:
		outline_material.set_shader_parameter("outline_strength", hover_amount)
	if building_sprite != null:
		building_sprite.scale = Vector2.ONE if reduced_motion else Vector2.ONE * lerpf(1.0, 1.02, hover_amount)
	if title_label != null:
		title_label.add_theme_color_override("font_color", AlveolusVisualTheme.IVORY.lerp(accent.lightened(0.24), hover_amount))

func _set_mouse_over(value: bool) -> void:
	mouse_over = value
	set_process(true)

func _wake_animation() -> void:
	set_process(true)

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	hover_amount = 1.0 if mouse_over or has_focus() else 0.0
	_apply_highlight()
	set_process(false if enabled else not is_equal_approx(hover_amount, 1.0 if mouse_over or has_focus() else 0.0))

func _aspect_fit_rect(texture: Texture2D, target: Rect2) -> Rect2:
	if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
		return target
	var texture_aspect := float(texture.get_width()) / float(texture.get_height())
	var target_aspect := target.size.x / maxf(target.size.y, 1.0)
	var fitted_size := target.size
	if texture_aspect > target_aspect:
		fitted_size.y = target.size.x / texture_aspect
	else:
		fitted_size.x = target.size.y * texture_aspect
	return Rect2(target.position + (target.size - fitted_size) * 0.5, fitted_size)
