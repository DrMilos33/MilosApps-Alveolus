extends SceneTree

## Reproduces the former P0 through the real Game fixed-step order:
## EnemyWorld steps first, a projectile kills afterwards, combat events recycle
## at tick end, and the same pooled Node is spawned again immediately.

const FIXED_DELTA := 1.0 / 60.0
const REUSE_CYCLES := 128
const POSITION_EPSILON := 0.08

var assertions := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	paused = false
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
	game.standard_wave_director.cancel()
	game.treatment_controller.enabled = false
	game.ability_controller.clear()
	game.stats.immune_level = 0
	game.stats.support_level = 0

	# Remove the run's opening group outside a fixed step, leaving only reusable
	# Nodes and a completely available EnemyWorld.
	var opening_enemies: Array = game.enemies.duplicate()
	for value in opening_enemies:
		var opening_enemy := value as InfectionEnemy
		game.enemies.erase(opening_enemy)
		game._store_enemy(opening_enemy)
	_assert_equal(game.enemy_world.active_count(), 0, "Opening enemies leave no logical leases")
	_assert_equal(game.enemy_world.allocated_count(), 0, "Opening enemies leave no physical leases")
	_assert_equal(game.enemy_world.available_count(), game.combat_capacity.max_enemies, "All enemy capacity is initially available")

	var reused_instance_id: int = 0
	for cycle in range(REUSE_CYCLES):
		var spawn_position := Vector2(390.0 + float(cycle % 5) * 9.0, -140.0 + float(cycle % 7) * 11.0)
		var request: EnemySpawnRequest = null
		if cycle == 0:
			request = EnemySpawnRequest.create(
				&"pneumococcus", spawn_position, &"", 1.0, 0.0, 1.0
			).configure_body_interaction(
				EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE,
				EnemySpawnRequest.ObstacleTraversal.PHASE_THROUGH
			)
		var enemy: InfectionEnemy = game._spawn_enemy(
			&"pneumococcus", spawn_position, 1.0, false, false, request
		)
		_assert_true(is_instance_valid(enemy), "Cycle %d spawns from available capacity" % cycle)
		if not is_instance_valid(enemy):
			break
		if reused_instance_id == 0:
			reused_instance_id = enemy.get_instance_id()
		_assert_equal(enemy.get_instance_id(), reused_instance_id, "Cycle %d reuses one stable pooled Node" % cycle)
		if cycle == 0:
			_assert_true(enemy.is_static_flow_obstacle(), "Cycle 0 carries the explicit static body role")
			_assert_equal(enemy.obstacle_traversal, EnemySpawnRequest.ObstacleTraversal.PHASE_THROUGH, "Cycle 0 carries the explicit traversal override")
		elif cycle == 1:
			_assert_true(not enemy.is_static_flow_obstacle(), "The reused Node resets to a mobile body")
			_assert_equal(enemy.body_role, EnemySpawnRequest.BodyRole.MOBILE, "The reused Node carries the mobile default")
			_assert_equal(enemy.obstacle_traversal, EnemySpawnRequest.ObstacleTraversal.DEFAULT, "The reused Node clears the old traversal override")
		enemy.spawn_timer = 0.0
		enemy.materialized_emitted = true
		enemy.reset_visual_motion()

		var handle: int = game.enemy_world.handle_for(enemy)
		_assert_true(EntityHandle.is_valid(handle), "Cycle %d has an active generation-safe handle" % cycle)
		_assert_true(game.enemy_world.resolve(handle) == enemy, "Cycle %d handle resolves to its sole owner" % cycle)
		_assert_equal(game.enemy_world.allocated_handle_for(enemy), handle, "Cycle %d instance map matches its physical lease" % cycle)
		_assert_unique_active_nodes(game, cycle)

		var before := enemy.global_position
		var expected_distance := enemy.definition.speed * enemy.speed_multiplier * enemy.status_speed_multiplier() * FIXED_DELTA
		var shots: Array[TreatmentShot] = [TreatmentShot.tracking(before, enemy, enemy.health + 100.0, 2000.0, &"reuse_regression")]
		game._on_treatment_shots_requested(shots)
		_assert_equal(game.projectile_world.active_count(), 1, "Cycle %d installs one post-enemy-phase killer" % cycle)

		# Real order: spawn/ability -> EnemyWorld -> combat -> ProjectileWorld ->
		# PickupWorld -> physical release -> event application -> snapshot.
		_assert_true(game.run_session.step_fixed(FIXED_DELTA), "Cycle %d advances the real Game fixed tick" % cycle)
		var moved_distance: float = before.distance_to(enemy.global_position)
		_assert_near(moved_distance, expected_distance, "Cycle %d steps the reused Node exactly once" % cycle)
		_assert_true(not game.enemies.has(enemy), "Cycle %d event flush removes the defeated enemy" % cycle)
		_assert_true(not EntityHandle.is_valid(game.enemy_world.allocated_handle_for(enemy)), "Cycle %d physically releases before pooling" % cycle)
		_assert_equal(game.enemy_world.active_count(), 0, "Cycle %d has no logical enemy slot after event flush" % cycle)
		_assert_equal(game.enemy_world.allocated_count(), 0, "Cycle %d has no hidden physical enemy slot" % cycle)
		_assert_equal(game.enemy_world.regular_count, 0, "Cycle %d restores the regular enemy count" % cycle)
		_assert_equal(game.enemy_world.available_count(), game.combat_capacity.max_enemies, "Cycle %d restores all enemy capacity" % cycle)
		_assert_equal(_occurrences(game.enemy_pool, enemy), 1, "Cycle %d pools the Node exactly once" % cycle)

	game.queue_free()
	await process_frame
	if failures == 0:
		print("ALVEOLUS_ENEMY_DEFERRED_REUSE_OK assertions=%d cycles=%d" % [assertions, REUSE_CYCLES])
	else:
		push_error("ALVEOLUS_ENEMY_DEFERRED_REUSE_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)

func _assert_unique_active_nodes(game: Node, cycle: int) -> void:
	var handles: PackedInt64Array = game.enemy_world.handles()
	_assert_equal(handles.size(), game.enemies.size(), "Cycle %d exposes one handle per active enemy" % cycle)
	var instance_ids := {}
	for handle in handles:
		var node: Node = game.enemy_world.resolve(int(handle))
		_assert_true(is_instance_valid(node), "Cycle %d has no unresolved active slot" % cycle)
		if not is_instance_valid(node):
			continue
		_assert_true(not instance_ids.has(node.get_instance_id()), "Cycle %d never leases one Node twice" % cycle)
		instance_ids[node.get_instance_id()] = true
		_assert_equal(game.enemy_world.handle_for(node), int(handle), "Cycle %d keeps instance-to-handle mapping intact" % cycle)

func _occurrences(items: Array, target: Variant) -> int:
	var count := 0
	for item in items:
		if item == target:
			count += 1
	return count

func _assert_near(actual: float, expected: float, message: String) -> void:
	_assert_true(absf(actual - expected) <= POSITION_EPSILON, "%s (%.4f != %.4f)" % [message, actual, expected])

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (%s != %s)" % [message, str(actual), str(expected)])

func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)
