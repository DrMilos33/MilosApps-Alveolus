extends SceneTree

const ENEMY_COUNT := 600
const PICKUP_DROP_COUNT := 1200
const MEASURED_PHYSICS_FRAMES := 240
const MAX_WALL_TIME_MS := 1250.0

func _init() -> void:
	call_deferred("_run_performance_test")

func _run_performance_test() -> void:
	Engine.physics_ticks_per_second = 240
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

	for index in range(ENEMY_COUNT):
		var angle := TAU * float(index) / float(ENEMY_COUNT)
		var ring := 380.0 + float(index % 9) * 58.0
		game._spawn_enemy(&"pneumococcus", game.topology.wrap_position(Vector2.from_angle(angle) * ring))

	for index in range(PICKUP_DROP_COUNT):
		var angle := TAU * float(index) / float(PICKUP_DROP_COUNT)
		var ring := 520.0 + float(index % 7) * 66.0
		var position: Vector2 = game.topology.wrap_position(Vector2.from_angle(angle) * ring)
		game._spawn_analysis_pickup(1, position)

	await physics_frame
	var started_usec := Time.get_ticks_usec()
	for _frame in range(MEASURED_PHYSICS_FRAMES):
		await physics_frame
	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var average_ms := elapsed_ms / float(MEASURED_PHYSICS_FRAMES)
	var stored_analysis := 0
	for pickup in game.pickups:
		stored_analysis += pickup.analysis_value
	var bounded_pickups: bool = game.pickups.size() <= game.MAX_ACTIVE_PICKUPS
	var value_preserved: bool = stored_analysis == PICKUP_DROP_COUNT
	var recycled_enemy: InfectionEnemy = game.enemies.back()
	var recycled_enemy_id := recycled_enemy.get_instance_id()
	recycled_enemy.take_damage(99999.0, &"therapy")
	recycled_enemy._physics_process(InfectionEnemy.DEATH_SECONDS)
	var replacement: InfectionEnemy = game._spawn_enemy(&"pneumococcus", Vector2(700.0, 0.0))
	var enemy_reused := replacement.get_instance_id() == recycled_enemy_id
	var crowd_batched: bool = game.crowd_renderer.is_batching()
	var passed: bool = elapsed_ms <= MAX_WALL_TIME_MS and bounded_pickups and value_preserved and enemy_reused and crowd_batched
	print("ALVEOLUS_PERF %s enemies=%d pickups=%d drops=%d stored=%d enemy_reused=%s crowd_batched=%s frames=%d elapsed_ms=%.1f average_ms=%.3f nodes=%d" % [
		"OK" if passed else "FAILED",
		game.enemies.size(), game.pickups.size(), PICKUP_DROP_COUNT, stored_analysis, enemy_reused, crowd_batched, MEASURED_PHYSICS_FRAMES,
		elapsed_ms, average_ms, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	])
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
