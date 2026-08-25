extends SceneTree

const GameScript := preload("res://scripts/game.gd")

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var levels := ContentCatalog.level_definitions()
	var scenarios := PracticeScenarioDefinition.catalog(levels)
	var profiles := PracticeBossProfile.catalog(levels, ContentCatalog.enemy_definitions())
	_check_context_duplication(scenarios, profiles)
	_check_base_configs(levels, scenarios)
	_check_event_configs(levels, scenarios)
	_check_boss_configs(levels, scenarios, profiles)
	_finish()


func _check_context_duplication(scenarios: Array[PracticeScenarioDefinition], profiles: Array[PracticeBossProfile]) -> void:
	var scenario := _scenario_by_id(scenarios, &"boss_test")
	var profile := profiles[0]
	var context := RunContext.create_practice(
		scenario,
		profile,
		2026082403,
		PreparedLoadout.create(&"treatment_precision", [&"ability_defense_burst", &"ability_treatment_line"]),
		{&"talent_precision": 2}
	)
	var copy := context.duplicate_context()
	_check(copy != context and copy.is_practice_test(), "Praxis-Kontext dupliziert sich mit explizitem Modus")
	_check(copy.practice_scenario != context.practice_scenario and copy.practice_scenario.get_id() == &"boss_test", "Praxis-Kontext trennt sein Szenario")
	_check(copy.practice_boss_profile != context.practice_boss_profile and copy.practice_boss_profile.get_id() == profile.get_id(), "Praxis-Kontext trennt sein dynamisches Bossprofil")
	_check(copy.loadout_snapshot != context.loadout_snapshot and copy.loadout_snapshot.to_dict() == context.loadout_snapshot.to_dict(), "Praxis-Kontext trennt den Loadout-Snapshot")
	_check(copy.talent_rank(&"talent_precision") == 2 and copy.seed == 2026082403, "Praxis-Kontext bewahrt Seed und Talente")


func _check_base_configs(levels: Array[LevelDefinition], scenarios: Array[PracticeScenarioDefinition]) -> void:
	var spawn := _configured_run(levels, _scenario_by_id(scenarios, &"spawn_test"), null)
	_check(spawn.initial_small_enemy_count == 12 and spawn.initial_cluster_enemy_count == 6, "Spawn-Test bewahrt seine Startgegner")
	_check(spawn.regular_spawns_enabled and spawn.regular_spawn_weight_cap == 145, "Spawn-Test verwendet laufende Wellen mit 145 Gewicht")
	_check(spawn.run_duration_seconds >= 1.0e11 and not spawn.automatic_boss_enabled, "Spawn-Test bleibt endlos und bossfrei")
	var obstacle := _configured_run(levels, _scenario_by_id(scenarios, &"obstacle_test"), null)
	_check(obstacle.initial_small_enemy_count == 8 and obstacle.initial_cluster_enemy_count == 4, "Hindernis-Test bewahrt seine Startgegner")
	_check(obstacle.regular_spawns_enabled and not obstacle.automatic_boss_enabled, "Hindernis-Test bleibt ein bossfreier Wellenlauf")


func _check_event_configs(levels: Array[LevelDefinition], scenarios: Array[PracticeScenarioDefinition]) -> void:
	for source in levels:
		if source.is_tutorial:
			continue
		var scenario := _scenario_by_id(scenarios, StringName("event_test:%s" % String(source.id)))
		var original_times := source.case_pressure_plan.target_focus_times.duplicate()
		var config := _configured_run(levels, scenario, null)
		_check(config.case_pressure_plan != null, "Fall %d Eventtest aktiviert den echten Pressure-Pfad" % source.order)
		_check(config.case_pressure_plan.target_focus_times == PackedFloat32Array([2.0]), "Fall %d Eventtest spawnt sein Ziel nach zwei Sekunden" % source.order)
		_check(config.case_pressure_plan.projectile_gate_times.is_empty() and config.case_pressure_plan.max_active_targets == 1, "Fall %d Eventtest isoliert genau ein Ziel" % source.order)
		_check(not config.regular_spawns_enabled and not config.automatic_boss_enabled, "Fall %d Eventtest deaktiviert Wellen und Boss" % source.order)
		_check(config.case_pressure_targets_stationary == source.case_pressure_targets_stationary, "Fall %d Eventtest bewahrt die Körperrolle" % source.order)
		_check(is_equal_approx(config.case_pressure_plan.target_movement_speed_multiplier, source.case_pressure_plan.target_movement_speed_multiplier), "Fall %d Eventtest bewahrt das Bewegungstempo" % source.order)
		_check(is_equal_approx(config.case_pressure_plan.target_attack_speed_multiplier, source.case_pressure_plan.target_attack_speed_multiplier), "Fall %d Eventtest bewahrt die Schussrate" % source.order)
		_check(config.case_pressure_plan.target_visual_id == source.case_pressure_plan.target_visual_id, "Fall %d Eventtest bewahrt das aktuelle Visual" % source.order)
		_check(source.case_pressure_plan.target_focus_times == original_times, "Fall %d Eventtest mutiert den Kampagnenkatalog nicht" % source.order)


func _check_boss_configs(
	levels: Array[LevelDefinition],
	scenarios: Array[PracticeScenarioDefinition],
	profiles: Array[PracticeBossProfile]
) -> void:
	var boss_scenario := _scenario_by_id(scenarios, &"boss_test")
	_check(profiles.size() == levels.size() - 1, "Boss-Test zeigt jeden aktuell definierten Kampagnenfallboss")
	for profile in profiles:
		var source := _level_by_id(levels, profile.get_source_case_id())
		var config := _configured_run(levels, boss_scenario, profile)
		_check(config.automatic_boss_enabled and is_equal_approx(config.run_duration_seconds, 2.0), "Bossprofil %s startet nach zwei Sekunden" % profile.get_id())
		_check(not config.regular_spawns_enabled and config.case_pressure_plan == null, "Bossprofil %s läuft ohne Wellen und Events" % profile.get_id())
		_check(config.boss_enemy_id == source.boss_enemy_id, "Bossprofil %s übernimmt die aktuelle Gegner-ID" % profile.get_id())
		_check(is_equal_approx(config.boss_health_multiplier, source.boss_health_multiplier), "Bossprofil %s übernimmt aktuelles Leben" % profile.get_id())
		_check(is_equal_approx(config.enemy_speed_multiplier, source.enemy_speed_multiplier), "Bossprofil %s übernimmt den aktuellen Fall-Tempoanteil" % profile.get_id())
		_check(is_equal_approx(config.boss_speed_multiplier, source.boss_speed_multiplier), "Bossprofil %s übernimmt das aktuelle Bosstempo" % profile.get_id())
		_check(is_equal_approx(config.contact_damage_multiplier, source.contact_damage_multiplier), "Bossprofil %s übernimmt den aktuellen Kontaktschaden" % profile.get_id())
		_check(config.boss_ranged_enabled == source.boss_ranged_enabled, "Bossprofil %s übernimmt den aktuellen Fernkampfstatus" % profile.get_id())
		_check(is_equal_approx(config.boss_projectile_damage_multiplier, source.boss_projectile_damage_multiplier), "Bossprofil %s übernimmt den aktuellen Projektilschaden" % profile.get_id())
		_check(is_equal_approx(config.boss_projectile_attack_speed_multiplier, source.boss_projectile_attack_speed_multiplier), "Bossprofil %s übernimmt die aktuelle Schussrate" % profile.get_id())
		_check(is_equal_approx(config.boss_projectile_speed_multiplier, source.boss_projectile_speed_multiplier), "Bossprofil %s übernimmt das aktuelle Projektiltempo" % profile.get_id())
		_check(config.boss_projectile_pattern == source.boss_projectile_pattern, "Bossprofil %s übernimmt das aktuelle Projektilmuster" % profile.get_id())
		_check(is_equal_approx(config.boss_projectile_turn_time_variation, source.boss_projectile_turn_time_variation), "Bossprofil %s übernimmt die aktuelle Knickvariation" % profile.get_id())
		_check(is_equal_approx(config.boss_wave_amplitude, source.boss_wave_amplitude), "Bossprofil %s übernimmt die aktuelle Rautenbreite" % profile.get_id())
		_check(is_equal_approx(config.boss_wave_length, source.boss_wave_length), "Bossprofil %s übernimmt die aktuelle Rautenlänge" % profile.get_id())
		_check(config.boss_phase_minions == source.boss_phase_minions, "Bossprofil %s übernimmt die aktuellen Phasenadds" % profile.get_id())
		_check(config.boss_phase_health_thresholds == source.boss_phase_health_thresholds, "Bossprofil %s übernimmt die aktuellen Phasengrenzen" % profile.get_id())
		_check(is_equal_approx(config.boss_aura_screen_diameter_fraction, source.boss_aura_screen_diameter_fraction), "Bossprofil %s übernimmt die aktuelle Aura" % profile.get_id())
		_check(is_equal_approx(config.boss_aura_speed_multiplier, source.boss_aura_speed_multiplier), "Bossprofil %s übernimmt den aktuellen Aura-Tempobonus" % profile.get_id())
		_check(is_equal_approx(config.boss_aura_damage_multiplier, source.boss_aura_damage_multiplier), "Bossprofil %s übernimmt den aktuellen Aura-Schadensbonus" % profile.get_id())
		_check(config.boss_projectiles_require_empty_aura == source.boss_projectiles_require_empty_aura, "Bossprofil %s übernimmt die aktuelle Schussbedingung" % profile.get_id())
		_check(is_equal_approx(config.boss_reinforcement_interval, source.boss_reinforcement_interval), "Bossprofil %s übernimmt das aktuelle Verstärkungsintervall" % profile.get_id())
		_check(config.boss_reinforcement_count == source.boss_reinforcement_count, "Bossprofil %s übernimmt die aktuelle Verstärkungsgröße" % profile.get_id())
		_check(config.boss_reinforcement_minimum_phase == source.boss_reinforcement_minimum_phase, "Bossprofil %s übernimmt die aktuelle Verstärkungsphase" % profile.get_id())
		_check(is_equal_approx(config.boss_add_defense_burst_shooting_lock_seconds, source.boss_add_defense_burst_shooting_lock_seconds), "Bossprofil %s übernimmt die aktuelle Stoß-Schusssperre der Adds" % profile.get_id())
		_check(is_equal_approx(config.boss_add_projectile_attack_speed_multiplier, source.boss_add_projectile_attack_speed_multiplier), "Bossprofil %s übernimmt die aktuelle Add-Schussrate" % profile.get_id())
		_check(config.boss_count == profile.get_boss_count(), "Bossprofil %s übernimmt die aktuelle Bossanzahl" % profile.get_id())


func _configured_run(
	levels: Array[LevelDefinition],
	scenario: PracticeScenarioDefinition,
	profile: PracticeBossProfile
) -> RunConfig:
	var baseline := _level_by_id(levels, scenario.get_source_case_id())
	if baseline == null and profile != null:
		baseline = _level_by_id(levels, profile.get_source_case_id())
	if baseline == null:
		baseline = levels[-1]
	var game := GameScript.new()
	game.levels = levels
	game.config = RunConfig.from_level(baseline)
	if profile != null:
		_poison_boss_contract(game.config, baseline)
	var context := RunContext.create_practice(scenario, profile, 2026082400, PreparedLoadout.default_loadout())
	game._configure_practice_run_config(context)
	var result := game.config
	game.free()
	return result


func _poison_boss_contract(config: RunConfig, source: LevelDefinition) -> void:
	config.boss_enemy_id = &"__poison__"
	config.boss_health_multiplier = -999.0
	config.enemy_speed_multiplier = -999.0
	config.boss_speed_multiplier = -999.0
	config.contact_damage_multiplier = -999.0
	config.boss_ranged_enabled = not source.boss_ranged_enabled
	config.boss_projectile_damage_multiplier = -999.0
	config.boss_projectile_attack_speed_multiplier = -999.0
	config.boss_projectile_speed_multiplier = -999.0
	config.boss_projectile_pattern = &"__poison__"
	config.boss_projectile_turn_time_variation = -999.0
	config.boss_projectiles_require_empty_aura = not source.boss_projectiles_require_empty_aura
	config.boss_wave_amplitude = -999.0
	config.boss_wave_length = -999.0
	config.boss_phase_minions = PackedInt32Array([999])
	config.boss_phase_health_thresholds = PackedFloat32Array([0.12345])
	config.boss_aura_screen_diameter_fraction = -999.0
	config.boss_aura_speed_multiplier = -999.0
	config.boss_aura_damage_multiplier = -999.0
	config.boss_reinforcement_interval = -999.0
	config.boss_reinforcement_count = -999
	config.boss_reinforcement_minimum_phase = -999
	config.boss_add_defense_burst_shooting_lock_seconds = -999.0
	config.boss_add_projectile_attack_speed_multiplier = -999.0
	config.boss_count = 99


func _scenario_by_id(values: Array[PracticeScenarioDefinition], id: StringName) -> PracticeScenarioDefinition:
	for value in values:
		if value.get_id() == id:
			return value
	return null


func _level_by_id(values: Array[LevelDefinition], id: StringName) -> LevelDefinition:
	for value in values:
		if value.id == id:
			return value
	return null


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_PRACTICE_RUNTIME_CONTRACT_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
