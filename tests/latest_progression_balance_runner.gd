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
	_equal(preview.effect_text, "+3 % Attack Speed", "Common-Karte nennt den additiven Attack-Speed-Bonus")
	_equal(preview.before_after_text, "0 %  >  3 %", "Vorschau zeigt ausschließlich den akkumulierten Bonus")
	_true(build.apply_upgrade(rhythm, 1), "Erster Attack-Speed-Rang wird angewendet")
	_near(1.0 / build.value(RunBuildState.TREATMENT_INTERVAL, impulse.base_interval, impulse.tags), (1.0 / impulse.base_interval) * 1.03, "Erster Common-Pick erhöht den Basis-Attack-Speed exakt um drei Prozent")
	_true(build.apply_upgrade(rhythm, 2), "Zweiter Attack-Speed-Rang wird angewendet")
	_near(1.0 / build.value(RunBuildState.TREATMENT_INTERVAL, impulse.base_interval, impulse.tags), (1.0 / impulse.base_interval) * 1.06, "Zweiter Pick addiert linear statt exponentiell")


func _test_research_and_intro_rewards() -> void:
	var expected_costs := {
		&"stability_reserve": PackedInt32Array([50, 350, 800]),
		&"therapy_precision": PackedInt32Array([63, 425, 950]),
		&"experience_gain": PackedInt32Array([63, 425, 950]),
		&"defense_training": PackedInt32Array([75, 450, 1000]),
		&"life_regeneration": PackedInt32Array([75, 450, 1000]),
		&"unlock_spread_treatment": PackedInt32Array([300]),
		&"unlock_piercing_treatment": PackedInt32Array([500]),
		&"movement_training": PackedInt32Array([75, 450, 1000]),
		&"unlock_defense_burst": PackedInt32Array([30]),
		&"unlock_treatment_line": PackedInt32Array([1000]),
	}
	var definitions := ContentCatalog.research_definitions()
	_equal(definitions.size(), expected_costs.size(), "Forschung enthält nur die zehn aktuellen Einträge")
	for definition in definitions:
		_true(expected_costs.has(definition.id), "Forschungs-ID %s ist Teil des aktuellen Vertrags" % definition.id)
		if expected_costs.has(definition.id):
			_equal(definition.costs, expected_costs[definition.id], "%s verwendet den günstigen Einstieg und die steile Folgekostenkurve" % definition.id)

	var modules := ContentCatalog.loadout_module_definitions()
	var empty_available := LoadoutAvailabilityPolicy.selectable_ids(modules, {})
	_true(not empty_available.has(&"ability_defense_burst") and not empty_available.has(&"ability_treatment_line"), "Aktive Fähigkeiten sind vor Forschung gesperrt")
	var researched_before_case := LoadoutAvailabilityPolicy.selectable_ids(modules, {&"unlock_defense_burst": 1, &"unlock_treatment_line": 1})
	_true(researched_before_case.has(&"ability_defense_burst") and not researched_before_case.has(&"ability_treatment_line"), "Ein alter Lazer-Forschungsrang umgeht den Fallmeilenstein nicht")
	var unlocked := LoadoutAvailabilityPolicy.selectable_ids(modules, {&"unlock_defense_burst": 1}, true)
	_true(unlocked.has(&"ability_defense_burst") and unlocked.has(&"ability_treatment_line"), "Fall 1 schaltet den zweiten Aktivplatz und den Lazer frei")

	var meta := MetaProgressionState.new(func() -> int: return 1_700_000_000)
	meta.reset_defaults(1_700_000_000)
	_equal(meta.research_points, 0, "Ein neuer Spielstand startet mit null Forschung")
	_true(meta.grant_intro_completion_rewards(), "Der erste Introabschluss vergibt die Startressourcen")
	_equal(meta.research_points, 75, "Intro oder Intro-Skip vergibt exakt 75 Basisforschung")
	_equal(MetaProgressionState.intro_research_reward(1), 94, "Ein besiegter Intro-Boss erhöht die Introbelohnung um 25 Prozent")
	_equal(meta.talent_points_earned(), 0, "Nach dem Intro steht noch kein Talentpunkt bereit")
	_true(bool(meta.tutorial_status.get(&"research_guidance_pending", false)), "Intro aktiviert den einmaligen Forschungshinweis")
	_true(not meta.grant_intro_completion_rewards(), "Introbelohnung ist idempotent")
	_equal(meta.research_points, 75, "Wiederholtes Gewähren verdoppelt Forschung nicht")
	var restored := MetaProgressionState.new(func() -> int: return 1_700_000_001)
	_true(restored.load_dict(meta.to_dict()), "Introressourcen überstehen den Save-Roundtrip")
	_equal(restored.talent_points_earned(), 0, "Der Save-Roundtrip erzeugt keinen alten Intro-Talentpunkt")
	_true(restored.complete_mastery(&"fall_2_first_victory"), "Der erste Abschluss von Fall 2 vergibt seine Meisterschaft")
	_equal(restored.talent_points_earned(), 1, "Der erste Talentpunkt entsteht erst durch den Abschluss von Fall 2")
	var mastery := MasteryObjectiveDefinition.catalog()
	_equal(mastery[&"fall_1_first_victory"].level_id, &"early_localized_focus", "Fall-1-Meisterschaft folgt dem neuen Order-1-Fall")
	_equal(mastery[&"fall_2_first_victory"].level_id, &"localized_focus", "Erhaltene Fall-2-Meisterschaft bleibt am Order-2-Anker")
	_equal(mastery[&"fall_3_first_victory"].level_id, &"severe_pneumonia", "Erhaltene schwere Meisterschaft folgt dem Order-6-Anker")


func _test_boss_and_finding_contract() -> void:
	var levels := ContentCatalog.level_definitions()
	_equal(levels.size(), 7, "Bossvertrag umfasst Intro plus sechs Hauptfälle")
	var intro := _level_by_id(levels, &"intro")
	var case_one := _level_by_id(levels, &"early_localized_focus")
	var case_two := _level_by_id(levels, &"localized_focus")
	var case_three := _level_by_id(levels, &"advancing_infection")
	var case_four := _level_by_id(levels, &"spreading_infection")
	var case_five := _level_by_id(levels, &"critical_infection")
	var case_six := _level_by_id(levels, &"severe_pneumonia")
	var ordered_cases := [intro, case_one, case_two, case_three, case_four, case_five, case_six]
	for order in range(ordered_cases.size()):
		_true(ordered_cases[order] != null and ordered_cases[order].order == order, "Bosskatalog bewahrt den Fall auf Order %d" % order)
	_equal(intro.boss_enemy_id, &"intro_focus", "Intro behält einen eigenen einfachen Boss")
	_near(intro.boss_health_multiplier, 0.09, "Intro-Boss besitzt gegenüber der vorherigen Einführung halbierte Leben")
	_true(intro.boss_ranged_enabled, "Intro-Boss feuert ein normales Projektil statt einer Spezialbahn")
	_equal(case_one.boss_enemy_id, &"localized_boss", "Fall 1 beginnt mit dem einfachen Bakterienkern")
	_true(not case_one.boss_ranged_enabled and case_one.boss_phase_minions == PackedInt32Array([2]), "Fall 1 verwendet genau eine kleine Zweierphase")
	_equal(case_two.boss_enemy_id, &"localized_boss", "Erhaltener Bakterienkern liegt auf Order 2")
	_true(not case_two.boss_ranged_enabled and case_two.boss_phase_minions == PackedInt32Array([3]), "Fall 2 bewahrt die einfache Dreierphase")
	_equal(case_three.boss_enemy_id, &"infection_focus", "Fall 3 führt den Infektionsherd ein")
	_true(case_three.boss_ranged_enabled, "Fall 3 führt die Rautenprojektile ein")
	_near(case_three.boss_projectile_damage_multiplier, 2.0, "Fall 3 verwendet den neuen Zwischen-Projektilfaktor")
	_near(case_three.boss_wave_amplitude, 68.0, "Fall 3 verwendet die neue Zwischen-Flugbahn")
	_equal(case_four.boss_enemy_id, &"infection_focus", "Der bisherige Spezialboss liegt jetzt auf Order 4")
	_true(case_four.boss_ranged_enabled, "Fall-4-Boss verwendet die Rautenprojektile")
	_near(case_four.boss_projectile_damage_multiplier, 2.5, "Fall-4-Projektilschaden ist um 150 Prozent erhöht")
	_near(case_four.boss_wave_amplitude, 92.0, "Fall-4-Rautenflugbahn ist deutlich breiter")
	_true(not case_five.boss_ranged_enabled and case_five.boss_phase_minions == PackedInt32Array([5, 6]), "Fall 5 verwendet den neuen stationären Nahkampf-Bossvertrag")
	_true(not case_six.boss_ranged_enabled and case_six.boss_phase_minions == PackedInt32Array([6, 8]), "Fall 6 bewahrt den schweren Standardboss")
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


func _level_by_id(levels: Array[LevelDefinition], id: StringName) -> LevelDefinition:
	for level in levels:
		if level.id == id:
			return level
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
