extends SceneTree

const Metrics = preload("res://tests/support/performance_metrics.gd")

const DEFAULT_ENEMY_COUNT := 600
const PICKUP_DROP_COUNT := 1200
const PROJECTILE_COUNT := 512
const FEEDBACK_EFFECT_COUNT := 80
const FIXED_DELTA := 1.0 / 60.0
const WARMUP_PHYSICS_FRAMES := 480
const MEASURED_PHYSICS_FRAMES := 900
const MAX_WALL_TIME_MS := 30000.0
const MAX_AVERAGE_FRAME_MS := 16.7
const MAX_P95_FRAME_MS := 16.7
const MAX_P99_FRAME_MS := 20.0
const MAX_SINGLE_FRAME_MS := 33.3

func _init() -> void:
	call_deferred("_run_performance_test")

func _run_performance_test() -> void:
	var enemy_count := _requested_enemy_count()
	Engine.physics_ticks_per_second = 60
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = game.levels[1]
	game.start_run()
	game.spawn_accumulator = 9999.0
	game.treatment_controller.enabled = false
	game.performance_profile_enabled = true
	game.enemy_world.set_crowd_profile_enabled(true)
	# This is a combat-runtime benchmark, not a level-outcome test. Keep the
	# session alive for the entire sample so a normal case deadline or patient
	# pressure cannot invalidate the capacity/reuse assertions below.
	game.config.run_duration_seconds = 100000.0
	game.config.final_deadline_seconds = 100000.0
	game.config.contact_damage_multiplier = 0.0
	game.state.max_stability = 1000000000.0
	game.state.stability = game.state.max_stability

	var enemies_to_add := maxi(enemy_count - game.enemies.size(), 0)
	for index in range(enemies_to_add):
		var angle := TAU * float(index) / float(maxi(enemies_to_add, 1))
		var ring := 380.0 + float(index % 9) * 58.0
		game._spawn_enemy(&"pneumococcus", game.topology.wrap_position(Vector2.from_angle(angle) * ring))
	_spawn_moving_projectiles(game, PROJECTILE_COUNT)

	for index in range(PICKUP_DROP_COUNT):
		var angle := TAU * float(index) / float(PICKUP_DROP_COUNT)
		var ring := 520.0 + float(index % 7) * 66.0
		var position: Vector2 = game.topology.wrap_position(Vector2.from_angle(angle) * ring)
		game._spawn_analysis_pickup(1, position)
	for index in range(FEEDBACK_EFFECT_COUNT):
		var angle := TAU * float(index) / float(FEEDBACK_EFFECT_COUNT)
		game._spawn_visual_burst(Vector2.from_angle(angle) * 260.0, &"spark", AlveolusVisualTheme.TURQUOISE, 4, 10.0, 24.0)

	# Measure actual simulation and renderer CPU work. Awaiting physics_frame at
	# a high tick rate mostly measures the engine scheduler and hid regressions.
	paused = true
	var feedback_remaining_before := _feedback_remaining(game)
	for _frame in range(WARMUP_PHYSICS_FRAMES):
		game.run_session.step_fixed(FIXED_DELTA)
		_flush_all_renderers(game)
	game.enemy_world.reset_crowd_profile_counters()
	var memory_before: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var node_count_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var frame_samples_ms: Array[float] = []
	var subsystem_samples: Dictionary = {}
	var started_usec := Time.get_ticks_usec()
	for _frame in range(MEASURED_PHYSICS_FRAMES):
		var frame_started_usec := Time.get_ticks_usec()
		game.run_session.step_fixed(FIXED_DELTA)
		for phase_id in game.last_phase_timings_ms:
			if not subsystem_samples.has(phase_id):
				subsystem_samples[phase_id] = [] as Array[float]
			(subsystem_samples[phase_id] as Array[float]).append(float(game.last_phase_timings_ms[phase_id]))
		_profile_renderer_flushes(game, subsystem_samples)
		frame_samples_ms.append(float(Time.get_ticks_usec() - frame_started_usec) / 1000.0)
	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var crowd_profile: PackedInt64Array = game.enemy_world.crowd_profile_snapshot()
	var timings: Dictionary = Metrics.summarize_ms(frame_samples_ms)
	var average_ms := float(timings.avg)
	var p50_ms := float(timings.p50)
	var p95_ms := float(timings.p95)
	var p99_ms := float(timings.p99)
	var max_frame_ms := float(timings.max)
	var stored_analysis := 0
	for pickup in game.pickups:
		stored_analysis += pickup.analysis_value
	var bounded_pickups: bool = game.pickups.size() <= game.MAX_ACTIVE_PICKUPS
	var value_preserved: bool = stored_analysis == PICKUP_DROP_COUNT
	var recycled_enemy: InfectionEnemy = game.enemies.back()
	var recycled_enemy_id := recycled_enemy.get_instance_id()
	recycled_enemy.take_damage(99999.0, &"therapy")
	var replacement: InfectionEnemy = game._spawn_enemy(&"pneumococcus", Vector2(700.0, 0.0))
	var enemy_reused := replacement != null and replacement.get_instance_id() == recycled_enemy_id
	var crowd_batched: bool = game.crowd_renderer.is_batching()
	var feedback_bounded: bool = game.visual_bursts.size() == FEEDBACK_EFFECT_COUNT
	var projectiles_bounded: bool = game.projectiles.size() == PROJECTILE_COUNT
	var feedback_rendered: bool = game.feedback_renderer.active_count() == FEEDBACK_EFFECT_COUNT
	var projectiles_rendered: bool = game.projectile_renderer.active_count() == PROJECTILE_COUNT
	var feedback_lifetime_stable := is_equal_approx(_feedback_remaining(game), feedback_remaining_before)
	var exact_enemy_count: bool = game.enemies.size() == enemy_count
	var maximum_guard_queries: int = MEASURED_PHYSICS_FRAMES * (
		ceili(float(enemy_count) / float(EnemyWorld.DIRECT_COLLISION_UPDATE_PHASES)) + 1
	)
	var guard_queries_bounded: bool = (
		crowd_profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES] <= maximum_guard_queries
	)
	var corridor_queries_reuse_guards: bool = (
		crowd_profile[EnemyWorld.CrowdProfileCounter.CORRIDOR_EVALUATIONS]
		<= crowd_profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES]
	)
	var grid_updates_incremental: bool = crowd_profile[EnemyWorld.CrowdProfileCounter.GRID_REBUILDS] == 0
	var replacement_clean: bool = (
		replacement != null
		and replacement.global_position.is_equal_approx(game.topology.wrap_position(Vector2(700.0, 0.0)))
		and not replacement.is_targetable()
	)
	var memory_after: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var node_count_after: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var passed: bool = (
		elapsed_ms <= MAX_WALL_TIME_MS
		and average_ms <= MAX_AVERAGE_FRAME_MS
		and p95_ms <= MAX_P95_FRAME_MS
		and p99_ms <= MAX_P99_FRAME_MS
		and max_frame_ms <= MAX_SINGLE_FRAME_MS
		and bounded_pickups
		and value_preserved
		and enemy_reused
		and replacement_clean
		and crowd_batched
		and feedback_bounded
		and projectiles_bounded
		and feedback_rendered
		and projectiles_rendered
		and feedback_lifetime_stable
		and exact_enemy_count
		and guard_queries_bounded
		and corridor_queries_reuse_guards
		and grid_updates_incremental
	)
	var quality := {
		"bounded_pickups": bounded_pickups,
		"drop_value_preserved": value_preserved,
		"enemy_pool_reused": enemy_reused,
		"reused_activation_clean": replacement_clean,
		"crowd_batched": crowd_batched,
		"feedback_bounded": feedback_bounded,
		"projectiles_bounded": projectiles_bounded,
		"feedback_rendered": feedback_rendered,
		"projectiles_rendered": projectiles_rendered,
		"feedback_lifetime_stable": feedback_lifetime_stable,
		"exact_enemy_count": exact_enemy_count,
		"guard_queries_bounded": guard_queries_bounded,
		"maximum_guard_queries": maximum_guard_queries,
		"corridor_queries_reuse_guards": corridor_queries_reuse_guards,
		"grid_updates_incremental": grid_updates_incremental,
	}
	var subsystem_timings: Dictionary = {}
	for phase_id in subsystem_samples:
		subsystem_timings[String(phase_id)] = Metrics.summarize_ms(subsystem_samples[phase_id])
	var report: Dictionary = Metrics.machine_metadata()
	report.merge({
		"schema": "alveolus.performance.v2",
		"passed": passed,
		"warmup_frames": WARMUP_PHYSICS_FRAMES,
		"measured_frames": MEASURED_PHYSICS_FRAMES,
		"timing_ms": {
			"elapsed": elapsed_ms,
			"avg": average_ms,
			"p50": p50_ms,
			"p95": p95_ms,
			"p99": p99_ms,
			"max": max_frame_ms,
			"process_monitor": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics_monitor": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		},
		"budgets_ms": {
			"elapsed": MAX_WALL_TIME_MS,
			"avg": MAX_AVERAGE_FRAME_MS,
			"p95": MAX_P95_FRAME_MS,
			"p99": MAX_P99_FRAME_MS,
			"max": MAX_SINGLE_FRAME_MS,
		},
		"counts": {
			"enemies": game.enemies.size(),
			"pickups": game.pickups.size(),
			"drop_values": PICKUP_DROP_COUNT,
			"stored_drop_values": stored_analysis,
			"feedback": game.visual_bursts.size(),
			"projectiles": game.projectiles.size(),
			"feedback_renderer_active": game.feedback_renderer.active_count(),
			"feedback_particles": game.feedback_renderer.active_particle_count(),
			"projectile_renderer_active": game.projectile_renderer.active_count(),
			"enemy_pool": game.enemy_pool.size(),
			"projectile_pool": game.projectile_pool.size(),
			"nodes_before": node_count_before,
			"nodes_after": node_count_after,
			"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			"render_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		},
		"memory_bytes": {
			"before": memory_before,
			"after": memory_after,
			"delta": memory_after - memory_before,
			"peak": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		},
		"quality": quality,
		"crowd_profile": {
			"grid_rebuilds": crowd_profile[EnemyWorld.CrowdProfileCounter.GRID_REBUILDS],
			"guard_queries": crowd_profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES],
			"guard_candidates": crowd_profile[EnemyWorld.CrowdProfileCounter.GUARD_CANDIDATES],
			"corridor_evaluations": crowd_profile[EnemyWorld.CrowdProfileCounter.CORRIDOR_EVALUATIONS],
			"active_bypass_ticks": crowd_profile[EnemyWorld.CrowdProfileCounter.ACTIVE_BYPASS_TICKS],
			"queued_no_corridor": crowd_profile[EnemyWorld.CrowdProfileCounter.QUEUED_NO_CORRIDOR],
			"bypass_starts": crowd_profile[EnemyWorld.CrowdProfileCounter.BYPASS_STARTS],
			"side_switches": crowd_profile[EnemyWorld.CrowdProfileCounter.SIDE_SWITCHES],
			"grid_rebuild_usec": crowd_profile[EnemyWorld.CrowdProfileCounter.GRID_REBUILD_USEC],
			"guard_prepare_usec": crowd_profile[EnemyWorld.CrowdProfileCounter.GUARD_PREPARE_USEC],
			"movement_usec": crowd_profile[EnemyWorld.CrowdProfileCounter.MOVEMENT_USEC],
		},
		"subsystem_timing_ms": subsystem_timings,
	}, true)
	print("ALVEOLUS_PERF %s enemies=%d pickups=%d drops=%d stored=%d feedback=%d enemy_reused=%s crowd_batched=%s frames=%d elapsed_ms=%.1f average_ms=%.3f p95_ms=%.3f p99_ms=%.3f max_ms=%.3f nodes=%d" % [
		"OK" if passed else "FAILED",
		game.enemies.size(), game.pickups.size(), PICKUP_DROP_COUNT, stored_analysis, game.visual_bursts.size(), enemy_reused, crowd_batched, MEASURED_PHYSICS_FRAMES,
		elapsed_ms, average_ms, p95_ms, p99_ms, max_frame_ms, node_count_after
	])
	print("ALVEOLUS_PERF_JSON=%s" % JSON.stringify(report))
	paused = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _requested_enemy_count() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crowd-enemies="):
			return clampi(argument.trim_prefix("--crowd-enemies=").to_int(), 1, 600)
	return DEFAULT_ENEMY_COUNT

func _spawn_moving_projectiles(game: Node, count: int) -> void:
	var shots: Array[TreatmentShot] = []
	for index in range(count):
		var origin := Vector2.from_angle(TAU * float(index) / float(maxi(count, 1))) * 180.0
		shots.append(TreatmentShot.tracking(origin, game.enemies[index % game.enemies.size()], 0.0, 2000.0, &"stress"))
	game._on_treatment_shots_requested(shots)
	for index in range(game.projectiles.size()):
		var projectile: TherapyProjectile = game.projectiles[index]
		projectile.lifetime = 100000.0
		# The bounded arena intentionally retires projectiles at its hard edge.
		# A low non-zero speed keeps all 512 moving for the complete 23-second
		# benchmark instead of silently turning this into a zero-projectile sample.
		projectile.speed = 24.0
		projectile.direction = Vector2.from_angle(TAU * float(index) / float(maxi(game.projectiles.size(), 1)) + PI * 0.5)
		projectile.rotation = projectile.direction.angle()
		projectile.target = null


## RunSession publishes the crowd/projectile fixed-tick snapshots before this
## helper runs. Feedback has no simulation snapshot: flushing only rebuilds its
## render buffer and deliberately does not advance VisualBurst.remaining.
func _flush_all_renderers(game: Node) -> void:
	game.crowd_renderer.flush_render_state(1.0)
	game.projectile_renderer.flush_render_state(1.0)
	game.feedback_renderer.flush_render_state()


func _profile_renderer_flushes(game: Node, subsystem_samples: Dictionary) -> void:
	var started_usec := Time.get_ticks_usec()
	game.crowd_renderer.flush_render_state(1.0)
	_append_subsystem_sample(subsystem_samples, &"crowd_renderer", started_usec)
	started_usec = Time.get_ticks_usec()
	game.projectile_renderer.flush_render_state(1.0)
	_append_subsystem_sample(subsystem_samples, &"projectile_renderer", started_usec)
	started_usec = Time.get_ticks_usec()
	# Do not call step_and_render() here: the synchronous benchmark is paused,
	# and advancing feedback with an artificial or OS delta would corrupt the
	# stable 80-effect acceptance load.
	game.feedback_renderer.flush_render_state()
	_append_subsystem_sample(subsystem_samples, &"feedback_renderer", started_usec)


func _append_subsystem_sample(samples: Dictionary, id: StringName, started_usec: int) -> void:
	if not samples.has(id):
		samples[id] = [] as Array[float]
	(samples[id] as Array[float]).append(float(Time.get_ticks_usec() - started_usec) / 1000.0)


func _feedback_remaining(game: Node) -> float:
	var total := 0.0
	for burst in game.visual_bursts:
		total += burst.remaining
	return total
