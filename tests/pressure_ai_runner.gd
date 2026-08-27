extends SceneTree

## Fixed-seed, graphics-free acceptance scenarios for the two crowd-pressure
## exploits that the offscreen director must close:
##
## 1. A one-sided 220-body crowd must become several local attack fronts while
##    Doctor Milos keeps running in a circle.
## 2. A gathered crowd must not remain entirely behind the camera while Doctor
##    Milos escapes in one straight direction. Relocated bodies must always
##    materialize fully outside both camera rectangles bracketing that tick.
##
## The runner reports wall time, but asserts only deterministic gameplay
## results and bounded EnemyWorld work.

const CIRCLE_RUN_SEED := 0x5052455353555245
const LINEAR_RUN_SEED := 0x4C494E4541525052
const FIXED_DELTA := 1.0 / 60.0
const ENEMY_COUNT := 220
const SECTOR_COUNT := 12
const SAMPLE_INTERVAL_TICKS := 15
const PRESSURE_SECTOR_THRESHOLD := 0.35
const RELOCATION_DISTANCE_THRESHOLD := 120.0
const MINIMUM_RELOCATION_SECTOR_DISTANCE := 2

const CIRCLE_SIMULATION_TICKS := 2700
const CIRCLE_EARLY_WINDOW_TICKS := 360
const CIRCLE_LATE_WINDOW_START_TICK := 1350
const ORBIT_RADIUS := 230.0
const NEAR_PRESSURE_RADIUS := 330.0

const MINIMUM_CIRCLE_RELOCATION_EVENTS := 24
const MINIMUM_CIRCLE_DISTINCT_RELOCATIONS := 14
const MINIMUM_RELOCATION_TARGET_SECTORS := 8
const MINIMUM_LATE_PRESSURE_SECTORS := 5.0
const MINIMUM_LATE_NEAR_SECTORS := 2.0
const MINIMUM_PEAK_NEAR_SECTORS := 4
const MINIMUM_CIRCLE_CONTACT_EVENTS := 4
const MINIMUM_CIRCLE_DISTINCT_CONTACTORS := 2

const LINEAR_SIMULATION_TICKS := 1800
const LINEAR_LATE_WINDOW_START_TICK := 600
const LINEAR_START_OFFSET := Vector2(-1600.0, 0.0)
const LINEAR_DIRECTION := Vector2.RIGHT
const LINEAR_REACHABLE_RADIUS := 360.0
const LINEAR_REAR_TOLERANCE := 20.0

const MINIMUM_LINEAR_TRAVEL_DISTANCE := 2500.0
const MINIMUM_LINEAR_RELOCATION_EVENTS := 320
const MINIMUM_LINEAR_DISTINCT_RELOCATIONS := 80
const MINIMUM_LINEAR_FRONT_SIDE_SAMPLE_RATIO := 0.55
const MINIMUM_LINEAR_VISIBLE_FRONT_SIDE_AVERAGE := 4.75
const MINIMUM_LINEAR_REACHABLE_FRONT_SIDE_AVERAGE := 4.75
const MINIMUM_LINEAR_FRONT_SIDE_SECTOR_AVERAGE := 3.0
const MINIMUM_LINEAR_CONTACT_EVENTS := 4
const MINIMUM_LINEAR_DISTINCT_CONTACTORS := 2
const MAXIMUM_LINEAR_MINIMUM_REAR_BACKLOG_RATIO := 0.85

var assertions := 0
var failures := 0
var contact_events := 0
var contact_enemy_ids: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.physics_ticks_per_second = 60

	var circle_game = await _prepare_game(CIRCLE_RUN_SEED)
	var relocation_rate_contract := _assert_proportional_rate_contract(circle_game)
	var circle_result := _run_circle_case(circle_game)
	await _dispose_game(circle_game)

	var linear_game = await _prepare_game(LINEAR_RUN_SEED)
	var linear_result := _run_linear_escape_case(linear_game)
	await _dispose_game(linear_game)

	var report := {
		"schema": "alveolus.pressure_ai.v5",
		"passed": failures == 0,
		"enemies_per_case": ENEMY_COUNT,
		"relocation_rate_contract": relocation_rate_contract,
		"circle": circle_result,
		"linear_escape": linear_result,
	}
	print("ALVEOLUS_PRESSURE_AI_JSON=%s" % JSON.stringify(report))
	if failures == 0:
		print("ALVEOLUS_PRESSURE_AI_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_PRESSURE_AI_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)


func _prepare_game(run_seed: int) -> Node:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	game.quick_run = true
	game.persistence_enabled = false
	game.run_test_settings.reset_defaults()
	game.meta.reset_defaults()
	game.discovery_manager.configure(game.discovery_definitions, {})
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = game.levels[1]
	var context := RunContext.create(
		game.selected_level.id,
		run_seed,
		PreparedLoadout.default_loadout(),
		{},
		&""
	)
	game.start_run(context)
	game.set_physics_process(false)
	game.standard_wave_director.cancel()
	game.treatment_controller.enabled = false
	game.ability_controller.clear()
	game.config.run_duration_seconds = 100000.0
	game.config.final_deadline_seconds = 100000.0
	game.config.contact_damage_multiplier = 0.0
	game.state.max_stability = 1000000000.0
	game.state.stability = game.state.max_stability
	game.enemy_world.set_crowd_profile_enabled(true)
	return game


func _dispose_game(game: Node) -> void:
	_release_movement_input()
	paused = false
	if is_instance_valid(game):
		game.queue_free()
	await process_frame


func _run_circle_case(game: Node) -> Dictionary:
	contact_events = 0
	contact_enemy_ids.clear()
	var orbit_center: Vector2 = game.topology.bounds.get_center()
	game.avatar.global_position = orbit_center + Vector2(ORBIT_RADIUS, 0.0)
	game.avatar.reset_physics_interpolation()
	game.avatar.input_enabled = true
	var tracked_enemies := _build_one_sided_crowd(game, orbit_center, 0.0)
	_true(tracked_enemies.size() == ENEMY_COUNT, "Der Kreisfall hält exakt %d Gegner" % ENEMY_COUNT)

	var previous_positions := _initial_positions(tracked_enemies)
	var relocation_events := 0
	var relocated_enemy_ids: Dictionary = {}
	var relocation_visibility_violations := 0
	var relocation_source_neighborhood_violations := 0
	var randomized_target_events := 0
	var randomized_depth_events := 0
	var relocation_target_sectors: Dictionary = {}
	var early_pressure_sector_sum := 0.0
	var early_sample_count := 0
	var late_pressure_sector_sum := 0.0
	var late_near_sector_sum := 0.0
	var late_near_enemy_sum := 0.0
	var late_sample_count := 0
	var peak_near_sectors := 0
	var peak_near_enemies := 0
	var started_usec := Time.get_ticks_usec()

	paused = true
	for tick in range(CIRCLE_SIMULATION_TICKS):
		_apply_circular_input(game, orbit_center)
		var visible_before := _current_visible_rect(game)
		_true(game.run_session.step_fixed(FIXED_DELTA), "Kreis-RunSession bleibt in Tick %d aktiv" % tick, false)
		var visible_after := _current_visible_rect(game)

		for index in range(tracked_enemies.size()):
			var enemy: InfectionEnemy = tracked_enemies[index]
			var travelled: float = game.topology.distance(previous_positions[index], enemy.global_position)
			if travelled >= RELOCATION_DISTANCE_THRESHOLD:
				var relocation_avatar_position: Vector2 = game.avatar.global_position
				relocation_events += 1
				relocated_enemy_ids[enemy.get_instance_id()] = true
				if not _relocation_target_is_offscreen(enemy, visible_before, visible_after):
					relocation_visibility_violations += 1
				if not _relocation_target_avoids_source_neighborhood(
					game,
					relocation_avatar_position,
					previous_positions[index],
					enemy.global_position
				):
					relocation_source_neighborhood_violations += 1
				var target_delta: Vector2 = game.topology.shortest_delta(relocation_avatar_position, enemy.global_position)
				relocation_target_sectors[game._sector_for_delta(target_delta)] = true
				if _relocation_target_is_randomized(game, relocation_avatar_position, enemy.global_position):
					randomized_target_events += 1
				if _relocation_target_has_randomized_depth(game, game.avatar.global_position, enemy):
					randomized_depth_events += 1
			previous_positions[index] = enemy.global_position

		if tick % SAMPLE_INTERVAL_TICKS != 0:
			continue
		var sample := _pressure_sample(game, tracked_enemies)
		peak_near_sectors = maxi(peak_near_sectors, int(sample.near_sectors))
		peak_near_enemies = maxi(peak_near_enemies, int(sample.near_enemies))
		if tick < CIRCLE_EARLY_WINDOW_TICKS:
			early_pressure_sector_sum += float(sample.pressure_sectors)
			early_sample_count += 1
		elif tick >= CIRCLE_LATE_WINDOW_START_TICK:
			late_pressure_sector_sum += float(sample.pressure_sectors)
			late_near_sector_sum += float(sample.near_sectors)
			late_near_enemy_sum += float(sample.near_enemies)
			late_sample_count += 1

	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	_release_movement_input()
	paused = false
	var profile: PackedInt64Array = game.enemy_world.crowd_profile_snapshot()
	var early_pressure_average := early_pressure_sector_sum / float(maxi(early_sample_count, 1))
	var late_pressure_average := late_pressure_sector_sum / float(maxi(late_sample_count, 1))
	var late_near_sector_average := late_near_sector_sum / float(maxi(late_sample_count, 1))
	var late_near_enemy_average := late_near_enemy_sum / float(maxi(late_sample_count, 1))
	var maximum_guard_queries := CIRCLE_SIMULATION_TICKS * (
		ceili(float(ENEMY_COUNT) / float(EnemyWorld.DIRECT_COLLISION_UPDATE_PHASES)) + 1
	)

	_true(relocation_events >= MINIMUM_CIRCLE_RELOCATION_EVENTS, "Kreisfall versetzt ausreichend oft (%d / %d)" % [relocation_events, MINIMUM_CIRCLE_RELOCATION_EVENTS])
	_true(relocated_enemy_ids.size() >= MINIMUM_CIRCLE_DISTINCT_RELOCATIONS, "Kreisversetzungen verteilen sich auf mehrere Gegner (%d / %d)" % [relocated_enemy_ids.size(), MINIMUM_CIRCLE_DISTINCT_RELOCATIONS])
	_true(relocation_visibility_violations == 0, "Auch im Kreisfall liegt jedes Versetzungsziel vollständig außerhalb des damaligen Bildes (%d Verstöße)" % relocation_visibility_violations)
	_true(relocation_source_neighborhood_violations == 0, "Kreisversetzungen meiden Quellsektor und direkte Nachbarsektoren (%d Verstöße)" % relocation_source_neighborhood_violations)
	_true(relocation_target_sectors.size() >= MINIMUM_RELOCATION_TARGET_SECTORS, "Kreisversetzungen streuen über mindestens %d Zielsektoren (%d)" % [MINIMUM_RELOCATION_TARGET_SECTORS, relocation_target_sectors.size()])
	_true(randomized_target_events >= relocation_events / 2, "Kreisversetzungen landen mehrheitlich nicht auf exakten Sektormittelpunkten (%d / %d)" % [randomized_target_events, relocation_events])
	_true(randomized_depth_events >= relocation_events / 2, "Kreisversetzungen streuen mehrheitlich auch ihre Tiefe (%d / %d)" % [randomized_depth_events, relocation_events])
	_true(late_pressure_average >= MINIMUM_LATE_PRESSURE_SECTORS, "Später lokaler Kreisdruck belegt mehrere Sektoren (%.2f / %.2f)" % [late_pressure_average, MINIMUM_LATE_PRESSURE_SECTORS])
	_true(late_near_sector_average >= MINIMUM_LATE_NEAR_SECTORS, "Nahe Gegner greifen im Kreis aus mehreren Richtungen an (%.2f / %.2f)" % [late_near_sector_average, MINIMUM_LATE_NEAR_SECTORS])
	_true(peak_near_sectors >= MINIMUM_PEAK_NEAR_SECTORS, "Der Kreisexploit erzeugt mindestens %d gleichzeitige Nahfronten (%d)" % [MINIMUM_PEAK_NEAR_SECTORS, peak_near_sectors])
	_true(contact_events >= MINIMUM_CIRCLE_CONTACT_EVENTS, "Kreisendes Laufen bleibt nicht schadlos (%d / %d Kontakte)" % [contact_events, MINIMUM_CIRCLE_CONTACT_EVENTS])
	_true(contact_enemy_ids.size() >= MINIMUM_CIRCLE_DISTINCT_CONTACTORS, "Mehr als ein Gegner erreicht den kreisenden Doctor (%d / %d)" % [contact_enemy_ids.size(), MINIMUM_CIRCLE_DISTINCT_CONTACTORS])
	_assert_bounded_crowd_work(profile, maximum_guard_queries, "Kreisfall")

	return {
		"ticks": CIRCLE_SIMULATION_TICKS,
		"elapsed_ms_informational": elapsed_ms,
		"relocation_events": relocation_events,
		"distinct_relocated_enemies": relocated_enemy_ids.size(),
		"relocation_visibility_violations": relocation_visibility_violations,
		"relocation_source_neighborhood_violations": relocation_source_neighborhood_violations,
		"relocation_target_sectors": relocation_target_sectors.size(),
		"randomized_target_events": randomized_target_events,
		"randomized_depth_events": randomized_depth_events,
		"early_pressure_sectors_avg": early_pressure_average,
		"late_pressure_sectors_avg": late_pressure_average,
		"late_near_sectors_avg": late_near_sector_average,
		"late_near_enemies_avg": late_near_enemy_average,
		"peak_near_sectors": peak_near_sectors,
		"peak_near_enemies": peak_near_enemies,
		"contact_events": contact_events,
		"distinct_contactors": contact_enemy_ids.size(),
		"crowd_profile": _crowd_profile_report(profile),
	}


func _run_linear_escape_case(game: Node) -> Dictionary:
	contact_events = 0
	contact_enemy_ids.clear()
	var start_position: Vector2 = game.topology.bounds.get_center() + LINEAR_START_OFFSET
	game.avatar.global_position = start_position
	game.avatar.reset_physics_interpolation()
	# CharacterBody2D.move_and_slide() is intentionally not the subject of this
	# graphics-free harness. Under a paused SceneTree it integrates only a tiny
	# fraction of the requested motion on this target platform. Drive the avatar
	# by the same deterministic 3 px fixed-step request so this case isolates the
	# camera-relative spawn and relocation director.
	game.avatar.input_enabled = false
	_current_visible_rect(game)
	var tracked_enemies := _build_one_sided_crowd(game, start_position, PI)
	_true(tracked_enemies.size() == ENEMY_COUNT, "Der geradlinige Fluchtfall hält exakt %d Gegner" % ENEMY_COUNT)
	var initial_pressure_sample := _linear_pressure_sample(
		game,
		tracked_enemies,
		_avatar_centered_visible_rect(game)
	)
	var initial_rear_backlog := int(initial_pressure_sample.rear_offscreen_enemies)
	var initial_rear_max_sector_backlog := int(initial_pressure_sample.rear_offscreen_max_sector_enemies)

	var previous_positions := _initial_positions(tracked_enemies)
	var relocation_events := 0
	var relocated_enemy_ids: Dictionary = {}
	var relocation_visibility_violations := 0
	var relocation_source_neighborhood_violations := 0
	var randomized_target_events := 0
	var randomized_depth_events := 0
	var relocation_target_sectors: Dictionary = {}
	var late_sample_count := 0
	var late_samples_with_front_side := 0
	var late_visible_front_side_sum := 0.0
	var late_reachable_front_side_sum := 0.0
	var late_front_side_sector_sum := 0.0
	var late_rear_backlog_sum := 0.0
	var late_rear_max_sector_backlog_sum := 0.0
	var peak_visible_front_side := 0
	var peak_reachable_front_side := 0
	var minimum_rear_backlog := initial_rear_backlog
	var minimum_rear_max_sector_backlog := initial_rear_max_sector_backlog
	var started_usec := Time.get_ticks_usec()

	paused = true
	for tick in range(LINEAR_SIMULATION_TICKS):
		_advance_linear_avatar(game)
		var visible_before := _current_visible_rect(game)
		_true(game.run_session.step_fixed(FIXED_DELTA), "Flucht-RunSession bleibt in Tick %d aktiv" % tick, false)
		var visible_after := _current_visible_rect(game)

		for index in range(tracked_enemies.size()):
			var enemy: InfectionEnemy = tracked_enemies[index]
			var travelled: float = game.topology.distance(previous_positions[index], enemy.global_position)
			if travelled >= RELOCATION_DISTANCE_THRESHOLD:
				var relocation_avatar_position: Vector2 = game.avatar.global_position
				relocation_events += 1
				relocated_enemy_ids[enemy.get_instance_id()] = true
				if not _relocation_target_is_offscreen(enemy, visible_before, visible_after):
					relocation_visibility_violations += 1
				if not _relocation_target_avoids_source_neighborhood(
					game,
					relocation_avatar_position,
					previous_positions[index],
					enemy.global_position
				):
					relocation_source_neighborhood_violations += 1
				var target_delta: Vector2 = game.topology.shortest_delta(relocation_avatar_position, enemy.global_position)
				relocation_target_sectors[game._sector_for_delta(target_delta)] = true
				if _relocation_target_is_randomized(game, relocation_avatar_position, enemy.global_position):
					randomized_target_events += 1
				if _relocation_target_has_randomized_depth(game, game.avatar.global_position, enemy):
					randomized_depth_events += 1
			previous_positions[index] = enemy.global_position

		if tick < LINEAR_LATE_WINDOW_START_TICK or tick % SAMPLE_INTERVAL_TICKS != 0:
			continue
		var sample := _linear_pressure_sample(game, tracked_enemies, _avatar_centered_visible_rect(game))
		late_sample_count += 1
		late_visible_front_side_sum += float(sample.visible_front_side_enemies)
		late_reachable_front_side_sum += float(sample.reachable_front_side_enemies)
		late_front_side_sector_sum += float(sample.front_side_sectors)
		late_rear_backlog_sum += float(sample.rear_offscreen_enemies)
		late_rear_max_sector_backlog_sum += float(sample.rear_offscreen_max_sector_enemies)
		peak_visible_front_side = maxi(peak_visible_front_side, int(sample.visible_front_side_enemies))
		peak_reachable_front_side = maxi(peak_reachable_front_side, int(sample.reachable_front_side_enemies))
		minimum_rear_backlog = mini(minimum_rear_backlog, int(sample.rear_offscreen_enemies))
		minimum_rear_max_sector_backlog = mini(
			minimum_rear_max_sector_backlog,
			int(sample.rear_offscreen_max_sector_enemies)
		)
		if int(sample.visible_front_side_enemies) > 0:
			late_samples_with_front_side += 1

	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	_release_movement_input()
	paused = false
	var profile: PackedInt64Array = game.enemy_world.crowd_profile_snapshot()
	var travel_distance: float = game.topology.distance(start_position, game.avatar.global_position)
	var late_visible_front_side_average := late_visible_front_side_sum / float(maxi(late_sample_count, 1))
	var late_reachable_front_side_average := late_reachable_front_side_sum / float(maxi(late_sample_count, 1))
	var late_front_side_sector_average := late_front_side_sector_sum / float(maxi(late_sample_count, 1))
	var late_rear_backlog_average := late_rear_backlog_sum / float(maxi(late_sample_count, 1))
	var late_rear_backlog_ratio := late_rear_backlog_average / float(maxi(initial_rear_backlog, 1))
	var minimum_rear_backlog_ratio := float(minimum_rear_backlog) / float(maxi(initial_rear_backlog, 1))
	var late_rear_max_sector_backlog_average := late_rear_max_sector_backlog_sum / float(maxi(late_sample_count, 1))
	var late_rear_max_sector_backlog_ratio := (
		late_rear_max_sector_backlog_average / float(maxi(initial_rear_max_sector_backlog, 1))
	)
	var final_pressure_sample := _linear_pressure_sample(
		game,
		tracked_enemies,
		_avatar_centered_visible_rect(game)
	)
	var final_rear_backlog := int(final_pressure_sample.rear_offscreen_enemies)
	var final_rear_max_sector_backlog := int(final_pressure_sample.rear_offscreen_max_sector_enemies)
	var front_side_sample_ratio := float(late_samples_with_front_side) / float(maxi(late_sample_count, 1))
	var maximum_guard_queries := LINEAR_SIMULATION_TICKS * (
		ceili(float(ENEMY_COUNT) / float(EnemyWorld.DIRECT_COLLISION_UPDATE_PHASES)) + 1
	)

	_true(travel_distance >= MINIMUM_LINEAR_TRAVEL_DISTANCE, "Der Fluchtfall legt wirklich eine lange Gerade zurück (%.1f / %.1f)" % [travel_distance, MINIMUM_LINEAR_TRAVEL_DISTANCE])
	_true(relocation_events >= MINIMUM_LINEAR_RELOCATION_EVENTS, "Geradlinige Flucht löst ausreichend Offscreen-Versetzungen aus (%d / %d)" % [relocation_events, MINIMUM_LINEAR_RELOCATION_EVENTS])
	_true(relocated_enemy_ids.size() >= MINIMUM_LINEAR_DISTINCT_RELOCATIONS, "Fluchtversetzungen verwenden ausreichend verschiedene Gegner (%d / %d)" % [relocated_enemy_ids.size(), MINIMUM_LINEAR_DISTINCT_RELOCATIONS])
	_true(relocation_visibility_violations == 0, "Jedes echte Flucht-Versetzungsziel liegt vollständig außerhalb des damaligen Bildes (%d Verstöße)" % relocation_visibility_violations)
	_true(relocation_source_neighborhood_violations == 0, "Fluchtversetzungen meiden Quellsektor und direkte Nachbarsektoren (%d Verstöße)" % relocation_source_neighborhood_violations)
	_true(relocation_target_sectors.size() >= MINIMUM_RELOCATION_TARGET_SECTORS, "Fluchtversetzungen streuen über mindestens %d Zielsektoren (%d)" % [MINIMUM_RELOCATION_TARGET_SECTORS, relocation_target_sectors.size()])
	_true(randomized_target_events >= relocation_events / 2, "Fluchtversetzungen landen mehrheitlich an gestreuten Punkten (%d / %d)" % [randomized_target_events, relocation_events])
	_true(randomized_depth_events >= relocation_events / 2, "Fluchtversetzungen streuen mehrheitlich auch ihre Tiefe (%d / %d)" % [randomized_depth_events, relocation_events])
	_true(minimum_rear_backlog_ratio <= MAXIMUM_LINEAR_MINIMUM_REAR_BACKLOG_RATIO, "Der Regler baut den gesamten rückwärtigen Rückstau zwischenzeitlich messbar ab (%.2f / %.2f; %d -> %d)" % [minimum_rear_backlog_ratio, MAXIMUM_LINEAR_MINIMUM_REAR_BACKLOG_RATIO, initial_rear_backlog, minimum_rear_backlog])
	_true(front_side_sample_ratio >= MINIMUM_LINEAR_FRONT_SIDE_SAMPLE_RATIO, "Vor oder seitlich bleibt in genügend späten Fluchtsamples Druck sichtbar (%.2f / %.2f)" % [front_side_sample_ratio, MINIMUM_LINEAR_FRONT_SIDE_SAMPLE_RATIO])
	_true(late_visible_front_side_average >= MINIMUM_LINEAR_VISIBLE_FRONT_SIDE_AVERAGE, "Die sichtbare Front-/Seitengruppe bleibt im Mittel besetzt (%.2f / %.2f)" % [late_visible_front_side_average, MINIMUM_LINEAR_VISIBLE_FRONT_SIDE_AVERAGE])
	_true(late_reachable_front_side_average >= MINIMUM_LINEAR_REACHABLE_FRONT_SIDE_AVERAGE, "Angreifer erreichen im Mittel die Front oder Seite des Doctors (%.2f / %.2f)" % [late_reachable_front_side_average, MINIMUM_LINEAR_REACHABLE_FRONT_SIDE_AVERAGE])
	_true(late_front_side_sector_average >= MINIMUM_LINEAR_FRONT_SIDE_SECTOR_AVERAGE, "Fluchtdruck bleibt nicht nur in einem rückwärtigen Knubbel (%.2f / %.2f Sektoren)" % [late_front_side_sector_average, MINIMUM_LINEAR_FRONT_SIDE_SECTOR_AVERAGE])
	_true(contact_events >= MINIMUM_LINEAR_CONTACT_EVENTS, "Geradliniges Weglaufen bleibt nicht vollständig sicher (%d / %d Kontakte)" % [contact_events, MINIMUM_LINEAR_CONTACT_EVENTS])
	_true(contact_enemy_ids.size() >= MINIMUM_LINEAR_DISTINCT_CONTACTORS, "Mehrere versetzte Angreifer erreichen den fliehenden Doctor (%d / %d)" % [contact_enemy_ids.size(), MINIMUM_LINEAR_DISTINCT_CONTACTORS])
	_assert_bounded_crowd_work(profile, maximum_guard_queries, "Fluchtfall")

	return {
		"ticks": LINEAR_SIMULATION_TICKS,
		"elapsed_ms_informational": elapsed_ms,
		"travel_distance": travel_distance,
		"relocation_events": relocation_events,
		"distinct_relocated_enemies": relocated_enemy_ids.size(),
		"relocation_visibility_violations": relocation_visibility_violations,
		"relocation_source_neighborhood_violations": relocation_source_neighborhood_violations,
		"relocation_target_sectors": relocation_target_sectors.size(),
		"randomized_target_events": randomized_target_events,
		"randomized_depth_events": randomized_depth_events,
		"initial_rear_offscreen_backlog": initial_rear_backlog,
		"late_rear_offscreen_backlog_avg": late_rear_backlog_average,
		"late_rear_offscreen_backlog_ratio": late_rear_backlog_ratio,
		"minimum_rear_offscreen_backlog": minimum_rear_backlog,
		"minimum_rear_offscreen_backlog_ratio": minimum_rear_backlog_ratio,
		"final_rear_offscreen_backlog": final_rear_backlog,
		"initial_rear_offscreen_max_sector_backlog": initial_rear_max_sector_backlog,
		"late_rear_offscreen_max_sector_backlog_avg": late_rear_max_sector_backlog_average,
		"late_rear_offscreen_max_sector_backlog_ratio": late_rear_max_sector_backlog_ratio,
		"minimum_rear_offscreen_max_sector_backlog": minimum_rear_max_sector_backlog,
		"final_rear_offscreen_max_sector_backlog": final_rear_max_sector_backlog,
		"late_front_side_sample_ratio": front_side_sample_ratio,
		"late_visible_front_side_avg": late_visible_front_side_average,
		"late_reachable_front_side_avg": late_reachable_front_side_average,
		"late_front_side_sectors_avg": late_front_side_sector_average,
		"peak_visible_front_side": peak_visible_front_side,
		"peak_reachable_front_side": peak_reachable_front_side,
		"contact_events": contact_events,
		"distinct_contactors": contact_enemy_ids.size(),
		"crowd_profile": _crowd_profile_report(profile),
	}


func _build_one_sided_crowd(game: Node, center: Vector2, wedge_center_angle: float) -> Array[InfectionEnemy]:
	var result: Array[InfectionEnemy] = []
	var columns := 22
	var wedge_radians := 1.46
	var half_extents: Vector2 = game._visible_world_half_extents()
	var base_radius := maxf(half_extents.x + 205.0, 780.0)
	for index in range(ENEMY_COUNT):
		var ring := floori(float(index) / float(columns))
		var column := index % columns
		var ring_phase := 0.5 if ring % 2 != 0 else 0.0
		var angle_fraction := (float(column) + 0.5 + ring_phase) / float(columns)
		var angle := wedge_center_angle - wedge_radians * 0.5 + angle_fraction * wedge_radians
		var radius := base_radius + float(ring) * 58.0
		var definition_id: StringName = &"bacterial_cluster" if index >= 3 and index % 5 == 0 else &"pneumococcus"
		var position: Vector2 = game.topology.resolve_position(
			center + Vector2.from_angle(angle) * radius,
			game._enemy_body_radius(definition_id)
		)
		var enemy: InfectionEnemy
		if index < game.enemies.size():
			enemy = game.enemies[index]
			var previous_position := enemy.global_position
			enemy.global_position = position
			enemy.reset_visual_motion()
			game.enemy_world.mark_enemy_relocated(game.enemy_world.handle_for(enemy), previous_position)
		else:
			enemy = game._spawn_enemy(definition_id, position)
		if not is_instance_valid(enemy):
			continue
		enemy.damage_multiplier = 0.0
		enemy.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
		enemy.pressure_applied.connect(_on_enemy_pressure.bind(enemy.get_instance_id()))
		result.append(enemy)
	return result


func _initial_positions(tracked_enemies: Array[InfectionEnemy]) -> PackedVector2Array:
	var result := PackedVector2Array()
	result.resize(tracked_enemies.size())
	for index in range(tracked_enemies.size()):
		result[index] = tracked_enemies[index].global_position
	return result


func _apply_circular_input(game: Node, center: Vector2) -> void:
	var radial: Vector2 = game.topology.shortest_delta(center, game.avatar.global_position)
	if radial.length_squared() <= 0.001:
		radial = Vector2.RIGHT * ORBIT_RADIUS
	var radial_direction := radial.normalized()
	var radius_error := (ORBIT_RADIUS - radial.length()) / ORBIT_RADIUS
	var desired_direction := (
		radial_direction.orthogonal()
		+ radial_direction * clampf(radius_error * 2.2, -0.38, 0.38)
	).normalized()
	_apply_directional_input(desired_direction)


func _advance_linear_avatar(game: Node) -> void:
	var movement_step: Vector2 = LINEAR_DIRECTION * game.stats.movement_speed * FIXED_DELTA
	game.avatar.global_position = game.topology.resolve_position(
		game.avatar.global_position + movement_step,
		TherapyAvatar.BODY_RADIUS
	)
	game.avatar.velocity = Vector2.ZERO
	if is_instance_valid(game.avatar.camera):
		game.avatar.camera.reset_smoothing()
		game.avatar.camera.align()
		game.avatar.camera.notification(Node.NOTIFICATION_INTERNAL_PHYSICS_PROCESS)
		game.avatar.camera.force_update_scroll()


func _apply_directional_input(desired_direction: Vector2) -> void:
	_release_movement_input()
	if desired_direction.x > 0.0:
		Input.action_press(&"move_right", desired_direction.x)
	elif desired_direction.x < 0.0:
		Input.action_press(&"move_left", -desired_direction.x)
	if desired_direction.y > 0.0:
		Input.action_press(&"move_down", desired_direction.y)
	elif desired_direction.y < 0.0:
		Input.action_press(&"move_up", -desired_direction.y)


func _current_visible_rect(game: Node) -> Rect2:
	if is_instance_valid(game.avatar.camera):
		game.avatar.camera.force_update_scroll()
	return game._visible_world_rect()


func _avatar_centered_visible_rect(game: Node) -> Rect2:
	var half_extents: Vector2 = game._visible_world_half_extents()
	return Rect2(game.avatar.global_position - half_extents, half_extents * 2.0)


func _relocation_target_is_offscreen(enemy: InfectionEnemy, visible_before: Rect2, visible_after: Rect2) -> bool:
	var body_radius := enemy.definition.radius if enemy.definition != null else 0.0
	return (
		_circle_is_fully_outside_rect(enemy.global_position, body_radius, visible_before)
		and _circle_is_fully_outside_rect(enemy.global_position, body_radius, visible_after)
	)


func _relocation_target_avoids_source_neighborhood(
	game: Node,
	avatar_position: Vector2,
	source_position: Vector2,
	target_position: Vector2
) -> bool:
	var source_direction: Vector2 = game.topology.shortest_delta(avatar_position, source_position)
	var target_direction: Vector2 = game.topology.shortest_delta(avatar_position, target_position)
	if source_direction.length_squared() <= 0.000001 or target_direction.length_squared() <= 0.000001:
		return false
	return game._sector_ring_distance(
		game._sector_for_delta(source_direction),
		game._sector_for_delta(target_direction)
	) >= MINIMUM_RELOCATION_SECTOR_DISTANCE


func _relocation_target_is_randomized(game: Node, avatar_position: Vector2, target_position: Vector2) -> bool:
	var target_direction: Vector2 = game.topology.shortest_delta(avatar_position, target_position)
	if target_direction.length_squared() <= 0.000001:
		return false
	var sector: int = int(game._sector_for_delta(target_direction))
	var sector_width: float = TAU / float(SECTOR_COUNT)
	var sector_center: float = (float(sector) + 0.5) * sector_width
	return absf(game._shortest_signed_angle(sector_center, target_direction.angle())) >= 0.03


func _relocation_target_has_randomized_depth(game: Node, avatar_position: Vector2, enemy: InfectionEnemy) -> bool:
	if not is_instance_valid(enemy) or enemy.definition == null:
		return false
	var target_delta: Vector2 = game.topology.shortest_delta(avatar_position, enemy.global_position)
	if target_delta.length_squared() <= 0.000001:
		return false
	var direction := target_delta.normalized()
	var base_distance: float = (
		game._ray_distance_to_visible_edge(avatar_position, direction)
		+ float(game.WAVE_SPAWN_SCREEN_MARGIN)
		+ enemy.definition.radius
	)
	var radial_offset := target_delta.length() - base_distance
	var nearest_authored_depth := INF
	for authored_depth in game.OFFSCREEN_PLACEMENT_RADIAL_OFFSETS:
		nearest_authored_depth = minf(nearest_authored_depth, absf(radial_offset - float(authored_depth)))
	return nearest_authored_depth >= 1.0


func _circle_is_fully_outside_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y)
	)
	return center.distance_squared_to(closest) > radius * radius


func _pressure_sample(game: Node, tracked_enemies: Array[InfectionEnemy]) -> Dictionary:
	var pressure: PackedFloat32Array = game._local_wave_sector_pressure()
	var pressure_sectors := 0
	for value in pressure:
		if value >= PRESSURE_SECTOR_THRESHOLD:
			pressure_sectors += 1
	var near_sector_occupied := PackedByteArray()
	near_sector_occupied.resize(SECTOR_COUNT)
	near_sector_occupied.fill(0)
	var near_enemies := 0
	for enemy in tracked_enemies:
		if not is_instance_valid(enemy) or not enemy.is_targetable():
			continue
		var delta: Vector2 = game.topology.shortest_delta(game.avatar.global_position, enemy.global_position)
		if delta.length_squared() > NEAR_PRESSURE_RADIUS * NEAR_PRESSURE_RADIUS:
			continue
		near_enemies += 1
		near_sector_occupied[game._sector_for_delta(delta)] = 1
	var near_sectors := 0
	for occupied in near_sector_occupied:
		near_sectors += int(occupied)
	return {
		"pressure_sectors": pressure_sectors,
		"near_sectors": near_sectors,
		"near_enemies": near_enemies,
	}


func _linear_pressure_sample(game: Node, tracked_enemies: Array[InfectionEnemy], visible_rect: Rect2) -> Dictionary:
	var front_side_sector_occupied := PackedByteArray()
	front_side_sector_occupied.resize(SECTOR_COUNT)
	front_side_sector_occupied.fill(0)
	var visible_front_side_enemies := 0
	var reachable_front_side_enemies := 0
	var rear_offscreen_enemies := 0
	var rear_offscreen_sector_counts := PackedInt32Array()
	rear_offscreen_sector_counts.resize(SECTOR_COUNT)
	rear_offscreen_sector_counts.fill(0)
	for enemy in tracked_enemies:
		if not is_instance_valid(enemy) or not enemy.is_targetable():
			continue
		var delta: Vector2 = game.topology.shortest_delta(game.avatar.global_position, enemy.global_position)
		var body_radius := enemy.definition.radius if enemy.definition != null else 0.0
		var is_fully_offscreen := _circle_is_fully_outside_rect(enemy.global_position, body_radius, visible_rect)
		if delta.dot(LINEAR_DIRECTION) < -(body_radius + LINEAR_REAR_TOLERANCE):
			if is_fully_offscreen:
				rear_offscreen_enemies += 1
				var rear_sector: int = game._sector_for_delta(delta)
				rear_offscreen_sector_counts[rear_sector] += 1
			continue
		if not is_fully_offscreen:
			visible_front_side_enemies += 1
		if delta.length_squared() <= LINEAR_REACHABLE_RADIUS * LINEAR_REACHABLE_RADIUS:
			reachable_front_side_enemies += 1
			front_side_sector_occupied[game._sector_for_delta(delta)] = 1
	var front_side_sectors := 0
	for occupied in front_side_sector_occupied:
		front_side_sectors += int(occupied)
	var rear_offscreen_max_sector_enemies := 0
	for sector_count in rear_offscreen_sector_counts:
		rear_offscreen_max_sector_enemies = maxi(rear_offscreen_max_sector_enemies, int(sector_count))
	return {
		"visible_front_side_enemies": visible_front_side_enemies,
		"reachable_front_side_enemies": reachable_front_side_enemies,
		"front_side_sectors": front_side_sectors,
		"rear_offscreen_enemies": rear_offscreen_enemies,
		"rear_offscreen_max_sector_enemies": rear_offscreen_max_sector_enemies,
	}


func _assert_proportional_rate_contract(game: Node) -> Dictionary:
	var anchor_counts := PackedInt32Array([
		0, 1, 12, 13, 24, 25, 60, 61, 120, 121, 180, 181, 204, 205, 216, 217, ENEMY_COUNT,
	])
	var expected_rates := PackedFloat32Array([
		0.0, 2.0, 2.0, 4.0, 4.0, 6.0, 10.0, 12.0, 20.0, 22.0, 30.0, 32.0,
		34.0, 36.0, 36.0, 36.0, 36.0,
	])
	var observed_rates := PackedFloat32Array()
	observed_rates.resize(anchor_counts.size())
	for index in range(anchor_counts.size()):
		var observed_rate := float(game._offscreen_relocation_rate_for_count(anchor_counts[index]))
		observed_rates[index] = observed_rate
		_true(
			is_equal_approx(observed_rate, expected_rates[index]),
			"Offscreen-Ratenanker %d Gegner ergibt %.0f/s statt %.0f/s" % [
				anchor_counts[index],
				observed_rate,
				expected_rates[index],
			]
		)
	var monotone := true
	var previous_rate := -INF
	for eligible_count in range(ENEMY_COUNT + 1):
		var current_rate := float(game._offscreen_relocation_rate_for_count(eligible_count))
		if current_rate + 0.0001 < previous_rate:
			monotone = false
			break
		previous_rate = current_rate
	_true(monotone, "Die geplante Offscreen-Rate bleibt von 0 bis %d Gegnern monoton" % ENEMY_COUNT)
	_true(
		observed_rates[2] < observed_rates[8] and observed_rates[8] < observed_rates[13],
		"Niedriger, mittlerer und hoher Rückstau planen strikt mehr Durchsatz (%.0f/s < %.0f/s < %.0f/s)" % [
			observed_rates[2],
			observed_rates[8],
			observed_rates[13],
		]
	)
	return {
		"anchor_counts": anchor_counts,
		"expected_moves_per_second": expected_rates,
		"observed_moves_per_second": observed_rates,
		"low_backlog_rate": observed_rates[2],
		"medium_backlog_rate": observed_rates[8],
		"high_backlog_rate": observed_rates[13],
		"maximum_backlog_rate": observed_rates[observed_rates.size() - 1],
		"monotone_through_count": ENEMY_COUNT,
	}


func _assert_bounded_crowd_work(profile: PackedInt64Array, maximum_guard_queries: int, case_label: String) -> void:
	_true(profile[EnemyWorld.CrowdProfileCounter.GRID_REBUILDS] <= 1, "%s baut den Crowd-Index nach dem Szenarioaufbau nur inkrementell" % case_label)
	_true(profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES] <= maximum_guard_queries, "%s hält lokale Guard-Abfragen phasenbegrenzt (%d / %d)" % [case_label, profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES], maximum_guard_queries])
	_true(profile[EnemyWorld.CrowdProfileCounter.CORRIDOR_EVALUATIONS] <= profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES], "%s verwendet für Korridorprüfungen den lokalen Guard-Cache" % case_label)


func _crowd_profile_report(profile: PackedInt64Array) -> Dictionary:
	return {
		"grid_rebuilds": profile[EnemyWorld.CrowdProfileCounter.GRID_REBUILDS],
		"guard_queries": profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES],
		"guard_candidates": profile[EnemyWorld.CrowdProfileCounter.GUARD_CANDIDATES],
		"corridor_evaluations": profile[EnemyWorld.CrowdProfileCounter.CORRIDOR_EVALUATIONS],
		"bypass_starts": profile[EnemyWorld.CrowdProfileCounter.BYPASS_STARTS],
		"active_bypass_ticks": profile[EnemyWorld.CrowdProfileCounter.ACTIVE_BYPASS_TICKS],
		"queued_no_corridor": profile[EnemyWorld.CrowdProfileCounter.QUEUED_NO_CORRIDOR],
		"side_switches": profile[EnemyWorld.CrowdProfileCounter.SIDE_SWITCHES],
	}


func _on_enemy_pressure(_amount: float, enemy_instance_id: int) -> void:
	contact_events += 1
	contact_enemy_ids[enemy_instance_id] = true


func _release_movement_input() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


func _true(condition: bool, label: String, count_assertion: bool = true) -> void:
	if count_assertion:
		assertions += 1
	if condition:
		return
	failures += 1
	push_error("PRESSURE_AI_ASSERTION_FAILED: %s" % label)
