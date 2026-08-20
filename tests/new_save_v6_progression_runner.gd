extends SceneTree

var assertions := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_ranked_talent_contract()
	_test_v6_roundtrip()
	_test_v6_revision3_refunds_retired_tree()
	_test_v5_migration_refunds_retired_tree()
	_test_independent_resets_and_seed_advance()
	if failures == 0:
		print("ALVEOLUS_SAVE_V6_PROGRESSION_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_SAVE_V6_PROGRESSION_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)


func _test_ranked_talent_contract() -> void:
	var definitions := TalentDefinition.definitions()
	_equal(definitions.size(), 4, "Der neue Baum enthält genau vier Talente")
	_equal(TalentDefinition.catalog()[&"spread_penetration"].max_rank, 3, "Streuimpuls besitzt drei Ränge")
	_equal(TalentDefinition.catalog()[&"piercing_persistence"].max_rank, 2, "Laserbestand besitzt zwei Ränge")

	var meta := _fully_funded_meta(1000)
	_true(not meta.purchase_talent_rank(&"spread_penetration"), "Ein Kind kann seine Voraussetzung nicht überspringen")
	_true(meta.purchase_talent_rank(&"treatment_damage_training"), "Das Wurzeltalent kann gekauft werden")
	_true(meta.purchase_talent_rank(&"spread_penetration"), "Der erste Streuungsrang kann gekauft werden")
	_true(meta.purchase_talent_rank(&"spread_penetration"), "Der zweite Streuungsrang kann gekauft werden")
	_true(meta.purchase_talent_rank(&"spread_penetration"), "Der dritte Streuungsrang kann gekauft werden")
	_true(not meta.purchase_talent_rank(&"spread_penetration"), "Der Streuungsrang bleibt am Maximum gedeckelt")
	_equal(meta.talent_rank(&"spread_penetration"), 3, "Rangabfrage liefert den vollständigen Ausbau")
	_equal(meta.talent_points_spent(), 4, "Rangkosten werden einzeln summiert")
	_true(not meta.set_talent_active(&"treatment_damage_training", false), "Eine belegte Voraussetzung wird nicht still entfernt")
	meta.clear_talents()
	_equal(meta.talent_points_spent(), 0, "Talentreset gibt alle Rangkosten frei")
	_equal(meta.available_talent_points(), meta.talent_points_earned(), "Nach dem Reset sind alle verdienten Punkte verfügbar")


func _test_v6_roundtrip() -> void:
	var source := _fully_funded_meta(2000)
	_true(source.set_talent_rank(&"treatment_damage_training", 1), "Wurzeltalent wird gesetzt")
	_true(source.set_talent_rank(&"spread_penetration", 3), "Mehrere Ränge werden atomar gesetzt")
	_true(source.set_talent_rank(&"piercing_persistence", 2), "Laserbestand wird vollständig gesetzt")
	source.research_points = 77
	source.research_ranks = {&"stability_reserve": 3, &"therapy_precision": 2}
	source.level_case_seeds[&"localized_focus"] = 424242
	source.case_seed_nonce = 9

	var saved := source.to_dict()
	_equal(int(saved.get("version", 0)), 6, "Neue Spielstände verwenden Save-Version 6")
	_equal(int(saved.get("talent_tree_revision", 0)), 4, "Save markiert Talentbaumrevision 4")
	_equal((saved.get("talent_ranks", {}) as Dictionary).get("spread_penetration", 0), 3, "Save schreibt Talentstufen als Dictionary")

	var restored := MetaProgressionState.new(func() -> int: return 2000)
	_true(restored.load_dict(saved), "Save-Version 6 wird geladen")
	_equal(restored.talent_rank(&"spread_penetration"), 3, "V6 bewahrt den dreistufigen Streuimpuls")
	_equal(restored.talent_rank(&"piercing_persistence"), 2, "V6 bewahrt den zweistufigen Laserbestand")
	_true(restored.has_talent(&"treatment_damage_training"), "Kompatible Aktivabfrage erkennt Rangtalente")
	_equal(restored.research_points, 77, "V6 bewahrt Forschungspunkte")
	_equal(restored.rank(&"stability_reserve"), 3, "V6 bewahrt Forschungsränge")
	_equal(restored.get_or_create_case_seed(&"localized_focus"), 424242, "V6 bewahrt den aktuellen Fallseed")

	var context := restored.create_run_context(&"localized_focus")
	_equal(context.talent_rank(&"spread_penetration"), 3, "RunContext übernimmt den exakten Talentrang")
	_true(context.has_talent(&"piercing_persistence"), "RunContext hält die boolesche Kompatibilitätsabfrage")


func _test_v6_revision3_refunds_retired_tree() -> void:
	var revision3 := {
		"version": 6,
		"research_points": 91,
		"research_ranks": {"movement_training": 2, "therapy_precision": 1},
		"completed_mastery_ids": ["intro_complete", "fall_1_first_victory"],
		"talent_tree_revision": 3,
		"talent_ranks": {"manual_treatment_aim": 1, "spread_penetration": 3, "piercing_persistence": 2, "piercing_return": 1},
	}
	var migrated := MetaProgressionState.new(func() -> int: return 2500)
	_true(migrated.load_dict(revision3), "Ein V6-Spielstand mit Revisionsbaum 3 wird geladen")
	_true(migrated.talent_ranks.is_empty(), "Revision-3-Auswahl wird atomar zurückgesetzt")
	_true(migrated.talent_tree_refund_pending, "Revision-3-Auswahl markiert die Rückerstattung")
	_equal(migrated.talent_points_earned(), 0, "Intro und Fall 1 geben nach der Migration keine Talentpunkte")
	_equal(migrated.research_points, 91, "Forschungspunkte bleiben bei Revision-3-Migration erhalten")
	_equal(migrated.rank(&"movement_training"), 2, "Forschungsränge bleiben bei Revision-3-Migration erhalten")


func _test_v5_migration_refunds_retired_tree() -> void:
	var legacy_v5 := {
		"version": 5,
		"research_points": 123,
		"research_ranks": {"stability_reserve": 2},
		"completed_mastery_ids": ["intro_complete", "fall_1_first_victory"],
		"selected_talent_ids": ["organization_1", "rapid_evaluation"],
		"talent_tree_revision": 2,
		"level_case_seeds": {"localized_focus": 8080},
		"case_seed_nonce": 4,
	}
	var migrated := MetaProgressionState.new(func() -> int: return 3000)
	_true(migrated.load_dict(legacy_v5), "Ein V5-Spielstand wird nach V6 migriert")
	_true(migrated.talent_ranks.is_empty(), "IDs des entfernten Talentbaums werden nicht neu interpretiert")
	_true(migrated.talent_tree_refund_pending, "Die Migration kennzeichnet zurückgegebene Altverteilung")
	_equal(migrated.talent_points_earned(), 0, "Alte Intro- und Fall-1-Abschlüsse geben keine Talentpunkte")
	_equal(migrated.available_talent_points(), 0, "Vor Fall 2 sind nach der Migration keine Talentpunkte frei")
	_equal(migrated.research_points, 123, "V5-Migration bewahrt Forschungspunkte")
	_equal(migrated.rank(&"stability_reserve"), 2, "V5-Migration bewahrt Forschungsränge")
	_equal(migrated.get_or_create_case_seed(&"localized_focus"), 8080, "V5-Migration bewahrt den Fallseed")


func _test_independent_resets_and_seed_advance() -> void:
	var research_signal_count := [0]
	var upgrade_signal_count := [0]
	var meta := _fully_funded_meta(4000)
	meta.research_points = 55
	meta.research_ranks = {&"stability_reserve": 2, &"therapy_precision": 1}
	meta.research_changed.connect(func(_points: int, _claimable: int) -> void: research_signal_count[0] += 1)
	meta.upgrades_changed.connect(func() -> void: upgrade_signal_count[0] += 1)
	var refunded := meta.clear_research_ranks(ContentCatalog.research_definitions())
	_true(meta.research_ranks.is_empty(), "Forschungsreset löscht ausschließlich die Ränge")
	_equal(refunded, 450, "Forschungsreset summiert die tatsächlich bezahlten Rangkosten")
	_equal(meta.research_points, 505, "Forschungsreset gibt alle bezahlten Forschungspunkte zurück")
	_equal(research_signal_count[0], 1, "Forschungsreset aktualisiert den Kontostand sichtbar")
	_equal(upgrade_signal_count[0], 1, "Forschungsreset aktualisiert abhängige Werte")

	meta.level_case_seeds[&"localized_focus"] = 12345
	meta.case_seed_nonce = 7
	meta.lifetime_runs = 3
	var twin := MetaProgressionState.new(func() -> int: return 999999)
	twin.level_case_seeds[&"localized_focus"] = 12345
	twin.case_seed_nonce = 7
	twin.lifetime_runs = 3
	var advanced := meta.advance_case_seed(&"localized_focus")
	var twin_advanced := twin.advance_case_seed(&"localized_focus")
	_true(advanced != 12345, "Ein erfolgreicher Abschluss kann einen neuen Fallseed erzeugen")
	_equal(advanced, twin_advanced, "Seedfortschritt ist aus demselben Zustand deterministisch")
	_equal(meta.get_or_create_case_seed(&"localized_focus"), advanced, "Der fortgeschrittene Seed bleibt bis zum nächsten Erfolg stabil")


func _fully_funded_meta(now: int) -> MetaProgressionState:
	var meta := MetaProgressionState.new(func() -> int: return now)
	meta.reset_defaults(now)
	var ids: Array[StringName] = []
	for definition in MasteryObjectiveDefinition.definitions():
		ids.append(definition.id)
	meta.apply_mastery_candidates(ids)
	return meta


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
