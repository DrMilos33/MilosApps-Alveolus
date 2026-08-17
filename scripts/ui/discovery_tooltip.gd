class_name DiscoveryTooltip
extends Control

signal dismissed

const PANEL_SIZE := Vector2(360.0, 250.0)

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
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	title_label = _label("ENTDECKUNG", 16, AlveolusVisualTheme.GOLD)
	title_label.add_theme_font_override("font", AlveolusVisualTheme.heading_font())
	stack.add_child(title_label)
	var copy_scroll := ScrollContainer.new()
	copy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	copy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy_scroll.follow_focus = true
	stack.add_child(copy_scroll)
	var copy_stack := VBoxContainer.new()
	copy_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_stack.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	copy_scroll.add_child(copy_stack)
	var gameplay_section := AlveolusUIComponents.semantic_copy_section(
		"IM SPIEL",
		"",
		&"ability",
		AlveolusVisualTheme.TEAL
	)
	gameplay_label = gameplay_section["body"] as Label
	copy_stack.add_child(gameplay_section["panel"] as Control)
	var medical_section := AlveolusUIComponents.semantic_copy_section(
		"MEDIZINISCHER HINTERGRUND",
		"",
		&"lexicon",
		AlveolusVisualTheme.COBALT
	)
	medical_label = medical_section["body"] as Label
	copy_stack.add_child(medical_section["panel"] as Control)
	understood_button = Button.new()
	understood_button.text = "Verstanden"
	understood_button.custom_minimum_size = Vector2(0.0, AlveolusVisualTheme.TOUCH_TARGET_MINIMUM)
	understood_button.add_theme_font_size_override("font_size", 16)
	understood_button.add_theme_font_override("font", AlveolusVisualTheme.heading_font())
	understood_button.add_theme_color_override("font_color", AlveolusVisualTheme.PETROL)
	understood_button.add_theme_color_override("font_hover_color", AlveolusVisualTheme.PETROL)
	understood_button.add_theme_color_override("font_pressed_color", AlveolusVisualTheme.PETROL)
	understood_button.add_theme_color_override("font_focus_color", AlveolusVisualTheme.PETROL)
	understood_button.add_theme_stylebox_override("normal", AlveolusVisualTheme.button_style(AlveolusVisualTheme.TURQUOISE, &"normal", true))
	understood_button.add_theme_stylebox_override("hover", AlveolusVisualTheme.button_style(AlveolusVisualTheme.TURQUOISE, &"hover", true))
	understood_button.add_theme_stylebox_override("pressed", AlveolusVisualTheme.button_style(AlveolusVisualTheme.TURQUOISE, &"pressed", true))
	understood_button.add_theme_stylebox_override("focus", AlveolusVisualTheme.button_style(AlveolusVisualTheme.TURQUOISE, &"focus", true))
	understood_button.pressed.connect(func() -> void: dismissed.emit())
	stack.add_child(understood_button)
	var self_focus := understood_button.get_path_to(understood_button)
	understood_button.focus_previous = self_focus
	understood_button.focus_next = self_focus
	understood_button.focus_neighbor_left = self_focus
	understood_button.focus_neighbor_right = self_focus
	understood_button.focus_neighbor_top = self_focus
	understood_button.focus_neighbor_bottom = self_focus
	resized.connect(_on_resized)
	hide()

func present(item: DiscoveryDefinition, target: Variant, override_text: String = "") -> void:
	definition = item
	target_object = target
	gameplay_override = override_text
	title_label.text = "NEU · %s" % definition.title.to_upper()
	gameplay_label.text = gameplay_override if not gameplay_override.is_empty() else definition.gameplay_text
	medical_label.text = definition.medical_text
	var resolved_target: Variant = target_object
	if resolved_target == null:
		resolved_target = get_viewport_rect().size * 0.5
	highlighter.follow(resolved_target, AlveolusVisualTheme.GOLD, 5.0)
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
	# This control lives under the scaled HUD root. Its own size is therefore
	# the authoritative logical viewport; using the physical viewport here
	# would place the panel off-screen at 125–200 % UI scale.
	var viewport_size := size
	var x := target_position.x + 56.0
	if x + PANEL_SIZE.x > viewport_size.x - 18.0:
		x = target_position.x - PANEL_SIZE.x - 56.0
	var max_x := maxf(18.0, viewport_size.x - PANEL_SIZE.x - 18.0)
	var max_y := maxf(12.0, viewport_size.y - PANEL_SIZE.y - 12.0)
	var min_y := minf(74.0, max_y)
	var y := clampf(target_position.y - PANEL_SIZE.y * 0.5, min_y, max_y)
	panel.position = Vector2(clampf(x, 18.0, max_x), y)

func _on_resized() -> void:
	if visible and panel != null:
		_update_panel_position()
		queue_redraw()

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
	draw_line(start, end, AlveolusVisualTheme.GOLD, 2.0, true)
	var side := direction.orthogonal() * 7.0
	draw_colored_polygon(PackedVector2Array([end, end - direction * 12.0 + side, end - direction * 12.0 - side]), AlveolusVisualTheme.GOLD)

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
	label.add_theme_font_override("font", AlveolusVisualTheme.heading_font() if size >= 18 else AlveolusVisualTheme.body_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style() -> StyleBoxFlat:
	return AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.MODAL_SHEET,
		AlveolusVisualTheme.GOLD,
		AlveolusVisualTheme.CornerTreatment.SIGNATURE_6
	)
