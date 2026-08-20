extends SceneTree

var assertions := 0
var failures := 0


func _init() -> void:
	_test_integer_and_attack_speed_contract()
	_test_research_and_intro_rewards()
	_test_boss_and_finding_contract()
	_test_damage_statistics()
	_finish()


func _test_integer_and_attack_speed_contract() -> void:
	var treatments := TreatmentDefinition.catalog()
	var impulse := treatments[&"treatment_precision"] as TreatmentDefinition
	_equal(PlayerStats.BASE_MAX_HEALTH, 50.0, "Doctor Milos beginnt mit 50 Basisleben")
	_equal(PlayerStats.BASE_MOVEMENT_SPEED, 180.0, "Der sichtbare Galopp besitzt den vereinbarten Basiswert")
	_equal(impulse.base_damage, 13.0, "Impuls verwendet ganzzahligen Schaden")
	_near(impulse.base_interval, 0.965, "Impuls ist gegenüber 0,82 Sekunden um etwa 15 Prozent verlangsamt")
	for definition in treatments.values():
		_true(is_equal_approx(definition.base_damage, roundf(definition.base_damage)), "%s besitzt ganzzahligen Schaden" % definition.id)
		_true(is_equal_approx(definition.base_range, roundf(definition.base_range)), "%s besitzt ganzzahlige Reichweite" % definition.id)
	for enemy in ContentCatalog.enemy_definitions().values():
		_true(is_equal_approx(enemy.speed, roundf(enemy.speed)), "%s besitzt ganzzahligen Galopp" % enemy.id)
		_true(is_equal_approx(enemy.base_damage, roundf(enemy.base_damage)), "%s besitzt ganzzahligen Schaden" % enemy.id)

	var rhythm := _upgrade(&"rhythm")
	_equal(StringName(rhythm.modifiers[0].get("operation", &"")), &"attack_speed_add", "Attack Speed verwendet einen linearen additiven Modifier")
	var build := RunBuildState.from_treatment(impulse)
	var preview := build.preview_upgrade(rhythm, 0)
	_equal(preview.effect_text, "+6 % Attack Speed", "Karte nennt den additiven Attack-Speed-Bonus")
	_equal(preview.before_after_text, "0 %  >  6 %", "Vorschau zeigt ausschließlich den akkumulierten Bonus")
	_true(build.apply_upgrade(rhythm, 1), "Erster Attack-Speed-Rang wird angewendet")
	_near(1.0 / build.value(RunBuildState.TREATMENT_INTERVAL, impulse.base_interval, impulse.tags), (1.0 / impulse.base_interval) * 1.06, "Erster Rang erhöht den Basis-Attack-Speed exakt um sechs Prozent")
	_true(build.apply_upgrade(rhythm, 2), "Zweiter Attack-Speed-Rang wird angewendet")
	_near(1.0 / build.value(RunBuildState.TREATMENT_INTERVAL, impulse.base_interval, impulse.tags), (1.0 / impulse.base_interval) * 1.12, "Zweiter Rang addiert linear statt exponentiell")


func _test_research_and_intro_rewards() -> void:
	var expected_costs := {
		&"stability_reserve": PackedInt32Array([100, 225, 400]),
		&"therapy_precision": PackedInt32Array([125, 275, 475]),
		&"experience_gain": PackedInt32Array([125, 275, 475]),
		&"defense_training": PackedInt32Array([150, 300, 500]),
		&"life_regeneration": PackedInt32Array([150, 300, 500]),
		&"unlock_spread_treatment": PackedInt32Array([300]),
		&"unlock_piercing_treatment": PackedInt32Array([500]),
		&"movement_training": PackedInt32Array([150, 300, 500]),
		&"unlock_defense_burst": PackedInt32Array([30]),
		&"unlock_treatment_line": PackedInt32Array([1000]),
	}
	var definitions := ContentCatalog.research_definitions()
	_equal(definitions.size(), expected_costs.size(), "Forschung enthält nur die zehn aktuellen Einträge")
	for definition in definitions:
		_true(expected_costs.has(definition.id), "Forschungs-ID %s ist Teil des aktuellen Vertrags" % definition.id)
		if expected_costs.has(definition.id):
			_equal(definition.costs, expected_costs[definition.id], "%s verwendet die vereinbarten fünffachen Kosten" % definition.id)

	var modules := ContentCatalog.loadout_module_definitions()
	var empty_available := LoadoutAvailabilityPolicy.selectable_ids(modules, {})
	_true(not empty_available.has(&"ability_defense_burst") and not empty_available.has(&"ability_treatment_line"), "Aktive Fähigkeiten sind vor Forschung gesperrt")
	var unlocked := LoadoutAvailabilityPolicy.selectable_ids(modules, {&"unlock_defense_burst": 1, &"unlock_treatment_line": 1})
	_true(unlocked.has(&"ability_defense_burst") and unlocked.has(&"ability_treatment_line"), "Beide Aktiven werden durch ihre Forschung freigeschaltet")

	var meta := MetaProgressionState.new(func() -> int: return 1_700_000_000)
	meta.reset_defaults(1_700_000_000)
	_true(meta.grant_intro_completion_rewards(), "Der erste Introabschluss vergibt die Startressourcen")
	_equal(meta.research_points, 30, "Intro vergibt exakt 30 Forschung")
	_equal(meta.talent_points_earned(), 0, "Nach dem Intro steht noch kein Talentpunkt bereit")
	_true(bool(meta.tutorial_status.get(&"research_guidance_pending", false)), "Intro aktiviert den einmaligen Forschungshinweis")
	_true(not meta.grant_intro_completion_rewards(), "Introbelohnung ist idempotent")
	_equal(meta.research_points, 30, "Wiederholtes Gewähren verdoppelt Forschung nicht")
	var restored := MetaProgressionState.new(func() -> int: return 1_700_000_001)
	_true(restored.load_dict(meta.to_dict()), "Introressourcen überstehen den Save-Roundtrip")
	_equal(restored.talent_points_earned(), 0, "Der Save-Roundtrip erzeugt keinen alten Intro-Talentpunkt")
	_true(restored.complete_mastery(&"fall_2_first_victory"), "Der erste Abschluss von Fall 2 vergibt seine Meisterschaft")
	_equal(restored.talent_points_earned(), 1, "Der erste Talentpunkt entsteht erst durch den Abschluss von Fall 2")


func _test_boss_and_finding_contract() -> void:
	var levels := ContentCatalog.level_definitions()
	_equal(levels[0].boss_enemy_id, &"intro_focus", "Intro behält einen eigenen einfachen Boss")
	_near(levels[0].boss_health_multiplier, 0.18, "Intro-Boss behält die alte kurze Lebensskalierung")
	_true(not levels[0].boss_ranged_enabled, "Intro-Boss bleibt ohne Spezialprojektile")
	_equal(levels[1].boss_enemy_id, &"localized_boss", "Fall 1 verwendet den neuen Bakterienkern")
	_true(not levels[1].boss_ranged_enabled, "Neuer erster Boss bleibt zunächst einfach")
	_equal(levels[2].boss_enemy_id, &"infection_focus", "Der bisherige Spezialboss lebt jetzt in Fall 2")
	_true(levels[2].boss_ranged_enabled, "Fall-2-Boss verwendet die Rautenprojektile")
	_near(levels[2].boss_projectile_damage_multiplier, 2.5, "Fall-2-Projektilschaden ist um 150 Prozent erhöht")
	_near(levels[2].boss_wave_amplitude, 92.0, "Fall-2-Rautenflugbahn ist deutlich breiter")
	_equal(ContentCatalog.finding_definitions().keys().size(), 2, "Nur zwei verständliche Befunde bleiben aktiv")
	_true(ContentCatalog.finding_definitions().has(&"grouping") and ContentCatalog.finding_definitions().has(&"hidden_nests"), "Gruppenbildung und verdeckte Nester bleiben erhalten")
	_true(ContentCatalog.validate_combat_profiles().is_empty(), "Neue Bossdefinitionen besitzen gültige Schadenstyp- und Resistenzprofile")


func _test_damage_statistics() -> void:
	var game := preload("res://scripts/game.gd").new()
	game.treatment_definitions = TreatmentDefinition.catalog()
	game.ability_definitions = AbilityDefinition.catalog()
	game.active_loadout = PreparedLoadout.create(&"treatment_precision", [&"ability_defense_burst", &"ability_treatment_line"])
	game.stats = PlayerStats.new()
	game.stats.immune_level = 1
	game.run_damage_by_source = {
		&"treatment_precision": 42.4,
		&"ability_defense_burst": 25.0,
		&"ability_treatment_line": 30.0,
		&"defense_cells": 10.0,
	}
	var statistics: Array[Dictionary] = game.result_damage_statistics()
	_equal(statistics.size(), 4, "Rundenstatistik enthält Behandlung, zwei Aktive und Abwehrzellen")
	_equal(statistics[0].damage, 42, "Rundenstatistik rundet nur die sichtbare Gesamtsumme")
	game.free()


func _upgrade(id: StringName) -> UpgradeDefinition:
	for definition in ContentCatalog.upgrade_definitions():
		if definition.id == id:
			return definition
	return null


func _finish() -> void:
	if failures == 0:
		print("ALVEOLUS_LATEST_PROGRESSION_BALANCE_OK assertions=%d" % assertions)
		quit(0)
		return
	push_error("ALVEOLUS_LATEST_PROGRESSION_BALANCE_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(1)


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s | expected=%s actual=%s" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_true(absf(actual - expected) <= tolerance, "%s | expected=%.4f actual=%.4f" % [message, expected, actual])
