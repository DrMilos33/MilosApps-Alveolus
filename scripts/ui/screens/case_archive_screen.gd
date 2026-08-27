class_name CaseArchiveScreen
extends Control

signal case_selected(case_id: StringName)
signal replay_story
signal back

const CARD_HEIGHT := 88.0
const CARD_HEIGHT_COMPACT := 84.0
const STATION_MEDALLION_SIZE := 40.0
const WIDE_BOARD_COLUMNS := 4
const COMPACT_BOARD_COLUMNS := 2
const SINGLE_BOARD_BREAKPOINT := 400.0
const COMPACT_BOARD_BREAKPOINT := 760.0

var _applied_revision := -1
var _applied_content_hash := 0
var _view_model: CaseArchiveViewModel
var _shell: PanelContainer
var _safe_area: MarginContainer
var _shell_stack: VBoxContainer
var _header: PanelContainer
var _scroll: ScrollContainer
var _board: GridContainer
var _header_actions: HBoxContainer
var _replay_button: Button
var _back_button: Button
var _cards: Dictionary = {}


func _init() -> void:
	set_process(false)
	set_physics_process(false)
	_build_interface()


func apply_view_model(view_model: CaseArchiveViewModel) -> bool:
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
		_applied_revision = maxi(_applied_revision, next_revision)
		return false
	_view_model = view_model.duplicate_immutable()
	_applied_revision = next_revision
	_applied_content_hash = next_hash
	_rebuild_cards()
	return true


func apply(view_model: CaseArchiveViewModel) -> bool:
	return apply_view_model(view_model)


func get_applied_revision() -> int:
	return _applied_revision


func get_applied_content_hash() -> int:
	return _applied_content_hash


func get_view_model() -> CaseArchiveViewModel:
	return _view_model.duplicate_immutable() if _view_model != null else null


func get_scroll_container() -> ScrollContainer:
	return _scroll


func card_for_case(case_id: StringName) -> Button:
	return _cards.get(case_id) as Button


func get_default_focus_control() -> Control:
	if _view_model == null:
		return null
	var selected_id := _view_model.get_selected_case_id()
	var selected_card := card_for_case(selected_id)
	if selected_card != null and not selected_card.disabled:
		return selected_card
	var next_card := card_for_case(_view_model.get_next_case_id())
	if next_card != null and not next_card.disabled:
		return next_card
	for entry in _view_model.get_entries():
		var card := card_for_case(entry.get_id())
		if card != null and not card.disabled:
			return card
	return null


func grab_initial_focus() -> void:
	var focus_control := get_default_focus_control()
	if focus_control != null:
		focus_control.grab_focus()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED

	_replay_button = AlveolusUIComponents.action_button(
		"Prolog",
		AlveolusUIComponents.ACTION_NAVIGATION,
		&"story",
		AlveolusVisualTheme.COBALT
	)
	_replay_button.name = "ReplayStoryButton"
	_replay_button.pressed.connect(func() -> void: replay_story.emit())

	_back_button = AlveolusUIComponents.action_button(
		"Zum Campus",
		AlveolusUIComponents.ACTION_NAVIGATION,
		&"back",
		AlveolusVisualTheme.TEAL
	)
	_back_button.name = "BackButton"
	_back_button.pressed.connect(func() -> void: back.emit())

	_header_actions = HBoxContainer.new()
	_header_actions.name = "HeaderActions"
	_header_actions.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_header_actions.add_child(_replay_button)
	_header_actions.add_child(_back_button)

	var header_parts := AlveolusUIComponents.page_header("Fallarchiv", "", _header_actions)
	var header := header_parts["panel"] as PanelContainer
	header.name = "PageHeader"
	_header = header

	var content := VBoxContainer.new()
	content.name = "ArchiveContent"
	content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	_scroll = ScrollContainer.new()
	_scroll.name = "CaseScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	_scroll.gui_input.connect(_on_board_gui_input)
	content.add_child(_scroll)

	_board = GridContainer.new()
	_board.name = "CaseBoard"
	_board.columns = WIDE_BOARD_COLUMNS
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_board.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_board.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	_board.set_meta(&"alveolus_component", &"case_board")
	_scroll.add_child(_board)
	_scroll.resized.connect(_refresh_board_geometry)

	var shell_parts := AlveolusUIComponents.page_shell(header, content)
	_shell = shell_parts["shell"] as PanelContainer
	_safe_area = shell_parts["safe_area"] as MarginContainer
	_shell_stack = shell_parts["stack"] as VBoxContainer
	_shell.name = "PageShell"
	add_child(_shell)
	resized.connect(_refresh_responsive_layout)
	_refresh_responsive_layout.call_deferred()


func _rebuild_cards() -> void:
	for child in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	_cards.clear()
	if _view_model == null:
		return
	var next_id := _view_model.get_next_case_id()
	for entry_value in _sorted_entries():
		var entry := entry_value as CaseArchiveViewModel.CaseEntryViewModel
		if entry == null:
			continue
		var state := _journey_state(entry, next_id)
		var card := _build_case_card(entry, state)
		_board.add_child(card)
		_cards[entry.get_id()] = card
	_configure_focus_path()
	_refresh_responsive_layout.call_deferred()
	_scroll_to_primary_card.call_deferred()


func _build_case_card(
	entry: CaseArchiveViewModel.CaseEntryViewModel,
	state: StringName
) -> Button:
	var visually_primary := state == &"current"
	var card := AlveolusUIComponents.choice_row("", "", "", visually_primary, not entry.is_unlocked())
	card.name = "Case_%s" % String(entry.get_id())
	card.custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.set_meta(&"case_id", entry.get_id())
	card.set_meta(&"journey_state", state)
	card.set_meta(&"alveolus_owns_directional_focus", true)
	card.set_meta(&"alveolus_accessible_name", _accessible_name(entry, state))
	card.focus_entered.connect(_ensure_card_visible.bind(card))
	card.gui_input.connect(_on_board_gui_input)
	card.pressed.connect(_emit_case_selected.bind(entry.get_id()))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)

	var medallion := AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_DOCUMENT_INSET)
	medallion.name = "CaseStationMedallion"
	medallion.custom_minimum_size = Vector2.ONE * STATION_MEDALLION_SIZE
	medallion.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	medallion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medallion.set_meta(&"alveolus_component", &"case_station_medallion")
	var medallion_center := CenterContainer.new()
	medallion_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medallion.add_child(medallion_center)
	var station_icon := SimpleIcon.new()
	station_icon.name = "CaseStationIcon"
	station_icon.custom_minimum_size = Vector2.ONE * 24.0
	station_icon.configure(_station_icon_kind(entry, state), _station_accent(entry, state))
	medallion_center.add_child(station_icon)
	row.add_child(medallion)

	var copy := VBoxContainer.new()
	copy.name = "CaseCopy"
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)

	var status := AlveolusUIComponents.label(_station_status_text(entry, state), AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	status.name = "Status"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.clip_text = true
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.max_lines_visible = 1
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.add_theme_color_override("font_color", _station_accent(entry, state).lightened(0.16))
	copy.add_child(status)

	var title := AlveolusUIComponents.label(entry.get_title(), AlveolusVisualTheme.TYPE_SECTION_LABEL)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.max_lines_visible = 1
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)

	var summary := AlveolusUIComponents.label(
		_station_summary(entry, state),
		AlveolusVisualTheme.TYPE_MUTED_LABEL
	)
	summary.name = "Summary"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.clip_text = true
	summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	summary.max_lines_visible = 1
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(summary)

	if state == &"locked":
		row.modulate = Color(0.82, 0.86, 0.87, 0.82)

	var card_margin := AlveolusUIComponents.margin(row, 12)
	card_margin.name = "CaseCardMargin"
	card_margin.add_theme_constant_override("margin_left", 10)
	card_margin.add_theme_constant_override("margin_top", 8)
	card_margin.add_theme_constant_override("margin_right", 10)
	card_margin.add_theme_constant_override("margin_bottom", 8)
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_margin)
	card_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return card


func _emit_case_selected(case_id: StringName) -> void:
	case_selected.emit(case_id)


func _compact_summary(best_text: String, record_text: String) -> String:
	# Records are the only card-level performance fact. Historical duration is
	# deliberately omitted from the archive overview and remains in save data.
	if not record_text.is_empty():
		return record_text
	return best_text


func _journey_state(entry: CaseArchiveViewModel.CaseEntryViewModel, next_id: StringName) -> StringName:
	if not entry.is_unlocked():
		return &"locked"
	if entry.is_completed():
		return &"completed"
	if entry.get_id() == next_id:
		return &"current"
	return &"available"


func _station_status_text(entry: CaseArchiveViewModel.CaseEntryViewModel, state: StringName) -> String:
	var prefix := "PROLOG" if entry.is_tutorial() else "FALL %02d" % entry.get_order()
	match state:
		&"completed":
			return "%s · ABGESCHLOSSEN" % prefix
		&"current":
			return "%s · NÄCHSTER FALL" % prefix
		&"locked":
			return "%s · GESPERRT" % prefix
	return "%s · BEREIT" % prefix


func _station_summary(entry: CaseArchiveViewModel.CaseEntryViewModel, state: StringName) -> String:
	match state:
		&"current":
			return "Bereit zur Einsatzplanung"
		&"locked":
			return "Folgt auf vorherige Einsätze"
	return _compact_summary(entry.get_best_text(), entry.get_record_text())


func _station_icon_kind(entry: CaseArchiveViewModel.CaseEntryViewModel, state: StringName) -> StringName:
	match state:
		&"completed":
			return &"check"
		&"current":
			return &"target"
		&"locked":
			return &"locked"
	return &"story" if entry.is_tutorial() else &"levels"


func _station_accent(entry: CaseArchiveViewModel.CaseEntryViewModel, state: StringName) -> Color:
	match state:
		&"completed":
			return AlveolusVisualTheme.TEAL
		&"current":
			return AlveolusVisualTheme.GOLD
		&"locked":
			return AlveolusVisualTheme.MUTED
	return entry.get_accent()


func _refresh_board_geometry() -> void:
	if _scroll == null or _board == null:
		return
	var logical_width := _layout_authority_width()
	var columns := _board_columns_for_width(logical_width)
	if _board.columns != columns:
		_board.columns = columns
		_configure_focus_path()
	var compact := columns < WIDE_BOARD_COLUMNS
	for card_value in _cards.values():
		var card := card_value as Button
		if card == null:
			continue
		card.custom_minimum_size = Vector2(0.0, CARD_HEIGHT_COMPACT if compact else CARD_HEIGHT)
	_scroll_to_primary_card.call_deferred()


func _board_columns_for_width(logical_width: float) -> int:
	if logical_width < SINGLE_BOARD_BREAKPOINT:
		return 1
	if logical_width < COMPACT_BOARD_BREAKPOINT:
		return COMPACT_BOARD_COLUMNS
	return WIDE_BOARD_COLUMNS


func _refresh_responsive_layout() -> void:
	# The screen is built before it is mounted under the scaled HUD root. Refit
	# the shell after this layout pass, when the final host rect is available.
	# Doing this deferred preserves the full-rect anchors without creating a
	# resize feedback loop through the PanelContainer's children.
	_fit_shell_to_host.call_deferred()
	var compact := _layout_authority_width() < 620.0
	AlveolusUIComponents.refresh_page_shell_layout(_shell, compact)
	_header_actions.add_theme_constant_override(
		"separation",
		AlveolusVisualTheme.GRID_UNIT if compact else AlveolusVisualTheme.CONTROL_GAP
	)
	if _replay_button is IconTextButton:
		(_replay_button as IconTextButton).set_caption("Prolog", compact)
	if _back_button is IconTextButton:
		(_back_button as IconTextButton).set_caption("Campus" if compact else "Zum Campus", compact)
	_back_button.set_meta(&"alveolus_accessible_name", "Zum Campus")
	_back_button.tooltip_text = "Zum Campus" if compact else ""
	_refresh_board_geometry.call_deferred()


func _layout_authority_width() -> float:
	var logical_width := size.x
	var host := get_parent() as Control
	if host != null and host.size.x > 0.0:
		logical_width = minf(logical_width, host.size.x) if logical_width > 0.0 else host.size.x
	return logical_width


func _configure_focus_path() -> void:
	if _view_model == null or _board == null:
		return
	var sorted_entries := _sorted_entries()
	var focusable_indices: Array[int] = []
	for index in range(sorted_entries.size()):
		var entry := sorted_entries[index] as CaseArchiveViewModel.CaseEntryViewModel
		var card := card_for_case(entry.get_id())
		if card == null:
			continue
		card.focus_neighbor_left = NodePath()
		card.focus_neighbor_top = NodePath()
		card.focus_neighbor_right = NodePath()
		card.focus_neighbor_bottom = NodePath()
		if not card.disabled:
			focusable_indices.append(index)
	var columns := maxi(1, _board.columns)
	for source_index in focusable_indices:
		var source_entry := sorted_entries[source_index] as CaseArchiveViewModel.CaseEntryViewModel
		var source := card_for_case(source_entry.get_id())
		_set_focus_neighbor(source, &"focus_neighbor_left", _spatial_neighbor(source_index, focusable_indices, columns, Vector2i.LEFT), sorted_entries, _replay_button)
		_set_focus_neighbor(source, &"focus_neighbor_right", _spatial_neighbor(source_index, focusable_indices, columns, Vector2i.RIGHT), sorted_entries, _back_button)
		_set_focus_neighbor(source, &"focus_neighbor_top", _spatial_neighbor(source_index, focusable_indices, columns, Vector2i.UP), sorted_entries, _replay_button)
		_set_focus_neighbor(source, &"focus_neighbor_bottom", _spatial_neighbor(source_index, focusable_indices, columns, Vector2i.DOWN), sorted_entries, _back_button)


func _spatial_neighbor(source_index: int, candidates: Array[int], columns: int, direction: Vector2i) -> int:
	var source_row := source_index / columns
	var source_column := source_index % columns
	var best_index := -1
	var best_primary := 1000000
	var best_secondary := 1000000
	for candidate_index in candidates:
		if candidate_index == source_index:
			continue
		var candidate_row := candidate_index / columns
		var candidate_column := candidate_index % columns
		var primary := 0
		var secondary := 0
		if direction == Vector2i.LEFT or direction == Vector2i.RIGHT:
			if candidate_row != source_row:
				continue
			var delta_column := candidate_column - source_column
			if direction == Vector2i.LEFT and delta_column >= 0:
				continue
			if direction == Vector2i.RIGHT and delta_column <= 0:
				continue
			primary = absi(delta_column)
		else:
			var delta_row := candidate_row - source_row
			if direction == Vector2i.UP and delta_row >= 0:
				continue
			if direction == Vector2i.DOWN and delta_row <= 0:
				continue
			primary = absi(delta_row)
			secondary = absi(candidate_column - source_column)
		if primary < best_primary or (primary == best_primary and secondary < best_secondary):
			best_index = candidate_index
			best_primary = primary
			best_secondary = secondary
	return best_index


func _set_focus_neighbor(
	source: Control,
	property_name: StringName,
	target_index: int,
	sorted_entries: Array[CaseArchiveViewModel.CaseEntryViewModel],
	fallback: Control
) -> void:
	if source == null:
		return
	var target := fallback
	if target_index >= 0 and target_index < sorted_entries.size():
		target = card_for_case(sorted_entries[target_index].get_id())
	if target != null:
		source.set(property_name, source.get_path_to(target))


func _on_board_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not (event as InputEventMouseButton).pressed:
		return
	var mouse_event := event as InputEventMouseButton
	var step := 0
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		step = -1
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step = 1
	if step == 0:
		return
	_move_focus_by_case(step)
	accept_event()


func _move_focus_by_case(step: int) -> bool:
	var focusable := _focusable_cards_in_order()
	if focusable.is_empty():
		return false
	var focus_owner := get_viewport().gui_get_focus_owner()
	var source_index := focusable.find(focus_owner)
	if source_index < 0:
		source_index = focusable.find(get_default_focus_control())
		if source_index < 0:
			source_index = 0
	var target_index := clampi(source_index + signi(step), 0, focusable.size() - 1)
	var target := focusable[target_index]
	if focus_owner != target:
		target.grab_focus()
	_ensure_card_visible(target)
	return target_index != source_index or focus_owner != target


func _focusable_cards_in_order() -> Array[Button]:
	var result: Array[Button] = []
	for entry in _sorted_entries():
		var card := card_for_case(entry.get_id())
		if card != null and not card.disabled:
			result.append(card)
	return result


func _sorted_entries() -> Array[CaseArchiveViewModel.CaseEntryViewModel]:
	var entries := _view_model.get_entries() if _view_model != null else []
	entries.sort_custom(func(a: CaseArchiveViewModel.CaseEntryViewModel, b: CaseArchiveViewModel.CaseEntryViewModel) -> bool: return a.get_order() < b.get_order())
	return entries


func _ensure_card_visible(card: Control) -> void:
	if card != null and _scroll != null:
		_scroll.ensure_control_visible(card)


func _scroll_to_primary_card() -> void:
	var primary := get_default_focus_control()
	if primary != null and _scroll != null:
		_scroll.ensure_control_visible(primary)


func _fit_shell_to_host() -> void:
	if _shell != null:
		_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _accessible_name(
	entry: CaseArchiveViewModel.CaseEntryViewModel,
	state: StringName
) -> String:
	return "%s. %s. %s" % [entry.get_title(), _station_status_text(entry, state), entry.get_record_text()]
