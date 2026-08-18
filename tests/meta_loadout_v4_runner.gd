extends SceneTree

var assertions := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_loadout_validation()
	_test_mastery_and_talents()
	_test_unlimited_test_progression()
	_test_v3_migration_and_v5_roundtrip()
	_test_v4_to_v5_migration_preserves_progression()
	_test_v5_settings_roundtrip_and_validation()
	_test_v5_repository_roundtrip()
	if failures == 0:
		print("ALVEOLUS_META_LOADOUT_V5_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_META_LOADOUT_V5_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)

func _test_loadout_validation() -> void:
	var definitions := ContentCatalog.loadout_module_definitions()
	var unlocked: Dictionary = {}
	for id in definitions:
		unlocked[id] = true
	var loadout := PreparedLoadout.default_loadout()
	var result := LoadoutValidator.validate(loadout, definitions, unlocked, 8)
	_equal(result.valid, true, "Der Starterplan ist gültig")
	_equal(result.capacity_used, 6, "Starterkomponenten kosten sechs Kapazität")
	_equal(loadout.slot_count(), 3, "Der neue Starterplan zählt ausschließlich seine sichtbaren aktiven Plätze")
	_equal(loadout.reserve_id, &"", "Neue Starterpläne beginnen ohne Reserve")

	loadout.passive_ids = [&"stability_reserve", &"therapy_precision"]
	loadout.reserve_id = &"reserve_buffer"
	result = LoadoutValidator.validate(loadout, definitions, unlocked, 8)
	_equal(result.valid, true, "Reserve kostet vor dem Einwechseln keine Kapazität")
	var swap_result := LoadoutValidator.validate_reserve_swap(loadout, &"stability_reserve", definitions, unlocked, 8)
	_equal(swap_result.valid, false, "Ein Reservewechsel darf die Kapazität nicht überschreiten")
	_equal(swap_result.capacity_used, 9, "Reservekosten werden nach dem Wechsel exakt berechnet")

	var duplicated := loadout.duplicate_loadout()
	duplicated.ability_ids.append(&"ability_focus_field")
	result = LoadoutValidator.validate(duplicated, definitions, unlocked, 10)
	_equal(result.valid, false, "Mehr als zwei Aktivplätze und Duplikate werden abgelehnt")
	_true(result.errors.size() >= 2, "Validierung meldet alle relevanten Planfehler gemeinsam")

	var restored := PreparedLoadout.from_dict(loadout.to_dict())
	_equal(restored.treatment_id, loadout.treatment_id, "Grundbehandlung überlebt die Serialisierung")
	_equal(restored.ability_ids, loadout.ability_ids, "Aktivplätze überleben die Serialisierung")
	_equal(restored.reserve_id, loadout.reserve_id, "Reserve überlebt die Serialisierung")

func _test_mastery_and_talents() -> void:
	_equal(MasteryObjectiveDefinition.definitions().size(), 10, "Der Katalog enthält genau zehn Meisterschaftsziele")
	_equal(MasteryObjectiveDefinition.total_reward_points(), 10, "Die aktuellen Fälle vergeben insgesamt zehn Talentpunkte")
	_equal(TalentDefinition.definitions().size(), 12, "Das Brett enthält zwölf Talente")
	_equal(TalentDefinition.total_cost(), 19, "Alle Talente zusammen kosten neunzehn Punkte")

	var tracker := MasteryTracker.new()
	tracker.begin_run(&"localized_focus", 135.0)
	tracker.record_finding_revealed(90.0)
	tracker.record_boss_spawned(135.0)
	tracker.record_stability(60.0, 100.0)
	var fall_one := tracker.completed_candidates(true)
	_true(fall_one.has(&"fall_1_first_victory"), "Fall-1-Sieg erfüllt das erste Ziel")
	_true(fall_one.has(&"fall_1_early_finding"), "Befund vor dem Boss wird erkannt")
	_true(fall_one.has(&"fall_1_healthy_win"), "Finaler Zustand von mindestens 50 Prozent wird erkannt")

	tracker.begin_run(&"spreading_infection", 180.0)
	tracker.record_ability_used(0)
	tracker.record_ability_used(1)
	var fall_two_entry := tracker.completed_candidates(true)
	_true(fall_two_entry.has(&"fall_2_reserve_win"), "Der stabile Alt-ID-Meilenstein wird jetzt durch je einen Einsatz beider Fähigkeiten erfüllt")
	_true(not fall_two_entry.has(&"fall_2_active_usage"), "Das anspruchsvollere Einsatzziel verlangt weiterhin vier Nutzungen je Fähigkeit")
	for ignored in range(3):
		tracker.record_ability_used(0)
		tracker.record_ability_used(1)
	var fall_two := tracker.completed_candidates(true)
	_true(fall_two.has(&"fall_2_reserve_win"), "Der kompatible Ziel-ID bleibt nach weiteren Fähigkeitseinsätzen erfüllt")
	_true(fall_two.has(&"fall_2_active_usage"), "Vier Einsätze beider Fähigkeiten werden erfasst")

	tracker.begin_run(&"severe_pneumonia", 225.0)
	tracker.record_boss_spawned(225.0)
	tracker.record_boss_defeated(269.9)
	tracker.record_stability(24.0, 100.0)
	var fall_three := tracker.completed_candidates(true)
	_true(fall_three.has(&"fall_3_fast_boss"), "Bosskontrolle innerhalb 45 Sekunden wird erkannt")
	_true(not fall_three.has(&"fall_3_safe_condition"), "Unterschreiten von 25 Prozent verhindert das Sicherheitsziel")

	var meta := MetaProgressionState.new(func() -> int: return 500000)
	meta.reset_defaults(500000)
	var starter_modules := meta.unlocked_module_ids(ContentCatalog.loadout_module_definitions(), ContentCatalog.research_definitions())
	_true(starter_modules.has(&"treatment_precision"), "Starter-Grundbehandlung ist freigeschaltet")
	_true(starter_modules.has(&"ability_focus_field"), "Starterfähigkeit ist freigeschaltet")
	_true(not starter_modules.has(&"treatment_spread"), "Ungekaufte Behandlung bleibt gesperrt")
	_true(not meta.validate_prepared_loadout(PreparedLoadout.default_loadout(), ContentCatalog.loadout_module_definitions(), ContentCatalog.research_definitions()).valid, "Forschungsbesitz bleibt von der vorläufigen Testverfügbarkeit getrennt")
	_true(LoadoutValidator.validate(PreparedLoadout.default_loadout(), ContentCatalog.loadout_module_definitions(), LoadoutAvailabilityPolicy.selectable_ids(ContentCatalog.loadout_module_definitions()), meta.preparation_capacity()).valid, "Die Testverfügbarkeit validiert den neuen Standardplan")
	meta.research_ranks[&"unlock_spread_treatment"] = 1
	var purchased_modules := meta.unlocked_module_ids(ContentCatalog.loadout_module_definitions(), ContentCatalog.research_definitions())
	_true(purchased_modules.has(&"treatment_spread"), "Forschung schaltet das zugehörige Modul frei")
	meta.apply_mastery_candidates([
		&"intro_complete", &"fall_1_first_victory", &"fall_1_early_finding", &"fall_1_healthy_win"
	])
	_equal(meta.talent_points_earned(), 4, "Vier einmalige Ziele ergeben vier Talentpunkte")
	_equal(meta.set_talent_selection([&"organization_2"]), false, "Abhängigkeiten können nicht übersprungen werden")
	_equal(meta.set_talent_selection([&"organization_1", &"organization_2"]), true, "Vier Punkte aktivieren beide Organisationstalente")
	_equal(meta.loadout_capacity(), 10, "Organisationstalente erhöhen die Kapazität auf zehn")
	_equal(meta.preparation_capacity(), 10, "Vorbereitungs-API verwendet dieselbe Talentkapazität")
	_equal(meta.available_talent_points(), 0, "Ausgegebene Talentpunkte werden korrekt abgezogen")
	_equal(meta.set_talent_active(&"organization_1", false), false, "Eine belegte Talentvoraussetzung wird nicht mit allen Nachfolgern still entfernt")
	_true(meta.has_talent(&"organization_1") and meta.has_talent(&"organization_2"), "Der blockierte Elternklick lässt den sichtbaren Ast unverändert")
	_true(meta.set_talent_active(&"organization_2", false) and meta.set_talent_active(&"organization_1", false), "Nachfolger und Voraussetzung lassen sich ausdrücklich von außen nach innen zurücksetzen")
	var complete_meta := MetaProgressionState.new(func() -> int: return 500000)
	complete_meta.reset_defaults(500000)
	var every_objective: Array[StringName] = []
	for definition in MasteryObjectiveDefinition.definitions():
		every_objective.append(definition.id)
	_equal(complete_meta.apply_mastery_candidates(every_objective).size(), 10, "Alle zehn Meisterschaften werden genau einmal gutgeschrieben")
	_equal(complete_meta.apply_mastery_candidates(every_objective).size(), 0, "Meisterschaft kann nicht doppelt gutgeschrieben werden")
	_equal(complete_meta.talent_points_earned(), 10, "Aktuell sind höchstens zehn Talentpunkte erreichbar")
	var every_talent: Array[StringName] = []
	for definition in TalentDefinition.definitions():
		every_talent.append(definition.id)
	_true(not complete_meta.set_talent_selection(every_talent), "Zehn Punkte können nicht das neunzehn Punkte teure Brett aktivieren")

func _test_v3_migration_and_v5_roundtrip() -> void:
	var meta := MetaProgressionState.new(func() -> int: return 600000)
	var version_three := {
		"version": 3,
		"research_points": 321,
		"passive_seconds": 900.0,
		"last_seen_unix": 600000,
		"research_ranks": {"stability_reserve": 2, "therapy_precision": 1, "sample_logistics": 3},
		"highest_unlocked_level": 2,
		"level_records": {"localized_focus": {"attempts": 2, "victories": 1, "best_time": 170.0}},
		"intro_skipped": true,
		"seen_discovery_ids": ["pneumococcus"],
		"tutorial_status": {"movement": true},
	}
	_true(meta.load_dict(version_three), "Savegame-Version 3 wird nach Version 5 migriert")
	_equal(meta.rank(&"sample_logistics"), 3, "Migration bewahrt bestehende Forschungsränge")
	_equal(meta.research_points, 321, "Migration bewahrt Forschungspunkte")
	var migrated_plan := meta.get_prepared_loadout(&"localized_focus")
	_equal(migrated_plan.treatment_id, &"treatment_precision", "Migration setzt die präzise Grundbehandlung")
	_equal(migrated_plan.ability_ids, [&"ability_defense_burst", &"ability_treatment_line"], "Migration setzt beide aktiven Testfähigkeiten")
	_true(migrated_plan.passive_ids.is_empty(), "Migration übernimmt keine Passivmodule in neue Pläne")
	_equal(migrated_plan.reserve_id, &"", "Migration erzeugt für neue Pläne keine sichtbare Reserve")

	var first_seed := meta.get_or_create_case_seed(&"localized_focus")
	_equal(meta.get_or_create_case_seed(&"localized_focus"), first_seed, "Briefing behält seinen Seed beim erneuten Öffnen")
	meta.clear_case_seed(&"localized_focus")
	_true(meta.get_or_create_case_seed(&"localized_focus") != first_seed, "Ein abgeschlossener Fall kann einen neuen Seed erhalten")

	meta.apply_mastery_candidates([&"intro_complete", &"fall_1_first_victory"])
	_true(meta.set_talent_selection([&"organization_1"]), "Eine aktuelle Talentverteilung kann am Astanfang gesetzt werden")
	var custom := migrated_plan.duplicate_loadout()
	custom.passive_ids = [&"sample_logistics"]
	meta.set_prepared_loadout(&"localized_focus", custom)
	var data := meta.to_dict()
	_equal(int(data.get("version", 0)), 5, "Neue Spielstände verwenden Save-Version 5")
	_true((data.get("prepared_loadouts", {}) as Dictionary).get("localized_focus", {}).has("slots"), "V5 schreibt feste Planplätze statt variabler Listen")

	var restored := MetaProgressionState.new(func() -> int: return 600000)
	_true(restored.load_dict(data), "Save-Version 5 wird geladen")
	_equal(restored.rank(&"sample_logistics"), 3, "V5-Roundtrip bewahrt Forschungsränge")
	_true(restored.has_completed_mastery(&"intro_complete"), "V5-Roundtrip bewahrt Meisterschaft")
	_true(restored.has_talent(&"organization_1"), "V5-Roundtrip mit aktueller Baumrevision bewahrt die Talentverteilung")
	_equal(restored.get_prepared_loadout(&"localized_focus").passive_ids, [&"sample_logistics"], "V5-Roundtrip bewahrt fallbezogene Pläne")
	_equal(restored.get_or_create_case_seed(&"localized_focus"), meta.get_or_create_case_seed(&"localized_focus"), "V5-Roundtrip bewahrt Fall-Seeds")

func _test_v4_to_v5_migration_preserves_progression() -> void:
	var version_four := {
		"version": 4,
		"research_points": 987,
		"passive_seconds": 1234.5,
		"last_seen_unix": 700000,
		"active_job_id": "complex_case",
		"job_started_at": 696400,
		"job_finishes_at": 703600,
		"research_ranks": {
			"stability_reserve": 3,
			"therapy_precision": 2,
			"sample_logistics": 1,
			"unlock_spread_treatment": 1,
		},
		"lifetime_runs": 17,
		"prologue_seen": true,
		"highest_unlocked_level": 3,
		"level_records": {
			"localized_focus": {
				"attempts": 7,
				"victories": 4,
				"best_time": 162.25,
				"highest_analysis": 9,
				"best_defeats": 143,
			},
		},
		"intro_skipped": true,
		"seen_discovery_ids": ["pneumococcus", "analysis_pickup"],
		"tutorial_status": {"movement": true, "first_upgrade": true},
		"show_run_stats": true,
		"completed_mastery_ids": ["intro_complete", "fall_1_first_victory"],
		"talent_tree_revision": MetaProgressionState.TALENT_TREE_REVISION - 1,
		"selected_talent_ids": ["hold_card", "rapid_evaluation"],
		"prepared_loadouts": {
			"localized_focus": {
				"treatment_id": "treatment_spread",
				"ability_ids": ["ability_focus_field", "ability_emergency_support", "ability_defense_burst"],
				"passive_ids": ["stability_reserve", "therapy_precision", "sample_logistics"],
				"reserve_id": "preanalysis",
			},
		},
		"level_case_seeds": {"localized_focus": 424242, "spreading_infection": 777},
		"case_seed_nonce": 8,
	}
	var meta := MetaProgressionState.new(func() -> int: return 700000)
	_true(meta.load_dict(version_four), "Ein vollständiger V4-Spielstand wird akzeptiert")
	_equal(meta.research_points, 987, "V4-Migration bewahrt Forschungspunkte")
	_equal(meta.passive_seconds, 1234.5, "V4-Migration bewahrt angefangene Offline-Forschungszeit")
	_equal(meta.last_seen_unix, 700000, "V4-Migration bewahrt den Zeitanker")
	_equal(meta.active_job_id, &"complex_case", "V4-Migration bewahrt den aktiven Klinikfall")
	_equal(meta.job_started_at, 696400, "V4-Migration bewahrt den Klinikstart")
	_equal(meta.job_finishes_at, 703600, "V4-Migration bewahrt das Klinikende")
	_equal(meta.rank(&"stability_reserve"), 3, "V4-Migration bewahrt Forschungsränge")
	_equal(meta.rank(&"unlock_spread_treatment"), 1, "V4-Migration bewahrt Komponentenfreischaltungen")
	_equal(meta.lifetime_runs, 17, "V4-Migration bewahrt die Runanzahl")
	_true(meta.prologue_seen and meta.intro_skipped, "V4-Migration bewahrt Prolog- und Introstatus")
	_equal(meta.highest_unlocked_level, 3, "V4-Migration bewahrt die Fallfreischaltung")
	var record := meta.get_level_record(&"localized_focus")
	_equal(record.attempts, 7, "V4-Migration bewahrt Fallversuche")
	_equal(record.victories, 4, "V4-Migration bewahrt Fallsiege")
	_equal(record.best_time, 162.25, "V4-Migration bewahrt die Bestzeit")
	_equal(record.highest_analysis, 9, "V4-Migration bewahrt das höchste Level")
	_equal(record.best_defeats, 143, "V4-Migration bewahrt die meisten besiegten Bakterien")
	_true(meta.has_seen_discovery(&"pneumococcus") and meta.has_seen_discovery(&"analysis_pickup"), "V4-Migration bewahrt Entdeckungen")
	_true(bool(meta.tutorial_status.get(&"movement", false)), "V4-Migration bewahrt den Tutorialstatus")
	_true(meta.show_run_stats, "V4-Migration bewahrt die Anzeige dynamischer Werte")
	_true(meta.has_completed_mastery(&"intro_complete") and meta.has_completed_mastery(&"fall_1_first_victory"), "V4-Migration bewahrt Meisterschaft")
	_true(meta.selected_talent_ids.is_empty(), "Eine alte Baumrevision aktiviert keine inzwischen anders abhängigen Talente")
	_true(meta.talent_tree_refund_pending, "Eine alte Baumrevision markiert die zurückgegebenen Talentpunkte sichtbar")
	_equal(meta.talent_points_earned(), 2, "Der Refund verliert keine durch Meisterschaft verdienten Punkte")
	_equal(meta.available_talent_points(), 2, "Nach dem Refund stehen alle verdienten Talentpunkte erneut zur Verfügung")
	_equal(meta.get_or_create_case_seed(&"localized_focus"), 424242, "V4-Migration bewahrt den ersten Fall-Seed")
	_equal(meta.get_or_create_case_seed(&"spreading_infection"), 777, "V4-Migration bewahrt weitere Fall-Seeds")
	_equal(meta.case_seed_nonce, 8, "V4-Migration bewahrt den Seed-Zähler")
	var plan := meta.get_prepared_loadout(&"localized_focus")
	_equal(plan.treatment_id, &"treatment_spread", "V4-Migration bewahrt die Grundbehandlung")
	_equal(plan.ability_ids, [&"ability_focus_field", &"ability_emergency_support"], "V4-Migration übernimmt stabil die ersten zwei Aktivfähigkeiten")
	_equal(plan.passive_ids, [&"stability_reserve", &"therapy_precision"], "V4-Migration übernimmt stabil die ersten zwei Passivmodule")
	_equal(plan.reserve_id, &"preanalysis", "V4-Migration bewahrt die separate Reserve")
	var migrated_data := meta.to_dict()
	_equal(int(migrated_data.get("version", 0)), 5, "Der nächste Speicherstand wird als V5 geschrieben")
	_equal(int(migrated_data.get("talent_tree_revision", 0)), MetaProgressionState.TALENT_TREE_REVISION, "Der nächste Speicherstand kennzeichnet die aktuelle Talentbaumrevision")
	var saved_plan: Dictionary = (migrated_data.get("prepared_loadouts", {}) as Dictionary).get("localized_focus", {})
	_equal(int(saved_plan.get("slot_schema_version", 0)), LoadoutSlotSaveAdapter.SLOT_SCHEMA_VERSION, "Migrierte Pläne verwenden das feste Slotschema")
	var saved_slots: Dictionary = saved_plan.get("slots", {})
	_equal(saved_slots.get("active_1"), "ability_focus_field", "Aktivplatz 1 besitzt nach der Migration eine stabile ID")
	_equal(saved_slots.get("active_2"), "ability_emergency_support", "Aktivplatz 2 besitzt nach der Migration eine stabile ID")
	_equal(saved_slots.get("passive_1"), "stability_reserve", "Passivplatz 1 besitzt nach der Migration eine stabile ID")
	_equal(saved_slots.get("passive_2"), "therapy_precision", "Passivplatz 2 besitzt nach der Migration eine stabile ID")
	_equal(saved_slots.get("reserve"), "preanalysis", "Die Reserve bleibt außerhalb der Kapazität getrennt")
	_equal(meta.ui_settings.to_dict(), UISettingsState.new().to_dict(), "V4 erhält sichere Standardeinstellungen")

func _test_v5_settings_roundtrip_and_validation() -> void:
	var meta := MetaProgressionState.new(func() -> int: return 800000)
	meta.reset_defaults(800000)
	var settings := UISettingsState.new()
	settings.master_volume = 0.42
	settings.ui_volume = 0.55
	settings.effects_volume = 0.66
	settings.music_volume = 0.12
	settings.master_muted = true
	settings.effects_muted = true
	settings.ui_scale = 1.5
	settings.reduce_motion = true
	settings.glyph_mode = UISettingsState.GLYPH_GAMEPAD
	settings.fullscreen = true
	settings.input_bindings = {
		"ability_primary": [{"type": "key", "physical_keycode": KEY_Q, "keycode": 0}],
		"ability_secondary": [{"type": "joy_button", "button_index": JOY_BUTTON_LEFT_SHOULDER}],
	}
	meta.set_ui_settings(settings)
	# MetaProgressionState keeps an owned copy so later UI edits cannot mutate the save implicitly.
	settings.master_volume = 0.99
	_equal(meta.ui_settings.master_volume, 0.42, "Gespeicherte Einstellungen sind von der UI-Arbeitskopie entkoppelt")
	var data := meta.to_dict()
	var restored := MetaProgressionState.new(func() -> int: return 800000)
	_true(restored.load_dict(data), "Ein V5-Spielstand mit Einstellungen wird geladen")
	_equal(restored.ui_settings.master_volume, 0.42, "V5 bewahrt die Masterlautstärke")
	_equal(restored.ui_settings.ui_volume, 0.55, "V5 bewahrt die UI-Lautstärke")
	_equal(restored.ui_settings.effects_volume, 0.66, "V5 bewahrt die Effektlautstärke")
	_equal(restored.ui_settings.music_volume, 0.12, "V5 bewahrt die vorbereitete Musiklautstärke")
	_true(restored.ui_settings.master_muted and restored.ui_settings.effects_muted, "V5 bewahrt Stummschaltungen")
	_equal(restored.ui_settings.ui_scale, 1.5, "V5 bewahrt eine unterstützte UI-Skalierung")
	_true(restored.ui_settings.reduce_motion, "V5 bewahrt reduzierte Bewegung")
	_equal(restored.ui_settings.glyph_mode, UISettingsState.GLYPH_GAMEPAD, "V5 bewahrt die gewählte Eingabesymbolart")
	_true(restored.ui_settings.fullscreen, "V5 bewahrt den Desktop-Fenstermodus")
	_equal(restored.ui_settings.input_bindings, meta.ui_settings.input_bindings, "V5 bewahrt frei belegte Aktionen")

	var malformed := data.duplicate(true)
	malformed["ui_settings"] = {
		"master_volume": 9.0,
		"ui_volume": -3.0,
		"ui_scale": 1.74,
		"glyph_mode": "unknown",
		"input_bindings": "not a dictionary",
	}
	var sanitized := MetaProgressionState.new(func() -> int: return 800000)
	_true(sanitized.load_dict(malformed), "Ungültige einzelne Einstellungen beschädigen nicht den Spielstand")
	_equal(sanitized.ui_settings.master_volume, 1.0, "Zu hohe Lautstärke wird begrenzt")
	_equal(sanitized.ui_settings.ui_volume, 0.0, "Negative Lautstärke wird begrenzt")
	_equal(sanitized.ui_settings.ui_scale, 1.5, "Freie Skalierungswerte werden auf die nächste unterstützte Größe gesetzt")
	_equal(sanitized.ui_settings.glyph_mode, UISettingsState.GLYPH_AUTO, "Unbekannte Eingabesymbole fallen sicher auf Automatik zurück")
	_true(sanitized.ui_settings.input_bindings.is_empty(), "Ungültige Tastenbelegungen werden verworfen")
	_true(not sanitized.load_dict({"version": 6}), "Eine unbekannte zukünftige Save-Version wird abgelehnt")

func _test_v5_repository_roundtrip() -> void:
	var path := "user://alveolus_meta_save_v5_isolated_test.json"
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
	var source := MetaProgressionState.new(func() -> int: return 900000)
	source.reset_defaults(900000)
	source.research_points = 456
	source.active_job_id = &"follow_up"
	source.job_started_at = 899500
	source.job_finishes_at = 900700
	source.mark_discovery_seen(&"analysis_pickup")
	var settings := UISettingsState.new()
	settings.reduce_motion = true
	settings.ui_scale = 1.25
	source.set_ui_settings(settings)
	var plan := PreparedLoadout.create(
		&"treatment_precision",
		[&"ability_focus_field", &"ability_emergency_support"],
		[&"stability_reserve", &"therapy_precision"],
		&"sample_logistics"
	)
	source.set_prepared_loadout(&"localized_focus", plan)
	var repository := MetaSaveRepository.new(path)
	_true(repository.save(source), "Save-v5 wird als lokales JSON geschrieben")
	var loaded := MetaProgressionState.new(func() -> int: return 900000)
	_true(repository.load_into(loaded), "Save-v5 wird aus dem lokalen JSON geladen")
	_equal(loaded.research_points, 456, "Repository-Roundtrip bewahrt Forschung")
	_equal(loaded.active_job_id, &"follow_up", "Repository-Roundtrip bewahrt Klinikfortschritt")
	_true(loaded.has_seen_discovery(&"analysis_pickup"), "Repository-Roundtrip bewahrt Entdeckungen")
	_true(loaded.ui_settings.reduce_motion, "Repository-Roundtrip bewahrt Einstellungen")
	_equal(loaded.get_prepared_loadout(&"localized_focus").reserve_id, &"sample_logistics", "Repository-Roundtrip bewahrt feste Loadoutslots")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)

func _test_unlimited_test_progression() -> void:
	var meta := MetaProgressionState.new(func() -> int: return 550000)
	meta.reset_defaults(550000)
	meta.set_unlimited_test_progression(true)
	_true(meta.is_unlimited_test_progression(), "Der temporäre Testmodus kann aktiviert werden")
	_equal(meta.research_balance(), MetaProgressionState.UNLIMITED_TEST_POINT_POOL, "Forschung ist im Testmodus unbegrenzt verfügbar")
	var research := ContentCatalog.research_definitions()[0]
	var stored_points := meta.research_points
	_true(meta.purchase(research), "Forschung kann im Testmodus ohne Guthaben gekauft werden")
	_equal(meta.research_points, stored_points, "Testkäufe verbrauchen keine gespeicherte Forschung")
	var every_talent: Array[StringName] = []
	for definition in TalentDefinition.definitions():
		every_talent.append(definition.id)
	_true(meta.set_talent_selection(every_talent), "Alle Talente können im Testmodus gleichzeitig aktiviert werden")
	_equal(meta.available_talent_points(), MetaProgressionState.UNLIMITED_TEST_POINT_POOL, "Talentpunkte bleiben nach der Auswahl unbegrenzt")
	var saved := meta.to_dict()
	_true(not saved.has("unlimited_test_progression"), "Der temporäre Testmodus wird nicht im Spielstand gespeichert")
	var restored := MetaProgressionState.new(func() -> int: return 550000)
	restored.set_unlimited_test_progression(true)
	_true(restored.load_dict(saved), "Ein aktueller Testspielstand kann im konfigurierten Laufzeit-Testmodus geladen werden")
	_equal(restored.selected_talent_ids.size(), every_talent.size(), "Gültige Talentbaum-IDs verschwinden beim Neustart nicht am Economy-Gate")
	for id in every_talent:
		_true(restored.has_talent(id), "Der Neustart bewahrt das gültige Testtalent %s" % id)
	var balanced_restore := MetaProgressionState.new(func() -> int: return 550000)
	_true(balanced_restore.load_dict(saved), "Derselbe Spielstand bleibt beim späteren Abschalten des Testmodus lesbar")
	_true(balanced_restore.selected_talent_ids.is_empty() and balanced_restore.talent_tree_refund_pending, "Ein im Normalmodus überteuerter Testbaum wird vollständig mit Refund-Hinweis geleert")

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
