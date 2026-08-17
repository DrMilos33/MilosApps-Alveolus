class_name CaseArchiveScreen
extends Control

signal case_selected(case_id: StringName)
signal replay_story
signal back

const CARD_MINIMUM_WIDTH := 260.0
const CARD_HEIGHT := 196.0

var _applied_revision := -1
var _applied_content_hash := 0
var _view_model: CaseArchiveViewModel
var _shell: PanelContainer
var _safe_area: MarginContainer
var _shell_stack: VBoxContainer
var _header: PanelContainer
var _scroll: ScrollContainer
var _card_flow: HFlowContainer
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
	var guidance := AlveolusUIComponents.label(
		"Wähle einen dokumentierten Fall. Ein Sieg schaltet den nächsten frei.",
		AlveolusVisualTheme.TYPE_MUTED_LABEL
	)
	guidance.name = "Guidance"
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(guidance)

	_scroll = ScrollContainer.new()
	_scroll.name = "CaseScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	content.add_child(_scroll)

	_card_flow = HFlowContainer.new()
	_card_flow.name = "CaseFlow"
	_card_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_flow.alignment = FlowContainer.ALIGNMENT_BEGIN
	_card_flow.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTENT_GAP)
	_card_flow.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTENT_GAP)
	_scroll.add_child(_card_flow)
	_scroll.resized.connect(_refresh_card_widths)

	var shell_parts := AlveolusUIComponents.page_shell(header, content)
	_shell = shell_parts["shell"] as PanelContainer
	_safe_area = shell_parts["safe_area"] as MarginContainer
	_shell_stack = shell_parts["stack"] as VBoxContainer
	_shell.name = "PageShell"
	add_child(_shell)
	resized.connect(_refresh_responsive_layout)
	_refresh_responsive_layout.call_deferred()


func _rebuild_cards() -> void:
	for child in _card_flow.get_children():
		_card_flow.remove_child(child)
		child.queue_free()
	_cards.clear()
	if _view_model == null:
		return
	var selected_id := _view_model.get_selected_case_id()
	for entry in _view_model.get_entries():
		if entry == null:
			continue
		var card := _build_case_card(entry, entry.get_id() == selected_id)
		_card_flow.add_child(card)
		_cards[entry.get_id()] = card
	_refresh_responsive_layout.call_deferred()


func _build_case_card(entry: CaseArchiveViewModel.CaseEntryViewModel, selected: bool) -> Button:
	var card := AlveolusUIComponents.selection_card("", "", "", selected, not entry.is_unlocked())
	card.name = "Case_%s" % String(entry.get_id())
	card.custom_minimum_size = Vector2(CARD_MINIMUM_WIDTH, CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.set_meta(&"case_id", entry.get_id())
	card.set_meta(&"alveolus_accessible_name", _accessible_name(entry, selected))
	card.pressed.connect(_emit_case_selected.bind(entry.get_id()))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)

	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	row.add_child(copy)

	var status_text := entry.get_status_text()
	if selected:
		status_text += " · Markiert"
	var status := AlveolusUIComponents.label(status_text, AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	status.name = "Status"
	status.add_theme_color_override("font_color", entry.get_accent().lightened(0.16))
	copy.add_child(status)

	var title := AlveolusUIComponents.label(entry.get_title(), AlveolusVisualTheme.TYPE_SECTION_LABEL)
	title.name = "Title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)

	var facts := AlveolusUIComponents.label(entry.get_facts_text(), AlveolusVisualTheme.TYPE_MUTED_LABEL)
	facts.name = "Facts"
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts.max_lines_visible = 2
	copy.add_child(facts)

	var best := AlveolusUIComponents.label(entry.get_best_text(), AlveolusVisualTheme.TYPE_BODY_LABEL)
	best.name = "Best"
	best.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(best)

	var record := AlveolusUIComponents.label(entry.get_record_text(), AlveolusVisualTheme.TYPE_MUTED_LABEL)
	record.name = "Record"
	record.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(record)

	var illustration := LevelCaseIllustration.new()
	illustration.name = "CaseIllustration"
	illustration.custom_minimum_size = Vector2(72.0, 72.0)
	illustration.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	illustration.configure(entry.get_order(), entry.is_tutorial(), entry.get_accent())
	illustration.set_locked(not entry.is_unlocked())
	row.add_child(illustration)

	if not entry.is_unlocked():
		copy.modulate = Color(0.66, 0.72, 0.73, 0.58)
		illustration.modulate = Color(0.56, 0.64, 0.65, 0.52)

	var card_margin := AlveolusUIComponents.margin(row, 12)
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_margin)
	return card


func _emit_case_selected(case_id: StringName) -> void:
	case_selected.emit(case_id)


func _refresh_card_widths() -> void:
	if _scroll == null or _card_flow == null or _cards.is_empty():
		return
	# Never derive a child's minimum width from the ScrollContainer's previous
	# layout width. Doing so creates a feedback loop: a wide construction-time
	# viewport becomes the card minimum and then forces the compact PageShell
	# wider than its host. The screen rect is the stable layout authority.
	var compact := size.x < 620.0
	var screen_margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if compact else AlveolusVisualTheme.SCREEN_MARGIN
	# Reserve the compact vertical scrollbar as well as a small breathing inset;
	# otherwise the single-column flow still widens the shell by the bar width.
	var available_width := maxf(size.x - float(screen_margin * 2) - 16.0, CARD_MINIMUM_WIDTH)
	var gap := float(AlveolusVisualTheme.CONTENT_GAP)
	var column_count := maxi(1, floori((available_width + gap) / (CARD_MINIMUM_WIDTH + gap)))
	column_count = mini(column_count, 4)
	var card_width := floorf((available_width - gap * float(column_count - 1)) / float(column_count))
	for card_value in _cards.values():
		var card := card_value as Button
		if card != null:
			card.custom_minimum_size.x = maxf(card_width, CARD_MINIMUM_WIDTH)


func _refresh_responsive_layout() -> void:
	# The screen is built before it is mounted under the scaled HUD root. Refit
	# the shell after this layout pass, when the final host rect is available.
	# Doing this deferred preserves the full-rect anchors without creating a
	# resize feedback loop through the PanelContainer's children.
	_fit_shell_to_host.call_deferred()
	var compact := size.x < 620.0
	var screen_margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if compact else AlveolusVisualTheme.SCREEN_MARGIN
	if _safe_area != null:
		for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
			_safe_area.add_theme_constant_override(side, screen_margin)
	if _shell_stack != null:
		_shell_stack.add_theme_constant_override(
			"separation",
			AlveolusVisualTheme.HEADER_CONTENT_GAP_COMPACT if compact else AlveolusVisualTheme.HEADER_CONTENT_GAP
		)
	if _header != null:
		_header.custom_minimum_size.y = AlveolusVisualTheme.HEADER_HEIGHT_COMPACT if compact else AlveolusVisualTheme.HEADER_HEIGHT
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
	for card_value in _cards.values():
		var card := card_value as Button
		if card == null:
			continue
		card.custom_minimum_size.y = 160.0 if compact else CARD_HEIGHT
		var illustration := card.find_child("CaseIllustration", true, false) as Control
		if illustration != null:
			illustration.custom_minimum_size = Vector2.ONE * (56.0 if compact else 72.0)
		var card_margin := card.get_child(0) as MarginContainer
		if card_margin != null:
			var inset := 8 if compact else 12
			for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
				card_margin.add_theme_constant_override(side, inset)
	_refresh_card_widths.call_deferred()


func _fit_shell_to_host() -> void:
	if _shell != null:
		_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _accessible_name(entry: CaseArchiveViewModel.CaseEntryViewModel, selected: bool) -> String:
	var state := "Ausgewählt" if selected else entry.get_status_text()
	return "%s. %s. %s. %s" % [entry.get_title(), state, entry.get_facts_text(), entry.get_record_text()]
