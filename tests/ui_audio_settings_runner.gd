extends SceneTree

var assertions := 0
var failures := 0
var original_actions: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_and_prepare_actions()
	_test_settings_defaults_validation_and_roundtrip()
	_test_rebinding_conflicts_and_safe_restore()
	_test_input_glyphs_follow_bindings_and_device()
	await _test_audio_buses_assets_pool_and_wiring()
	_test_save_v7_settings_roundtrip()
	_restore_actions()
	if failures == 0:
		print("ALVEOLUS_UI_AUDIO_SETTINGS_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_UI_AUDIO_SETTINGS_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)


func _capture_and_prepare_actions() -> void:
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
		original_actions[action] = {
			"existed": InputMap.has_action(action),
			"events": InputMap.action_get_events(action) if InputMap.has_action(action) else [],
		}
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


func _test_settings_defaults_validation_and_roundtrip() -> void:
	var defaults := UISettingsState.new()
	_near(defaults.master_volume, 0.80, 0.0001, "Master startet bei 80 Prozent")
	_near(defaults.ui_volume, 0.65, 0.0001, "UI startet bei 65 Prozent")
	_near(defaults.effects_volume, 0.80, 0.0001, "Effekte starten bei 80 Prozent")
	_equal(defaults.ui_scale, 1.0, "UI startet mit 100 Prozent Skalierung")
	_equal(UISettingsState.UI_SCALES, [0.75, 0.90, 1.0, 1.25, 1.5, 2.0], "UI-Skalierung bietet die sechs verbindlichen Stufen einschließlich 75 und 90 Prozent")
	_equal(defaults.glyph_mode, UISettingsState.GLYPH_AUTO, "Eingabesymbole erkennen das Gerät standardmäßig automatisch")
	_true(not defaults.reduce_motion, "Reduzierte Bewegung ist optional")
	_true(defaults.show_discovery_info, "Hinweise sind standardmäßig aktiviert")
	_true(defaults.show_boss_target_arrows and defaults.show_event_target_arrows, "Boss- und Eventmonster-Pfeile sind standardmäßig sichtbar")
	_true(not defaults.show_character_name, "Der Charaktername ist standardmäßig dezent ausgeblendet")
	_true(not defaults.show_character_health_bar, "Der kleine Charakter-Lebensbalken ist standardmäßig ausgeblendet")
	_true(defaults.confirm_run_restart, "Strg+R verlangt standardmäßig eine bewusste Bestätigung")
	_true(UISettingsState.from_dict({}).confirm_run_restart, "Ältere Einstellungsdaten erhalten den sicheren Neustart-Standard")
	_true(UISettingsState.from_dict({}).show_discovery_info, "Ältere Einstellungsdaten erhalten den aktivierten Hinweis-Standard")
	_true(UISettingsState.from_dict({}).show_boss_target_arrows and UISettingsState.from_dict({}).show_event_target_arrows, "Ältere Einstellungsdaten behalten beide Zielpfeile")
	_true(not UISettingsState.from_dict({}).show_character_health_bar, "Ältere Einstellungsdaten blenden den optionalen Charakter-Lebensbalken aus")
	_true(UISettingsState.CONFIGURABLE_ACTIONS.has(&"ui_info"), "Kontextinformationen besitzen eine konfigurierbare Eingabeaktion")
	for upgrade_action in [&"upgrade_1", &"upgrade_2", &"upgrade_3", &"reroll_upgrades"]:
		_true(UISettingsState.CONFIGURABLE_ACTIONS.has(upgrade_action), "%s ist in den Einstellungen frei belegbar" % String(upgrade_action))
	_true(_has_key(InputMap.action_get_events(&"ui_info"), KEY_I), "Informationen verwenden standardmäßig I")
	_true(_has_joy_button(InputMap.action_get_events(&"ui_info"), JOY_BUTTON_Y), "Informationen verwenden standardmäßig Gamepad-Y")

	var sanitized := UISettingsState.from_dict({
		"master_volume": 4.0,
		"ui_volume": -2.0,
		"effects_volume": 0.42,
		"music_volume": 0.33,
		"ui_scale": 1.48,
		"glyph_mode": "invalid",
		"reduce_motion": true,
		"show_discovery_info": false,
		"show_boss_target_arrows": false,
		"show_event_target_arrows": false,
		"show_character_name": true,
		"show_character_health_bar": true,
		"fullscreen": true,
		"confirm_run_restart": false,
		"input_bindings": {"active_ability_1": [{"type": "key", "physical_keycode": KEY_R}]},
	})
	_equal(sanitized.master_volume, 1.0, "Geladene Lautstärke wird oben begrenzt")
	_equal(sanitized.ui_volume, 0.0, "Geladene Lautstärke wird unten begrenzt")
	_equal(sanitized.ui_scale, 1.5, "Nicht unterstützte UI-Skalierung wird auf die nächste Stufe gesetzt")
	_equal(sanitized.glyph_mode, UISettingsState.GLYPH_AUTO, "Unbekannter Glyphmodus fällt sicher auf Automatisch zurück")
	_true(sanitized.reduce_motion and not sanitized.show_discovery_info and sanitized.show_character_name and sanitized.fullscreen, "Ein ausdrücklich ausgeschalteter Hinweiswert und die übrigen Anzeigeoptionen überleben das Laden")
	_true(not bool(sanitized.to_dict().get("show_discovery_info", true)), "Das Einstellungs-Dictionary bewahrt einen ausdrücklich ausgeschalteten Hinweiswert")
	_true(not sanitized.show_boss_target_arrows and not sanitized.show_event_target_arrows, "Beide Zielpfeile lassen sich unabhängig vom Hinweiswert ausschalten")
	_true(not bool(sanitized.to_dict().get("show_boss_target_arrows", true)) and not bool(sanitized.to_dict().get("show_event_target_arrows", true)), "Das Einstellungs-Dictionary speichert beide Zielpfeile explizit")
	_true(sanitized.show_character_health_bar, "Der Charakter-Lebensbalken überlebt das Laden")
	_true(not sanitized.confirm_run_restart, "Die Neustartbestätigung lässt sich im Einstellungs-Dictionary ausschalten")
	_true(bool(sanitized.to_dict().get("show_character_health_bar", false)), "Das Einstellungs-Dictionary speichert den Charakter-Lebensbalken explizit")
	_true(not bool(sanitized.to_dict().get("confirm_run_restart", true)), "Das Einstellungs-Dictionary speichert die Neustartbestätigung explizit")
	_equal(UISettingsState.from_dict({"ui_scale": 0.76}).ui_scale, 0.75, "Niedrige Save-Skalierung rastet sicher auf 75 Prozent ein")
	_equal(UISettingsState.from_dict({"ui_scale": 0.88}).ui_scale, 0.90, "Niedrige Save-Skalierung rastet sicher auf 90 Prozent ein")
	var copy := sanitized.duplicate_settings()
	_true(not copy.show_discovery_info, "Einstellungsduplikate bewahren ausdrücklich ausgeschaltete Hinweise")
	_true(not copy.show_boss_target_arrows and not copy.show_event_target_arrows, "Einstellungsduplikate bewahren beide Zielpfeile")
	_true(not copy.confirm_run_restart, "Einstellungsduplikate bewahren die Neustartbestätigung")
	_true(copy.show_character_name, "Einstellungsduplikate bewahren die Namensanzeige")
	_true(copy.show_character_health_bar, "Einstellungsduplikate bewahren den Charakter-Lebensbalken")
	(copy.input_bindings["active_ability_1"] as Array).append({"type": "key", "physical_keycode": KEY_T})
	_equal((sanitized.input_bindings["active_ability_1"] as Array).size(), 1, "Einstellungsduplikate teilen keine verschachtelten Bindingdaten")

	var modified_key := _key(KEY_R)
	modified_key.ctrl_pressed = true
	modified_key.shift_pressed = true
	var decoded := UISettingsState.deserialize_input_event(UISettingsState.serialize_input_event(modified_key)) as InputEventKey
	_true(decoded != null and decoded.ctrl_pressed and decoded.shift_pressed, "Tastenmodifikatoren werden verlustfrei gespeichert")
	_equal(decoded.physical_keycode, KEY_R, "Physische Taste überlebt den Roundtrip")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	var decoded_mouse := UISettingsState.deserialize_input_event(UISettingsState.serialize_input_event(mouse)) as InputEventMouseButton
	_equal(decoded_mouse.button_index, MOUSE_BUTTON_RIGHT, "Maustasten sind im Bindingformat unterstützt")
	var legacy_settings := UISettingsState.from_dict({"input_bindings": {"active_ability_1": [{"type": "key", "physical_keycode": KEY_T}]}})
	_true(not legacy_settings.input_bindings.has("ui_info"), "Ältere Einstellungsdaten benötigen keinen künstlichen ui_info-Saveeintrag")


func _test_rebinding_conflicts_and_safe_restore() -> void:
	var settings := UISettingsState.new()
	var reserved_restart := _key(KEY_R)
	reserved_restart.ctrl_pressed = true
	_true(UISettingsState.is_reserved_quick_restart_binding(reserved_restart), "Strg+R wird als reservierter Rundenneustart erkannt")
	_true(not settings.set_single_binding(&"active_ability_1", reserved_restart), "Der globale Neustart-Shortcut kann keine konfigurierbare Spielaktion überschreiben")
	_true(not settings.set_single_binding(&"ui_info", reserved_restart), "Auch die Informationstaste respektiert die Strg+R-Reservierung")
	_true(settings.set_single_binding(&"active_ability_1", _key(KEY_H)), "Eine freie Taste kann neu belegt werden")
	var ability_one_events := InputMap.action_get_events(&"active_ability_1")
	_true(_has_key(ability_one_events, KEY_H), "Die neue Tastaturbelegung ist sofort aktiv")
	_true(_has_joy_button(ability_one_events, JOY_BUTTON_LEFT_SHOULDER), "Neue Tastaturbelegung bewahrt die Gamepadbelegung")
	_true(not settings.set_single_binding(&"active_ability_2", _key(KEY_H)), "Doppelte konfigurierbare Eingaben werden abgelehnt")
	var chord := _key(KEY_R)
	chord.ctrl_pressed = true
	_true(not settings.set_single_binding(&"active_ability_2", chord), "Strg+R bleibt auch nach anderen Belegungen für den Neustart reserviert")
	chord = _key(KEY_F)
	chord.ctrl_pressed = true
	_true(settings.set_single_binding(&"active_ability_2", chord), "Eine freie Tastenkombination kann belegt werden")
	_true(not settings.set_single_binding(&"not_configurable", _key(KEY_F)), "Nur freigegebene Aktionen können durch Save-Daten verändert werden")
	_true(settings.set_single_binding(&"ui_info", _key(KEY_G)), "Die Informationstaste lässt sich unabhängig neu belegen")
	_true(_has_key(InputMap.action_get_events(&"ui_info"), KEY_G), "Die neue Informationstaste ist sofort aktiv")
	_true(_has_joy_button(InputMap.action_get_events(&"ui_info"), JOY_BUTTON_Y), "Ein Tastatur-Remap bewahrt Gamepad-Y")
	_true(settings.set_single_binding(&"ui_info", _joy(JOY_BUTTON_RIGHT_STICK)), "Auch die Gamepadbelegung für Informationen lässt sich ändern")
	_true(_has_key(InputMap.action_get_events(&"ui_info"), KEY_G), "Ein Gamepad-Remap bewahrt die Informationstaste der Tastatur")
	_true(_has_joy_button(InputMap.action_get_events(&"ui_info"), JOY_BUTTON_RIGHT_STICK), "Der Gamepad-Remap ersetzt Y innerhalb seiner Geräteklasse")
	_true(not _has_joy_button(InputMap.action_get_events(&"ui_info"), JOY_BUTTON_Y), "Die alte Gamepadbelegung bleibt nach dem Remap nicht doppelt aktiv")
	_true(settings.input_bindings.has("ui_info"), "Der ui_info-Remap verwendet das bestehende save-kompatible Bindingformat")

	var move_up_keys := settings.keyboard_bindings_for(&"move_up")
	_equal(move_up_keys.size(), 2, "Bewegung stellt beide sichtbaren Tastaturplätze bereit")
	_equal(move_up_keys[0].physical_keycode, KEY_W, "Der erste Tastaturplatz bewahrt W")
	_equal(move_up_keys[1].physical_keycode, KEY_UP, "Der zweite Tastaturplatz bewahrt Pfeil hoch")
	_true(settings.set_keyboard_binding_slot(&"move_up", 1, _key(KEY_T)), "Der zweite Tastaturplatz lässt sich unabhängig ändern")
	var remapped_move_up := InputMap.action_get_events(&"move_up")
	_true(_has_key(remapped_move_up, KEY_W) and _has_key(remapped_move_up, KEY_T), "Ein Slot-Remap bewahrt die andere Tastaturbelegung")
	_true(_has_joy_button(remapped_move_up, JOY_BUTTON_DPAD_UP), "Unsichtbare Controllerbelegungen bleiben beim Tastatur-Remap aktiv")
	_equal(settings.keyboard_binding_conflict(&"active_ability_1", _key(KEY_S)), &"move_down", "Eine anderweitig verwendete Taste benennt die Konfliktaktion")
	_true(not settings.set_keyboard_binding_slot(&"active_ability_1", 1, _key(KEY_S)), "Konflikte werden ohne Bestätigung nicht still übernommen")
	_true(settings.set_keyboard_binding_slot(&"active_ability_1", 1, _key(KEY_S), true), "Eine ausdrücklich bestätigte Taste wird übernommen")
	_true(_has_key(InputMap.action_get_events(&"active_ability_1"), KEY_H) and _has_key(InputMap.action_get_events(&"active_ability_1"), KEY_S), "Bestätigtes Verschieben bewahrt den anderen Fähigkeitsslot")
	_true(not _has_key(InputMap.action_get_events(&"move_down"), KEY_S), "Bestätigtes Verschieben entfernt die Taste atomar von der Konfliktaktion")
	_true(_has_key(InputMap.action_get_events(&"move_down"), KEY_DOWN), "Die zweite Taste hält die bisherige Konfliktaktion weiterhin bedienbar")
	_true(settings.input_bindings.has("move_down"), "Auch die veränderte Konfliktaktion wird im vorhandenen Saveformat aktualisiert")

	# Legacy saves may contain more keyboard events than the two visible slots.
	# Editing one visible slot must not silently erase those additional inputs.
	InputMap.action_add_event(&"ui_accept", _key(KEY_KP_ENTER))
	_true(settings.set_keyboard_binding_slot(&"ui_accept", 0, _key(KEY_U)), "Ein sichtbarer Bestätigen-Slot lässt sich trotz Legacy-Zusatztaste ändern")
	_true(_has_key(InputMap.action_get_events(&"ui_accept"), KEY_U) and _has_key(InputMap.action_get_events(&"ui_accept"), KEY_SPACE), "Beide sichtbaren Bestätigen-Slots bleiben erhalten")
	_true(_has_key(InputMap.action_get_events(&"ui_accept"), KEY_KP_ENTER), "Eine zusätzliche Legacy-Tastaturbelegung wird beim Zwei-Slot-Edit nicht gelöscht")

	InputMap.action_add_event(&"ui_cancel", _key(KEY_ESCAPE))
	var escape_conflicts := settings.keyboard_binding_conflicts(&"active_ability_2", _key(KEY_ESCAPE))
	_true(escape_conflicts.has(&"pause_game") and escape_conflicts.has(&"ui_cancel"), "Ein Mehrfachkonflikt benennt jede betroffene Aktion vor der Übernahme")

	InputMap.action_erase_events(&"active_ability_1")
	InputMap.action_add_event(&"active_ability_1", _key(KEY_V))
	settings.apply_saved_bindings()
	_true(_has_key(InputMap.action_get_events(&"active_ability_1"), KEY_H), "Gespeicherte Belegung wird wieder angewendet")
	_true(_has_joy_button(InputMap.action_get_events(&"active_ability_1"), JOY_BUTTON_LEFT_SHOULDER), "Gespeicherter Roundtrip bewahrt beide Geräteklassen")
	_true(_has_key(InputMap.action_get_events(&"ui_info"), KEY_G), "Der gespeicherte ui_info-Roundtrip stellt die Tastaturklasse wieder her")
	_true(_has_joy_button(InputMap.action_get_events(&"ui_info"), JOY_BUTTON_RIGHT_STICK), "Der gespeicherte ui_info-Roundtrip stellt die Gamepadklasse wieder her")

	var saved_gamepad := UISettingsState.new()
	saved_gamepad.input_bindings = {
		"active_ability_2": [
			{"type": "joy_button", "button_index": JOY_BUTTON_Y},
			{"type": "joy_motion", "axis": JOY_AXIS_RIGHT_X, "axis_value": -1.0},
		]
	}
	saved_gamepad.apply_saved_bindings()
	var restored_gamepad_events := InputMap.action_get_events(&"active_ability_2")
	_true(_has_device_independent_joy_button(restored_gamepad_events, JOY_BUTTON_Y), "Geladene Gamepadtasten gelten nach einem Neustart für jeden Controller")
	_true(_has_device_independent_joy_motion(restored_gamepad_events, JOY_AXIS_RIGHT_X, -1.0), "Geladene Gamepadachsen bleiben nach einem Neustart geräteunabhängig")

	var corrupt := UISettingsState.new()
	corrupt.input_bindings = {"move_up": [{"type": "unknown"}]}
	var before := InputMap.action_get_events(&"move_up")
	corrupt.apply_saved_bindings()
	_equal(InputMap.action_get_events(&"move_up").size(), before.size(), "Beschädigte Bindingdaten löschen keine funktionierende Standardbelegung")
	_true(_has_key(InputMap.action_get_events(&"move_up"), KEY_W), "Der Standard bleibt nach beschädigten Save-Daten benutzbar")

	InputMap.action_erase_events(&"ui_info")
	InputMap.action_add_event(&"ui_info", _key(KEY_I))
	InputMap.action_add_event(&"ui_info", _joy(JOY_BUTTON_Y))


func _test_input_glyphs_follow_bindings_and_device() -> void:
	var service := InputGlyphService.new()
	root.add_child(service)
	for icon_id in InputGlyphService.ICON_PATHS:
		_true(ResourceLoader.exists(String(InputGlyphService.ICON_PATHS[icon_id])), "Promptgrafik %s ist importierbar" % String(icon_id))
	var notifications := [0]
	service.input_method_changed.connect(func(_method: StringName) -> void: notifications[0] += 1)
	service.configure(UISettingsState.GLYPH_KEYBOARD)
	_equal(service.glyph_for_action(&"active_ability_1"), "H", "Tastatursymbol folgt der tatsächlichen neuen Belegung")
	_true(service.icon_for_action(&"active_ability_1") == null, "Eine freie Remap-Taste verwendet bewusst den Textfallback")
	_equal(service.glyph_for_action(&"ui_info"), "I", "Die Informationstaste löst auf der Tastatur ihr tatsächliches Glyph auf")
	_equal(InputGlyphService.caption_for_action(&"ui_info"), "Informationen", "Die Einstellungszeile benennt ui_info verständlich")
	_true(service.icon_for_action(&"ui_info") == null, "I verwendet ohne passendes lizenziertes Asset bewusst den klaren Textfallback")
	service.configure(UISettingsState.GLYPH_GAMEPAD)
	_equal(service.glyph_for_action(&"active_ability_1"), "LB", "Gamepadsymbol folgt der tatsächlichen Belegung")
	_true(service.icon_for_action(&"active_ability_1") != null, "Eine bekannte Standardbelegung verwendet die lizenzierte Promptgrafik")
	_equal(service.glyph_for_action(&"ui_info"), "Y", "Kontextinformationen zeigen auf dem Gamepad Y")
	_true(service.icon_for_action(&"ui_info") == null, "Y fällt ohne falsches Button-Asset auf zentrierten Text zurück")
	InputMap.action_erase_events(&"ui_info")
	_equal(service.glyph_for_action(&"ui_info"), "Y", "Der Gamepad-Fallback bleibt vor der Laufzeitregistrierung verständlich")
	service.configure(UISettingsState.GLYPH_KEYBOARD)
	_equal(service.glyph_for_action(&"ui_info"), "I", "Der Tastatur-Fallback bleibt vor der Laufzeitregistrierung verständlich")
	InputMap.action_add_event(&"ui_info", _key(KEY_I))
	InputMap.action_add_event(&"ui_info", _joy(JOY_BUTTON_Y))
	service.configure(UISettingsState.GLYPH_AUTO)
	var gamepad_event := InputEventJoypadButton.new()
	gamepad_event.button_index = JOY_BUTTON_X
	gamepad_event.pressed = true
	service._input(gamepad_event)
	_equal(service.method(), InputGlyphService.GAMEPAD, "Automatik erkennt eine Gamepadeingabe")
	var quiet_axis := InputEventJoypadMotion.new()
	quiet_axis.axis_value = 0.1
	service._input(quiet_axis)
	_equal(service.method(), InputGlyphService.GAMEPAD, "Stickdrift wechselt das Eingabegerät nicht")
	var keyboard_event := _key(KEY_SPACE)
	keyboard_event.pressed = true
	service._input(keyboard_event)
	_equal(service.method(), InputGlyphService.KEYBOARD_MOUSE, "Automatik kehrt bei Tastatureingabe zur Tastatur zurück")
	_true(notifications[0] >= 4, "Glyphänderungen werden auch nach Konfiguration und Rebinding signalisiert")
	service.free()


func _test_audio_buses_assets_pool_and_wiring() -> void:
	var service := UISoundService.new()
	root.add_child(service)
	await process_frame
	for bus_name in [&"Master", &"UI", &"Effects", &"Music"]:
		_true(AudioServer.get_bus_index(bus_name) >= 0, "Audiobus %s ist verfügbar" % String(bus_name))
	_equal(service.players.size(), UISoundService.PLAYER_COUNT, "UI-Sounds besitzen einen Playerpool gegen abgeschnittenes Feedback")
	for cue in UISoundService.SOUND_PATHS:
		var path := String(UISoundService.SOUND_PATHS[cue])
		_true(ResourceLoader.exists(path), "Audiocue %s verweist auf eine importierbare Datei" % String(cue))
		_true(service.streams.has(cue), "Audiocue %s wurde in den semantischen Katalog geladen" % String(cue))
	_equal(
		UISoundService.SOUND_ROLES,
		[UISoundService.NONE, UISoundService.PRESS, UISoundService.CONFIRM, UISoundService.BACK, UISoundService.ERROR, UISoundService.OPEN, UISoundService.REWARD, UISoundService.RUN_START, UISoundService.ABILITY_READY, UISoundService.ABILITY_BLOCKED],
		"Der explizite Aktivierungsvertrag enthält genau die verbindlichen Soundrollen"
	)

	var settings := UISettingsState.new()
	settings.master_volume = 0.40
	settings.ui_volume = 0.25
	settings.effects_volume = 0.0
	settings.music_volume = 0.70
	settings.ui_muted = true
	service.configure(settings)
	_near(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master"))), 0.40, 0.002, "Masterbus verwendet lineare Prozentwerte")
	_near(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"UI"))), 0.25, 0.002, "UI-Bus verwendet seinen eigenen Regler")
	_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"UI")), "UI-Stummschaltung wirkt auf den UI-Bus")
	_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Effects")), "Null Prozent schaltet einen Bus vollständig stumm")

	var panel := Control.new()
	root.add_child(panel)
	var initial_button := Button.new()
	panel.add_child(initial_button)
	service.wire_tree(panel)
	_true(bool(initial_button.get_meta(&"alveolus_sound_wired", false)), "Bestehende Buttons werden genau einmal akustisch verdrahtet")
	var dynamic_button := Button.new()
	panel.add_child(dynamic_button)
	var third_button := Button.new()
	panel.add_child(third_button)
	var campus_card := CampusBuildingCard.new()
	panel.add_child(campus_card)
	await process_frame
	await process_frame
	_true(bool(dynamic_button.get_meta(&"alveolus_sound_wired", false)), "Später erzeugte Buttons erhalten dasselbe Feedback")
	_true(bool(third_button.get_meta(&"alveolus_sound_wired", false)), "Mehrere dynamische Buttons werden jeweils genau einmal verdrahtet")
	_true(bool(campus_card.get_meta(&"alveolus_sound_wired", false)), "Campusgebäude verwenden denselben expliziten Soundvertrag")
	var before_player := service.next_player
	service.play(UISoundService.PRESS)
	_equal(service.next_player, (before_player + 1) % UISoundService.PLAYER_COUNT, "Ein Cue belegt genau einen Poolplayer")
	var blocked_player_index := service.next_player
	service.play(UISoundService.ABILITY_BLOCKED)
	_equal(service.next_player, (blocked_player_index + 1) % UISoundService.PLAYER_COUNT, "Eine noch abklingende Fähigkeit erzeugt genau einen leichten Cue")
	_near(service.players[blocked_player_index].volume_db, -12.0, 0.01, "Der Blockiert-Cue bleibt deutlich leiser als eine Bestätigung")

	# Pointer movement and hover are deliberately silent, including the custom
	# campus controls. A dense sweep must not accidentally model keyboard focus.
	initial_button.grab_focus()
	await process_frame
	var before_mouse_sweep := service.next_player
	for _step in range(64):
		service._input(InputEventMouseMotion.new())
		initial_button.mouse_entered.emit()
		dynamic_button.mouse_entered.emit()
		campus_card.mouse_entered.emit()
	_equal(service.next_player, before_mouse_sweep, "Dichter Mouse-Sweep und Campus-Hover erzeugen null Fokus-Cues")
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	service._input(mouse_press)
	dynamic_button.grab_focus()
	_equal(service.next_player, before_mouse_sweep, "Mausfokus bleibt auch nach einem Pointer-Klick stumm")

	# One deliberate navigation event arms exactly its resulting focus change.
	var keyboard_navigation := InputEventKey.new()
	keyboard_navigation.physical_keycode = KEY_TAB
	keyboard_navigation.pressed = true
	var before_keyboard_focus := service.next_player
	service._input(keyboard_navigation)
	third_button.grab_focus()
	_equal(service.next_player, (before_keyboard_focus + 1) % UISoundService.PLAYER_COUNT, "Tastaturnavigation erzeugt je Fokuswechsel genau einen Cue")
	third_button.grab_focus()
	_equal(service.next_player, (before_keyboard_focus + 1) % UISoundService.PLAYER_COUNT, "Unveränderter Fokus wiederholt den Tastatur-Cue nicht")

	var gamepad_navigation := InputEventJoypadButton.new()
	gamepad_navigation.button_index = JOY_BUTTON_DPAD_LEFT
	gamepad_navigation.pressed = true
	var before_gamepad_focus := service.next_player
	service._input(gamepad_navigation)
	initial_button.grab_focus()
	_equal(service.next_player, (before_gamepad_focus + 1) % UISoundService.PLAYER_COUNT, "Gamepadnavigation erzeugt je Fokuswechsel genau einen Cue")

	# Activation uses explicit roles. Captions have no acoustic meaning anymore,
	# while the legacy metadata key remains supported for existing callers.
	initial_button.text = "Zurück"
	_equal(service._cue_for_button(initial_button), UISoundService.PRESS, "Deutscher Buttontext leitet keine Soundrolle mehr ab")
	_true(UISoundService.set_sound_role(initial_button, UISoundService.BACK), "Buttons akzeptieren eine explizite Soundrolle per API")
	_equal(service._cue_for_button(initial_button), UISoundService.BACK, "Die explizite Back-Rolle wird unverändert aufgelöst")
	var before_activation := service.next_player
	initial_button.pressed.emit()
	_equal(service.next_player, (before_activation + 1) % UISoundService.PLAYER_COUNT, "Eine Aktivierung erzeugt genau einen Rollen-Cue")
	_true(UISoundService.set_sound_role(initial_button, UISoundService.NONE), "NONE ist eine gültige explizite Soundrolle")
	before_activation = service.next_player
	initial_button.pressed.emit()
	_equal(service.next_player, before_activation, "NONE unterdrückt Aktivierungsfeedback vollständig")
	dynamic_button.set_meta(&"ui_sound_cue", UISoundService.CONFIRM)
	_equal(service._cue_for_button(dynamic_button), UISoundService.CONFIRM, "Bestehende ui_sound_cue-Aufrufer bleiben kompatibel")
	before_activation = service.next_player
	dynamic_button.pressed.emit()
	_equal(service.next_player, (before_activation + 1) % UISoundService.PLAYER_COUNT, "Legacy-Metadata erzeugt ebenfalls genau einen Aktivierungs-Cue")
	_equal(UISoundService.sound_role(campus_card), UISoundService.OPEN, "Campusgebäude erhalten explizit die Rolle OPEN")
	before_activation = service.next_player
	campus_card.selected.emit()
	_equal(service.next_player, (before_activation + 1) % UISoundService.PLAYER_COUNT, "Campusauswahl erzeugt genau einen Open-Cue")
	for player in service.players:
		player.stop()
		player.stream = null
	service.streams.clear()
	await process_frame
	panel.free()
	service.free()


func _test_save_v7_settings_roundtrip() -> void:
	var meta := MetaProgressionState.new(func() -> int: return 900000)
	meta.reset_defaults(900000)
	var settings := UISettingsState.new()
	settings.master_volume = 0.31
	settings.ui_volume = 0.47
	settings.ui_scale = 0.90
	settings.reduce_motion = true
	settings.show_discovery_info = false
	settings.show_boss_target_arrows = false
	settings.show_event_target_arrows = false
	settings.show_character_health_bar = true
	settings.glyph_mode = UISettingsState.GLYPH_GAMEPAD
	settings.confirm_run_restart = false
	settings.input_bindings = {
		"active_ability_1": [
			{"type": "key", "physical_keycode": KEY_Q, "keycode": 0},
			{"type": "key", "physical_keycode": KEY_F, "keycode": 0},
		],
		"ui_info": [
			{"type": "key", "physical_keycode": KEY_I, "keycode": 0},
			{"type": "joy_button", "button_index": JOY_BUTTON_Y},
		],
	}
	meta.set_ui_settings(settings)
	var data := meta.to_dict()
	_equal(int(data.get("version", 0)), 7, "Einstellungen werden im Save-v7-Container gespeichert")
	var restored := MetaProgressionState.new(func() -> int: return 900000)
	_true(restored.load_dict(data), "Save v7 mit Einstellungen kann geladen werden")
	_near(restored.ui_settings.master_volume, 0.31, 0.0001, "Masterlautstärke überlebt den Savegame-Roundtrip")
	_near(restored.ui_settings.ui_volume, 0.47, 0.0001, "UI-Lautstärke überlebt den Savegame-Roundtrip")
	_equal(restored.ui_settings.ui_scale, 0.90, "Eine UI-Skalierung unter 100 Prozent überlebt den Savegame-Roundtrip")
	_true(restored.ui_settings.reduce_motion, "Reduzierte Bewegung überlebt den Savegame-Roundtrip")
	_true(not restored.ui_settings.show_discovery_info, "Ausdrücklich ausgeschaltete Hinweise überleben im Save-v7-Container")
	_true(not restored.ui_settings.show_boss_target_arrows and not restored.ui_settings.show_event_target_arrows, "Beide Zielpfeiloptionen überleben den Savegame-Roundtrip")
	_true(restored.ui_settings.show_character_health_bar, "Der Charakter-Lebensbalken überlebt den Savegame-Roundtrip")
	_equal(restored.ui_settings.glyph_mode, UISettingsState.GLYPH_GAMEPAD, "Glyphmodus überlebt den Savegame-Roundtrip")
	_true(not restored.ui_settings.confirm_run_restart, "Die ausgeschaltete Neustartbestätigung überlebt den Savegame-Roundtrip")
	_true(restored.ui_settings.input_bindings.has("ui_info"), "Eine angepasste ui_info-Belegung überlebt im aktuellen Saveformat")
	_equal((restored.ui_settings.input_bindings["ui_info"] as Array).size(), 2, "ui_info bewahrt Tastatur- und Gamepadklasse im Save-v7-Container")
	_equal((restored.ui_settings.input_bindings["active_ability_1"] as Array).size(), 2, "Zwei Tastaturplätze überleben unverändert im Save-v7-Container")
	var migrated := MetaProgressionState.new(func() -> int: return 900000)
	_true(migrated.load_dict({"version": 4, "research_points": 17}), "Save v4 wird weiterhin migriert")
	_equal(migrated.ui_settings.to_dict(), UISettingsState.new().to_dict(), "Save v4 erhält vollständige sichere Standardeinstellungen")


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
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


func _has_joy_button(events: Array[InputEvent], button_index: JoyButton) -> bool:
	for event in events:
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button_index:
			return true
	return false


func _has_device_independent_joy_button(events: Array[InputEvent], button_index: JoyButton) -> bool:
	for event in events:
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button_index:
			return event.device == -1
	return false


func _has_device_independent_joy_motion(events: Array[InputEvent], axis: JoyAxis, direction: float) -> bool:
	for event in events:
		if event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if motion.axis == axis and signf(motion.axis_value) == signf(direction):
				return motion.device == -1
	return false


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual == expected:
		return
	failures += 1
	printerr("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, tolerance: float, message: String) -> void:
	assertions += 1
	if absf(actual - expected) <= tolerance:
		return
	failures += 1
	printerr("FAIL: %s | expected=%f actual=%f" % [message, expected, actual])
