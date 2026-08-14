class_name DiscoveryTooltip
extends Control

signal dismissed

const PANEL_SIZE := Vector2(330.0, 150.0)

var definition: DiscoveryDefinition
var target_object: Variant
var target_position: Vector2
var gameplay_override: String = ""
var highlighter: ObjectHighlighter
var panel: Panel
var title_label: Label
var medical_label: Label
var gameplay_label: Label
var understood_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	highlighter = ObjectHighlighter.new()
	highlighter.geometry_changed.connect(_on_target_geometry_changed)
	add_child(highlighter)
	panel = Panel.new()
	panel.size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	title_label = _label("ENTDECKUNG", 13, Color("f2bd68"))
	stack.add_child(title_label)
	medical_label = _label("", 10, Color("e7f3f1"))
	medical_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	medical_label.max_lines_visible = 2
	medical_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(medical_label)
	gameplay_label = _label("", 10, Color("91c8c3"))
	gameplay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gameplay_label.max_lines_visible = 2
	gameplay_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(gameplay_label)
	understood_button = Button.new()
	understood_button.text = "VERSTANDEN  ↵"
	understood_button.custom_minimum_size = Vector2(0.0, 28.0)
	understood_button.add_theme_font_size_override("font_size", 10)
	understood_button.add_theme_color_override("font_color", Color("102029"))
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("58dacb")
	button_style.set_corner_radius_all(7)
	understood_button.add_theme_stylebox_override("normal", button_style)
	understood_button.pressed.connect(func() -> void: dismissed.emit())
	stack.add_child(understood_button)
	hide()

func present(item: DiscoveryDefinition, target: Variant, override_text: String = "") -> void:
	definition = item
	target_object = target
	gameplay_override = override_text
	title_label.text = "NEU · %s" % definition.title.to_upper()
	medical_label.text = definition.medical_text
	gameplay_label.text = gameplay_override if not gameplay_override.is_empty() else definition.gameplay_text
	var resolved_target: Variant = target_object
	if resolved_target == null:
		resolved_target = get_viewport_rect().size * 0.5
	highlighter.follow(resolved_target, Color("f2bd68"), 5.0)
	target_position = highlighter.center()
	_update_panel_position()
	show()
	understood_button.grab_focus()
	queue_redraw()

func conceal() -> void:
	highlighter.clear()
	target_object = null
	hide()

func _update_panel_position() -> void:
	var viewport_size := get_viewport_rect().size
	var x := target_position.x + 56.0
	if x + PANEL_SIZE.x > viewport_size.x - 18.0:
		x = target_position.x - PANEL_SIZE.x - 56.0
	var y := clampf(target_position.y - PANEL_SIZE.y * 0.5, 74.0, viewport_size.y - PANEL_SIZE.y - 24.0)
	panel.position = Vector2(clampf(x, 18.0, viewport_size.x - PANEL_SIZE.x - 18.0), y)

func _draw() -> void:
	if not visible or panel == null:
		return
	var panel_center := panel.position + panel.size * 0.5
	var start := panel_center
	if panel_center.x > target_position.x:
		start.x = panel.position.x
	else:
		start.x = panel.position.x + panel.size.x
	var direction := (target_position - start).normalized()
	var target_extent := maxf(highlighter.bounds().size.x, highlighter.bounds().size.y) * 0.5
	var end := target_position - direction * (target_extent + 4.0)
	draw_line(start, end, Color("f2bd68"), 2.0, true)
	var side := direction.orthogonal() * 7.0
	draw_colored_polygon(PackedVector2Array([end, end - direction * 12.0 + side, end - direction * 12.0 - side]), Color("f2bd68"))

func _on_target_geometry_changed(bounds: Rect2) -> void:
	target_position = bounds.get_center()
	if panel != null:
		_update_panel_position()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			dismissed.emit()
			accept_event()

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.09, 0.12, 0.98)
	style.border_color = Color("f2bd68")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 8
	return style
