extends SceneTree

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var host := _create_logical_host(Vector2i(1280, 720))
	var source_audio := _audio_fixture()
	var source_options := _option_fixture()
	var source_toggles := _toggle_fixture()
	var source_bindings := _binding_fixture()
	var view_model := SettingsScreenViewModel.new(
		1, source_audio, source_options, source_toggles, source_bindings, "", true
	)
	var original_hash := view_model.get_content_hash()
	source_audio.clear()
	source_options[0].get_entries().clear()
	source_bindings.clear()
	_check(view_model.get_audio_settings().size() == 4, "Audio-View-Models werden tief kopiert")
	_check(view_model.get_option_settings()[0].get_entries().size() == 6, "Optionslisten geben keine interne Collection frei")
	_check(view_model.get_binding_settings().size() == 10, "Binding-View-Models werden tief kopiert")
	_check(view_model.get_content_hash() == original_hash, "Externe Mutationen verändern den Content-Hash nicht")

	var screen := SettingsScreen.new()
	screen.theme = AlveolusVisualTheme.create_theme()
	host.add_child(screen)
	await process_frame
	_check(screen.apply(view_model), "Erste Settings-Revision wird angewendet")
	await _settle()
	_check(screen.get_applied_revision() == 1 and screen.get_applied_content_hash() == original_hash, "Screen speichert Revision und Content-Hash")
	_check(not screen.apply(view_model.duplicate_immutable()), "Identische Settings werden idempotent nicht neu aufgebaut")
	_check(screen.get_node_or_null("PageShell") != null, "Settings verwenden den zentralen PageShell")
	_check(screen.get_node("PageShell").get_meta(&"alveolus_component", &"") == &"page_shell", "PageShell stammt aus AlveolusUIComponents")
	_check(screen.get_scroll_container().follow_focus, "Settings-Scrollfläche folgt Tastatur- und Gamepadfokus")
	_check(screen.get_scroll_container().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Settings benötigen keinen horizontalen Scrollbereich")
	_check(screen.get_upper_column_count() == 2, "Audio und Anzeige stehen auf breiten Ansichten in zwei Spalten")
	_check(screen.get_binding_column_count() == 2, "Steuerungszeilen nutzen auf breiten Ansichten zwei Spalten")
	var wide_toggles := screen.find_child("DisplayTogglesGrid", true, false) as GridContainer
	_check(wide_toggles != null and wide_toggles.columns == 2, "Anzeige ordnet vier Schalter platzsparend in zwei Spalten an")
	_check(screen.control_for_setting(&"binding.ui_info") != null, "ui_info erscheint als reguläre, zugängliche Binding-Zeile")
	_assert_sections_are_content_driven(screen)
	_assert_compact_labeled_rows(screen)
	_assert_intents(screen)

	_resize_logical_host(host, Vector2i(480, 270))
	await _settle()
	_check(screen.is_compact_layout(), "480 logische Pixel bilden die 200-Prozent-Kompaktstruktur ab")
	_check(screen.get_upper_column_count() == 1, "Audio und Anzeige stapeln bei 200 Prozent einspaltig")
	_check(screen.get_binding_column_count() == 1, "Steuerung stapelt bei 200 Prozent einspaltig")
	var compact_toggles := screen.find_child("DisplayTogglesGrid", true, false) as GridContainer
	_check(compact_toggles != null and compact_toggles.columns == 1, "Anzeigeschalter bleiben bei 200 Prozent einspaltig lesbar")
	_check(screen.get_scroll_container().get_v_scroll_bar().max_value > screen.get_scroll_container().size.y, "Kompakte Settings zeigen ihren notwendigen vertikalen Scrollpfad")
	var page_shell := screen.get_node_or_null("PageShell") as Control
	var back_button := screen.find_child("BackButton", true, false) as Control
	var first_audio_row := screen.find_child("AudioLayout_master", true, false) as Control
	_check(page_shell != null and _fully_inside(page_shell, host), "Settings-PageShell bleibt im echten logischen 480-mal-270-Host")
	_check(back_button != null and _fully_inside(back_button, host), "Kompakter Zurück-Button bleibt vollständig im Host")
	_check(screen.get_scroll_container() != null and _fully_inside(screen.get_scroll_container(), host), "Settings-Scrollfläche bleibt vollständig im Host")
	_check(first_audio_row != null and _fully_inside(first_audio_row, host), "Erste kompakte Audiozeile ist beim Öffnen vollständig enthalten")
	_check(first_audio_row != null and _visible_children_inside(first_audio_row), "Label, Wert, Slider und Stummschalter bleiben in der ersten Audiozeile")
	_check(screen.get_scroll_container().scroll_vertical == 0, "Kompakte Settings öffnen am oberen Scrollanfang")

	var info_binding := screen.control_for_setting(&"binding.ui_info") as Button
	info_binding.grab_focus()
	await process_frame
	screen.get_scroll_container().scroll_vertical = 120
	await process_frame
	var updated_model := SettingsScreenViewModel.new(
		2, _audio_fixture(0.55), _option_fixture(), _toggle_fixture(), _binding_fixture(), "Belegung aktualisiert.", true
	)
	_check(screen.apply(updated_model), "Neue Settings-Revision aktualisiert den Screen")
	await _settle()
	var restored_focus := get_root().gui_get_focus_owner()
	_check(restored_focus == screen.control_for_setting(&"binding.ui_info"), "Apply stellt Fokus anhand der semantischen Setting-ID wieder her")
	_check(screen.get_scroll_container().scroll_vertical > 0, "Apply bewahrt die vorherige Scrollposition soweit möglich")

	_assert_dependency_contract()
	host.queue_free()
	await process_frame
	_finish()


func _assert_intents(screen: SettingsScreen) -> void:
	var audio_values: Array = []
	var audio_mutes: Array = []
	var options: Array = []
	var toggles: Array = []
	var bindings: Array[StringName] = []
	var reset_count := [0]
	var quit_count := [0]
	var back_count := [0]
	screen.audio_value_changed.connect(func(id: StringName, value: float) -> void: audio_values.append([id, value]))
	screen.audio_mute_changed.connect(func(id: StringName, muted: bool) -> void: audio_mutes.append([id, muted]))
	screen.option_changed.connect(func(id: StringName, index: int) -> void: options.append([id, index]))
	screen.toggle_changed.connect(func(id: StringName, enabled: bool) -> void: toggles.append([id, enabled]))
	screen.binding_change_requested.connect(func(id: StringName) -> void: bindings.append(id))
	screen.bindings_reset_requested.connect(func() -> void: reset_count[0] += 1)
	screen.quit_requested.connect(func() -> void: quit_count[0] += 1)
	screen.back.connect(func() -> void: back_count[0] += 1)

	(screen.control_for_setting(&"audio.master.value") as HSlider).value = 42.0
	(screen.control_for_setting(&"audio.master.mute") as CheckButton).toggled.emit(true)
	(screen.control_for_setting(&"option.ui_scale") as OptionButton).item_selected.emit(3)
	(screen.control_for_setting(&"toggle.reduce_motion") as CheckButton).toggled.emit(true)
	(screen.control_for_setting(&"binding.ui_info") as Button).pressed.emit()
	(screen.control_for_setting(&"bindings.reset") as Button).pressed.emit()
	(screen.control_for_setting(&"quit") as Button).pressed.emit()
	(screen.control_for_setting(&"back") as Button).pressed.emit()

	_check(audio_values.size() == 1 and audio_values[0][0] == &"master" and is_equal_approx(audio_values[0][1], 0.42), "Lautstärke emittiert ID und linearen Wert")
	_check(audio_mutes == [[&"master", true]], "Stummschaltung emittiert einen typisierten Intent")
	_check(options == [[&"ui_scale", 3]], "Option emittiert ID und Index")
	_check(toggles == [[&"reduce_motion", true]], "Schalter emittiert ID und Zustand")
	_check(bindings == [&"ui_info"], "Binding-Intent enthält ausschließlich die Aktions-ID")
	_check(reset_count[0] == 1 and quit_count[0] == 1 and back_count[0] == 1, "Reset, Beenden und Zurück bleiben getrennte Intents")


func _assert_sections_are_content_driven(screen: SettingsScreen) -> void:
	for section_name in ["AudioSection", "DisplaySection", "ControlsSection"]:
		var section := screen.find_child(section_name, true, false) as PanelContainer
		_check(section != null, "%s ist vorhanden" % section_name)
		if section != null:
			_check(not section.clip_contents, "%s schneidet Inhalt nicht an einer festen Höhe ab" % section_name)
			_check(section.custom_minimum_size.y <= 0.0, "%s reserviert keinen dekorativen Leerraum" % section_name)


func _assert_compact_labeled_rows(screen: SettingsScreen) -> void:
	var explanation := screen.find_child("BindingsExplanation", true, false) as Label
	_check(explanation != null and explanation.text.contains("Aktion") and explanation.text.contains("Belegung"), "Steuerung benennt die sichtbaren Spalten Aktion und Belegung")
	for row_name in [
		"OptionLayout_ui_scale",
		"ToggleLayout_reduce_motion",
		"ToggleLayout_confirm_restart",
		"BindingLayout_move_up",
		"BindingLayout_ui_info",
	]:
		var row := screen.find_child(row_name, true, false) as HBoxContainer
		_check(row != null, "%s ist als kompakte Einstellungszeile vorhanden" % row_name)
		if row == null:
			continue
		_check(row.get_meta(&"alveolus_component", &"") == &"compact_setting_row", "%s nutzt die zentrale kompakte Zeilenstruktur" % row_name)
		_check(row.custom_minimum_size.y == AlveolusVisualTheme.TOUCH_TARGET_MINIMUM, "%s bleibt genau eine kompakte Trefferzeile hoch" % row_name)
		var purpose := row.find_child("SettingPurpose", true, false) as Label
		_check(purpose != null and not purpose.text.strip_edges().is_empty(), "%s nennt seinen Zweck sichtbar" % row_name)
	var restart_row := screen.find_child("ToggleLayout_confirm_restart", true, false) as HBoxContainer
	var restart_purpose: Label = restart_row.find_child("SettingPurpose", true, false) as Label if restart_row != null else null
	_check(restart_purpose != null and restart_purpose.text == "Strg+R bestätigen", "Neustartoption erklärt den festen Shortcut direkt in ihrer Zeile")
	var compact_toggle_labels := {
		&"reduce_motion": "Weniger Bewegung",
		&"run_stats": "Werte im Run",
		&"fullscreen": "Vollbild",
	}
	for setting_id: StringName in compact_toggle_labels:
		var toggle_row := screen.find_child("ToggleLayout_%s" % String(setting_id), true, false) as HBoxContainer
		var toggle_purpose: Label = toggle_row.find_child("SettingPurpose", true, false) as Label if toggle_row != null else null
		_check(toggle_purpose != null and toggle_purpose.text == compact_toggle_labels[setting_id], "%s bleibt in der zweispaltigen Anzeige vollständig lesbar" % setting_id)
	var binding_row := screen.find_child("BindingLayout_ui_info", true, false) as HBoxContainer
	_check(binding_row != null and binding_row.get_child_count() == 2, "Tastenbelegung besteht nur aus Zweck und kompakter Aktion")
	var binding_purpose := binding_row.find_child("SettingPurpose", true, false) as Label if binding_row != null else null
	_check(binding_purpose != null and binding_purpose.text == "Details anzeigen", "ui_info benennt seinen Spielerzweck statt nur die interne Aktion")
	for action_id in [
		"move_up", "move_down", "move_left", "move_right", "active_ability_1",
		"active_ability_2", "pause_game", "ui_accept", "ui_cancel", "ui_info",
	]:
		var shortcut_card := screen.find_child("BindingCard_%s" % action_id, true, false) as PanelContainer
		_check(shortcut_card != null, "%s besitzt einen eigenen kompakten Bio-Lumen-Container" % action_id)
	var binding_card := screen.find_child("BindingCard_ui_info", true, false) as PanelContainer
	if binding_card != null:
		_check(binding_card.get_meta(&"alveolus_component", &"") == &"shortcut_container", "Shortcut-Container ist semantisch als gemeinsame Einstellungsstruktur markiert")
		_check(binding_card.get_meta(&"alveolus_surface_role", -1) == AlveolusVisualTheme.SurfaceRole.VALUE_ROW, "Shortcut-Container verwendet die zentrale ValueRow-Fläche")
	var binding_button := screen.control_for_setting(&"binding.ui_info") as Button
	if binding_purpose != null and binding_button != null:
		_check(binding_purpose.custom_minimum_size.x <= 176.0 and binding_button.custom_minimum_size.x <= 210.0, "Beschreibung und Belegung bleiben in der Containerzeile direkt benachbart")


func _assert_dependency_contract() -> void:
	for path in [
		"res://scripts/ui/screens/settings_screen.gd",
		"res://scripts/ui/view_models/settings_screen_view_model.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		for forbidden in ["ContentCatalog", "MetaProgressionState", "PlayerStats", "RunState", "UISettingsState", "InputMap", "AudioServer", "DisplayServer", "add_theme_stylebox_override", "ShaderMaterial", "func _process", "func _physics_process"]:
			_check(not source.contains(forbidden), "%s bleibt frei von %s" % [path, forbidden])


func _audio_fixture(master_value: float = 0.80) -> Array[SettingsScreenViewModel.AudioSettingViewModel]:
	var result: Array[SettingsScreenViewModel.AudioSettingViewModel] = []
	result.append(SettingsScreenViewModel.AudioSettingViewModel.new(&"master", "Gesamtlautstärke", master_value, false))
	result.append(SettingsScreenViewModel.AudioSettingViewModel.new(&"ui", "Menü", 0.65, false))
	result.append(SettingsScreenViewModel.AudioSettingViewModel.new(&"effects", "Effekte", 0.80, false))
	result.append(SettingsScreenViewModel.AudioSettingViewModel.new(&"music", "Musik", 0.80, true))
	return result


func _option_fixture() -> Array[SettingsScreenViewModel.OptionSettingViewModel]:
	var scales: Array[String] = ["75 %", "90 %", "100 %", "125 %", "150 %", "200 %"]
	var glyphs: Array[String] = ["Automatisch", "Tastatur", "Gamepad"]
	var result: Array[SettingsScreenViewModel.OptionSettingViewModel] = []
	result.append(SettingsScreenViewModel.OptionSettingViewModel.new(&"ui_scale", "UI-Größe", scales, 2))
	result.append(SettingsScreenViewModel.OptionSettingViewModel.new(&"glyph_mode", "Eingabesymbole", glyphs, 0))
	return result


func _toggle_fixture() -> Array[SettingsScreenViewModel.ToggleSettingViewModel]:
	var result: Array[SettingsScreenViewModel.ToggleSettingViewModel] = []
	result.append(SettingsScreenViewModel.ToggleSettingViewModel.new(&"reduce_motion", "Bewegung reduzieren", false))
	result.append(SettingsScreenViewModel.ToggleSettingViewModel.new(&"run_stats", "Charakterwerte im Run", true))
	result.append(SettingsScreenViewModel.ToggleSettingViewModel.new(&"fullscreen", "Vollbild", false))
	result.append(SettingsScreenViewModel.ToggleSettingViewModel.new(&"confirm_restart", "Neustart bestätigen", true))
	return result


func _binding_fixture() -> Array[SettingsScreenViewModel.BindingSettingViewModel]:
	var result: Array[SettingsScreenViewModel.BindingSettingViewModel] = []
	for entry in [
		[&"move_up", "Nach oben", "W / ↑ · D-Pad ↑"],
		[&"move_down", "Nach unten", "S / ↓ · D-Pad ↓"],
		[&"move_left", "Nach links", "A / ← · D-Pad ←"],
		[&"move_right", "Nach rechts", "D / → · D-Pad →"],
		[&"active_ability_1", "Fähigkeit 1", "Q · LB"],
		[&"active_ability_2", "Fähigkeit 2", "E · RB"],
		[&"pause_game", "Pause", "Esc · Menü"],
		[&"ui_accept", "Bestätigen", "Enter · A"],
		[&"ui_cancel", "Zurück", "Esc · B"],
		[&"ui_info", "Informationen", "I · Y"],
	]:
		result.append(SettingsScreenViewModel.BindingSettingViewModel.new(entry[0], entry[1], entry[2]))
	return result


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _create_logical_host(logical_size: Vector2i) -> Control:
	var host := Control.new()
	host.name = "LogicalViewportHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size = Vector2(logical_size)
	get_root().add_child(host)
	return host


func _resize_logical_host(host: Control, logical_size: Vector2i) -> void:
	host.size = Vector2(logical_size)


func _fully_inside(control: Control, container: Control, tolerance: float = 0.5) -> bool:
	if control == null or container == null:
		return false
	var rect := control.get_global_rect()
	var bounds := container.get_global_rect()
	return rect.position.x >= bounds.position.x - tolerance \
		and rect.position.y >= bounds.position.y - tolerance \
		and rect.end.x <= bounds.end.x + tolerance \
		and rect.end.y <= bounds.end.y + tolerance


func _visible_children_inside(container: Control, tolerance: float = 0.5) -> bool:
	if container == null:
		return false
	var bounds := container.get_global_rect()
	for child in container.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		var rect := control.get_global_rect()
		if rect.position.x < bounds.position.x - tolerance \
			or rect.position.y < bounds.position.y - tolerance \
			or rect.end.x > bounds.end.x + tolerance \
			or rect.end.y > bounds.end.y + tolerance:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SETTINGS_SCREEN_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("SETTINGS_SCREEN_MODULE_FAILED assertions=%d failures=%d" % [assertions, failures.size()])
	quit(1)
