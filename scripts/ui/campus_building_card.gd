class_name CampusBuildingCard
extends Control

signal selected

var accent: Color = Color("f2bd68")
var title_text: String = ""
var status_text: String = ""
var building_polygon := PackedVector2Array()
var title_label: Label
var status_label: Label
var highlighter: ObjectHighlighter
var hover_amount: float = 0.0
var highlighted_status: bool = false
var mouse_over: bool = false

func configure(title: String, polygon: PackedVector2Array, card_accent: Color, label_position: Vector2) -> void:
	title_text = title
	building_polygon = polygon
	accent = card_accent
	highlighter = ObjectHighlighter.new()
	add_child(highlighter)
	highlighter.show_polygon(building_polygon, accent, 0.0)
	_build_labels(label_position)

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_mouse_over.bind(true))
	mouse_exited.connect(_set_mouse_over.bind(false))
	focus_entered.connect(_wake_animation)
	focus_exited.connect(_wake_animation)
	set_process(false)

func _build_labels(label_position: Vector2) -> void:
	if title_label != null:
		return
	var label_panel := Panel.new()
	label_panel.position = label_position
	label_panel.size = Vector2(size.x - label_position.x * 2.0, 30.0)
	label_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.075, 0.88)
	style.border_color = Color(0.55, 0.68, 0.70, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	label_panel.add_theme_stylebox_override("panel", style)
	add_child(label_panel)
	title_label = Label.new()
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color("eaf2ef"))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_panel.add_child(title_label)
	status_label = Label.new()
	status_label.position = label_position + Vector2(0.0, 32.0)
	status_label.size = Vector2(size.x - label_position.x * 2.0, 20.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", Color("b7c9c5"))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.modulate.a = 0.0
	add_child(status_label)

func set_status(text: String, highlighted: bool = false) -> void:
	status_text = text
	highlighted_status = highlighted
	if status_label != null:
		status_label.text = text

func _has_point(point: Vector2) -> bool:
	return building_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(point, building_polygon)

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
	hover_amount = move_toward(hover_amount, target, delta * 9.0)
	if highlighter != null:
		highlighter.set_strength(hover_amount)
	if title_label != null:
		title_label.add_theme_color_override("font_color", Color("eaf2ef").lerp(accent, hover_amount))
	if status_label != null:
		status_label.modulate = Color(accent if highlighted_status else Color("b7c9c5"), hover_amount)
	if is_equal_approx(hover_amount, target):
		set_process(false)

func _set_mouse_over(value: bool) -> void:
	mouse_over = value
	set_process(true)

func _wake_animation() -> void:
	set_process(true)
