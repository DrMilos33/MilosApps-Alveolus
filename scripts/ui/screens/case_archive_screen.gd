class_name CaseArchiveScreen
extends Control

signal case_selected(case_id: StringName)
signal replay_story
signal back

const CARD_MINIMUM_WIDTH := 260.0
const CARD_HEIGHT := 84.0
const CARD_HEIGHT_CURRENT := 100.0
const CARD_HEIGHT_COMPACT := 88.0
const STATION_WIDTH := 650.0
const STATION_WIDTH_CURRENT := 820.0
const STATION_WIDTH_LOCKED := 560.0
const STATION_MEDALLION_SIZE := 46.0
const CONNECTOR_HEIGHT := 10.0

var _applied_revision := -1
var _applied_content_hash := 0
var _view_model: CaseArchiveViewModel
var _shell: PanelContainer
var _safe_area: MarginContainer
var _shell_stack: VBoxContainer
var _header: PanelContainer
var _scroll: ScrollContainer
var _journey: VBoxContainer
var _header_actions: HBoxContainer
var _replay_button: Button
var _back_button: Button
var _cards: Dictionary = {}
var _station_rows: Dictionary = {}
var _connectors: Array[ColorRect] = []


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
	content.add_child(_scroll)

	_journey = VBoxContainer.new()
	_journey.name = "CaseJourney"
	_journey.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journey.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_journey.add_theme_constant_override("separation", 0)
	_journey.set_meta(&"alveolus_component", &"case_journey")
	_scroll.add_child(_journey)
	_scroll.resized.connect(_refresh_station_geometry)

	var shell_parts := AlveolusUIComponents.page_shell(header, content)
	_shell = shell_parts["shell"] as PanelContainer
	_safe_area = shell_parts["safe_area"] as MarginContainer
	_shell_stack = shell_parts["stack"] as VBoxContainer
	_shell.name = "PageShell"
	add_child(_shell)
	resized.connect(_refresh_responsive_layout)
	_refresh_responsive_layout.call_deferred()


func _rebuild_cards() -> void:
	for child in _journey.get_children():
		_journey.remove_child(child)
		child.queue_free()
	_cards.clear()
	_station_rows.clear()
	_connectors.clear()
	if _view_model == null:
		return
	var selected_id := _view_model.get_selected_case_id()
	var next_id := _view_model.get_next_case_id()
	var entries := _view_model.get_entries()
	entries.sort_custom(func(a: CaseArchiveViewModel.CaseEntryViewModel, b: CaseArchiveViewModel.CaseEntryViewModel) -> bool: return a.get_order() < b.get_order())
	for index in range(entries.size()):
		var entry := entries[index] as CaseArchiveViewModel.CaseEntryViewModel
		if entry == null:
			continue
		var state := _journey_state(entry, next_id)
		var row := _build_station_row(entry.get_id())
		var card := _build_case_card(entry, state, entry.get_id() == selected_id)
		row.add_child(card)
		var right_spacer := Control.new()
		right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(right_spacer)
		_journey.add_child(row)
		_cards[entry.get_id()] = card
		_station_rows[entry.get_id()] = row
		if index < entries.size() - 1:
			var connector := _build_connector(entry.is_completed())
			_journey.add_child(connector.get_parent())
			_connectors.append(connector)
	_configure_focus_path()
	_refresh_responsive_layout.call_deferred()
	_scroll_to_primary_station.call_deferred()


func _build_station_row(case_id: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "StationRow_%s" % String(case_id)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left_spacer := Control.new()
	left_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_spacer)
	return row


func _build_connector(progressed: bool) -> ColorRect:
	var center := CenterContainer.new()
	center.name = "JourneyConnectorHost"
	center.custom_minimum_size.y = CONNECTOR_HEIGHT
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var connector := ColorRect.new()
	connector.name = "JourneyConnector"
	connector.custom_minimum_size = Vector2(3.0, CONNECTOR_HEIGHT)
	connector.color = Color(AlveolusVisualTheme.TEAL, 0.72) if progressed else Color(AlveolusVisualTheme.MUTED, 0.30)
	connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	connector.set_meta(&"journey_progressed", progressed)
	center.add_child(connector)
	return connector


func _build_case_card(
	entry: CaseArchiveViewModel.CaseEntryViewModel,
	state: StringName,
	selected: bool
) -> Button:
	var visually_primary := state == &"current"
	var card := AlveolusUIComponents.choice_row("", "", "", visually_primary, not entry.is_unlocked())
	card.name = "Case_%s" % String(entry.get_id())
	card.custom_minimum_size = Vector2(CARD_MINIMUM_WIDTH, CARD_HEIGHT_CURRENT if visually_primary else CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.set_meta(&"case_id", entry.get_id())
	card.set_meta(&"journey_state", state)
	card.set_meta(&"journey_selected", selected)
	card.set_meta(&"alveolus_accessible_name", _accessible_name(entry, state, selected))
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
	station_icon.custom_minimum_size = Vector2.ONE * 28.0
	station_icon.configure(_station_icon_kind(entry, state), _station_accent(entry, state))
	medallion_center.add_child(station_icon)
	row.add_child(medallion)

	var copy := VBoxContainer.new()
	copy.name = "CaseCopy"
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	row.add_child(copy)

	var status := AlveolusUIComponents.label(_station_status_text(entry, state), AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	status.name = "Status"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_color_override("font_color", _station_accent(entry, state).lightened(0.16))
	copy.add_child(status)

	var title := AlveolusUIComponents.label(entry.get_title(), AlveolusVisualTheme.TYPE_SECTION_LABEL)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	summary.max_lines_visible = 1
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(summary)

	var state_icon := SimpleIcon.new()
	state_icon.name = "CaseStateIcon"
	state_icon.custom_minimum_size = Vector2.ONE * (26.0 if state == &"current" else 22.0)
	state_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	state_icon.configure(_station_icon_kind(entry, state), _station_accent(entry, state))
	row.add_child(state_icon)
	if state == &"locked":
		row.modulate = Color(0.82, 0.86, 0.87, 0.82)

	var card_margin := AlveolusUIComponents.margin(row, 12)
	card_margin.name = "CaseCardMargin"
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		card_margin.add_theme_constant_override(side, 10)
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


func _refresh_station_geometry() -> void:
	if _scroll == null or _journey == null or _cards.is_empty():
		return
	var logical_width := _layout_authority_width()
	var compact := logical_width < 620.0
	var screen_margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if compact else AlveolusVisualTheme.SCREEN_MARGIN
	# The compact scrollbar reserves twenty logical pixels in this theme. Keep it
	# outside the station width so the PageShell never grows past its host.
	var available_width := maxf(logical_width - float(screen_margin * 2) - 20.0, CARD_MINIMUM_WIDTH)
	for card_value in _cards.values():
		var card := card_value as Button
		if card == null:
			continue
		var state := StringName(card.get_meta(&"journey_state", &"available"))
		var target_width := STATION_WIDTH_CURRENT if state == &"current" else (STATION_WIDTH_LOCKED if state == &"locked" else STATION_WIDTH)
		card.custom_minimum_size.x = available_width if compact else minf(available_width, target_width)
		card.custom_minimum_size.y = (CARD_HEIGHT_CURRENT if state == &"current" else CARD_HEIGHT_COMPACT) if compact else (CARD_HEIGHT_CURRENT if state == &"current" else CARD_HEIGHT)


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
	_refresh_station_geometry.call_deferred()


func _layout_authority_width() -> float:
	var logical_width := size.x
	var host := get_parent() as Control
	if host != null and host.size.x > 0.0:
		logical_width = minf(logical_width, host.size.x) if logical_width > 0.0 else host.size.x
	return logical_width


func _configure_focus_path() -> void:
	var focusable: Array[Button] = []
	if _view_model == null:
		return
	for entry in _view_model.get_entries():
		var card := card_for_case(entry.get_id())
		if card != null and not card.disabled:
			focusable.append(card)
	for index in range(focusable.size()):
		var card := focusable[index]
		if index > 0:
			card.focus_neighbor_top = card.get_path_to(focusable[index - 1])
		if index + 1 < focusable.size():
			card.focus_neighbor_bottom = card.get_path_to(focusable[index + 1])


func _scroll_to_primary_station() -> void:
	var primary := get_default_focus_control()
	if primary != null and _scroll != null:
		_scroll.ensure_control_visible(primary)


func _fit_shell_to_host() -> void:
	if _shell != null:
		_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _accessible_name(
	entry: CaseArchiveViewModel.CaseEntryViewModel,
	state: StringName,
	selected: bool
) -> String:
	var state_text := _station_status_text(entry, state)
	if selected:
		state_text += ". Ausgewählt"
	return "%s. %s. %s" % [entry.get_title(), state_text, entry.get_record_text()]
