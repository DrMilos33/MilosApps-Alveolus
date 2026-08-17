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
	_test_mouse_and_axis_capture(hud, glyphs)
	_test_scale_and_reduced_motion(hud)
	_test_restart_confirmation_setting(hud)
	_test_semantic_sounds(hud, sound)
	_test_binding_feedback(hud, sound)

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
	_true(hud.ability_key_icons[0].texture != null and hud.ability_key_icons[0].visible, "Q verwendet im HUD die Kenney-Promptgrafik")
	_true(hud.ability_key_icons[1].texture != null and hud.ability_key_icons[1].visible, "E verwendet im HUD die Kenney-Promptgrafik")
	_equal(hud.ability_key_icons[0].stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Promptgrafiken sind rechnerisch und optisch zentriert")
	_true(not hud.ability_key_labels[0].visible, "Bei einer Promptgrafik wird kein doppelter Text gezeichnet")

	glyphs.configure(UISettingsState.GLYPH_GAMEPAD)
	_true(hud.ability_key_icons[0].texture != null and hud.ability_key_icons[0].visible, "LB verwendet im HUD die Xbox-Promptgrafik")
	_true(hud.ability_key_icons[1].texture != null and hud.ability_key_icons[1].visible, "RB verwendet im HUD die Xbox-Promptgrafik")
	var pause_action := hud.pause_resume_button as IconTextButton
	_true(pause_action != null and pause_action.caption.text == "Weiter", "Das Pausemenü zeichnet die Hauptaktion genau einmal als zentrierte Icon-Text-Einheit")
	_true(hud.pause_resume_button.icon == null and hud.pause_resume_button.text.is_empty(), "Das Pausemenü bläht die Hauptaktion nicht mit einem zweiten Menu-Prompt auf")
	_true(not hud.pause_resume_button.tooltip_text.is_empty(), "Die aktuelle Pausenbelegung bleibt im Tooltip auffindbar")

	var settings := UISettingsState.new()
	_true(settings.set_single_binding(&"active_ability_1", _key(KEY_F)), "Freie Remap-Taste kann für die HUD-Prüfung gesetzt werden")
	glyphs.configure(UISettingsState.GLYPH_KEYBOARD)
	hud.configure_ui_settings(settings)
	_true(not hud.ability_key_icons[0].visible, "Eine frei remappte Taste verwendet keine falsche Standardgrafik")
	_true(hud.ability_key_labels[0].visible and hud.ability_key_labels[0].text == "F", "Freie Remaps besitzen einen zentrierten Textfallback")


func _test_mouse_and_axis_capture(hud: GameHUD, glyphs: InputGlyphService) -> void:
	hud.show_settings(false)
	hud._begin_binding_capture(&"move_up")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	hud._input(mouse)
	_true(hud.pending_binding_action == &"", "Eine Maustaste schließt die erfolgreiche Erfassung")
	_true(hud._binding_summary(&"move_up").contains("Maus 3"), "Die Einstellungen zeigen die remappte Maustaste verständlich")

	hud._begin_binding_capture(&"active_ability_2")
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_RIGHT_X
	axis.axis_value = 0.90
	hud._input(axis)
	_true(hud.pending_binding_action == &"", "Eine deutliche Stickbewegung kann als Gamepadeingabe belegt werden")
	_true(hud._binding_summary(&"active_ability_2").contains("RS X+"), "Die Achsenbelegung wird mit Stick und Richtung benannt")
	glyphs.configure(UISettingsState.GLYPH_GAMEPAD)
	_true(not hud.ability_key_icons[1].visible and hud.ability_key_labels[1].text == "RS X+", "Eine remappte Achse fällt im Fähigkeiten-HUD auf Text zurück")
	_true(hud.ability_key_containers[1].custom_minimum_size.x > 28.0, "Längere Textfallbacks erhalten genug Breite und bleiben zentriert")


func _test_scale_and_reduced_motion(hud: GameHUD) -> void:
	var settings := hud.current_ui_settings.duplicate_settings()
	_true(hud.settings_scale_option.item_count == UISettingsState.UI_SCALES.size(), "Die Anzeigeoption listet jede unterstützte UI-Skalierung genau einmal")
	_equal(hud.settings_scale_option.get_item_text(0), "75 %", "75 Prozent ist als kleinste UI-Stufe auswählbar")
	_equal(hud.settings_scale_option.get_item_text(1), "90 %", "90 Prozent ist als zweite kompakte UI-Stufe auswählbar")
	settings.ui_scale = 0.75
	hud.configure_ui_settings(settings)
	_near(hud.root.theme.default_base_scale, 0.75, 0.001, "75 Prozent UI-Skalierung erreicht das zentrale Theme")
	_equal(hud.settings_scale_option.selected, 0, "Die Anzeigeoption markiert die aktive 75-Prozent-Stufe")
	settings.ui_scale = 0.90
	hud.configure_ui_settings(settings)
	_near(hud.root.theme.default_base_scale, 0.90, 0.001, "90 Prozent UI-Skalierung erreicht das zentrale Theme")
	_equal(hud.settings_scale_option.selected, 1, "Die Anzeigeoption markiert die aktive 90-Prozent-Stufe")
	settings.ui_scale = 2.0
	settings.reduce_motion = true
	hud.configure_ui_settings(settings)
	_near(hud.root.theme.default_base_scale, 2.0, 0.001, "200 Prozent UI-Skalierung erreicht das zentrale Theme")
	_true(hud.reduced_motion_enabled, "Reduzierte Bewegung wird im HUD unmittelbar aktiviert")
	hud.settings_quit_button.scale = Vector2.ONE * 1.02
	hud._animate_button(hud.settings_quit_button, Vector2.ONE * 1.02)
	_equal(hud.settings_quit_button.scale, Vector2.ONE, "Reduzierte Bewegung unterdrückt Button-Skalierung statt nur die Option zu speichern")
	var campus_card := hud.campus_buttons[&"practice"] as CampusBuildingCard
	campus_card.set_reduced_motion(true)
	campus_card._set_mouse_over(true)
	campus_card._process(0.016)
	_equal(campus_card.building_sprite.scale, Vector2.ONE, "Campusgebäude behalten bei reduzierter Bewegung ihre feste Größe")

func _test_restart_confirmation_setting(hud: GameHUD) -> void:
	var settings := hud.current_ui_settings.duplicate_settings()
	settings.confirm_run_restart = true
	hud.configure_ui_settings(settings)
	_true(hud.settings_restart_confirmation_toggle.button_pressed, "Das HUD spiegelt den sicheren Standard für Strg+R als aktiven Schalter")
	_equal(hud.settings_restart_confirmation_toggle.text, "Ein", "Der aktive Neustartschalter besitzt eine eindeutige Beschriftung")
	_true(_control_text(hud.settings_overlay).contains("Strg+R startet die aktuelle Runde neu."), "Die Einstellungen erklären den globalen Neustart-Shortcut direkt am Schalter")
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


func _test_binding_feedback(hud: GameHUD, sound: UISoundService) -> void:
	hud.show_settings(false)
	hud._begin_binding_capture(&"active_ability_1")
	var before_error := sound.next_player
	hud._apply_binding_event(_key(KEY_S))
	_equal(sound.next_player, (before_error + 1) % UISoundService.PLAYER_COUNT, "Ein Bindingkonflikt spielt den Error-Cue")
	_true(hud.pending_binding_action == &"active_ability_1", "Nach einem Konflikt bleibt die Erfassung kontrolliert offen")
	var before_cancel := sound.next_player
	hud._cancel_binding_capture()
	_equal(sound.next_player, (before_cancel + 1) % UISoundService.PLAYER_COUNT, "Abbruch der Erfassung spielt den Back-Cue")


func _prepare_actions() -> void:
	var defaults := {
		&"move_up": [_key(KEY_W), _joy(JOY_BUTTON_DPAD_UP)],
		&"move_down": [_key(KEY_S), _joy(JOY_BUTTON_DPAD_DOWN)],
		&"move_left": [_key(KEY_A), _joy(JOY_BUTTON_DPAD_LEFT)],
		&"move_right": [_key(KEY_D), _joy(JOY_BUTTON_DPAD_RIGHT)],
		&"active_ability_1": [_key(KEY_Q), _joy(JOY_BUTTON_LEFT_SHOULDER)],
		&"active_ability_2": [_key(KEY_E), _joy(JOY_BUTTON_RIGHT_SHOULDER)],
		&"pause_game": [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)],
		&"ui_accept": [_key(KEY_ENTER), _joy(JOY_BUTTON_A)],
		&"ui_cancel": [_key(KEY_BACKSPACE), _joy(JOY_BUTTON_B)],
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


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _joy(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	return event


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


func _near(actual: float, expected: float, tolerance: float, message: String) -> void:
	assertions += 1
	if absf(actual - expected) > tolerance:
		failures += 1
		printerr("FAIL: %s | expected=%f actual=%f" % [message, expected, actual])
