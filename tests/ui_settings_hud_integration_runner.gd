extends SceneTree

var assertions := 0
var failures := 0
var original_actions: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_prepare_actions()
	var sound := UISoundService.new()
	root.add_child(sound)
	var glyphs := InputGlyphService.new()
	root.add_child(glyphs)
	var hud := GameHUD.new()
	root.add_child(hud)
	await process_frame
	sound.wire_tree(hud.root)
	hud.configure_input_glyphs(glyphs)

	_test_prompt_icons_and_text_fallback(hud, glyphs)
	_test_dual_keyboard_capture_and_conflict_popup(hud)
	_test_live_test_slider_identity(hud)
	_test_visible_settings_and_reduced_motion(hud)
	_test_restart_confirmation_setting(hud)
	_test_semantic_sounds(hud, sound)
	_test_binding_cancel_feedback(hud, sound)

	for player in sound.players:
		player.stop()
		player.stream = null
	sound.streams.clear()
	hud.free()
	glyphs.free()
	sound.free()
	_restore_actions()
	await process_frame
	if failures == 0:
		print("ALVEOLUS_UI_SETTINGS_HUD_INTEGRATION_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_UI_SETTINGS_HUD_INTEGRATION_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)


func _test_prompt_icons_and_text_fallback(hud: GameHUD, glyphs: InputGlyphService) -> void:
	glyphs.configure(UISettingsState.GLYPH_KEYBOARD)
	hud.configure_ui_settings(UISettingsState.new())
	_true(hud.run_hud_screen != null, "Das zentrale RunHUDOverlay ist für Eingabeglyphen verfügbar")
	_equal(hud.ability_key_icons.size(), 0, "Das RunHUDOverlay erzeugt keine alten TextureRect-Promptbilder")
	_equal(hud.ability_key_containers.size(), 0, "Das RunHUDOverlay benötigt keine separaten Promptbild-Container")
	_equal(hud.ability_key_labels.size(), 2, "Das RunHUDOverlay besitzt genau zwei textbasierte Fähigkeitsglyphen")
	_true(hud.ability_key_labels[0].visible and hud.ability_key_labels[0].text == "Q", "Fähigkeit 1 zeigt die scharfe Tastaturglyphe Q als Text")
	_true(hud.ability_key_labels[1].visible and hud.ability_key_labels[1].text == "E", "Fähigkeit 2 zeigt die scharfe Tastaturglyphe E als Text")

	_true(not hud.run_hud_screen.pause_action().tooltip_text.is_empty(), "Die Run-HUD-Pauseaktion hält ihre aktuelle Belegung im Tooltip auffindbar")
	var pause_action := hud.pause_resume_button as IconTextButton
	_true(pause_action != null and pause_action.caption.text == "Weiter", "Das Pausemenü zeichnet die Hauptaktion genau einmal als zentrierte Icon-Text-Einheit")
	_true(hud.pause_resume_button.icon == null and hud.pause_resume_button.text.is_empty(), "Das Pausemenü bläht die Hauptaktion nicht mit einem zweiten Menu-Prompt auf")
	_true(not hud.pause_resume_button.tooltip_text.is_empty(), "Die aktuelle Pausenbelegung bleibt im Tooltip auffindbar")

	var settings := UISettingsState.new()
	_true(settings.set_single_binding(&"active_ability_1", _key(KEY_F)), "Freie Remap-Taste kann für die HUD-Prüfung gesetzt werden")
	glyphs.configure(UISettingsState.GLYPH_KEYBOARD)
	hud.configure_ui_settings(settings)
	_true(hud.ability_key_labels[0].visible and hud.ability_key_labels[0].text == "F", "Freie Remaps aktualisieren die sichtbare Textglyphe unmittelbar")


func _test_dual_keyboard_capture_and_conflict_popup(hud: GameHUD) -> void:
	hud.show_settings(false)
	_true(hud.settings_screen.control_for_setting(&"option.ui_scale") == null, "UI-Größe ist aus der sichtbaren Settingsoberfläche entfernt")
	_true(hud.settings_screen.control_for_setting(&"option.glyph_mode") == null, "Eingabemodus ist aus der sichtbaren Settingsoberfläche entfernt")
	_true(hud.settings_scale_option == null and hud.settings_glyph_option == null, "Die HUD-Kompatibilitätsfassade erhält für dormante Anzeigeoptionen keine sichtbaren Controls")
	_true(hud.settings_screen.control_for_setting(&"binding.move_up.0") != null, "Nach oben besitzt ein erstes Tastaturfeld")
	_true(hud.settings_screen.control_for_setting(&"binding.move_up.1") != null, "Nach oben besitzt ein zweites Tastaturfeld")
	_equal(_button_caption(hud.settings_screen.control_for_setting(&"binding.move_up.0") as Button), "W", "Der erste Bewegungsplatz zeigt W ohne Controllerzusatz")
	_equal(_button_caption(hud.settings_screen.control_for_setting(&"binding.move_up.1") as Button), "Up", "Der zweite Bewegungsplatz zeigt Pfeil hoch getrennt")
	_true(not hud._binding_summary(&"move_up").contains("D-Pad"), "Die Settings-Zusammenfassung blendet Controllerbelegungen visuell aus")
	for action in [&"upgrade_1", &"upgrade_2", &"upgrade_3", &"reroll_upgrades"]:
		_true(hud.settings_screen.control_for_setting(StringName("binding.%s.0" % String(action))) != null, "%s ist im Settings-Screen belegbar" % String(action))

	hud._begin_binding_capture(&"move_up", 1)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	hud._input(mouse)
	_true(hud.pending_binding_action == &"move_up", "Unsichtbare Maustasten ändern einen Tastaturplatz nicht")
	hud._input(_pressed_key(KEY_T))
	_true(hud.pending_binding_action == &"", "Eine Tastaturbelegung schließt die erfolgreiche Erfassung")
	_true(_has_key(InputMap.action_get_events(&"move_up"), KEY_W) and _has_key(InputMap.action_get_events(&"move_up"), KEY_T), "Der zweite Tastaturplatz ändert sich unabhängig vom ersten")
	_true(_has_joy(InputMap.action_get_events(&"move_up"), JOY_BUTTON_DPAD_UP), "Controllerbelegung bleibt runtime-seitig erhalten")

	hud._begin_binding_capture(&"active_ability_1", 1)
	hud._apply_binding_event(_key(KEY_S))
	_true(hud.settings_screen.is_binding_conflict_open(), "Eine bereits verwendete Taste öffnet das Bestätigungspopup")
	_true(_has_key(InputMap.action_get_events(&"move_down"), KEY_S), "Vor Bestätigung bleibt die bestehende Aktion unverändert")
	var confirm := hud.settings_screen.find_child("BindingConflictConfirm", true, false) as Button
	_true(confirm != null, "Das Konfliktpopup besitzt eine ausdrückliche Übernehmen-Aktion")
	confirm.pressed.emit()
	_true(_has_key(InputMap.action_get_events(&"active_ability_1"), KEY_S), "Bestätigung übernimmt die Taste in den gewählten Fähigkeitsslot")
	_true(not _has_key(InputMap.action_get_events(&"move_down"), KEY_S), "Bestätigung entfernt die Taste aus der vorherigen Aktion")
	_true(not hud.is_binding_interaction_active(), "Nach der Konfliktentscheidung bleibt keine exklusive Eingabeebene aktiv")

	hud._begin_binding_capture(&"move_left", 1)
	_true(hud.is_binding_interaction_active(), "Eine laufende Tastaturerfassung ist als exklusive Eingabeebene erkennbar")
	hud.show_running_hud()
	_true(not hud.is_binding_interaction_active() and hud.pending_binding_action == &"", "Verlassen der Einstellungen verwirft eine unvollständige Erfassung vollständig")
	hud.show_settings(false)


func _test_visible_settings_and_reduced_motion(hud: GameHUD) -> void:
	var settings := hud.current_ui_settings.duplicate_settings()
	_true(hud.settings_scale_option == null, "Das fokussierte Settingsprofil besitzt keine UI-Größenmatrix mehr")
	_true(hud.settings_glyph_option == null, "Das fokussierte Settingsprofil besitzt keine Eingabemodusmatrix mehr")
	var discovery_toggle := hud.settings_screen.control_for_setting(&"toggle.show_discovery_info") as CheckButton
	_true(discovery_toggle != null and discovery_toggle.button_pressed, "Neuigkeiten besitzen einen standardmäßig aktiven Settings-Schalter")
	discovery_toggle.button_pressed = false
	_true(not hud.current_ui_settings.show_discovery_info, "Der Schalter deaktiviert pausierende Entdeckungsinfos unmittelbar")
	discovery_toggle.button_pressed = true
	_true(hud.current_ui_settings.show_discovery_info, "Entdeckungsinfos lassen sich im selben Screen wieder aktivieren")
	var health_toggle := hud.settings_screen.control_for_setting(&"toggle.show_character_health_bar") as CheckButton
	_true(health_toggle != null and not health_toggle.button_pressed, "Der kleine Charakter-Lebensbalken ist standardmäßig ausgeschaltet")
	_true(health_toggle != null and health_toggle.tooltip_text.contains("ohne Zahlen") and health_toggle.tooltip_text.contains("Doctor Milos"), "Der Schalter erklärt den kleinen zahlenlosen Lebensbalken über der Figur")
	_true(health_toggle != null and str(health_toggle.get_meta(&"alveolus_accessible_name", "")).contains("Kleiner Lebensbalken"), "Der Charakter-Lebensbalken besitzt einen klaren zugänglichen Namen")
	var emitted: Array[UISettingsState] = []
	hud.ui_settings_changed.connect(func(updated: UISettingsState) -> void: emitted.append(updated))
	health_toggle.button_pressed = true
	_true(hud.current_ui_settings.show_character_health_bar, "Der Schalter aktiviert den Charakter-Lebensbalken unmittelbar")
	_true(not emitted.is_empty() and emitted.back().show_character_health_bar, "Der Charakter-Lebensbalken emittiert eine speicherbare Einstellungskopie")
	health_toggle.button_pressed = false
	_true(not hud.current_ui_settings.show_character_health_bar and not emitted.back().show_character_health_bar, "Der Charakter-Lebensbalken lässt sich im selben Screen wieder ausschalten")
	settings.reduce_motion = true
	hud.configure_ui_settings(settings)
	_true(hud.reduced_motion_enabled, "Reduzierte Bewegung wird im HUD unmittelbar aktiviert")
	hud.settings_quit_button.scale = Vector2.ONE * 1.02
	hud._animate_button(hud.settings_quit_button, Vector2.ONE * 1.02)
	_equal(hud.settings_quit_button.scale, Vector2.ONE, "Reduzierte Bewegung unterdrückt Button-Skalierung statt nur die Option zu speichern")
	var campus_card := hud.campus_buttons[&"practice"] as CampusBuildingCard
	campus_card.set_reduced_motion(true)
	campus_card._set_mouse_over(true)
	campus_card._process(0.016)
	_equal(campus_card.building_sprite.scale, Vector2.ONE, "Campusgebäude behalten bei reduzierter Bewegung ihre feste Größe")


func _test_live_test_slider_identity(hud: GameHUD) -> void:
	var settings := RunTestSettings.new(false, 0, 100)
	hud.configure_test_settings(settings, true)
	hud.show_settings(false)
	var slider := hud.settings_screen.control_for_setting(&"test.outgoing_damage_bonus_percent") as HSlider
	_true(slider != null, "Debug-Einstellungen stellen den Schadensregler im HUD bereit")
	if slider == null:
		return
	var slider_instance := slider.get_instance_id()
	var relay := func(percent: int) -> void:
		if settings.set_outgoing_damage_bonus_percent(percent):
			hud.configure_test_settings(settings, true)
	hud.test_outgoing_damage_bonus_percent_changed.connect(relay)
	slider.value = 10.0
	slider.value = 20.0
	_true(is_instance_valid(slider) and slider.get_instance_id() == slider_instance, "Live-Integratorrefresh ersetzt den gezogenen Testregler nicht")
	_equal(slider.value, 20.0, "Ein Testregler verarbeitet mehr als einen Wert desselben Pointer-Drags")
	_equal(settings.outgoing_damage_bonus_percent(), 20, "Der zweite Live-Wert erreicht die persistierbare Testkonfiguration")
	hud.test_outgoing_damage_bonus_percent_changed.disconnect(relay)

func _test_restart_confirmation_setting(hud: GameHUD) -> void:
	var settings := hud.current_ui_settings.duplicate_settings()
	settings.confirm_run_restart = true
	hud.configure_ui_settings(settings)
	_true(hud.settings_restart_confirmation_toggle.button_pressed, "Das HUD spiegelt den sicheren Standard für Strg+R als aktiven Schalter")
	_equal(hud.settings_restart_confirmation_toggle.text, "Ein", "Der aktive Neustartschalter besitzt eine eindeutige Beschriftung")
	_true(_control_text(hud.settings_overlay).contains("Strg+R bestätigen"), "Die Einstellungen erklären den globalen Neustart-Shortcut kompakt direkt am Schalter")
	var emitted: Array[UISettingsState] = []
	hud.ui_settings_changed.connect(func(updated: UISettingsState) -> void: emitted.append(updated))
	hud.settings_restart_confirmation_toggle.button_pressed = false
	_true(not hud.current_ui_settings.confirm_run_restart, "Ausschalten aktualisiert den HUD-Einstellungszustand unmittelbar")
	_equal(hud.settings_restart_confirmation_toggle.text, "Aus", "Der ausgeschaltete Neustartschalter zeigt seinen Zustand verständlich")
	_true(not emitted.is_empty() and not emitted.back().confirm_run_restart, "Der Neustartschalter emittiert eine speicherbare Einstellungskopie")
	hud.settings_restart_confirmation_toggle.button_pressed = true
	_true(hud.current_ui_settings.confirm_run_restart and emitted.back().confirm_run_restart, "Der Neustartschutz lässt sich im selben Screen wieder einschalten")


func _test_semantic_sounds(hud: GameHUD, sound: UISoundService) -> void:
	var back := Button.new()
	back.text = "Zum Campus"
	UISoundService.set_sound_role(back, UISoundService.BACK)
	_equal(sound._cue_for_button(back), UISoundService.BACK, "Zurücknavigation verwendet den Back-Cue")
	var start := Button.new()
	start.text = "Behandlung starten"
	UISoundService.set_sound_role(start, UISoundService.RUN_START)
	_equal(sound._cue_for_button(start), UISoundService.RUN_START, "Der Runstart verwendet seinen expliziten Cue")
	var settings := Button.new()
	settings.text = "Einstellungen"
	UISoundService.set_sound_role(settings, UISoundService.OPEN)
	_equal(sound._cue_for_button(settings), UISoundService.OPEN, "Ein öffnender Menübutton verwendet den Open-Cue")
	back.free()
	start.free()
	settings.free()

	var mouse_before_focus := sound.next_player
	sound._input(InputEventMouseMotion.new())
	(hud.settings_binding_buttons[&"move_up"] as Button).focus_entered.emit()
	_equal(sound.next_player, mouse_before_focus, "Mausbewegung und Hover erzeugen keinen Fokus-Cue")
	var before_focus := sound.next_player
	var navigation := InputEventKey.new()
	navigation.physical_keycode = KEY_DOWN
	navigation.pressed = true
	sound._input(navigation)
	(hud.settings_binding_buttons[&"move_down"] as Button).focus_entered.emit()
	_equal(sound.next_player, (before_focus + 1) % UISoundService.PLAYER_COUNT, "Ein fokussierter HUD-Button spielt genau einen Fokus-Cue")
	var before_campus := sound.next_player
	(hud.campus_buttons[&"practice"] as CampusBuildingCard).selected.emit()
	_equal(sound.next_player, (before_campus + 1) % UISoundService.PLAYER_COUNT, "Auch die nicht von Button abgeleiteten Campusgebäude geben Öffnungsfeedback")


func _test_binding_cancel_feedback(hud: GameHUD, sound: UISoundService) -> void:
	hud.show_settings(false)
	hud._begin_binding_capture(&"active_ability_1", 1)
	var before_cancel := sound.next_player
	hud._cancel_binding_capture()
	_equal(sound.next_player, (before_cancel + 1) % UISoundService.PLAYER_COUNT, "Abbruch der Erfassung spielt den Back-Cue")


func _prepare_actions() -> void:
	var defaults := {
		&"move_up": [_key(KEY_W), _key(KEY_UP), _joy(JOY_BUTTON_DPAD_UP)],
		&"move_down": [_key(KEY_S), _key(KEY_DOWN), _joy(JOY_BUTTON_DPAD_DOWN)],
		&"move_left": [_key(KEY_A), _key(KEY_LEFT), _joy(JOY_BUTTON_DPAD_LEFT)],
		&"move_right": [_key(KEY_D), _key(KEY_RIGHT), _joy(JOY_BUTTON_DPAD_RIGHT)],
		&"active_ability_1": [_key(KEY_Q), _joy(JOY_BUTTON_LEFT_SHOULDER)],
		&"active_ability_2": [_key(KEY_E), _joy(JOY_BUTTON_RIGHT_SHOULDER)],
		&"pause_game": [_key(KEY_P), _key(KEY_ESCAPE), _joy(JOY_BUTTON_START)],
		&"upgrade_1": [_key(KEY_1)],
		&"upgrade_2": [_key(KEY_2)],
		&"upgrade_3": [_key(KEY_3)],
		&"reroll_upgrades": [_key(KEY_R), _joy(JOY_BUTTON_X)],
		&"ui_accept": [_key(KEY_ENTER), _key(KEY_SPACE), _joy(JOY_BUTTON_A)],
		&"ui_cancel": [_key(KEY_BACKSPACE), _joy(JOY_BUTTON_B)],
		&"ui_info": [_key(KEY_I), _joy(JOY_BUTTON_Y)],
	}
	for action in UISettingsState.CONFIGURABLE_ACTIONS:
		original_actions[action] = {"existed": InputMap.has_action(action), "events": InputMap.action_get_events(action) if InputMap.has_action(action) else []}
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for event in defaults[action]:
			InputMap.action_add_event(action, event)


func _restore_actions() -> void:
	for action in UISettingsState.CONFIGURABLE_ACTIONS:
		InputMap.action_erase_events(action)
		var snapshot: Dictionary = original_actions[action]
		if bool(snapshot["existed"]):
			for event in snapshot["events"]:
				InputMap.action_add_event(action, event)
		else:
			InputMap.erase_action(action)

func _control_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	elif node is Button:
		result += (node as Button).text + "\n"
	for child in node.get_children():
		result += _control_text(child)
	return result


func _button_caption(button: Button) -> String:
	if button is IconTextButton:
		return (button as IconTextButton).caption.text
	return button.text


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _pressed_key(code: Key) -> InputEventKey:
	var event := _key(code)
	event.pressed = true
	return event


func _joy(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	return event


func _has_key(events: Array[InputEvent], code: Key) -> bool:
	for event in events:
		if event is InputEventKey and (event as InputEventKey).physical_keycode == code:
			return true
	return false


func _has_joy(events: Array[InputEvent], button_index: JoyButton) -> bool:
	for event in events:
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button_index:
			return true
	return false


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: %s" % message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures += 1
		printerr("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])
