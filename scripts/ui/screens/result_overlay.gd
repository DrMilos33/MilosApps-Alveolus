class_name ResultOverlay
extends Control

signal retry
signal levels
signal campus

const CANCEL_POLICY := &"consume"
const COMPACT_WIDTH := 700.0
const MODAL_MAXIMUM_WIDTH := 660.0
const MODAL_PADDING := 16
const MINIMUM_BODY_VIEWPORT_HEIGHT := 34.0

var _view_model: ResultOverlayViewModel
var _applied_revision := -1
var _applied_content_hash := 0
var _safe_area: MarginContainer
var _scroll: ScrollContainer
var _center: CenterContainer
var _modal_host: VBoxContainer
var _modal: PanelContainer
var _body_content: VBoxContainer
var _action_row: HBoxContainer
var _stats_grid: GridContainer
var _action_grid: GridContainer
var _compact_secondary_grid: GridContainer
var _levels_button: Button
var _retry_button: Button
var _campus_button: Button
var _compact_layout := false


func _init() -> void:
	set_process(false)
	set_physics_process(false)
	_build_stage()


func apply(view_model: ResultOverlayViewModel) -> bool:
	if view_model == null:
		return false
	var next_revision := view_model.get_revision()
	var next_hash := view_model.get_content_hash()
	if next_revision < _applied_revision:
		return false
	if next_revision == _applied_revision and _view_model != null:
		return false
	if _view_model != null and next_hash == _applied_content_hash:
		_view_model = view_model.duplicate_immutable()
		_applied_revision = next_revision
		return false
	_view_model = view_model.duplicate_immutable()
	_applied_revision = next_revision
	_applied_content_hash = next_hash
	_rebuild_modal()
	return true


func apply_view_model(view_model: ResultOverlayViewModel) -> bool:
	return apply(view_model)


func get_applied_revision() -> int:
	return _applied_revision


func get_applied_content_hash() -> int:
	return _applied_content_hash


func get_view_model() -> ResultOverlayViewModel:
	return _view_model.duplicate_immutable() if _view_model != null else null


func get_cancel_policy() -> StringName:
	return CANCEL_POLICY


func consumes_cancel() -> bool:
	return true


## The completed result is a terminal layer. ui_cancel is acknowledged while
## visible, but deliberately emits no navigation intent and cannot dismiss it.
func handle_ui_cancel() -> bool:
	return is_inside_tree() and is_visible_in_tree()


func get_default_focus_control() -> Control:
	return _levels_button


func grab_initial_focus() -> void:
	if _levels_button == null:
		return
	# The dominant action lives in the sticky footer. It must not change the
	# internal result-body position while the sheet is opening.
	if _scroll != null:
		_scroll.follow_focus = false
		_scroll.scroll_vertical = 0
	_levels_button.grab_focus()
	_restore_initial_scroll.call_deferred()


func get_scroll_container() -> ScrollContainer:
	return _scroll


func get_modal() -> PanelContainer:
	return _modal


func get_stats_column_count() -> int:
	return _stats_grid.columns if _stats_grid != null else 0


func get_action_column_count() -> int:
	if _compact_layout and _compact_secondary_grid != null:
		return _compact_secondary_grid.columns
	return _action_grid.columns if _action_grid != null else 0


func is_compact_layout() -> bool:
	return _compact_layout


func _build_stage() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED

	var dimmer := ColorRect.new()
	dimmer.name = "Backdrop"
	dimmer.color = Color(AlveolusVisualTheme.PETROL_DEEP, 0.90)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	_safe_area = MarginContainer.new()
	_safe_area.name = "SafeArea"
	_safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_area)

	_center = CenterContainer.new()
	_center.name = "ResultCenter"
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_safe_area.add_child(_center)

	_modal_host = VBoxContainer.new()
	_modal_host.name = "ModalHost"
	_modal_host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_center.add_child(_modal_host)

	resized.connect(_refresh_responsive_layout)


func _rebuild_modal() -> void:
	for child in _modal_host.get_children():
		_modal_host.remove_child(child)
		child.queue_free()

	var accent := AlveolusVisualTheme.TEAL if _view_model.is_success() else AlveolusVisualTheme.CORAL
	_body_content = VBoxContainer.new()
	_body_content.name = "ResultContent"
	_body_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)

	var heading := HBoxContainer.new()
	heading.name = "OutcomeHeading"
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_body_content.add_child(heading)
	var outcome_icon := SimpleIcon.new()
	outcome_icon.name = "OutcomeIcon"
	outcome_icon.custom_minimum_size = Vector2(34.0, 34.0)
	outcome_icon.configure(&"check" if _view_model.is_success() else &"remove", accent)
	heading.add_child(outcome_icon)
	var title := AlveolusUIComponents.label(_view_model.get_title(), AlveolusVisualTheme.TYPE_TITLE_LABEL)
	title.name = "OutcomeTitle"
	title.add_theme_color_override("font_color", accent.lightened(0.12))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	heading.add_child(title)

	var reason_text := _view_model.get_reason().strip_edges()
	if not reason_text.is_empty():
		var reason := AlveolusUIComponents.label(reason_text, AlveolusVisualTheme.TYPE_BODY_LABEL)
		reason.name = "Reason"
		reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body_content.add_child(reason)
	var detail_text := _view_model.get_detail().strip_edges()
	if not detail_text.is_empty():
		var detail := AlveolusUIComponents.label(detail_text, AlveolusVisualTheme.TYPE_MUTED_LABEL)
		detail.name = "Detail"
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body_content.add_child(detail)

	_stats_grid = GridContainer.new()
	_stats_grid.name = "StatsGrid"
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_stats_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	for stat in _view_model.get_stats():
		var row := AlveolusUIComponents.value_row(stat.get_label(), stat.get_value(), stat.is_highlighted())
		row.name = "Stat_%s" % String(stat.get_id())
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats_grid.add_child(row)
	if _stats_grid.get_child_count() > 0:
		_body_content.add_child(_stats_grid)

	_add_optional_section(_body_content, &"reward", "Belohnung", _view_model.get_reward_text(), &"research", AlveolusVisualTheme.GOLD)
	_add_optional_section(_body_content, &"unlock", "Freigeschaltet", _view_model.get_unlock_text(), &"archive", AlveolusVisualTheme.COBALT)
	_add_optional_section(_body_content, &"mastery", "Meisterschaft", _view_model.get_mastery_text(), &"check", AlveolusVisualTheme.TURQUOISE)

	_scroll = ScrollContainer.new()
	_scroll.name = "ResultBodyScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = false
	_scroll.add_child(_body_content)
	_scroll.resized.connect(_refresh_responsive_layout)

	_action_grid = GridContainer.new()
	_action_grid.name = "ResultActions"
	_action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_action_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	_levels_button = AlveolusUIComponents.action_button(
		"Fallübersicht",
		AlveolusUIComponents.ACTION_PRIMARY,
		&"archive",
		AlveolusVisualTheme.TEAL
	)
	_levels_button.name = "LevelsButton"
	_levels_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_levels_button.pressed.connect(func() -> void: levels.emit())
	_action_grid.add_child(_levels_button)
	_retry_button = AlveolusUIComponents.action_button(
		"Erneut behandeln",
		AlveolusUIComponents.ACTION_SECONDARY,
		&"restart",
		AlveolusVisualTheme.TEAL
	)
	_retry_button.name = "RetryButton"
	_retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_retry_button.pressed.connect(func() -> void: retry.emit())
	_action_grid.add_child(_retry_button)
	_campus_button = AlveolusUIComponents.action_button(
		"Zum Campus",
		AlveolusUIComponents.ACTION_SECONDARY,
		&"back",
		AlveolusVisualTheme.COBALT
	)
	_campus_button.name = "CampusButton"
	_campus_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campus_button.pressed.connect(func() -> void: campus.emit())
	_action_grid.add_child(_campus_button)
	_compact_secondary_grid = GridContainer.new()
	_compact_secondary_grid.name = "CompactSecondaryActions"
	_compact_secondary_grid.columns = 2
	_compact_secondary_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_secondary_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_compact_secondary_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	_compact_secondary_grid.hide()
	_action_grid.add_child(_compact_secondary_grid)
	_link_action_focus_cycle()

	var modal_actions: Array[Control] = [_action_grid]
	var sheet := AlveolusUIComponents.modal_sheet("", _scroll, modal_actions, MODAL_PADDING, accent)
	_modal = sheet["panel"] as PanelContainer
	_action_row = sheet["actions"] as HBoxContainer
	_modal.name = "ResultModal"
	_modal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_modal.set_meta(&"result_success", _view_model.is_success())
	_modal.set_meta(&"cancel_policy", CANCEL_POLICY)
	_modal_host.add_child(_modal)
	if _scroll != null:
		_scroll.follow_focus = false
		_scroll.scroll_vertical = 0
	_refresh_responsive_layout.call_deferred()
	_restore_initial_scroll.call_deferred()


func _link_action_focus_cycle() -> void:
	var actions: Array[Button] = [_levels_button, _retry_button, _campus_button]
	for index in range(actions.size()):
		var action := actions[index]
		var previous := actions[(index - 1 + actions.size()) % actions.size()]
		var next := actions[(index + 1) % actions.size()]
		action.focus_neighbor_left = action.get_path_to(previous)
		action.focus_neighbor_top = action.get_path_to(previous)
		action.focus_neighbor_right = action.get_path_to(next)
		action.focus_neighbor_bottom = action.get_path_to(next)


func _add_optional_section(
	parent: VBoxContainer,
	section_id: StringName,
	title_text: String,
	body_text: String,
	icon_kind: StringName,
	accent: Color
) -> void:
	if body_text.is_empty():
		return
	var section := AlveolusUIComponents.semantic_copy_section(title_text, body_text, icon_kind, accent)
	var panel := section["panel"] as PanelContainer
	panel.name = "Optional_%s" % String(section_id)
	panel.set_meta(&"result_optional_section", section_id)
	(section["body"] as Label).name = "Optional_%s_Body" % String(section_id)
	parent.add_child(panel)


func _refresh_responsive_layout() -> void:
	if _safe_area == null:
		return
	var logical_width := size.x
	if logical_width <= 1.0 and get_viewport() != null:
		logical_width = get_viewport().get_visible_rect().size.x
	_compact_layout = logical_width < COMPACT_WIDTH
	var margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if _compact_layout else AlveolusVisualTheme.SCREEN_MARGIN
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_safe_area.add_theme_constant_override(side, margin)
	if _modal != null:
		var available_width := maxf(0.0, logical_width - float(margin * 2))
		_modal.custom_minimum_size.x = minf(MODAL_MAXIMUM_WIDTH, available_width)
		_modal.custom_minimum_size.y = 0.0
	if _stats_grid != null:
		_stats_grid.columns = 1 if _compact_layout else maxi(1, mini(3, _stats_grid.get_child_count()))
	if _apply_action_layout():
		_refresh_responsive_layout.call_deferred()
		return
	if _scroll != null and _body_content != null:
		var available_height := maxf(0.0, size.y - float(margin * 2))
		var footer_height := _action_row.get_combined_minimum_size().y if _action_row != null else 0.0
		var modal_chrome_height := float(MODAL_PADDING * 2)
		if _action_row != null:
			modal_chrome_height += float(AlveolusVisualTheme.CONTENT_GAP)
		var available_body_height := maxf(
			MINIMUM_BODY_VIEWPORT_HEIGHT,
			available_height - footer_height - modal_chrome_height
		)
		var content_height := _body_content.get_combined_minimum_size().y
		var visible_body_height := minf(content_height, available_body_height)
		_scroll.custom_minimum_size.y = visible_body_height
		var requires_scroll := content_height > visible_body_height + 1.0
		_scroll.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_AUTO if requires_scroll
			else ScrollContainer.SCROLL_MODE_DISABLED
		)
		if not requires_scroll:
			_scroll.scroll_vertical = 0


func _apply_action_layout() -> bool:
	if _action_grid == null or _compact_secondary_grid == null:
		return false
	var changed := false
	var secondary_buttons: Array[Button] = [_retry_button, _campus_button]
	if _compact_layout:
		changed = changed or _action_grid.columns != 1 or _compact_secondary_grid.columns != 2
		_action_grid.columns = 1
		_compact_secondary_grid.columns = 2
		_compact_secondary_grid.show()
		for button in secondary_buttons:
			if button != null and button.get_parent() != _compact_secondary_grid:
				button.reparent(_compact_secondary_grid, false)
				changed = true
	else:
		changed = changed or _action_grid.columns != 3 or _compact_secondary_grid.visible
		_action_grid.columns = 3
		for button in secondary_buttons:
			if button != null and button.get_parent() != _action_grid:
				button.reparent(_action_grid, false)
				changed = true
		_compact_secondary_grid.hide()
	if changed:
		_link_action_focus_cycle()
	return changed


func _restore_initial_scroll() -> void:
	if _scroll == null:
		return
	_scroll.scroll_vertical = 0
	_scroll.follow_focus = false
