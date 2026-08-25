extends SceneTree

const GameScript := preload("res://scripts/game.gd")
const PracticeScenarioScript := preload("res://scripts/data/practice_scenario_definition.gd")
const PracticeBossProfileScript := preload("res://scripts/data/practice_boss_profile.gd")

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_run_context_contract()
	_check_practice_run_configs()
	_check_obstacle_definition_contract()
	await _check_result_abort_and_runtime_obstacles()
	_finish()


func _check_run_context_contract() -> void:
	var scenario := PracticeScenarioScript.get_by_id(&"boss_test")
	var profile := PracticeBossProfileScript.get_by_id(&"diamond_infection_focus")
	var loadout := PreparedLoadout.create(
		&"treatment_precision",
		[&"ability_defense_burst", &"ability_treatment_line"]
	)
	var context := RunContext.create_practice(
		scenario,
		profile,
		2026082403,
		loadout,
		{&"talent_precision": 2}
	)
	var copy := context.duplicate_context()
	_check(context.is_practice_test() and context.mode == RunContext.Mode.PRACTICE_TEST, "Praxis-Kontext besitzt den expliziten Laufmodus")
	_check(copy != context and copy.is_practice_test() and copy.mode == context.mode, "Kontextduplikation bewahrt den Praxismodus")
	_check(copy.practice_scenario != context.practice_scenario, "Kontextduplikation trennt die Szenarioinstanz")
	_check(copy.practice_scenario.get_id() == &"boss_test", "Kontextduplikation bewahrt die Szenario-ID")
	_check(copy.practice_boss_profile != context.practice_boss_profile, "Kontextduplikation trennt die Bossprofilinstanz")
	_check(copy.practice_boss_profile.get_id() == &"diamond_infection_focus", "Kontextduplikation bewahrt die Bossprofil-ID")
	_check(copy.seed == 2026082403 and copy.talent_rank(&"talent_precision") == 2, "Kontextduplikation bewahrt Seed und Talent-Snapshot")
	_check(copy.loadout_snapshot != context.loadout_snapshot and copy.loadout_snapshot.to_dict() == context.loadout_snapshot.to_dict(), "Kontextduplikation bewahrt einen getrennten Loadout-Snapshot")

	var game := GameScript.new()
	var resolved := game._resolved_run_context(context)
	_check(resolved != context and resolved.is_practice_test(), "Game löst einen Praxis-Kontext als getrennte Kopie auf")
	_check(resolved.practice_scenario.get_id() == &"boss_test" and resolved.practice_boss_profile.get_id() == &"diamond_infection_focus", "Game-Auflösung bewahrt Szenario und Bossprofil")
	game.free()


func _check_practice_run_configs() -> void:
	var spawn := _configured_practice_run(&"spawn_test")
	_check_common_config(spawn, 12, 6, 180.0, 1.10, true, false)
	_check(is_equal_approx(spawn.cluster_chance_start, 0.5) and is_equal_approx(spawn.cluster_chance_end, 0.5), "Spawn-Test aktiviert die gemischte Endloswelle")
	_check(spawn.run_duration_seconds >= 1.0e11, "Spawn-Test besitzt einen praktisch endlosen Laufhorizont")

	var obstacle := _configured_practice_run(&"obstacle_test")
	_check_common_config(obstacle, 8, 4, 180.0, 1.10, true, false)
	_check(is_equal_approx(obstacle.cluster_chance_start, 0.5) and is_equal_approx(obstacle.cluster_chance_end, 0.5), "Hindernis-Test aktiviert dieselbe gemischte Endloswelle")
	_check(obstacle.run_duration_seconds >= 1.0e11, "Hindernis-Test besitzt einen praktisch endlosen Laufhorizont")

	var profiles: Array = PracticeBossProfileScript.catalog()
	_check(profiles.size() == 4, "Praxislaufzeit besitzt genau vier Bossprofile")
	var expected_profile_ids := [
		&"intro_boss",
		&"bacterial_core",
		&"diamond_infection_focus",
		&"standard_infection_focus",
	]
	for index in range(mini(profiles.size(), expected_profile_ids.size())):
		var profile = profiles[index]
		_check(profile.get_id() == expected_profile_ids[index], "Bossprofil %d bewahrt seine feste ID" % index)
		_check(not profile.get_title().is_empty() and not profile.get_description().is_empty(), "Bossprofil %s besitzt vollständige Präsentationsdaten" % profile.get_id())
		_check(profile.get_source_case_id() != &"" and profile.get_visual_id() == &"infection_focus", "Bossprofil %s besitzt Herkunftsfall und Visual-ID" % profile.get_id())
		var boss := _configured_practice_run(&"boss_test", profile.get_id())
		_check_common_config(boss, 0, 0, 0.0, 0.0, false, true)
		_check(is_equal_approx(boss.run_duration_seconds, 2.0), "Bossprofil %s startet nach zwei Sekunden" % profile.get_id())
		_check(boss.boss_enemy_id == profile.get_enemy_id(), "Bossprofil %s überträgt die Gegner-ID" % profile.get_id())
		_check(is_equal_approx(boss.boss_health_multiplier, profile.get_health_multiplier()), "Bossprofil %s überträgt den Lebensfaktor" % profile.get_id())
		_check(is_equal_approx(boss.enemy_speed_multiplier, profile.get_enemy_speed_multiplier()), "Bossprofil %s überträgt den globalen Tempofaktor" % profile.get_id())
		_check(is_equal_approx(boss.boss_speed_multiplier, profile.get_boss_speed_multiplier()), "Bossprofil %s überträgt den Boss-Tempofaktor" % profile.get_id())
		_check(is_equal_approx(boss.contact_damage_multiplier, profile.get_contact_damage_multiplier()), "Bossprofil %s überträgt den Kontaktfaktor" % profile.get_id())
		_check(boss.boss_ranged_enabled == profile.is_ranged_enabled(), "Bossprofil %s überträgt den Fernkampfschalter" % profile.get_id())
		_check(is_equal_approx(boss.boss_projectile_damage_multiplier, profile.get_projectile_damage_multiplier()), "Bossprofil %s überträgt den Projektilfaktor" % profile.get_id())
		_check(is_equal_approx(boss.boss_wave_amplitude, profile.get_wave_amplitude()), "Bossprofil %s überträgt die Projektilamplitude" % profile.get_id())
		_check(boss.boss_phase_minions == profile.get_phase_minions(), "Bossprofil %s überträgt alle Phasen" % profile.get_id())
		_check(boss.boss_count == profile.get_boss_count(), "Bossprofil %s überträgt die Bossanzahl" % profile.get_id())
		_check(is_equal_approx(boss.boss_projectile_attack_speed_multiplier, profile.get_projectile_attack_speed_multiplier()), "Bossprofil %s überträgt die Schussrate" % profile.get_id())
		_check(is_equal_approx(boss.boss_reinforcement_interval, profile.get_reinforcement_interval()), "Bossprofil %s überträgt das Verstärkungsintervall" % profile.get_id())
		_check(boss.boss_reinforcement_count == profile.get_reinforcement_count(), "Bossprofil %s überträgt die Verstärkungsmenge" % profile.get_id())
		_check(boss.boss_reinforcement_minimum_phase == profile.get_reinforcement_minimum_phase(), "Bossprofil %s überträgt die Verstärkungsphase" % profile.get_id())
		_check(is_equal_approx(boss.boss_add_defense_burst_shooting_lock_seconds, profile.get_add_defense_burst_shooting_lock_seconds()), "Bossprofil %s überträgt die Stoß-Sperre der Adds" % profile.get_id())


func _configured_practice_run(scenario_id: StringName, profile_id: StringName = &"") -> RunConfig:
	var scenario := PracticeScenarioScript.get_by_id(scenario_id)
	var profile = PracticeBossProfileScript.get_by_id(profile_id) if profile_id != &"" else null
	var context := RunContext.create_practice(
		scenario,
		profile,
		2026082400,
		PreparedLoadout.default_loadout()
	)
	var game := GameScript.new()
	game.config = RunConfig.new()
	game._configure_practice_run_config(context)
	var result: RunConfig = game.config
	game.free()
	return result


func _check_common_config(
	config: RunConfig,
	initial_small: int,
	initial_medium: int,
	ramp_seconds: float,
	spawn_multiplier: float,
	regular_spawns: bool,
	automatic_boss: bool
) -> void:
	_check(config.initial_small_enemy_count == initial_small, "Praxis-Config bewahrt die kleine Startfüllung %d" % initial_small)
	_check(config.initial_cluster_enemy_count == initial_medium, "Praxis-Config bewahrt die mittlere Startfüllung %d" % initial_medium)
	_check(is_equal_approx(config.spawn_ramp_seconds, ramp_seconds), "Praxis-Config bewahrt die Rampe %.0f s" % ramp_seconds)
	_check(is_equal_approx(config.spawn_rate_multiplier, spawn_multiplier), "Praxis-Config bewahrt den Spawnfaktor %.2f" % spawn_multiplier)
	_check(config.regular_spawns_enabled == regular_spawns, "Praxis-Config bewahrt den Wellenmodus")
	_check(config.regular_spawn_weight_cap == (145 if regular_spawns else 0), "Praxis-Config überträgt ihr explizites Wellengewichtslimit")
	_check(config.automatic_boss_enabled == automatic_boss, "Praxis-Config bewahrt den automatischen Bossmodus")
	_check(not config.event_driven_intro and not config.has_deadline(), "Praxis-Config deaktiviert Introereignisse und Deadline")
	_check(is_zero_approx(config.reward_multiplier), "Praxis-Config deaktiviert Belohnungen")
	_check(is_equal_approx(config.experience_gain_multiplier, 1.0), "Praxis-Config bewahrt normalen Erfahrungsgewinn")
	_check(config.case_pressure_plan == null and not config.case_pressure_targets_stationary, "Praxis-Config deaktiviert Fall-Druckereignisse")
	if not regular_spawns:
		_check(is_zero_approx(config.cluster_chance_start) and is_zero_approx(config.cluster_chance_end), "Praxis-Config ohne Wellen deaktiviert beide Clusterchancen")


func _check_obstacle_definition_contract() -> void:
	var scenario := PracticeScenarioScript.get_by_id(&"obstacle_test")
	var obstacles: Array = scenario.get_obstacles()
	var expected_positions := [
		Vector2(-280.0, -140.0),
		Vector2(-280.0, 140.0),
		Vector2(260.0, 0.0),
	]
	_check(obstacles.size() == 3, "Hindernis-Test definiert genau drei Laufzeithindernisse")
	for index in range(expected_positions.size()):
		var obstacle = obstacles[index]
		_check(obstacle.get_position() == expected_positions[index], "Hindernis %d bewahrt seine exakte Position" % index)
		_check(obstacle.get_body_role() == EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE, "Hindernis %d bewahrt STATIC_FLOW_OBSTACLE" % index)
		_check(obstacle.get_obstacle_traversal() == EnemySpawnRequest.ObstacleTraversal.DEFAULT, "Hindernis %d bewahrt die normale Umlaufregel" % index)
		_check(is_equal_approx(obstacle.get_health_multiplier(), 20.0), "Hindernis %d bewahrt zwanzigfaches Leben" % index)


func _check_result_abort_and_runtime_obstacles() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.persistence_enabled = false
	game.test_tools_available = true
	game.practice_scenarios = PracticeScenarioScript.catalog()
	game.practice_boss_profiles = PracticeBossProfileScript.catalog()
	game.meta.reset_defaults(710000)
	game.discovery_manager.configure(game.discovery_definitions, {})
	var untouched_signature := _meta_signature(game.meta)

	game._show_practice()
	game._on_practice_scenario_selected(&"obstacle_test")
	_check(game.flow_state == GameFlowState.State.PREPARATION, "Hindernis-Test erreicht ohne Save-Schreibpfad die Einsatzplanung")
	game._on_preparation_start_requested(game.pending_preparation_loadout.to_dict())
	_check(game.flow_state == GameFlowState.State.RUNNING and game.active_run_context.is_practice_test(), "Hindernis-Test startet im expliziten Praxismodus")
	_check_runtime_obstacles(game)
	_check_practice_group_spawns_ignore_discovery_gate(game)
	game._set_flow(GameFlowState.State.MANUAL_PAUSE)
	game.hud.show_pause(false, game.stats, game.state)
	game._on_abort_requested()
	game._on_abort_confirmed()
	await process_frame
	_check(game.flow_state == GameFlowState.State.PRACTICE, "Praxisabbruch kehrt direkt zur Praxis zurück")
	_check(_meta_signature(game.meta) == untouched_signature, "Praxisabbruch lässt MetaProgressionState.to_dict() bytegleich")

	var before_result := _meta_signature(game.meta)
	game._on_practice_scenario_selected(&"boss_test")
	game._on_practice_boss_profile_selected(&"intro_boss")
	_check(game.flow_state == GameFlowState.State.PREPARATION, "Boss-Test erreicht ohne Save-Schreibpfad die Einsatzplanung")
	game._on_preparation_start_requested(game.pending_preparation_loadout.to_dict())
	_check(game.flow_state == GameFlowState.State.RUNNING and game.active_run_context.is_practice_test(), "Boss-Test startet im expliziten Praxismodus")
	game.state.finish(true, "Praxis-Boss kontrolliert.")
	await process_frame
	_check(game.flow_state == GameFlowState.State.RESULT, "Praxisresultat verwendet den lokalen Ergebniszweig")
	_check(_meta_signature(game.meta) == before_result, "Praxisresultat lässt MetaProgressionState.to_dict() bytegleich")

	game.queue_free()
	await process_frame
	paused = false


func _check_runtime_obstacles(game: Node) -> void:
	var expected_positions := [
		Vector2(-280.0, -140.0),
		Vector2(-280.0, 140.0),
		Vector2(260.0, 0.0),
	]
	var actual_positions: Array[Vector2] = []
	for enemy in game.enemies:
		if not enemy.is_static_flow_obstacle():
			continue
		actual_positions.append(enemy.position)
		_check(enemy.body_role == EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE, "Materialisiertes Hindernis bewahrt seine Körperrolle")
		_check(enemy.obstacle_traversal == EnemySpawnRequest.ObstacleTraversal.DEFAULT, "Materialisiertes Hindernis bewahrt DEFAULT als authored Umlaufregel")
		_check(enemy.resolved_obstacle_traversal() == EnemySpawnRequest.ObstacleTraversal.FLOW_AROUND, "Materialisiertes Hindernis löst die normale Umlaufregel zu FLOW_AROUND auf")
	_check(actual_positions.size() == 3, "Hindernis-Test materialisiert genau drei statische Hindernisse")
	for expected in expected_positions:
		_check(actual_positions.has(expected), "Materialisiertes Hindernis steht exakt bei %s" % expected)


func _check_practice_group_spawns_ignore_discovery_gate(game: Node) -> void:
	_check(not game.discovery_manager.has_seen(&"pneumococcus"), "Frischer Praxistest besitzt absichtlich keine Kampagnenentdeckung")
	var groups_before := 0
	for enemy in game.enemies:
		if enemy.definition != null and enemy.definition.id == &"bacterial_cluster":
			groups_before += 1
	game.config.cluster_chance_start = 1.0
	game.config.cluster_chance_end = 1.0
	game.standard_wave_director.force_next_wave()
	game.state.elapsed = 1.0
	game._spawn_step(4.5)
	var groups_after := 0
	for enemy in game.enemies:
		if enemy.definition != null and enemy.definition.id == &"bacterial_cluster":
			groups_after += 1
	_check(groups_after > groups_before, "Praxis-Gruppenmix funktioniert ohne freigeschaltete Kampagnenentdeckung")


func _meta_signature(meta: MetaProgressionState) -> PackedByteArray:
	return var_to_bytes(meta.to_dict())


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
