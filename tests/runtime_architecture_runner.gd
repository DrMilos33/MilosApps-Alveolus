extends SceneTree

class FakeSystem extends RefCounted:
	var id: String
	var log: Array[String]
	var begin_calls: int = 0
	var end_calls: int = 0

	func _init(system_id: String, output: Array[String]) -> void:
		id = system_id
		log = output

	func begin_session(_session: RunSession) -> void:
		begin_calls += 1

	func step_fixed(_delta: float, _session: RunSession) -> void:
		log.append(id)

	func end_session(_session: RunSession) -> void:
		end_calls += 1

class FakeEntity extends Node:
	var ticks: int = 0
	var accumulated_delta: float = 0.0

	func step_fixed(delta: float) -> void:
		ticks += 1
		accumulated_delta += delta

class PauseSystem extends RefCounted:
	var log: Array[String]

	func _init(output: Array[String]) -> void:
		log = output

	func step_fixed(_delta: float, session: RunSession) -> void:
		log.append("pause")
		session.pause_session()

var assertions := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_capacity()
	_test_handles()
	_test_spawn_request()
	_test_deferred_events()
	_test_torus_queries()
	_test_node_worlds()
	_test_run_session()
	_test_cosmetic_budget()
	if failures == 0:
		print("ALVEOLUS_RUNTIME_ARCHITECTURE_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_RUNTIME_ARCHITECTURE_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)

func _test_capacity() -> void:
	var capacity := CombatCapacity.defaults()
	_assert_true(capacity.is_valid(), "Default capacity is internally consistent")
	_assert_true(capacity.can_allocate_enemy(599, 40, false), "Last regular slot is available")
	_assert_true(not capacity.can_allocate_enemy(600, 0, false), "Regular enemies cannot consume reserve")
	_assert_true(capacity.can_allocate_enemy(600, 39, true), "Critical spawn can consume reserve")
	_assert_true(not capacity.can_allocate_enemy(600, 40, true), "Total enemy capacity is hard")
	_assert_equal(capacity.available_enemy_slots(598, 10, false), 2, "Regular availability respects regular cap")

func _test_handles() -> void:
	var handle := EntityHandle.make(42, 7)
	_assert_true(EntityHandle.is_valid(handle), "Encoded handle is valid")
	_assert_equal(EntityHandle.slot(handle), 42, "Handle preserves slot")
	_assert_equal(EntityHandle.generation(handle), 7, "Handle preserves generation")
	_assert_true(EntityHandle.matches(handle, 42, 7), "Matching generation resolves")
	_assert_true(not EntityHandle.matches(handle, 42, 8), "Reused generation invalidates stale handle")
	_assert_equal(EntityHandle.make(-1, 1), EntityHandle.INVALID, "Negative slot is invalid")
	_assert_equal(EntityHandle.next_generation(EntityHandle.GENERATION_MASK), 1, "Generation wraps without producing zero")

func _test_spawn_request() -> void:
	var request := EnemySpawnRequest.create(
		&"pneumococcus",
		Vector2(120.0, -40.0),
		&"germ_green",
		1.4,
		1.1,
		1.2,
		PackedInt32Array([3, 4]),
		EnemySpawnRequest.Priority.CRITICAL,
		&"boss_phase"
	)
	request.metadata["wave"] = 2
	request.configure_body_interaction(
		EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE,
		EnemySpawnRequest.ObstacleTraversal.PHASE_THROUGH
	)
	var copy := request.duplicate_request()
	request.metadata["wave"] = 3
	_assert_true(copy.is_valid() and copy.is_critical(), "Spawn request captures complete critical request")
	_assert_equal(copy.resolved_visual_id(), &"germ_green", "Explicit visual id is preserved")
	_assert_equal(copy.metadata["wave"], 2, "Spawn request duplicate owns metadata")
	_assert_equal(copy.boss_phases, PackedInt32Array([3, 4]), "Spawn phases are preserved")
	_assert_equal(copy.body_role, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE, "Spawn request duplicate preserves body role")
	_assert_equal(copy.obstacle_traversal, EnemySpawnRequest.ObstacleTraversal.PHASE_THROUGH, "Spawn request duplicate preserves traversal override")
	request.reset()
	_assert_equal(request.body_role, EnemySpawnRequest.BodyRole.MOBILE, "Spawn request reset restores mobile body role")
	_assert_equal(request.obstacle_traversal, EnemySpawnRequest.ObstacleTraversal.DEFAULT, "Spawn request reset restores default traversal")

func _test_deferred_events() -> void:
	var queue := CombatEventQueue.new()
	var first := queue.push(&"damage", EntityHandle.make(0, 1), EntityHandle.INVALID, 8.0)
	var second := queue.push(&"death", EntityHandle.make(1, 1))
	var observed: Array[int] = []
	var flushed := queue.flush_to(func(event: CombatEventQueue.CombatEvent) -> void:
		observed.append(event.sequence)
		if event.sequence == first:
			queue.push(&"drop", event.subject_handle)
	)
	_assert_equal(flushed, 2, "Flush processes only its initial snapshot")
	_assert_equal(observed, [first, second], "Combat events retain FIFO order")
	_assert_equal(queue.pending_count(), 1, "Re-entrant event is deferred to next flush")
	queue.flush_to(func(event: CombatEventQueue.CombatEvent) -> void: observed.append(event.sequence))
	_assert_equal(observed.size(), 3, "Deferred event is processed exactly once")
	_assert_true(queue.is_empty() and queue.pooled_count() >= 2, "Events return to reusable pool")

func _test_torus_queries() -> void:
	var topology := ArenaTopology.new(Rect2(-500.0, -500.0, 1000.0, 1000.0))
	var left := EntityHandle.make(0, 1)
	var right := EntityHandle.make(1, 1)
	var far := EntityHandle.make(2, 1)
	var handles := PackedInt64Array([left, right, far])
	var positions := {
		left: Vector2(-490.0, 0.0),
		right: Vector2(490.0, 0.0),
		far: Vector2(0.0, 260.0),
	}
	var query := CombatQuery.new().configure(
		topology,
		func(handle: int) -> Vector2: return positions.get(handle, Vector2.ZERO),
		func(_handle: int) -> float: return 10.0,
		func(_handle: int) -> bool: return true,
		func(handle: int) -> Variant: return positions.get(handle),
		64.0,
		16.0
	)
	query.rebuild(handles)
	var seam_circle := query.circle(Vector2(480.0, 0.0), 25.0)
	_assert_true(seam_circle.has(left) and seam_circle.has(right), "Circle query crosses torus seam")
	var nearest := query.nearest(Vector2(485.0, 0.0), 80.0, 2)
	_assert_equal(nearest.size(), 2, "Nearest query finds both seam neighbors")
	_assert_equal(nearest[0], right, "Nearest query keeps distance order")
	var seam_line := query.line(Vector2(480.0, 0.0), Vector2.RIGHT, 40.0, 4.0, 2)
	_assert_true(seam_line.has(left), "Line query crosses torus seam")
	_assert_equal(query.resolve(far), positions[far], "Query resolver exposes integration object")

func _test_run_session() -> void:
	var session := RunSession.new().configure(null, false)
	get_root().add_child(session)
	var log: Array[String] = []
	var late := FakeSystem.new("late", log)
	var early := FakeSystem.new("early", log)
	_assert_true(session.register_system(late, RunSession.Phase.EVENT, 0), "Session accepts fixed-step system")
	_assert_true(session.register_system(early, RunSession.Phase.ENEMY, 0), "Session accepts earlier phase")
	_assert_true(session.start({"seed": 7}), "Session starts from idle")
	_assert_true(session.step_fixed(0.25), "Running session advances")
	_assert_equal(log, ["early", "late"], "Systems execute in deterministic phase order")
	_assert_equal(session.fixed_tick, 1, "Session records fixed tick")
	_assert_near(session.elapsed, 0.25, "Session records fixed time")
	_assert_true(session.pause_session(), "Running session can pause")
	_assert_true(not session.step_fixed(0.25), "Paused session cannot advance")
	_assert_true(session.resume_session(), "Paused session can resume")
	_assert_true(session.finish(true, "done"), "Active session can finish")
	_assert_equal(early.begin_calls, 1, "System begin hook runs once")
	_assert_equal(early.end_calls, 1, "System end hook runs once")
	session.queue_free()
	var interrupted := RunSession.new().configure(null, false)
	get_root().add_child(interrupted)
	var interrupted_log: Array[String] = []
	var pause_system := PauseSystem.new(interrupted_log)
	var late_callback := interrupted.register_callable(
		func(_delta: float) -> void: interrupted_log.append("late"),
		RunSession.Phase.EVENT
	)
	_assert_true(late_callback != null, "Legacy callback can be registered as fixed-step system")
	interrupted.register_system(pause_system, RunSession.Phase.ENEMY)
	interrupted.start()
	interrupted.step_fixed(0.1)
	_assert_equal(interrupted_log, ["pause"], "Lifecycle change aborts remaining systems in current tick")
	interrupted.cancel()
	interrupted.queue_free()

func _test_node_worlds() -> void:
	var small_capacity := CombatCapacity.new().configure(4, 3, 3, 4, 2, 2)
	var world := EnemyWorld.new().configure_enemy_world(small_capacity)
	var enemies: Array[FakeEntity] = []
	var handles := PackedInt64Array()
	for _index in range(4):
		var enemy := FakeEntity.new()
		get_root().add_child(enemy)
		enemies.append(enemy)
	var first := world.register_enemy(enemies[0])
	handles.append(first)
	handles.append(world.register_enemy(enemies[1]))
	handles.append(world.register_enemy(enemies[2]))
	_assert_equal(world.register_enemy(enemies[3]), EntityHandle.INVALID, "EnemyWorld protects critical reserve")
	var critical := world.register_enemy(enemies[3], true)
	_assert_true(EntityHandle.is_valid(critical), "EnemyWorld admits critical entity into reserve")
	var reused_handle_buffer := world.handles()
	reused_handle_buffer = world.handles(reused_handle_buffer)
	_assert_equal(reused_handle_buffer.size(), 4, "Reusable handle buffer retains every active entity")
	_assert_equal(world.handles().size(), 4, "Reusable output cannot clear the registry handle cache")
	_assert_true(not enemies[0].is_physics_processing(), "World disables automatic entity physics")
	world.step_fixed(0.1)
	_assert_equal(enemies[0].ticks, 1, "World centrally steps each entity once")
	_assert_near(enemies[0].accumulated_delta, 0.1, "World forwards fixed delta")
	_assert_true(world.release(first), "World accepts deferred release")
	_assert_true(world.resolve(first) == null, "Retiring handle invalidates immediately")
	_assert_equal(world.allocated_count(), 4, "Deferred slot remains allocated until flush")
	world.flush_deferred()
	_assert_equal(world.allocated_count(), 3, "Flush removes slot with O(1) dense removal")
	var replacement := FakeEntity.new()
	get_root().add_child(replacement)
	var replacement_handle := world.register_enemy(replacement)
	_assert_equal(EntityHandle.slot(replacement_handle), EntityHandle.slot(first), "Released slot is reused")
	_assert_true(EntityHandle.generation(replacement_handle) != EntityHandle.generation(first), "Reused slot advances generation")
	_assert_true(world.resolve(first) == null and world.resolve(replacement_handle) == replacement, "Stale handle cannot resolve replacement")
	var projectile_world := ProjectileWorld.new().configure_projectile_world(small_capacity)
	var projectile := FakeEntity.new()
	get_root().add_child(projectile)
	var projectile_handle := projectile_world.register_projectile(projectile)
	projectile_world.release(projectile_handle)
	projectile_world.step_fixed(0.1)
	_assert_equal(projectile.ticks, 0, "Deferred projectile removal happens before another central step")
	var pickup_world := PickupWorld.new().configure_pickup_world(small_capacity)
	var pickup := FakeEntity.new()
	get_root().add_child(pickup)
	var pickup_handle := pickup_world.register_pickup(pickup)
	_assert_true(pickup_world.resolve(pickup_handle) == pickup, "PickupWorld exposes generation-safe resolution")
	world.clear()
	projectile_world.clear()
	pickup_world.clear()
	for enemy in enemies:
		enemy.queue_free()
	replacement.queue_free()
	projectile.queue_free()
	pickup.queue_free()

func _test_cosmetic_budget() -> void:
	var budget := CosmeticBudgetController.new().configure(true, false)
	get_root().add_child(budget)
	for _index in range(20):
		budget.sample_observed_fps(50.0, 0.1)
	_assert_equal(budget.quality, CosmeticBudgetController.Quality.REDUCED, "Sustained sub-55 FPS reduces one tier")
	for _index in range(20):
		budget.sample_observed_fps(40.0, 0.1)
	_assert_equal(budget.quality, CosmeticBudgetController.Quality.MINIMAL, "Sustained sub-45 FPS reaches minimal tier")
	_assert_equal(budget.particle_count(10, CosmeticBudgetController.EffectPriority.DECORATIVE), 2, "Minimal tier reduces decorative particles")
	_assert_equal(budget.particle_count(10, CosmeticBudgetController.EffectPriority.CRITICAL), 10, "Critical particles are not reduced")
	_assert_true(budget.allows_effect(CosmeticBudgetController.EffectPriority.CRITICAL, 999), "Critical indicator is never rejected")
	for _index in range(50):
		budget.sample_observed_fps(60.0, 0.1)
	_assert_equal(budget.quality, CosmeticBudgetController.Quality.REDUCED, "Recovery changes only one tier after five seconds")
	budget.queue_free()

func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (%s != %s)" % [message, actual, expected])

func _assert_near(actual: float, expected: float, message: String, epsilon: float = 0.0001) -> void:
	_assert_true(absf(actual - expected) <= epsilon, "%s (%.5f != %.5f)" % [message, actual, expected])
