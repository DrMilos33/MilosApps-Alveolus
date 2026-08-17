class_name DiscoveryTooltip
extends Control

signal dismissed

const PANEL_MIN_WIDTH := 300.0
const PANEL_MAX_WIDTH := 400.0
const VIEWPORT_MARGIN := 12.0
const TARGET_GAP := 56.0
const MINIMUM_COPY_VIEWPORT_HEIGHT := 88.0

var definition: DiscoveryDefinition
var target_object: Variant
var target_position: Vector2
var gameplay_override: String = ""
var highlighter: ObjectHighlighter
var panel: PanelContainer
var title_label: Label
var modal_content: VBoxContainer
var action_row: HBoxContainer
var copy_scroll: ScrollContainer
var copy_stack: VBoxContainer
var medical_label: Label
var gameplay_label: Label
var understood_button: Button

var _layout_generation := 0
var _dismiss_queued := false
var _compact_sheet_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 950

	highlighter = ObjectHighlighter.new()
	highlighter.geometry_changed.connect(_on_target_geometry_changed)
	add_child(highlighter)

	copy_scroll = ScrollContainer.new()
	copy_scroll.name = "DiscoveryCopyScroll"
	copy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	copy_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	copy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_scroll.follow_focus = true

	copy_stack = VBoxContainer.new()
	copy_stack.name = "DiscoveryCopy"
	copy_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_stack.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	copy_scroll.add_child(copy_stack)

	var gameplay_section := AlveolusUIComponents.semantic_copy_section(
		"Spielwirkung",
		"",
		&"ability",
		AlveolusVisualTheme.TEAL
	)
	gameplay_label = gameplay_section["body"] as Label
	copy_stack.add_child(gameplay_section["panel"] as Control)

	var medical_section := AlveolusUIComponents.semantic_copy_section(
		"Medizinischer Kontext",
		"",
		&"lexicon",
		AlveolusVisualTheme.COBALT
	)
	medical_label = medical_section["body"] as Label
	copy_stack.add_child(medical_section["panel"] as Control)

	understood_button = AlveolusUIComponents.action_button(
		"Verstanden",
		AlveolusUIComponents.ACTION_PRIMARY,
		&"check"
	)
	understood_button.name = "Understood"
	understood_button.pressed.connect(_request_dismiss)
	understood_button.gui_input.connect(_on_action_gui_input)

	var actions: Array[Control] = [understood_button]
	var modal_parts := AlveolusUIComponents.modal_sheet("Neue Entdeckung", copy_scroll, actions)
	panel = modal_parts["panel"] as PanelContainer
	panel.name = "DiscoveryModal"
	panel.custom_minimum_size = Vector2(PANEL_MIN_WIDTH, 0.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	modal_content = modal_parts["content"] as VBoxContainer
	action_row = modal_parts["actions"] as HBoxContainer
	title_label = modal_content.get_child(0) as Label
	title_label.name = "DiscoveryTitle"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_trap_focus_on_action()
	resized.connect(_on_resized)
	hide()


func present(item: DiscoveryDefinition, target: Variant, override_text: String = "") -> void:
	definition = item
	target_object = target
	gameplay_override = override_text
	_dismiss_queued = false
	title_label.text = "Neu · %s" % definition.title
	gameplay_label.text = gameplay_override if not gameplay_override.is_empty() else definition.gameplay_text
	medical_label.text = definition.medical_text

	_refresh_target_geometry()
	panel.hide()
	show()
	_layout_generation += 1
	_measure_and_place.call_deferred(_layout_generation, 0)
	understood_button.grab_focus()
	queue_redraw()


func conceal() -> void:
	_layout_generation += 1
	_compact_sheet_active = false
	highlighter.clear()
	target_object = null
	hide()


func is_compact_sheet_active() -> bool:
	return _compact_sheet_active


func _measure_and_place(generation: int, phase: int) -> void:
	if generation != _layout_generation or not visible:
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var available_width := maxf(1.0, viewport_size.x - VIEWPORT_MARGIN * 2.0)
	var width := minf(PANEL_MAX_WIDTH, available_width)
	var maximum_height := maxf(1.0, viewport_size.y - VIEWPORT_MARGIN * 2.0)
	if available_width >= PANEL_MIN_WIDTH:
		width = maxf(width, PANEL_MIN_WIDTH)

	if phase == 0:
		copy_scroll.custom_minimum_size.y = 0.0
		# Lay out the copy once at its real width before measuring wrapped text.
		# Keeping the sheet hidden would leave the labels at a one-pixel width and
		# falsely classify short copy as a viewport-sized scroll document.
		copy_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		panel.custom_minimum_size = Vector2(width, 1.0)
		panel.size = Vector2(width, maximum_height)
		panel.modulate.a = 0.0
		panel.show()
		_update_panel_position()
		get_tree().process_frame.connect(
			_measure_and_place.bind(generation, 1),
			CONNECT_ONE_SHOT
		)
		return

	var copy_height := ceilf(copy_stack.get_combined_minimum_size().y)
	copy_scroll.custom_minimum_size.y = copy_height
	copy_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content_margin := modal_content.get_parent() as MarginContainer
	var outer_vertical_margin := 0.0
	if content_margin != null:
		outer_vertical_margin = float(content_margin.get_theme_constant("margin_top") + content_margin.get_theme_constant("margin_bottom"))
	var fixed_chrome_height := ceilf(
		title_label.get_combined_minimum_size().y
		+ action_row.get_combined_minimum_size().y
		+ float(modal_content.get_theme_constant("separation")) * 2.0
		+ outer_vertical_margin
	)
	var full_height := fixed_chrome_height + copy_height
	if full_height > maximum_height:
		var available_copy_height := maxf(
			minf(MINIMUM_COPY_VIEWPORT_HEIGHT, copy_height),
			maximum_height - fixed_chrome_height
		)
		copy_scroll.custom_minimum_size.y = minf(copy_height, available_copy_height)
		copy_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		full_height = fixed_chrome_height + copy_scroll.custom_minimum_size.y

	panel.custom_minimum_size = Vector2(width, minf(full_height, maximum_height))
	panel.size = panel.custom_minimum_size
	_update_panel_position()
	panel.modulate.a = 1.0
	panel.show()
	queue_redraw()


func _update_panel_position() -> void:
	# This control lives under the scaled HUD root. Its own size is therefore
	# the authoritative logical viewport; the physical viewport would move the
	# modal out of bounds at 125–200 % UI scaling.
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var right_x := target_position.x + TARGET_GAP
	var left_x := target_position.x - panel.size.x - TARGET_GAP
	var fits_right := right_x + panel.size.x <= viewport_size.x - VIEWPORT_MARGIN
	var fits_left := left_x >= VIEWPORT_MARGIN
	_compact_sheet_active = not fits_right and not fits_left
	var maximum_x := maxf(VIEWPORT_MARGIN, viewport_size.x - panel.size.x - VIEWPORT_MARGIN)
	var maximum_y := maxf(VIEWPORT_MARGIN, viewport_size.y - panel.size.y - VIEWPORT_MARGIN)
	if _compact_sheet_active:
		# At high UI scales there is no meaningful side for an anchored tooltip.
		# A centered, blocking sheet is clearer than covering the very object the
		# connector claims to explain. The target remains bound and is restored as
		# soon as enough side room becomes available again.
		panel.position = Vector2(
			clampf((viewport_size.x - panel.size.x) * 0.5, VIEWPORT_MARGIN, maximum_x),
			clampf((viewport_size.y - panel.size.y) * 0.5, VIEWPORT_MARGIN, maximum_y)
		)
		highlighter.hide()
		queue_redraw()
		return
	var x := right_x if fits_right else left_x
	panel.position = Vector2(
		clampf(x, VIEWPORT_MARGIN, maximum_x),
		clampf(target_position.y - panel.size.y * 0.5, VIEWPORT_MARGIN, maximum_y)
	)
	highlighter.visible = highlighter.strength > 0.001 and highlighter.shape != ObjectHighlighter.Shape.NONE


func _on_resized() -> void:
	if not visible or panel == null:
		return
	# Re-resolve once after a logical viewport change. The run remains paused, so
	# this keeps the anchor exact without introducing a permanent polling owner.
	_refresh_target_geometry()
	_layout_generation += 1
	_measure_and_place.call_deferred(_layout_generation, 0)
	queue_redraw()


func _refresh_target_geometry() -> void:
	var resolved_target: Variant = target_object
	if resolved_target == null:
		var logical_size := size
		if logical_size.x <= 0.0 or logical_size.y <= 0.0:
			logical_size = get_viewport_rect().size
		resolved_target = logical_size * 0.5
	highlighter.clear()
	highlighter.follow(resolved_target, AlveolusVisualTheme.GOLD, 5.0)
	# A discovery pauses the run, so its highlighted target cannot move between
	# explicit geometry/viewport changes.
	highlighter.set_process(false)
	target_position = highlighter.center()
	if _compact_sheet_active:
		highlighter.hide()


func _draw() -> void:
	if not visible or panel == null or not panel.visible or _compact_sheet_active:
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
	draw_colored_polygon(PackedVector2Array([
		end,
		end - direction * 12.0 + side,
		end - direction * 12.0 - side,
	]), AlveolusVisualTheme.GOLD)


func _on_target_geometry_changed(bounds: Rect2) -> void:
	target_position = bounds.get_center()
	if panel != null and panel.visible:
		_update_panel_position()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _is_fresh_action(event, &"ui_cancel") or _is_confirmation_key(event):
		_request_dismiss()
		accept_event()


func _on_action_gui_input(event: InputEvent) -> void:
	if not _is_fresh_action(event, &"ui_cancel"):
		return
	_request_dismiss()
	get_viewport().set_input_as_handled()


func _request_dismiss() -> void:
	if not visible or _dismiss_queued:
		return
	_dismiss_queued = true
	dismissed.emit()
	_clear_dismiss_guard.call_deferred()


func _clear_dismiss_guard() -> void:
	_dismiss_queued = false


func _trap_focus_on_action() -> void:
	var self_path := understood_button.get_path_to(understood_button)
	understood_button.focus_previous = self_path
	understood_button.focus_next = self_path
	understood_button.focus_neighbor_left = self_path
	understood_button.focus_neighbor_right = self_path
	understood_button.focus_neighbor_top = self_path
	understood_button.focus_neighbor_bottom = self_path


func _is_fresh_action(event: InputEvent, action: StringName) -> bool:
	if not event.is_action_pressed(action):
		return false
	return not (event is InputEventKey and (event as InputEventKey).echo)


func _is_confirmation_key(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
