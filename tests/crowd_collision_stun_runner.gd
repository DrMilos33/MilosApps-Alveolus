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
	for _tick in range(90):
		world.step_fixed(1.0 / 60.0)
	var sustained_spacing := topology.shortest_delta(first.global_position, second.global_position).length()
	_true(sustained_spacing >= definition.radius * 2.3, "Lokale Spuren halten gleich große Gegner dauerhaft sichtbar auseinander (%.2f)" % sustained_spacing)

	var small_definition := EnemyDefinition.create(
		&"pneumococcus", "Kleines Bakterium", 22.0, 60.0, 2.0, 1, 18.0, Color.WHITE
	)
	first.configure(small_definition, avatar, topology)
	second.configure(small_definition, avatar, topology)
	first.spawn_timer = 0.0
	second.spawn_timer = 0.0
	first.global_position = Vector2(140.0, -23.0)
	second.global_position = Vector2(140.0, 23.0)
	first.reset_visual_motion()
	second.reset_visual_motion()
	var small_minimum := first.crowd_radius() + second.crowd_radius()
	var smallest_spacing := INF
	for _tick in range(150):
		world.step_fixed(1.0 / 60.0)
		smallest_spacing = minf(smallest_spacing, topology.shortest_delta(first.global_position, second.global_position).length())
	_true(first.crowd_radius() < small_definition.radius * 1.18, "Kleine Bakterien stehen etwas enger als im vorherigen globalen Abstand")
	_true(smallest_spacing >= small_minimum - 0.75, "Kleine Bakterien unterschreiten ihre Modellhülle nicht (%.2f / %.2f)" % [smallest_spacing, small_minimum])

	var cluster_definition := EnemyDefinition.create(
		&"bacterial_cluster", "Bakteriengruppe", 74.0, 45.0, 5.0, 4, 30.0, Color.WHITE
	)
	first.configure(cluster_definition, avatar, topology)
	second.configure(cluster_definition, avatar, topology)
	first.spawn_timer = 0.0
	second.spawn_timer = 0.0
	first.global_position = Vector2(180.0, -49.0)
	second.global_position = Vector2(180.0, 49.0)
	first.reset_visual_motion()
	second.reset_visual_motion()
	world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var cluster_minimum := first.crowd_radius() + second.crowd_radius()
	var smallest_cluster_spacing := INF
	for _tick in range(180):
		world.step_fixed(1.0 / 60.0)
		smallest_cluster_spacing = minf(smallest_cluster_spacing, topology.shortest_delta(first.global_position, second.global_position).length())
	_true(cluster_minimum > cluster_definition.radius * 2.4, "Rote Gruppen erhalten eine modellbezogen größere Abstandshülle")
	_true(smallest_cluster_spacing >= cluster_minimum - 0.75, "Rote Gruppen unterschreiten ihre Modellhülle nicht (%.2f / %.2f)" % [smallest_cluster_spacing, cluster_minimum])

	first.global_position = Vector2(1.0, 0.0)
	second.global_position = Vector2(-300.0, 0.0)
	avatar.global_position = Vector2.ZERO
	world.step_fixed(1.0 / 60.0)
	_true(avatar.crowd_blocking().length_squared() > 0.0, "Ein größerer Gegner blockiert nur die Bewegungsrichtung des Doctors")
	_true(first.global_position.x < 1.0, "Ein größerer Gegner wird vom Doctor nicht weggeschoben")

	first.configure(small_definition, avatar, topology)
	first.spawn_timer = 0.0
	first.global_position = Vector2(10.0, 0.0)
	for _tick in range(3):
		world.step_fixed(1.0 / 60.0)
	var small_avatar_yield_origin := first.global_position
	for _tick in range(3):
		world.step_fixed(1.0 / 60.0)
	_true(avatar.crowd_blocking().length_squared() <= 0.0001, "Ein kleines Bakterium blockiert den Doctor nicht hart")
	_true(first.global_position.x > small_avatar_yield_origin.x, "Nur ein kleines Bakterium weicht sichtbar vor dem Doctor zurück")

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

	# Dense packs previously queried only the first six occupants of a grid cell;
	# a nearer seventh body could therefore be missed and briefly overlap. Keep a
	# full 12-unit ring outside the avatar and track every pair while it closes in.
	avatar.global_position = Vector2.ZERO
	first.configure(small_definition, avatar, topology)
	second.configure(small_definition, avatar, topology)
	first.spawn_timer = 0.0
	second.spawn_timer = 0.0
	var dense_enemies: Array[InfectionEnemy] = [first, second]
	for index in range(10):
		var extra := InfectionEnemy.new()
		extra.configure(small_definition, avatar, topology)
		extra.spawn_timer = 0.0
		_true(EntityHandle.is_valid(world.register_enemy(extra)), "Dichter Gegner %d erhält einen stabilen Handle" % (index + 3))
		dense_enemies.append(extra)
	for index in range(dense_enemies.size()):
		dense_enemies[index].global_position = Vector2.from_angle(TAU * float(index) / float(dense_enemies.size())) * 120.0
		dense_enemies[index].reset_visual_motion()
	var dense_minimum := first.crowd_radius() + second.crowd_radius()
	var dense_smallest_spacing := INF
	for _tick in range(90):
		world.step_fixed(1.0 / 60.0)
		for first_index in range(dense_enemies.size()):
			for second_index in range(first_index + 1, dense_enemies.size()):
				dense_smallest_spacing = minf(dense_smallest_spacing, topology.shortest_delta(
					dense_enemies[first_index].global_position,
					dense_enemies[second_index].global_position
				).length())
	_true(dense_smallest_spacing >= dense_minimum - 0.75, "Auch mehr als sechs lokale Nachbarn unterschreiten ihre Hülle nicht (%.2f / %.2f)" % [dense_smallest_spacing, dense_minimum])
	world.clear()
	for enemy in dense_enemies:
		enemy.free()
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
