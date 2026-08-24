extends SceneTree

const PracticeScenarioScript := preload("res://scripts/data/practice_scenario_definition.gd")
const PracticeBossProfileScript := preload("res://scripts/data/practice_boss_profile.gd")

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	_check_scenario_catalog()
	_check_boss_profile_catalog()
	_check_source_contracts()
	_finish()


func _check_scenario_catalog() -> void:
	var scenarios: Array = PracticeScenarioScript.catalog()
	_check(scenarios.size() == 3, "Praxis besitzt genau drei lokale Szenarien")
	_check(_ids(scenarios) == [&"spawn_test", &"obstacle_test", &"boss_test"], "Szenario-IDs und Reihenfolge bleiben stabil")

	var spawn := PracticeScenarioScript.get_by_id(&"spawn_test")
	_check(spawn != null and spawn.get_run_type() == PracticeScenarioScript.RunType.SPAWN_TEST, "Spawn-Test besitzt eine explizite Laufart")
	_check(spawn.get_small_enemy_id() == &"pneumococcus" and spawn.get_medium_enemy_id() == &"bacterial_cluster", "Spawn-Test verwendet die festen kleinen und mittleren Gegner")
	_check(spawn.get_initial_small_count() == 12 and spawn.get_initial_medium_count() == 6, "Spawn-Test startet exakt mit 12 kleinen und 6 mittleren Gegnern")
	_check(spawn.get_ongoing_weighted_cap() == 145, "Spawn-Test nutzt 145 ausschließlich als laufendes Gewichtslimit")
	_check(spawn.is_endless() and spawn.are_waves_enabled(), "Spawn-Test läuft endlos mit Wellen")
	_check(spawn.get_spawn_baseline_case_order() == 6, "Spawn-Test verankert seine Spawnkurve an Fall 6")
	_check(is_equal_approx(spawn.get_spawn_ramp_seconds(), 180.0), "Spawn-Test rampt exakt 180 Sekunden")
	_check(is_equal_approx(spawn.get_spawn_rate_multiplier(), 1.10), "Spawn-Test liegt exakt zehn Prozent über Fall 6")
	_check(spawn.get_obstacle_count() == 0 and not spawn.requires_boss_profile(), "Spawn-Test trägt weder Hindernisse noch Bossprofil")

	var obstacle := PracticeScenarioScript.get_by_id(&"obstacle_test")
	_check(obstacle != null and obstacle.get_run_type() == PracticeScenarioScript.RunType.OBSTACLE_TEST, "Hindernis-Test besitzt eine explizite Laufart")
	_check(obstacle.get_initial_small_count() == 8 and obstacle.get_initial_medium_count() == 4, "Hindernis-Test startet exakt mit 8 kleinen und 4 mittleren Gegnern")
	_check(obstacle.get_ongoing_weighted_cap() == 145, "Hindernis-Test nutzt 145 ausschließlich als laufendes Gewichtslimit")
	_check(obstacle.is_endless() and obstacle.are_waves_enabled(), "Hindernis-Test läuft endlos mit Wellen")
	_check(obstacle.get_spawn_baseline_case_order() == 6, "Hindernis-Test verankert seine Spawnkurve an Fall 6")
	_check(is_equal_approx(obstacle.get_spawn_ramp_seconds(), 180.0), "Hindernis-Test rampt exakt 180 Sekunden")
	_check(is_equal_approx(obstacle.get_spawn_rate_multiplier(), 1.10), "Hindernis-Test liegt exakt zehn Prozent über Fall 6")
	_check(obstacle.get_obstacle_count() == 3, "Hindernis-Test besitzt genau drei feste Hindernisse")
	var expected_positions := [Vector2(-280.0, -140.0), Vector2(-280.0, 140.0), Vector2(260.0, 0.0)]
	for index in range(expected_positions.size()):
		var obstacle_definition = obstacle.get_obstacle_at(index)
		_check(obstacle_definition != null and obstacle_definition.get_position() == expected_positions[index], "Hindernis %d besitzt seine feste Position" % index)
		_check(obstacle_definition.get_enemy_id() == &"minor_focus" and obstacle_definition.get_visual_id() == &"infection_focus", "Hindernis %d besitzt eine vollständige Spawnidentität" % index)
		_check(is_equal_approx(obstacle_definition.get_health_multiplier(), 20.0), "Hindernis %d besitzt zwanzigfaches Leben" % index)
		_check(is_zero_approx(obstacle_definition.get_movement_multiplier()) and is_zero_approx(obstacle_definition.get_contact_damage_multiplier()), "Hindernis %d bleibt unbeweglich und kontaktschadensfrei" % index)
		_check(obstacle_definition.get_priority() == EnemySpawnRequest.Priority.CRITICAL, "Hindernis %d nutzt den kritischen Spawnpfad" % index)
		_check(obstacle_definition.get_body_role() == EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE, "Hindernis %d besitzt STATIC_FLOW_OBSTACLE" % index)
		_check(obstacle_definition.get_obstacle_traversal() == EnemySpawnRequest.ObstacleTraversal.DEFAULT, "Hindernis %d nutzt die normale Umlaufregel" % index)
	var returned_obstacles: Array = obstacle.get_obstacles()
	returned_obstacles.clear()
	_check(obstacle.get_obstacle_count() == 3, "Ausgelesene Hindernisse können das Szenario nicht verändern")

	var boss := PracticeScenarioScript.get_by_id(&"boss_test")
	_check(boss != null and boss.get_run_type() == PracticeScenarioScript.RunType.BOSS_TEST, "Boss-Test besitzt eine explizite Laufart")
	_check(boss.get_initial_small_count() == 0 and boss.get_initial_medium_count() == 0, "Boss-Test besitzt keine Startwelle")
	_check(boss.get_ongoing_weighted_cap() == 0, "Boss-Test besitzt kein laufendes Wellenlimit")
	_check(not boss.is_endless() and not boss.are_waves_enabled(), "Boss-Test deaktiviert Wellen vollständig")
	_check(boss.requires_boss_profile() and boss.get_obstacle_count() == 0, "Boss-Test verlangt ausschließlich ein Bossprofil")
	_check(PracticeScenarioScript.get_by_id(&"missing") == null, "Unbekannte Szenario-ID löst nicht auf")
	scenarios.clear()
	_check(PracticeScenarioScript.catalog().size() == 3, "Katalogaufrufe liefern voneinander getrennte Arrays")


func _check_boss_profile_catalog() -> void:
	var profiles: Array = PracticeBossProfileScript.catalog()
	_check(profiles.size() == 4, "Praxis besitzt genau vier Bossprofile")
	_check(
		_ids(profiles) == [
			&"intro_boss",
			&"bacterial_core",
			&"diamond_infection_focus",
			&"standard_infection_focus",
		],
		"Bossprofil-IDs und Reihenfolge bleiben stabil"
	)
	_check_profile(
		PracticeBossProfileScript.get_by_id(&"intro_boss"),
		&"intro", &"intro_focus", 0.09, 0.80, 1.0, 0.50, true, 1.0, 44.0, PackedInt32Array()
	)
	_check_profile(
		PracticeBossProfileScript.get_by_id(&"bacterial_core"),
		&"localized_focus", &"localized_boss", 1.0, 1.08, 1.0, 1.25, false, 1.0, 44.0, PackedInt32Array([3])
	)
	_check_profile(
		PracticeBossProfileScript.get_by_id(&"diamond_infection_focus"),
		&"spreading_infection", &"infection_focus", 0.75, 1.16, 1.35, 1.45, true, 2.5, 115.0, PackedInt32Array([4, 4])
	)
	_check_profile(
		PracticeBossProfileScript.get_by_id(&"standard_infection_focus"),
		&"severe_pneumonia", &"infection_focus", 1.35, 1.24, 1.0, 1.65, false, 1.0, 44.0, PackedInt32Array([6, 8])
	)
	var diamond = PracticeBossProfileScript.get_by_id(&"diamond_infection_focus")
	var phases := diamond.get_phase_minions()
	phases[0] = 99
	_check(diamond.get_phase_minions() == PackedInt32Array([4, 4]), "Ausgelesene Bossphasen können das Profil nicht verändern")
	_check(diamond.duplicate_immutable() != diamond, "Bossprofile liefern getrennte unveränderliche Kopien")
	_check(PracticeBossProfileScript.get_by_id(&"missing") == null, "Unbekannte Bossprofil-ID löst nicht auf")
	profiles.clear()
	_check(PracticeBossProfileScript.catalog().size() == 4, "Bosskatalogaufrufe liefern voneinander getrennte Arrays")


func _check_profile(
	profile,
	source_case_id: StringName,
	enemy_id: StringName,
	health_multiplier: float,
	enemy_speed_multiplier: float,
	boss_speed_multiplier: float,
	contact_damage_multiplier: float,
	ranged_enabled: bool,
	projectile_damage_multiplier: float,
	wave_amplitude: float,
	phase_minions: PackedInt32Array
) -> void:
	_check(profile != null, "Bossprofil %s ist vorhanden" % enemy_id)
	if profile == null:
		return
	_check(profile.get_source_case_id() == source_case_id, "Bossprofil %s bewahrt seinen Herkunftsfall" % profile.get_id())
	_check(profile.get_enemy_id() == enemy_id and profile.get_visual_id() == &"infection_focus", "Bossprofil %s besitzt Gegner- und Visual-ID" % profile.get_id())
	_check(is_equal_approx(profile.get_health_multiplier(), health_multiplier), "Bossprofil %s besitzt seinen Lebensfaktor" % profile.get_id())
	_check(is_equal_approx(profile.get_enemy_speed_multiplier(), enemy_speed_multiplier), "Bossprofil %s besitzt seinen globalen Tempofaktor" % profile.get_id())
	_check(is_equal_approx(profile.get_boss_speed_multiplier(), boss_speed_multiplier), "Bossprofil %s besitzt seinen Boss-Tempofaktor" % profile.get_id())
	_check(is_equal_approx(profile.get_effective_speed_multiplier(), enemy_speed_multiplier * boss_speed_multiplier), "Bossprofil %s kann sein effektives Tempo liefern" % profile.get_id())
	_check(is_equal_approx(profile.get_contact_damage_multiplier(), contact_damage_multiplier), "Bossprofil %s besitzt seinen Kontaktfaktor" % profile.get_id())
	_check(profile.is_ranged_enabled() == ranged_enabled, "Bossprofil %s besitzt seinen Fernkampfschalter" % profile.get_id())
	_check(is_equal_approx(profile.get_projectile_damage_multiplier(), projectile_damage_multiplier), "Bossprofil %s besitzt seinen Projektilfaktor" % profile.get_id())
	_check(is_equal_approx(profile.get_wave_amplitude(), wave_amplitude), "Bossprofil %s besitzt seine Projektilamplitude" % profile.get_id())
	_check(profile.get_phase_minions() == phase_minions, "Bossprofil %s besitzt seine vollständigen Phasen" % profile.get_id())
	_check(profile.get_boss_count() == 1, "Bossprofil %s startet genau einen Boss" % profile.get_id())


func _ids(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(value.get_id())
	return result


func _check_source_contracts() -> void:
	var scenario_source := FileAccess.get_file_as_string("res://scripts/data/practice_scenario_definition.gd")
	var profile_source := FileAccess.get_file_as_string("res://scripts/data/practice_boss_profile.gd")
	for forbidden in ["ContentCatalog", "MetaProgressionState", "SaveRepository", "OS.is_debug_build"]:
		_check(not scenario_source.contains(forbidden), "Szenariokatalog greift nicht auf %s zu" % forbidden)
		_check(not profile_source.contains(forbidden), "Bossprofilkatalog greift nicht auf %s zu" % forbidden)
	_check(not scenario_source.contains("@export"), "Szenariokatalog öffnet keine veränderlichen Exportfelder")
	_check(not profile_source.contains("@export"), "Bossprofilkatalog öffnet keine veränderlichen Exportfelder")


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_PRACTICE_SCENARIO_CONTRACT_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
