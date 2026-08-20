extends SceneTree

var assertions := 0
var failures := 0
var contact_hits := 0


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
	for _tick in range(6):
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
	first.pressure_applied.connect(func(_amount: float) -> void: contact_hits += 1)
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
	_true(first.crowd_radius() <= small_definition.radius, "Kleine Bakterien verwenden höchstens ihren eigentlichen Körperradius")
	_true(smallest_spacing >= small_minimum - 0.75, "Kleine Bakterien unterschreiten ihre Modellhülle nicht (%.2f / %.2f)" % [smallest_spacing, small_minimum])

	# A converging pair must steer rather than inherit the old collision brake.
	first.global_position = Vector2(220.0, -20.0)
	second.global_position = Vector2(220.0, 20.0)
	first.reset_visual_motion()
	second.reset_visual_motion()
	var first_travel := 0.0
	var second_travel := 0.0
	for _tick in range(30):
		var first_before := first.global_position
		var second_before := second.global_position
		world.step_fixed(1.0 / 60.0)
		first_travel += topology.shortest_delta(first_before, first.global_position).length()
		second_travel += topology.shortest_delta(second_before, second.global_position).length()
	var free_travel := small_definition.speed * 0.5
	_true(first_travel >= free_travel * 0.9, "Kollisionen bremsen den ersten Gegner nicht ab (%.2f / %.2f)" % [first_travel, free_travel])
	_true(second_travel >= free_travel * 0.9, "Kollisionen bremsen den zweiten Gegner nicht ab (%.2f / %.2f)" % [second_travel, free_travel])

	# A front body owns the direct lane and must reach the contact shell. Its
	# follower keeps one bypass side for the complete pass instead of alternating
	# left/right every 100 ms.
	first.global_position = Vector2(100.0, 0.0)
	second.global_position = Vector2(140.0, 0.0)
	first.reset_visual_motion()
	second.reset_visual_motion()
	contact_hits = 0
	var follower_previous_y := second.global_position.y
	var follower_lateral_sign := 0
	var follower_lateral_flips := 0
	var follower_lateral_travel := 0.0
	for tick in range(150):
		world.step_fixed(1.0 / 60.0)
		var lateral_step := second.global_position.y - follower_previous_y
		follower_previous_y = second.global_position.y
		follower_lateral_travel += absf(lateral_step)
		# Once the pass is complete, returning from the lane to the Doctor is an
		# intentional direction change. Only count oscillation while the follower
		# is still actively navigating around the front body.
		if tick < 60 and absf(lateral_step) > 0.01:
			var step_sign := 1 if lateral_step > 0.0 else -1
			if follower_lateral_sign != 0 and step_sign != follower_lateral_sign:
				follower_lateral_flips += 1
			follower_lateral_sign = step_sign
	_true(contact_hits > 0, "Die Vorderreihe erreicht den Doctor und löst Kontaktschaden aus")
	_true(follower_lateral_travel >= 12.0, "Der hintere Gegner läuft sichtbar seitlich an der Vorderreihe vorbei (%.2f)" % follower_lateral_travel)
	_true(follower_lateral_flips <= 1, "Eine aktive Umgehung wechselt nicht wiederholt ihre Seite (%d Wechsel)" % follower_lateral_flips)

	# When the Doctor stands still, a follower queued directly behind an attacker
	# still passes, but it must not orbit the complete contact ring at full speed.
	var queue_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	queue_world.configure_crowd_collision(topology, avatar, 18.0)
	var queue_front := InfectionEnemy.new()
	var queue_follower := InfectionEnemy.new()
	queue_front.configure(small_definition, avatar, topology)
	queue_follower.configure(small_definition, avatar, topology)
	queue_front.spawn_timer = 0.0
	queue_follower.spawn_timer = 0.0
	queue_front.global_position = Vector2(40.0, 0.0)
	queue_follower.global_position = Vector2(76.0, 0.0)
	queue_front.reset_visual_motion()
	queue_follower.reset_visual_motion()
	avatar.velocity = Vector2.ZERO
	_true(EntityHandle.is_valid(queue_world.register_enemy(queue_front)), "Stillstands-Front erhält einen stabilen Handle")
	_true(EntityHandle.is_valid(queue_world.register_enemy(queue_follower)), "Stillstands-Folgegegner erhält einen stabilen Handle")
	var queued_travel := 0.0
	for _tick in range(60):
		var follower_before := queue_follower.global_position
		queue_world.step_fixed(1.0 / 60.0)
		queued_travel += topology.shortest_delta(follower_before, queue_follower.global_position).length()
	_true(queued_travel >= 4.0, "Die Stillstandsreihe bleibt beweglich statt vollständig einzufrieren (%.2f)" % queued_travel)
	_true(queued_travel <= 24.0, "Die Stillstandsreihe umkreist den Doctor nicht länger mit voller Geschwindigkeit (%.2f)" % queued_travel)
	avatar.velocity = Vector2.RIGHT * 100.0
	var moving_queue_travel := 0.0
	for _tick in range(30):
		var follower_before := queue_follower.global_position
		queue_world.step_fixed(1.0 / 60.0)
		moving_queue_travel += topology.shortest_delta(follower_before, queue_follower.global_position).length()
	_true(moving_queue_travel >= 20.0, "Bei Bewegung des Doctors nimmt die Reihe wieder ihr normales Tempo auf (%.2f)" % moving_queue_travel)
	avatar.velocity = Vector2.ZERO
	queue_world.clear()
	queue_front.free()
	queue_follower.free()

	# A rear body that starts too close must yield. The leading body may continue
	# toward the avatar but must never be pushed back out by its follower.
	first.global_position = Vector2(60.0, 0.0)
	second.global_position = Vector2(92.0, 0.0)
	first.reset_visual_motion()
	second.reset_visual_motion()
	var leading_start_distance := first.global_position.distance_to(avatar.global_position)
	var initial_pair_spacing := topology.shortest_delta(first.global_position, second.global_position).length()
	var leading_max_distance := leading_start_distance
	for _tick in range(30):
		world.step_fixed(1.0 / 60.0)
		leading_max_distance = maxf(leading_max_distance, first.global_position.distance_to(avatar.global_position))
	_true(leading_max_distance <= leading_start_distance + 0.25, "Ein hinterer Gegner schiebt den vorderen nicht vom Ziel weg")
	_true(topology.shortest_delta(first.global_position, second.global_position).length() > initial_pair_spacing, "Eine bestehende Überlappung löst sich ohne Rückwärtsschub des vorderen Gegners")

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
	_true(cluster_minimum > cluster_definition.radius * 2.0, "Rote Gruppen behalten eine kleine modellbezogene Körperhülle")
	_true(cluster_minimum <= cluster_definition.radius * 2.1, "Rote Gruppen erhalten keinen breiten unsichtbaren Außenabstand")
	_true(smallest_cluster_spacing >= cluster_minimum - 0.75, "Rote Gruppen unterschreiten ihre Modellhülle nicht (%.2f / %.2f)" % [smallest_cluster_spacing, cluster_minimum])

	first.global_position = Vector2(1.0, 0.0)
	second.global_position = Vector2(-300.0, 0.0)
	avatar.global_position = Vector2.ZERO
	first.reset_visual_motion()
	second.reset_visual_motion()
	world.step_fixed(1.0 / 60.0)
	_true(avatar.crowd_blocking().length_squared() > 0.0, "Ein größerer Gegner blockiert nur die Bewegungsrichtung des Doctors")
	_true(first.global_position.x <= 1.05, "Ein größerer Gegner wird vom Doctor nicht weggeschoben")

	first.configure(small_definition, avatar, topology)
	first.spawn_timer = 0.0
	first.global_position = Vector2(10.0, 0.0)
	for _tick in range(6):
		world.step_fixed(1.0 / 60.0)
	var small_avatar_yield_origin := first.global_position
	for _tick in range(6):
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
	var dense_minimum_tick := -1
	var dense_minimum_pair := Vector2i(-1, -1)
	for tick in range(90):
		world.step_fixed(1.0 / 60.0)
		for first_index in range(dense_enemies.size()):
			for second_index in range(first_index + 1, dense_enemies.size()):
				var pair_spacing := topology.shortest_delta(
					dense_enemies[first_index].global_position,
					dense_enemies[second_index].global_position
				).length()
				if pair_spacing < dense_smallest_spacing:
					dense_smallest_spacing = pair_spacing
					dense_minimum_tick = tick
					dense_minimum_pair = Vector2i(first_index, second_index)
	var dense_first_position := dense_enemies[dense_minimum_pair.x].global_position if dense_minimum_pair.x >= 0 else Vector2.ZERO
	var dense_second_position := dense_enemies[dense_minimum_pair.y].global_position if dense_minimum_pair.y >= 0 else Vector2.ZERO
	_true(dense_smallest_spacing >= dense_minimum - 1.25, "Auch mehr als sechs lokale Nachbarn bleiben innerhalb einer Fixed-Tick-Toleranz an ihrer Hülle (%.2f / %.2f, Tick %d, Paar %s, Positionen %s / %s)" % [dense_smallest_spacing, dense_minimum, dense_minimum_tick, dense_minimum_pair, dense_first_position, dense_second_position])
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
