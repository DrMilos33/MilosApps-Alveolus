extends SceneTree

const Metrics = preload("res://tests/support/performance_metrics.gd")

const ENEMY_COUNT := 600
const PICKUP_DROP_COUNT := 1200
const PROJECTILE_COUNT := 512
const FEEDBACK_COUNT := 80
const FIXED_DELTA := 1.0 / 60.0
const WARMUP_FRAMES := 120
const QUICK_MEASURED_FRAMES := 600
const FULL_MEASURED_FRAMES := 18000
const CHURN_INTERVAL_FRAMES := 12
const CHURN_COUNT := 4
const MAX_P95_MS := 16.7
const MAX_P99_MS := 20.0
const MAX_FRAME_MS := 33.3
const MAX_MEMORY_GROWTH_RATIO := 0.10
const MAX_NODE_GROWTH_RATIO := 0.05

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.physics_ticks_per_second = 60
	var full_soak := OS.get_cmdline_user_args().has("--soak-full")
	var measured_frames := FULL_MEASURED_FRAMES if full_soak else QUICK_MEASURED_FRAMES
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.quick_run = true
	game.persistence_enabled = false
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = game.levels[1]
	game.start_run()
	game.spawn_accumulator = 9999.0
	game.treatment_controller.enabled = false
	# The full soak deliberately outlives every shipped case. It validates the
	# runtime lifecycle, so the normal boss/deadline rules must not end it first.
	game.config.run_duration_seconds = 100000.0
	game.config.final_deadline_seconds = 100000.0
	game.config.contact_damage_multiplier = 0.0
	game.state.max_stability = 1000000000.0
	game.state.stability = game.state.max_stability

	for initial_enemy in game.enemies.duplicate():
		game.enemies.erase(initial_enemy)
		game._store_enemy(initial_enemy)
	for index in range(ENEMY_COUNT):
		_spawn_at_index(game, index, 0)
	_spawn_moving_projectiles(game, PROJECTILE_COUNT)
	for index in range(PICKUP_DROP_COUNT):
		var angle := TAU * float(index) / float(PICKUP_DROP_COUNT)
		var ring := 510.0 + float(index % 8) * 61.0
		game._spawn_analysis_pickup(1, game.topology.wrap_position(Vector2.from_angle(angle) * ring))
	for index in range(FEEDBACK_COUNT):
		var angle := TAU * float(index) / float(FEEDBACK_COUNT)
		game._spawn_visual_burst(Vector2.from_angle(angle) * 260.0, &"soak", AlveolusVisualTheme.TURQUOISE, 4, 360.0, 24.0)

	# Drive the fixed simulation synchronously. Awaiting a headless timer measures
	# OS scheduler jitter rather than combat/render CPU cost and made this gate
	# nondeterministic. Native/browser rAF pacing is covered by the visual soak.
	paused = true
	var feedback_remaining_before := _feedback_remaining(game)
	for _frame in range(WARMUP_FRAMES):
		game.run_session.step_fixed(FIXED_DELTA)
		_flush_all_renderers(game)
	var baseline: Dictionary = Metrics.monitor_snapshot()
	var samples_ms: Array[float] = []
	var renderer_samples: Dictionary = {
		&"crowd_renderer": [] as Array[float],
		&"projectile_renderer": [] as Array[float],
		&"feedback_renderer": [] as Array[float],
	}
	var churn_attempts := 0
	var churn_reused := 0
	var long_frames := 0
	for frame in range(measured_frames):
		if frame % CHURN_INTERVAL_FRAMES == 0:
			for churn_index in range(CHURN_COUNT):
				if game.enemies.is_empty():
					break
				var recycled: InfectionEnemy = game.enemies[game.enemies.size() - 1 - churn_index]
				var recycled_id := recycled.get_instance_id()
				game.enemies.erase(recycled)
				game._store_enemy(recycled)
				var replacement: InfectionEnemy = _spawn_at_index(game, churn_index, frame + 1)
				churn_attempts += 1
				if replacement.get_instance_id() == recycled_id:
					churn_reused += 1
		var started_usec := Time.get_ticks_usec()
		game.run_session.step_fixed(FIXED_DELTA)
		_profile_renderer_flushes(game, renderer_samples)
		var frame_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
		samples_ms.append(frame_ms)
		if frame_ms > MAX_FRAME_MS:
			long_frames += 1

	var final_snapshot: Dictionary = Metrics.monitor_snapshot()
	var timing: Dictionary = Metrics.summarize_ms(samples_ms)
	var memory_growth_ratio := _growth_ratio(float(baseline.memory_static), float(final_snapshot.memory_static))
	var node_growth_ratio := _growth_ratio(float(baseline.nodes), float(final_snapshot.nodes))
	var reuse_ratio := float(churn_reused) / maxf(float(churn_attempts), 1.0)
	var counts_stable: bool = (
		game.enemies.size() == ENEMY_COUNT
		and game.pickups.size() <= game.MAX_ACTIVE_PICKUPS
		and game.projectiles.size() == PROJECTILE_COUNT
		and game.visual_bursts.size() == FEEDBACK_COUNT
		and game.projectile_renderer.active_count() == PROJECTILE_COUNT
		and game.feedback_renderer.active_count() == FEEDBACK_COUNT
	)
	var feedback_lifetime_stable := is_equal_approx(_feedback_remaining(game), feedback_remaining_before)
	var passed: bool = (
		float(timing.p95) <= MAX_P95_MS
		and float(timing.p99) <= MAX_P99_MS
		and float(timing.max) <= MAX_FRAME_MS
		and long_frames == 0
		and memory_growth_ratio <= MAX_MEMORY_GROWTH_RATIO
		and node_growth_ratio <= MAX_NODE_GROWTH_RATIO
		and reuse_ratio >= 0.99
		and counts_stable
		and feedback_lifetime_stable
		and game.crowd_renderer.is_batching()
	)
	var report: Dictionary = Metrics.machine_metadata()
	var renderer_timings: Dictionary = {}
	for renderer_id in renderer_samples:
		renderer_timings[String(renderer_id)] = Metrics.summarize_ms(renderer_samples[renderer_id])
	report.merge({
		"schema": "alveolus.performance_soak.v1",
		"mode": "full_5_minute" if full_soak else "quick_10_second",
		"passed": passed,
		"warmup_frames": WARMUP_FRAMES,
		"measured_frames": measured_frames,
		"timing_ms": timing,
		"budgets_ms": {"p95": MAX_P95_MS, "p99": MAX_P99_MS, "max": MAX_FRAME_MS},
		"counts": {
			"enemies": game.enemies.size(),
			"pickups": game.pickups.size(),
			"drop_values": PICKUP_DROP_COUNT,
			"feedback": game.visual_bursts.size(),
			"projectiles": game.projectiles.size(),
			"feedback_renderer_active": game.feedback_renderer.active_count(),
			"feedback_particles": game.feedback_renderer.active_particle_count(),
			"projectile_renderer_active": game.projectile_renderer.active_count(),
			"churn_attempts": churn_attempts,
			"churn_reused": churn_reused,
			"long_frames": long_frames,
		},
		"growth": {
			"memory_ratio": memory_growth_ratio,
			"node_ratio": node_growth_ratio,
			"memory_budget_ratio": MAX_MEMORY_GROWTH_RATIO,
			"node_budget_ratio": MAX_NODE_GROWTH_RATIO,
		},
		"quality": {
			"counts_stable": counts_stable,
			"feedback_lifetime_stable": feedback_lifetime_stable,
			"crowd_batched": game.crowd_renderer.is_batching(),
			"pool_reuse_ratio": reuse_ratio,
		},
		"subsystem_timing_ms": renderer_timings,
		"baseline_monitors": baseline,
		"final_monitors": final_snapshot,
	}, true)
	print("ALVEOLUS_SOAK %s mode=%s frames=%d avg_ms=%.3f p95_ms=%.3f p99_ms=%.3f max_ms=%.3f reuse=%.3f memory_growth=%.4f node_growth=%.4f" % [
		"OK" if passed else "FAILED",
		report.mode,
		measured_frames,
		float(timing.avg),
		float(timing.p95),
		float(timing.p99),
		float(timing.max),
		reuse_ratio,
		memory_growth_ratio,
		node_growth_ratio,
	])
	print("ALVEOLUS_SOAK_JSON=%s" % JSON.stringify(report))
	paused = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func _spawn_at_index(game: Node, index: int, epoch: int) -> InfectionEnemy:
	var normalized := posmod(index * 17 + epoch * 31, ENEMY_COUNT)
	var angle := TAU * float(normalized) / float(ENEMY_COUNT)
	var ring := 380.0 + float(normalized % 9) * 58.0
	var enemy: InfectionEnemy = game._spawn_enemy(&"pneumococcus", game.topology.wrap_position(Vector2.from_angle(angle) * ring))
	enemy.damage_multiplier = 0.0
	return enemy

func _spawn_moving_projectiles(game: Node, count: int) -> void:
	var shots: Array[TreatmentShot] = []
	for index in range(count):
		var origin := Vector2.from_angle(TAU * float(index) / float(maxi(count, 1))) * 180.0
		shots.append(TreatmentShot.tracking(origin, game.enemies[index % game.enemies.size()], 0.0, 2000.0, &"soak"))
	game._on_treatment_shots_requested(shots)
	for index in range(game.projectiles.size()):
		var projectile: TherapyProjectile = game.projectiles[index]
		projectile.lifetime = 100000.0
		projectile.speed = 520.0
		projectile.direction = Vector2.from_angle(TAU * float(index) / float(maxi(game.projectiles.size(), 1)) + PI * 0.5)
		projectile.rotation = projectile.direction.angle()
		projectile.target = null


## RunSession publishes the crowd/projectile snapshots. Feedback is render-only
## in this paused synchronous test, so its stable workload is flushed without
## consuming lifetime through FeedbackRenderer.step_and_render().
func _flush_all_renderers(game: Node) -> void:
	game.crowd_renderer.flush_render_state(1.0)
	game.projectile_renderer.flush_render_state(1.0)
	game.feedback_renderer.flush_render_state()


func _profile_renderer_flushes(game: Node, samples: Dictionary) -> void:
	var started_usec := Time.get_ticks_usec()
	game.crowd_renderer.flush_render_state(1.0)
	_append_renderer_sample(samples, &"crowd_renderer", started_usec)
	started_usec = Time.get_ticks_usec()
	game.projectile_renderer.flush_render_state(1.0)
	_append_renderer_sample(samples, &"projectile_renderer", started_usec)
	started_usec = Time.get_ticks_usec()
	game.feedback_renderer.flush_render_state()
	_append_renderer_sample(samples, &"feedback_renderer", started_usec)


func _append_renderer_sample(samples: Dictionary, id: StringName, started_usec: int) -> void:
	(samples[id] as Array[float]).append(float(Time.get_ticks_usec() - started_usec) / 1000.0)


func _feedback_remaining(game: Node) -> float:
	var total := 0.0
	for burst in game.visual_bursts:
		total += burst.remaining
	return total

func _growth_ratio(before: float, after: float) -> float:
	if before <= 0.0:
		return 0.0
	return maxf(0.0, (after - before) / before)
