class_name CampusBuildingCard
extends Control

const UnitBodyComponent = preload("res://scripts/ui/unit_body_2d.gd")
const OUTLINE_SHADER := preload("res://assets/shaders/campus_building_outline.gdshader")

signal selected

var accent: Color = AlveolusVisualTheme.GOLD
var title_text: String = ""
var status_text: String = ""
var unit_body: Variant
var building_sprite: TextureRect
var outline_material: ShaderMaterial
var title_panel: PanelContainer
var status_panel: PanelContainer
var title_label: Label
var status_label: Label
var hover_amount: float = 0.0
var highlighted_status: bool = false
var mouse_over: bool = false
var reduced_motion: bool = false
var available: bool = true
var unavailable_reason: String = ""
var guidance_emphasis: bool = false

var _label_width: float = 0.0
var _label_y: float = 0.0
var _layout_refresh_pending: bool = false

func configure(title: String, texture_source: Variant, card_accent: Color, label_width: float, label_y: float = -34.0) -> void:
	title_text = title
	accent = card_accent
	_label_width = label_width
	_label_y = label_y
	set_meta(&"alveolus_component", &"campus_building_card")
	set_meta(&"alveolus_accessible_name", title)
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
	focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if available else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_ARROW
	mouse_entered.connect(_set_mouse_over.bind(true))
	mouse_exited.connect(_set_mouse_over.bind(false))
	focus_entered.connect(_wake_animation)
	focus_exited.connect(_wake_animation)
	set_process(false)

func _build_labels(label_width: float, label_y: float) -> void:
	if title_label != null:
		return
	title_panel = AlveolusUIComponents.surface(AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE)
	title_panel.name = "TitleChrome"
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.clip_contents = false
	title_panel.set_meta(&"campus_chrome_role", &"title")
	add_child(title_panel)
	title_label = AlveolusUIComponents.label(title_text, AlveolusVisualTheme.TYPE_VALUE_LABEL)
	title_label.name = "Title"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var title_inset := AlveolusUIComponents.margin(title_label, 8)
	title_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(title_inset)

	status_panel = AlveolusUIComponents.surface(AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET)
	status_panel.name = "StatusChrome"
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.clip_contents = false
	status_panel.set_meta(&"campus_chrome_role", &"status")
	add_child(status_panel)
	status_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_MUTED_LABEL)
	status_label.name = "Status"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.max_lines_visible = 2
	var status_inset := AlveolusUIComponents.margin(status_label, 6)
	status_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(status_inset)
	status_panel.hide()
	_refresh_chrome_layout(label_width, label_y)
	_refresh_chrome_visuals()

func set_status(text: String, highlighted: bool = false) -> void:
	status_text = text
	highlighted_status = highlighted
	_refresh_chrome_visuals()
	_queue_chrome_layout_refresh()

func set_available(value: bool, reason: String = "") -> void:
	available = value
	unavailable_reason = reason
	if not available:
		mouse_over = false
		if has_focus():
			release_focus()
	focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if available else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_ARROW
	set_meta(&"alveolus_available", available)
	_refresh_chrome_visuals()
	_queue_chrome_layout_refresh()
	set_process(true)


func set_guidance_emphasis(enabled: bool) -> void:
	guidance_emphasis = enabled
	_apply_highlight()
	set_process(true)

func _has_point(point: Vector2) -> bool:
	return unit_body != null and unit_body.contains_parent_point(point)

func get_highlight_body() -> Variant:
	return unit_body

func _gui_input(event: InputEvent) -> void:
	if not available:
		var blocked_pointer_accept: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		if blocked_pointer_accept or event.is_action_pressed(&"ui_accept", true):
			accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		selected.emit()
		accept_event()
	elif event.is_action_pressed(&"ui_accept", true):
		selected.emit()
		accept_event()

func _process(delta: float) -> void:
	var target := 1.0 if available and (mouse_over or has_focus()) else 0.0
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
		var emphasized := available and guidance_emphasis
		var outline_color := AlveolusVisualTheme.GOLD if has_focus() or emphasized else accent.lightened(0.16)
		outline_material.set_shader_parameter("outline_color", outline_color)
		outline_material.set_shader_parameter("outline_width", 5.0 if emphasized else 2.0)
		outline_material.set_shader_parameter("outline_strength", maxf(hover_amount, 1.0 if emphasized else 0.0))
	if building_sprite != null:
		# Campus art is outside the UI skin rollout. Hover and focus therefore
		# alter only its existing outline and never its geometry or sampling.
		building_sprite.scale = Vector2.ONE
	_refresh_chrome_visuals()

func _set_mouse_over(value: bool) -> void:
	mouse_over = value and available
	set_process(true)

func _wake_animation() -> void:
	set_process(true)

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	hover_amount = 1.0 if available and (mouse_over or has_focus()) else 0.0
	_apply_highlight()
	set_process(false if enabled else not is_equal_approx(hover_amount, 1.0 if available and (mouse_over or has_focus()) else 0.0))

func _refresh_chrome_visuals() -> void:
	if title_label == null or status_label == null:
		return
	var display_status := status_text if available else (unavailable_reason if not unavailable_reason.is_empty() else "Gesperrt")
	status_label.text = display_status
	status_panel.visible = not display_status.is_empty()
	if not available:
		if building_sprite != null:
			building_sprite.modulate = Color(0.56, 0.60, 0.60, 0.58)
		title_label.add_theme_color_override("font_color", Color(AlveolusVisualTheme.SKY_DEEP, 0.56))
		status_label.add_theme_color_override("font_color", Color(AlveolusVisualTheme.SKY_DEEP, 0.54))
		title_panel.modulate = Color(0.72, 0.76, 0.76, 0.78)
		status_panel.modulate = Color(0.70, 0.74, 0.74, 0.72)
		return
	if building_sprite != null:
		building_sprite.modulate = Color.WHITE
	title_panel.modulate = Color.WHITE
	status_panel.modulate = Color.WHITE
	var title_color := AlveolusVisualTheme.IVORY
	if has_focus():
		title_color = AlveolusVisualTheme.GOLD
	elif mouse_over:
		title_color = accent.lightened(0.20)
	title_label.add_theme_color_override("font_color", title_color)
	status_label.add_theme_color_override(
		"font_color",
		accent.lightened(0.20) if highlighted_status else AlveolusVisualTheme.SKY_DEEP
	)

func _queue_chrome_layout_refresh() -> void:
	if _layout_refresh_pending or not is_inside_tree():
		return
	_layout_refresh_pending = true
	call_deferred("_refresh_chrome_layout", _label_width, _label_y)

func _refresh_chrome_layout(label_width: float = -1.0, label_y: float = NAN) -> void:
	_layout_refresh_pending = false
	if title_panel == null or status_panel == null:
		return
	var resolved_width := _label_width if label_width < 0.0 else label_width
	var resolved_y := _label_y if is_nan(label_y) else label_y
	var title_minimum := title_panel.get_combined_minimum_size()
	var title_width := maxf(resolved_width, title_minimum.x)
	var title_height := maxf(32.0, title_minimum.y)
	title_panel.position = Vector2((size.x - title_width) * 0.5, resolved_y)
	title_panel.size = Vector2(title_width, title_height)
	var status_minimum := status_panel.get_combined_minimum_size()
	var status_width := maxf(resolved_width, status_minimum.x)
	var status_height := maxf(26.0, status_minimum.y)
	status_panel.position = Vector2((size.x - status_width) * 0.5, resolved_y + title_height + AlveolusVisualTheme.GRID_UNIT)
	status_panel.size = Vector2(status_width, status_height)
	# Campus art keeps its authored full-canvas geometry at every UI scale. If a
	# building sits near the lower edge, move only its descriptive chrome into
	# the viewport; the sprite, hit target and world position remain untouched.
	if get_viewport() != null:
		var visible_bottom := get_viewport().get_visible_rect().end.y - 12.0
		var chrome_bottom := (
			status_panel.get_global_rect().end.y
			if status_panel.visible
			else title_panel.get_global_rect().end.y
		)
		var overflow := maxf(0.0, chrome_bottom - visible_bottom)
		if overflow > 0.0:
			var canvas_scale := maxf(absf(get_global_transform_with_canvas().get_scale().y), 0.01)
			var local_shift := overflow / canvas_scale
			title_panel.position.y -= local_shift
			status_panel.position.y -= local_shift

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_queue_chrome_layout_refresh()

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
