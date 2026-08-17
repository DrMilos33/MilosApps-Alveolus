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
	_check(view_model.get_binding_settings().size() == 14, "Alle Spielaktionen werden als Binding-View-Models tief kopiert")
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
	_check(screen.get_binding_column_count() == 3, "Steuerungszeilen nutzen auf breiten Ansichten drei kompakte Spalten")
	var wide_options := screen.find_child("DisplayOptionsGrid", true, false) as GridContainer
	_check(wide_options != null and wide_options.columns == 2, "UI-Größe und Eingabemodus stehen kompakt nebeneinander")
	var wide_toggles := screen.find_child("DisplayTogglesGrid", true, false) as GridContainer
	_check(wide_toggles != null and wide_toggles.columns == 2, "Anzeige ordnet vier Schalter platzsparend in zwei Spalten an")
	_check(screen.control_for_setting(&"binding.ui_info.0") != null, "ui_info besitzt einen zugänglichen ersten Tastaturplatz")
	_check(screen.control_for_setting(&"binding.ui_info.1") != null, "ui_info besitzt einen zugänglichen zweiten Tastaturplatz")
	_assert_sections_are_content_driven(screen)
	_assert_compact_labeled_rows(screen)
	_assert_intents(screen)
	_resize_logical_host(host, Vector2i(960, 540))
	await _settle()
	_check(screen.get_binding_column_count() == 2, "Steuerung wechselt auf mittlerer Breite responsiv zu zwei Spalten")
	_resize_logical_host(host, Vector2i(1280, 720))
	await _settle()
	_check(screen.get_binding_column_count() == 3, "Steuerung kehrt auf Desktopbreite zu drei Spalten zurück")
	await _assert_conflict_modal(screen)

	_resize_logical_host(host, Vector2i(480, 270))
	await _settle()
	_check(screen.is_compact_layout(), "480 logische Pixel bilden die 200-Prozent-Kompaktstruktur ab")
	_check(screen.get_upper_column_count() == 1, "Audio und Anzeige stapeln bei 200 Prozent einspaltig")
	_check(screen.get_binding_column_count() == 1, "Steuerung stapelt bei 200 Prozent einspaltig")
	var compact_options := screen.find_child("DisplayOptionsGrid", true, false) as GridContainer
	_check(compact_options != null and compact_options.columns == 1, "Anzeigeoptionen stapeln bei 200 Prozent einspaltig")
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

	var info_binding := screen.control_for_setting(&"binding.ui_info.1") as Button
	info_binding.grab_focus()
	await process_frame
	screen.get_scroll_container().scroll_vertical = 120
	await process_frame
	var updated_model := SettingsScreenViewModel.new(
		4, _audio_fixture(0.55), _option_fixture(), _toggle_fixture(), _binding_fixture(), "Belegung aktualisiert.", true
	)
	_check(screen.apply(updated_model), "Neue Settings-Revision aktualisiert den Screen")
	await _settle()
	var restored_focus := get_root().gui_get_focus_owner()
	_check(restored_focus == screen.control_for_setting(&"binding.ui_info.1"), "Apply stellt Fokus bis auf den konkreten Tastaturplatz wieder her")
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
	var bindings: Array = []
	var legacy_bindings: Array[StringName] = []
	var reset_count := [0]
	var quit_count := [0]
	var back_count := [0]
	screen.audio_value_changed.connect(func(id: StringName, value: float) -> void: audio_values.append([id, value]))
	screen.audio_mute_changed.connect(func(id: StringName, muted: bool) -> void: audio_mutes.append([id, muted]))
	screen.option_changed.connect(func(id: StringName, index: int) -> void: options.append([id, index]))
	screen.toggle_changed.connect(func(id: StringName, enabled: bool) -> void: toggles.append([id, enabled]))
	screen.binding_slot_change_requested.connect(func(id: StringName, slot_index: int) -> void: bindings.append([id, slot_index]))
	screen.binding_change_requested.connect(func(id: StringName) -> void: legacy_bindings.append(id))
	screen.bindings_reset_requested.connect(func() -> void: reset_count[0] += 1)
	screen.quit_requested.connect(func() -> void: quit_count[0] += 1)
	screen.back.connect(func() -> void: back_count[0] += 1)

	(screen.control_for_setting(&"audio.master.value") as HSlider).value = 42.0
	(screen.control_for_setting(&"audio.master.mute") as CheckButton).toggled.emit(true)
	(screen.control_for_setting(&"option.ui_scale") as OptionButton).item_selected.emit(3)
	(screen.control_for_setting(&"toggle.reduce_motion") as CheckButton).toggled.emit(true)
	(screen.control_for_setting(&"binding.ui_info.1") as Button).pressed.emit()
	(screen.control_for_setting(&"binding.ui_info.0") as Button).pressed.emit()
	(screen.control_for_setting(&"bindings.reset") as Button).pressed.emit()
	(screen.control_for_setting(&"quit") as Button).pressed.emit()
	(screen.control_for_setting(&"back") as Button).pressed.emit()

	_check(audio_values.size() == 1 and audio_values[0][0] == &"master" and is_equal_approx(audio_values[0][1], 0.42), "Lautstärke emittiert ID und linearen Wert")
	_check(audio_mutes == [[&"master", true]], "Stummschaltung emittiert einen typisierten Intent")
	_check(options == [[&"ui_scale", 3]], "Option emittiert ID und Index")
	_check(toggles == [[&"reduce_motion", true]], "Schalter emittiert ID und Zustand")
	_check(bindings == [[&"ui_info", 1], [&"ui_info", 0]], "Binding-Intent enthält Aktion und den ausdrücklich gewählten Tastaturplatz")
	_check(legacy_bindings == [&"ui_info"], "Der erste Tastaturplatz emittiert weiterhin den kompatiblen Ein-Slot-Intent")
	_check(reset_count[0] == 1 and quit_count[0] == 1 and back_count[0] == 1, "Reset, Beenden und Zurück bleiben getrennte Intents")


func _assert_conflict_modal(screen: SettingsScreen) -> void:
	var conflict := SettingsScreenViewModel.BindingConflictViewModel.new(
		&"active_ability_1",
		1,
		"Aktive Fähigkeit 1",
		&"move_down",
		"Bewegen · nach unten",
		"S"
	)
	var conflict_model := SettingsScreenViewModel.new(
		2,
		_audio_fixture(),
		_option_fixture(),
		_toggle_fixture(),
		_binding_fixture(),
		"",
		true,
		conflict
	)
	_check(screen.apply(conflict_model), "Ein Bindingkonflikt aktualisiert die Settings-Ansicht")
	await _settle()
	_check(screen.is_binding_conflict_open(), "Eine bereits verwendete Taste öffnet eine ausdrückliche Bestätigung")
	var modal := screen.find_child("BindingConflictModal", true, false) as PanelContainer
	_check(modal != null and modal.get_meta(&"alveolus_component", &"") == &"modal_sheet", "Bindingkonflikt verwendet den zentralen ModalSheet")
	var conflict_text := screen.find_child("BindingConflictText", true, false) as Label
	_check(conflict_text != null and conflict_text.text.contains("S") and conflict_text.text.contains("Bewegen · nach unten"), "Popup nennt Taste und bestehende Aktion")
	_check(screen.get_binding_conflict_default_focus_control() == screen.find_child("BindingConflictCancel", true, false), "Die sichere Behalten-Aktion erhält den Standardfokus")
	_check(get_root().gui_get_focus_owner() == screen.get_binding_conflict_default_focus_control(), "Der verzögerte Navigations-Restore stiehlt dem Konfliktmodal keinen Fokus")
	var decisions: Array = []
	screen.binding_conflict_decided.connect(func(action: StringName, slot: int, other: StringName, replace_existing: bool) -> void:
		decisions.append([action, slot, other, replace_existing])
	)
	(screen.find_child("BindingConflictConfirm", true, false) as Button).pressed.emit()
	_check(decisions == [[&"active_ability_1", 1, &"move_down", true]], "Popup emittiert eine explizite bestätigte Konfliktentscheidung")

	var cleared_model := SettingsScreenViewModel.new(
		3, _audio_fixture(), _option_fixture(), _toggle_fixture(), _binding_fixture(), "Taste übernommen.", true
	)
	_check(screen.apply(cleared_model), "Aufgelöster Bindingkonflikt aktualisiert die Ansicht")
	await _settle()
	_check(not screen.is_binding_conflict_open(), "Bestätigung verschwindet erst nach dem aktualisierten View-Model")
	_check(get_root().gui_get_focus_owner() == screen.control_for_setting(&"binding.active_ability_1.1"), "Nach dem Popup kehrt der Fokus zum konkreten Tastaturplatz zurück")


func _assert_sections_are_content_driven(screen: SettingsScreen) -> void:
	for section_name in ["AudioSection", "DisplaySection", "ControlsSection"]:
		var section := screen.find_child(section_name, true, false) as PanelContainer
		_check(section != null, "%s ist vorhanden" % section_name)
		if section != null:
			_check(not section.clip_contents, "%s schneidet Inhalt nicht an einer festen Höhe ab" % section_name)
			_check(section.custom_minimum_size.y <= 0.0, "%s reserviert keinen dekorativen Leerraum" % section_name)


func _assert_compact_labeled_rows(screen: SettingsScreen) -> void:
	var explanation := screen.find_child("BindingsExplanation", true, false) as Label
	_check(explanation != null and explanation.text.contains("zwei") and explanation.text.contains("Tastatur"), "Steuerung erklärt die zwei sichtbaren Tastaturplätze ohne Controllertext")
	for row_name in [
		"OptionLayout_ui_scale",
		"ToggleLayout_reduce_motion",
		"ToggleLayout_confirm_restart",
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
		&"reduce_motion": "Animationen reduzieren",
		&"run_stats": "Werte im Run",
		&"fullscreen": "Vollbild",
	}
	for setting_id: StringName in compact_toggle_labels:
		var toggle_row := screen.find_child("ToggleLayout_%s" % String(setting_id), true, false) as HBoxContainer
		var toggle_purpose: Label = toggle_row.find_child("SettingPurpose", true, false) as Label if toggle_row != null else null
		_check(toggle_purpose != null and toggle_purpose.text == compact_toggle_labels[setting_id], "%s bleibt in der zweispaltigen Anzeige vollständig lesbar" % setting_id)
	var options_grid := screen.find_child("DisplayOptionsGrid", true, false) as GridContainer
	for option_id in [&"ui_scale", &"glyph_mode"]:
		var option_row := screen.find_child("OptionLayout_%s" % String(option_id), true, false) as HBoxContainer
		var option_purpose := option_row.find_child("SettingPurpose", true, false) as Label if option_row != null else null
		var option_control := screen.control_for_setting(StringName("option.%s" % String(option_id))) as OptionButton
		_check(option_row != null and option_row.get_parent() == options_grid, "%s liegt ohne zusätzliche Kachel direkt im kompakten Optionsraster" % option_id)
		_check(option_row != null and option_row.size_flags_horizontal == Control.SIZE_SHRINK_BEGIN, "%s belegt nicht unnötig die gesamte Anzeigenbreite" % option_id)
		_check(option_control != null and option_control.custom_minimum_size.x <= 132.0, "%s hält Auswahlwert und Beschriftung eng zusammen" % option_id)
		_check(option_purpose != null and not option_purpose.clip_text, "%s bleibt links vollständig lesbar" % option_id)
	var scale_row := screen.find_child("OptionLayout_ui_scale", true, false) as HBoxContainer
	var glyph_row := screen.find_child("OptionLayout_glyph_mode", true, false) as HBoxContainer
	var scale_purpose := scale_row.find_child("SettingPurpose", true, false) as Label if scale_row != null else null
	var glyph_purpose := glyph_row.find_child("SettingPurpose", true, false) as Label if glyph_row != null else null
	_check(scale_purpose != null and scale_purpose.text == "UI-Größe", "UI-Skalierung verwendet eine knappe eindeutige Beschriftung")
	_check(glyph_purpose != null and glyph_purpose.text == "Eingabemodus", "Eingabedarstellung wird als verständlicher Eingabemodus benannt")
	var binding_layout := screen.find_child("BindingLayout_ui_info", true, false) as VBoxContainer
	_check(binding_layout != null and binding_layout.get_child_count() == 2, "Tastenbelegung stapelt Zweck und zwei nahe Tastaturfelder kompakt")
	_check(binding_layout != null and binding_layout.get_meta(&"alveolus_component", &"") == &"compact_binding_card", "Tastenbelegung ist als kompakte Kartenstruktur markiert")
	var binding_purpose := binding_layout.find_child("SettingPurpose", true, false) as Label if binding_layout != null else null
	_check(binding_purpose != null and binding_purpose.text == "Details anzeigen", "ui_info benennt seinen Spielerzweck statt nur die interne Aktion")
	for action_id in [
		"move_up", "move_down", "move_left", "move_right", "active_ability_1",
		"active_ability_2", "pause_game", "upgrade_1", "upgrade_2", "upgrade_3",
		"reroll_upgrades", "ui_accept", "ui_cancel", "ui_info",
	]:
		var shortcut_card := screen.find_child("BindingCard_%s" % action_id, true, false) as PanelContainer
		_check(shortcut_card != null, "%s besitzt einen eigenen kompakten Bio-Lumen-Container" % action_id)
		var slot_group := screen.find_child("BindingSlots_%s" % action_id, true, false) as HBoxContainer
		_check(slot_group != null and slot_group.get_child_count() == 2, "%s zeigt genau zwei getrennte Tastaturfelder" % action_id)
	var binding_card := screen.find_child("BindingCard_ui_info", true, false) as PanelContainer
	if binding_card != null:
		_check(binding_card.get_meta(&"alveolus_component", &"") == &"shortcut_container", "Shortcut-Container ist semantisch als gemeinsame Einstellungsstruktur markiert")
		_check(binding_card.get_meta(&"alveolus_surface_role", -1) == AlveolusVisualTheme.SurfaceRole.VALUE_ROW, "Shortcut-Container verwendet die zentrale ValueRow-Fläche")
		_check(binding_card.custom_minimum_size.y <= 80.0, "Shortcut-Container reserviert keinen unnötigen vertikalen Leerraum")
	var binding_grid := screen.find_child("BindingsGrid", true, false) as GridContainer
	_check(binding_grid != null and binding_grid.get_theme_constant("h_separation") == AlveolusVisualTheme.GRID_UNIT, "Drei Binding-Spalten verwenden nur den kleinen Rasterabstand")
	_check(binding_grid != null and binding_grid.get_theme_constant("v_separation") == AlveolusVisualTheme.GRID_UNIT, "Binding-Zeilen verwenden nur den kleinen Rasterabstand")
	var binding_button := screen.control_for_setting(&"binding.ui_info.0") as Button
	var second_binding_button := screen.control_for_setting(&"binding.ui_info.1") as Button
	if binding_purpose != null and binding_button != null:
		_check(binding_purpose.custom_minimum_size.x <= 0.0 and binding_button.custom_minimum_size.x <= 104.0, "Beschreibung und Tastaturplätze bleiben innerhalb der kompakten Karte dicht")
	for action_id in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		var movement_layout := screen.find_child("BindingLayout_%s" % String(action_id), true, false) as VBoxContainer
		var movement_purpose := movement_layout.find_child("SettingPurpose", true, false) as Label if movement_layout != null else null
		_check(
			movement_purpose != null
			and not movement_purpose.clip_text
			and movement_purpose.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING
			and _label_fits_single_line(movement_purpose),
			"%s bleibt im Desktop-Dreispaltenraster vollständig lesbar" % String(action_id)
		)
	_check(second_binding_button != null and _button_caption(second_binding_button) == "Nicht belegt", "Ein freier zweiter Tastaturplatz ist ausdrücklich sichtbar")
	var visible_binding := _button_caption(binding_button)
	_check(not visible_binding.contains("Y") and not visible_binding.contains("Gamepad"), "Controllerbelegungen sind in der Settings-Zeile visuell ausgeblendet")
	var toggle_grid := screen.find_child("DisplayTogglesGrid", true, false) as GridContainer
	for setting_id in [&"reduce_motion", &"run_stats", &"fullscreen", &"confirm_restart"]:
		var toggle := screen.control_for_setting(StringName("toggle.%s" % String(setting_id))) as CheckButton
		var toggle_row := screen.find_child("ToggleLayout_%s" % String(setting_id), true, false) as HBoxContainer
		_check(toggle_row != null and toggle_row.get_parent() == toggle_grid, "%s liegt ohne zusätzliche Kachel direkt im Anzeigenraster" % setting_id)
		_check(toggle != null and toggle.theme_type_variation == &"", "%s verwendet keinen eigenen Kachelhintergrund" % setting_id)
		_check(toggle != null and toggle.flat, "%s entfernt die umgebende Button-Kachel vollständig" % setting_id)
		_check(toggle != null and toggle.custom_minimum_size.y >= 44.0, "%s behält trotz flacher Darstellung ein 44-Pixel-Trefferziel" % setting_id)
		_check(toggle != null and toggle.get_meta(&"alveolus_component", &"") == &"transparent_toggle", "%s ist redundant als transparenter Switch markiert" % setting_id)
	var reduce_motion := screen.control_for_setting(&"toggle.reduce_motion") as CheckButton
	_check(reduce_motion != null and reduce_motion.tooltip_text.contains("UI-Animationen"), "Animationen reduzieren erklärt die Wirkung knapp und verständlich")
	for bus_id in [&"master", &"ui", &"effects", &"music"]:
		var mute := screen.control_for_setting(StringName("audio.%s.mute" % String(bus_id))) as CheckButton
		_check(mute != null and mute.theme_type_variation == &"", "%s-Stummschaltung liegt transparent in ihrer Audiozeile" % bus_id)
		_check(mute != null and mute.flat, "%s-Stummschaltung besitzt keine umgebende Button-Kachel" % bus_id)
		_check(mute != null and mute.custom_minimum_size.y >= 44.0, "%s-Stummschaltung behält ihr 44-Pixel-Trefferziel" % bus_id)


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
		[&"move_up", "Nach oben", ["W", "↑"]],
		[&"move_down", "Nach unten", ["S", "↓"]],
		[&"move_left", "Nach links", ["A", "←"]],
		[&"move_right", "Nach rechts", ["D", "→"]],
		[&"active_ability_1", "Fähigkeit 1", ["Q", "Nicht belegt"]],
		[&"active_ability_2", "Fähigkeit 2", ["E", "Nicht belegt"]],
		[&"pause_game", "Pause", ["P", "Esc"]],
		[&"upgrade_1", "Ausbau links", ["1", "Nicht belegt"]],
		[&"upgrade_2", "Ausbau mittig", ["2", "Nicht belegt"]],
		[&"upgrade_3", "Ausbau rechts", ["3", "Nicht belegt"]],
		[&"reroll_upgrades", "Neu ziehen", ["R", "Nicht belegt"]],
		[&"ui_accept", "Bestätigen", ["Enter", "Leertaste"]],
		[&"ui_cancel", "Zurück", ["Esc", "Nicht belegt"]],
		[&"ui_info", "Informationen", ["I", "Nicht belegt"]],
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


func _label_fits_single_line(label: Label) -> bool:
	if label == null:
		return false
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if font == null or font_size <= 0:
		return false
	var required_width := font.get_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x
	return label.size.x + 0.5 >= required_width


func _button_caption(button: Button) -> String:
	if button is IconTextButton:
		return (button as IconTextButton).caption.text
	return button.text


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
