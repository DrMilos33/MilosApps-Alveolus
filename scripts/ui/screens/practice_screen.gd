class_name PracticeScreen
extends Control

## Bio-Lumen Practice screen.
##
## The screen consumes immutable PracticeScreenViewModel values and emits only
## local test selection intent. Visibility policy and run construction remain
## outside this module so release/debug decisions never depend on OS state here.

signal scenario_selected(id: StringName)
signal boss_profile_selected(id: StringName)
signal back_requested

const PracticeScreenViewModelType := preload("res://scripts/ui/view_models/practice_screen_view_model.gd")
const ROUTE_ID := &"practice"
const FOUR_COLUMN_MINIMUM := 1120.0
const TWO_COLUMN_MINIMUM := 620.0
const SUBSELECTION_TWO_COLUMN_MINIMUM := 760.0

enum Subselection {
	NONE,
	EVENT,
	BOSS,
}

var _page_shell: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _tests_content: VBoxContainer
var _availability_notice: PanelContainer

var _scenario_card: PanelContainer
var _scenario_grid: GridContainer
var _event_card: PanelContainer
var _event_grid: GridContainer
var _boss_card: PanelContainer
var _boss_grid: GridContainer

var _back_button: Button
var _scenario_buttons: Dictionary = {}
var _event_scenario_buttons: Dictionary = {}
var _boss_profile_buttons: Dictionary = {}

var _has_applied_model := false
var _applied_revision := -1
var _applied_content_hash := 0
var _applied_scenario_offers_hash := 0
var _applied_boss_profile_offers_hash := 0
var _selected_scenario_id: StringName = &""
var _selected_boss_profile_id: StringName = &""
var _active_subselection := Subselection.NONE


func _init() -> void:
	name = "PracticeScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	set_process(false)
	set_physics_process(false)
	set_process_shortcut_input(true)
	_build()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()


func route_id() -> StringName:
	return ROUTE_ID


## Returns true only when visible content changed. A newer revision with the
## same content hash is acknowledged without rebuilding controls.
func apply_view_model(view_model: PracticeScreenViewModelType) -> bool:
	if view_model == null:
		return false
	var next_revision := view_model.revision()
	if _has_applied_model and next_revision <= _applied_revision:
		return false
	if _has_applied_model and view_model.content_hash() == _applied_content_hash:
		_applied_revision = next_revision
		return false

	if not _has_applied_model or view_model.scenario_offers_hash() != _applied_scenario_offers_hash:
		_rebuild_scenario_offers(
			view_model.primary_scenario_offers(),
			view_model.event_scenario_offers()
		)
	if not _has_applied_model or view_model.boss_profile_offers_hash() != _applied_boss_profile_offers_hash:
		_rebuild_boss_profile_offers(view_model.boss_profile_offers())

	var previous_scenario_id := _selected_scenario_id
	_selected_scenario_id = view_model.selected_scenario_id()
	_selected_boss_profile_id = view_model.selected_boss_profile_id()
	var tests_are_visible := view_model.tests_visible()
	_tests_content.visible = tests_are_visible
	_availability_notice.visible = not tests_are_visible
	var selection_changed := not _has_applied_model or previous_scenario_id != _selected_scenario_id
	if not tests_are_visible:
		_set_active_subselection(Subselection.NONE)
	elif selection_changed and view_model.selected_scenario_requires_boss_profile():
		_set_active_subselection(Subselection.BOSS, _has_applied_model)
	elif selection_changed and view_model.selected_scenario_is_event_test():
		_set_active_subselection(Subselection.EVENT, _has_applied_model)
	elif selection_changed:
		_set_active_subselection(Subselection.NONE)
	else:
		_refresh_subselection_visibility()
	_update_selected_states()

	_has_applied_model = true
	_applied_revision = next_revision
	_applied_content_hash = view_model.content_hash()
	_applied_scenario_offers_hash = view_model.scenario_offers_hash()
	_applied_boss_profile_offers_hash = view_model.boss_profile_offers_hash()
	return true


func applied_revision() -> int:
	return _applied_revision


func applied_content_hash() -> int:
	return _applied_content_hash


func tests_visible() -> bool:
	return _tests_content.visible


func boss_profile_selection_visible() -> bool:
	return _boss_card.visible


func event_scenario_selection_visible() -> bool:
	return _event_card.visible


func layout_columns() -> int:
	return _scenario_grid.columns


func event_layout_columns() -> int:
	return _event_grid.columns


func boss_layout_columns() -> int:
	return _boss_grid.columns


func default_focus_control() -> Control:
	if _tests_content.visible:
		var subselection_focus := _first_enabled_button(_visible_subselection_grid())
		if subselection_focus != null:
			return subselection_focus
		for child in _scenario_grid.get_children():
			if child is Button and not (child as Button).disabled:
				return child as Button
	return _back_button


func back_action() -> Button:
	return _back_button


func scenario_action(id: StringName) -> Button:
	var result := _scenario_buttons.get(id) as Button
	if result != null:
		return result
	return _event_scenario_buttons.get(id) as Button


func event_scenario_action(id: StringName) -> Button:
	return _event_scenario_buttons.get(id) as Button


func boss_profile_action(id: StringName) -> Button:
	return _boss_profile_buttons.get(id) as Button


## Consumes Back only while a nested Event- or Bossauswahl is visible.
## The integration layer remains responsible for leaving the Practice screen.
func handle_ui_cancel() -> bool:
	if not is_inside_tree() or not is_visible_in_tree() or _active_subselection == Subselection.NONE:
		return false
	var focus_target := _scenario_buttons.get(
		PracticeScreenViewModelType.EVENT_TEST_GROUP_ID
		if _active_subselection == Subselection.EVENT
		else _selected_scenario_id
	) as Button
	_set_active_subselection(Subselection.NONE)
	if focus_target != null and focus_target.is_visible_in_tree() and not focus_target.disabled:
		focus_target.grab_focus.call_deferred()
	return true


func _shortcut_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and handle_ui_cancel():
		get_viewport().set_input_as_handled()


func _build() -> void:
	_back_button = AlveolusUIComponents.action_button(
		"Zum Campus",
		AlveolusUIComponents.ACTION_NAVIGATION,
		&"back",
		AlveolusVisualTheme.TEAL
	)
	_back_button.name = "BackAction"
	_back_button.pressed.connect(_on_back_pressed)
	var header_parts := AlveolusUIComponents.page_header("Praxis", "", _back_button)

	_scroll = ScrollContainer.new()
	_scroll.name = "PracticeScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_body = VBoxContainer.new()
	_body.name = "PracticeContent"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_body.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	_scroll.add_child(_body)
	_build_availability_notice()
	_build_test_content()

	var shell_parts := AlveolusUIComponents.page_shell(
		header_parts["panel"] as Control,
		_scroll,
		false
	)
	_page_shell = shell_parts["shell"] as PanelContainer
	_page_shell.name = "PracticePageShell"
	add_child(_page_shell)


func _build_availability_notice() -> void:
	_availability_notice = AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_ACTION_CARD)
	_availability_notice.name = "PracticeAvailabilityNotice"
	_availability_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	content.add_child(AlveolusUIComponents.section_header(
		"LOKALE TESTLÄUFE",
		"In diesem Build nicht verfügbar",
		"Die Sichtbarkeit wird von der Einsatzplanung vorgegeben."
	))
	_availability_notice.add_child(AlveolusUIComponents.margin(content, AlveolusVisualTheme.CARD_PADDING))
	_body.add_child(_availability_notice)


func _on_back_pressed() -> void:
	if not handle_ui_cancel():
		back_requested.emit()


func _build_test_content() -> void:
	_tests_content = VBoxContainer.new()
	_tests_content.name = "PracticeTests"
	_tests_content.visible = false
	_tests_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tests_content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	_body.add_child(_tests_content)
	_build_scenario_card()
	_build_event_card()
	_build_boss_card()


func _build_scenario_card() -> void:
	_scenario_card = AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_ACTION_CARD)
	_scenario_card.name = "ScenarioSelectionCard"
	_scenario_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	content.add_child(AlveolusUIComponents.section_header(
		"LOKALE TESTLÄUFE",
		"Testumgebung wählen",
		"Diese Läufe erzeugen keinen Fortschritt und verändern keinen Spielstand."
	))
	_scenario_grid = GridContainer.new()
	_scenario_grid.name = "ScenarioOffers"
	_scenario_grid.columns = 3
	_scenario_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scenario_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTENT_GAP)
	_scenario_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTENT_GAP)
	content.add_child(_scenario_grid)
	_scenario_card.add_child(AlveolusUIComponents.margin(content, AlveolusVisualTheme.CARD_PADDING))
	_tests_content.add_child(_scenario_card)


func _build_event_card() -> void:
	_event_card = AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_ACTION_CARD)
	_event_card.name = "EventScenarioSelectionCard"
	_event_card.visible = false
	_event_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	content.add_child(AlveolusUIComponents.section_header(
		"EVENT-TEST",
		"Fallprofil wählen",
		"Jeder Test übernimmt das aktuelle Eventmonster des ausgewählten Falls."
	))
	_event_grid = GridContainer.new()
	_event_grid.name = "EventScenarioOffers"
	_event_grid.columns = 2
	_event_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTENT_GAP)
	_event_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	content.add_child(_event_grid)
	_event_card.add_child(AlveolusUIComponents.margin(content, AlveolusVisualTheme.CARD_PADDING))
	_tests_content.add_child(_event_card)


func _build_boss_card() -> void:
	_boss_card = AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_ACTION_CARD)
	_boss_card.name = "BossProfileSelectionCard"
	_boss_card.visible = false
	_boss_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	content.add_child(AlveolusUIComponents.section_header(
		"BOSS-TEST",
		"Bossprofil wählen",
		"Jedes Profil übernimmt Leben, Tempo, Angriff und Phasen vollständig."
	))
	_boss_grid = GridContainer.new()
	_boss_grid.name = "BossProfileOffers"
	_boss_grid.columns = 2
	_boss_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTENT_GAP)
	_boss_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	content.add_child(_boss_grid)
	_boss_card.add_child(AlveolusUIComponents.margin(content, AlveolusVisualTheme.CARD_PADDING))
	_tests_content.add_child(_boss_card)


func _rebuild_scenario_offers(primary_offers: Array, event_offers: Array) -> void:
	_clear_offer_controls(_scenario_grid, _scenario_buttons)
	_clear_offer_controls(_event_grid, _event_scenario_buttons)
	for offer in primary_offers:
		var button := AlveolusUIComponents.choice_card(
			offer.title(),
			offer.description(),
			offer.facts_text(),
			false,
			not offer.enabled()
		)
		button.name = "Scenario_%s" % String(offer.id())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta(&"practice_scenario_id", offer.id())
		button.set_meta(&"requires_boss_profile", offer.requires_boss_profile())
		button.pressed.connect(_on_primary_scenario_pressed.bind(offer.id(), offer.requires_boss_profile()))
		AlveolusUIComponents.set_button_disabled(button, not offer.enabled())
		_scenario_grid.add_child(button)
		_scenario_buttons[offer.id()] = button
	if not event_offers.is_empty():
		var event_group_id: StringName = PracticeScreenViewModelType.EVENT_TEST_GROUP_ID
		var event_group_enabled := false
		for offer in event_offers:
			if offer.enabled():
				event_group_enabled = true
				break
		var event_button := AlveolusUIComponents.choice_card(
			"Event-Test",
			"Ein aktuelles Eventmonster ohne Begleitwellen",
			"%d Fallprofile wählen" % event_offers.size(),
			false,
			not event_group_enabled
		)
		event_button.name = "Scenario_%s" % String(event_group_id)
		event_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		event_button.set_meta(&"practice_scenario_group_id", event_group_id)
		event_button.pressed.connect(_open_event_selection)
		AlveolusUIComponents.set_button_disabled(event_button, not event_group_enabled)
		_scenario_grid.add_child(event_button)
		_scenario_buttons[event_group_id] = event_button
	for offer in event_offers:
		var event_option := AlveolusUIComponents.choice_row(
			offer.title(),
			offer.description(),
			offer.facts_text(),
			false,
			not offer.enabled()
		)
		event_option.name = "EventScenario_%s" % String(offer.id())
		event_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		event_option.set_meta(&"practice_scenario_id", offer.id())
		event_option.pressed.connect(_emit_scenario_selected.bind(offer.id()))
		AlveolusUIComponents.set_button_disabled(event_option, not offer.enabled())
		_event_grid.add_child(event_option)
		_event_scenario_buttons[offer.id()] = event_option


func _rebuild_boss_profile_offers(offers: Array) -> void:
	_clear_offer_controls(_boss_grid, _boss_profile_buttons)
	for offer in offers:
		var button := AlveolusUIComponents.choice_row(
			offer.title(),
			offer.description(),
			offer.facts_text(),
			false,
			not offer.enabled()
		)
		button.name = "BossProfile_%s" % String(offer.id())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta(&"practice_boss_profile_id", offer.id())
		button.pressed.connect(_emit_boss_profile_selected.bind(offer.id()))
		AlveolusUIComponents.set_button_disabled(button, not offer.enabled())
		_boss_grid.add_child(button)
		_boss_profile_buttons[offer.id()] = button


func _clear_offer_controls(container: Container, controls: Dictionary) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()
	controls.clear()


func _update_selected_states() -> void:
	for id_value in _scenario_buttons:
		var scenario_id := StringName(id_value)
		var button := _scenario_buttons[scenario_id] as Button
		var is_selected := _primary_scenario_is_selected(scenario_id)
		button.theme_type_variation = (
			AlveolusVisualTheme.TYPE_SELECTED_CARD
			if is_selected
			else AlveolusVisualTheme.TYPE_SELECTION_CARD
		)
		button.set_pressed_no_signal(is_selected)
	for id_value in _event_scenario_buttons:
		var event_id := StringName(id_value)
		var event_button := _event_scenario_buttons[event_id] as Button
		event_button.theme_type_variation = (
			AlveolusVisualTheme.TYPE_SELECTED_CHOICE_ROW
			if event_id == _selected_scenario_id
			else AlveolusVisualTheme.TYPE_CHOICE_ROW
		)
		event_button.set_pressed_no_signal(event_id == _selected_scenario_id)
	for id_value in _boss_profile_buttons:
		var profile_id := StringName(id_value)
		var button := _boss_profile_buttons[profile_id] as Button
		button.theme_type_variation = (
			AlveolusVisualTheme.TYPE_SELECTED_CHOICE_ROW
			if profile_id == _selected_boss_profile_id
			else AlveolusVisualTheme.TYPE_CHOICE_ROW
		)
		button.set_pressed_no_signal(profile_id == _selected_boss_profile_id)


func _primary_scenario_is_selected(scenario_id: StringName) -> bool:
	var is_event_group := scenario_id == PracticeScreenViewModelType.EVENT_TEST_GROUP_ID
	if _active_subselection == Subselection.EVENT:
		return is_event_group
	if _active_subselection == Subselection.BOSS:
		return scenario_id == _selected_scenario_id
	if is_event_group:
		return PracticeScreenViewModelType.is_event_test_scenario_id(_selected_scenario_id)
	return scenario_id == _selected_scenario_id


func _emit_scenario_selected(id: StringName) -> void:
	scenario_selected.emit(id)


func _on_primary_scenario_pressed(id: StringName, requires_boss_profile: bool) -> void:
	if requires_boss_profile and id == _selected_scenario_id and _active_subselection != Subselection.BOSS:
		_set_active_subselection(Subselection.BOSS, true)
		return
	scenario_selected.emit(id)


func _open_event_selection() -> void:
	_set_active_subselection(Subselection.EVENT, true)


func _emit_boss_profile_selected(id: StringName) -> void:
	boss_profile_selected.emit(id)


func _set_active_subselection(next: int, request_focus: bool = false) -> void:
	_active_subselection = next
	_refresh_subselection_visibility()
	_update_selected_states()
	if request_focus:
		_focus_active_subselection.call_deferred()


func _refresh_subselection_visibility() -> void:
	if _active_subselection == Subselection.EVENT and _event_scenario_buttons.is_empty():
		_active_subselection = Subselection.NONE
	_event_card.visible = _tests_content.visible and _active_subselection == Subselection.EVENT and not _event_scenario_buttons.is_empty()
	_boss_card.visible = _tests_content.visible and _active_subselection == Subselection.BOSS


func _focus_active_subselection() -> void:
	var target := _first_enabled_button(_visible_subselection_grid())
	if target != null and target.is_visible_in_tree():
		target.grab_focus()
		_scroll.ensure_control_visible(target)


func _visible_subselection_grid() -> GridContainer:
	if _event_card.visible:
		return _event_grid
	if _boss_card.visible:
		return _boss_grid
	return null


func _first_enabled_button(container: Container) -> Button:
	if container == null:
		return null
	for child in container.get_children():
		if child is Button and not (child as Button).disabled:
			return child as Button
	return null


func _update_responsive_layout() -> void:
	if _scenario_grid == null:
		return
	var logical_width := size.x
	if logical_width <= 0.0 and get_viewport() != null:
		logical_width = get_viewport_rect().size.x
	AlveolusUIComponents.refresh_page_shell_layout(_page_shell, logical_width < TWO_COLUMN_MINIMUM)
	if logical_width >= FOUR_COLUMN_MINIMUM:
		_scenario_grid.columns = 4
	elif logical_width >= TWO_COLUMN_MINIMUM:
		_scenario_grid.columns = 2
	else:
		_scenario_grid.columns = 1
	var subselection_columns := 2 if logical_width >= SUBSELECTION_TWO_COLUMN_MINIMUM else 1
	_event_grid.columns = subselection_columns
	_boss_grid.columns = subselection_columns
