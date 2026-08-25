extends SceneTree

var assertions: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := ContentCatalog.loadout_module_definitions()
	var fresh_available := LoadoutAvailabilityPolicy.selectable_ids(definitions)
	_equal(definitions.size(), 9, "Der aktive Planungskatalog enthält drei Behandlungen und sechs Aktive")
	_equal(fresh_available.size(), 1, "Vor Forschung und Fallabschluss ist ausschließlich Impuls verfügbar")
	_true(bool(fresh_available.get(&"treatment_precision", false)), "Impuls ist ohne Forschung verfügbar")
	for id in [&"ability_defense_burst", &"ability_treatment_line"]:
		_true(not bool(fresh_available.get(id, false)), "%s besitzt seinen eigenen Fortschrittsvertrag" % String(id))
	for id in [&"treatment_spread", &"treatment_pierce"]:
		_true(not bool(fresh_available.get(id, false)), "%s wartet auf seine Forschung" % String(id))
	for id in [&"ability_focus_field", &"ability_emergency_support", &"ability_protection_field", &"ability_sample_pull"]:
		_true(not bool(fresh_available.get(id, false)), "%s bleibt als graue aktive Fähigkeit gesperrt" % String(id))

	var default_loadout := PreparedLoadout.default_loadout()
	_equal(default_loadout.treatment_id, &"treatment_precision", "Der Standardplan startet mit Präzisem Impuls")
	_equal(default_loadout.ability_ids, [], "Der Standardplan startet vor den Fortschrittsfreischaltungen ohne aktive Fähigkeit")
	_true(default_loadout.passive_ids.is_empty() and default_loadout.reserve_id == &"", "Der Standardplan enthält keine Passive oder Reserve")
	_true(LoadoutValidator.validate(default_loadout, definitions, fresh_available, 8).valid, "Der frische Ein-Komponenten-Plan ist vor Fortschrittsfreischaltungen gültig")
	var burst_owned := {&"unlock_defense_burst": 1}
	var first_case_available := LoadoutAvailabilityPolicy.selectable_ids(definitions, burst_owned, true)
	_true(bool(first_case_available.get(&"ability_defense_burst", false)) and not bool(first_case_available.get(&"ability_treatment_line", false)), "Fall-1-Abschluss öffnet Slot 2, besitzt den Lazer aber noch nicht")
	var lazer_owned := {&"unlock_defense_burst": 1, &"unlock_treatment_line": 1}
	_true(bool(LoadoutAvailabilityPolicy.selectable_ids(definitions, lazer_owned, true).get(&"ability_treatment_line", false)), "Fall-1-Meilenstein plus Forschungsrang schalten den Lazer frei")
	_equal(LoadoutAvailabilityPolicy.active_ability_slot_limit(false), 1, "Vor Fall 1 steht genau ein Aktivplatz bereit")
	_equal(LoadoutAvailabilityPolicy.active_ability_slot_limit(true), 2, "Nach Fall 1 stehen zwei Aktivplätze bereit")
	_true(not LoadoutAvailabilityPolicy.slot_is_available(LoadoutSlotId.ACTIVE_2, false), "Aktiv 2 ist vor Fall 1 gesperrt")
	_true(LoadoutAvailabilityPolicy.slot_unavailable_reason(LoadoutSlotId.ACTIVE_2, false).contains("Fall 1"), "Aktiv 2 erklärt seinen Meilenstein")

	var historical := PreparedLoadout.create(
		&"treatment_spread",
		[&"ability_focus_field", &"ability_treatment_line"],
		[&"therapy_precision", &"quick_test"],
		&"reserve_buffer"
	)
	var historical_snapshot := historical.to_dict()
	var sanitized := LoadoutAvailabilityPolicy.sanitized_copy(historical, definitions)
	_equal(sanitized.treatment_id, &"treatment_precision", "Eine noch nicht erforschte historische Behandlung fällt auf den Präzisen Impuls zurück")
	_equal(sanitized.ability_ids, [], "Ein historischer Lazer umgeht weder Fallmeilenstein noch ersten Aktivplatz")
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
		if research.id == LoadoutAvailabilityPolicy.TREATMENT_LINE_RESEARCH_ID:
			_true(not LoadoutAvailabilityPolicy.research_purchase_enabled(research, false), "Fetter lazer ist vor Fall 1 nicht kaufbar")
			_true(LoadoutAvailabilityPolicy.research_purchase_enabled(research, true), "Fetter lazer wird nach Fall 1 als manuelle Forschung kaufbar")
			_true(LoadoutAvailabilityPolicy.research_icon_kind(research, false) == &"question", "Der gesperrte Lazer nutzt die Fragezeichenglyphe")
			_true(LoadoutAvailabilityPolicy.research_status(research, definitions, false).contains("Fall 1"), "Der gesperrte Lazer erklärt seinen Fallmeilenstein")
			_equal(LoadoutAvailabilityPolicy.research_effective_rank(research, research.max_level, false), 0, "Ein alter Forschungsrang umgeht den Meilenstein nicht")
		else:
			_true(LoadoutAvailabilityPolicy.research_purchase_enabled(research), "%s bleibt im aktuellen Testschritt kaufbar" % String(research.id))
	meta.research_ranks[LoadoutAvailabilityPolicy.TREATMENT_LINE_RESEARCH_ID] = 0
	meta.get_level_record(LoadoutAvailabilityPolicy.FIRST_CASE_LEVEL_ID).victories = 1
	var available := LoadoutAvailabilityPolicy.selectable_ids(definitions, meta.research_ranks, true)
	_equal(available.size(), 4, "Fall 1 allein ergänzt keinen automatisch besessenen Lazer")
	var researched_sanitized := LoadoutAvailabilityPolicy.sanitized_copy(historical, definitions, meta.research_ranks, true)
	_equal(researched_sanitized.treatment_id, &"treatment_spread", "Eine erforschte historische Behandlung bleibt erhalten")
	_equal(researched_sanitized.ability_ids, [], "Ohne manuellen Forschungsrang entfernt die effektive Kopie den historischen Lazer")
	var lazer_research: ResearchDefinition
	for research in ContentCatalog.research_definitions():
		if research.id == LoadoutAvailabilityPolicy.TREATMENT_LINE_RESEARCH_ID:
			lazer_research = research
			break
	_true(lazer_research != null and lazer_research.cost_for_rank(0) == 0, "Die manuelle Lazer-Freischaltung kostet nach Fall 1 null Forschung")
	var research_before := meta.research_points
	await _test_lazer_hud_transition(meta, lazer_research)
	_equal(meta.research_points, research_before, "Der kostenlose Lazer-Kauf verändert den Forschungsstand nicht")
	available = LoadoutAvailabilityPolicy.selectable_ids(definitions, meta.research_ranks, true)
	_equal(available.size(), 5, "Nach dem manuellen Klick gehört der Lazer zum Planungspool")
	researched_sanitized = LoadoutAvailabilityPolicy.sanitized_copy(historical, definitions, meta.research_ranks, true)
	_equal(researched_sanitized.ability_ids, [&"ability_treatment_line"], "Der gespeicherte kostenlose Rang erhält den Lazer in der effektiven Kopie")
	_true(SimpleIcon.supports(&"question"), "Die semantische Fragezeichenglyphe ist zentral registriert")

	var completed_case_loadout := PreparedLoadout.create(
		&"treatment_precision",
		[&"ability_defense_burst", &"ability_treatment_line"]
	)
	await _test_hud(definitions, available, completed_case_loadout, meta)
	_finish()


func _test_lazer_hud_transition(meta: MetaProgressionState, lazer_research: ResearchDefinition) -> void:
	get_root().size = Vector2i(1280, 720)
	var hud := GameHUD.new()
	get_root().add_child(hud)
	await process_frame
	await process_frame
	hud.set_progression_availability(true, true)
	hud.show_research_tabs(meta, ContentCatalog.research_definitions(), TalentDefinition.definitions())
	await process_frame
	var before_item: ProgressionScreenViewModel.ResearchItemViewModel
	for item in hud.progression_research_items:
		if item.id() == LoadoutAvailabilityPolicy.TREATMENT_LINE_RESEARCH_ID:
			before_item = item
			break
	_true(before_item != null, "Die echte HUD-Brücke veröffentlicht das Lazer-Forschungsfeld")
	if before_item != null:
		_equal(before_item.state(), ProgressionScreenViewModel.ItemState.AVAILABLE, "Nach Fall 1 ist der ungekaufte Lazer verfügbar")
		_true(before_item.interactive(), "Der kostenlose Lazer ist nach Fall 1 anklickbar")
		_equal(before_item.cost_text(), "Kostenlos", "Das Lazer-Feld zeigt den Nullkostenvertrag sichtbar")
		_true(not before_item.milestone_lock_cover(), "Nach Fall 1 ist die Vollflächen-Padlocksperre entfernt")
	var lazer_button := hud.progression_screen.research_action(LoadoutAvailabilityPolicy.TREATMENT_LINE_RESEARCH_ID)
	_true(lazer_button != null and lazer_button.find_child("ResearchMilestoneLock", true, false) == null, "Die echte Karte trägt nach Fall 1 keine Padlockfläche")
	_true(meta.purchase(lazer_research), "Der kostenlose Forschungsklick speichert den Lazer-Rang")
	hud.show_research_tabs(meta, ContentCatalog.research_definitions(), TalentDefinition.definitions())
	await process_frame
	var after_item: ProgressionScreenViewModel.ResearchItemViewModel
	for item in hud.progression_research_items:
		if item.id() == LoadoutAvailabilityPolicy.TREATMENT_LINE_RESEARCH_ID:
			after_item = item
			break
	_true(after_item != null, "Der gekaufte Lazer bleibt im echten HUD-Forschungsmodell")
	if after_item != null:
		_equal(after_item.state(), ProgressionScreenViewModel.ItemState.ACTIVE, "Nach dem Klick ist der Lazer aktiv")
		_true(not after_item.interactive(), "Der einmalige Lazer-Kauf ist danach abgeschlossen")
	hud.queue_free()
	await process_frame


func _test_hud(definitions: Dictionary, available: Dictionary, loadout: PreparedLoadout, meta: MetaProgressionState) -> void:
	get_root().size = Vector2i(1280, 720)
	var hud := GameHUD.new()
	get_root().add_child(hud)
	await process_frame
	await process_frame
	var reasons: Dictionary = {}
	for id in definitions:
		var reason := LoadoutAvailabilityPolicy.unavailable_reason(id, definitions, meta.research_ranks, true)
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

	hud.set_progression_availability(true, true)
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
