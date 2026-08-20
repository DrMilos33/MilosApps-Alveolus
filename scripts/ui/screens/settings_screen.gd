class_name SettingsScreen
extends Control

signal audio_value_changed(setting_id: StringName, linear_value: float)
signal audio_mute_changed(setting_id: StringName, muted: bool)
signal option_changed(setting_id: StringName, selected_index: int)
signal toggle_changed(setting_id: StringName, enabled: bool)
# Compatibility signal retained for facade/API stability. New integrations
# connect binding_slot_change_requested so both keyboard slots stay distinct.
signal binding_change_requested(action_id: StringName)
signal binding_slot_change_requested(action_id: StringName, slot_index: int)
signal binding_conflict_decided(
	action_id: StringName,
	slot_index: int,
	conflicting_action_id: StringName,
	replace_existing: bool
)
signal bindings_reset_requested
signal new_game_requested
signal quit_requested
signal back

const COMPACT_WIDTH := 760.0
const TWO_BINDING_COLUMNS_WIDTH := 760.0
const THREE_BINDING_COLUMNS_WIDTH := 1180.0
const TWO_UPPER_CONTROL_COLUMNS_WIDTH := 1180.0
const OPTION_LABEL_WIDTH := 116.0
const TOGGLE_LABEL_WIDTH := 172.0

var _view_model: SettingsScreenViewModel
var _applied_revision := -1
var _applied_content_hash := 0
var _shell: PanelContainer
var _safe_area: MarginContainer
var _shell_stack: VBoxContainer
var _header: PanelContainer
var _scroll: ScrollContainer
var _settings_stack: VBoxContainer
var _upper_grid: GridContainer
var _options_grid: GridContainer
var _toggles_grid: GridContainer
var _bindings_grid: GridContainer
var _back_button: Button
var _controls: Dictionary = {}
var _audio_layout_records: Array[Dictionary] = []
var _option_controls: Array[OptionButton] = []
var _option_layout_records: Array[Dictionary] = []
var _binding_layout_records: Array[Dictionary] = []
var _focus_order: Array[Control] = []
var _conflict_layer: ColorRect
var _conflict_modal: PanelContainer
var _conflict_cancel_button: Button
var _conflict_confirm_button: Button
var _compact_layout := false
var _navigation_restore_scheduled := false
var _pending_restore_setting_id: StringName = &""
var _pending_restore_scroll := 0
var _pending_restore_revision := -1


func _init() -> void:
	set_process(false)
	set_physics_process(false)
	_build_interface()


func apply(view_model: SettingsScreenViewModel) -> bool:
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

	var previous_focus_id := _focused_setting_id()
	var previous_scroll := _scroll.scroll_vertical
	_view_model = view_model.duplicate_immutable()
	_applied_revision = next_revision
	_applied_content_hash = next_hash
	_rebuild_sections()
	_sync_binding_conflict()
	if is_binding_conflict_open():
		_pending_restore_setting_id = &""
		_pending_restore_scroll = previous_scroll
		_pending_restore_revision = _applied_revision
	else:
		_restore_navigation_state(previous_focus_id, previous_scroll, _applied_revision)
	return true


func apply_view_model(view_model: SettingsScreenViewModel) -> bool:
	return apply(view_model)


func get_applied_revision() -> int:
	return _applied_revision


func get_applied_content_hash() -> int:
	return _applied_content_hash


func get_view_model() -> SettingsScreenViewModel:
	return _view_model.duplicate_immutable() if _view_model != null else null


func get_scroll_container() -> ScrollContainer:
	return _scroll


func get_upper_column_count() -> int:
	return _upper_grid.columns if _upper_grid != null else 0


func get_binding_column_count() -> int:
	return _bindings_grid.columns if _bindings_grid != null else 0


func is_compact_layout() -> bool:
	return _compact_layout


func control_for_setting(setting_key: StringName) -> Control:
	return _controls.get(setting_key) as Control


func is_binding_conflict_open() -> bool:
	return (
		_conflict_layer != null
		and is_instance_valid(_conflict_layer)
		and _conflict_layer.is_visible_in_tree()
	)


func get_binding_conflict_default_focus_control() -> Control:
	return _conflict_cancel_button


func cancel_binding_conflict() -> bool:
	if _view_model == null:
		return false
	var conflict := _view_model.get_binding_conflict()
	if conflict == null:
		return false
	_on_binding_conflict_decided(conflict, false)
	return true


func get_default_focus_control() -> Control:
	if _view_model != null:
		var audio_settings := _view_model.get_audio_settings()
		if not audio_settings.is_empty():
			var first_key := _audio_value_key(audio_settings[0].get_id())
			var first_control := control_for_setting(first_key)
			if first_control != null:
				return first_control
	return _back_button


func grab_initial_focus() -> void:
	var focus_control := get_default_focus_control()
	if focus_control != null:
		focus_control.grab_focus()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED

	_back_button = AlveolusUIComponents.action_button(
		"Zurück",
		AlveolusUIComponents.ACTION_NAVIGATION,
		&"back",
		AlveolusVisualTheme.TEAL
	)
	_back_button.name = "BackButton"
	_back_button.set_meta(&"setting_id", &"back")
	_back_button.pressed.connect(func() -> void: back.emit())
	_controls[&"back"] = _back_button

	var header_parts := AlveolusUIComponents.page_header("Einstellungen", "", _back_button)
	_header = header_parts["panel"] as PanelContainer
	_header.name = "PageHeader"

	_scroll = ScrollContainer.new()
	_scroll.name = "SettingsScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true

	_settings_stack = VBoxContainer.new()
	_settings_stack.name = "SettingsStack"
	_settings_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_stack.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_scroll.add_child(_settings_stack)

	var shell_parts := AlveolusUIComponents.page_shell(_header, _scroll)
	_shell = shell_parts["shell"] as PanelContainer
	_safe_area = shell_parts["safe_area"] as MarginContainer
	_shell_stack = shell_parts["stack"] as VBoxContainer
	_shell.name = "PageShell"
	add_child(_shell)
	resized.connect(_refresh_responsive_layout)


func _rebuild_sections() -> void:
	for child in _settings_stack.get_children():
		_settings_stack.remove_child(child)
		child.queue_free()
	_controls.clear()
	_controls[&"back"] = _back_button
	_focus_order.clear()
	_focus_order.append(_back_button)
	_audio_layout_records.clear()
	_option_controls.clear()
	_option_layout_records.clear()
	_binding_layout_records.clear()
	_upper_grid = GridContainer.new()
	_upper_grid.name = "UpperSections"
	_upper_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upper_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTENT_GAP)
	_upper_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTENT_GAP)
	_settings_stack.add_child(_upper_grid)

	var audio_section := _section("Audio", AlveolusVisualTheme.TEAL)
	var audio_panel := audio_section["panel"] as PanelContainer
	var audio_content := audio_section["content"] as VBoxContainer
	audio_panel.name = "AudioSection"
	_upper_grid.add_child(audio_panel)
	for setting in _view_model.get_audio_settings():
		_build_audio_row(audio_content, setting)

	var display_section := _section("Anzeige und Bedienung", AlveolusVisualTheme.COBALT)
	var display_panel := display_section["panel"] as PanelContainer
	var display_content := display_section["content"] as VBoxContainer
	display_panel.name = "DisplaySection"
	_upper_grid.add_child(display_panel)
	_options_grid = null
	var visible_options := _view_model.get_visible_option_settings()
	if not visible_options.is_empty():
		_options_grid = GridContainer.new()
		_options_grid.name = "DisplayOptionsGrid"
		_options_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_options_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
		_options_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.GRID_UNIT)
		display_content.add_child(_options_grid)
		for setting in visible_options:
			_build_option_row(_options_grid, setting)
	_toggles_grid = GridContainer.new()
	_toggles_grid.name = "DisplayTogglesGrid"
	_toggles_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toggles_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_toggles_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.GRID_UNIT)
	display_content.add_child(_toggles_grid)
	for setting in _view_model.get_toggle_settings():
		if setting.is_visible():
			_build_toggle_row(_toggles_grid, setting)

	var controls_section := _section("Steuerung", AlveolusVisualTheme.TURQUOISE)
	var controls_panel := controls_section["panel"] as PanelContainer
	var controls_content := controls_section["content"] as VBoxContainer
	controls_panel.name = "ControlsSection"
	_settings_stack.add_child(controls_panel)
	var bindings_explanation := AlveolusUIComponents.label(
		"Jede Aktion besitzt zwei frei belegbare Tastaturplätze.",
		AlveolusVisualTheme.TYPE_MUTED_LABEL
	)
	bindings_explanation.name = "BindingsExplanation"
	bindings_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_content.add_child(bindings_explanation)
	_bindings_grid = GridContainer.new()
	_bindings_grid.name = "BindingsGrid"
	_bindings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bindings_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.GRID_UNIT)
	_bindings_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.GRID_UNIT)
	controls_content.add_child(_bindings_grid)
	for binding in _view_model.get_binding_settings():
		_build_binding_row(binding)

	var reset_button := AlveolusUIComponents.action_button(
		"Standardbelegung wiederherstellen",
		AlveolusUIComponents.ACTION_QUIET,
		&"restart",
		AlveolusVisualTheme.MUTED
	)
	reset_button.name = "ResetBindingsButton"
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset_button.set_meta(&"setting_id", &"bindings.reset")
	reset_button.set_meta(&"alveolus_accessible_name", "Standardbelegung wiederherstellen")
	reset_button.pressed.connect(func() -> void: bindings_reset_requested.emit())
	_controls[&"bindings.reset"] = reset_button
	_focus_order.append(reset_button)
	controls_content.add_child(reset_button)

	var status := AlveolusUIComponents.label(_view_model.get_status_text(), AlveolusVisualTheme.TYPE_MUTED_LABEL)
	status.name = "StatusText"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.visible = not _view_model.get_status_text().is_empty()
	controls_content.add_child(status)

	# Keep the compatibility control mounted while letting the content model
	# decide whether it contributes any layout space.
	var actions := HBoxContainer.new()
	actions.name = "SettingsActions"
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.visible = true
	var new_game_button := AlveolusUIComponents.action_button(
		"Neues Spiel",
		AlveolusUIComponents.ACTION_DANGER,
		&"restart",
		AlveolusVisualTheme.CORAL
	)
	new_game_button.name = "NewGameButton"
	new_game_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	new_game_button.set_meta(&"setting_id", &"new_game")
	new_game_button.set_meta(&"alveolus_accessible_name", "Neues Spiel. Löscht den lokalen Fortschritt.")
	new_game_button.tooltip_text = "Setzt Forschung, Talente, Fälle und Entdeckungen zurück."
	new_game_button.pressed.connect(func() -> void: new_game_requested.emit())
	_controls[&"new_game"] = new_game_button
	actions.add_child(new_game_button)
	_focus_order.append(new_game_button)
	var quit_button := AlveolusUIComponents.action_button(
		"Spiel beenden",
		AlveolusUIComponents.ACTION_DANGER,
		&"",
		AlveolusVisualTheme.CORAL
	)
	quit_button.name = "QuitButton"
	quit_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	quit_button.set_meta(&"setting_id", &"quit")
	quit_button.set_meta(&"alveolus_accessible_name", "Spiel beenden")
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	_controls[&"quit"] = quit_button
	actions.add_child(quit_button)
	quit_button.visible = _view_model.should_show_quit()
	controls_content.add_child(actions)
	if quit_button.visible:
		_focus_order.append(quit_button)

	_refresh_responsive_layout()
	_refresh_focus_neighbors()


func _section(title_text: String, accent: Color) -> Dictionary:
	var panel := AlveolusUIComponents.surface(AlveolusVisualTheme.SurfaceRole.ACTION_CARD, accent)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.set_meta(&"settings_section", StringName(title_text))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	content.add_child(AlveolusUIComponents.label(title_text, AlveolusVisualTheme.TYPE_SECTION_LABEL))
	panel.add_child(AlveolusUIComponents.margin(content, AlveolusVisualTheme.CONTENT_GAP))
	return {"panel": panel, "content": content}


func _build_audio_row(parent: VBoxContainer, setting: SettingsScreenViewModel.AudioSettingViewModel) -> void:
	var parts := AlveolusUIComponents.slider_row(
		setting.get_label(),
		0.0,
		100.0,
		setting.get_linear_value() * 100.0,
		1.0
	)
	var row := parts["row"] as HBoxContainer
	var title := parts["label"] as Label
	var slider := parts["control"] as HSlider
	var value_label := parts["value_label"] as Label
	var mute := AlveolusUIComponents.toggle_row("Stumm", setting.is_muted())
	# The switch remains a full-size input, but its Button chrome is flat so it
	# does not read as another card inside the section surface.
	mute.theme_type_variation = &""
	mute.flat = true
	mute.set_meta(&"alveolus_component", &"transparent_toggle")
	# Four controls in a fixed HBox cannot shrink safely at 200 percent because
	# label text contributes its intrinsic width. A responsive grid keeps the
	# desktop row unchanged and forms two readable rows on compact canvases.
	for control in [title, slider, value_label]:
		row.remove_child(control)
	row.free()
	var layout := GridContainer.new()
	layout.name = "AudioLayout_%s" % String(setting.get_id())
	layout.columns = 4
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	layout.add_theme_constant_override("v_separation", AlveolusVisualTheme.GRID_UNIT)
	layout.add_child(title)
	layout.add_child(slider)
	layout.add_child(value_label)
	layout.add_child(mute)
	var value_key := _audio_value_key(setting.get_id())
	var mute_key := _audio_mute_key(setting.get_id())
	slider.name = "Audio_%s" % String(setting.get_id())
	slider.set_meta(&"setting_id", value_key)
	mute.set_meta(&"setting_id", mute_key)
	slider.set_meta(
		&"alveolus_accessible_name",
		"%s: %d Prozent" % [setting.get_label(), roundi(setting.get_linear_value() * 100.0)]
	)
	mute.set_meta(
		&"alveolus_accessible_name",
		"%s stumm: %s" % [setting.get_label(), "Ein" if setting.is_muted() else "Aus"]
	)
	mute.set_meta(&"setting_purpose", "%s stumm" % setting.get_label())
	mute.custom_minimum_size.x = 92.0
	slider.value_changed.connect(_on_audio_value_changed.bind(setting.get_id()))
	mute.toggled.connect(_on_audio_mute_changed.bind(setting.get_id()))
	_controls[value_key] = slider
	_controls[mute_key] = mute
	_focus_order.append(slider)
	_focus_order.append(mute)
	parent.add_child(layout)
	_link_horizontal_focus_pair(slider, mute)
	_audio_layout_records.append({
		"layout": layout,
		"label": title,
		"slider": slider,
		"value": value_label,
		"mute": mute,
	})


func _build_option_row(parent: Container, setting: SettingsScreenViewModel.OptionSettingViewModel) -> void:
	var parts := AlveolusUIComponents.option_row(setting.get_label(), setting.get_entries(), setting.get_selected_index())
	var row := parts["row"] as HBoxContainer
	var title := parts["label"] as Label
	var control := parts["control"] as OptionButton
	row.name = "OptionLayout_%s" % String(setting.get_id())
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	row.custom_minimum_size.y = AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	row.set_meta(&"alveolus_component", &"compact_setting_row")
	title.name = "SettingPurpose"
	title.text = _option_purpose(setting.get_id(), setting.get_label())
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.custom_minimum_size.x = OPTION_LABEL_WIDTH
	title.clip_text = false
	title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var key := _option_key(setting.get_id())
	control.name = "Option_%s" % String(setting.get_id())
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	control.set_meta(&"setting_id", key)
	control.set_meta(&"alveolus_accessible_name", title.text)
	control.item_selected.connect(_on_option_changed.bind(setting.get_id()))
	_controls[key] = control
	_focus_order.append(control)
	_option_controls.append(control)
	_option_layout_records.append({"row": row, "label": title, "control": control})
	parent.add_child(row)


func _option_purpose(setting_id: StringName, fallback: String) -> String:
	match setting_id:
		&"ui_scale":
			return "UI-Größe"
		&"glyph_mode":
			return "Eingabemodus"
	return fallback


func _build_toggle_row(parent: Container, setting: SettingsScreenViewModel.ToggleSettingViewModel) -> void:
	var toggle := AlveolusUIComponents.toggle_row("Ein" if setting.is_enabled() else "Aus", setting.is_enabled())
	toggle.theme_type_variation = &""
	toggle.flat = true
	toggle.set_meta(&"alveolus_component", &"transparent_toggle")
	var key := _toggle_key(setting.get_id())
	var visible_label := _toggle_purpose(setting.get_id(), setting.get_label())
	toggle.name = "Toggle_%s" % String(setting.get_id())
	toggle.set_meta(&"setting_id", key)
	toggle.set_meta(&"setting_purpose", visible_label)
	toggle.set_meta(
		&"alveolus_accessible_name",
		"%s: %s" % [visible_label, "Ein" if setting.is_enabled() else "Aus"]
	)
	toggle.custom_minimum_size.x = 80.0
	toggle.toggled.connect(_on_toggle_changed.bind(setting.get_id(), toggle))
	var row := _compact_setting_row(visible_label, toggle)
	row.name = "ToggleLayout_%s" % String(setting.get_id())
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	var purpose_label := row.find_child("SettingPurpose", true, false) as Label
	if purpose_label != null:
		purpose_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		purpose_label.custom_minimum_size.x = TOGGLE_LABEL_WIDTH
		purpose_label.clip_text = false
		purpose_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	if setting.get_id() == &"reduce_motion":
		toggle.tooltip_text = "Reduziert UI-Animationen und Bewegungseffekte."
	elif setting.get_id() == &"show_character_name":
		toggle.tooltip_text = "Zeigt Doctor Milos dezent über der Spielfigur."
	_controls[key] = toggle
	_focus_order.append(toggle)
	parent.add_child(row)


func _toggle_purpose(setting_id: StringName, fallback: String) -> String:
	match setting_id:
		&"reduce_motion":
			return "Animationen reduzieren"
		&"run_stats":
			return "Werte im Run"
		&"show_character_name":
			return "Charaktername anzeigen"
		&"fullscreen":
			return "Vollbild"
		&"confirm_restart":
			return "Strg+R bestätigen"
	return fallback


func _build_binding_row(setting: SettingsScreenViewModel.BindingSettingViewModel) -> void:
	var purpose := _binding_purpose(setting.get_action_id(), setting.get_label())
	var slots := HBoxContainer.new()
	slots.name = "BindingSlots_%s" % String(setting.get_action_id())
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	var buttons: Array[Button] = []
	for slot_index in range(2):
		var caption := "Taste drücken …" if setting.is_slot_capturing(slot_index) else setting.get_binding_text(slot_index)
		var button := AlveolusUIComponents.action_button(
			caption,
			AlveolusUIComponents.ACTION_SECONDARY,
			&"",
			AlveolusVisualTheme.COBALT
		)
		var key := _binding_slot_key(setting.get_action_id(), slot_index)
		button.name = "Binding_%s_%d" % [String(setting.get_action_id()), slot_index]
		button.set_meta(&"setting_id", key)
		button.set_meta(&"action_id", setting.get_action_id())
		button.set_meta(&"binding_slot", slot_index)
		button.set_meta(
			&"alveolus_accessible_name",
			"%s, Taste %d: %s" % [purpose, slot_index + 1, caption]
		)
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = "Taste %d · %s" % [slot_index + 1, caption]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_binding_requested.bind(setting.get_action_id(), slot_index))
		_controls[key] = button
		_focus_order.append(button)
		# The former semantic key resolves to the primary keyboard slot so
		# existing focus-restoration and facade lookups remain compatible.
		if slot_index == 0:
			_controls[_binding_key(setting.get_action_id())] = button
		slots.add_child(button)
		buttons.append(button)
	var layout := VBoxContainer.new()
	layout.name = "BindingLayout_%s" % String(setting.get_action_id())
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	layout.set_meta(&"alveolus_component", &"compact_binding_card")
	var purpose_label := AlveolusUIComponents.label(purpose, AlveolusVisualTheme.TYPE_BODY_LABEL)
	purpose_label.name = "SettingPurpose"
	purpose_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	purpose_label.clip_text = false
	purpose_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	layout.add_child(purpose_label)
	layout.add_child(slots)
	var card := AlveolusUIComponents.surface(
		AlveolusVisualTheme.SurfaceRole.VALUE_ROW,
		AlveolusVisualTheme.COBALT
	)
	card.name = "BindingCard_%s" % String(setting.get_action_id())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 80.0
	card.set_meta(&"alveolus_component", &"shortcut_container")
	card.add_child(AlveolusUIComponents.margin(layout, 6))
	_binding_layout_records.append({
		"card": card,
		"layout": layout,
		"purpose": purpose_label,
		"slots": slots,
		"buttons": buttons,
	})
	_bindings_grid.add_child(card)
	if buttons.size() == 2:
		_link_horizontal_focus_pair(buttons[0], buttons[1])


func _link_horizontal_focus_pair(left: Control, right: Control) -> void:
	if left == null or right == null:
		return
	left.focus_neighbor_right = left.get_path_to(right)
	right.focus_neighbor_left = right.get_path_to(left)


func _refresh_focus_neighbors() -> void:
	var focusable: Array[Control] = []
	for control in _focus_order:
		if control != null and is_instance_valid(control) and control.focus_mode != Control.FOCUS_NONE:
			focusable.append(control)
	if focusable.is_empty():
		return
	for index in range(focusable.size()):
		var control := focusable[index]
		var previous := focusable[posmod(index - 1, focusable.size())]
		var next := focusable[(index + 1) % focusable.size()]
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)
	_refresh_binding_grid_neighbors()


func _refresh_binding_grid_neighbors() -> void:
	if _bindings_grid == null or _binding_layout_records.is_empty():
		return
	var column_count := maxi(_bindings_grid.columns, 1)
	var first_buttons: Array = _binding_layout_records[0].get("buttons", []) as Array
	var preceding_control: Control = null
	if not first_buttons.is_empty():
		var first_button := first_buttons[0] as Control
		var first_index := _focus_order.find(first_button)
		if first_index > 0:
			preceding_control = _focus_order[first_index - 1]
	var following_control := _controls.get(&"bindings.reset") as Control
	for record_index in range(_binding_layout_records.size()):
		var buttons: Array = _binding_layout_records[record_index].get("buttons", []) as Array
		for slot_index in range(buttons.size()):
			var button := buttons[slot_index] as Control
			if button == null:
				continue
			var above_index := record_index - column_count
			var below_index := record_index + column_count
			var above := preceding_control
			var below := following_control
			if above_index >= 0:
				var above_buttons: Array = _binding_layout_records[above_index].get("buttons", []) as Array
				if slot_index < above_buttons.size():
					above = above_buttons[slot_index] as Control
			if below_index < _binding_layout_records.size():
				var below_buttons: Array = _binding_layout_records[below_index].get("buttons", []) as Array
				if slot_index < below_buttons.size():
					below = below_buttons[slot_index] as Control
			if above != null:
				button.focus_neighbor_top = button.get_path_to(above)
			if below != null:
				button.focus_neighbor_bottom = button.get_path_to(below)


func _compact_setting_row(text_value: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	row.set_meta(&"alveolus_component", &"compact_setting_row")
	var title := AlveolusUIComponents.label(text_value, AlveolusVisualTheme.TYPE_BODY_LABEL)
	title.name = "SettingPurpose"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)
	control.focus_mode = Control.FOCUS_ALL
	control.custom_minimum_size.y = maxf(
		control.custom_minimum_size.y,
		AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	)
	row.add_child(control)
	return row


func _binding_purpose(action_id: StringName, fallback: String) -> String:
	match action_id:
		&"move_up": return "Bewegen · nach oben"
		&"move_down": return "Bewegen · nach unten"
		&"move_left": return "Bewegen · nach links"
		&"move_right": return "Bewegen · nach rechts"
		&"active_ability_1": return "Aktive Fähigkeit 1"
		&"active_ability_2": return "Aktive Fähigkeit 2"
		&"pause_game": return "Pausenmenü öffnen"
		&"upgrade_1": return "Ausbau links wählen"
		&"upgrade_2": return "Ausbau mittig wählen"
		&"upgrade_3": return "Ausbau rechts wählen"
		&"reroll_upgrades": return "Ausbauten neu ziehen"
		&"ui_accept": return "Auswahl bestätigen"
		&"ui_cancel": return "Zurück / schließen"
		&"ui_info": return "Details anzeigen"
	return fallback


func _sync_binding_conflict() -> void:
	if _conflict_layer != null and is_instance_valid(_conflict_layer):
		remove_child(_conflict_layer)
		_conflict_layer.queue_free()
	_conflict_layer = null
	_conflict_modal = null
	_conflict_cancel_button = null
	_conflict_confirm_button = null
	if _view_model == null:
		return
	var conflict := _view_model.get_binding_conflict()
	if conflict == null:
		return

	_conflict_layer = ColorRect.new()
	_conflict_layer.name = "BindingConflictLayer"
	_conflict_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_conflict_layer.color = Color(AlveolusVisualTheme.PETROL_DEEP, 0.86)
	_conflict_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_conflict_layer.z_index = 100
	add_child(_conflict_layer)

	var safe_area := MarginContainer.new()
	safe_area.name = "BindingConflictSafeArea"
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		safe_area.add_theme_constant_override(side, AlveolusVisualTheme.SCREEN_MARGIN_COMPACT)
	_conflict_layer.add_child(safe_area)

	var center := CenterContainer.new()
	center.name = "BindingConflictCenter"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_area.add_child(center)

	var body := AlveolusUIComponents.label(
		"„%s“ ist bereits für „%s“ belegt. Für „%s“ übernehmen?" % [
			conflict.binding_text(),
			conflict.conflicting_action_label(),
			conflict.action_label(),
		],
		AlveolusVisualTheme.TYPE_BODY_LABEL
	)
	body.name = "BindingConflictText"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var actions := GridContainer.new()
	actions.name = "BindingConflictActions"
	actions.columns = 2
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	actions.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	_conflict_cancel_button = AlveolusUIComponents.action_button(
		"Behalten",
		AlveolusUIComponents.ACTION_SECONDARY,
		&"back",
		AlveolusVisualTheme.COBALT
	)
	_conflict_cancel_button.name = "BindingConflictCancel"
	_conflict_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conflict_cancel_button.set_meta(
		&"setting_id",
		_binding_slot_key(conflict.action_id(), conflict.slot_index())
	)
	_conflict_cancel_button.pressed.connect(_on_binding_conflict_decided.bind(conflict, false))
	actions.add_child(_conflict_cancel_button)
	_conflict_confirm_button = AlveolusUIComponents.action_button(
		"Taste übernehmen",
		AlveolusUIComponents.ACTION_PRIMARY,
		&"check",
		AlveolusVisualTheme.TEAL
	)
	_conflict_confirm_button.name = "BindingConflictConfirm"
	_conflict_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conflict_confirm_button.set_meta(
		&"setting_id",
		_binding_slot_key(conflict.action_id(), conflict.slot_index())
	)
	_conflict_confirm_button.pressed.connect(_on_binding_conflict_decided.bind(conflict, true))
	actions.add_child(_conflict_confirm_button)

	var modal_actions: Array[Control] = [actions]
	var modal_parts := AlveolusUIComponents.modal_sheet(
		"Taste bereits belegt",
		body,
		modal_actions,
		20,
		AlveolusVisualTheme.TEAL
	)
	_conflict_modal = modal_parts["panel"] as PanelContainer
	_conflict_modal.name = "BindingConflictModal"
	_conflict_modal.custom_minimum_size.x = 420.0
	_conflict_modal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_conflict_modal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(_conflict_modal)
	_link_binding_conflict_focus()
	_grab_binding_conflict_focus.call_deferred()


func _link_binding_conflict_focus() -> void:
	if _conflict_cancel_button == null or _conflict_confirm_button == null:
		return
	var to_confirm := _conflict_cancel_button.get_path_to(_conflict_confirm_button)
	var to_cancel := _conflict_confirm_button.get_path_to(_conflict_cancel_button)
	_conflict_cancel_button.focus_previous = to_confirm
	_conflict_cancel_button.focus_next = to_confirm
	_conflict_cancel_button.focus_neighbor_left = to_confirm
	_conflict_cancel_button.focus_neighbor_right = to_confirm
	_conflict_confirm_button.focus_previous = to_cancel
	_conflict_confirm_button.focus_next = to_cancel
	_conflict_confirm_button.focus_neighbor_left = to_cancel
	_conflict_confirm_button.focus_neighbor_right = to_cancel


func _grab_binding_conflict_focus() -> void:
	if (
		_conflict_cancel_button != null
		and is_instance_valid(_conflict_cancel_button)
		and _conflict_cancel_button.is_inside_tree()
		and _conflict_cancel_button.is_visible_in_tree()
	):
		_conflict_cancel_button.grab_focus()


func _on_binding_conflict_decided(
	conflict: SettingsScreenViewModel.BindingConflictViewModel,
	replace_existing: bool
) -> void:
	if conflict == null:
		return
	binding_conflict_decided.emit(
		conflict.action_id(),
		conflict.slot_index(),
		conflict.conflicting_action_id(),
		replace_existing
	)


func _on_audio_value_changed(percent_value: float, setting_id: StringName) -> void:
	var slider := control_for_setting(_audio_value_key(setting_id))
	if slider != null:
		slider.set_meta(
			&"alveolus_accessible_name",
			"%s: %d Prozent" % [_audio_setting_label(setting_id), roundi(percent_value)]
		)
	audio_value_changed.emit(setting_id, clampf(percent_value / 100.0, 0.0, 1.0))


func _on_audio_mute_changed(muted: bool, setting_id: StringName) -> void:
	var control := control_for_setting(_audio_mute_key(setting_id))
	if control != null:
		var purpose := str(control.get_meta(&"setting_purpose", "Stumm"))
		control.set_meta(&"alveolus_accessible_name", "%s: %s" % [purpose, "Ein" if muted else "Aus"])
	audio_mute_changed.emit(setting_id, muted)


func _on_option_changed(selected_index: int, setting_id: StringName) -> void:
	option_changed.emit(setting_id, selected_index)


func _on_toggle_changed(enabled: bool, setting_id: StringName, toggle: CheckButton) -> void:
	if toggle != null:
		toggle.text = "Ein" if enabled else "Aus"
		var purpose := str(toggle.get_meta(&"setting_purpose", _toggle_purpose(setting_id, String(setting_id))))
		toggle.set_meta(&"alveolus_accessible_name", "%s: %s" % [purpose, toggle.text])
	toggle_changed.emit(setting_id, enabled)


func _audio_setting_label(setting_id: StringName) -> String:
	if _view_model != null:
		for setting in _view_model.get_audio_settings():
			if setting.get_id() == setting_id:
				return setting.get_label()
	return String(setting_id)


func _on_binding_requested(action_id: StringName, slot_index: int) -> void:
	binding_slot_change_requested.emit(action_id, slot_index)
	if slot_index == 0:
		binding_change_requested.emit(action_id)


func _refresh_responsive_layout() -> void:
	if _safe_area == null:
		return
	var logical_width := size.x
	if logical_width <= 1.0 and get_viewport() != null:
		logical_width = get_viewport().get_visible_rect().size.x
	_compact_layout = logical_width < COMPACT_WIDTH
	if _back_button is IconTextButton:
		(_back_button as IconTextButton).set_caption("" if _compact_layout else "Zurück", true)
		_back_button.set_meta(&"alveolus_accessible_name", "Zurück")
		_back_button.tooltip_text = "Zurück" if _compact_layout else ""
	AlveolusUIComponents.refresh_page_shell_layout(_shell, _compact_layout)
	if _upper_grid != null:
		_upper_grid.columns = 1 if _compact_layout else 2
	if _options_grid != null:
		_options_grid.columns = 2 if logical_width >= TWO_UPPER_CONTROL_COLUMNS_WIDTH else 1
	if _toggles_grid != null:
		_toggles_grid.columns = 2 if logical_width >= TWO_UPPER_CONTROL_COLUMNS_WIDTH else 1
	if _bindings_grid != null:
		_bindings_grid.columns = (
			3
			if logical_width >= THREE_BINDING_COLUMNS_WIDTH
			else (2 if logical_width >= TWO_BINDING_COLUMNS_WIDTH else 1)
		)
	for record in _audio_layout_records:
		var audio_layout := record["layout"] as GridContainer
		var audio_label := record["label"] as Label
		var audio_slider := record["slider"] as HSlider
		var audio_value := record["value"] as Label
		var audio_mute := record["mute"] as CheckButton
		audio_layout.columns = 2 if _compact_layout else 4
		# Compact rows read as label/value followed by a full slider/mute row.
		# Keeping the desktop child order here would give the slider the entire
		# second column and collapse a long German label to only a few letters.
		if _compact_layout:
			audio_layout.move_child(audio_label, 0)
			audio_layout.move_child(audio_value, 1)
			audio_layout.move_child(audio_slider, 2)
			audio_layout.move_child(audio_mute, 3)
		else:
			audio_layout.move_child(audio_label, 0)
			audio_layout.move_child(audio_slider, 1)
			audio_layout.move_child(audio_value, 2)
			audio_layout.move_child(audio_mute, 3)
		audio_label.custom_minimum_size.x = 0.0 if _compact_layout else 132.0
		audio_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if _compact_layout else TextServer.OVERRUN_NO_TRIMMING
		audio_slider.custom_minimum_size.x = 120.0 if _compact_layout else 160.0
		audio_value.custom_minimum_size.x = 48.0
		audio_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		audio_mute.custom_minimum_size.x = 88.0 if _compact_layout else 92.0
	for record in _option_layout_records:
		var option_row := record["row"] as HBoxContainer
		var option_label := record["label"] as Label
		var option := record["control"] as OptionButton
		option_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		option_label.custom_minimum_size.x = OPTION_LABEL_WIDTH
		option.custom_minimum_size.x = 140.0 if _compact_layout else 132.0
	for record in _binding_layout_records:
		var binding_purpose := record["purpose"] as Label
		var binding_slots := record["slots"] as HBoxContainer
		var binding_buttons: Array = record["buttons"] as Array
		binding_purpose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		binding_purpose.custom_minimum_size.x = 0.0
		binding_purpose.clip_text = false
		binding_purpose.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		binding_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for binding_button_value in binding_buttons:
			var binding_button := binding_button_value as Button
			binding_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			binding_button.custom_minimum_size.x = 104.0
	_refresh_focus_neighbors()


func _focused_setting_id() -> StringName:
	if not is_inside_tree():
		return &""
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or not is_ancestor_of(focus_owner):
		return &""
	return StringName(focus_owner.get_meta(&"setting_id", &""))


func _restore_navigation_state(setting_id: StringName, scroll_position: int, revision: int) -> void:
	_pending_restore_setting_id = setting_id
	_pending_restore_scroll = scroll_position
	_pending_restore_revision = revision
	if not is_inside_tree():
		return
	if _navigation_restore_scheduled:
		return
	_navigation_restore_scheduled = true
	get_tree().process_frame.connect(
		_restore_navigation_scroll,
		CONNECT_ONE_SHOT
	)


func _restore_navigation_scroll() -> void:
	_navigation_restore_scheduled = false
	if not is_inside_tree() or _pending_restore_revision != _applied_revision:
		return
	if is_binding_conflict_open():
		_grab_binding_conflict_focus.call_deferred()
		return
	_scroll.scroll_vertical = _pending_restore_scroll
	_restore_navigation_focus.call_deferred(_pending_restore_setting_id, _pending_restore_revision)


func _restore_navigation_focus(setting_id: StringName, revision: int) -> void:
	if not is_inside_tree() or revision != _applied_revision or setting_id == &"" or is_binding_conflict_open():
		return
	var control := control_for_setting(setting_id)
	if control != null and control.is_visible_in_tree():
		control.grab_focus()


func _audio_value_key(setting_id: StringName) -> StringName:
	return StringName("audio.%s.value" % String(setting_id))


func _audio_mute_key(setting_id: StringName) -> StringName:
	return StringName("audio.%s.mute" % String(setting_id))


func _option_key(setting_id: StringName) -> StringName:
	return StringName("option.%s" % String(setting_id))


func _toggle_key(setting_id: StringName) -> StringName:
	return StringName("toggle.%s" % String(setting_id))


func _binding_key(action_id: StringName) -> StringName:
	return StringName("binding.%s" % String(action_id))


func _binding_slot_key(action_id: StringName, slot_index: int) -> StringName:
	return StringName("binding.%s.%d" % [String(action_id), slot_index])
