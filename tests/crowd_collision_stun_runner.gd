extends SceneTree

var assertions := 0
var failures := 0
var contact_hits := 0
var ring_contact_hits := 0
var ring_hits_this_tick := 0
var ring_max_hits_per_tick := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var topology := ArenaTopology.new(Rect2(-500.0, -500.0, 1000.0, 1000.0))
	var avatar := TherapyAvatar.new()
	avatar.configure(topology.bounds, PlayerStats.new(), topology)
	avatar.global_position = Vector2.ZERO
	avatar.velocity = Vector2.RIGHT * 100.0
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

	# A stationary Doctor exposes twelve deterministic micro slots. Small bodies
	# reserve two adjacent slots, so exactly six may attack while the seventh waits
	# radially behind its matching slot instead of orbiting the complete ring.
	var ring_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	ring_world.configure_crowd_collision(topology, avatar, 18.0)
	var ring_enemies: Array[InfectionEnemy] = []
	var ring_handles := PackedInt64Array()
	avatar.velocity = Vector2.ZERO
	ring_contact_hits = 0
	ring_hits_this_tick = 0
	ring_max_hits_per_tick = 0
	for index in range(7):
		var ring_enemy := InfectionEnemy.new()
		ring_enemy.configure(small_definition, avatar, topology)
		ring_enemy.spawn_timer = 0.0
		var angle := 0.0 if index == 6 else TAU * float(index) / 6.0
		var radius := 126.0 if index == 6 else 90.0
		ring_enemy.global_position = Vector2.from_angle(angle) * radius
		ring_enemy.reset_visual_motion()
		ring_enemy.pressure_applied.connect(_on_ring_pressure_applied)
		var ring_handle := ring_world.register_enemy(ring_enemy)
		_true(EntityHandle.is_valid(ring_handle), "Ringgegner %d erhält einen stabilen Handle" % (index + 1))
		ring_enemies.append(ring_enemy)
		ring_handles.append(ring_handle)
	var waiting_initial_direction := topology.shortest_delta(avatar.global_position, ring_enemies[6].global_position).normalized()
	for _tick in range(180):
		ring_hits_this_tick = 0
		ring_world.step_fixed(1.0 / 60.0)
		ring_max_hits_per_tick = maxi(ring_max_hits_per_tick, ring_hits_this_tick)
	_true(ring_world.contact_ring_is_active(), "Der feste Kontaktring aktiviert sich nach 0,25 Sekunden Stillstand")
	_true(ring_world.contact_ring_claim_count() == 6, "Zwölf Mikroslots ergeben maximal sechs kleine Kontaktplätze")
	var latched_count := 0
	var claimed_indices := PackedInt32Array()
	for index in range(ring_handles.size()):
		var claim := ring_world.contact_ring_claim(ring_handles[index])
		if not claim.is_empty():
			claimed_indices.append(index)
			if bool(claim.get("latched", false)):
				latched_count += 1
	_true(latched_count == 6, "Alle sechs Slotowner erreichen ihren Kontaktpunkt und bleiben dort")
	_true(ring_world.contact_ring_claim(ring_handles[6]).is_empty(), "Der siebte kleine Gegner erhält keinen überbuchten Kontaktplatz")
	var waiting_distance := topology.distance(avatar.global_position, ring_enemies[6].global_position)
	_true(waiting_distance >= 76.0 and waiting_distance <= 84.0, "Der siebte Gegner wartet radial hinter dem passenden Slot (%.2f)" % waiting_distance)
	var waiting_final_direction := topology.shortest_delta(avatar.global_position, ring_enemies[6].global_position).normalized()
	_true(absf(waiting_initial_direction.angle_to(waiting_final_direction)) <= 0.35, "Der wartende Gegner läuft keinen sichtbaren Orbit (%.3f rad)" % absf(waiting_initial_direction.angle_to(waiting_final_direction)))
	var ring_minimum_spacing := INF
	for first_index in range(claimed_indices.size()):
		for second_index in range(first_index + 1, claimed_indices.size()):
			ring_minimum_spacing = minf(
				ring_minimum_spacing,
				topology.distance(
					ring_enemies[claimed_indices[first_index]].global_position,
					ring_enemies[claimed_indices[second_index]].global_position
				)
			)
	_true(ring_minimum_spacing >= small_minimum - 0.75, "Kontaktplätze halten die sichtbare Körperhülle ein (%.2f / %.2f)" % [ring_minimum_spacing, small_minimum])
	_true(ring_contact_hits > 0, "Gelatchte Ringgegner lösen stabil Kontaktschaden aus")
	_true(ring_max_hits_per_tick <= 2, "Slotphasen verhindern einen ungestaffelten Kontaktschadensburst (%d gleichzeitig)" % ring_max_hits_per_tick)

	# Knockback releases a generation-safe claim. The waiting seventh body takes
	# exactly that span and advances directly into the newly free contact point.
	var released_index := int(claimed_indices[0])
	var released_enemy := ring_enemies[released_index]
	var knockback_direction := topology.shortest_delta(avatar.global_position, released_enemy.global_position).normalized()
	released_enemy.apply_knockback(knockback_direction, 90.0, 0.28, 1.0)
	for _tick in range(12):
		ring_world.step_fixed(1.0 / 60.0)
	_true(not ring_world.contact_ring_claim(ring_handles[6]).is_empty(), "Der wartende Gegner übernimmt den durch Rückstoß freigegebenen Span")
	for _tick in range(90):
		ring_world.step_fixed(1.0 / 60.0)
	_true(bool(ring_world.contact_ring_claim(ring_handles[6]).get("latched", false)), "Der nachgerückte Gegner erreicht den freigegebenen Kontaktpunkt")

	# Movement hysteresis releases the formation after 0.10 seconds and restores
	# the established moving-avatar solver without retaining stale slot claims.
	avatar.velocity = Vector2.RIGHT * 100.0
	for _tick in range(7):
		ring_world.step_fixed(1.0 / 60.0)
	_true(not ring_world.contact_ring_is_active(), "Doctorbewegung löst den festen Ring nach 0,10 Sekunden")
	_true(ring_world.contact_ring_claim_count() == 0, "Der Moving-Solver übernimmt ohne verbleibende Ringclaims")
	ring_world.clear()
	for ring_enemy in ring_enemies:
		ring_enemy.free()

	# Red bacterial clusters occupy three micro slots each, but they also belong
	# to the shared large-body budget. Two may hold visible contact positions;
	# the third stays in the radial queue even though another three-slot span is
	# geometrically still available.
	var ring_cluster_definition := EnemyDefinition.create(
		&"bacterial_cluster", "Bakteriengruppe", 74.0, 45.0, 5.0, 4, 30.0, Color.WHITE
	)
	var cluster_ring_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	cluster_ring_world.configure_crowd_collision(topology, avatar, ring_cluster_definition.radius)
	var cluster_ring_enemies: Array[InfectionEnemy] = []
	var cluster_ring_handles := PackedInt64Array()
	avatar.velocity = Vector2.ZERO
	for index in range(3):
		var cluster_ring_enemy := InfectionEnemy.new()
		cluster_ring_enemy.configure(ring_cluster_definition, avatar, topology)
		cluster_ring_enemy.spawn_timer = 0.0
		cluster_ring_enemy.global_position = Vector2.from_angle(TAU * float(index) / 3.0) * 100.0
		cluster_ring_enemy.reset_visual_motion()
		var cluster_ring_handle := cluster_ring_world.register_enemy(cluster_ring_enemy)
		_true(EntityHandle.is_valid(cluster_ring_handle), "Ringgruppe %d erhält einen stabilen Handle" % (index + 1))
		cluster_ring_enemies.append(cluster_ring_enemy)
		cluster_ring_handles.append(cluster_ring_handle)
	for _tick in range(90):
		cluster_ring_world.step_fixed(1.0 / 60.0)
	_true(cluster_ring_world.contact_ring_is_active(), "Der Großkörperring aktiviert sich für rote Bakteriengruppen")
	_true(cluster_ring_world.contact_ring_claim_count() == 2, "Der Großkörpervertrag erlaubt exakt zwei rote Bakteriengruppen am Ring")
	for index in range(2):
		var cluster_claim := cluster_ring_world.contact_ring_claim(cluster_ring_handles[index])
		_true(not cluster_claim.is_empty(), "Rote Bakteriengruppe %d erhält einen Kontaktplatz" % (index + 1))
		_true(int(cluster_claim.get("span", 0)) == 3, "Eine rote Bakteriengruppe belegt exakt drei Mikroslots")
	_true(cluster_ring_world.contact_ring_claim(cluster_ring_handles[2]).is_empty(), "Die dritte rote Bakteriengruppe wartet trotz freier Geometrieslots")
	var waiting_cluster_distance := topology.distance(avatar.global_position, cluster_ring_enemies[2].global_position)
	_true(waiting_cluster_distance > TherapyAvatar.BODY_RADIUS + ring_cluster_definition.radius, "Die dritte rote Bakteriengruppe bleibt radial hinter dem Kontaktring (%.2f)" % waiting_cluster_distance)
	cluster_ring_world.clear()
	for cluster_ring_enemy in cluster_ring_enemies:
		cluster_ring_enemy.free()
	avatar.velocity = Vector2.RIGHT * 100.0

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
	world.clear()
	world = EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	world.configure_crowd_collision(topology, avatar, 18.0)
	_true(EntityHandle.is_valid(world.register_enemy(first)), "Dichter erster Gegner erhält einen frischen World-Handle")
	_true(EntityHandle.is_valid(world.register_enemy(second)), "Dichter zweiter Gegner erhält einen frischen World-Handle")
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
	_true(dense_smallest_spacing >= dense_minimum - 2.5, "Auch mehr als sechs lokale Nachbarn bleiben innerhalb einer Fixed-Tick-Toleranz an ihrer Hülle (%.2f / %.2f, Tick %d, Paar %s, Positionen %s / %s)" % [dense_smallest_spacing, dense_minimum, dense_minimum_tick, dense_minimum_pair, dense_first_position, dense_second_position])
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


func _on_ring_pressure_applied(_amount: float) -> void:
	ring_contact_hits += 1
	ring_hits_this_tick += 1
