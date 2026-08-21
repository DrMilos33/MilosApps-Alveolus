extends SceneTree

var assertions := 0
var failures := 0
var small_hits := 0
var cluster_hits := 0
var front_hits := 0
var blocked_hits := 0
var offset_hits := 0
var mixed_small_hits := 0
var mixed_cluster_hits := 0
var boss_hits := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var added_input_actions: Array[StringName] = []
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			added_input_actions.append(action)
	var topology := ArenaTopology.new(
		Rect2(-600.0, -400.0, 1200.0, 800.0),
		ArenaTopology.BoundaryMode.BOUNDED
	)
	var avatar := TherapyAvatar.new()
	avatar.configure(topology.bounds, PlayerStats.new(), topology)
	get_root().add_child(avatar)
	avatar.global_position = Vector2.ZERO
	avatar.velocity = Vector2.ZERO

	var small_definition := EnemyDefinition.create(
		&"pneumococcus", "Kleines Bakterium", 22.0, 60.0, 2.0, 1, 18.0, Color.WHITE
	).configure_contact_radius(17.0)
	var cluster_definition := EnemyDefinition.create(
		&"bacterial_cluster", "Bakteriengruppe", 74.0, 45.0, 5.0, 4, 30.0, Color.WHITE
	).configure_contact_radius(23.0)

	# A free path remains exact direct pursuit for both enemy sizes.
	var world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var small := _enemy(small_definition, avatar, topology, Vector2(190.0, 70.0))
	var cluster := _enemy(cluster_definition, avatar, topology, Vector2(-230.0, -85.0))
	small.pressure_applied.connect(_on_small_pressure)
	cluster.pressure_applied.connect(_on_cluster_pressure)
	_true(EntityHandle.is_valid(world.register_enemy(small)), "Kleines Bakterium erhält einen World-Handle")
	_true(EntityHandle.is_valid(world.register_enemy(cluster)), "Rote Bakteriengruppe erhält einen World-Handle")
	var maximum_free_lateral := 0.0
	var maximum_free_retreat := 0.0
	for _tick in range(360):
		var before_positions := [small.global_position, cluster.global_position]
		var before_distances := [
			topology.distance(small.global_position, avatar.global_position),
			topology.distance(cluster.global_position, avatar.global_position),
		]
		world.step_fixed(1.0 / 60.0)
		var enemies: Array[InfectionEnemy] = [small, cluster]
		for index in range(enemies.size()):
			var target_direction := topology.shortest_delta(before_positions[index], avatar.global_position).normalized()
			var step := topology.shortest_delta(before_positions[index], enemies[index].global_position)
			if step.length_squared() > 0.000001:
				maximum_free_lateral = maxf(maximum_free_lateral, absf(step.cross(target_direction)))
			maximum_free_retreat = maxf(
				maximum_free_retreat,
				topology.distance(enemies[index].global_position, avatar.global_position) - before_distances[index]
			)
	_true(maximum_free_lateral <= 0.001, "Freie Verfolgung bleibt exakt geradlinig (%.5f)" % maximum_free_lateral)
	_true(maximum_free_retreat <= 0.001, "Freie Verfolgung entfernt sich nie vom Doctor (%.5f)" % maximum_free_retreat)
	_assert_at_contact(small, avatar, topology, "Kleines Bakterium")
	_assert_at_contact(cluster, avatar, topology, "Rote Bakteriengruppe")
	_true(small_hits > 0, "Das kleine Bakterium greift am Schadenskontakt an")
	_true(cluster_hits > 0, "Die rote Bakteriengruppe greift am Schadenskontakt an")
	world.clear()
	small.free()
	cluster.free()

	# Bosses share Doctor-contact and arena geometry, but ordinary enemy bodies
	# never delay or redirect their direct pursuit.
	var boss_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	var boss_definition := EnemyDefinition.create(
		&"localized_boss", "Testboss", 900.0, 90.0, 6.0, 20, 60.0, Color.WHITE, true
	).configure_contact_radius(47.0)
	var boss_blocker_definition := EnemyDefinition.create(
		&"pneumococcus", "Statischer Blocker", 22.0, 0.0, 0.0, 0, 18.0, Color.WHITE
	).configure_contact_radius(17.0)
	boss_world.configure_crowd_collision(topology, avatar, boss_definition.radius)
	var boss_blockers: Array[InfectionEnemy] = []
	for y in [-35.0, 0.0, 35.0]:
		var blocker := _enemy(boss_blocker_definition, avatar, topology, Vector2(105.0, y))
		boss_blockers.append(blocker)
		_true(EntityHandle.is_valid(boss_world.register_enemy(blocker)), "Bossbarriere erhält einen Handle")
	var direct_boss := _enemy(boss_definition, avatar, topology, Vector2(210.0, 0.0))
	direct_boss.pressure_applied.connect(_on_boss_pressure)
	_true(EntityHandle.is_valid(boss_world.register_enemy(direct_boss, true)), "Boss erhält einen kritischen Handle")
	var boss_maximum_lateral := 0.0
	var boss_maximum_retreat := 0.0
	for _tick in range(180):
		var before := direct_boss.global_position
		var before_distance := topology.distance(before, avatar.global_position)
		boss_world.step_fixed(1.0 / 60.0)
		boss_maximum_lateral = maxf(boss_maximum_lateral, absf(direct_boss.global_position.y))
		boss_maximum_retreat = maxf(
			boss_maximum_retreat,
			topology.distance(direct_boss.global_position, avatar.global_position) - before_distance
		)
	_true(boss_maximum_lateral <= 0.001, "Der Boss läuft geradlinig durch andere Monster (%.5f lateral)" % boss_maximum_lateral)
	_true(boss_maximum_retreat <= 0.001, "Andere Monster drücken den Boss niemals zurück (%.5f)" % boss_maximum_retreat)
	_assert_at_contact(direct_boss, avatar, topology, "Boss")
	_true(boss_hits > 0, "Der Boss erreicht den Doctor durch die Monsterbarriere und greift an")
	for index in range(boss_blockers.size()):
		_true(
			boss_blockers[index].global_position.is_equal_approx(Vector2(105.0, [-35.0, 0.0, 35.0][index])),
			"Bossdurchgang verschiebt normalen Blocker %d nicht" % (index + 1)
		)
	boss_world.clear()
	direct_boss.free()
	for blocker in boss_blockers:
		blocker.free()

	# One real front body is enough to start a stable obstacle bypass. The rear
	# attacker chooses one side, never retreats and eventually reaches contact.
	var queue_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	queue_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var front := _enemy(small_definition, avatar, topology, Vector2(28.5, 0.0))
	var blocked := _enemy(cluster_definition, avatar, topology, Vector2(130.0, 0.0))
	front.pressure_applied.connect(_on_front_pressure)
	blocked.pressure_applied.connect(_on_blocked_pressure)
	var front_handle := queue_world.register_enemy(front)
	_true(EntityHandle.is_valid(front_handle), "Vorderer Angreifer erhält einen Handle")
	_true(EntityHandle.is_valid(queue_world.register_enemy(blocked)), "Blockierte rote Gruppe erhält einen Handle")
	var queue_minimum_spacing := INF
	var queue_maximum_retreat := 0.0
	var queue_lateral_sign := 0
	var queue_lateral_sign_flips := 0
	var queue_maximum_lateral := 0.0
	for _tick in range(240):
		var before_position := blocked.global_position
		var before_distance := topology.distance(blocked.global_position, avatar.global_position)
		queue_world.step_fixed(1.0 / 60.0)
		var target_direction := topology.shortest_delta(before_position, avatar.global_position).normalized()
		var step := topology.shortest_delta(before_position, blocked.global_position)
		var lateral_step := step.cross(target_direction)
		if absf(lateral_step) > 0.01:
			var sign_value := 1 if lateral_step > 0.0 else -1
			if queue_lateral_sign != 0 and sign_value != queue_lateral_sign:
				queue_lateral_sign_flips += 1
			queue_lateral_sign = sign_value
		queue_maximum_lateral = maxf(queue_maximum_lateral, absf(blocked.global_position.y))
		queue_minimum_spacing = minf(queue_minimum_spacing, topology.distance(front.global_position, blocked.global_position))
		queue_maximum_retreat = maxf(
			queue_maximum_retreat,
			topology.distance(blocked.global_position, avatar.global_position) - before_distance
		)
	var small_cluster_boundary := front.contact_body_radius() + blocked.contact_body_radius()
	_true(queue_minimum_spacing >= small_cluster_boundary - 0.06, "Klein/Rot unterschreiten ihre Schadenshitboxen nicht (%.3f / %.3f)" % [queue_minimum_spacing, small_cluster_boundary])
	_true(queue_maximum_lateral > 1.0, "Ein realer Vorderkörper löst das lokale Umlaufen aus")
	_true(queue_lateral_sign_flips <= 1, "Der Verfolger behält beim Umlaufen seine gewählte Seite (%d Wechsel)" % queue_lateral_sign_flips)
	_true(queue_maximum_retreat <= 0.001, "Der blockierte Verfolger läuft niemals zurück (%.5f)" % queue_maximum_retreat)
	_true(front_hits > 0, "Der vordere Körper greift weiterhin an")
	_true(blocked_hits > 0, "Der umlaufende Körper erreicht den Doctor und greift an")
	queue_world.release(front_handle, false)
	for _tick in range(180):
		queue_world.step_fixed(1.0 / 60.0)
	_assert_at_contact(blocked, avatar, topology, "Freigegebene rote Bakteriengruppe")
	_true(blocked_hits > 0, "Nach Freigabe verfolgt und trifft der zuvor blockierte Körper")
	queue_world.clear()
	front.free()
	blocked.free()

	# A slightly offset blocker is the only source of lateral movement. The
	# direct remainder slides on its circle and never gains a retreat component.
	var slide_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	slide_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var slide_front := _enemy(small_definition, avatar, topology, Vector2(28.5, 0.0))
	var slider := _enemy(small_definition, avatar, topology, Vector2(100.0, 12.0))
	slider.pressure_applied.connect(_on_offset_pressure)
	_true(EntityHandle.is_valid(slide_world.register_enemy(slide_front)), "Seitlicher Blocker erhält einen Handle")
	_true(EntityHandle.is_valid(slide_world.register_enemy(slider)), "Seitlicher Verfolger erhält einen Handle")
	var slide_minimum_spacing := INF
	var slide_maximum_retreat := 0.0
	var blocked_lateral := 0.0
	var clear_lateral := 0.0
	var clear_ticks := 0
	var small_boundary := slide_front.contact_body_radius() + slider.contact_body_radius()
	for _tick in range(360):
		var before_position := slider.global_position
		var before_doctor_distance := topology.distance(before_position, avatar.global_position)
		var target_direction := topology.shortest_delta(before_position, avatar.global_position).normalized()
		var direct_step := target_direction * minf(
			small_definition.speed / 60.0,
			maxf(before_doctor_distance - TherapyAvatar.CONTACT_RADIUS - slider.contact_body_radius() + 0.5, 0.0)
		)
		var direct_endpoint := before_position + direct_step
		var direct_would_block := topology.distance(direct_endpoint, slide_front.global_position) < (
			small_boundary
			+ EnemyWorld.DIRECT_COLLISION_SKIN
			+ EnemyWorld.DIRECT_COLLISION_BYPASS_ACTIVATION_MARGIN
		)
		slide_world.step_fixed(1.0 / 60.0)
		var step := topology.shortest_delta(before_position, slider.global_position)
		var lateral := absf(step.cross(target_direction))
		var after_pair_distance := topology.distance(slider.global_position, slide_front.global_position)
		slide_minimum_spacing = minf(slide_minimum_spacing, after_pair_distance)
		slide_maximum_retreat = maxf(
			slide_maximum_retreat,
			topology.distance(slider.global_position, avatar.global_position) - before_doctor_distance
		)
		if direct_would_block:
			clear_ticks = 0
			blocked_lateral = maxf(blocked_lateral, lateral)
		else:
			clear_ticks += 1
			if clear_ticks > EnemyWorld.DIRECT_COLLISION_BYPASS_CLEAR_TICKS:
				clear_lateral = maxf(clear_lateral, lateral)
	_true(slide_minimum_spacing >= small_boundary - 0.06, "Seitliches Gleiten hält die exakte Klein/Klein-Hitboxgrenze (%.3f / %.3f)" % [slide_minimum_spacing, small_boundary])
	_true(blocked_lateral > 0.01, "Seitliche Bewegung entsteht, wenn ein echter Körper den Weg blockiert")
	_true(clear_lateral <= 0.001, "Ohne Körperkontakt bleibt die Verfolgung geradlinig (%.5f)" % clear_lateral)
	_true(slide_maximum_retreat <= 0.001, "Auch beim Gleiten entsteht keine Fluchtbewegung (%.5f)" % slide_maximum_retreat)
	_true(offset_hits > 0, "Der seitlich geglittene Gegner erreicht danach den Doctor")
	slide_world.clear()
	slide_front.free()
	slider.free()

	# A shallow wedge keeps the same stable side for the complete obstacle pass.
	var wedge_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	wedge_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var static_small_definition := EnemyDefinition.create(
		&"static_small", "Statischer Testkörper", 22.0, 0.0, 0.0, 0, 18.0, Color.WHITE
	).configure_contact_radius(17.0)

	# A genuine front body with one clearly open body-width corridor starts the
	# bypass before physical contact. The side gate closes only the positive
	# corridor, so the first fixed tick must already select the negative route.
	var early_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	early_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var early_origin := Vector2(142.0, 0.0)
	var early_front := _enemy(static_small_definition, avatar, topology, Vector2(100.0, 0.0))
	var early_chase_direction := topology.shortest_delta(early_origin, avatar.global_position).normalized()
	var early_positive_direction := (
		early_chase_direction * EnemyWorld.DIRECT_COLLISION_BYPASS_FORWARD_WEIGHT
		+ early_chase_direction.orthogonal() * EnemyWorld.DIRECT_COLLISION_BYPASS_LATERAL_WEIGHT
	).normalized()
	var early_gate := _enemy(
		static_small_definition,
		avatar,
		topology,
		early_origin + early_positive_direction * 48.0
	)
	var early_follower := _enemy(small_definition, avatar, topology, early_origin)
	_true(EntityHandle.is_valid(early_world.register_enemy(early_front)), "Der frühe Vorderkörper erhält einen Handle")
	_true(EntityHandle.is_valid(early_world.register_enemy(early_gate)), "Das frühe Korridortor erhält einen Handle")
	var early_handle := early_world.register_enemy(early_follower)
	_true(EntityHandle.is_valid(early_handle), "Der frühe Verfolger erhält einen Handle")
	var early_before := early_follower.global_position
	early_world.step_fixed(1.0 / 60.0)
	var early_slot := EntityHandle.slot(early_handle)
	var early_corridor_offset := early_slot * 2
	var early_step := topology.shortest_delta(early_before, early_follower.global_position)
	_true(
		int(early_world._direct_collision_corridor_open[early_corridor_offset])
			+ int(early_world._direct_collision_corridor_open[early_corridor_offset + 1]) == 1,
		"Der frühe Test besitzt genau einen freien Körperkorridor"
	)
	_true(early_world._crowd_lane_signs[early_slot] == -1, "Der freie Seitenkorridor wird bereits vor Körperkontakt geleast")
	_true(
		int(early_world._direct_collision_corridor_epochs[early_slot])
			== early_world._direct_collision_prepare_epoch,
		"Eine neue Seitenlease beruht auf dem Corridor-Snapshot desselben Fixed Ticks"
	)
	_true(absf(early_step.cross(early_chase_direction)) > 0.5, "Der frühe Bypass erzeugt im ersten Tick sichtbare Seitenbewegung")
	_true(early_step.dot(early_chase_direction) > 0.0, "Der frühe Bypass behält Vorwärtsfortschritt zum Doctor")
	for blocker in [early_front, early_gate]:
		var early_margin: float = (
			topology.distance(early_follower.global_position, blocker.global_position)
			- early_follower.contact_body_radius()
			- blocker.contact_body_radius()
		)
		_true(early_margin >= -0.06, "Der frühe Bypass wahrt die Schadenshitboxen (Margin %.3f)" % early_margin)
	early_world.clear()
	early_front.free()
	early_gate.free()
	early_follower.free()

	var wedge_upper := _enemy(static_small_definition, avatar, topology, Vector2(72.0, -26.0))
	var wedge_lower := _enemy(static_small_definition, avatar, topology, Vector2(72.0, 26.0))
	var wedge_follower := _enemy(small_definition, avatar, topology, Vector2(120.0, 0.0))
	_true(EntityHandle.is_valid(wedge_world.register_enemy(wedge_upper)), "Oberer Keilkörper erhält einen Handle")
	_true(EntityHandle.is_valid(wedge_world.register_enemy(wedge_lower)), "Unterer Keilkörper erhält einen Handle")
	var wedge_follower_handle := wedge_world.register_enemy(wedge_follower)
	_true(EntityHandle.is_valid(wedge_follower_handle), "Keilverfolger erhält einen Handle")
	var wedge_start_distance := topology.distance(wedge_follower.global_position, avatar.global_position)
	var wedge_maximum_lateral := 0.0
	var wedge_lateral_sign := 0
	var wedge_lateral_sign_flips := 0
	var wedge_maximum_retreat := 0.0
	var wedge_minimum_margin := INF
	for _tick in range(300):
		var before_position := wedge_follower.global_position
		var before_distance := topology.distance(before_position, avatar.global_position)
		var before_target_direction := topology.shortest_delta(before_position, avatar.global_position).normalized()
		wedge_world.step_fixed(1.0 / 60.0)
		var wedge_step := topology.shortest_delta(before_position, wedge_follower.global_position)
		var wedge_lateral_step := wedge_step.cross(before_target_direction)
		if absf(wedge_lateral_step) > 0.01:
			var lateral_sign := 1 if wedge_lateral_step > 0.0 else -1
			if wedge_lateral_sign != 0 and lateral_sign != wedge_lateral_sign:
				wedge_lateral_sign_flips += 1
			wedge_lateral_sign = lateral_sign
		wedge_maximum_lateral = maxf(wedge_maximum_lateral, absf(wedge_follower.global_position.y))
		wedge_maximum_retreat = maxf(
			wedge_maximum_retreat,
			topology.distance(wedge_follower.global_position, avatar.global_position) - before_distance
		)
		for blocker in [wedge_upper, wedge_lower]:
			wedge_minimum_margin = minf(
				wedge_minimum_margin,
				topology.distance(wedge_follower.global_position, blocker.global_position)
					- wedge_follower.contact_body_radius()
					- blocker.contact_body_radius()
			)
	_true(wedge_minimum_margin >= -0.06, "Der Mehrfachkontakt hält weiterhin exakt die Schadenshitboxen (Margin %.3f)" % wedge_minimum_margin)
	_true(wedge_maximum_retreat <= 0.001, "Der geometrische Ausweg erzeugt keine Rückwärtsbewegung (%.5f)" % wedge_maximum_retreat)
	_true(wedge_maximum_lateral > 1.0, "Der Keilverfolger nutzt einen sichtbaren, lokalen Bogen (%.2f)" % wedge_maximum_lateral)
	_true(wedge_lateral_sign_flips <= 1, "Ein bestehender Knubbel erzeugt kein wiederholtes Links-Rechts-Wackeln (%d Wechsel)" % wedge_lateral_sign_flips)
	_true(
		topology.distance(wedge_follower.global_position, avatar.global_position) <= wedge_start_distance - 20.0,
		"Der Keilverfolger verfolgt bis an die echte Körpergrenze und stockt erst dort (%.2f -> %.2f)" % [wedge_start_distance, topology.distance(wedge_follower.global_position, avatar.global_position)]
	)
	wedge_world.clear()
	wedge_upper.free()
	wedge_lower.free()
	wedge_follower.free()

	# A body inside a closed six-body shell has no body-width side corridor. It
	# queues geometrically instead of inventing a lateral bypass.
	var enclosed_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	enclosed_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var enclosed_origin := Vector2(160.0, 0.0)
	var enclosed_blockers: Array[InfectionEnemy] = []
	for index in range(6):
		var blocker := _enemy(
			static_small_definition,
			avatar,
			topology,
			enclosed_origin + Vector2.from_angle(TAU * float(index) / 6.0) * 34.05
		)
		enclosed_blockers.append(blocker)
		_true(EntityHandle.is_valid(enclosed_world.register_enemy(blocker)), "Hüllkörper %d erhält einen Handle" % (index + 1))
	var enclosed := _enemy(small_definition, avatar, topology, enclosed_origin)
	var enclosed_handle := enclosed_world.register_enemy(enclosed)
	_true(EntityHandle.is_valid(enclosed_handle), "Der innere Verfolger erhält einen Handle")
	var enclosed_maximum_drift := 0.0
	var enclosed_lateral_travel := 0.0
	var enclosed_maximum_retreat := 0.0
	var enclosed_lane_lease_ticks := 0
	var enclosed_trigger_switches := 0
	var enclosed_last_trigger := EntityHandle.INVALID
	for _tick in range(90):
		var before_position := enclosed.global_position
		var before_distance := topology.distance(before_position, avatar.global_position)
		enclosed_world.step_fixed(1.0 / 60.0)
		var step := topology.shortest_delta(before_position, enclosed.global_position)
		var target_direction := topology.shortest_delta(before_position, avatar.global_position).normalized()
		enclosed_lateral_travel += absf(step.cross(target_direction))
		enclosed_maximum_drift = maxf(enclosed_maximum_drift, topology.distance(enclosed_origin, enclosed.global_position))
		enclosed_maximum_retreat = maxf(
			enclosed_maximum_retreat,
			topology.distance(enclosed.global_position, avatar.global_position) - before_distance
		)
		var enclosed_slot_during_wait := EntityHandle.slot(enclosed_handle)
		if enclosed_world._crowd_lane_signs[enclosed_slot_during_wait] != 0:
			enclosed_lane_lease_ticks += 1
		var enclosed_trigger := int(enclosed_world._direct_collision_corridor_blockers[enclosed_slot_during_wait])
		if EntityHandle.is_valid(enclosed_trigger):
			if EntityHandle.is_valid(enclosed_last_trigger) and enclosed_trigger != enclosed_last_trigger:
				enclosed_trigger_switches += 1
			enclosed_last_trigger = enclosed_trigger
	_true(enclosed_lateral_travel <= 0.001, "Ein innerer Gegner erzeugt keine absichtliche Seitenbewegung (%.5f)" % enclosed_lateral_travel)
	_true(enclosed_maximum_drift <= 0.01, "Ein vollständig umschlossener Gegner wartet geometrisch (%.5f)" % enclosed_maximum_drift)
	_true(enclosed_maximum_retreat <= 0.001, "Auch ein umschlossener Gegner läuft nie vom Doctor weg (%.5f)" % enclosed_maximum_retreat)
	_true(enclosed_lane_lease_ticks == 0, "Ein geschlossener Pulk erfindet in keinem Tick eine Bypassseite")
	_true(enclosed_trigger_switches == 0, "Ein wartender Gegner wechselt seinen Vorderkörper nicht und wackelt nicht")
	var enclosed_slot := EntityHandle.slot(enclosed_handle)
	_true(enclosed_world._crowd_lane_signs[enclosed_slot] == 0, "Ohne freien Korridor wird keine Bypassseite geleast")
	var enclosed_trigger_handle := int(enclosed_world._direct_collision_corridor_blockers[enclosed_slot])
	_true(EntityHandle.is_valid(enclosed_trigger_handle), "Die Warteschlange bindet ihren auslösenden Vorderkörper generationssicher")
	var release_start_distance := topology.distance(enclosed.global_position, avatar.global_position)
	_true(enclosed_world.release(enclosed_trigger_handle, false), "Der auslösende Vorderkörper kann generation-sicher freigegeben werden")
	for _tick in range(EnemyWorld.DIRECT_COLLISION_UPDATE_PHASES + 1):
		if int(enclosed_world._direct_collision_corridor_blockers[enclosed_slot]) != enclosed_trigger_handle:
			break
		enclosed_world.step_fixed(1.0 / 60.0)
	_true(
		int(enclosed_world._direct_collision_corridor_blockers[enclosed_slot]) != enclosed_trigger_handle,
		"Die phasenweise Prüfung entfernt den freigegebenen Vorderkörper generationssicher aus dem Cache"
	)
	for blocker in enclosed_blockers:
		var remaining_handle := enclosed_world.handle_for(blocker)
		if EntityHandle.is_valid(remaining_handle):
			_true(enclosed_world.release(remaining_handle, false), "Ein verbleibender Hüllkörper wird freigegeben")
	for _tick in range(EnemyWorld.DIRECT_COLLISION_UPDATE_PHASES + 2):
		enclosed_world.step_fixed(1.0 / 60.0)
	_true(
		topology.distance(enclosed.global_position, avatar.global_position) < release_start_distance - 0.5,
		"Nach Freigabe des Vorderkörpers bleibt der innere Gegner nicht im geschlossenen Cache hängen"
	)
	enclosed_world.clear()
	for blocker in enclosed_blockers:
		blocker.free()
	enclosed.free()

	# At the outer edge exactly one body-width corridor stays open. The follower
	# leases that side once, makes progress and never flips while the lease lives.
	var edge_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	edge_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var edge_origin := Vector2(160.0, 0.0)
	var edge_offsets := [
		Vector2(-36.0, 0.0),
		Vector2(36.0, 0.0),
		Vector2(-18.0, 31.177),
		Vector2(18.0, 31.177),
	]
	var edge_blockers: Array[InfectionEnemy] = []
	for index in range(edge_offsets.size()):
		var blocker := _enemy(static_small_definition, avatar, topology, edge_origin + edge_offsets[index])
		edge_blockers.append(blocker)
		_true(EntityHandle.is_valid(edge_world.register_enemy(blocker)), "Randkörper %d erhält einen Handle" % (index + 1))
	var edge_follower := _enemy(small_definition, avatar, topology, edge_origin)
	var edge_handle := edge_world.register_enemy(edge_follower)
	_true(EntityHandle.is_valid(edge_handle), "Der Randverfolger erhält einen Handle")
	var edge_slot := EntityHandle.slot(edge_handle)
	var edge_start_distance := topology.distance(edge_follower.global_position, avatar.global_position)
	var edge_maximum_lateral := 0.0
	var edge_maximum_retreat := 0.0
	var edge_lease_sign := 0
	var edge_sign_flips := 0
	var edge_open_count_at_start := -1
	var edge_minimum_margin := INF
	for _tick in range(180):
		var before_position := edge_follower.global_position
		var before_distance := topology.distance(before_position, avatar.global_position)
		edge_world.step_fixed(1.0 / 60.0)
		var lane_sign := int(edge_world._crowd_lane_signs[edge_slot])
		if lane_sign != 0:
			if edge_lease_sign == 0:
				edge_lease_sign = lane_sign
				var corridor_offset := edge_slot * 2
				edge_open_count_at_start = int(edge_world._direct_collision_corridor_open[corridor_offset]) + int(edge_world._direct_collision_corridor_open[corridor_offset + 1])
			elif lane_sign != edge_lease_sign:
				edge_sign_flips += 1
		edge_maximum_lateral = maxf(edge_maximum_lateral, absf(edge_follower.global_position.y - edge_origin.y))
		edge_maximum_retreat = maxf(
			edge_maximum_retreat,
			topology.distance(edge_follower.global_position, avatar.global_position) - before_distance
		)
		for blocker in edge_blockers:
			edge_minimum_margin = minf(
				edge_minimum_margin,
				topology.distance(edge_follower.global_position, blocker.global_position)
					- edge_follower.contact_body_radius()
					- blocker.contact_body_radius()
			)
	_true(edge_open_count_at_start == 1, "Der Randfall besitzt beim Start exakt einen freien Körperkorridor")
	_true(edge_lease_sign != 0 and edge_maximum_lateral >= 8.0, "Der Randgegner nutzt den einzigen freien Korridor (%.2f)" % edge_maximum_lateral)
	_true(edge_sign_flips == 0, "Die geleaste Randseite wechselt nicht direkt (%d Wechsel)" % edge_sign_flips)
	_true(edge_minimum_margin >= -0.06, "Der Randbogen wahrt alle Schadenshitboxen (Margin %.3f)" % edge_minimum_margin)
	_true(edge_maximum_retreat <= 0.001, "Der Randbogen erzeugt keine Fluchtbewegung (%.5f)" % edge_maximum_retreat)
	_true(
		topology.distance(edge_follower.global_position, avatar.global_position) <= edge_start_distance - 10.0,
		"Der Randgegner nähert sich durch den freien Korridor sichtbar an"
	)
	edge_world.clear()
	for blocker in edge_blockers:
		blocker.free()
	edge_follower.free()

	# Closing the leased corridor releases it before another side may be chosen.
	# Reopening the same unique edge route allows a fresh lease without a flip.
	var closing_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	closing_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var closing_blockers: Array[InfectionEnemy] = []
	for index in range(edge_offsets.size()):
		var blocker := _enemy(static_small_definition, avatar, topology, edge_origin + edge_offsets[index])
		closing_blockers.append(blocker)
		_true(EntityHandle.is_valid(closing_world.register_enemy(blocker)), "Schließkörper %d erhält einen Handle" % (index + 1))
	var corridor_gate := _enemy(static_small_definition, avatar, topology, Vector2(520.0, 320.0))
	var corridor_gate_handle := closing_world.register_enemy(corridor_gate)
	_true(EntityHandle.is_valid(corridor_gate_handle), "Das Korridortor erhält einen Handle")
	var closing_follower := _enemy(small_definition, avatar, topology, edge_origin)
	var closing_handle := closing_world.register_enemy(closing_follower)
	_true(EntityHandle.is_valid(closing_handle), "Der Schließtest-Verfolger erhält einen Handle")
	var closing_slot := EntityHandle.slot(closing_handle)
	var closing_sign := 0
	for _tick in range(90):
		closing_world.step_fixed(1.0 / 60.0)
		closing_sign = int(closing_world._crowd_lane_signs[closing_slot])
		if closing_sign != 0:
			break
	_true(closing_sign != 0, "Der Schließtest beginnt mit einer gültigen Randlease")
	var closing_direction := topology.shortest_delta(closing_follower.global_position, avatar.global_position).normalized()
	var closing_tangent := closing_direction.orthogonal()
	var leased_direction := (
		closing_direction * EnemyWorld.DIRECT_COLLISION_BYPASS_FORWARD_WEIGHT
		+ closing_tangent * EnemyWorld.DIRECT_COLLISION_BYPASS_LATERAL_WEIGHT * float(closing_sign)
	).normalized()
	var gate_previous_position := corridor_gate.global_position
	corridor_gate.global_position = closing_follower.global_position + leased_direction * 74.0
	corridor_gate.reset_visual_motion()
	_true(closing_world.mark_enemy_relocated(corridor_gate_handle, gate_previous_position), "Das geschlossene Tor aktualisiert seinen Spatial-Cache")
	closing_world.step_fixed(1.0 / 60.0)
	_true(closing_world._crowd_lane_signs[closing_slot] == 0, "Eine Relocation invalidiert benachbarte Guards sofort und gibt den geschlossenen Korridor frei")
	_true(closing_world._direct_collision_queued[closing_slot] != 0, "Ein geschlossener Randkorridor wechselt im selben Tick in den Wartezustand")
	var closed_position := closing_follower.global_position
	for _tick in range(4):
		closing_world.step_fixed(1.0 / 60.0)
		_true(closing_world._crowd_lane_signs[closing_slot] != -closing_sign, "Der geschlossene Korridor erzeugt keinen direkten Links-Rechts-Wechsel")
	var closed_drift := topology.distance(closed_position, closing_follower.global_position)
	_true(closed_drift <= 0.001, "Mit beiden Seiten geschlossen bleibt der Gegner ohne seitliches Rutschen stehen (Drift %.5f)" % closed_drift)
	gate_previous_position = corridor_gate.global_position
	corridor_gate.global_position = Vector2(520.0, 320.0)
	corridor_gate.reset_visual_motion()
	_true(closing_world.mark_enemy_relocated(corridor_gate_handle, gate_previous_position), "Das wieder geöffnete Tor aktualisiert seinen Spatial-Cache")
	for _tick in range(EnemyWorld.DIRECT_COLLISION_UPDATE_PHASES + 2):
		closing_world.step_fixed(1.0 / 60.0)
		if closing_world._crowd_lane_signs[closing_slot] != 0:
			break
	_true(closing_world._crowd_lane_signs[closing_slot] == closing_sign, "Nach Wiederöffnung wird dieselbe einzige Randseite neu geleast")
	var closing_minimum_margin := INF
	for blocker in closing_blockers + [corridor_gate]:
		closing_minimum_margin = minf(
			closing_minimum_margin,
			topology.distance(closing_follower.global_position, blocker.global_position)
				- closing_follower.contact_body_radius()
				- blocker.contact_body_radius()
		)
	_true(closing_minimum_margin >= -0.06, "Schließen und Öffnen bewahren die Schadenshitboxen (Margin %.3f)" % closing_minimum_margin)
	closing_world.clear()
	for blocker in closing_blockers:
		blocker.free()
	corridor_gate.free()
	closing_follower.free()

	# A mixed pack preserves every pair's own contact boundary. Rear bodies may
	# stop, while both enemy classes still produce visible front attackers.
	var mixed_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	mixed_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var mixed_enemies: Array[InfectionEnemy] = []
	for index in range(9):
		var definition := small_definition if index < 6 else cluster_definition
		var angle := TAU * float(index) / 9.0
		# Put one representative of both sizes on the eventual front. The test
		# validates collision geometry, not a particular spawn-order advantage.
		var radius := 150.0 + float(index % 3) * 8.0 if index < 6 else 108.0 + float(index % 3) * 8.0
		var enemy := _enemy(definition, avatar, topology, Vector2.from_angle(angle) * radius)
		if index < 6:
			enemy.pressure_applied.connect(_on_mixed_small_pressure)
		else:
			enemy.pressure_applied.connect(_on_mixed_cluster_pressure)
		mixed_enemies.append(enemy)
		_true(EntityHandle.is_valid(mixed_world.register_enemy(enemy)), "Gemischter Verfolger %d erhält einen Handle" % (index + 1))
	var mixed_minimum_margin := INF
	var mixed_minimum_pair := Vector2i(-1, -1)
	var mixed_minimum_tick := -1
	var mixed_maximum_retreat := 0.0
	for tick in range(420):
		var distances_before := PackedFloat32Array()
		for enemy in mixed_enemies:
			distances_before.append(topology.distance(enemy.global_position, avatar.global_position))
		mixed_world.step_fixed(1.0 / 60.0)
		for index in range(mixed_enemies.size()):
			mixed_maximum_retreat = maxf(
				mixed_maximum_retreat,
				topology.distance(mixed_enemies[index].global_position, avatar.global_position) - distances_before[index]
			)
		for first_index in range(mixed_enemies.size()):
			for second_index in range(first_index + 1, mixed_enemies.size()):
				var required := mixed_enemies[first_index].contact_body_radius() + mixed_enemies[second_index].contact_body_radius()
				var margin := topology.distance(mixed_enemies[first_index].global_position, mixed_enemies[second_index].global_position) - required
				if margin < mixed_minimum_margin:
					mixed_minimum_margin = margin
					mixed_minimum_pair = Vector2i(first_index, second_index)
					mixed_minimum_tick = tick
	_true(mixed_minimum_margin >= -0.06, "Gemischte Gegner überlappen ihre individuellen Schadenshitboxen nicht (Margin %.3f, Tick %d, Paar %s)" % [mixed_minimum_margin, mixed_minimum_tick, mixed_minimum_pair])
	_true(mixed_maximum_retreat <= 0.001, "Der gemischte Pulk erzeugt keine Rückwärtsbewegung (%.5f)" % mixed_maximum_retreat)
	_true(mixed_small_hits > 0, "Mindestens ein kleines Bakterium erreicht und trifft den Doctor")
	_true(mixed_cluster_hits > 0, "Mindestens eine rote Bakteriengruppe erreicht und trifft den Doctor")

	# Explicit knockback remains the only intentional distance increase.
	mixed_world.clear()
	for enemy in mixed_enemies:
		enemy.free()
	var knockback_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	knockback_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var knocked := _enemy(small_definition, avatar, topology, Vector2(80.0, 0.0))
	_true(EntityHandle.is_valid(knockback_world.register_enemy(knocked)), "Rückstoßgegner erhält einen Handle")
	knocked.apply_knockback(Vector2.RIGHT, 45.0, 0.28, 1.0)
	var knockback_origin_distance := topology.distance(knocked.global_position, avatar.global_position)
	for _tick in range(18):
		knockback_world.step_fixed(1.0 / 60.0)
	var knocked_distance := topology.distance(knocked.global_position, avatar.global_position)
	_true(knocked_distance > knockback_origin_distance + 30.0, "Nur expliziter Rückstoß bewegt einen Gegner sichtbar vom Doctor weg")
	_true(knocked.is_stunned(), "Rückstoß betäubt den Gegner weiterhin")
	for _tick in range(72):
		knockback_world.step_fixed(1.0 / 60.0)
	_true(not knocked.is_stunned(), "Betäubung endet weiterhin nach einer Sekunde")
	_true(topology.distance(knocked.global_position, avatar.global_position) < knocked_distance, "Nach Betäubung verfolgt der Gegner sofort wieder den Doctor")
	knockback_world.clear()
	knocked.free()

	# Doctor Milos uses the same damage-contact circles as physical boundaries.
	# Large bodies hard-block; small bacteria yield slowly without a status slow.
	avatar.global_position = Vector2.ZERO
	avatar.input_enabled = true
	var hard_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	hard_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var static_cluster_definition := EnemyDefinition.create(
		&"bacterial_cluster", "Statische Bakteriengruppe", 74.0, 0.0, 0.0, 0, 30.0, Color.WHITE
	).configure_contact_radius(23.0)
	var hard_cluster := _enemy(
		static_cluster_definition,
		avatar,
		topology,
		Vector2(TherapyAvatar.CONTACT_RADIUS + 23.2, 0.0)
	)
	_true(EntityHandle.is_valid(hard_world.register_enemy(hard_cluster)), "Harter Spielerkörper erhält einen Handle")
	hard_world.step_fixed(1.0 / 60.0)
	Input.action_press(&"move_right")
	for _tick in range(30):
		hard_world.prepare_avatar_body_interaction(1.0 / 60.0)
		avatar.step_fixed(1.0 / 60.0)
	Input.action_release(&"move_right")
	_true(avatar.global_position.x <= 0.25, "Eine rote Bakteriengruppe blockiert den Doctor an ihrer sichtbaren Schadenshitbox (%.3f)" % avatar.global_position.x)
	_true(hard_cluster.global_position.is_equal_approx(Vector2(TherapyAvatar.CONTACT_RADIUS + 23.2, 0.0)), "Ein harter Körper wird vom Spieler nicht verschoben")
	hard_world.clear()
	hard_cluster.free()

	avatar.global_position = Vector2.ZERO
	var push_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	push_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var push_definition := EnemyDefinition.create(
		&"pneumococcus", "Schiebbares Bakterium", 22.0, 0.0, 0.0, 0, 18.0, Color.WHITE
	).configure_contact_radius(17.0)
	var pushed_small := _enemy(
		push_definition,
		avatar,
		topology,
		Vector2(TherapyAvatar.CONTACT_RADIUS + 17.2, 0.0)
	)
	var pushed_handle := push_world.register_enemy(pushed_small)
	_true(EntityHandle.is_valid(pushed_handle), "Schiebbares kleines Bakterium erhält einen Handle")
	push_world.step_fixed(1.0 / 60.0)
	var small_origin := pushed_small.global_position
	Input.action_press(&"move_right")
	for _tick in range(30):
		push_world.prepare_avatar_body_interaction(1.0 / 60.0)
		avatar.step_fixed(1.0 / 60.0)
	Input.action_release(&"move_right")
	_true(avatar.global_position.x > 5.0 and avatar.global_position.x < 40.0, "Der Doctor arbeitet sich physisch, aber nicht mit vollem Galopp durch kleine Bakterien (%.2f)" % avatar.global_position.x)
	_true(pushed_small.global_position.x > small_origin.x + 5.0, "Das kleine Bakterium wird über mehrere Ticks sichtbar weggedrückt")
	_true(
		pushed_small.global_position.distance_to(avatar.global_position) >= TherapyAvatar.CONTACT_RADIUS + pushed_small.contact_body_radius() - 0.1,
		"Spieler und kleines Bakterium unterschreiten beim Schieben nie ihre Schadenshitboxgrenze"
	)
	_true(not pushed_small.is_stunned(), "Normales Spielerschieben betäubt kleine Bakterien nicht")

	# Off-screen relocation owns no respawn semantics and is locked immediately
	# after damage. Game adds ranged/tutorial exclusions before calling this API.
	pushed_small.take_damage(1.0, &"relocation_contract")
	var preserved_health := pushed_small.health
	_true(pushed_small.is_recently_interacted() and not pushed_small.can_be_relocated(), "Ein kürzlich getroffener Gegner ist nicht versetzbar")
	pushed_small.step_fixed(InfectionEnemy.RELOCATION_INTERACTION_LOCK_SECONDS + 0.01)
	_true(pushed_small.can_be_relocated(), "Der reine Interaktionsschutz läuft deterministisch aus")
	var relocation_target := Vector2(-240.0, 180.0)
	_true(pushed_small.relocate_preserving_state(relocation_target), "Ein normaler off-screen Gegner kann ohne Respawn versetzt werden")
	_true(pushed_small.health == preserved_health, "Versetzen erhält das aktuelle Leben")
	_true(pushed_small.global_position.is_equal_approx(relocation_target), "Versetzen übernimmt die neue Position atomar")
	_true(push_world.mark_enemy_relocated(pushed_handle), "EnemyWorld verwirft nach Versetzen den lokalen Bypasszustand")
	_true(not pushed_small.can_be_relocated(), "Ein gerade versetzter Gegner bleibt für das nächste Directorfenster gesperrt")
	pushed_small.step_fixed(InfectionEnemy.RELOCATION_POST_MOVE_LOCK_SECONDS + 0.01)
	_true(pushed_small.can_be_relocated(), "Der separate Schutz nach echtem Versetzen läuft deterministisch aus")
	push_world.clear()
	pushed_small.free()
	avatar.input_enabled = false
	avatar.free()
	for action in added_input_actions:
		InputMap.erase_action(action)
	if failures == 0:
		print("ALVEOLUS_CROWD_COLLISION_STUN_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_CROWD_COLLISION_STUN_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)


func _enemy(
	definition: EnemyDefinition,
	avatar: TherapyAvatar,
	topology: ArenaTopology,
	position: Vector2
) -> InfectionEnemy:
	var enemy := InfectionEnemy.new()
	enemy.configure(definition, avatar, topology)
	enemy.spawn_timer = 0.0
	enemy.global_position = position
	enemy.reset_visual_motion()
	return enemy


func _assert_at_contact(enemy: InfectionEnemy, avatar: TherapyAvatar, topology: ArenaTopology, label: String) -> void:
	var distance := topology.distance(enemy.global_position, avatar.global_position)
	var expected := TherapyAvatar.CONTACT_RADIUS + enemy.contact_body_radius()
	_true(distance <= expected + 0.05, "%s erreicht den Schadenskontakt (%.2f / %.2f)" % [label, distance, expected])
	_true(distance >= expected - 0.65, "%s läuft nicht durch Doctor Milos hindurch (%.2f / %.2f)" % [label, distance, expected])


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)


func _on_small_pressure(_amount: float) -> void:
	small_hits += 1


func _on_cluster_pressure(_amount: float) -> void:
	cluster_hits += 1


func _on_front_pressure(_amount: float) -> void:
	front_hits += 1


func _on_blocked_pressure(_amount: float) -> void:
	blocked_hits += 1


func _on_offset_pressure(_amount: float) -> void:
	offset_hits += 1


func _on_mixed_small_pressure(_amount: float) -> void:
	mixed_small_hits += 1


func _on_mixed_cluster_pressure(_amount: float) -> void:
	mixed_cluster_hits += 1


func _on_boss_pressure(_amount: float) -> void:
	boss_hits += 1
