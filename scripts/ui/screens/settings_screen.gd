class_name SettingsScreen
extends Control

signal audio_value_changed(setting_id: StringName, linear_value: float)
signal audio_mute_changed(setting_id: StringName, muted: bool)
signal option_changed(setting_id: StringName, selected_index: int)
signal toggle_changed(setting_id: StringName, enabled: bool)
signal binding_change_requested(action_id: StringName)
signal bindings_reset_requested
signal quit_requested
signal back

const COMPACT_WIDTH := 760.0
const TWO_BINDING_COLUMNS_WIDTH := 920.0

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
var _toggles_grid: GridContainer
var _bindings_grid: GridContainer
var _back_button: Button
var _controls: Dictionary = {}
var _audio_layout_records: Array[Dictionary] = []
var _option_controls: Array[OptionButton] = []
var _binding_layout_records: Array[Dictionary] = []
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
	_audio_layout_records.clear()
	_option_controls.clear()
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
	for setting in _view_model.get_option_settings():
		if setting.is_visible():
			_build_option_row(display_content, setting)
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
		"Aktion links · aktuelle Belegung rechts",
		AlveolusVisualTheme.TYPE_MUTED_LABEL
	)
	bindings_explanation.name = "BindingsExplanation"
	bindings_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_content.add_child(bindings_explanation)
	_bindings_grid = GridContainer.new()
	_bindings_grid.name = "BindingsGrid"
	_bindings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bindings_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTENT_GAP)
	_bindings_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
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
	reset_button.pressed.connect(func() -> void: bindings_reset_requested.emit())
	_controls[&"bindings.reset"] = reset_button
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
	actions.visible = _view_model.should_show_quit()
	var quit_button := AlveolusUIComponents.action_button(
		"Spiel beenden",
		AlveolusUIComponents.ACTION_DANGER,
		&"",
		AlveolusVisualTheme.CORAL
	)
	quit_button.name = "QuitButton"
	quit_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	quit_button.set_meta(&"setting_id", &"quit")
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	_controls[&"quit"] = quit_button
	actions.add_child(quit_button)
	controls_content.add_child(actions)

	_refresh_responsive_layout()


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
	mute.custom_minimum_size.x = 92.0
	slider.value_changed.connect(_on_audio_value_changed.bind(setting.get_id()))
	mute.toggled.connect(_on_audio_mute_changed.bind(setting.get_id()))
	_controls[value_key] = slider
	_controls[mute_key] = mute
	parent.add_child(layout)
	_audio_layout_records.append({
		"layout": layout,
		"label": title,
		"slider": slider,
		"value": value_label,
		"mute": mute,
	})


func _build_option_row(parent: VBoxContainer, setting: SettingsScreenViewModel.OptionSettingViewModel) -> void:
	var parts := AlveolusUIComponents.option_row(setting.get_label(), setting.get_entries(), setting.get_selected_index())
	var row := parts["row"] as HBoxContainer
	var title := parts["label"] as Label
	var control := parts["control"] as OptionButton
	row.name = "OptionLayout_%s" % String(setting.get_id())
	row.custom_minimum_size.y = AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	row.set_meta(&"alveolus_component", &"compact_setting_row")
	title.name = "SettingPurpose"
	var key := _option_key(setting.get_id())
	control.name = "Option_%s" % String(setting.get_id())
	control.set_meta(&"setting_id", key)
	control.item_selected.connect(_on_option_changed.bind(setting.get_id()))
	_controls[key] = control
	_option_controls.append(control)
	parent.add_child(row)


func _build_toggle_row(parent: Container, setting: SettingsScreenViewModel.ToggleSettingViewModel) -> void:
	var toggle := AlveolusUIComponents.toggle_row("Ein" if setting.is_enabled() else "Aus", setting.is_enabled())
	var key := _toggle_key(setting.get_id())
	toggle.name = "Toggle_%s" % String(setting.get_id())
	toggle.set_meta(&"setting_id", key)
	toggle.custom_minimum_size.x = 80.0
	toggle.toggled.connect(_on_toggle_changed.bind(setting.get_id(), toggle))
	var visible_label := _toggle_purpose(setting.get_id(), setting.get_label())
	var row := _compact_setting_row(visible_label, toggle)
	row.name = "ToggleLayout_%s" % String(setting.get_id())
	_controls[key] = toggle
	parent.add_child(row)


func _toggle_purpose(setting_id: StringName, fallback: String) -> String:
	match setting_id:
		&"reduce_motion":
			return "Weniger Bewegung"
		&"run_stats":
			return "Werte im Run"
		&"fullscreen":
			return "Vollbild"
		&"confirm_restart":
			return "Strg+R bestätigen"
	return fallback


func _build_binding_row(setting: SettingsScreenViewModel.BindingSettingViewModel) -> void:
	var caption := "Taste drücken …" if setting.is_capturing() else setting.get_binding_text()
	var purpose := _binding_purpose(setting.get_action_id(), setting.get_label())
	var button := AlveolusUIComponents.action_button(
		caption,
		AlveolusUIComponents.ACTION_SECONDARY,
		&"",
		AlveolusVisualTheme.COBALT
	)
	var key := _binding_key(setting.get_action_id())
	button.name = "Binding_%s" % String(setting.get_action_id())
	button.set_meta(&"setting_id", key)
	button.set_meta(&"action_id", setting.get_action_id())
	button.set_meta(&"alveolus_accessible_name", "%s: %s" % [purpose, caption])
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = caption
	button.pressed.connect(_on_binding_requested.bind(setting.get_action_id()))
	var row := _compact_setting_row(purpose, button)
	row.name = "BindingLayout_%s" % String(setting.get_action_id())
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var purpose_label := row.find_child("SettingPurpose", true, false) as Label
	var card := AlveolusUIComponents.surface(
		AlveolusVisualTheme.SurfaceRole.VALUE_ROW,
		AlveolusVisualTheme.COBALT
	)
	card.name = "BindingCard_%s" % String(setting.get_action_id())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = AlveolusVisualTheme.TOUCH_TARGET_MINIMUM + 12.0
	card.set_meta(&"alveolus_component", &"shortcut_container")
	card.add_child(AlveolusUIComponents.margin(row, 6))
	_controls[key] = button
	_binding_layout_records.append({
		"card": card,
		"row": row,
		"purpose": purpose_label,
		"button": button,
	})
	_bindings_grid.add_child(card)


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
		&"ui_accept": return "Auswahl bestätigen"
		&"ui_cancel": return "Zurück / schließen"
		&"ui_info": return "Details anzeigen"
	return fallback


func _on_audio_value_changed(percent_value: float, setting_id: StringName) -> void:
	audio_value_changed.emit(setting_id, clampf(percent_value / 100.0, 0.0, 1.0))


func _on_audio_mute_changed(muted: bool, setting_id: StringName) -> void:
	audio_mute_changed.emit(setting_id, muted)


func _on_option_changed(selected_index: int, setting_id: StringName) -> void:
	option_changed.emit(setting_id, selected_index)


func _on_toggle_changed(enabled: bool, setting_id: StringName, toggle: CheckButton) -> void:
	if toggle != null:
		toggle.text = "Ein" if enabled else "Aus"
	toggle_changed.emit(setting_id, enabled)


func _on_binding_requested(action_id: StringName) -> void:
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
	if _toggles_grid != null:
		_toggles_grid.columns = 1 if _compact_layout else 2
	if _bindings_grid != null:
		_bindings_grid.columns = 1 if logical_width < TWO_BINDING_COLUMNS_WIDTH else 2
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
	for option in _option_controls:
		option.custom_minimum_size.x = 148.0 if _compact_layout else 176.0
	for record in _binding_layout_records:
		var binding_purpose := record["purpose"] as Label
		var binding_button := record["button"] as Button
		# Each shortcut is a compact two-part unit. Fixed local columns keep the
		# action and its binding visually adjacent instead of pushing the binding
		# to the remote edge of a wide settings section.
		binding_purpose.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		binding_purpose.custom_minimum_size.x = 124.0 if _compact_layout else 176.0
		binding_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		binding_button.custom_minimum_size.x = 156.0 if _compact_layout else 210.0


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
	_scroll.scroll_vertical = _pending_restore_scroll
	_restore_navigation_focus.call_deferred(_pending_restore_setting_id, _pending_restore_revision)


func _restore_navigation_focus(setting_id: StringName, revision: int) -> void:
	if not is_inside_tree() or revision != _applied_revision or setting_id == &"":
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
