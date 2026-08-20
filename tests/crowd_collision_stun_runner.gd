extends SceneTree

var assertions := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var topology := ArenaTopology.new(Rect2(-500.0, -500.0, 1000.0, 1000.0))
	var avatar := TherapyAvatar.new()
	avatar.configure(topology.bounds, PlayerStats.new(), topology)
	avatar.global_position = Vector2.ZERO
	var definition := EnemyDefinition.create(
		&"collision_test", "Testgegner", 100.0, 60.0, 5.0, 0, 18.0, Color.WHITE
	)
	var first := InfectionEnemy.new()
	var second := InfectionEnemy.new()
	first.configure(definition, avatar, topology)
	second.configure(definition, avatar, topology)
	first.spawn_timer = 0.0
	second.spawn_timer = 0.0
	first.global_position = Vector2(80.0, 0.0)
	second.global_position = Vector2(80.0, 0.0)
	first.reset_visual_motion()
	second.reset_visual_motion()
	var world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	world.configure_crowd_collision(topology, avatar, 18.0)
	_true(EntityHandle.is_valid(world.register_enemy(first)), "Erster Gegner erhält einen stabilen World-Handle")
	_true(EntityHandle.is_valid(world.register_enemy(second)), "Zweiter Gegner erhält einen stabilen World-Handle")
	world.step_fixed(1.0 / 60.0)
	_true(first.global_position.distance_to(second.global_position) > 0.1, "Zwei überlagerte Gegner lenken vor der Bewegung auseinander")

	first.global_position = Vector2(1.0, 0.0)
	second.global_position = Vector2(-300.0, 0.0)
	avatar.global_position = Vector2.ZERO
	world.step_fixed(1.0 / 60.0)
	_true(avatar.crowd_blocking().length_squared() > 0.0, "Ein größerer Gegner blockiert nur die Bewegungsrichtung des Doctors")
	_true(first.global_position.x < 1.0, "Ein größerer Gegner wird vom Doctor nicht weggeschoben")

	var small_definition := EnemyDefinition.create(
		&"pneumococcus", "Kleines Bakterium", 22.0, 60.0, 2.0, 1, 18.0, Color.WHITE
	)
	first.configure(small_definition, avatar, topology)
	first.spawn_timer = 0.0
	first.global_position = Vector2(1.0, 0.0)
	world.step_fixed(1.0 / 60.0)
	_true(avatar.crowd_blocking().length_squared() <= 0.0001, "Ein kleines Bakterium blockiert den Doctor nicht hart")
	_true(first.global_position.x > 1.0, "Nur ein kleines Bakterium weicht sichtbar vor dem Doctor zurück")

	first.global_position = Vector2(100.0, 0.0)
	first.reset_visual_motion()
	var knockback_origin := first.global_position
	first.apply_knockback(Vector2.RIGHT, 120.0, 0.28, 1.0)
	_true(first.is_stunned(), "Stoß markiert den Gegner sofort als betäubt")
	world.step_fixed(0.08)
	var partial_distance := first.global_position.distance_to(knockback_origin)
	_true(partial_distance > 0.0 and partial_distance < 120.0, "Rückstoß bewegt sichtbar über mehrere Ticks statt zu teleportieren")
	for _step in range(3):
		world.step_fixed(0.08)
	_true(first.global_position.distance_to(knockback_origin) >= 119.0, "Der vollständige Rückstoßweg wird erreicht")
	for _step in range(11):
		world.step_fixed(0.08)
	_true(not first.is_stunned(), "Betäubung endet nach einer Sekunde")
	world.clear()
	first.free()
	second.free()
	avatar.free()

	if failures == 0:
		print("ALVEOLUS_CROWD_COLLISION_STUN_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_CROWD_COLLISION_STUN_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)
