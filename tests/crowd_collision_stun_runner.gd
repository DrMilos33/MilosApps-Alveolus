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
var edge_hits := 0
var stationary_contact_ids: Dictionary = {}


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
	_assert_at_contact(blocked, avatar, topology, "Umlaufende rote Bakteriengruppe")
	_true(blocked_hits > 0, "Der Hinterkörper erreicht den Doctor ohne manuelle Freigabe")
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
	var slide_front_handle := slide_world.register_enemy(slide_front)
	_true(EntityHandle.is_valid(slide_front_handle), "Seitlicher Blocker erhält einen Handle")
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
	var slider_before_release := slider.global_position
	_true(slide_world.release(slide_front_handle, false), "Der seitliche Vorderkörper wird generationssicher freigegeben")
	slide_world.step_fixed(1.0 / 60.0)
	var slider_release_direction := topology.shortest_delta(slider_before_release, avatar.global_position).normalized()
	var slider_release_step := topology.shortest_delta(slider_before_release, slider.global_position)
	_true(slider_release_step.dot(slider_release_direction) > 0.0, "Der seitlich blockierte Gegner wacht nach Freigabe direkt auf")
	_true(absf(slider_release_step.cross(slider_release_direction)) <= 0.001, "Nach Freigabe endet der Bypass ohne Nachschwingen")
	for _tick in range(180):
		slide_world.step_fixed(1.0 / 60.0)
	_true(offset_hits > 0, "Der freigegebene Gegner erreicht danach den Doctor")
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
	_true(wedge_maximum_lateral <= 0.001, "Ohne vollständig verifizierten Seitenkorridor erfindet der Keilverfolger keinen Bogen (%.5f)" % wedge_maximum_lateral)
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
	enclosed_world.set_crowd_profile_enabled(true)
	enclosed_world.reset_crowd_profile_counters()
	for _tick in range(EnemyWorld.DIRECT_COLLISION_UPDATE_PHASES):
		enclosed_world.step_fixed(1.0 / 60.0)
	var enclosed_profile := enclosed_world.crowd_profile_snapshot()
	_true(
		enclosed_profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES] <= enclosed_blockers.size() + 1,
		"Der wartende Innenkörper verwendet seinen validierten Cache statt einer zusätzlichen Vollabfrage (%d / %d)" % [
			enclosed_profile[EnemyWorld.CrowdProfileCounter.GUARD_QUERIES],
			enclosed_blockers.size(),
		]
	)
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
	edge_follower.pressure_applied.connect(_on_edge_pressure)
	var edge_handle := edge_world.register_enemy(edge_follower)
	_true(EntityHandle.is_valid(edge_handle), "Der Randverfolger erhält einen Handle")
	var edge_slot := EntityHandle.slot(edge_handle)
	var edge_start_distance := topology.distance(edge_follower.global_position, avatar.global_position)
	var edge_maximum_lateral := 0.0
	var edge_maximum_retreat := 0.0
	var edge_lease_sign := 0
	var edge_sign_flips := 0
	var edge_open_count_at_start := -1
	var edge_first_lease_tick := -1
	var edge_first_attack_tick := -1
	var edge_minimum_margin := INF
	for _tick in range(360):
		var before_position := edge_follower.global_position
		var before_distance := topology.distance(before_position, avatar.global_position)
		edge_world.step_fixed(1.0 / 60.0)
		var lane_sign := int(edge_world._crowd_lane_signs[edge_slot])
		if lane_sign != 0:
			if edge_lease_sign == 0:
				edge_lease_sign = lane_sign
				edge_first_lease_tick = _tick
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
		if edge_hits > 0 and edge_first_attack_tick < 0:
			edge_first_attack_tick = _tick
	_true(edge_open_count_at_start == 1, "Der Randfall besitzt beim Start exakt einen freien Körperkorridor")
	_true(
		edge_first_lease_tick >= 0 and edge_first_lease_tick < EnemyWorld.DIRECT_COLLISION_UPDATE_PHASES,
		"Der freie Randkorridor wird innerhalb eines verteilten Guard-Zyklus aktiv (%d Ticks)" % edge_first_lease_tick
	)
	_true(edge_lease_sign != 0 and edge_maximum_lateral >= 8.0, "Der Randgegner nutzt den einzigen freien Korridor (%.2f)" % edge_maximum_lateral)
	_true(edge_sign_flips == 0, "Die geleaste Randseite wechselt nicht direkt (%d Wechsel)" % edge_sign_flips)
	_true(edge_minimum_margin >= -0.06, "Der Randbogen wahrt alle Schadenshitboxen (Margin %.3f)" % edge_minimum_margin)
	_true(edge_maximum_retreat <= 0.001, "Der Randbogen erzeugt keine Fluchtbewegung (%.5f)" % edge_maximum_retreat)
	_assert_at_contact(edge_follower, avatar, topology, "Randgegner mit freiem Korridor")
	_true(
		edge_first_attack_tick >= 0 and edge_first_attack_tick <= 300,
		"Der Randgegner erreicht den Doctor ohne manuelle Freigabe (Tick %d)" % edge_first_attack_tick
	)
	_true(edge_hits > 0, "Der Randgegner greift nach seinem freien Bogen an")
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
	var closed_position := closing_follower.global_position
	var closed_start_distance := topology.distance(closed_position, avatar.global_position)
	var closed_lateral_travel := 0.0
	var closed_maximum_retreat := 0.0
	for _tick in range(4):
		var before_position := closing_follower.global_position
		var before_distance := topology.distance(before_position, avatar.global_position)
		var direct_direction := topology.shortest_delta(before_position, avatar.global_position).normalized()
		closing_world.step_fixed(1.0 / 60.0)
		var closed_step := topology.shortest_delta(before_position, closing_follower.global_position)
		closed_lateral_travel += absf(closed_step.cross(direct_direction))
		closed_maximum_retreat = maxf(
			closed_maximum_retreat,
			topology.distance(closing_follower.global_position, avatar.global_position) - before_distance
		)
		_true(closing_world._crowd_lane_signs[closing_slot] != -closing_sign, "Der geschlossene Korridor erzeugt keinen direkten Links-Rechts-Wechsel")
	var closed_drift := topology.distance(closed_position, closing_follower.global_position)
	_true(closed_lateral_travel <= 0.001, "Mit beiden Seiten geschlossen bleibt die Verfolgung bis zum echten Körperkontakt geradlinig (seitlich %.5f)" % closed_lateral_travel)
	_true(closed_maximum_retreat <= 0.001, "Ein geschlossener Korridor erzeugt keine Fluchtbewegung (%.5f)" % closed_maximum_retreat)
	_true(
		closed_drift > 0.1
			and topology.distance(closing_follower.global_position, avatar.global_position) < closed_start_distance,
		"Ein entfernter geschlossener Cache stoppt den Gegner nicht vor der echten Körpergrenze (Fortschritt %.3f)" % closed_drift
	)
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

	# A queued rear follower may acquire a new physical front body while its last
	# closed corridor sample still belongs to another living body. That stale
	# identity must wake the scheduled refresh instead of sleeping forever.
	var cache_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	cache_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var cache_follower_position := Vector2(180.0, 0.0)
	var cache_follower := _enemy(small_definition, avatar, topology, cache_follower_position)
	var cache_queue_blocker := _enemy(
		static_small_definition,
		avatar,
		topology,
		cache_follower_position + Vector2.LEFT * (
			small_definition.contact_radius
			+ static_small_definition.contact_radius
			+ EnemyWorld.DIRECT_COLLISION_SKIN
		)
	)
	var cache_corridor_blocker := _enemy(
		static_small_definition,
		avatar,
		topology,
		Vector2(520.0, 320.0)
	)
	var cache_positive_direction := (
		Vector2.LEFT * EnemyWorld.DIRECT_COLLISION_BYPASS_FORWARD_WEIGHT
		+ Vector2.LEFT.orthogonal() * EnemyWorld.DIRECT_COLLISION_BYPASS_LATERAL_WEIGHT
	).normalized()
	var cache_negative_direction := (
		Vector2.LEFT * EnemyWorld.DIRECT_COLLISION_BYPASS_FORWARD_WEIGHT
		- Vector2.LEFT.orthogonal() * EnemyWorld.DIRECT_COLLISION_BYPASS_LATERAL_WEIGHT
	).normalized()
	var cache_positive_side := _enemy(
		static_small_definition,
		avatar,
		topology,
		cache_follower_position + cache_positive_direction * 18.0
	)
	var cache_negative_side := _enemy(
		static_small_definition,
		avatar,
		topology,
		cache_follower_position + cache_negative_direction * 18.0
	)
	var cache_queue_handle := cache_world.register_enemy(cache_queue_blocker)
	var cache_corridor_handle := cache_world.register_enemy(cache_corridor_blocker)
	var cache_positive_handle := cache_world.register_enemy(cache_positive_side)
	var cache_negative_handle := cache_world.register_enemy(cache_negative_side)
	var cache_follower_handle := cache_world.register_enemy(cache_follower)
	_true(EntityHandle.is_valid(cache_queue_handle), "Der aktuelle Queue-Blocker erhält einen Handle")
	_true(EntityHandle.is_valid(cache_corridor_handle), "Der veraltete Korridor-Blocker bleibt als lebender Handle reproduzierbar")
	_true(EntityHandle.is_valid(cache_positive_handle) and EntityHandle.is_valid(cache_negative_handle), "Beide geschlossenen Cache-Seiten besitzen lebende Blocker")
	_true(EntityHandle.is_valid(cache_follower_handle), "Der Cachewechsel-Verfolger erhält einen Handle")
	var cache_follower_slot := EntityHandle.slot(cache_follower_handle)
	var cache_corridor_offset := cache_follower_slot * 2
	cache_world._direct_collision_queue_blockers[cache_follower_slot] = cache_queue_handle
	cache_world._direct_collision_corridor_blockers[cache_follower_slot] = cache_corridor_handle
	cache_world._direct_collision_corridor_directions[cache_follower_slot] = Vector2.LEFT
	cache_world._direct_collision_corridor_open[cache_corridor_offset] = 0
	cache_world._direct_collision_corridor_open[cache_corridor_offset + 1] = 0
	cache_world._direct_collision_corridor_side_blockers[cache_corridor_offset] = cache_positive_handle
	cache_world._direct_collision_corridor_side_blockers[cache_corridor_offset + 1] = cache_negative_handle
	_true(
		cache_world._queued_blocker_still_at_contact(cache_follower_slot, cache_follower),
		"Der neue direkte Queue-Blocker liegt tatsächlich an der Körpergrenze"
	)
	_true(
		not cache_world._cached_closed_queue_still_blocked(cache_follower_slot, cache_follower),
		"Ein geschlossener Cache für einen anderen Körper darf den verteilten Refresh nicht überspringen"
	)
	for cache_handle in [
		cache_queue_handle,
		cache_corridor_handle,
		cache_positive_handle,
		cache_negative_handle,
		cache_follower_handle,
	]:
		cache_world._crowd_motion_guards[EntityHandle.slot(int(cache_handle))] = 1
	cache_world._direct_collision_queued[cache_follower_slot] = 1
	cache_world._crowd_lane_signs[cache_follower_slot] = 0
	cache_world._crowd_phase = posmod(
		cache_follower_slot,
		EnemyWorld.DIRECT_COLLISION_UPDATE_PHASES
	)
	cache_world._prepare_direct_collision_guards()
	_true(
		int(cache_world._direct_collision_corridor_blockers[cache_follower_slot])
			!= int(cache_corridor_handle),
		"Der vorgesehene Slot-Takt ersetzt den lebenden, aber veralteten Korridor-Blocker"
	)
	cache_world.clear()
	cache_follower.free()
	cache_queue_blocker.free()
	cache_corridor_blocker.free()
	cache_positive_side.free()
	cache_negative_side.free()

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
	var mixed_initial_distances := PackedFloat32Array()
	for enemy in mixed_enemies:
		mixed_initial_distances.append(topology.distance(enemy.global_position, avatar.global_position))
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
	var mixed_front_margin := INF
	for index in range(mixed_enemies.size()):
		mixed_front_margin = minf(
			mixed_front_margin,
			topology.distance(mixed_enemies[index].global_position, avatar.global_position)
				- mixed_enemies[index].contact_body_radius()
				- TherapyAvatar.CONTACT_RADIUS
		)
		_true(
			topology.distance(mixed_enemies[index].global_position, avatar.global_position)
				< float(mixed_initial_distances[index]),
			"Jeder gemischte Verfolger beendet die Probe näher am Doctor (%d)" % index
		)
	_true(
		mixed_small_hits + mixed_cluster_hits > 0,
		"Der frühere stabile Pulk führt einen physisch freien Vorderkörper bis zum Doctor (klein %d, Gruppe %d, nächste Kontaktmarge %.3f)" % [mixed_small_hits, mixed_cluster_hits, mixed_front_margin]
	)

	# A one-sided dense pack against a stationary Doctor must keep feeding its
	# physically open frontier instead of freezing the complete rear mass.
	stationary_contact_ids.clear()
	var stationary_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	stationary_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	stationary_world.set_crowd_profile_enabled(true)
	var stationary_enemies: Array[InfectionEnemy] = []
	var stationary_initial_distances := PackedFloat32Array()
	var stationary_late_travel := PackedFloat32Array()
	var stationary_removed := PackedByteArray()
	var lattice_spacing := 34.4
	var lattice_column_spacing := lattice_spacing * 0.8660254
	for column in range(10):
		for row in range(8):
			var position := Vector2(
				110.0 + float(column) * lattice_column_spacing,
				(float(row) - 3.5) * lattice_spacing + (0.5 * lattice_spacing if posmod(column, 2) != 0 else 0.0)
			)
			var enemy := _enemy(small_definition, avatar, topology, position)
			enemy.pressure_applied.connect(_on_stationary_pressure.bind(enemy.get_instance_id()))
			stationary_enemies.append(enemy)
			stationary_initial_distances.append(topology.distance(position, avatar.global_position))
			stationary_late_travel.append(0.0)
			stationary_removed.append(0)
			_true(EntityHandle.is_valid(stationary_world.register_enemy(enemy)), "Stationärer Verfolger %d erhält einen Handle" % stationary_enemies.size())
	var stationary_minimum_margin := INF
	var stationary_maximum_retreat := 0.0
	var stationary_release_count := 0
	var stationary_pre_release_progressed := 0
	var stationary_pre_release_contactors := 0
	for tick in range(720):
		var before_positions := PackedVector2Array()
		var before_distances := PackedFloat32Array()
		for enemy in stationary_enemies:
			before_positions.append(enemy.global_position)
			before_distances.append(topology.distance(enemy.global_position, avatar.global_position))
		stationary_world.step_fixed(1.0 / 60.0)
		for index in range(stationary_enemies.size()):
			if stationary_removed[index] != 0:
				continue
			var travelled := topology.distance(before_positions[index], stationary_enemies[index].global_position)
			if tick >= 360:
				stationary_late_travel[index] += travelled
			stationary_maximum_retreat = maxf(
				stationary_maximum_retreat,
				topology.distance(stationary_enemies[index].global_position, avatar.global_position)
					- float(before_distances[index])
			)
		for first_index in range(stationary_enemies.size()):
			if stationary_removed[first_index] != 0:
				continue
			for second_index in range(first_index + 1, stationary_enemies.size()):
				if stationary_removed[second_index] != 0:
					continue
				var stationary_margin := (
					topology.distance(
						stationary_enemies[first_index].global_position,
						stationary_enemies[second_index].global_position
					)
						- stationary_enemies[first_index].contact_body_radius()
						- stationary_enemies[second_index].contact_body_radius()
				)
				stationary_minimum_margin = minf(stationary_minimum_margin, stationary_margin)
		if tick == 359:
			for index in range(stationary_enemies.size()):
				var distance_before_releases := topology.distance(
					stationary_enemies[index].global_position,
					avatar.global_position
				)
				if distance_before_releases <= float(stationary_initial_distances[index]) - 20.0:
					stationary_pre_release_progressed += 1
			stationary_pre_release_contactors = stationary_contact_ids.size()
		# After the no-release window has filled the physical contact shell, simulate
		# the normal combat loop removing roughly one front attacker per second. Each
		# opened place must pull a new body out of the rear pack without repositioning.
		if tick >= 360 and posmod(tick - 360, 60) == 0:
			var release_index := -1
			var release_distance := INF
			for index in range(stationary_enemies.size()):
				if stationary_removed[index] != 0:
					continue
				var handle := stationary_world.handle_for(stationary_enemies[index])
				if not EntityHandle.is_valid(handle):
					continue
				var distance := topology.distance(
					stationary_enemies[index].global_position,
					avatar.global_position
				)
				var contact_distance := (
					TherapyAvatar.CONTACT_RADIUS
					+ stationary_enemies[index].contact_body_radius()
				)
				if distance <= contact_distance + 0.25 and distance < release_distance:
					release_index = index
					release_distance = distance
			if release_index >= 0:
				var release_handle := stationary_world.handle_for(stationary_enemies[release_index])
				if stationary_world.release(release_handle, false):
					stationary_removed[release_index] = 1
					stationary_release_count += 1
	var stationary_progressed := 0
	var stationary_late_movers := 0
	var stationary_sectors := PackedByteArray()
	stationary_sectors.resize(12)
	stationary_sectors.fill(0)
	for index in range(stationary_enemies.size()):
		var enemy := stationary_enemies[index]
		var final_distance := topology.distance(enemy.global_position, avatar.global_position)
		if final_distance <= float(stationary_initial_distances[index]) - 20.0:
			stationary_progressed += 1
		if float(stationary_late_travel[index]) >= 8.0:
			stationary_late_movers += 1
		if stationary_removed[index] == 0 and final_distance <= 240.0:
			var angle := topology.shortest_delta(avatar.global_position, enemy.global_position).angle()
			var sector := posmod(int(floor((angle + PI) / TAU * 12.0)), 12)
			stationary_sectors[sector] = 1
	var stationary_sector_count := 0
	for occupied in stationary_sectors:
		stationary_sector_count += int(occupied)
	_true(stationary_minimum_margin >= -0.06, "Der stationäre dichte Pulk wahrt alle Schadenskontakthitboxen (Margin %.3f)" % stationary_minimum_margin)
	_true(stationary_maximum_retreat <= 0.001, "Der stationäre dichte Pulk erzeugt keine Fluchtbewegung (%.5f)" % stationary_maximum_retreat)
	_true(stationary_pre_release_progressed >= 8, "Der stationäre Pulk führt vor dem ersten Kill mehrere Randkörper nach (%d / 80)" % stationary_pre_release_progressed)
	_true(stationary_pre_release_contactors >= 2, "Die freie Außenkante erreicht vor dem ersten Kill mehrere echte Kontaktplätze (%d)" % stationary_pre_release_contactors)
	_true(stationary_release_count >= 6, "Der Kampfersatz öffnet wiederholt echte Plätze am Doctor (%d)" % stationary_release_count)
	_true(stationary_progressed >= 10, "Der einseitige Pulk führt wiederholt neue Körper deutlich nach (%d / 80)" % stationary_progressed)
	_true(stationary_late_movers >= 3, "Auch spät fließen mehrere Verfolger aus dem Pulk weiter (%d)" % stationary_late_movers)
	_true(stationary_contact_ids.size() >= 8, "Mehrere unterschiedliche Verfolger erreichen den stehenden Doctor (%d)" % stationary_contact_ids.size())
	_true(stationary_sector_count >= 3, "Der einseitige Pulk hält mehrere Angriffssektoren am Doctor aktiv (%d / 12)" % stationary_sector_count)
	stationary_world.clear()
	for enemy in stationary_enemies:
		enemy.free()

	# Reproduce the reported one-sided screen pack with the two authored ordinary
	# archetypes at their production speed. The outside rows must keep feeding a
	# stable boundary without overlap, retreat or registration-order dependence.
	var authored_enemies := ContentCatalog.enemy_definitions()
	var flow_small_definition: EnemyDefinition = authored_enemies[&"pneumococcus"]
	var flow_cluster_definition: EnemyDefinition = authored_enemies[&"bacterial_cluster"]
	var flow_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	flow_world.configure_crowd_collision(topology, avatar, flow_cluster_definition.radius)
	var flow_enemies: Array[InfectionEnemy] = []
	var flow_handles := PackedInt64Array()
	var flow_cluster_flags := PackedByteArray()
	var flow_exterior_flags := PackedByteArray()
	var flow_upper_flags := PackedByteArray()
	var flow_removed := PackedByteArray()
	var flow_window_origins := PackedVector2Array()
	var flow_window_paths := PackedFloat32Array()
	# Multiplication by 37 permutes all 64 indices and avoids front-to-back slots.
	for order_index in range(64):
		var spec_index := posmod(order_index * 37 + 11, 64)
		var column := int(spec_index / 8)
		var row := posmod(spec_index, 8)
		var is_cluster := posmod(column + row * 2, 3) == 0
		var definition := flow_cluster_definition if is_cluster else flow_small_definition
		var position := Vector2(
			-110.0 - float(column) * 43.30127,
			(float(row) - 3.5) * 50.0 + (25.0 if posmod(column, 2) != 0 else 0.0)
		)
		var enemy := _enemy(definition, avatar, topology, position)
		flow_enemies.append(enemy)
		flow_cluster_flags.append(1 if is_cluster else 0)
		flow_exterior_flags.append(1 if row == 0 or row == 7 else 0)
		flow_upper_flags.append(1 if row == 0 else 0)
		flow_removed.append(0)
		flow_window_origins.append(position)
		flow_window_paths.append(0.0)
		var handle := flow_world.register_enemy(enemy)
		flow_handles.append(handle)
		_true(EntityHandle.is_valid(handle), "Gemischter Randverfolger %d erhält einen Handle" % (order_index + 1))
	var flow_minimum_margin := INF
	var flow_minimum_pair := Vector2i(-1, -1)
	var flow_minimum_tick := -1
	var flow_maximum_retreat := 0.0
	var flow_window_exterior_movers := PackedInt32Array()
	flow_window_exterior_movers.resize(4)
	flow_window_exterior_movers.fill(0)
	var flow_unique_exterior_movers: Dictionary = {}
	var flow_released_contactors: Dictionary = {}
	for tick in range(480):
		var before_positions := PackedVector2Array()
		var before_distances := PackedFloat32Array()
		for index in range(flow_enemies.size()):
			before_positions.append(flow_enemies[index].global_position)
			before_distances.append(topology.distance(flow_enemies[index].global_position, avatar.global_position))
		flow_world.step_fixed(1.0 / 60.0)
		for index in range(flow_enemies.size()):
			if flow_removed[index] != 0:
				continue
			flow_window_paths[index] += topology.distance(
				before_positions[index],
				flow_enemies[index].global_position
			)
			flow_maximum_retreat = maxf(
				flow_maximum_retreat,
				topology.distance(flow_enemies[index].global_position, avatar.global_position)
					- float(before_distances[index])
			)
		for first_index in range(flow_enemies.size()):
			if flow_removed[first_index] != 0:
				continue
			for second_index in range(first_index + 1, flow_enemies.size()):
				if flow_removed[second_index] != 0:
					continue
				var margin := (
					topology.distance(
						flow_enemies[first_index].global_position,
						flow_enemies[second_index].global_position
					)
					- flow_enemies[first_index].contact_body_radius()
					- flow_enemies[second_index].contact_body_radius()
				)
				if margin < flow_minimum_margin:
					flow_minimum_margin = margin
					flow_minimum_pair = Vector2i(first_index, second_index)
					flow_minimum_tick = tick
		if posmod(tick + 1, 120) == 0:
			var window_index := int(tick / 120)
			for index in range(flow_enemies.size()):
				if flow_removed[index] != 0:
					continue
				var net_travel := topology.distance(
					flow_window_origins[index],
					flow_enemies[index].global_position
				)
				var path_travel := float(flow_window_paths[index])
				if (
					flow_exterior_flags[index] != 0
					and net_travel >= 8.0
					and net_travel / maxf(path_travel, 0.001) >= 0.6
				):
					flow_window_exterior_movers[window_index] += 1
					if window_index >= 1:
						flow_unique_exterior_movers[flow_enemies[index].get_instance_id()] = index
				flow_window_origins[index] = flow_enemies[index].global_position
				flow_window_paths[index] = 0.0
		# Once the untouched four-second window has formed the natural shell,
		# simulate one ordinary front kill per second so opened places can refill.
		if tick in [239, 299, 359, 419]:
			var release_index := -1
			var release_distance := INF
			for index in range(flow_enemies.size()):
				if flow_removed[index] != 0:
					continue
				var distance := topology.distance(flow_enemies[index].global_position, avatar.global_position)
				var contact_distance := TherapyAvatar.CONTACT_RADIUS + flow_enemies[index].contact_body_radius()
				if distance <= contact_distance + 0.25 and distance < release_distance:
					release_index = index
					release_distance = distance
			if release_index >= 0:
				var release_handle := int(flow_handles[release_index])
				if flow_world.release(release_handle, false):
					flow_removed[release_index] = 1
					flow_released_contactors[flow_enemies[release_index].get_instance_id()] = true
	var flow_unique_clusters := 0
	var flow_unique_small := 0
	var flow_unique_upper := 0
	var flow_unique_lower := 0
	for index_value in flow_unique_exterior_movers.values():
		var index := int(index_value)
		if flow_cluster_flags[index] != 0:
			flow_unique_clusters += 1
		else:
			flow_unique_small += 1
		if flow_upper_flags[index] != 0:
			flow_unique_upper += 1
		else:
			flow_unique_lower += 1
	_true(
		flow_minimum_margin >= -0.06,
		"Der große gemischte Pulk wahrt jede authored Schadenshitbox (Margin %.3f, Tick %d, Paar %s)" % [
			flow_minimum_margin,
			flow_minimum_tick,
			flow_minimum_pair,
		]
	)
	_true(flow_maximum_retreat <= 0.001, "Der große gemischte Pulk erzeugt keine Fluchtbewegung (%.5f)" % flow_maximum_retreat)
	_true(flow_window_exterior_movers[1] >= 6, "Die freie Außenkante fließt im unberührten 2–4-s-Fenster sichtbar weiter (%d)" % flow_window_exterior_movers[1])
	_true(flow_window_exterior_movers[2] >= 4, "Nach dem ersten Kill fließen mehrere Randkörper weiter (%d)" % flow_window_exterior_movers[2])
	_true(
		flow_window_exterior_movers[2] + flow_window_exterior_movers[3] >= 4,
		"In der zweiten Laufhälfte bleibt die Außenkante aktiv (%d / %d)" % [flow_window_exterior_movers[2], flow_window_exterior_movers[3]]
	)
	_true(flow_unique_exterior_movers.size() >= 6, "Mehrere eindeutige Randkörper tragen den sichtbaren Strom (%d)" % flow_unique_exterior_movers.size())
	_true(flow_unique_clusters >= 1 and flow_unique_small >= 1, "Kleine und rote Gegner fließen beide an der Außenkante (%d / %d)" % [flow_unique_small, flow_unique_clusters])
	_true(flow_unique_upper >= 2 and flow_unique_lower >= 2, "Obere und untere Außenkante bleiben beide aktiv (%d / %d)" % [flow_unique_upper, flow_unique_lower])
	_true(flow_released_contactors.size() >= 3, "Geöffnete Kontaktplätze werden wiederholt von neuen Angreifern gefüllt (%d)" % flow_released_contactors.size())
	# The thresholded island keeps its complete bounded contact guards while the
	# Doctor starts moving; ordinary non-island pursuit still uses the smaller path.
	avatar.global_position += Vector2(0.5, 0.0)
	flow_world.step_fixed(1.0 / 60.0)
	var maximum_moving_guard_count := 0
	for index in range(flow_enemies.size()):
		if flow_removed[index] != 0:
			continue
		var slot := EntityHandle.slot(int(flow_handles[index]))
		maximum_moving_guard_count = maxi(
			maximum_moving_guard_count,
			int(flow_world._crowd_motion_guard_counts[slot])
		)
	_true(not flow_world._crowd_avatar_stationary_this_tick, "Die World erkennt den ersten bewegten Doctor-Tick sofort")
	_true(maximum_moving_guard_count <= EnemyWorld.MAX_CROWD_MOTION_GUARDS, "Der bewegte Bulk bleibt auf den vollständigen begrenzten Kontaktguards (%d)" % maximum_moving_guard_count)
	avatar.global_position = Vector2.ZERO
	flow_world.clear()
	for enemy in flow_enemies:
		enemy.free()

	# The reported failure is not a rectangular edge: it is a dense rear island
	# connected to an already active front by a narrow diagonal neck. Track bodies
	# by their initial depth so a handful of moving front/outer-row bodies cannot
	# hide a sleeping rear reservoir.
	var rear_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	rear_world.configure_crowd_collision(topology, avatar, flow_cluster_definition.radius)
	var rear_specs: Array[Dictionary] = []
	for column in range(4):
		for row in range(7):
			rear_specs.append({"column": column, "row": row, "region": 0})
	for column in range(4, 6):
		for row in range(1, 5):
			rear_specs.append({"column": column, "row": row, "region": 1})
	for column in range(6, 11):
		var row_start := 1 if column == 10 else 0
		var row_end := 5 if column == 10 else 6
		for row in range(row_start, row_end):
			rear_specs.append({"column": column, "row": row, "region": 2})
	_true(rear_specs.size() == 64, "Die zweilappige Rückpulk-Fixture besitzt exakt 64 Körper")
	var rear_enemies: Array[InfectionEnemy] = []
	var rear_flags := PackedByteArray()
	var rear_cluster_flags := PackedByteArray()
	var rear_deep_flags := PackedByteArray()
	var rear_post_warmup_distances := PackedFloat32Array()
	var rear_window_start_distances := PackedFloat32Array()
	var rear_window_paths := PackedFloat32Array()
	for order_index in range(rear_specs.size()):
		var spec_index := posmod(order_index * 37 + 11, rear_specs.size())
		var spec: Dictionary = rear_specs[spec_index]
		var column := int(spec["column"])
		var row := int(spec["row"])
		var region := int(spec["region"])
		var position := Vector2.ZERO
		if region == 0:
			position = Vector2(
				-90.0 - float(column) * 43.30127,
				(float(row) - 3.0) * 50.0 + (25.0 if posmod(column, 2) != 0 else 0.0)
			)
		elif region == 1:
			position = Vector2(
				-90.0 - float(column) * 43.30127,
				(float(row) - 3.0) * 50.0 + (25.0 if posmod(column, 2) != 0 else 0.0)
			)
		else:
			position = Vector2(
				-90.0 - float(column) * 43.30127,
				(float(row) - 2.5) * 50.0 - 75.0 + (25.0 if posmod(column, 2) != 0 else 0.0)
			)
		var is_cluster := posmod(column * 2 + row, 4) == 0
		var definition := flow_cluster_definition if is_cluster else flow_small_definition
		var enemy := _enemy(definition, avatar, topology, position)
		rear_enemies.append(enemy)
		rear_flags.append(1 if region == 2 else 0)
		rear_cluster_flags.append(1 if is_cluster else 0)
		rear_deep_flags.append(1 if region == 2 and column >= 8 else 0)
		var initial_distance := topology.distance(position, avatar.global_position)
		rear_post_warmup_distances.append(initial_distance)
		rear_window_start_distances.append(initial_distance)
		rear_window_paths.append(0.0)
		_true(
			EntityHandle.is_valid(rear_world.register_enemy(enemy)),
			"Zweilappiger Rückpulk-Körper %d erhält einen Handle" % (order_index + 1)
		)
	var rear_window_movers := PackedInt32Array()
	rear_window_movers.resize(4)
	rear_window_movers.fill(0)
	var rear_entered_neck: Dictionary = {}
	var rear_minimum_margin := INF
	var rear_maximum_retreat := 0.0
	var rear_neck_plane_x := -315.0
	for tick in range(240):
		var before_positions := PackedVector2Array()
		var before_distances := PackedFloat32Array()
		for enemy in rear_enemies:
			before_positions.append(enemy.global_position)
			before_distances.append(topology.distance(enemy.global_position, avatar.global_position))
		rear_world.step_fixed(1.0 / 60.0)
		for index in range(rear_enemies.size()):
			var current_distance := topology.distance(rear_enemies[index].global_position, avatar.global_position)
			rear_window_paths[index] += topology.distance(
				before_positions[index],
				rear_enemies[index].global_position
			)
			rear_maximum_retreat = maxf(
				rear_maximum_retreat,
				current_distance - float(before_distances[index])
			)
			if (
				rear_flags[index] != 0
				and rear_enemies[index].global_position.x >= rear_neck_plane_x
				and rear_enemies[index].global_position.y >= -105.0
				and rear_enemies[index].global_position.y <= 80.0
			):
				rear_entered_neck[rear_enemies[index].get_instance_id()] = true
		for first_index in range(rear_enemies.size()):
			for second_index in range(first_index + 1, rear_enemies.size()):
				rear_minimum_margin = minf(
					rear_minimum_margin,
					topology.distance(
						rear_enemies[first_index].global_position,
						rear_enemies[second_index].global_position
					)
						- rear_enemies[first_index].contact_body_radius()
						- rear_enemies[second_index].contact_body_radius()
				)
		if posmod(tick + 1, 60) == 0:
			var window_index := int(tick / 60)
			for index in range(rear_enemies.size()):
				var current_distance := topology.distance(rear_enemies[index].global_position, avatar.global_position)
				if window_index == 0:
					rear_post_warmup_distances[index] = current_distance
				var window_progress := float(rear_window_start_distances[index]) - current_distance
				if (
					rear_flags[index] != 0
					and window_progress >= 4.0
					and float(rear_window_paths[index]) >= 6.0
				):
					rear_window_movers[window_index] += 1
				rear_window_start_distances[index] = current_distance
				rear_window_paths[index] = 0.0
	var rear_progress_values := PackedFloat32Array()
	var rear_progressed_sixteen := 0
	var rear_small_progressed_sixteen := 0
	var rear_cluster_progressed_sixteen := 0
	var rear_deep_progressed_eight := 0
	for index in range(rear_enemies.size()):
		if rear_flags[index] == 0:
			continue
		var forward_progress := (
			float(rear_post_warmup_distances[index])
			- topology.distance(rear_enemies[index].global_position, avatar.global_position)
		)
		rear_progress_values.append(forward_progress)
		if forward_progress >= 16.0:
			rear_progressed_sixteen += 1
			if rear_cluster_flags[index] != 0:
				rear_cluster_progressed_sixteen += 1
			else:
				rear_small_progressed_sixteen += 1
		if rear_deep_flags[index] != 0 and forward_progress >= 8.0:
			rear_deep_progressed_eight += 1
	rear_progress_values.sort()
	var rear_median_progress := float(rear_progress_values[int(rear_progress_values.size() / 2)])
	_true(rear_minimum_margin >= -0.06, "Der zweilappige Rückpulk wahrt alle Schadenshitboxen (Margin %.3f)" % rear_minimum_margin)
	_true(rear_maximum_retreat <= 0.001, "Der zweilappige Rückpulk erzeugt keine Fluchtbewegung (%.5f)" % rear_maximum_retreat)
	_true(rear_window_movers[1] >= 8, "Im 1–2-s-Fenster laufen mehrere echte Rückkörper nach (%d / 28)" % rear_window_movers[1])
	_true(rear_window_movers[2] >= 8, "Im 2–3-s-Fenster bleibt der hintere Pulk in Bewegung (%d / 28)" % rear_window_movers[2])
	_true(rear_window_movers[3] >= 8, "Im 3–4-s-Fenster schläft der hintere Pulk nicht ein (%d / 28)" % rear_window_movers[3])
	_true(rear_progressed_sixteen >= 10, "Mindestens zehn Rückkörper nähern sich in vier Sekunden deutlich (%d / 28)" % rear_progressed_sixteen)
	_true(
		rear_small_progressed_sixteen >= 6 and rear_cluster_progressed_sixteen >= 2,
		"Kleine und rote Rückkörper fließen beide sichtbar nach (%d klein / %d rot)" % [
			rear_small_progressed_sixteen,
			rear_cluster_progressed_sixteen,
		]
	)
	_true(
		rear_deep_progressed_eight >= 4,
		"Auch die tiefen Rückreihen laufen nach der freien Startsekunde sichtbar nach (%d)" % rear_deep_progressed_eight
	)
	_true(rear_median_progress >= 8.0, "Der mediane Rückpulk-Fortschritt bleibt sichtbar (%.2f)" % rear_median_progress)
	_true(rear_entered_neck.size() >= 3, "Mehrere ursprüngliche Rückkörper fließen in den schmalen Hals (%d)" % rear_entered_neck.size())
	rear_world.clear()
	for enemy in rear_enemies:
		enemy.free()

	# An active mixed-speed component uses the fastest member's complete effective
	# speed product. Entry/exit blend changes only how much of that shared speed
	# is inherited; component steering and contact geometry remain untouched.
	var bulk_speed_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	bulk_speed_world.configure_crowd_collision(topology, avatar, 10.0)
	var slow_bulk_definition := EnemyDefinition.create(
		&"pneumococcus", "Langsames Pulkmitglied", 22.0, 40.0, 2.0, 1, 10.0, Color.WHITE
	).configure_contact_radius(8.0)
	var fast_bulk_definition := EnemyDefinition.create(
		&"pneumococcus", "Schnelles Pulkmitglied", 22.0, 80.0, 2.0, 1, 10.0, Color.WHITE
	).configure_contact_radius(8.0)
	var bulk_speed_enemies: Array[InfectionEnemy] = []
	var bulk_speed_handles := PackedInt64Array()
	for index in range(6):
		var bulk_enemy := _enemy(
			fast_bulk_definition if index == 0 else slow_bulk_definition,
			avatar,
			topology,
			Vector2(280.0 + float(index) * 18.0, 0.0)
		)
		if index == 0:
			bulk_enemy.speed_multiplier = 1.25
			bulk_enemy.set_status_modifier(&"bulk_speed_regression", 1.20, 1.0)
		bulk_speed_enemies.append(bulk_enemy)
		bulk_speed_handles.append(bulk_speed_world.register_enemy(bulk_enemy))
	for snapshot in range(EnemyWorld.BULK_ENTER_SNAPSHOTS):
		for queued_index in range(2):
			bulk_speed_world._direct_collision_queued[EntityHandle.slot(int(bulk_speed_handles[queued_index]))] = 1
		bulk_speed_world._start_bulk_component_refresh()
		while bulk_speed_world._bulk_refresh_in_progress:
			bulk_speed_world._continue_bulk_component_refresh()
	var fast_bulk_handle := int(bulk_speed_handles[0])
	var slow_bulk_handle := int(bulk_speed_handles[1])
	var fast_bulk_slot := EntityHandle.slot(fast_bulk_handle)
	var slow_bulk_slot := EntityHandle.slot(slow_bulk_handle)
	var fast_bulk_state := bulk_speed_world.bulk_member_state(fast_bulk_handle)
	var slow_bulk_state := bulk_speed_world.bulk_member_state(slow_bulk_handle)
	_true(bool(fast_bulk_state.get("active", false)) and bool(slow_bulk_state.get("active", false)), "Der gemischte Geschwindigkeitspulk erreicht den aktiven Vertrag")
	_equal(fast_bulk_state.get("component_root"), slow_bulk_state.get("component_root"), "Schnelles und langsames Mitglied teilen denselben Komponenten-Root")
	_near(float(fast_bulk_state.get("effective_speed", 0.0)), 120.0, "Der Root speichert definition.speed × speed_multiplier × Statusfaktor")
	_near(float(slow_bulk_state.get("effective_speed", 0.0)), 120.0, "Jedes Mitglied erhält die maximale effektive Root-Geschwindigkeit")
	bulk_speed_world._bulk_blends[fast_bulk_slot] = 1.0
	bulk_speed_world._bulk_blends[slow_bulk_slot] = 1.0
	var fast_bulk_delta := bulk_speed_world._bulk_desired_delta(fast_bulk_slot, bulk_speed_enemies[0], bulk_speed_enemies[0].global_position, 1.0 / 60.0)
	var slow_bulk_delta := bulk_speed_world._bulk_desired_delta(slow_bulk_slot, bulk_speed_enemies[1], bulk_speed_enemies[1].global_position, 1.0 / 60.0)
	_near(fast_bulk_delta.length(), 2.0, "Das schnellste Mitglied behält seine effektive Geschwindigkeit")
	_near(slow_bulk_delta.length(), 2.0, "Das langsame Mitglied übernimmt bei vollem Blend die schnellste Geschwindigkeit")
	bulk_speed_world._bulk_blends[slow_bulk_slot] = 0.5
	var blended_bulk_delta := bulk_speed_world._bulk_desired_delta(slow_bulk_slot, bulk_speed_enemies[1], bulk_speed_enemies[1].global_position, 1.0 / 60.0)
	_near(blended_bulk_delta.length(), 80.0 / 60.0, "Der Ein-/Austrittsblend interpoliert zwischen eigener und Root-Geschwindigkeit")
	bulk_speed_world.clear()
	for enemy in bulk_speed_enemies:
		enemy.free()

	# Explicit knockback remains the only intentional distance increase.
	mixed_world.clear()
	for enemy in mixed_enemies:
		enemy.free()
	var knockback_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	knockback_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var knocked := _enemy(small_definition, avatar, topology, Vector2(80.0, 0.0))
	var recovery_blocker_definition := EnemyDefinition.create(
		&"pneumococcus", "Statischer Rückstoßnachbar", 22.0, 0.0, 0.0, 0, 18.0, Color.WHITE
	).configure_contact_radius(17.0)
	var old_recovery_neighbor := _enemy(recovery_blocker_definition, avatar, topology, Vector2(80.0, 45.0))
	var new_recovery_neighbor := _enemy(recovery_blocker_definition, avatar, topology, Vector2(125.0, 75.0))
	var knocked_handle := knockback_world.register_enemy(knocked)
	var old_recovery_handle := knockback_world.register_enemy(old_recovery_neighbor)
	var new_recovery_handle := knockback_world.register_enemy(new_recovery_neighbor)
	_true(EntityHandle.is_valid(knocked_handle), "Rückstoßgegner erhält einen Handle")
	_true(EntityHandle.is_valid(old_recovery_handle) and EntityHandle.is_valid(new_recovery_handle), "Alte und neue Rückstoßnachbarschaft sind registriert")
	var interruption_edges: Array[bool] = []
	knocked.stun_changed.connect(func(_enemy_value: InfectionEnemy, stunned: bool) -> void:
		interruption_edges.append(stunned)
		_true(knockback_world.notify_enemy_motion_interrupted(knocked_handle), "Jede Stun-Kante invalidiert den aktuellen generationssicheren Handle")
	)
	var knocked_slot := EntityHandle.slot(knocked_handle)
	var old_recovery_slot := EntityHandle.slot(old_recovery_handle)
	var new_recovery_slot := EntityHandle.slot(new_recovery_handle)
	knockback_world._direct_collision_queued[knocked_slot] = 1
	knockback_world._crowd_lane_signs[knocked_slot] = 1
	knockback_world._bulk_active[knocked_slot] = 1
	knockback_world._bulk_blends[knocked_slot] = 1.0
	knockback_world._direct_collision_queue_blockers[old_recovery_slot] = knocked_handle
	knockback_world._crowd_lane_signs[old_recovery_slot] = 1
	knockback_world._flow_lease_handles[old_recovery_slot] = knocked_handle
	knockback_world._bulk_active[old_recovery_slot] = 1
	knockback_world._bulk_blends[old_recovery_slot] = 1.0
	knocked.apply_knockback(Vector2.RIGHT, 45.0, 0.28, 1.0)
	_true(knockback_world._direct_collision_queued[knocked_slot] == 0 and knockback_world._crowd_lane_signs[knocked_slot] == 0, "Stoßbeginn entfernt die eigenen Queue-/Lane-Caches synchron")
	_true(knockback_world._bulk_active[knocked_slot] == 0 and knockback_world._bulk_blends[knocked_slot] == 0.0, "Ein gestunnter Gegner behält niemals Bulk-Motion")
	var knockback_origin_distance := topology.distance(knocked.global_position, avatar.global_position)
	knockback_world.step_fixed(1.0 / 60.0)
	_true(
		knockback_world._direct_collision_queue_blockers[old_recovery_slot] == EntityHandle.INVALID
			and knockback_world._crowd_lane_signs[old_recovery_slot] == 0
			and knockback_world._flow_lease_handles[old_recovery_slot] == EntityHandle.INVALID
			and knockback_world._bulk_active[old_recovery_slot] == 0,
		"Die alte lokale Nachbarschaft verliert Queue, Lane, Flow und Bulk ohne Weltreset"
	)
	for _tick in range(17):
		knockback_world.step_fixed(1.0 / 60.0)
	var knocked_distance := topology.distance(knocked.global_position, avatar.global_position)
	_true(knocked_distance > knockback_origin_distance + 30.0, "Nur expliziter Rückstoß bewegt einen Gegner sichtbar vom Doctor weg")
	_true(knocked.is_stunned(), "Rückstoß betäubt den Gegner weiterhin")
	knockback_world._direct_collision_queue_blockers[new_recovery_slot] = knocked_handle
	knockback_world._crowd_lane_signs[new_recovery_slot] = -1
	knockback_world._flow_lease_handles[new_recovery_slot] = knocked_handle
	knockback_world._bulk_active[new_recovery_slot] = 1
	knockback_world._bulk_blends[new_recovery_slot] = 1.0
	for _tick in range(72):
		knockback_world.step_fixed(1.0 / 60.0)
	_true(not knocked.is_stunned(), "Betäubung endet weiterhin nach einer Sekunde")
	_equal(interruption_edges, [true, false], "Game erhält genau eine Beginn- und Endkante der Bewegungsunterbrechung")
	_true(
		knockback_world._direct_collision_queue_blockers[new_recovery_slot] == EntityHandle.INVALID
			and knockback_world._crowd_lane_signs[new_recovery_slot] == 0
			and knockback_world._flow_lease_handles[new_recovery_slot] == EntityHandle.INVALID
			and knockback_world._bulk_active[new_recovery_slot] == 0,
		"Die neue lokale Nachbarschaft wird an der Stun-Endkante vollständig geweckt"
	)
	_true(topology.distance(knocked.global_position, avatar.global_position) < knocked_distance, "Nach Betäubung verfolgt der Gegner sofort wieder den Doctor")
	knockback_world.clear()
	knocked.free()
	old_recovery_neighbor.free()
	new_recovery_neighbor.free()

	# Doctor Milos uses the same damage-contact circles as physical boundaries.
	# Every ordinary mobile non-boss yields slowly by default, independent of ID.
	avatar.global_position = Vector2.ZERO
	var cluster_push_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	cluster_push_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var pushable_cluster_definition := EnemyDefinition.create(
		&"bacterial_cluster", "Schiebbare Bakteriengruppe", 74.0, 0.0, 0.0, 0, 30.0, Color.WHITE
	).configure_contact_radius(23.0)
	var pushed_cluster := _enemy(
		pushable_cluster_definition,
		avatar,
		topology,
		Vector2(TherapyAvatar.CONTACT_RADIUS + 23.2, 0.0)
	)
	_true(pushed_cluster.can_be_pushed_by_player(), "Eine gewöhnliche mobile Bakteriengruppe ist standardmäßig schiebbar")
	_true(EntityHandle.is_valid(cluster_push_world.register_enemy(pushed_cluster)), "Schiebbare Bakteriengruppe erhält einen Handle")
	cluster_push_world.step_fixed(1.0 / 60.0)
	var cluster_origin := pushed_cluster.global_position
	avatar.input_enabled = true
	Input.action_press(&"move_right")
	for _tick in range(30):
		cluster_push_world.prepare_avatar_body_interaction(1.0 / 60.0)
		avatar.step_fixed(1.0 / 60.0)
	Input.action_release(&"move_right")
	_true(avatar.global_position.x > 5.0 and avatar.global_position.x < 40.0, "Der Doctor arbeitet sich physisch, aber nicht mit vollem Galopp durch eine Bakteriengruppe (%.2f)" % avatar.global_position.x)
	_true(pushed_cluster.global_position.x > cluster_origin.x + 5.0, "Auch eine große gewöhnliche Gegnerart wird sichtbar weggedrückt")
	_true(
		pushed_cluster.global_position.distance_to(avatar.global_position) >= TherapyAvatar.CONTACT_RADIUS + pushed_cluster.contact_body_radius() - 0.1,
		"Spieler und Bakteriengruppe unterschreiten beim Schieben nie ihre Schadenshitboxgrenze"
	)
	_true(not pushed_cluster.is_stunned(), "Normales Spielerschieben betäubt große Gegner nicht")
	cluster_push_world.clear()
	pushed_cluster.free()

	# A definition can explicitly reject avatar pushing and remains a hard body.
	avatar.global_position = Vector2.ZERO
	var opted_out_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	opted_out_world.configure_crowd_collision(topology, avatar, cluster_definition.radius)
	var opted_out_definition := EnemyDefinition.create(
		&"avatar_push_locked", "Verankerter Gegner", 74.0, 0.0, 0.0, 0, 30.0, Color.WHITE
	).configure_contact_radius(23.0).configure_player_push(false)
	var opted_out_enemy := _enemy(
		opted_out_definition,
		avatar,
		topology,
		Vector2(TherapyAvatar.CONTACT_RADIUS + 23.2, 0.0)
	)
	_true(not opted_out_enemy.can_be_pushed_by_player(), "Eine Definition kann Spielerschieben ausdrücklich verbieten")
	_true(EntityHandle.is_valid(opted_out_world.register_enemy(opted_out_enemy)), "Verankerter Gegner erhält einen Handle")
	opted_out_world.step_fixed(1.0 / 60.0)
	var opted_out_origin := opted_out_enemy.global_position
	Input.action_press(&"move_right")
	for _tick in range(30):
		opted_out_world.prepare_avatar_body_interaction(1.0 / 60.0)
		avatar.step_fixed(1.0 / 60.0)
	Input.action_release(&"move_right")
	_true(avatar.global_position.x <= 0.25, "Ein ausdrücklich verankerter Gegner blockiert den Doctor an seiner Schadenshitbox (%.3f)" % avatar.global_position.x)
	_true(opted_out_enemy.global_position.is_equal_approx(opted_out_origin), "Ein ausdrücklich verankerter Gegner wird nicht verschoben")
	opted_out_enemy.apply_displacement(Vector2.RIGHT * 20.0)
	_true(opted_out_enemy.global_position.is_equal_approx(opted_out_origin), "Auch direkte Spieler-Verschiebung respektiert das Definitionsverbot")
	opted_out_enemy.apply_knockback(Vector2.RIGHT, 30.0, 0.1, 1.0)
	opted_out_enemy.step_fixed(0.05)
	_true(opted_out_enemy.global_position.is_equal_approx(opted_out_origin), "Stoß betäubt einen verankerten Gegner, ohne ihn zu verschieben")
	_true(opted_out_enemy.is_stunned(), "Das reine Verschiebungsverbot entfernt den bestehenden Stoß-Stun nicht")
	opted_out_world.clear()
	opted_out_enemy.free()

	# Boss status is a non-overridable hard-body exception for avatar contact.
	avatar.global_position = Vector2.ZERO
	var boss_push_world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	boss_push_world.configure_crowd_collision(topology, avatar, 60.0)
	var avatar_push_boss_definition := EnemyDefinition.create(
		&"avatar_push_boss", "Nicht schiebbarer Boss", 400.0, 0.0, 0.0, 0, 60.0, Color.WHITE, true
	).configure_contact_radius(47.0)
	var avatar_push_boss := _enemy(
		avatar_push_boss_definition,
		avatar,
		topology,
		Vector2(TherapyAvatar.CONTACT_RADIUS + 47.2, 0.0)
	)
	_true(not avatar_push_boss.can_be_pushed_by_player(), "Ein Boss bleibt trotz Defaultflag grundsätzlich nicht schiebbar")
	_true(EntityHandle.is_valid(boss_push_world.register_enemy(avatar_push_boss, true)), "Nicht schiebbarer Boss erhält einen kritischen Handle")
	boss_push_world.step_fixed(1.0 / 60.0)
	var avatar_push_boss_origin := avatar_push_boss.global_position
	Input.action_press(&"move_right")
	for _tick in range(30):
		boss_push_world.prepare_avatar_body_interaction(1.0 / 60.0)
		avatar.step_fixed(1.0 / 60.0)
	Input.action_release(&"move_right")
	_true(avatar.global_position.x <= 0.25, "Ein Boss blockiert den Doctor weiterhin an seiner Schadenshitbox (%.3f)" % avatar.global_position.x)
	_true(avatar_push_boss.global_position.is_equal_approx(avatar_push_boss_origin), "Avatar-Körperkontakt verschiebt einen Boss nie")
	boss_push_world.clear()
	avatar_push_boss.free()

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


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (erwartet %s, erhalten %s)" % [message, expected, actual])


func _near(actual: float, expected: float, message: String) -> void:
	_true(is_equal_approx(actual, expected), "%s (erwartet %.4f, erhalten %.4f)" % [message, expected, actual])


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


func _on_edge_pressure(_amount: float) -> void:
	edge_hits += 1


func _on_stationary_pressure(_amount: float, enemy_id: int) -> void:
	stationary_contact_ids[enemy_id] = true
