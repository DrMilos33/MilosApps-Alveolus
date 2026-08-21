extends SceneTree

## Fixed-seed, graphics-free acceptance scenario for the circular-kiting
## exploit. A one-sided 220-body crowd must be redistributed by the production
## offscreen director and create several local attack fronts while Doctor Milos
## keeps running in a circle. The runner reports wall time, but asserts only
## deterministic gameplay results and bounded EnemyWorld work.

const RUN_SEED := 0x5052455353555245
const FIXED_DELTA := 1.0 / 60.0
const ENEMY_COUNT := 220
const SECTOR_COUNT := 12
const SIMULATION_TICKS := 2700
const SAMPLE_INTERVAL_TICKS := 15
const EARLY_WINDOW_TICKS := 360
const LATE_WINDOW_START_TICK := 1350
const ORBIT_RADIUS := 230.0
const NEAR_PRESSURE_RADIUS := 330.0
const PRESSURE_SECTOR_THRESHOLD := 0.35
const RELOCATION_DISTANCE_THRESHOLD := 120.0

const MINIMUM_RELOCATION_EVENTS := 24
const MINIMUM_DISTINCT_RELOCATIONS := 14
const MINIMUM_LATE_PRESSURE_SECTORS := 5.0
const MINIMUM_PRESSURE_SECTOR_GAIN := 1.25
const MINIMUM_LATE_NEAR_SECTORS := 2.0
const MINIMUM_PEAK_NEAR_SECTORS := 4
const MINIMUM_CONTACT_EVENTS := 4
const MINIMUM_DISTINCT_CONTACTORS := 2

var assertions := 0
var failures := 0
var contact_events := 0
var contact_enemy_ids: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.physics_ticks_per_second = 60
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	game.quick_run = true
	game.persistence_enabled = false
	game.meta.reset_defaults()
	game.discovery_manager.configure(game.discovery_definitions, {})
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = game.levels[1]
	var context := RunContext.create(
		game.selected_level.id,
		RUN_SEED,
		PreparedLoadout.default_loadout(),
		{},
		&"",
		&""
	)
	game.start_run(context)
	game.set_physics_process(false)
	game.spawn_accumulator = 999999.0
	game.treatment_controller.enabled = false
	game.ability_controller.clear()
	game.config.run_duration_seconds = 100000.0
	game.config.final_deadline_seconds = 100000.0
	game.config.contact_damage_multiplier = 0.0
	game.state.max_stability = 1000000000.0
	game.state.stability = game.state.max_stability
	game.enemy_world.set_crowd_profile_enabled(true)

	var orbit_center: Vector2 = game.topology.bounds.get_center()
	game.avatar.global_position = orbit_center + Vector2(ORBIT_RADIUS, 0.0)
	game.avatar.reset_physics_interpolation()
	game.avatar.input_enabled = true
	var tracked_enemies := _build_one_sided_crowd(game, orbit_center)
	_true(tracked_enemies.size() == ENEMY_COUNT, "Der Szenariolauf hält exakt %d Gegner" % ENEMY_COUNT)

	var previous_positions := PackedVector2Array()
	previous_positions.resize(tracked_enemies.size())
	for index in range(tracked_enemies.size()):
		previous_positions[index] = tracked_enemies[index].global_position

	var relocation_events := 0
	var relocated_enemy_ids: Dictionary = {}
	var early_pressure_sector_sum := 0.0
	var early_sample_count := 0
	var late_pressure_sector_sum := 0.0
	var late_near_sector_sum := 0.0
	var late_near_enemy_sum := 0.0
	var late_sample_count := 0
	var peak_near_sectors := 0
	var peak_near_enemies := 0
	var started_usec := Time.get_ticks_usec()

	# Direct RunSession stepping is the same authoritative fixed-tick path used
	# by Game. SceneTree time stays paused so no render frame or second clock can
	# mutate the sample.
	paused = true
	for tick in range(SIMULATION_TICKS):
		_apply_circular_input(game, orbit_center)
		if is_instance_valid(game.avatar.camera):
			game.avatar.camera.force_update_scroll()
		_true(game.run_session.step_fixed(FIXED_DELTA), "RunSession bleibt in Tick %d aktiv" % tick, false)

		for index in range(tracked_enemies.size()):
			var enemy: InfectionEnemy = tracked_enemies[index]
			var travelled: float = game.topology.distance(previous_positions[index], enemy.global_position)
			if travelled >= RELOCATION_DISTANCE_THRESHOLD:
				relocation_events += 1
				relocated_enemy_ids[enemy.get_instance_id()] = true
			previous_positions[index] = enemy.global_position

		if tick % SAMPLE_INTERVAL_TICKS != 0:
			continue
		var sample := _pressure_sample(game, tracked_enemies)
		peak_near_sectors = maxi(peak_near_sectors, int(sample.near_sectors))
		peak_near_enemies = maxi(peak_near_enemies, int(sample.near_enemies))
		if tick < EARLY_WINDOW_TICKS:
			early_pressure_sector_sum += float(sample.pressure_sectors)
			early_sample_count += 1
		elif tick >= LATE_WINDOW_START_TICK:
			late_pressure_sector_sum += float(sample.pressure_sectors)
			late_near_sector_sum += float(sample.near_sectors)
			late_near_enemy_sum += float(sample.near_enemies)
			late_sample_count += 1

	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	_release_movement_input()
	var profile: PackedInt64Array = game.enemy_world.crowd_profile_snapshot()
	var early_pressure_average := early_pressure_sector_sum / float(maxi(early_sample_count, 1))
	var late_pressure_average := late_pressure_sector_sum / float(maxi(late_sample_count, 1))
	var late_near_sector_average := late_near_sector_sum / float(maxi(late_sample_count, 1))
	var late_near_enemy_average := late_near_enemy_sum / float(maxi(late_sample_count, 1))
	var maximum_guard_queries := SIMULATION_TICKS * (
		ceili(float(ENEMY_COUNT) / float(EnemyWorld.DIRECT_COLLISION_UPDATE_PHASES)) + 1
	)

	_true(relocation_events >= MINIMUM_RELOCATION_EVENTS, "Offscreen-Director versetzt ausreichend oft (%d / %d)" % [relocation_events, MINIMUM_RELOCATION_EVENTS])
	_true(relocated_enemy_ids.size() >= MINIMUM_DISTINCT_RELOCATIONS, "Versetzungen verteilen sich auf mehrere Gegner (%d / %d)" % [relocated_enemy_ids.size(), MINIMUM_DISTINCT_RELOCATIONS])
	_true(late_pressure_average >= MINIMUM_LATE_PRESSURE_SECTORS, "Später lokaler Druck belegt im Mittel mehrere Sektoren (%.2f / %.2f)" % [late_pressure_average, MINIMUM_LATE_PRESSURE_SECTORS])
	_true(late_pressure_average >= early_pressure_average + MINIMUM_PRESSURE_SECTOR_GAIN, "Der einseitige Start wird messbar zu Mehrseiten-Druck (%.2f -> %.2f)" % [early_pressure_average, late_pressure_average])
	_true(late_near_sector_average >= MINIMUM_LATE_NEAR_SECTORS, "Nahe Gegner greifen im Mittel aus mehreren Richtungen an (%.2f / %.2f)" % [late_near_sector_average, MINIMUM_LATE_NEAR_SECTORS])
	_true(peak_near_sectors >= MINIMUM_PEAK_NEAR_SECTORS, "Der Kreisexploit erzeugt mindestens %d gleichzeitige Nahfronten (%d)" % [MINIMUM_PEAK_NEAR_SECTORS, peak_near_sectors])
	_true(contact_events >= MINIMUM_CONTACT_EVENTS, "Kreisendes Laufen bleibt nicht schadlos (%d / %d Kontakte)" % [contact_events, MINIMUM_CONTACT_EVENTS])
	_true(contact_enemy_ids.size() >= MINIMUM_DISTINCT_CONTACTORS, "Mehr als ein Gegner erreicht den Doctor (%d / %d)" % [contact_enemy_ids.size(), MINIMUM_DISTINCT_CONTACTORS])
	_true(profile[EnemyWorld.CrowdProfileCounter.GRID_REBUILDS] <= 1, "Der Crowd-Index wird nach dem einmaligen Szenarioaufbau nur inkrementell gepflegt")
	_true(profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES] <= maximum_guard_queries, "Lokale Guard-Abfragen bleiben phasenbegrenzt (%d / %d)" % [profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES], maximum_guard_queries])
	_true(profile[EnemyWorld.CrowdProfileCounter.CORRIDOR_EVALUATIONS] <= profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES], "Korridorprüfungen verwenden den lokalen Guard-Cache")

	var report := {
		"schema": "alveolus.pressure_ai.v1",
		"passed": failures == 0,
		"ticks": SIMULATION_TICKS,
		"enemies": tracked_enemies.size(),
		"elapsed_ms_informational": elapsed_ms,
		"relocation_events": relocation_events,
		"distinct_relocated_enemies": relocated_enemy_ids.size(),
		"early_pressure_sectors_avg": early_pressure_average,
		"late_pressure_sectors_avg": late_pressure_average,
		"late_near_sectors_avg": late_near_sector_average,
		"late_near_enemies_avg": late_near_enemy_average,
		"peak_near_sectors": peak_near_sectors,
		"peak_near_enemies": peak_near_enemies,
		"contact_events": contact_events,
		"distinct_contactors": contact_enemy_ids.size(),
		"crowd_profile": {
			"grid_rebuilds": profile[EnemyWorld.CrowdProfileCounter.GRID_REBUILDS],
			"guard_queries": profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES],
			"guard_candidates": profile[EnemyWorld.CrowdProfileCounter.GUARD_CANDIDATES],
			"corridor_evaluations": profile[EnemyWorld.CrowdProfileCounter.CORRIDOR_EVALUATIONS],
			"bypass_starts": profile[EnemyWorld.CrowdProfileCounter.BYPASS_STARTS],
			"active_bypass_ticks": profile[EnemyWorld.CrowdProfileCounter.ACTIVE_BYPASS_TICKS],
			"queued_no_corridor": profile[EnemyWorld.CrowdProfileCounter.QUEUED_NO_CORRIDOR],
			"side_switches": profile[EnemyWorld.CrowdProfileCounter.SIDE_SWITCHES],
		},
	}
	print("ALVEOLUS_PRESSURE_AI_JSON=%s" % JSON.stringify(report))
	if failures == 0:
		print("ALVEOLUS_PRESSURE_AI_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_PRESSURE_AI_FAILED failures=%d assertions=%d" % [failures, assertions])

	paused = false
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _build_one_sided_crowd(game: Node, center: Vector2) -> Array[InfectionEnemy]:
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
		var angle := -wedge_radians * 0.5 + angle_fraction * wedge_radians
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
	_release_movement_input()
	if desired_direction.x > 0.0:
		Input.action_press(&"move_right", desired_direction.x)
	elif desired_direction.x < 0.0:
		Input.action_press(&"move_left", -desired_direction.x)
	if desired_direction.y > 0.0:
		Input.action_press(&"move_down", desired_direction.y)
	elif desired_direction.y < 0.0:
		Input.action_press(&"move_up", -desired_direction.y)


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
