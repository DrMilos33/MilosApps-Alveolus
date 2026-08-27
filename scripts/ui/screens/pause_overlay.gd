class_name PauseOverlay
extends Control

## Bio-Lumen pause overlay with an embedded character-values mode.
##
## The overlay renders immutable PauseOverlayViewModel data and emits intents.
## Routing, simulation pause and confirmation dialogs remain responsibilities
## of GameHUD/Game. Only the body viewport may scroll; title and the active
## return/continue action remain fixed and visible.

signal resume_requested
signal settings_requested
signal stats_requested
signal test_values_requested
signal test_damage_immunity_changed(enabled: bool)
signal test_outgoing_damage_bonus_percent_changed(percent: int)
signal test_movement_speed_percent_changed(percent: int)
signal test_values_reset_requested
signal abort_requested
signal intro_skip_requested
signal back_requested

enum Mode {
	MENU,
	STATS,
	TEST,
}

const MENU_MAXIMUM_WIDTH := 620.0
const STATS_MAXIMUM_WIDTH := 900.0
const COMPACT_MENU_BREAKPOINT := 560.0
# Two compact value columns remain readable down to the 480 x 270 logical
# viewport used by 960 x 540 at 200 percent. Only genuinely narrow layouts
# collapse to one column.
const COMPACT_STATS_BREAKPOINT := 400.0
const BUILD_GRID_BREAKPOINT := 700.0
const MODAL_PADDING := 20
const COMPACT_MODAL_PADDING := 16
const STAT_LABEL_MINIMUM_WIDTH := 64.0
# At the two-column 480-px layout the caption and measured value share a
# stable text budget. Short values therefore leave more room for their label,
# while long values keep their full 56–120-px value column and trim only the
# caption (the row tooltip remains unabridged).
const COMPACT_STAT_TEXT_MINIMUM_WIDTH := 136.0
const COMPACT_STAT_LABEL_FLOOR := 16.0
const SECTION_CHEVRON_SIZE := 20.0

var _view_model: PauseOverlayViewModel
var _mode := Mode.MENU
var _applied_revision := -1
var _applied_content_hash := ""

var _backdrop: ColorRect
var _safe_area: MarginContainer
var _center: CenterContainer
var _sheet: PanelContainer
var _sheet_margin: MarginContainer
var _sheet_stack: VBoxContainer
var _pause_header: VBoxContainer
var _doctor_balance: Control
var _title_label: Label
var _doctor_label: Label
var _body_scroll: ScrollContainer
var _scrollbar_inset: MarginContainer
var _body_stack: VBoxContainer
var _menu_body: VBoxContainer
var _menu_actions: GridContainer
var _menu_danger_row: HBoxContainer
var _stats_body: VBoxContainer
var _stats_core_host: VBoxContainer
var _stats_grid: GridContainer
var _empty_stats_label: Label
var _test_body: VBoxContainer
var _footer_actions: HBoxContainer

var _resume_button: Button
var _settings_button: Button
var _stats_button: Button
var _test_values_button: Button
var _abort_button: Button
var _intro_skip_button: Button
var _back_button: Button
var _test_damage_immunity_toggle: CheckButton
var _test_outgoing_damage_slider: HSlider
var _test_outgoing_damage_value: Label
var _test_movement_speed_slider: HSlider
var _test_movement_speed_value: Label
var _test_reset_button: Button
var _stat_sections: Array[PanelContainer] = []
var _stat_rows: Array[PanelContainer] = []
var _section_controls: Dictionary = {}
var _section_headers: Dictionary = {}
var _section_bodies: Dictionary = {}
var _expanded_sections: Dictionary = {}


func _init() -> void:
	name = "PauseOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	set_process(false)
	set_physics_process(false)
	_build()
	resized.connect(_queue_responsive_layout)


func apply_view_model(view_model: PauseOverlayViewModel, mode: int = Mode.MENU) -> bool:
	if view_model == null or mode < Mode.MENU or mode > Mode.TEST:
		return false
	if mode == Mode.TEST and not view_model.has_test_settings():
		return false
	if _applied_revision >= 0 and view_model.revision() < _applied_revision:
		return false

	var content_changed := view_model.content_hash() != _applied_content_hash
	var mode_changed := mode != _mode
	var revision_changed := view_model.revision() != _applied_revision
	if not content_changed and not mode_changed and not revision_changed:
		return false

	_view_model = view_model
	_applied_revision = view_model.revision()
	_applied_content_hash = view_model.content_hash()
	if view_model.has_test_settings():
		_build_test_body()
	if content_changed:
		_sync_stat_sections()
		_sync_test_settings()
	AlveolusUIComponents.set_button_disabled(_stats_button, not view_model.has_stats())
	_test_values_button.visible = view_model.has_test_settings()
	AlveolusUIComponents.set_button_disabled(_test_values_button, not view_model.has_test_settings())
	_intro_skip_button.visible = view_model.show_intro_skip()
	_apply_mode(mode)
	# A newer presenter revision with identical visible data is acknowledged but
	# intentionally causes no layout churn.
	return content_changed or mode_changed


func present(view_model: PauseOverlayViewModel, mode: int = Mode.MENU, request_focus: bool = true) -> bool:
	var changed := apply_view_model(view_model, mode)
	show()
	if request_focus:
		grab_initial_focus.call_deferred()
	return changed


func dismiss() -> void:
	hide()


func set_mode(mode: int, request_focus: bool = true) -> bool:
	if mode < Mode.MENU or mode > Mode.TEST or mode == _mode:
		return false
	if mode == Mode.TEST and (_view_model == null or not _view_model.has_test_settings()):
		return false
	_apply_mode(mode)
	if request_focus:
		grab_initial_focus.call_deferred()
	return true


## UIScreenRouter/GameHUD can call this for ui_cancel without installing a
## second input listener. Exactly one back intent is emitted in either mode.
func handle_ui_cancel() -> bool:
	if not is_inside_tree() or not is_visible_in_tree():
		return false
	back_requested.emit()
	return true


func grab_initial_focus() -> bool:
	var target: Control = _resume_button
	if _mode == Mode.STATS:
		target = _back_button
	elif _mode == Mode.TEST:
		target = _test_damage_immunity_toggle
	if not is_inside_tree() or not is_visible_in_tree() or target == null or not target.is_visible_in_tree():
		return false
	target.grab_focus()
	_ensure_focus_visible.call_deferred(target)
	return true


func current_mode() -> int:
	return _mode


func applied_revision() -> int:
	return _applied_revision


func applied_content_hash() -> String:
	return _applied_content_hash


func title_text() -> String:
	return _title_label.text


func modal_sheet() -> PanelContainer:
	return _sheet


func body_scroll() -> ScrollContainer:
	return _body_scroll


func menu_action_grid() -> GridContainer:
	return _menu_actions


func stats_grid() -> GridContainer:
	return _stats_grid


func test_values_body() -> VBoxContainer:
	return _test_body


func stat_sections() -> Array[PanelContainer]:
	var result: Array[PanelContainer] = []
	result.assign(_stat_sections)
	return result


func stat_rows() -> Array[PanelContainer]:
	var result: Array[PanelContainer] = []
	result.assign(_stat_rows)
	return result


func section_header(section_id: StringName) -> Button:
	return _section_headers.get(section_id) as Button


func section_body(section_id: StringName) -> GridContainer:
	return _section_bodies.get(section_id) as GridContainer


func is_section_expanded(section_id: StringName) -> bool:
	return bool(_expanded_sections.get(section_id, false))


func set_section_expanded(section_id: StringName, expanded: bool) -> bool:
	if not _section_controls.has(section_id) or is_section_expanded(section_id) == expanded:
		return false
	_expanded_sections[section_id] = expanded
	_apply_section_expansion(section_id)
	_update_focus_trap()
	_queue_responsive_layout()
	return true


func resume_action() -> Button:
	return _resume_button


func settings_action() -> Button:
	return _settings_button


func stats_action() -> Button:
	return _stats_button


func test_values_action() -> Button:
	return _test_values_button


func test_control(setting_id: StringName) -> Control:
	match setting_id:
		&"damage_immunity":
			return _test_damage_immunity_toggle
		&"outgoing_damage_bonus_percent":
			return _test_outgoing_damage_slider
		&"movement_speed_percent":
			return _test_movement_speed_slider
		&"reset":
			return _test_reset_button
	return null


func abort_action() -> Button:
	return _abort_button


func intro_skip_action() -> Button:
	return _intro_skip_button


func back_action() -> Button:
	return _back_button


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "ModalBackdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(AlveolusVisualTheme.PETROL_DEEP, 0.82)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_meta(&"alveolus_component", &"modal_backdrop")
	add_child(_backdrop)

	_safe_area = MarginContainer.new()
	_safe_area.name = "SafeArea"
	_safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.add_child(_safe_area)

	_center = CenterContainer.new()
	_center.name = "PauseCenter"
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center.resized.connect(_queue_responsive_layout)
	_safe_area.add_child(_center)

	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "PauseBodyScroll"
	_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.follow_focus = true
	_body_scroll.resized.connect(_queue_responsive_layout)

	_scrollbar_inset = MarginContainer.new()
	_scrollbar_inset.name = "ScrollbarSafeInset"
	_scrollbar_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.add_child(_scrollbar_inset)

	_body_stack = VBoxContainer.new()
	_body_stack.name = "BodyStack"
	_body_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_stack.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	_scrollbar_inset.add_child(_body_stack)

	_build_menu_body()
	_build_stats_body()

	_resume_button = AlveolusUIComponents.action_button(
		"Weiter",
		AlveolusUIComponents.ACTION_PRIMARY,
		&"play"
	)
	_resume_button.name = "Resume"
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())

	_back_button = AlveolusUIComponents.action_button(
		"Zurück",
		AlveolusUIComponents.ACTION_SECONDARY,
		&"back",
		AlveolusVisualTheme.COBALT
	)
	_back_button.name = "Back"
	_back_button.pressed.connect(func() -> void: back_requested.emit())

	var footer_buttons: Array[Control] = [_resume_button, _back_button]
	var sheet_parts := AlveolusUIComponents.modal_sheet(
		"",
		_body_scroll,
		footer_buttons,
		MODAL_PADDING,
		AlveolusVisualTheme.COBALT
	)
	_sheet = sheet_parts["panel"] as PanelContainer
	_sheet.name = "PauseSheet"
	_sheet_stack = sheet_parts["content"] as VBoxContainer
	_sheet_margin = _sheet_stack.get_parent() as MarginContainer
	_footer_actions = sheet_parts["actions"] as HBoxContainer

	_pause_header = VBoxContainer.new()
	_pause_header.name = "PauseHeader"
	_pause_header.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	var title_line := HBoxContainer.new()
	title_line.name = "PauseTitleLine"
	title_line.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_doctor_balance = Control.new()
	_doctor_balance.name = "DoctorBalance"
	_doctor_balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_doctor_balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_line.add_child(_doctor_balance)
	_title_label = AlveolusUIComponents.label("Pause", AlveolusVisualTheme.TYPE_TITLE_LABEL)
	_title_label.name = "Title"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_line.add_child(_title_label)
	_doctor_label = AlveolusUIComponents.label("Doctor Milos", AlveolusVisualTheme.TYPE_MUTED_LABEL)
	_doctor_label.name = "DoctorMeta"
	_doctor_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_line.add_child(_doctor_label)
	_sync_doctor_balance.call_deferred()
	_pause_header.add_child(title_line)
	_sheet_stack.add_child(_pause_header)
	_sheet_stack.move_child(_pause_header, 0)
	_center.add_child(_sheet)

	var all_buttons: Array[Button] = [
		_resume_button,
		_settings_button,
		_stats_button,
		_test_values_button,
		_abort_button,
		_intro_skip_button,
		_back_button,
	]
	for button in all_buttons:
		button.focus_entered.connect(_ensure_focus_visible.bind(button))
	_apply_mode(Mode.MENU)


func _build_menu_body() -> void:
	_menu_body = VBoxContainer.new()
	_menu_body.name = "MenuBody"
	_menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_body.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_body_stack.add_child(_menu_body)

	_menu_actions = GridContainer.new()
	_menu_actions.name = "PauseActions"
	_menu_actions.columns = 3
	_menu_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_actions.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_menu_actions.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	_menu_body.add_child(_menu_actions)

	# At compact sizes the danger action moves into this dedicated full-width
	# row. This keeps the two routine actions side by side and all three menu
	# intents visible above the fixed Continue footer at 480 x 270 logical.
	_menu_danger_row = HBoxContainer.new()
	_menu_danger_row.name = "DangerRow"
	_menu_danger_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_danger_row.hide()
	_menu_body.add_child(_menu_danger_row)

	_settings_button = AlveolusUIComponents.action_button(
		"Einstellungen",
		AlveolusUIComponents.ACTION_SECONDARY,
		&"settings",
		AlveolusVisualTheme.COBALT
	)
	_settings_button.name = "Settings"
	_settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_button.pressed.connect(func() -> void: settings_requested.emit())
	_menu_actions.add_child(_settings_button)

	_stats_button = AlveolusUIComponents.action_button(
		"Charakterwerte",
		AlveolusUIComponents.ACTION_SECONDARY,
		&"information",
		AlveolusVisualTheme.TEAL
	)
	_stats_button.name = "Stats"
	_stats_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_button.pressed.connect(func() -> void: stats_requested.emit())
	_menu_actions.add_child(_stats_button)

	_test_values_button = AlveolusUIComponents.action_button(
		"Testwerte",
		AlveolusUIComponents.ACTION_SECONDARY,
		&"settings",
		AlveolusVisualTheme.GOLD
	)
	_test_values_button.name = "TestValues"
	_test_values_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_values_button.set_meta(&"test_only", true)
	_test_values_button.hide()
	_test_values_button.pressed.connect(func() -> void: test_values_requested.emit())
	_menu_actions.add_child(_test_values_button)

	_abort_button = AlveolusUIComponents.action_button(
		"Runde abbrechen",
		AlveolusUIComponents.ACTION_DANGER,
		&"exit",
		AlveolusVisualTheme.CORAL
	)
	_abort_button.name = "Abort"
	_abort_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_abort_button.pressed.connect(func() -> void: abort_requested.emit())
	_menu_actions.add_child(_abort_button)

	_intro_skip_button = AlveolusUIComponents.action_button(
		"Einführung überspringen",
		AlveolusUIComponents.ACTION_QUIET,
		&"story",
		AlveolusVisualTheme.GOLD
	)
	_intro_skip_button.name = "IntroSkip"
	_intro_skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intro_skip_button.hide()
	_intro_skip_button.pressed.connect(func() -> void: intro_skip_requested.emit())
	_menu_actions.add_child(_intro_skip_button)


func _build_stats_body() -> void:
	_stats_body = VBoxContainer.new()
	_stats_body.name = "StatsBody"
	_stats_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_body.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	_body_stack.add_child(_stats_body)

	_empty_stats_label = AlveolusUIComponents.label(
		"Noch keine Rundenwerte verfügbar.",
		AlveolusVisualTheme.TYPE_MUTED_LABEL
	)
	_empty_stats_label.name = "EmptyStats"
	_empty_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_body.add_child(_empty_stats_label)

	_stats_core_host = VBoxContainer.new()
	_stats_core_host.name = "PatientCore"
	_stats_core_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_core_host.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	_stats_body.add_child(_stats_core_host)

	_stats_grid = GridContainer.new()
	_stats_grid.name = "BuildSections"
	_stats_grid.columns = 2
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_stats_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTENT_GAP)
	_stats_body.add_child(_stats_grid)


func _build_test_body() -> void:
	if _test_body != null:
		return
	_test_body = VBoxContainer.new()
	_test_body.name = "TestValuesBody"
	_test_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_body.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	_test_body.set_meta(&"test_only", true)
	_body_stack.add_child(_test_body)

	var panel := AlveolusUIComponents.surface(
		AlveolusVisualTheme.SurfaceRole.ACTION_CARD,
		AlveolusVisualTheme.GOLD
	)
	panel.name = "TestValuesPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.name = "TestValuesControls"
	content.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	panel.add_child(AlveolusUIComponents.margin(content, AlveolusVisualTheme.CONTENT_GAP))
	_test_body.add_child(panel)

	_test_damage_immunity_toggle = AlveolusUIComponents.toggle_row("Aus", false)
	_test_damage_immunity_toggle.name = "TestDamageImmunity"
	_test_damage_immunity_toggle.theme_type_variation = &""
	_test_damage_immunity_toggle.flat = true
	_test_damage_immunity_toggle.set_meta(&"alveolus_component", &"transparent_toggle")
	_test_damage_immunity_toggle.set_meta(&"test_only", true)
	_test_damage_immunity_toggle.toggled.connect(_on_test_damage_immunity_changed)
	content.add_child(_test_setting_row("Schadensimmunität", _test_damage_immunity_toggle))

	var damage_parts := _test_slider_row(
		"Ausgehender Schaden",
		RunTestSettingsViewModel.OUTGOING_DAMAGE_BONUS_MIN,
		RunTestSettingsViewModel.OUTGOING_DAMAGE_BONUS_MAX,
		0,
		RunTestSettingsViewModel.OUTGOING_DAMAGE_BONUS_STEP,
		true
	)
	_test_outgoing_damage_slider = damage_parts["control"] as HSlider
	_test_outgoing_damage_slider.name = "TestOutgoingDamageBonus"
	_test_outgoing_damage_value = damage_parts["value_label"] as Label
	_test_outgoing_damage_value.name = "TestOutgoingDamageBonusValue"
	content.add_child(damage_parts["row"] as HBoxContainer)

	var movement_parts := _test_slider_row(
		"Galopp",
		RunTestSettingsViewModel.MOVEMENT_SPEED_MIN,
		RunTestSettingsViewModel.MOVEMENT_SPEED_MAX,
		100,
		RunTestSettingsViewModel.MOVEMENT_SPEED_STEP,
		false
	)
	_test_movement_speed_slider = movement_parts["control"] as HSlider
	_test_movement_speed_slider.name = "TestMovementSpeed"
	_test_movement_speed_value = movement_parts["value_label"] as Label
	_test_movement_speed_value.name = "TestMovementSpeedValue"
	content.add_child(movement_parts["row"] as HBoxContainer)

	_test_reset_button = AlveolusUIComponents.action_button(
		"Testwerte zurücksetzen",
		AlveolusUIComponents.ACTION_QUIET,
		&"restart",
		AlveolusVisualTheme.MUTED
	)
	_test_reset_button.name = "ResetTestValues"
	_test_reset_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_test_reset_button.set_meta(&"test_only", true)
	_test_reset_button.set_meta(&"alveolus_accessible_name", "Testwerte auf Standard zurücksetzen")
	_test_reset_button.pressed.connect(func() -> void: test_values_reset_requested.emit())
	content.add_child(_test_reset_button)
	for control in [
		_test_damage_immunity_toggle,
		_test_outgoing_damage_slider,
		_test_movement_speed_slider,
		_test_reset_button,
	]:
		control.focus_entered.connect(_ensure_focus_visible.bind(control))


func _test_setting_row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	row.set_meta(&"alveolus_component", &"compact_setting_row")
	var label := AlveolusUIComponents.label(label_text, AlveolusVisualTheme.TYPE_BODY_LABEL)
	label.name = "SettingPurpose"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	control.focus_mode = Control.FOCUS_ALL
	control.custom_minimum_size.y = maxf(
		control.custom_minimum_size.y,
		AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	)
	row.add_child(control)
	return row


func _test_slider_row(
	label_text: String,
	minimum: int,
	maximum: int,
	current_value: int,
	step_value: int,
	is_bonus: bool
) -> Dictionary:
	var parts := AlveolusUIComponents.slider_row(
		label_text,
		float(minimum),
		float(maximum),
		float(current_value),
		float(step_value)
	)
	var slider := parts["control"] as HSlider
	var value_label := parts["value_label"] as Label
	slider.set_meta(&"test_only", true)
	value_label.custom_minimum_size.x = 64.0
	_update_test_percent_label(value_label, slider, current_value, label_text, is_bonus)
	slider.value_changed.connect(
		_on_test_percent_changed.bind(slider, value_label, label_text, is_bonus)
	)
	return parts


func _sync_test_settings() -> void:
	if _view_model == null or not _view_model.has_test_settings():
		return
	var settings := _view_model.test_settings()
	_test_damage_immunity_toggle.set_pressed_no_signal(settings.damage_immunity_enabled())
	_update_test_immunity(settings.damage_immunity_enabled())
	_test_outgoing_damage_slider.set_value_no_signal(settings.outgoing_damage_bonus_percent())
	_update_test_percent_label(
		_test_outgoing_damage_value,
		_test_outgoing_damage_slider,
		settings.outgoing_damage_bonus_percent(),
		"Ausgehender Schaden",
		true
	)
	_test_movement_speed_slider.set_value_no_signal(settings.movement_speed_percent())
	_update_test_percent_label(
		_test_movement_speed_value,
		_test_movement_speed_slider,
		settings.movement_speed_percent(),
		"Galopp",
		false
	)


func _on_test_damage_immunity_changed(enabled: bool) -> void:
	_update_test_immunity(enabled)
	test_damage_immunity_changed.emit(enabled)


func _update_test_immunity(enabled: bool) -> void:
	_test_damage_immunity_toggle.text = "Ein" if enabled else "Aus"
	_test_damage_immunity_toggle.set_meta(
		&"alveolus_accessible_name",
		"Schadensimmunität: %s" % ("Ein" if enabled else "Aus")
	)


func _on_test_percent_changed(
	value: float,
	slider: HSlider,
	value_label: Label,
	label_text: String,
	is_bonus: bool
) -> void:
	var percent := roundi(value)
	_update_test_percent_label(value_label, slider, percent, label_text, is_bonus)
	if is_bonus:
		test_outgoing_damage_bonus_percent_changed.emit(percent)
	else:
		test_movement_speed_percent_changed.emit(percent)


func _update_test_percent_label(
	value_label: Label,
	slider: HSlider,
	percent: int,
	label_text: String,
	is_bonus: bool
) -> void:
	var formatted := "+%d %%" % percent if is_bonus else "%d %%" % percent
	value_label.text = formatted
	slider.set_meta(&"alveolus_accessible_name", "%s: %s" % [label_text, formatted])


func _sync_stat_sections() -> void:
	var preserved_scroll := _body_scroll.scroll_vertical
	var preserved_focus_id := _focused_section_id()
	_stat_sections.clear()
	_stat_rows.clear()
	if _view_model == null:
		_empty_stats_label.show()
		_stats_core_host.hide()
		_stats_grid.hide()
		return
	_empty_stats_label.visible = not _view_model.has_stats()
	_stats_core_host.visible = _view_model.has_stats()
	_stats_grid.visible = _view_model.has_stats()
	var live_section_ids: Dictionary = {}
	var build_index := 0
	for section_index in range(_view_model.section_count()):
		var section := _view_model.section_at(section_index)
		var section_id: StringName = section.id()
		live_section_ids[section_id] = true
		var target_parent: Container = _stats_core_host if section_id == &"general" else _stats_grid
		var target_index := 0 if section_id == &"general" else build_index
		var section_panel := _section_controls.get(section_id) as PanelContainer
		if section_panel == null:
			section_panel = _create_stat_section(section)
			_section_controls[section_id] = section_panel
			target_parent.add_child(section_panel)
			_expanded_sections[section_id] = section_id == &"general"
		elif section_panel.get_parent() != target_parent:
			section_panel.reparent(target_parent, false)
		target_parent.move_child(section_panel, target_index)
		_update_stat_section(section, section_panel)
		_stat_sections.append(section_panel)
		if section_id != &"general":
			build_index += 1
	for stale_id_value in _section_controls.keys():
		var stale_id := StringName(String(stale_id_value))
		if live_section_ids.has(stale_id):
			continue
		var stale_panel := _section_controls.get(stale_id) as PanelContainer
		_section_controls.erase(stale_id)
		_section_headers.erase(stale_id)
		_section_bodies.erase(stale_id)
		_expanded_sections.erase(stale_id)
		if stale_panel != null:
			var stale_parent := stale_panel.get_parent()
			if stale_parent != null:
				stale_parent.remove_child(stale_panel)
			stale_panel.queue_free()
	_update_focus_trap()
	_queue_responsive_layout()
	_restore_stats_view_state.call_deferred(preserved_focus_id, preserved_scroll)


func _create_stat_section(section: PauseOverlayViewModel.SectionViewModel) -> PanelContainer:
	var section_id := section.id()
	var accent := _accent_color(section.accent_role())
	var surface_role := (
		AlveolusVisualTheme.SurfaceRole.SECTION_GROUP
		if section_id == &"general"
		else AlveolusVisualTheme.SurfaceRole.ACTION_CARD
	)
	var section_panel := AlveolusUIComponents.surface(surface_role, accent)
	section_panel.name = "StatSection_%s" % _safe_node_suffix(section_id)
	section_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	section_panel.set_meta(&"alveolus_component", &"stat_accordion_section")
	section_panel.set_meta(&"alveolus_visual_role", &"patient_core" if section_id == &"general" else &"build_card")
	section_panel.set_meta(&"section_id", section_id)
	var stack := VBoxContainer.new()
	stack.name = "SectionStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	var header := AlveolusUIComponents.action_button(
		"",
		AlveolusUIComponents.ACTION_QUIET
	)
	header.name = "SectionHeader"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.toggle_mode = true
	header.flat = true
	header.focus_mode = Control.FOCUS_ALL
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.custom_minimum_size.y = AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	header.set_meta(&"section_id", section_id)
	header.toggled.connect(_on_section_toggled.bind(section_id))
	header.focus_entered.connect(_ensure_focus_visible.bind(header))
	var header_inset := MarginContainer.new()
	header_inset.name = "SectionHeaderInset"
	header_inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_inset.add_theme_constant_override("margin_left", AlveolusVisualTheme.CONTROL_GAP)
	header_inset.add_theme_constant_override("margin_right", AlveolusVisualTheme.CONTROL_GAP)
	header_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header_row := HBoxContainer.new()
	header_row.name = "SectionHeaderRow"
	header_row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_inset.add_child(header_row)
	var section_icon := SimpleIcon.new()
	section_icon.name = "SectionIcon"
	section_icon.custom_minimum_size = Vector2(28.0, 28.0)
	section_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	section_icon.configure(section.icon_id(), accent)
	header_row.add_child(section_icon)
	var identity := VBoxContainer.new()
	identity.name = "SectionIdentity"
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 0)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var eyebrow := AlveolusUIComponents.label(section.title(), AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	eyebrow.name = "SectionEyebrow"
	eyebrow.add_theme_color_override("font_color", accent.lightened(0.14))
	eyebrow.visible = not section.detail_title().is_empty()
	identity.add_child(eyebrow)
	var header_label := AlveolusUIComponents.label(
		section.detail_title() if not section.detail_title().is_empty() else section.title(),
		AlveolusVisualTheme.TYPE_VALUE_LABEL
	)
	header_label.name = "SectionTitle"
	header_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(header_label)
	header_row.add_child(identity)
	var chevron := SimpleIcon.new()
	chevron.name = "SectionChevron"
	chevron.custom_minimum_size = Vector2.ONE * SECTION_CHEVRON_SIZE
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.configure(&"chevron_right", AlveolusVisualTheme.TURQUOISE)
	chevron.set_meta(&"alveolus_component", &"accordion_chevron")
	header_row.add_child(chevron)
	header.add_child(header_inset)
	stack.add_child(header)
	var body := GridContainer.new()
	body.name = "SectionRows"
	body.columns = 2
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTENT_GAP)
	body.add_theme_constant_override("v_separation", AlveolusVisualTheme.GRID_UNIT)
	body.set_meta(&"section_id", section_id)
	stack.add_child(body)
	section_panel.add_child(AlveolusUIComponents.margin(stack, AlveolusVisualTheme.GRID_UNIT))
	_section_headers[section_id] = header
	_section_bodies[section_id] = body
	return section_panel


func _update_stat_section(section: PauseOverlayViewModel.SectionViewModel, _section_panel: PanelContainer) -> void:
	var section_id := section.id()
	var body := _section_bodies.get(section_id) as GridContainer
	var header := _section_headers.get(section_id) as Button
	if body == null or header == null:
		return
	header.set_meta(&"section_id", section_id)
	var section_icon := header.find_child("SectionIcon", true, false) as SimpleIcon
	if section_icon != null:
		section_icon.configure(section.icon_id(), _accent_color(section.accent_role()))
	_sync_section_rows(section, body)
	_apply_section_expansion(section_id)


func _sync_section_rows(section: PauseOverlayViewModel.SectionViewModel, body: GridContainer) -> void:
	var existing_rows: Dictionary = {}
	for child in body.get_children():
		if child is PanelContainer and child.has_meta(&"stat_id"):
			existing_rows[StringName(String(child.get_meta(&"stat_id")))] = child
	var live_row_ids: Dictionary = {}
	for row_index in range(section.row_count()):
		var stat := section.row_at(row_index)
		var row_id: StringName = stat.id()
		live_row_ids[row_id] = true
		var row_panel := existing_rows.get(row_id) as PanelContainer
		if row_panel == null:
			row_panel = _create_stat_row(stat)
			body.add_child(row_panel)
		body.move_child(row_panel, row_index)
		_update_stat_row(stat, row_panel)
		_stat_rows.append(row_panel)
	for stale_id_value in existing_rows.keys():
		var stale_id := StringName(String(stale_id_value))
		if live_row_ids.has(stale_id):
			continue
		var stale_row := existing_rows.get(stale_id) as PanelContainer
		if stale_row != null:
			body.remove_child(stale_row)
			stale_row.queue_free()


func _create_stat_row(stat: PauseOverlayViewModel.StatValueViewModel) -> PanelContainer:
	var row_panel := AlveolusUIComponents.dossier_value_row(
		stat.label(),
		stat.formatted_value(),
		stat.icon_id(),
		_accent_color(stat.accent_role())
	)
	row_panel.name = "StatRow_%s" % _safe_node_suffix(stat.id())
	row_panel.custom_minimum_size.y = 40.0
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var marker := row_panel.find_child("ValueIcon", true, false) as SimpleIcon
	if marker != null:
		marker.name = "StatIcon"
	var caption := row_panel.find_child("ValueName", true, false) as Label
	if caption != null:
		caption.name = "StatLabel"
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.custom_minimum_size.x = STAT_LABEL_MINIMUM_WIDTH
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var value := row_panel.find_child("Value", true, false) as Label
	if value != null:
		value.name = "StatValue"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return row_panel


func _update_stat_row(stat: PauseOverlayViewModel.StatValueViewModel, row_panel: PanelContainer) -> void:
	row_panel.set_meta(&"stat_id", stat.id())
	row_panel.set_meta(&"stat_group", stat.section_id())
	row_panel.set_meta(&"stat_accent_role", stat.accent_role())
	row_panel.tooltip_text = (
		stat.detail_text()
		if not stat.detail_text().is_empty()
		else "%s: %s" % [stat.label(), stat.formatted_value()]
	)
	var marker := row_panel.find_child("StatIcon", true, false) as SimpleIcon
	var caption := row_panel.find_child("StatLabel", true, false) as Label
	var value := row_panel.find_child("StatValue", true, false) as Label
	if marker != null:
		marker.configure(stat.icon_id(), _accent_color(stat.accent_role()))
	if caption != null:
		caption.text = stat.label()
	if value != null:
		value.text = stat.formatted_value()
		# The row is already attached when refreshed, so the inherited Bio-Lumen
		# font is available for deterministic value-column measurement.
		value.custom_minimum_size.x = _measured_stat_value_width(value)


func _on_section_toggled(expanded: bool, section_id: StringName) -> void:
	if not _section_controls.has(section_id):
		return
	_expanded_sections[section_id] = expanded
	_apply_section_expansion(section_id)
	_update_focus_trap()
	_queue_responsive_layout()


func _apply_section_expansion(section_id: StringName) -> void:
	var expanded := is_section_expanded(section_id)
	var header := _section_headers.get(section_id) as Button
	var body := _section_bodies.get(section_id) as GridContainer
	var section := _view_model.section_by_id(section_id) if _view_model != null else null
	if header != null:
		header.set_pressed_no_signal(expanded)
		var title := section.display_title() if section != null else "Werte"
		var chevron := header.find_child("SectionChevron", true, false) as SimpleIcon
		var title_label := header.find_child("SectionTitle", true, false) as Label
		var eyebrow_label := header.find_child("SectionEyebrow", true, false) as Label
		if chevron != null:
			chevron.configure(
				&"chevron_down" if expanded else &"chevron_right",
				AlveolusVisualTheme.TURQUOISE
			)
			chevron.set_meta(&"accordion_state", &"expanded" if expanded else &"collapsed")
		if title_label != null:
			title_label.text = (
				section.detail_title()
				if section != null and not section.detail_title().is_empty()
				else section.title() if section != null else "Werte"
			)
		if eyebrow_label != null:
			eyebrow_label.text = section.title() if section != null else ""
			eyebrow_label.visible = section != null and not section.detail_title().is_empty()
		header.set_meta(&"accordion_state", &"expanded" if expanded else &"collapsed")
		header.set_meta(
			&"alveolus_accessible_name",
			"%s, %s. %s" % [
				title,
				"ausgeklappt" if expanded else "eingeklappt",
				"Einklappen" if expanded else "Ausklappen",
			]
		)
		header.tooltip_text = "%s %s" % [title, "einklappen" if expanded else "ausklappen"]
	if body != null:
		body.visible = expanded


func _focused_section_id() -> StringName:
	if not is_inside_tree():
		return &""
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and focus_owner.has_meta(&"section_id"):
		return StringName(String(focus_owner.get_meta(&"section_id")))
	return &""


func _restore_stats_view_state(section_id: StringName, scroll_value: int) -> void:
	if _body_scroll == null:
		return
	if section_id != &"":
		var header := _section_headers.get(section_id) as Button
		if header != null and header.is_visible_in_tree() and get_viewport().gui_get_focus_owner() != header:
			header.grab_focus()
	_body_scroll.scroll_vertical = clampi(scroll_value, 0, roundi(_body_scroll.get_v_scroll_bar().max_value))


func _safe_node_suffix(value: StringName) -> String:
	return String(value).replace(":", "_").replace("/", "_").replace(" ", "_")


func _apply_mode(mode: int) -> void:
	_mode = mode
	var menu_visible := mode == Mode.MENU
	match mode:
		Mode.MENU:
			_title_label.text = "Pause"
		Mode.STATS:
			_title_label.text = "Charakterwerte"
		Mode.TEST:
			_title_label.text = "Testwerte"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if menu_visible else HORIZONTAL_ALIGNMENT_LEFT
	_doctor_balance.visible = menu_visible
	_doctor_label.visible = mode in [Mode.MENU, Mode.STATS]
	_doctor_label.text = "Doctor Milos" if menu_visible else "Doctor Milos · aktueller Run"
	_menu_body.visible = menu_visible
	_stats_body.visible = mode == Mode.STATS
	if _test_body != null:
		_test_body.visible = mode == Mode.TEST
	_resume_button.visible = menu_visible
	_back_button.visible = not menu_visible
	_update_focus_trap()
	_queue_responsive_layout()


func _update_focus_trap() -> void:
	var visible_actions: Array[Control] = []
	if _mode == Mode.MENU:
		var menu_buttons: Array[Button] = [
			_settings_button,
			_stats_button,
			_test_values_button,
			_intro_skip_button,
			_abort_button,
			_resume_button,
		]
		for button in menu_buttons:
			if not button.disabled and button.visible:
				visible_actions.append(button)
	elif _mode == Mode.STATS:
		if _view_model != null:
			for section in _view_model.sections():
				var header := _section_headers.get(section.id()) as Button
				if header != null and header.visible and not header.disabled:
					visible_actions.append(header)
		visible_actions.append(_back_button)
	else:
		for control in [
			_test_damage_immunity_toggle,
			_test_outgoing_damage_slider,
			_test_movement_speed_slider,
			_test_reset_button,
			_back_button,
		]:
			if control != null and control.visible and control.focus_mode != Control.FOCUS_NONE:
				visible_actions.append(control)
	for index in range(visible_actions.size()):
		var action := visible_actions[index]
		var previous := visible_actions[posmod(index - 1, visible_actions.size())]
		var following := visible_actions[(index + 1) % visible_actions.size()]
		action.focus_neighbor_left = action.get_path_to(previous)
		action.focus_neighbor_top = action.get_path_to(previous)
		action.focus_neighbor_right = action.get_path_to(following)
		action.focus_neighbor_bottom = action.get_path_to(following)


func _ensure_focus_visible(control: Control) -> void:
	if _body_scroll != null and control != null and _body_scroll.is_ancestor_of(control):
		_body_scroll.ensure_control_visible(control)


func _queue_responsive_layout() -> void:
	_update_responsive_layout.call_deferred()


func _update_responsive_layout() -> void:
	if _center == null or _sheet == null or _body_scroll == null:
		return
	var compact := size.x < 640.0 or size.y < 400.0
	var outer_margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if compact else AlveolusVisualTheme.SCREEN_MARGIN
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_safe_area.add_theme_constant_override(side, outer_margin)
	# Derive the responsive budget from the actual logical viewport. Reading the
	# CenterContainer here creates a circular minimum-size dependency: a wide
	# two-column child can temporarily enlarge the center and prevent the compact
	# breakpoint from ever being reached.
	var available := Vector2(
		maxf(0.0, size.x - outer_margin * 2.0),
		maxf(0.0, size.y - outer_margin * 2.0)
	)
	if available.x <= 0.0 or available.y <= 0.0:
		return
	_sync_doctor_balance()

	var maximum_width := MENU_MAXIMUM_WIDTH if _mode == Mode.MENU else STATS_MAXIMUM_WIDTH
	var sheet_width := minf(maximum_width, available.x)
	_sheet.custom_minimum_size.x = floorf(sheet_width)
	var sheet_padding := COMPACT_MODAL_PADDING if compact else MODAL_PADDING
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_sheet_margin.add_theme_constant_override(side, sheet_padding)
	var compact_menu := sheet_width < COMPACT_MENU_BREAKPOINT
	_menu_actions.columns = 2 if compact_menu or _has_test_settings() else 3
	_set_compact_menu_layout(compact_menu)
	# Opening a build card reveals its values in place. It must not reflow the
	# surrounding dossier or turn a half-width component into a full-width row.
	_stats_grid.columns = 1 if sheet_width < BUILD_GRID_BREAKPOINT else 2
	for section_id_value in _section_bodies:
		var section_id := StringName(String(section_id_value))
		var body_value: Variant = _section_bodies[section_id_value]
		var section_body := body_value as GridContainer
		if section_body != null:
			section_body.columns = (
				1 if section_id != &"general" or sheet_width < COMPACT_STATS_BREAKPOINT else 2
			)
	_set_compact_stat_label_width(compact_menu)

	_body_scroll.custom_minimum_size.y = 0.0
	var active_body: Control = _menu_body
	if _mode == Mode.STATS:
		active_body = _stats_body
	elif _mode == Mode.TEST:
		active_body = _test_body
	var body_height := active_body.get_combined_minimum_size().y
	var active_footer := _resume_button if _mode == Mode.MENU else _back_button
	var chrome_height := (
		float(sheet_padding * 2)
		+ _pause_header.get_combined_minimum_size().y
		+ active_footer.get_combined_minimum_size().y
		+ float(AlveolusVisualTheme.CONTENT_GAP * 2)
	)
	var maximum_body_height := maxf(0.0, available.y - chrome_height)
	var visible_body_height := minf(body_height, maximum_body_height)
	_body_scroll.custom_minimum_size.y = ceilf(visible_body_height)
	var requires_scroll := body_height > visible_body_height + 1.0
	_body_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if requires_scroll
		else ScrollContainer.SCROLL_MODE_DISABLED
	)
	var scrollbar_inset := ceili(_body_scroll.get_v_scroll_bar().get_combined_minimum_size().x) if requires_scroll else 0
	_scrollbar_inset.add_theme_constant_override("margin_right", scrollbar_inset)
	if not requires_scroll:
		_body_scroll.scroll_vertical = 0


func _sync_doctor_balance() -> void:
	if _doctor_balance == null or _doctor_label == null:
		return
	# Equal left and right side widths keep "Pause" geometrically centered even
	# though the Doctor metadata remains aligned at the right edge.
	_doctor_balance.custom_minimum_size.x = _doctor_label.get_combined_minimum_size().x


func _set_compact_menu_layout(compact: bool) -> void:
	if compact:
		if _abort_button.get_parent() != _menu_danger_row:
			_abort_button.reparent(_menu_danger_row)
			_update_focus_trap()
		_menu_danger_row.show()
		return
	if _abort_button.get_parent() != _menu_actions:
		_abort_button.reparent(_menu_actions)
		# Routine actions stay before the danger action. The optional intro
		# action follows them when it is enabled.
		_menu_actions.move_child(_abort_button, mini(3, _menu_actions.get_child_count() - 1))
		_update_focus_trap()
	_menu_danger_row.hide()


func _has_test_settings() -> bool:
	return _view_model != null and _view_model.has_test_settings()


func _measured_stat_value_width(value: Label) -> float:
	var font := value.get_theme_font("font")
	var font_size := value.get_theme_font_size("font_size")
	var text_width := font.get_string_size(
		value.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x
	# The bounded value column preserves as much room as possible for the
	# caption while keeping full values readable. The row tooltip remains the
	# unabridged fallback for exceptionally long localized values.
	return clampf(ceilf(text_width + 8.0), 56.0, 120.0)


func _set_compact_stat_label_width(compact: bool) -> void:
	for row in _stat_rows:
		var caption := row.find_child("StatLabel", true, false) as Label
		var value := row.find_child("StatValue", true, false) as Label
		if caption == null:
			continue
		caption.custom_minimum_size.x = (
			maxf(COMPACT_STAT_LABEL_FLOOR, COMPACT_STAT_TEXT_MINIMUM_WIDTH - value.custom_minimum_size.x)
			if compact and value != null
			else STAT_LABEL_MINIMUM_WIDTH
		)


func _accent_color(role: StringName) -> Color:
	match role:
		&"teal":
			return AlveolusVisualTheme.TEAL
		&"turquoise":
			return AlveolusVisualTheme.TURQUOISE
		&"cobalt":
			return AlveolusVisualTheme.COBALT
		&"coral":
			return AlveolusVisualTheme.CORAL
	return AlveolusVisualTheme.GOLD
