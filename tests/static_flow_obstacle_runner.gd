extends SceneTree

const FIXED_DELTA := 1.0 / 60.0
const POSITION_EPSILON := 0.18

var assertions := 0
var failures := 0
var _added_input_actions: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_prepare_input_actions()
	_test_small_and_cluster_flow_around_single_obstacle()
	_test_doctor_side_target_keeps_blocked_route_moving()
	_test_bulk_route_uses_doctor_side_progress_target()
	_test_small_group_enters_bulk_early()
	_test_off_axis_side_choice_is_progress_stable()
	_test_dense_bulk_preserves_bodies_and_flow_side()
	_test_bottleneck_accelerates_only_free_front_body()
	_test_knockback_clears_mover_route_but_not_static_body()
	_test_generation_safe_obstacle_reuse_clears_route()
	_test_boss_default_and_explicit_traversal()
	_test_static_only_dead_end_never_waits()
	for action in _added_input_actions:
		InputMap.erase_action(action)
	if failures == 0:
		print("ALVEOLUS_STATIC_FLOW_OBSTACLE_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_STATIC_FLOW_OBSTACLE_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)


func _prepare_input_actions() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			_added_input_actions.append(action)


func _test_small_and_cluster_flow_around_single_obstacle() -> void:
	_assert_single_obstacle_pass(_small_definition(), "Kleines Bakterium", Vector2(230.0, 0.0))
	_assert_single_obstacle_pass(_cluster_definition(), "Bakteriengruppe", Vector2(245.0, 0.0))


func _assert_single_obstacle_pass(
	mover_definition: EnemyDefinition,
	label: String,
	start: Vector2
) -> void:
	var fixture := _fixture(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var world: EnemyWorld = fixture.world
	var avatar: TherapyAvatar = fixture.avatar
	var topology: ArenaTopology = fixture.topology
	var obstacle := _enemy(
		_focus_definition(), avatar, topology, Vector2(110.0, 0.0),
		0.0, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE
	)
	var mover := _enemy(mover_definition, avatar, topology, start)
	var obstacle_handle := world.register_enemy(obstacle, true)
	var mover_handle := world.register_enemy(mover)
	_true(EntityHandle.is_valid(obstacle_handle), "%s-Test registriert das Flusshindernis" % label)
	_true(EntityHandle.is_valid(mover_handle), "%s-Test registriert den mobilen Körper" % label)
	var required_spacing := mover.contact_body_radius() + obstacle.contact_body_radius()
	var minimum_spacing := INF
	var minimum_active_surface_gap := INF
	var maximum_lateral := 0.0
	var maximum_retreat := 0.0
	var leased_side := 0
	var side_flips := 0
	var route_stationary_ticks := 0
	var route_motion_samples := 0
	var hugging_started := false
	var maximum_hugging_gap := 0.0
	var reached_doctor := false
	for _tick in range(900):
		var position_before := mover.global_position
		var distance_before := topology.distance(mover.global_position, avatar.global_position)
		world.step_fixed(FIXED_DELTA)
		maximum_retreat = maxf(
			maximum_retreat,
			topology.distance(mover.global_position, avatar.global_position) - distance_before
		)
		minimum_spacing = minf(
			minimum_spacing,
			topology.distance(mover.global_position, obstacle.global_position)
		)
		maximum_lateral = maxf(maximum_lateral, absf(mover.global_position.y))
		var slot := EntityHandle.slot(mover_handle)
		var current_side := int(world._flow_side_signs[slot])
		if current_side != 0:
			var current_surface_gap := (
				topology.distance(mover.global_position, obstacle.global_position) - required_spacing
			)
			minimum_active_surface_gap = minf(
				minimum_active_surface_gap,
				current_surface_gap
			)
			if current_surface_gap <= 1.25:
				hugging_started = true
			if hugging_started:
				maximum_hugging_gap = maxf(maximum_hugging_gap, current_surface_gap)
				route_motion_samples += 1
				if topology.distance(position_before, mover.global_position) <= 0.01:
					route_stationary_ticks += 1
			if leased_side != 0 and current_side != leased_side:
				side_flips += 1
			leased_side = current_side
		if _at_doctor_contact(mover, avatar, topology):
			reached_doctor = true
			break
	_true(
		minimum_spacing + POSITION_EPSILON >= required_spacing,
		"%s überschneidet den Zielherd nie (%.2f / %.2f)" % [label, minimum_spacing, required_spacing]
	)
	_true(maximum_lateral >= required_spacing * 0.65, "%s läuft sichtbar um den Zielherd" % label)
	_true(
		minimum_active_surface_gap <= 1.25,
		"%s zieht seine Umlaufbahn eng an die Kontakthitbox (Lücke %.2f)" % [label, minimum_active_surface_gap]
	)
	_true(hugging_started and route_motion_samples > 0, "%s erreicht einen messbaren Kontaktbogen" % label)
	_true(maximum_hugging_gap <= 1.30, "%s bleibt nach Kontakt eng an der Hitbox (max. %.2f)" % [label, maximum_hugging_gap])
	_equal(route_stationary_ticks, 0, "%s stockt auf dem freien Kontaktbogen nie" % label)
	_true(maximum_retreat <= POSITION_EPSILON, "%s flieht während des Umlaufs nicht vor Doctor Milos" % label)
	_equal(side_flips, 0, "%s behält seine gewählte Umlaufseite" % label)
	_true(reached_doctor, "%s erreicht Doctor Milos hinter dem Zielherd" % label)
	_true(obstacle.global_position.is_equal_approx(Vector2(110.0, 0.0)), "Der Zielherd bleibt stationär")
	_cleanup_fixture(fixture, [obstacle, mover])


func _test_doctor_side_target_keeps_blocked_route_moving() -> void:
	var fixture := _fixture(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var world: EnemyWorld = fixture.world
	var avatar: TherapyAvatar = fixture.avatar
	var topology: ArenaTopology = fixture.topology
	var obstacle := _enemy(
		_focus_definition(), avatar, topology, Vector2(30.0, 0.0),
		0.0, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE
	)
	var mover := _enemy(_small_definition(), avatar, topology, Vector2(105.0, 0.0))
	world.register_enemy(obstacle, true)
	var mover_handle := world.register_enemy(mover)
	var mover_slot := EntityHandle.slot(mover_handle)
	var required_spacing := mover.contact_body_radius() + obstacle.contact_body_radius()
	var stop_radius := (
		mover.contact_body_radius()
		+ TherapyAvatar.CONTACT_RADIUS
		- InfectionEnemy.DIRECT_CHASE_CONTACT_DEPTH
	)
	var blocked_shell_samples := 0
	var blocked_shell_motion_samples := 0
	var stationary_streak := 0
	var maximum_stationary_streak := 0
	var route_finished_after_shell := false
	var minimum_obstacle_spacing := INF
	for _tick in range(720):
		var position_before := mover.global_position
		world.step_fixed(FIXED_DELTA)
		minimum_obstacle_spacing = minf(
			minimum_obstacle_spacing,
			topology.distance(mover.global_position, obstacle.global_position)
		)
		var lease_active := EntityHandle.is_valid(int(world._flow_lease_handles[mover_slot]))
		var full_target_delta := avatar.global_position - mover.global_position
		var object_still_blocks := (
			world._flow_segment_entry_distance(
				mover.global_position,
				full_target_delta,
				obstacle.global_position,
				required_spacing
			) != INF
		)
		var inside_direct_stop_shell := full_target_delta.length() <= stop_radius + POSITION_EPSILON
		if lease_active and object_still_blocks and inside_direct_stop_shell:
			blocked_shell_samples += 1
			var moved := topology.distance(position_before, mover.global_position)
			if moved > 0.01:
				blocked_shell_motion_samples += 1
				stationary_streak = 0
			else:
				stationary_streak += 1
				maximum_stationary_streak = maxi(maximum_stationary_streak, stationary_streak)
		elif blocked_shell_samples > 0 and not lease_active:
			route_finished_after_shell = true
			break
	_true(blocked_shell_samples > 0, "Der nahe Doctor erzeugt den blockierten Zielkontakt-Randfall")
	_true(
		blocked_shell_motion_samples == blocked_shell_samples,
		"Der Seitwärtsziel-Fallback bewegt jeden noch objektblockierten Tick (%d/%d)" % [blocked_shell_motion_samples, blocked_shell_samples]
	)
	_equal(maximum_stationary_streak, 0, "Der objektblockierte Verfolger bleibt am Doctor-Zielradius niemals stehen")
	_true(
		route_finished_after_shell,
		"Nach freier Direktlinie übernimmt wieder die normale Doctor-Verfolgung (pos=%s Doctor-Abstand=%.2f Seite=%d)" % [
			str(mover.global_position),
			topology.distance(mover.global_position, avatar.global_position),
			int(world._flow_side_signs[mover_slot])
		]
	)
	_true(
		minimum_obstacle_spacing + POSITION_EPSILON >= required_spacing,
		"Der Seitwärtsziel-Fallback überschneidet das Flusshindernis nicht"
	)
	_cleanup_fixture(fixture, [obstacle, mover])


func _test_bulk_route_uses_doctor_side_progress_target() -> void:
	var fixture := _fixture(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var world: EnemyWorld = fixture.world
	var avatar: TherapyAvatar = fixture.avatar
	var topology: ArenaTopology = fixture.topology
	var obstacle := _enemy(
		_focus_definition(), avatar, topology, Vector2(60.0, 0.0),
		0.0, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE
	)
	var mover := _enemy(_small_definition(), avatar, topology, Vector2(109.0, 0.0))
	var obstacle_handle := world.register_enemy(obstacle, true)
	var mover_handle := world.register_enemy(mover)
	var mover_slot := EntityHandle.slot(mover_handle)
	world._refresh_flow_guards(mover_slot, mover)
	var route_delta := world._static_flow_desired_delta(
		mover_slot,
		mover,
		mover.global_position,
		Vector2.LEFT * _small_definition().speed * FIXED_DELTA,
		FIXED_DELTA,
		false
	)
	_true(EntityHandle.is_valid(int(world._flow_lease_handles[mover_slot])), "Der Bulk-Fallbacktest erzeugt eine echte Hindernislease")
	_equal(int(world._flow_fail_open[mover_slot]), 0, "Die offene Testroute benötigt kein statisches Durchgleiten")
	_equal(int(world._bulk_neighbor_counts[mover_slot]), 0, "Der Testkörper ist nicht durch einen echten Pulk gesättigt")
	_true(absf(route_delta.y) > 0.0001, "Die echte Route wählt eine sichtbare Umlaufseite")
	var lateral_step := Vector2(0.0, signf(route_delta.y))
	world._bulk_origins[mover_slot] = mover.global_position
	world._bulk_proposals[mover_slot] = lateral_step
	world._bulk_direct_directions[mover_slot] = Vector2.LEFT
	var routed_result := world._bulk_project_cached_proposal(mover_slot)
	_true(
		routed_result.length() > 0.9 and signf(routed_result.y) == signf(lateral_step.y),
		"Der Bulk-Solver akzeptiert den freien Schritt zum Doctor-Seitenziel (Route=%s, Vorschlag=%s, Ergebnis=%s, Seite=%d)" % [
			str(route_delta),
			str(lateral_step),
			str(routed_result),
			int(world._flow_side_signs[mover_slot])
		]
	)
	world._set_flow_obstacle_active(obstacle_handle, obstacle, false)
	_equal(int(world._flow_lease_handles[mover_slot]), EntityHandle.INVALID, "Ohne Hindernis endet das temporäre Seitenziel")
	world._bulk_proposals[mover_slot] = lateral_step
	var ordinary_lateral_result := world._bulk_project_cached_proposal(mover_slot)
	_true(ordinary_lateral_result.is_zero_approx(), "Ein gewöhnlicher Bulk erfindet weiterhin keinen seitlichen Zielpunkt")
	world._bulk_proposals[mover_slot] = Vector2.LEFT
	var ordinary_direct_result := world._bulk_project_cached_proposal(mover_slot)
	_true(ordinary_direct_result.x < -0.9, "Nach freier Direktlinie übernimmt sofort wieder die Doctor-Verfolgung")
	_cleanup_fixture(fixture, [obstacle, mover])


func _test_small_group_enters_bulk_early() -> void:
	var light_fixture := _fixture(Rect2(-700.0, -450.0, 1400.0, 900.0))
	var light_world: EnemyWorld = light_fixture.world
	var light_avatar: TherapyAvatar = light_fixture.avatar
	var light_topology: ArenaTopology = light_fixture.topology
	var light_movers: Array[InfectionEnemy] = []
	for index in range(5):
		var mover := _enemy(
			_small_definition(), light_avatar, light_topology,
			Vector2(250.0 + float(index) * 34.0, 0.0)
		)
		light_movers.append(mover)
		light_world.register_enemy(mover)
	for _tick in range(45):
		light_world.step_fixed(FIXED_DELTA)
	_equal(light_world.bulk_active_weight(), 0, "Fünf kleine Bakterien bleiben unter der neuen Bulk-Schwelle")
	_cleanup_fixture(light_fixture, light_movers)

	var fixture := _fixture(Rect2(-700.0, -450.0, 1400.0, 900.0))
	var world: EnemyWorld = fixture.world
	var avatar: TherapyAvatar = fixture.avatar
	var topology: ArenaTopology = fixture.topology
	var movers: Array[InfectionEnemy] = []
	for index in range(6):
		var mover := _enemy(
			_small_definition(), avatar, topology,
			Vector2(250.0 + float(index) * 34.0, 0.0)
		)
		movers.append(mover)
		world.register_enemy(mover)
	var first_active_tick := -1
	for tick in range(75):
		world.step_fixed(FIXED_DELTA)
		if world.bulk_active_weight() >= 6:
			first_active_tick = tick
			break
	_true(first_active_tick >= 0, "Sechs verbundene kleine Bakterien bilden bereits einen Bulk")
	_true(first_active_tick <= 48, "Der kleine Bulk aktiviert nach zwei frühen 0,25-s-Snapshots (%d)" % first_active_tick)
	_cleanup_fixture(fixture, movers)


func _test_dense_bulk_preserves_bodies_and_flow_side() -> void:
	var fixture := _fixture(Rect2(-700.0, -450.0, 1400.0, 900.0))
	var world: EnemyWorld = fixture.world
	var avatar: TherapyAvatar = fixture.avatar
	var topology: ArenaTopology = fixture.topology
	var obstacle := _enemy(
		_focus_definition(), avatar, topology, Vector2(110.0, 0.0),
		0.0, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE
	)
	var obstacle_handle := world.register_enemy(obstacle, true)
	var movers: Array[InfectionEnemy] = []
	var mover_handles := PackedInt64Array()
	for column in range(6):
		for row in range(4):
			var mover := _enemy(
				_small_definition(), avatar, topology,
				Vector2(180.0 + float(column) * 36.0, -54.0 + float(row) * 36.0)
			)
			movers.append(mover)
			mover_handles.append(world.register_enemy(mover))
	for index in range(movers.size()):
		world._refresh_direct_collision_guards(EntityHandle.slot(int(mover_handles[index])), movers[index])
	_true(EntityHandle.is_valid(obstacle_handle), "Der dichte Pulk registriert sein Flusshindernis")
	_true(mover_handles.size() == 24, "Der dichte Pulk enthält 24 mobile Körper")
	var minimum_obstacle_spacing := INF
	var minimum_mobile_spacing := INF
	var flow_seen := false
	var bulk_seen := false
	var routed_bulk_member_seen := false
	var maximum_routed_neighbor_count := 0
	var maximum_routed_bulk_blend := 0.0
	var active_route_by_handle := {}
	var side_flips := 0
	var side_flip_detail := ""
	var reached_doctor := false
	var stationary_route_streaks := {}
	var maximum_stationary_route_streak := 0
	var maximum_stationary_route_detail := ""
	var route_motion_samples := 0
	var moving_route_handles := {}
	for _tick in range(900):
		var before_positions: Array[Vector2] = []
		for mover in movers:
			before_positions.append(mover.global_position)
		world.step_fixed(FIXED_DELTA)
		bulk_seen = bulk_seen or world.bulk_active_weight() > 0
		for index in range(movers.size()):
			var mover := movers[index]
			minimum_obstacle_spacing = minf(
				minimum_obstacle_spacing,
				topology.distance(mover.global_position, obstacle.global_position)
			)
			var handle := int(mover_handles[index])
			var slot := EntityHandle.slot(handle)
			var current_side := int(world._flow_side_signs[slot])
			var current_lease := int(world._flow_lease_handles[slot])
			var current_epoch := int(world._flow_route_epochs[slot])
			if current_side != 0 and current_epoch > 0 and EntityHandle.is_valid(current_lease):
				flow_seen = true
				maximum_routed_neighbor_count = maxi(
					maximum_routed_neighbor_count,
					int(world._bulk_neighbor_counts[slot])
				)
				maximum_routed_bulk_blend = maxf(
					maximum_routed_bulk_blend,
					float(world._bulk_blends[slot])
				)
				routed_bulk_member_seen = (
					routed_bulk_member_seen
					or int(world._bulk_pending[slot]) != 0
				)
				if (
					not _at_doctor_contact(mover, avatar, topology)
					and int(world._direct_collision_queued[slot]) == 0
				):
					route_motion_samples += 1
					var moved := topology.distance(before_positions[index], mover.global_position)
					if moved > 0.01:
						moving_route_handles[handle] = true
					var stationary_streak := int(stationary_route_streaks.get(handle, 0))
					stationary_streak = stationary_streak + 1 if moved <= 0.01 else 0
					stationary_route_streaks[handle] = stationary_streak
					if stationary_streak > maximum_stationary_route_streak:
						maximum_stationary_route_streak = stationary_streak
						maximum_stationary_route_detail = "handle=%s pos=%s neighbors=%d queued=%d" % [
							str(handle), str(mover.global_position),
							int(world._bulk_neighbor_counts[slot]),
							int(world._direct_collision_queued[slot])
						]
				var previous_route: Dictionary = active_route_by_handle.get(handle, {})
				if (
					not previous_route.is_empty()
					and int(previous_route.get("epoch", 0)) == current_epoch
					and int(previous_route.get("side", 0)) != current_side
				):
					side_flips += 1
					side_flip_detail = "handle=%s lease=%s epoch=%s %s->%s" % [str(handle), str(current_lease), str(current_epoch), str(previous_route.get("side", 0)), str(current_side)]
				active_route_by_handle[handle] = {"epoch": current_epoch, "side": current_side}
			else:
				active_route_by_handle.erase(handle)
				stationary_route_streaks.erase(handle)
			reached_doctor = reached_doctor or _at_doctor_contact(mover, avatar, topology)
		for first_index in range(movers.size()):
			for second_index in range(first_index + 1, movers.size()):
				minimum_mobile_spacing = minf(
					minimum_mobile_spacing,
					topology.distance(
						movers[first_index].global_position,
						movers[second_index].global_position
					)
				)
		if reached_doctor and flow_seen and bulk_seen and routed_bulk_member_seen:
			break
	var obstacle_spacing := _small_definition().contact_radius + obstacle.contact_body_radius()
	_true(flow_seen, "Der dichte Pulk aktiviert den stationären Hindernisfluss")
	_true(bulk_seen, "Der bestehende stabile Pulkfluss bleibt neben dem Hindernisfluss aktiv")
	_true(
		routed_bulk_member_seen,
		"Dieselbe Hindernislease wird vom Pulk-Solver bewegt (Nachbarn %d, Blend %.2f)" % [maximum_routed_neighbor_count, maximum_routed_bulk_blend]
	)
	_true(route_motion_samples > 0, "Der dichte Pulk erzeugt messbare Umlaufschritte")
	_true(moving_route_handles.size() >= 2, "Beide freien Pulkspitzen umlaufen das Hindernis flüssig (%d)" % moving_route_handles.size())
	_equal(maximum_stationary_route_streak, 0, "Eine freie aktive Umlaufroute hat niemals einen Nullschritt (%s)" % maximum_stationary_route_detail)
	_equal(side_flips, 0, "Aktive Umlaufleases wechseln im dichten Pulk nie die Seite (%s)" % side_flip_detail)
	_true(
		minimum_obstacle_spacing + POSITION_EPSILON >= obstacle_spacing,
		"Der dichte Pulk überschneidet das Hindernis nicht (%.2f / %.2f)" % [minimum_obstacle_spacing, obstacle_spacing]
	)
	_true(
		minimum_mobile_spacing + POSITION_EPSILON >= _small_definition().contact_radius * 2.0,
		"Der dichte Pulk wahrt auch beim Umlaufen alle Körperabstände (%.2f)" % minimum_mobile_spacing
	)
	_true(reached_doctor, "Der dichte Pulk strömt bis Doctor Milos durch")
	_true(not bool(world.bulk_member_state(obstacle_handle).get("active", true)), "Das Flusshindernis wird nie Pulkmitglied")
	_cleanup_fixture(fixture, [obstacle] + movers)


func _test_off_axis_side_choice_is_progress_stable() -> void:
	var chosen_sides: Array[int] = []
	for even_slot in [false, true]:
		var fixture := _fixture(Rect2(-700.0, -450.0, 1400.0, 900.0))
		var world: EnemyWorld = fixture.world
		var avatar: TherapyAvatar = fixture.avatar
		var topology: ArenaTopology = fixture.topology
		var obstacle := _enemy(
			_focus_definition(), avatar, topology, Vector2(110.0, 24.0),
			0.0, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE
		)
		world.register_enemy(obstacle, true)
		var enemies: Array[InfectionEnemy] = [obstacle]
		if even_slot:
			var parity_dummy := _enemy(
				_small_definition(), avatar, topology, Vector2(-520.0, 340.0), 0.0,
				EnemySpawnRequest.BodyRole.MOBILE,
				EnemySpawnRequest.ObstacleTraversal.PHASE_THROUGH
			)
			world.register_enemy(parity_dummy)
			enemies.append(parity_dummy)
		var mover := _enemy(_small_definition(), avatar, topology, Vector2(230.0, 0.0))
		var mover_handle := world.register_enemy(mover)
		enemies.append(mover)
		var selected_side := 0
		var reached_doctor := false
		for _tick in range(600):
			world.step_fixed(FIXED_DELTA)
			var side := int(world._flow_side_signs[EntityHandle.slot(mover_handle)])
			if side != 0 and selected_side == 0:
				selected_side = side
			if _at_doctor_contact(mover, avatar, topology):
				reached_doctor = true
				break
		_true(selected_side != 0, "Der versetzte Zielherd erzeugt für beide Slotparitäten eine Umlauflease")
		_true(reached_doctor, "Der versetzte Zielherd setzt keine Slotparität dauerhaft fest")
		chosen_sides.append(selected_side)
		_cleanup_fixture(fixture, enemies)
	_equal(chosen_sides[0], chosen_sides[1], "Bei gleicher Freiheit priorisiert die Seitenauswahl Doctor-Fortschritt vor Slotparität")


func _test_bottleneck_accelerates_only_free_front_body() -> void:
	var fixture := _fixture(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var world: EnemyWorld = fixture.world
	var avatar: TherapyAvatar = fixture.avatar
	var topology: ArenaTopology = fixture.topology
	var first_obstacle := _enemy(
		_focus_definition(), avatar, topology, Vector2(110.0, 0.0),
		0.0, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE
	)
	var second_obstacle := _enemy(
		_focus_definition(), avatar, topology, Vector2(110.0, -72.0),
		0.0, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE
	)
	var orbit_radius := 48.1
	var front := _enemy(
		_small_definition(), avatar, topology,
		first_obstacle.global_position + Vector2.RIGHT.rotated(0.73) * orbit_radius
	)
	var rear := _enemy(
		_small_definition(), avatar, topology,
		first_obstacle.global_position + Vector2.RIGHT * orbit_radius
	)
	var first_handle := world.register_enemy(first_obstacle, true)
	world.register_enemy(second_obstacle, true)
	var front_handle := world.register_enemy(front)
	var rear_handle := world.register_enemy(rear)
	var front_slot := EntityHandle.slot(front_handle)
	var rear_slot := EntityHandle.slot(rear_handle)
	world._flow_lease_handles[front_slot] = first_handle
	world._flow_lease_handles[rear_slot] = first_handle
	world._flow_side_signs[front_slot] = 1
	world._flow_side_signs[rear_slot] = 1
	world._flow_speed_leaders[front_slot] = 1
	world._flow_speed_leaders[rear_slot] = 0
	world._refresh_direct_collision_guards(front_slot, front)
	world._refresh_direct_collision_guards(rear_slot, rear)
	var direct_step := Vector2.LEFT * _small_definition().speed * FIXED_DELTA
	var front_delta := Vector2.ZERO
	var rear_delta := Vector2.ZERO
	for _tick in range(9):
		world._direct_collision_queued[front_slot] = 0
		world._direct_collision_queued[rear_slot] = 1
		front_delta = world._static_flow_desired_delta(front_slot, front, front.global_position, direct_step, FIXED_DELTA, false)
		rear_delta = world._static_flow_desired_delta(rear_slot, rear, rear.global_position, direct_step, FIXED_DELTA, false)
	_equal(float(world._flow_speed_blends[front_slot]), 1.0, "Der freie Vorderkörper blendet den Kanalbonus in 0,15 Sekunden vollständig ein")
	_equal(float(world._flow_speed_blends[rear_slot]), 0.0, "Der aufgestaute Hinterkörper bleibt auf Basistempo")
	_true(front_delta.length() > direct_step.length(), "Nur der freie Vorderkörper wird im Engpass beschleunigt")
	_true(front_delta.length() <= direct_step.length() * 1.25 + 0.001, "Der Kanalbonus bleibt auf 1,25× Basistempo begrenzt")
	_true(rear_delta.length() <= direct_step.length() + 0.001, "Der Hinterkörper erhält keinen versteckten Geschwindigkeitsbonus")
	world._set_flow_obstacle_active(first_handle, first_obstacle, false)
	var second_handle := world.handle_for(second_obstacle)
	world._set_flow_obstacle_active(second_handle, second_obstacle, false)
	var faded_delta := world._static_flow_desired_delta(front_slot, front, front.global_position, direct_step, FIXED_DELTA, false)
	_true(float(world._flow_speed_blends[front_slot]) < 1.0, "Der Kanalbonus blendet nach der Passage kontrolliert aus")
	_true(faded_delta.length() > direct_step.length(), "Das Ausblenden wirkt auch auf die reale Direktbewegung")
	_cleanup_fixture(fixture, [first_obstacle, second_obstacle, front, rear])


func _test_knockback_clears_mover_route_but_not_static_body() -> void:
	var fixture := _fixture(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var world: EnemyWorld = fixture.world
	var avatar: TherapyAvatar = fixture.avatar
	var topology: ArenaTopology = fixture.topology
	var obstacle := _enemy(
		_focus_definition(), avatar, topology, Vector2(110.0, 0.0),
		0.0, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE
	)
	var mover := _enemy(_small_definition(), avatar, topology, Vector2(180.0, 0.0))
	world.register_enemy(obstacle, true)
	var mover_handle := world.register_enemy(mover)
	var mover_slot := EntityHandle.slot(mover_handle)
	for _tick in range(60):
		world.step_fixed(FIXED_DELTA)
		if EntityHandle.is_valid(int(world._flow_lease_handles[mover_slot])):
			break
	_true(EntityHandle.is_valid(int(world._flow_lease_handles[mover_slot])), "Der Rückstoßtest beginnt mit einer aktiven Umlauflease")
	var obstacle_position := obstacle.global_position
	obstacle.apply_knockback(Vector2.RIGHT, 90.0, 0.28, 1.0)
	world.step_fixed(FIXED_DELTA)
	_true(obstacle.global_position.is_equal_approx(obstacle_position), "Ein stationäres Flusshindernis ignoriert Rückstoß")
	_true(not obstacle.is_stunned(), "Rückstoß verwandelt ein stationäres Hindernis nicht in einen Statuskörper")
	mover.apply_knockback(Vector2.RIGHT, 20.0, 0.28, 1.0)
	world.step_fixed(FIXED_DELTA)
	_equal(int(world._flow_lease_handles[mover_slot]), EntityHandle.INVALID, "Rückstoß löscht die Umlauflease eines mobilen Gegners")
	_cleanup_fixture(fixture, [obstacle, mover])


func _test_generation_safe_obstacle_reuse_clears_route() -> void:
	var fixture := _fixture(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var world: EnemyWorld = fixture.world
	var avatar: TherapyAvatar = fixture.avatar
	var topology: ArenaTopology = fixture.topology
	var obstacle := _enemy(
		_focus_definition(), avatar, topology, Vector2(110.0, 0.0),
		0.0, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE
	)
	var mover := _enemy(_small_definition(), avatar, topology, Vector2(180.0, 0.0))
	var old_handle := world.register_enemy(obstacle, true)
	var mover_handle := world.register_enemy(mover)
	var mover_slot := EntityHandle.slot(mover_handle)
	for _tick in range(60):
		world.step_fixed(FIXED_DELTA)
		if EntityHandle.is_valid(int(world._flow_lease_handles[mover_slot])):
			break
	_equal(int(world._flow_lease_handles[mover_slot]), old_handle, "Der mobile Körper besitzt vor Recycling die Zielherdlease")
	_true(world.release(old_handle), "Der Zielherd kann generationensicher freigegeben werden")
	world.flush_deferred()
	_equal(int(world._flow_lease_handles[mover_slot]), EntityHandle.INVALID, "Die Zielherdzerstörung löscht die aktive Lease")
	var replacement := _enemy(_small_definition(), avatar, topology, Vector2(-180.0, 120.0))
	var replacement_handle := world.register_enemy(replacement, true)
	_equal(EntityHandle.slot(replacement_handle), EntityHandle.slot(old_handle), "Der Test verwendet denselben physischen Obstacle-Slot wieder")
	_true(EntityHandle.generation(replacement_handle) != EntityHandle.generation(old_handle), "Obstacle-Recycling erhöht die Generation")
	_true(world.resolve(old_handle) == null, "Der alte Obstacle-Handle bleibt ungültig")
	_true(world.resolve(replacement_handle) == replacement, "Nur die mobile Ersatzgeneration löst auf")
	var replacement_slot := EntityHandle.slot(replacement_handle)
	_equal(int(world._flow_obstacle_bodies[replacement_slot]), 0, "Der wiederverwendete Slot übernimmt keine Hindernisrolle")
	_equal(int(world._flow_obstacle_active[replacement_slot]), 0, "Der wiederverwendete Slot übernimmt keinen Hindernisstatus")
	_true(int(world._flow_lease_handles[mover_slot]) != old_handle, "Die neue Generation übernimmt keine alte Umlauflease")
	_cleanup_fixture(fixture, [obstacle, replacement, mover])


func _test_boss_default_and_explicit_traversal() -> void:
	_assert_boss_obstacle_pass(EnemySpawnRequest.ObstacleTraversal.DEFAULT, false, "Standardboss")
	_assert_boss_obstacle_pass(EnemySpawnRequest.ObstacleTraversal.FLOW_AROUND, true, "Umlauf-Testboss")


func _assert_boss_obstacle_pass(traversal: int, should_flow: bool, label: String) -> void:
	var fixture := _fixture(Rect2(-700.0, -450.0, 1400.0, 900.0))
	var world: EnemyWorld = fixture.world
	var avatar: TherapyAvatar = fixture.avatar
	var topology: ArenaTopology = fixture.topology
	var obstacle := _enemy(
		_focus_definition(), avatar, topology, Vector2(110.0, 0.0),
		0.0, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE
	)
	var boss := _enemy(
		_boss_definition(), avatar, topology, Vector2(250.0, 0.0), 1.0,
		EnemySpawnRequest.BodyRole.MOBILE, traversal
	)
	world.register_enemy(obstacle, true)
	world.register_enemy(boss, true)
	var minimum_spacing := INF
	var maximum_lateral := 0.0
	var reached_doctor := false
	for _tick in range(420):
		world.step_fixed(FIXED_DELTA)
		minimum_spacing = minf(minimum_spacing, topology.distance(boss.global_position, obstacle.global_position))
		maximum_lateral = maxf(maximum_lateral, absf(boss.global_position.y))
		if _at_doctor_contact(boss, avatar, topology):
			reached_doctor = true
			break
	var required_spacing := boss.contact_body_radius() + obstacle.contact_body_radius()
	if should_flow:
		_true(minimum_spacing + POSITION_EPSILON >= required_spacing, "%s respektiert den Zielherdkörper" % label)
		_true(maximum_lateral > 1.0, "%s umläuft den Zielherd sichtbar" % label)
	else:
		_true(minimum_spacing < required_spacing * 0.5, "%s durchquert den Zielherd geradlinig" % label)
		_true(maximum_lateral <= 0.001, "%s erhält keine seitliche Ablenkung" % label)
	_true(reached_doctor, "%s erreicht Doctor Milos" % label)
	_cleanup_fixture(fixture, [obstacle, boss])


func _test_static_only_dead_end_never_waits() -> void:
	var fixture := _fixture(Rect2(-100.0, -100.0, 200.0, 200.0))
	var world: EnemyWorld = fixture.world
	var avatar: TherapyAvatar = fixture.avatar
	var topology: ArenaTopology = fixture.topology
	avatar.global_position = Vector2(-60.0, -60.0)
	var obstacle := _enemy(
		_focus_definition(), avatar, topology, Vector2(47.0, 47.0),
		0.0, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE
	)
	var mover := _enemy(_corner_small_definition(), avatar, topology, Vector2(83.0, 83.0))
	world.register_enemy(obstacle, true)
	var mover_handle := world.register_enemy(mover)
	var mover_slot := EntityHandle.slot(mover_handle)
	var previous_position := mover.global_position
	var fail_open_tick := -1
	var stationary_ticks := 0
	var maximum_step := 0.0
	for tick in range(12):
		world.step_fixed(FIXED_DELTA)
		var moved := mover.global_position.distance_to(previous_position)
		maximum_step = maxf(maximum_step, moved)
		if moved <= POSITION_EPSILON:
			stationary_ticks += 1
		previous_position = mover.global_position
		if int(world._flow_fail_open[mover_slot]) != 0:
			fail_open_tick = tick
			break
	_true(fail_open_tick >= 0 and fail_open_tick <= 4, "Eine ausschließlich statisch geschlossene Route öffnet erst am tatsächlichen Sackgassenkontakt (%d)" % fail_open_tick)
	_equal(stationary_ticks, 0, "Die statische Sackgasse erzeugt vor der Ausfallsicherung keinen Wartetick")
	_true(
		maximum_step <= _corner_small_definition().speed * FIXED_DELTA + POSITION_EPSILON,
		"Die sofortige Ausfallsicherung bleibt ein normaler Schritt und teleportiert nicht"
	)
	for _tick in range(180):
		world.step_fixed(FIXED_DELTA)
		if int(world._flow_fail_open[mover_slot]) == 0:
			break
	_equal(int(world._flow_fail_open[mover_slot]), 0, "Außerhalb aller Objektkörper endet das Durchgleiten wieder")
	_cleanup_fixture(fixture, [obstacle, mover])


func _fixture(bounds: Rect2) -> Dictionary:
	var topology := ArenaTopology.new(bounds, ArenaTopology.BoundaryMode.BOUNDED)
	var avatar := TherapyAvatar.new()
	avatar.configure(bounds, PlayerStats.new(), topology)
	avatar.global_position = Vector2.ZERO
	avatar.velocity = Vector2.ZERO
	var world := EnemyWorld.new().configure_enemy_world(CombatCapacity.defaults())
	world.configure_crowd_collision(topology, avatar, 60.0)
	return {"topology": topology, "avatar": avatar, "world": world}


func _enemy(
	definition: EnemyDefinition,
	avatar: TherapyAvatar,
	topology: ArenaTopology,
	position: Vector2,
	movement_scale: float = 1.0,
	body_role: int = EnemySpawnRequest.BodyRole.MOBILE,
	traversal: int = EnemySpawnRequest.ObstacleTraversal.DEFAULT
) -> InfectionEnemy:
	var enemy := InfectionEnemy.new()
	enemy.configure(
		definition, avatar, topology, 1.0, movement_scale, 1.0,
		PackedInt32Array(), null, 0.0, body_role, traversal
	)
	enemy.spawn_timer = 0.0
	enemy.materialized_emitted = true
	enemy.global_position = position
	enemy.reset_visual_motion()
	return enemy


func _small_definition() -> EnemyDefinition:
	return EnemyDefinition.create(
		&"pneumococcus", "Kleines Bakterium", 22.0, 60.0, 2.0, 1, 18.0, Color.WHITE
	).configure_contact_radius(17.0)


func _cluster_definition() -> EnemyDefinition:
	return EnemyDefinition.create(
		&"bacterial_cluster", "Bakteriengruppe", 74.0, 45.0, 5.0, 4, 30.0, Color.WHITE
	).configure_contact_radius(23.0)


func _corner_small_definition() -> EnemyDefinition:
	return EnemyDefinition.create(
		&"pneumococcus", "Ecktest-Bakterium", 22.0, 60.0, 2.0, 1, 17.0, Color.WHITE
	).configure_contact_radius(17.0)


func _focus_definition() -> EnemyDefinition:
	return EnemyDefinition.create(
		&"minor_focus", "Zielherd", 120.0, 0.0, 0.0, 7, 34.0, Color.WHITE
	).configure_contact_radius(31.0)


func _boss_definition() -> EnemyDefinition:
	return EnemyDefinition.create(
		&"localized_boss", "Testboss", 900.0, 90.0, 6.0, 20, 60.0, Color.WHITE, true
	).configure_contact_radius(47.0)


func _at_doctor_contact(enemy: InfectionEnemy, avatar: TherapyAvatar, topology: ArenaTopology) -> bool:
	return topology.distance(enemy.global_position, avatar.global_position) <= (
		TherapyAvatar.CONTACT_RADIUS + enemy.contact_body_radius() + 0.1
	)


func _cleanup_fixture(fixture: Dictionary, enemies: Array) -> void:
	var world: EnemyWorld = fixture.world
	world.clear()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.free()
	var avatar: TherapyAvatar = fixture.avatar
	avatar.free()


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (%s != %s)" % [message, str(actual), str(expected)])
