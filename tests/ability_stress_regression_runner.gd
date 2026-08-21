extends SceneTree

## Capacity and determinism regression for the complete active-ability path.
##
## This deliberately instantiates the real game scene. EnemyWorld, PickupWorld,
## ProjectileWorld, CombatQuery, AbilityController, GameplayZoneWorld and
## AbilityFeedbackWorld therefore run with the same wiring used by a playable
## case. Only the clock is owned by this runner so all quality tiers receive the
## exact same fixed-step trace.

const Metrics = preload("res://tests/support/performance_metrics.gd")

const ENEMY_COUNT := 600
const PICKUP_COUNT := 360
const PROJECTILE_COUNT := 512
const EXISTING_FEEDBACK_COUNT := 80
const FIXED_DELTA := 1.0 / 60.0
const MATERIALIZATION_FRAMES := 45
const MEASURED_FRAMES := 360
const COMMAND_INTERVAL_FRAMES := 90
const RUN_SEED := 0xA81E17

const MAX_AVERAGE_FRAME_MS := 16.7
const MAX_P95_FRAME_MS := 16.7
const MAX_P99_FRAME_MS := 20.0
const MAX_SINGLE_FRAME_MS := 33.3
const WATCHDOG_AVERAGE_MS := 25.0
const WATCHDOG_SIMULATION_P95_MS := 25.0
const WATCHDOG_SIMULATION_P99_MS := 30.0
const WATCHDOG_SINGLE_FRAME_MS := 50.0

var assertions: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.physics_ticks_per_second = 60
	var qualities: Array[CosmeticBudgetController.Quality] = [
		CosmeticBudgetController.Quality.FULL,
		CosmeticBudgetController.Quality.REDUCED,
		CosmeticBudgetController.Quality.MINIMAL,
	]
	var results: Array[Dictionary] = []
	for quality in qualities:
		results.append(await _simulate_quality(quality))

	for index in range(results.size()):
		var result: Dictionary = results[index]
		var tier_name := _quality_name(qualities[index])
		_equal(int(result.quality), int(qualities[index]), "%s quality is applied" % tier_name)
		_equal(int(result.counts.enemies), ENEMY_COUNT, "%s keeps every enemy entity" % tier_name)
		_equal(int(result.counts.enemy_world), ENEMY_COUNT, "%s keeps every EnemyWorld handle" % tier_name)
		_equal(int(result.counts.enemy_visuals), ENEMY_COUNT, "%s keeps every enemy visual" % tier_name)
		_equal(int(result.counts.pickups), PICKUP_COUNT, "%s keeps every pickup entity" % tier_name)
		_equal(int(result.counts.pickup_world), PICKUP_COUNT, "%s keeps every PickupWorld handle" % tier_name)
		_equal(int(result.counts.pickup_visuals), PICKUP_COUNT, "%s keeps every pickup visual" % tier_name)
		_equal(int(result.counts.projectiles), PROJECTILE_COUNT, "%s keeps every projectile entity" % tier_name)
		_equal(int(result.counts.projectile_world), PROJECTILE_COUNT, "%s keeps every ProjectileWorld handle" % tier_name)
		_equal(int(result.counts.projectile_visuals), PROJECTILE_COUNT, "%s keeps every projectile visual" % tier_name)
		_equal(int(result.counts.existing_feedback), EXISTING_FEEDBACK_COUNT, "%s preserves the existing feedback load" % tier_name)
		_equal(int(result.counts.feedback_renderer), EXISTING_FEEDBACK_COUNT, "%s keeps existing feedback registered" % tier_name)
		_equal(int(result.counts.command_failures), 0, "%s executes every queued active command" % tier_name)
		_true(int(result.counts.command_successes) >= 5, "%s repeatedly executes both available active abilities" % tier_name)
		_true(int(result.counts.burst_commands) >= 2, "%s repeatedly executes defense-burst commands" % tier_name)
		_true(int(result.counts.line_commands) >= 2, "%s repeatedly executes treatment-line commands" % tier_name)
		_true(int(result.counts.burst_hits) > 0, "%s defense burst damages spatial-query targets" % tier_name)
		_true(int(result.counts.line_hits) > 0, "%s treatment line damages spatial-query targets" % tier_name)
		_true(int(result.counts.burst_feedback_started) >= 2, "%s starts distinct defense-burst feedback" % tier_name)
		_true(int(result.counts.line_feedback_started) >= 2, "%s starts distinct treatment-line feedback" % tier_name)
		_true(bool(result.burst_feedback_critical), "%s keeps defense-burst geometry critical" % tier_name)
		_true(bool(result.line_feedback_critical), "%s keeps treatment-line geometry critical" % tier_name)
		_equal(int(result.node_delta), 0, "%s allocates no Nodes during ability spam" % tier_name)
		_equal(int(result.queued_commands), 0, "%s drains the deterministic command queue" % tier_name)
		_true(bool(result.session_running), "%s run remains active for the full stress trace" % tier_name)
		_true(not String(result.gameplay_hash).is_empty(), "%s produces a gameplay hash" % tier_name)
		# The strict 16.7/20 ms acceptance remains in performance_runner.gd,
		# which runs one stable FULL-quality sample. This three-world functional
		# stress test records the same targets but uses a wider watchdog so Windows
		# scheduler or concurrent CI jitter cannot turn gameplay correctness into a
		# flaky failure.
		_true(float(result.timing_ms.avg) <= WATCHDOG_AVERAGE_MS, "%s average combined CPU time stays below the regression watchdog" % tier_name)
		_true(float(result.timing_ms.max) <= WATCHDOG_SINGLE_FRAME_MS, "%s maximum combined CPU time stays below the regression watchdog" % tier_name)
		_true(float(result.simulation_timing_ms.p95) <= WATCHDOG_SIMULATION_P95_MS, "%s p95 simulation CPU time stays below the regression watchdog" % tier_name)
		_true(float(result.simulation_timing_ms.p99) <= WATCHDOG_SIMULATION_P99_MS, "%s p99 simulation CPU time stays below the regression watchdog" % tier_name)

	var baseline: Dictionary = results[0]
	for index in range(1, results.size()):
		var candidate: Dictionary = results[index]
		_equal(candidate.gameplay_hash, baseline.gameplay_hash, "%s has the same gameplay trace as FULL" % _quality_name(qualities[index]))
		_equal(candidate.gameplay_summary, baseline.gameplay_summary, "%s has the same final gameplay summary as FULL" % _quality_name(qualities[index]))

	var report: Dictionary = Metrics.machine_metadata()
	report.merge({
		"schema": "alveolus.ability_stress.v1",
		"passed": failures == 0,
		"assertions": assertions,
		"load": {
			"enemies": ENEMY_COUNT,
			"pickups": PICKUP_COUNT,
			"projectiles": PROJECTILE_COUNT,
			"existing_feedback": EXISTING_FEEDBACK_COUNT,
			"measured_frames": MEASURED_FRAMES,
			"active_command_interval_frames": COMMAND_INTERVAL_FRAMES,
		},
		"reference_targets_ms": {
			"combined_avg": MAX_AVERAGE_FRAME_MS,
			"combined_max": MAX_SINGLE_FRAME_MS,
			"simulation_p95": MAX_P95_FRAME_MS,
			"simulation_p99": MAX_P99_FRAME_MS,
		},
		"regression_watchdog_ms": {
			"combined_avg": WATCHDOG_AVERAGE_MS,
			"combined_max": WATCHDOG_SINGLE_FRAME_MS,
			"simulation_p95": WATCHDOG_SIMULATION_P95_MS,
			"simulation_p99": WATCHDOG_SIMULATION_P99_MS,
		},
		"qualities": results,
	}, true)
	if failures == 0:
		print("ALVEOLUS_ABILITY_STRESS_OK assertions=%d hash=%s full_p95_ms=%.3f reduced_p95_ms=%.3f minimal_p95_ms=%.3f" % [
			assertions,
			String(baseline.gameplay_hash),
			float(results[0].timing_ms.p95),
			float(results[1].timing_ms.p95),
			float(results[2].timing_ms.p95),
		])
	else:
		push_error("ALVEOLUS_ABILITY_STRESS_FAILED failures=%d assertions=%d" % [failures, assertions])
	print("ALVEOLUS_ABILITY_STRESS_JSON=%s" % JSON.stringify(report))
	quit(0 if failures == 0 else 1)


func _simulate_quality(quality: CosmeticBudgetController.Quality) -> Dictionary:
	paused = false
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	# Do not read or mutate persistent progress after the scene's initial setup.
	game.quick_run = true
	game.persistence_enabled = false
	game.meta.reset_defaults()
	game.discovery_manager.configure(game.discovery_definitions, {})
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)

	game.selected_level = game.levels[1]
	game.meta.research_ranks[&"unlock_defense_burst"] = 1
	game.meta.register_level_result(game.selected_level, true, 1.0, 1, 1)
	var active_ids: Array[StringName] = [&"ability_defense_burst", &"ability_treatment_line"]
	var loadout := PreparedLoadout.create(&"treatment_precision", active_ids)
	var context := RunContext.create(game.selected_level.id, RUN_SEED, loadout, {}, &"", &"")
	game.start_run(context)
	game.set_physics_process(false)
	game.stress_test = true
	game.stress_reported = true
	game.spawn_accumulator = 999999.0
	game.treatment_controller.enabled = false
	game.config.run_duration_seconds = 100000.0
	game.config.final_deadline_seconds = 100000.0
	game.config.enemy_speed_multiplier = 0.0
	game.config.contact_damage_multiplier = 0.0
	game.state.max_stability = 1000000000.0
	game.state.stability = game.state.max_stability

	_spawn_enemy_grid(game)
	# start_run() creates a tiny initial pressure sample before this accelerated
	# harness takes over. Freeze those entries together with the grid so the load
	# measures queries/rendering rather than contact outcomes.
	for enemy in game.enemies:
		enemy.speed_multiplier = 0.0
		enemy.damage_multiplier = 0.0
		enemy.max_health = 1000000000.0
		enemy.health = enemy.max_health
	_spawn_pickup_load(game)
	_spawn_projectile_load(game)
	_spawn_existing_feedback_load(game)

	# Cosmetics are created at the full acceptance load before the tier changes.
	# Lower qualities may simplify their drawing but must never remove gameplay
	# entities or the critical ability-field geometry.
	game.cosmetic_budget_controller.configure(false, false)
	game.cosmetic_budget_controller.set_quality(quality)
	game.ability_feedback_world.set_quality_tier(quality)

	paused = true
	for _frame in range(MATERIALIZATION_FRAMES):
		game.run_session.step_fixed(FIXED_DELTA)
		_flush_renderers(game)
	game._ensure_combat_query()
	game._ensure_pickup_query()

	# Warm the real CanvasItem and MultiMesh paths once before collecting node and
	# timing baselines. Game physics remains disabled, so this render frame cannot
	# alter the deterministic simulation clock.
	paused = false
	game.ability_feedback_world.publish_snapshot()
	await process_frame
	paused = true

	var command_counts := {
		"successes": 0,
		"failures": 0,
		"burst": 0,
		"line": 0,
		"burst_hits": 0,
		"line_hits": 0,
	}
	var feedback_counts: Dictionary = {
		&"ability_defense_burst": 0,
		&"ability_treatment_line": 0,
	}
	var feedback_critical: Dictionary = {
		&"ability_defense_burst": false,
		&"ability_treatment_line": false,
	}
	game.ability_controller.execution_completed.connect(func(result: AbilityExecutionResult) -> void:
		if result.success:
			command_counts.successes = int(command_counts.successes) + 1
			if result.ability_id == &"ability_defense_burst":
				command_counts.burst = int(command_counts.burst) + 1
				command_counts.burst_hits = int(command_counts.burst_hits) + result.affected_handles.size()
			elif result.ability_id == &"ability_treatment_line":
				command_counts.line = int(command_counts.line) + 1
				command_counts.line_hits = int(command_counts.line_hits) + result.affected_handles.size()
		else:
			command_counts.failures = int(command_counts.failures) + 1
	)
	game.ability_feedback_world.feedback_started.connect(func(handle: int, source_id: StringName) -> void:
		if feedback_counts.has(source_id):
			feedback_counts[source_id] = int(feedback_counts[source_id]) + 1
			feedback_critical[source_id] = bool(game.ability_feedback_world.render_state(handle).get("critical", false))
	)

	var node_count_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var memory_before := float(Performance.get_monitor(Performance.MEMORY_STATIC))
	var frame_samples_ms: Array[float] = []
	var simulation_samples_ms: Array[float] = []
	var last_targets: Dictionary = {
		&"ability_defense_burst": Vector2.ZERO,
		&"ability_treatment_line": Vector2.ZERO,
	}
	for frame in range(MEASURED_FRAMES):
		if frame == 0:
			_queue_field_command(game, AbilityController.SLOT_Q, frame, last_targets)
			_queue_field_command(game, AbilityController.SLOT_E, frame, last_targets)
		elif frame % COMMAND_INTERVAL_FRAMES == 0:
			var slot := AbilityController.SLOT_Q if (frame / COMMAND_INTERVAL_FRAMES) % 2 == 0 else AbilityController.SLOT_E
			_queue_field_command(game, slot, frame, last_targets)
		var frame_started := Time.get_ticks_usec()
		game.run_session.step_fixed(FIXED_DELTA)
		simulation_samples_ms.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
		_flush_renderers(game)
		frame_samples_ms.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)

	game.ability_feedback_world.publish_snapshot()
	paused = false
	await process_frame
	paused = true
	var node_count_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var memory_after := float(Performance.get_monitor(Performance.MEMORY_STATIC))

	var gameplay_state := _canonical_gameplay_state(game)
	var timings := Metrics.summarize_ms(frame_samples_ms)
	var simulation_timings := Metrics.summarize_ms(simulation_samples_ms)
	var gameplay_summary := {
		"fixed_tick": game.run_session.fixed_tick,
		"elapsed": _f(game.run_session.elapsed),
		"rng_state": int(game.rng.state),
		"enemy_count": game.enemy_world.active_count(),
		"pickup_count": game.pickup_world.active_count(),
		"projectile_count": game.projectile_world.active_count(),
		"zone_count": game.ability_controller.zone_world.active_count(),
	}
	var result := {
		"quality": int(quality),
		"quality_name": _quality_name(quality),
		"gameplay_hash": _sha256(gameplay_state),
		"gameplay_summary": gameplay_summary,
		"session_running": game.run_session.lifecycle == RunSession.Lifecycle.RUNNING,
		"queued_commands": game.ability_controller.queued_command_count(),
		"burst_feedback_critical": bool(feedback_critical[&"ability_defense_burst"]),
		"line_feedback_critical": bool(feedback_critical[&"ability_treatment_line"]),
		"node_delta": node_count_after - node_count_before,
		"memory_delta_bytes": memory_after - memory_before,
		"timing_ms": timings,
		"simulation_timing_ms": simulation_timings,
		"counts": {
			"enemies": game.enemies.size(),
			"enemy_world": game.enemy_world.active_count(),
			"enemy_visuals": game.crowd_renderer.active_enemy_visual_count(),
			"pickups": game.pickups.size(),
			"pickup_world": game.pickup_world.active_count(),
			"pickup_visuals": game.crowd_renderer.active_pickup_visual_count(),
			"projectiles": game.projectiles.size(),
			"projectile_world": game.projectile_world.active_count(),
			"projectile_visuals": game.projectile_renderer.active_count(),
			"existing_feedback": game.visual_bursts.size(),
			"feedback_renderer": game.feedback_renderer.active_count(),
			"ability_feedback": game.ability_feedback_world.active_count(),
			"command_successes": int(command_counts.successes),
			"command_failures": int(command_counts.failures),
			"burst_commands": int(command_counts.burst),
			"line_commands": int(command_counts.line),
			"burst_hits": int(command_counts.burst_hits),
			"line_hits": int(command_counts.line_hits),
			"burst_feedback_started": int(feedback_counts[&"ability_defense_burst"]),
			"line_feedback_started": int(feedback_counts[&"ability_treatment_line"]),
		},
	}

	paused = false
	game.queue_free()
	await process_frame
	return result


func _spawn_enemy_grid(game: Node) -> void:
	const COLUMNS := 30
	const ROWS := 20
	for row in range(ROWS):
		for column in range(COLUMNS):
			var position := Vector2(
				lerpf(-1120.0, 1120.0, float(column) / float(COLUMNS - 1)),
				lerpf(-610.0, 610.0, float(row) / float(ROWS - 1))
			)
			game._spawn_enemy(&"pneumococcus", position, 12.0, false, false)


func _spawn_pickup_load(game: Node) -> void:
	for index in range(PICKUP_COUNT):
		var side := -1.0 if index % 2 == 0 else 1.0
		var y := lerpf(-610.0, 610.0, float(index % 180) / 179.0)
		game._spawn_analysis_pickup(1, Vector2(side * 1040.0, y))


func _spawn_projectile_load(game: Node) -> void:
	var shots: Array[TreatmentShot] = []
	for index in range(PROJECTILE_COUNT):
		var origin := Vector2.from_angle(TAU * float(index) / float(PROJECTILE_COUNT)) * 180.0
		shots.append(TreatmentShot.tracking(origin, game.enemies[index % game.enemies.size()], 0.0, 2000.0, &"stress"))
	game._on_treatment_shots_requested(shots)
	for index in range(game.projectiles.size()):
		var projectile: TherapyProjectile = game.projectiles[index]
		projectile.lifetime = 100000.0
		projectile.speed = 260.0
		projectile.direction = Vector2.from_angle(TAU * float(index) / float(maxi(game.projectiles.size(), 1)) + PI * 0.5)
		projectile.rotation = projectile.direction.angle()
		projectile.target = null


func _spawn_existing_feedback_load(game: Node) -> void:
	for index in range(EXISTING_FEEDBACK_COUNT):
		var angle := TAU * float(index) / float(EXISTING_FEEDBACK_COUNT)
		game._spawn_visual_burst(
			Vector2.from_angle(angle) * 280.0,
			&"stress_feedback",
			AlveolusVisualTheme.TURQUOISE,
			4,
			100000.0,
			24.0
		)


func _queue_field_command(game: Node, slot: int, frame: int, last_targets: Dictionary) -> void:
	var runtime: AbilityRuntime = game.ability_controller.runtime(slot)
	if runtime == null:
		return
	runtime.reset()
	var enemy_index := posmod(frame * 37 + slot * 211, game.enemies.size())
	var target: Vector2 = game.enemies[enemy_index].global_position
	last_targets[runtime.definition.id] = target
	game.ability_controller.queue_slot(slot, target, AbilityCommand.InputDevice.KEYBOARD_MOUSE, game.run_session.fixed_tick)


func _flush_renderers(game: Node) -> void:
	game.crowd_renderer.flush_render_state(1.0)
	game.projectile_renderer.flush_render_state(1.0)
	game.feedback_renderer.flush_render_state()


func _canonical_gameplay_state(game: Node) -> String:
	var parts := PackedStringArray()
	parts.append("tick=%d" % game.run_session.fixed_tick)
	parts.append("elapsed=%s" % _f(game.run_session.elapsed))
	parts.append("run=%s,%s,%d,%d" % [
		_f(game.state.elapsed),
		_f(game.state.stability),
		game.state.analysis,
		game.state.level,
	])
	parts.append("rng=%d" % int(game.rng.state))
	for slot in [AbilityController.SLOT_Q, AbilityController.SLOT_E]:
		var ability_state: Dictionary = game.ability_controller.ability_state(slot)
		parts.append("ability=%d,%s,%s,%s" % [
			slot,
			String(ability_state.get("id", &"")),
			_f(float(ability_state.get("remaining", 0.0))),
			_f(float(ability_state.get("total", 0.0))),
		])
	var enemy_handles: PackedInt64Array = game.enemy_world.handles()
	enemy_handles.sort()
	for handle in enemy_handles:
		var enemy := game.enemy_world.resolve(handle) as InfectionEnemy
		parts.append("enemy=%d,%s,%s,%s,%s" % [
			handle,
			_v(enemy.global_position),
			_f(enemy.health),
			_f(enemy.status_speed_multiplier()),
			_f(enemy.status_contact_multiplier()),
		])
	var pickup_handles: PackedInt64Array = game.pickup_world.handles()
	pickup_handles.sort()
	for handle in pickup_handles:
		var pickup := game.pickup_world.resolve(handle) as AnalysisPickup
		parts.append("pickup=%d,%s,%d,%d" % [handle, _v(pickup.global_position), pickup.analysis_value, int(pickup.guided_to_target)])
	var projectile_handles: PackedInt64Array = game.projectile_world.handles()
	projectile_handles.sort()
	for handle in projectile_handles:
		var projectile := game.projectile_world.resolve(handle) as TherapyProjectile
		parts.append("projectile=%d,%s,%s,%s,%s" % [
			handle,
			_v(projectile.global_position),
			_v(projectile.direction),
			_f(projectile.lifetime),
			_f(projectile.travelled_distance),
		])
	var zone_handles: PackedInt64Array = game.ability_controller.zone_world.active_handles()
	zone_handles.sort()
	for handle in zone_handles:
		var zone := game.ability_controller.zone_world.resolve(handle) as GameplayZoneState
		parts.append("zone=%d,%s,%s,%s,%s" % [
			handle,
			String(zone.effect_id),
			_v(zone.center),
			_f(zone.radius),
			_f(zone.remaining),
		])
	return "|".join(parts)


func _quality_name(quality: CosmeticBudgetController.Quality) -> String:
	match quality:
		CosmeticBudgetController.Quality.REDUCED:
			return "REDUCED"
		CosmeticBudgetController.Quality.MINIMAL:
			return "MINIMAL"
	return "FULL"


func _f(value: float) -> String:
	return "%.4f" % (round(value * 10000.0) / 10000.0)


func _v(value: Vector2) -> String:
	return "%s,%s" % [_f(value.x), _f(value.y)]


func _sha256(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (actual=%s expected=%s)" % [message, actual, expected])
