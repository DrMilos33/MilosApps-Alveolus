extends SceneTree

var assertions: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := ContentCatalog.loadout_module_definitions()
	var fresh_available := LoadoutAvailabilityPolicy.selectable_ids(definitions)
	_equal(definitions.size(), 9, "Der aktive Planungskatalog enthält drei Behandlungen und sechs Aktive")
	_equal(fresh_available.size(), 3, "Frisch verfügbar sind Präziser Impuls und zwei aktive Fähigkeiten")
	for id in [&"treatment_precision", &"ability_defense_burst", &"ability_treatment_line"]:
		_true(bool(fresh_available.get(id, false)), "%s ist ohne Forschung verfügbar" % String(id))
	for id in [&"treatment_spread", &"treatment_pierce"]:
		_true(not bool(fresh_available.get(id, false)), "%s wartet auf seine Forschung" % String(id))
	for id in [&"ability_focus_field", &"ability_emergency_support", &"ability_protection_field", &"ability_sample_pull"]:
		_true(not bool(fresh_available.get(id, false)), "%s bleibt als graue aktive Fähigkeit gesperrt" % String(id))

	var default_loadout := PreparedLoadout.default_loadout()
	_equal(default_loadout.treatment_id, &"treatment_precision", "Der Standardplan startet mit Präzisem Impuls")
	_equal(default_loadout.ability_ids, [&"ability_defense_burst", &"ability_treatment_line"], "Der Standardplan verwendet nur die beiden aktiven Testfähigkeiten")
	_true(default_loadout.passive_ids.is_empty() and default_loadout.reserve_id == &"", "Der Standardplan enthält keine Passive oder Reserve")
	var default_validation := LoadoutValidator.validate(default_loadout, definitions, fresh_available, 8)
	_true(default_validation.valid, "Der Standardplan ist gegen die Verfügbarkeit gültig")
	_equal(default_validation.capacity_used, 6, "Der Standardplan benötigt sechs von acht Kapazität")

	var historical := PreparedLoadout.create(
		&"treatment_spread",
		[&"ability_focus_field", &"ability_treatment_line"],
		[&"therapy_precision", &"quick_test"],
		&"reserve_buffer"
	)
	var historical_snapshot := historical.to_dict()
	var sanitized := LoadoutAvailabilityPolicy.sanitized_copy(historical, definitions)
	_equal(sanitized.treatment_id, &"treatment_precision", "Eine noch nicht erforschte historische Behandlung fällt auf den Präzisen Impuls zurück")
	_equal(sanitized.ability_ids, [&"ability_treatment_line"], "Erlaubte Aktive behalten ihre Reihenfolge, ohne freie Plätze still zu befüllen")
	_true(sanitized.passive_ids.is_empty() and sanitized.reserve_id == &"", "Passive und Reserve werden nur aus der effektiven Kopie entfernt")
	_equal(historical.to_dict(), historical_snapshot, "Die historische Save-Kopie bleibt bei der Bereinigung unangetastet")
	_true(LoadoutValidator.validate(sanitized, definitions, fresh_available, 8).valid, "Die bereinigte Kopie ist spielbar")

	var intentionally_empty := PreparedLoadout.create(&"treatment_precision", [], [], &"")
	var empty_sanitized := LoadoutAvailabilityPolicy.sanitized_copy(intentionally_empty, definitions)
	_equal(empty_sanitized.ability_ids, [], "Bewusst leere Aktivplätze bleiben beim Runstart leer")
	var invalid := PreparedLoadout.create(&"unknown_treatment", [&"unknown_ability"], [&"quick_test"], &"reserve_buffer")
	var fallback := LoadoutAvailabilityPolicy.sanitized_copy(invalid, definitions)
	_equal(fallback.treatment_id, &"treatment_precision", "Eine unbekannte Behandlung fällt auf den Präzisen Impuls zurück")
	_true(fallback.ability_ids.is_empty() and fallback.passive_ids.is_empty() and fallback.reserve_id == &"", "Unbekannte und gesperrte IDs werden nicht durch versteckte Komponenten ersetzt")

	var meta := MetaProgressionState.new()
	meta.set_unlimited_test_progression(true)
	for research in ContentCatalog.research_definitions():
		_true(SimpleIcon.supports(research.id), "%s besitzt eine registrierte semantische Forschungsglyphe" % String(research.id))
		meta.research_ranks[research.id] = research.max_level
		_true(LoadoutAvailabilityPolicy.research_purchase_enabled(research), "%s bleibt im aktuellen Testschritt kaufbar" % String(research.id))
	var available := LoadoutAvailabilityPolicy.selectable_ids(definitions, meta.research_ranks)
	_equal(available.size(), 5, "Beide Forschungsbehandlungen erweitern den Planungspool")
	var researched_sanitized := LoadoutAvailabilityPolicy.sanitized_copy(historical, definitions, meta.research_ranks)
	_equal(researched_sanitized.treatment_id, &"treatment_spread", "Eine erforschte historische Behandlung bleibt erhalten")

	await _test_hud(definitions, available, default_loadout, meta)
	_finish()


func _test_hud(definitions: Dictionary, available: Dictionary, loadout: PreparedLoadout, meta: MetaProgressionState) -> void:
	get_root().size = Vector2i(1280, 720)
	var hud := GameHUD.new()
	get_root().add_child(hud)
	await process_frame
	await process_frame
	var reasons: Dictionary = {}
	for id in definitions:
		var reason := LoadoutAvailabilityPolicy.unavailable_reason(id, definitions, meta.research_ranks)
		if not reason.is_empty():
			reasons[id] = reason
	var validation := LoadoutValidator.validate(loadout, definitions, available, 8)
	hud.show_preparation({
		"level_title": "Verfügbarkeitstest",
		"level_description": "Prüft den vorläufigen Kampfkatalog.",
		"duration_text": "3:00 Min.",
		"boss_time_text": "2:15 Min.",
		"validation": validation,
		"available_ids": available,
		"availability_reasons": reasons,
		"slot_snapshot": {
			LoadoutSlotId.TREATMENT: loadout.treatment_id,
			LoadoutSlotId.ACTIVE_1: loadout.ability_ids[0],
			LoadoutSlotId.ACTIVE_2: loadout.ability_ids[1],
			LoadoutSlotId.PASSIVE_1: &"",
			LoadoutSlotId.PASSIVE_2: &"",
			LoadoutSlotId.RESERVE: &"",
		},
	}, definitions.values(), loadout)
	await process_frame
	_equal(hud.preparation_component_buttons.size(), 3, "Der Behandlungsplatz zeigt alle drei Behandlungen")
	for id in LoadoutAvailabilityPolicy.AVAILABLE_TREATMENT_IDS:
		var state := StringName((hud.preparation_component_buttons[id] as Button).get_meta(&"catalog_state", &"locked"))
		_true(state != &"locked", "%s ist im Behandlungsplatz freigegeben" % String(id))

	hud._on_preparation_slot_pressed(LoadoutSlotId.ACTIVE_1)
	await process_frame
	_equal(hud.preparation_component_buttons.size(), 6, "Der Aktivplatz zeigt alle sechs aktiven Fähigkeiten")
	for id in LoadoutAvailabilityPolicy.AVAILABLE_ABILITY_IDS:
		var state := StringName((hud.preparation_component_buttons[id] as Button).get_meta(&"catalog_state", &"locked"))
		_true(state != &"locked", "%s ist im Aktivplatz freigegeben" % String(id))
	for id in [&"ability_focus_field", &"ability_emergency_support", &"ability_protection_field", &"ability_sample_pull"]:
		var button := hud.preparation_component_buttons[id] as Button
		_true(not button.disabled and not bool(button.get_meta(&"catalog_available", true)), "%s bleibt sichtbar und fokussierbar, aber nicht auswählbar" % String(id))
		_true(String(button.get_meta(&"catalog_lock_reason", "")).contains("vorgemerkt"), "%s erklärt die vorläufige Sperre" % String(id))

	hud.show_research_tabs(meta, ContentCatalog.research_definitions(), TalentDefinition.definitions())
	await process_frame
	_equal(hud.progression_research_items.size(), ContentCatalog.research_definitions().size(), "Alle Forschungswerte bleiben sichtbar")
	for item in hud.progression_research_items:
		_equal(item.state(), ProgressionScreenViewModel.ItemState.ACTIVE, "%s ist im Forschungsbrett vollständig ausgebaut" % String(item.id()))
		_true(not item.interactive(), "%s ist auf Maximalrang nicht erneut kaufbar" % String(item.id()))

	hud.queue_free()
	await process_frame


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s · erwartet=%s erhalten=%s" % [message, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_LOADOUT_AVAILABILITY_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("ALVEOLUS_LOADOUT_AVAILABILITY_FAILED assertions=%d failures=%d" % [assertions, failures.size()])
	quit(1)
