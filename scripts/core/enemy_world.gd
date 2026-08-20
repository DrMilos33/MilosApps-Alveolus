class_name EnemyWorld
extends NodeEntityRegistry

var combat_capacity := CombatCapacity.defaults()
var regular_count: int = 0
var critical_count: int = 0
var _critical_by_slot: PackedByteArray = PackedByteArray()
var _typed_enemies: Array[InfectionEnemy] = []
var _typed_runtime_only: bool = true
var _crowd_topology: ArenaTopology
var _crowd_avatar: TherapyAvatar
var _crowd_grid := CombatSpatialGrid.new()
var _crowd_candidates := PackedInt64Array()
var _crowd_nearest_candidates := PackedInt64Array()
var _crowd_nearest_distances := PackedFloat32Array()
var _crowd_constraint_normals := PackedVector2Array()
var _crowd_constraint_limits := PackedFloat32Array()
var _crowd_lane_signs := PackedInt32Array()
var _crowd_lane_holds := PackedInt32Array()
var _crowd_contact_latched := PackedByteArray()
var _crowd_resolved_directions := PackedVector2Array()
var _crowd_resolved_speeds := PackedFloat32Array()
var _contact_ring_owners := PackedInt64Array()
var _contact_ring_claim_starts := PackedInt32Array()
var _contact_ring_claim_spans := PackedInt32Array()
var _contact_ring_wait_starts := PackedInt32Array()
var _contact_ring_wait_ranks := PackedInt32Array()
var _contact_ring_wait_counts := PackedInt32Array()
var _contact_ring_attack_armed := PackedByteArray()
var _contact_ring_reclaim_holds := PackedInt32Array()
var _maximum_body_radius: float = 72.0
var _maximum_crowd_radius: float = 97.2
var _crowd_phase: int = 0
var _contact_ring_active: bool = false
var _contact_ring_stationary_seconds: float = 0.0
var _contact_ring_moving_seconds: float = 0.0
var _crowd_elapsed_seconds: float = 0.0

const AVATAR_SPACING_FACTOR := 1.0
const MAX_CROWD_NEIGHBORS := 6
const MAX_CROWD_QUERY_CANDIDATES := 13
const MAX_AVATAR_NEIGHBORS := 12
const SMALL_ENEMY_ID := &"pneumococcus"
const CROWD_NEIGHBOR_MARGIN := 18.0
const MAX_CROWD_RADIUS_FACTOR := 1.25
const FRONT_PRIORITY_EPSILON := 0.5
const FRONT_ALIGNMENT_MINIMUM := -0.1
const BYPASS_HOLD_UPDATES := 6
const BYPASS_BIAS_MINIMUM := 0.84
const BYPASS_BIAS_MAXIMUM := 1.26
const STATIONARY_AVATAR_SPEED_THRESHOLD := 12.0
const CONTACT_ENTRY_DEPTH := 1.0
const CONTACT_RELEASE_MARGIN := 4.0
const SMALL_AVATAR_YIELD_DEPTH := 2.0
const CROWD_UPDATE_PHASES := 6
const CROWD_GRID_CELL_SIZE := 64.0
const CONTACT_RING_MICRO_SLOTS := 12
const CONTACT_RING_SMALL_SPAN := 2
const CONTACT_RING_CLUSTER_SPAN := 3
const CONTACT_RING_MAX_HARD_BODIES := 2
const CONTACT_RING_STATIONARY_ENTER_SECONDS := 0.25
const CONTACT_RING_MOVING_EXIT_SECONDS := 0.10
const CONTACT_RING_RESERVATION_MARGIN := 150.0
const CONTACT_RING_RESERVATION_RELEASE_MARGIN := 36.0
const CONTACT_RING_WAIT_MARGIN := 4.0
const CONTACT_RING_TARGET_TOLERANCE := 0.9
const CONTACT_RING_ATTACK_ARM_MARGIN := CONTACT_ENTRY_DEPTH + 0.1
const CONTACT_RING_CLAIM_CLEARANCE := 1.0
const CONTACT_RING_RECLAIM_HOLD_UPDATES := 6
const CLUSTER_ENEMY_ID := &"bacterial_cluster"

func configure_enemy_world(runtime_capacity: CombatCapacity = null) -> EnemyWorld:
	combat_capacity = runtime_capacity if runtime_capacity != null else CombatCapacity.defaults()
	super.configure(combat_capacity.max_enemies, &"step_fixed")
	_critical_by_slot.resize(combat_capacity.max_enemies)
	_critical_by_slot.fill(0)
	_typed_enemies.resize(combat_capacity.max_enemies)
	_typed_enemies.fill(null)
	_crowd_lane_signs.resize(combat_capacity.max_enemies)
	_crowd_lane_signs.fill(0)
	_crowd_lane_holds.resize(combat_capacity.max_enemies)
	_crowd_lane_holds.fill(0)
	_crowd_contact_latched.resize(combat_capacity.max_enemies)
	_crowd_contact_latched.fill(0)
	_crowd_resolved_directions.resize(combat_capacity.max_enemies)
	_crowd_resolved_directions.fill(Vector2.ZERO)
	_crowd_resolved_speeds.resize(combat_capacity.max_enemies)
	_crowd_resolved_speeds.fill(1.0)
	_contact_ring_owners.resize(CONTACT_RING_MICRO_SLOTS)
	_contact_ring_owners.fill(EntityHandle.INVALID)
	_contact_ring_claim_starts.resize(combat_capacity.max_enemies)
	_contact_ring_claim_starts.fill(-1)
	_contact_ring_claim_spans.resize(combat_capacity.max_enemies)
	_contact_ring_claim_spans.fill(0)
	_contact_ring_wait_starts.resize(combat_capacity.max_enemies)
	_contact_ring_wait_starts.fill(-1)
	_contact_ring_wait_ranks.resize(combat_capacity.max_enemies)
	_contact_ring_wait_ranks.fill(0)
	_contact_ring_wait_counts.resize(CONTACT_RING_MICRO_SLOTS)
	_contact_ring_wait_counts.fill(0)
	_contact_ring_attack_armed.resize(combat_capacity.max_enemies)
	_contact_ring_attack_armed.fill(0)
	_contact_ring_reclaim_holds.resize(combat_capacity.max_enemies)
	_contact_ring_reclaim_holds.fill(0)
	_typed_runtime_only = true
	regular_count = 0
	critical_count = 0
	_crowd_phase = 0
	_contact_ring_active = false
	_contact_ring_stationary_seconds = 0.0
	_contact_ring_moving_seconds = 0.0
	_crowd_elapsed_seconds = 0.0
	return self


## Enables the central, broad-phase-backed crowd steering pass. Separation is
## folded into locomotion before movement; positions are never repaired after
## the fact, which prevents visible popping in dense survivor-style crowds.
func configure_crowd_collision(
	arena_topology: ArenaTopology,
	avatar_node: TherapyAvatar,
	maximum_body_radius: float = 72.0
) -> EnemyWorld:
	_crowd_topology = arena_topology
	_crowd_avatar = avatar_node
	_maximum_body_radius = maxf(maximum_body_radius, 1.0)
	_maximum_crowd_radius = _maximum_body_radius * MAX_CROWD_RADIUS_FACTOR
	_crowd_grid.configure(arena_topology, CROWD_GRID_CELL_SIZE)
	return self

func register_enemy(enemy: Node, critical: bool = false, disable_automatic_physics: bool = true) -> int:
	if not is_instance_valid(enemy):
		return EntityHandle.INVALID
	var existing := allocated_handle_for(enemy)
	if existing != EntityHandle.INVALID:
		# Logical retirement invalidates targeting immediately, but the Node may
		# only be registered again after its physical lease has been flushed.
		return existing if is_active(existing) else EntityHandle.INVALID
	if not combat_capacity.can_allocate_enemy(regular_count, critical_count, critical):
		return EntityHandle.INVALID
	var handle := _register_new_entity(enemy, disable_automatic_physics)
	if not EntityHandle.is_valid(handle):
		return handle
	var slot := EntityHandle.slot(handle)
	if enemy is InfectionEnemy:
		_typed_enemies[slot] = enemy as InfectionEnemy
	else:
		# Generic test/dynamic entities retain the defensive Callable path.
		_typed_runtime_only = false
	_critical_by_slot[slot] = 1 if critical else 0
	# Lane state is reset only at a new physical lease. The first real blocker
	# selects a side and hysteresis keeps it stable through the complete pass.
	_crowd_lane_signs[slot] = 0
	_crowd_lane_holds[slot] = 0
	_crowd_contact_latched[slot] = 0
	_crowd_resolved_directions[slot] = Vector2.ZERO
	_crowd_resolved_speeds[slot] = 1.0
	_contact_ring_claim_starts[slot] = -1
	_contact_ring_claim_spans[slot] = 0
	_contact_ring_wait_starts[slot] = -1
	_contact_ring_wait_ranks[slot] = 0
	_contact_ring_attack_armed[slot] = 0
	_contact_ring_reclaim_holds[slot] = 0
	if critical:
		critical_count += 1
	else:
		regular_count += 1
	return handle

func register_entity(entity: Node, disable_automatic_physics: bool = true) -> int:
	return register_enemy(entity, false, disable_automatic_physics)

func is_critical(handle: int) -> bool:
	return is_active(handle) and _critical_by_slot[EntityHandle.slot(handle)] != 0


func step_fixed(delta: float, session: RunSession = null) -> void:
	if not _typed_runtime_only:
		super.step_fixed(delta, session)
		return
	if delta <= 0.0:
		flush_deferred()
		return
	_prepare_crowd_steering(delta)
	# Production EnemyWorld leases contain only InfectionEnemy instances. Their
	# renderer and pool are released before a slot can be reused, so this typed
	# dense loop avoids 600 validity checks and dynamic Callable invocations per
	# fixed tick while retaining deterministic slot order.
	var count_at_start := _active_slots.size()
	for dense_index in range(count_at_start):
		var slot := int(_active_slots[dense_index])
		if _retiring[slot] != 0:
			continue
		var enemy := _typed_enemies[slot]
		if enemy != null:
			enemy.step_fixed(delta)
	flush_deferred()


func _prepare_crowd_steering(delta: float) -> void:
	if _crowd_topology == null or not is_instance_valid(_crowd_avatar) or _active_slots.is_empty():
		return
	_crowd_elapsed_seconds += delta
	_update_contact_ring_mode(delta)
	_refresh_contact_ring_claims()
	_prepare_contact_ring_assignments()
	_crowd_grid.clear()
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _retiring[slot] != 0:
			continue
		var enemy := _typed_enemies[slot]
		if enemy == null or not enemy.is_targetable() or enemy.definition == null:
			continue
		_crowd_grid.insert_unique(EntityHandle.make(slot, _generations[slot]), enemy.global_position)

	var strongest_avatar_block := Vector2.ZERO
	var strongest_avatar_overlap := 0.0
	# Resolve a bounded local safe direction rather than applying displacement.
	# Each enemy refreshes at 10 Hz while locomotion remains at 60 Hz. The body
	# closer to the avatar owns the lane; only its follower curves around it. A
	# persistent circulation side and short release hysteresis prevent the
	# left/right replanning that otherwise reads as visible shaking.
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _retiring[slot] != 0:
			continue
		var enemy := _typed_enemies[slot]
		if enemy == null or not enemy.is_targetable() or enemy.definition == null:
			continue
		var avatar_delta := _crowd_topology.shortest_delta(enemy.global_position, _crowd_avatar.global_position)
		var avatar_distance_squared := avatar_delta.length_squared()
		var avatar_distance := sqrt(maxf(avatar_distance_squared, 0.000001))
		var contact_radius := TherapyAvatar.BODY_RADIUS + enemy.definition.radius
		var ring_claimed := _contact_ring_active and _contact_ring_claim_starts[slot] >= 0
		if (
			posmod(slot, CROWD_UPDATE_PHASES) != _crowd_phase
			and not ring_claimed
			and _crowd_contact_latched[slot] == 0
		):
			continue
		_query_nearest_crowd_candidates(
			slot,
			enemy,
			enemy.crowd_radius() + _maximum_crowd_radius + CROWD_NEIGHBOR_MARGIN
		)
		var avatar_chase_direction := avatar_delta.normalized() if avatar_distance_squared > 0.000001 else Vector2.RIGHT
		var chase_direction := avatar_chase_direction
		var lateral_axis := chase_direction.orthogonal()
		var ring_target_active := false
		var ring_target_distance := INF
		var ring_wait_owner_handle := EntityHandle.INVALID
		if _contact_ring_active:
			var ring_target := Vector2.ZERO
			if ring_claimed:
				_contact_ring_wait_starts[slot] = -1
				ring_target = _contact_ring_target_position(
					_contact_ring_claim_starts[slot],
					_contact_ring_claim_spans[slot],
					contact_radius - CONTACT_ENTRY_DEPTH,
					enemy.crowd_radius()
				)
				ring_target_active = true
			else:
				var span := _contact_ring_span(enemy)
				var bearing := _contact_ring_bearing_from_avatar_delta(avatar_delta)
				var wait_start := _contact_ring_wait_starts[slot]
				if wait_start < 0:
					wait_start = _contact_ring_desired_start(span, bearing)
				_contact_ring_wait_starts[slot] = wait_start
				ring_wait_owner_handle = _contact_ring_owner_for_span(wait_start, span)
				if avatar_distance <= contact_radius + CONTACT_RING_RESERVATION_MARGIN + CONTACT_RING_RESERVATION_RELEASE_MARGIN:
					ring_target = _contact_ring_target_position(
						wait_start,
						span,
						_contact_ring_wait_radius(slot, enemy, wait_start, span),
						enemy.crowd_radius()
					)
					ring_target_active = true
			if ring_target_active:
				var target_delta := _crowd_topology.shortest_delta(enemy.global_position, ring_target)
				ring_target_distance = target_delta.length()
				if ring_target_distance > 0.0001:
					chase_direction = target_delta / ring_target_distance
					lateral_axis = chase_direction.orthogonal()
			if ring_claimed and _contact_ring_attack_armed[slot] == 0:
				var contact_step := (
					enemy.definition.speed
					* enemy.speed_multiplier
					* enemy.status_speed_multiplier()
					* delta
				)
				if ring_target_distance <= contact_step + CONTACT_RING_ATTACK_ARM_MARGIN:
					_apply_contact_ring_cooldown(enemy, _contact_ring_claim_starts[slot], _contact_ring_claim_spans[slot])
					_contact_ring_attack_armed[slot] = 1
			if ring_claimed and ring_target_distance <= CONTACT_RING_TARGET_TOLERANCE:
				if _crowd_contact_latched[slot] == 0:
					_crowd_contact_latched[slot] = 1
					if _contact_ring_attack_armed[slot] == 0:
						_apply_contact_ring_cooldown(enemy, _contact_ring_claim_starts[slot], _contact_ring_claim_spans[slot])
						_contact_ring_attack_armed[slot] = 1
		if _crowd_contact_latched[slot] != 0:
			if avatar_distance > contact_radius + CONTACT_RELEASE_MARGIN:
				_crowd_contact_latched[slot] = 0
			elif enemy.definition.id == SMALL_ENEMY_ID and avatar_distance < contact_radius - SMALL_AVATAR_YIELD_DEPTH:
				# Doctor Milos may still push through the smallest bacterium. This is
				# deliberately separate from enemy/enemy avoidance and never changes
				# the lane chosen by the crowd solver.
				var yield_direction := -avatar_chase_direction
				_crowd_resolved_directions[slot] = yield_direction
				_crowd_resolved_speeds[slot] = 1.0
				enemy.set_crowd_steering(
					_crowd_steering_for_direction(avatar_chase_direction, yield_direction),
					1.0
				)
				continue
			else:
				_crowd_resolved_directions[slot] = chase_direction
				_crowd_resolved_speeds[slot] = 0.0
				enemy.set_crowd_steering(Vector2.ZERO, 0.0)
				continue
		var safe_direction := chase_direction
		var neighbor_avoidance_active := false
		var strongest_bypass_proximity := 0.0
		var strongest_bypass_lateral_offset := 0.0
		var current_movement_speed := maxf(
			enemy.definition.speed * enemy.speed_multiplier * enemy.status_speed_multiplier(),
			0.001
		)
		_crowd_constraint_normals.clear()
		_crowd_constraint_limits.clear()
		for other_handle in _crowd_nearest_candidates:
			var other_slot := EntityHandle.slot(other_handle)
			if other_slot < 0 or other_slot == slot or other_slot >= _typed_enemies.size() or _retiring[other_slot] != 0:
				continue
			var other := _typed_enemies[other_slot]
			if other == null or not other.is_targetable() or other.definition == null:
				continue
			if _contact_ring_active:
				if ring_claimed and _contact_ring_claim_starts[other_slot] >= 0:
					continue
				if not ring_claimed and other_handle == ring_wait_owner_handle:
					continue
			var neighbor_delta := _crowd_topology.shortest_delta(enemy.global_position, other.global_position)
			var preferred_distance := enemy.crowd_radius() + other.crowd_radius()
			var influence_distance := preferred_distance + CROWD_NEIGHBOR_MARGIN
			var distance_squared := neighbor_delta.length_squared()
			if distance_squared >= influence_distance * influence_distance:
				continue
			var distance := sqrt(maxf(distance_squared, 0.000001))
			var toward_other := neighbor_delta / distance if distance_squared > 0.000001 else -_overlap_axis(slot, other_slot)
			var clearance := distance - preferred_distance
			var forward_alignment := toward_other.dot(chase_direction)
			var other_avatar_delta := _crowd_topology.shortest_delta(other.global_position, _crowd_avatar.global_position)
			var other_avatar_distance := other_avatar_delta.length()
			var other_has_priority := _crowd_contact_latched[other_slot] != 0
			if not other_has_priority:
				other_has_priority = other_avatar_distance < avatar_distance - FRONT_PRIORITY_EPSILON
			if not other_has_priority and absf(other_avatar_distance - avatar_distance) <= FRONT_PRIORITY_EPSILON:
				other_has_priority = other_slot < slot
			if not other_has_priority or (forward_alignment < FRONT_ALIGNMENT_MINIMUM and clearance >= 0.0):
				# A follower never steers the front line. Equal-depth bodies resolve
				# ownership through their stable slot, so the correction is one-sided.
				continue
			if enemy.definition.is_boss and not other.definition.is_boss:
				continue
			neighbor_avoidance_active = true
			var proximity := clampf(
				(influence_distance - distance) / CROWD_NEIGHBOR_MARGIN,
				0.0,
				1.0
			)
			if proximity > strongest_bypass_proximity:
				strongest_bypass_proximity = proximity
				strongest_bypass_lateral_offset = toward_other.dot(lateral_axis)
			# Resolve relative velocity, not motion against a fictional stationary
			# blocker. Matching the leader's normal component keeps the shell stable;
			# existing overlap adds a small separating component. This lets both bodies
			# continue moving instead of the follower slowly closing the gap.
			var other_normalized_projection := 0.0
			if _crowd_contact_latched[other_slot] == 0 and not other.is_stunned():
				var other_chase_direction := other_avatar_delta.normalized() if other_avatar_distance > 0.0001 else Vector2.RIGHT
				var other_resolved_direction := _crowd_resolved_directions[other_slot]
				if other_resolved_direction.length_squared() <= 0.0001:
					other_resolved_direction = other_chase_direction
				var other_movement_speed := other.definition.speed * other.speed_multiplier * other.status_speed_multiplier()
				other_normalized_projection = (
					other_resolved_direction.dot(toward_other)
					* other_movement_speed * float(_crowd_resolved_speeds[other_slot])
					/ current_movement_speed
				)
			var clearance_fraction := clampf(clearance / CROWD_NEIGHBOR_MARGIN, 0.0, 1.0)
			var allowed_inward_speed := lerpf(other_normalized_projection, 1.0, clearance_fraction)
			if clearance < 0.0:
				allowed_inward_speed -= clampf(-clearance / CROWD_NEIGHBOR_MARGIN, 0.0, 0.45)
			allowed_inward_speed = clampf(allowed_inward_speed, -0.95, 1.0)
			_crowd_constraint_normals.append(toward_other)
			_crowd_constraint_limits.append(allowed_inward_speed)

		# Only the actual front body owns a contact position. A follower already
		# inside the shell must finish its bypass instead of latching into the same
		# space and freezing a visible pile.
		if (
			not _contact_ring_active
			and not neighbor_avoidance_active
			and avatar_distance <= contact_radius - CONTACT_ENTRY_DEPTH
		):
			_crowd_contact_latched[slot] = 1
			_crowd_resolved_directions[slot] = chase_direction
			_crowd_resolved_speeds[slot] = 0.0
			enemy.set_crowd_steering(Vector2.ZERO, 0.0)
			continue

		if neighbor_avoidance_active:
			if _crowd_lane_holds[slot] <= 0:
				# Choose the side away from the first actual blocker, then keep it
				# through the complete pass. A perfectly frontal tie uses the shared
				# circulation direction so followers do not meet head-on.
				_crowd_lane_signs[slot] = -1 if strongest_bypass_lateral_offset > 0.02 else 1
			_crowd_lane_holds[slot] = BYPASS_HOLD_UPDATES
		elif _crowd_lane_holds[slot] > 0:
			_crowd_lane_holds[slot] -= 1
			if _crowd_lane_holds[slot] <= 0:
				_crowd_lane_signs[slot] = 0
		var lane_active := neighbor_avoidance_active or _crowd_lane_holds[slot] > 0
		var lane_sign := _crowd_lane_signs[slot] if _crowd_lane_signs[slot] != 0 else 1
		var preferred_lateral := lateral_axis * float(lane_sign)
		if lane_active:
			var bypass_bias := lerpf(
				BYPASS_BIAS_MINIMUM,
				BYPASS_BIAS_MAXIMUM,
				strongest_bypass_proximity
			)
			safe_direction = (chase_direction + preferred_lateral * bypass_bias).normalized()
		if neighbor_avoidance_active:
			safe_direction = _project_crowd_velocity(safe_direction, preferred_lateral)
		var resolved_speed := 1.0
		if ring_target_active:
			if ring_target_distance <= CONTACT_RING_TARGET_TOLERANCE:
				resolved_speed = 0.0
			else:
				var refresh_steps := 1.0 if ring_claimed else float(CROWD_UPDATE_PHASES)
				resolved_speed = clampf(
					ring_target_distance / maxf(current_movement_speed * delta * refresh_steps, 0.001),
					0.0,
					1.0
				)
		_crowd_resolved_directions[slot] = safe_direction
		_crowd_resolved_speeds[slot] = resolved_speed
		enemy.set_crowd_steering(
			_crowd_steering_for_direction(avatar_chase_direction, safe_direction),
			resolved_speed
		)

	_crowd_phase = (_crowd_phase + 1) % CROWD_UPDATE_PHASES
	_crowd_candidates = _crowd_grid.query_circle_candidates_limited(
		_crowd_avatar.global_position,
		TherapyAvatar.BODY_RADIUS + _maximum_body_radius,
		MAX_AVATAR_NEIGHBORS,
		_crowd_candidates
	)
	for handle in _crowd_candidates:
		var enemy := resolve(handle) as InfectionEnemy
		if enemy == null or not enemy.is_targetable() or enemy.definition == null or enemy.definition.id == SMALL_ENEMY_ID:
			continue
		var avatar_delta := _crowd_topology.shortest_delta(enemy.global_position, _crowd_avatar.global_position)
		var avatar_minimum := (TherapyAvatar.BODY_RADIUS + enemy.definition.radius) * AVATAR_SPACING_FACTOR
		var avatar_distance_squared := avatar_delta.length_squared()
		if avatar_distance_squared >= avatar_minimum * avatar_minimum:
			continue
		var avatar_distance := sqrt(maxf(avatar_distance_squared, 0.000001))
		var avatar_overlap := 1.0 - avatar_distance / maxf(avatar_minimum, 0.001)
		if avatar_overlap <= strongest_avatar_overlap:
			continue
		var toward_avatar := avatar_delta / avatar_distance if avatar_distance_squared > 0.000001 else Vector2.RIGHT
		strongest_avatar_overlap = avatar_overlap
		strongest_avatar_block = -toward_avatar * clampf(avatar_overlap * 1.35, 0.0, 1.0)
	_crowd_avatar.set_crowd_blocking(strongest_avatar_block)


func contact_ring_is_active() -> bool:
	return _contact_ring_active


func contact_ring_claim_count() -> int:
	var count := 0
	for slot in _active_slots:
		if _retiring[slot] == 0 and _contact_ring_claim_starts[slot] >= 0:
			count += 1
	return count


func contact_ring_claim(handle: int) -> Dictionary:
	if not is_active(handle):
		return {}
	var slot := EntityHandle.slot(handle)
	var start := _contact_ring_claim_starts[slot]
	if start < 0:
		return {}
	return {
		"start": start,
		"span": _contact_ring_claim_spans[slot],
		"latched": _crowd_contact_latched[slot] != 0,
	}


func _update_contact_ring_mode(delta: float) -> void:
	var avatar_stationary := (
		_crowd_avatar.velocity.length_squared()
		<= STATIONARY_AVATAR_SPEED_THRESHOLD * STATIONARY_AVATAR_SPEED_THRESHOLD
	)
	if avatar_stationary:
		_contact_ring_stationary_seconds += delta
		_contact_ring_moving_seconds = 0.0
		if not _contact_ring_active and _contact_ring_stationary_seconds >= CONTACT_RING_STATIONARY_ENTER_SECONDS:
			_set_contact_ring_active(true)
	else:
		_contact_ring_stationary_seconds = 0.0
		_contact_ring_moving_seconds += delta
		if _contact_ring_active and _contact_ring_moving_seconds >= CONTACT_RING_MOVING_EXIT_SECONDS:
			_set_contact_ring_active(false)


func _set_contact_ring_active(active: bool) -> void:
	if _contact_ring_active == active:
		return
	_contact_ring_active = active
	_clear_contact_ring_claims()
	for slot_value in _active_slots:
		var slot := int(slot_value)
		_crowd_contact_latched[slot] = 0
		_crowd_lane_signs[slot] = 0
		_crowd_lane_holds[slot] = 0
		_crowd_resolved_directions[slot] = Vector2.ZERO
		_crowd_resolved_speeds[slot] = 1.0
		_contact_ring_wait_starts[slot] = -1
		_contact_ring_wait_ranks[slot] = 0
		_contact_ring_attack_armed[slot] = 0
		var enemy := _typed_enemies[slot]
		if enemy != null:
			enemy.set_crowd_steering(Vector2.ZERO, 1.0)


func _refresh_contact_ring_claims() -> void:
	if not _contact_ring_active:
		return
	for micro_slot in range(CONTACT_RING_MICRO_SLOTS):
		var handle := int(_contact_ring_owners[micro_slot])
		if not EntityHandle.is_valid(handle):
			continue
		var slot := EntityHandle.slot(handle)
		if slot < 0 or slot >= _typed_enemies.size() or _contact_ring_claim_starts[slot] != micro_slot:
			continue
		var enemy := resolve(handle) as InfectionEnemy
		if enemy == null or not enemy.is_targetable() or enemy.definition == null or enemy.is_stunned():
			_release_contact_ring_claim(slot, handle)
			continue
		var avatar_distance := _crowd_topology.distance(enemy.global_position, _crowd_avatar.global_position)
		var contact_radius := TherapyAvatar.BODY_RADIUS + enemy.definition.radius
		var release_distance := (
			contact_radius + CONTACT_RELEASE_MARGIN
			if _crowd_contact_latched[slot] != 0
			else contact_radius + CONTACT_RING_RESERVATION_MARGIN + CONTACT_RING_RESERVATION_RELEASE_MARGIN
		)
		if avatar_distance > release_distance:
			_release_contact_ring_claim(slot, handle)


func _prepare_contact_ring_assignments() -> void:
	if not _contact_ring_active:
		return
	_contact_ring_wait_counts.fill(0)
	for slot_value in _active_slots:
		var slot := int(slot_value)
		_contact_ring_wait_ranks[slot] = 0
		if _retiring[slot] != 0:
			continue
		var enemy := _typed_enemies[slot]
		if enemy == null or not enemy.is_targetable() or enemy.definition == null or enemy.is_stunned():
			continue
		var avatar_delta := _crowd_topology.shortest_delta(enemy.global_position, _crowd_avatar.global_position)
		var avatar_distance := avatar_delta.length()
		var contact_radius := TherapyAvatar.BODY_RADIUS + enemy.definition.radius
		var handle := EntityHandle.make(slot, _generations[slot])
		if _contact_ring_reclaim_holds[slot] > 0:
			_contact_ring_reclaim_holds[slot] -= 1
		if (
			_contact_ring_claim_starts[slot] < 0
			and _contact_ring_reclaim_holds[slot] <= 0
			and avatar_distance <= contact_radius + CONTACT_RING_RESERVATION_MARGIN
		):
			_try_claim_contact_ring(handle, enemy, avatar_delta)
		if _contact_ring_claim_starts[slot] >= 0:
			_contact_ring_wait_starts[slot] = -1
			continue
		var span := _contact_ring_span(enemy)
		if _contact_ring_wait_starts[slot] < 0:
			var desired_wait_start := _contact_ring_desired_start(
				span,
				_contact_ring_bearing_from_avatar_delta(avatar_delta)
			)
			var owner_wait_start := _contact_ring_nearest_owner_start(
				_contact_ring_bearing_from_avatar_delta(avatar_delta)
			)
			_contact_ring_wait_starts[slot] = owner_wait_start if owner_wait_start >= 0 else desired_wait_start
		var wait_start := _contact_ring_wait_starts[slot]
		_contact_ring_wait_ranks[slot] = _contact_ring_wait_counts[wait_start]
		_contact_ring_wait_counts[wait_start] += 1


func _try_claim_contact_ring(handle: int, enemy: InfectionEnemy, avatar_delta: Vector2) -> bool:
	if not EntityHandle.is_valid(handle) or enemy == null or enemy.definition == null:
		return false
	var slot := EntityHandle.slot(handle)
	if _contact_ring_claim_starts[slot] >= 0:
		return true
	if _contact_ring_is_hard_body(enemy) and _contact_ring_hard_claim_count() >= CONTACT_RING_MAX_HARD_BODIES:
		return false
	var span := _contact_ring_span(enemy)
	var bearing := _contact_ring_bearing_from_avatar_delta(avatar_delta)
	var best_start := -1
	var best_distance := INF
	for start in range(CONTACT_RING_MICRO_SLOTS):
		if not _contact_ring_span_is_free(start, span) or not _contact_ring_target_is_clear(enemy, start, span):
			continue
		var distance := _contact_ring_angle_distance(_contact_ring_center_bearing(start, span), bearing)
		if distance < best_distance - 0.0001 or (is_equal_approx(distance, best_distance) and start < best_start):
			best_start = start
			best_distance = distance
	if best_start < 0:
		return false
	for offset in range(span):
		_contact_ring_owners[posmod(best_start + offset, CONTACT_RING_MICRO_SLOTS)] = handle
	_contact_ring_claim_starts[slot] = best_start
	_contact_ring_claim_spans[slot] = span
	_contact_ring_wait_starts[slot] = -1
	_contact_ring_wait_ranks[slot] = 0
	_contact_ring_attack_armed[slot] = 0
	_contact_ring_reclaim_holds[slot] = 0
	return true


func _release_contact_ring_claim(slot: int, handle: int) -> void:
	if slot < 0 or slot >= _contact_ring_claim_starts.size():
		return
	for micro_slot in range(CONTACT_RING_MICRO_SLOTS):
		if int(_contact_ring_owners[micro_slot]) == handle:
			_contact_ring_owners[micro_slot] = EntityHandle.INVALID
	_contact_ring_claim_starts[slot] = -1
	_contact_ring_claim_spans[slot] = 0
	_contact_ring_wait_starts[slot] = -1
	_contact_ring_wait_ranks[slot] = 0
	_contact_ring_attack_armed[slot] = 0
	_contact_ring_reclaim_holds[slot] = CONTACT_RING_RECLAIM_HOLD_UPDATES
	_crowd_contact_latched[slot] = 0
	_crowd_resolved_directions[slot] = Vector2.ZERO
	_crowd_resolved_speeds[slot] = 1.0
	var enemy := resolve(handle) as InfectionEnemy
	if enemy != null:
		enemy.set_crowd_steering(Vector2.ZERO, 1.0)


func _clear_contact_ring_claims() -> void:
	_contact_ring_owners.fill(EntityHandle.INVALID)
	_contact_ring_claim_starts.fill(-1)
	_contact_ring_claim_spans.fill(0)
	_contact_ring_wait_starts.fill(-1)
	_contact_ring_wait_ranks.fill(0)
	_contact_ring_wait_counts.fill(0)
	_contact_ring_attack_armed.fill(0)
	_contact_ring_reclaim_holds.fill(0)


func _contact_ring_span(enemy: InfectionEnemy) -> int:
	match enemy.definition.id:
		SMALL_ENEMY_ID:
			return CONTACT_RING_SMALL_SPAN
		CLUSTER_ENEMY_ID:
			return CONTACT_RING_CLUSTER_SPAN
	var contact_radius := maxf(TherapyAvatar.BODY_RADIUS + enemy.definition.radius, 0.001)
	var radius_ratio := clampf(enemy.crowd_radius() / contact_radius, 0.0, 0.999)
	var angular_diameter := 2.0 * asin(radius_ratio)
	return clampi(ceili(angular_diameter / (TAU / float(CONTACT_RING_MICRO_SLOTS))), 1, CONTACT_RING_MICRO_SLOTS)


func _contact_ring_is_hard_body(enemy: InfectionEnemy) -> bool:
	# Every body larger than the single bacterium shares the same hard cap. This
	# explicitly limits red bacterial clusters to two while bosses, nests and
	# future large definitions cannot silently overbook the remaining ring.
	return enemy.definition.id != SMALL_ENEMY_ID


func _contact_ring_hard_claim_count() -> int:
	var count := 0
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _retiring[slot] != 0 or _contact_ring_claim_starts[slot] < 0:
			continue
		var enemy := _typed_enemies[slot]
		if enemy != null and enemy.definition != null and _contact_ring_is_hard_body(enemy):
			count += 1
	return count


func _contact_ring_span_is_free(start: int, span: int) -> bool:
	for offset in range(span):
		if EntityHandle.is_valid(int(_contact_ring_owners[posmod(start + offset, CONTACT_RING_MICRO_SLOTS)])):
			return false
	return true


func _contact_ring_target_is_clear(enemy: InfectionEnemy, start: int, span: int) -> bool:
	var target := _contact_ring_target_position(
		start,
		span,
		TherapyAvatar.BODY_RADIUS + enemy.definition.radius - CONTACT_ENTRY_DEPTH,
		enemy.crowd_radius()
	)
	for slot_value in _active_slots:
		var other_slot := int(slot_value)
		if _retiring[other_slot] != 0 or _contact_ring_claim_starts[other_slot] < 0:
			continue
		var other := _typed_enemies[other_slot]
		if other == null or other.definition == null:
			continue
		var other_target := _contact_ring_target_position(
			_contact_ring_claim_starts[other_slot],
			_contact_ring_claim_spans[other_slot],
			TherapyAvatar.BODY_RADIUS + other.definition.radius - CONTACT_ENTRY_DEPTH,
			other.crowd_radius()
		)
		var minimum_distance := enemy.crowd_radius() + other.crowd_radius() + CONTACT_RING_CLAIM_CLEARANCE
		if _crowd_topology.distance_squared(target, other_target) < minimum_distance * minimum_distance:
			return false
	return true


func _contact_ring_bearing_from_avatar_delta(avatar_delta: Vector2) -> float:
	return fposmod((-avatar_delta).angle(), TAU) if avatar_delta.length_squared() > 0.000001 else 0.0


func _contact_ring_center_bearing(start: int, span: int) -> float:
	return fposmod(
		(float(start) + float(span) * 0.5) * TAU / float(CONTACT_RING_MICRO_SLOTS),
		TAU
	)


func _contact_ring_angle_distance(first: float, second: float) -> float:
	return absf(fposmod(first - second + PI, TAU) - PI)


func _contact_ring_desired_start(span: int, bearing: float) -> int:
	var scaled := bearing * float(CONTACT_RING_MICRO_SLOTS) / TAU - float(span) * 0.5
	return posmod(roundi(scaled), CONTACT_RING_MICRO_SLOTS)


func _contact_ring_target_position(start: int, span: int, radial_distance: float, body_radius: float) -> Vector2:
	var bearing := _contact_ring_center_bearing(start, span)
	return _crowd_topology.resolve_position(
		_crowd_avatar.global_position + Vector2.from_angle(bearing) * maxf(radial_distance, 1.0),
		body_radius
	)


func _contact_ring_wait_radius(slot: int, enemy: InfectionEnemy, start: int, span: int) -> float:
	var owner_handle := _contact_ring_owner_for_span(start, span)
	var front_radius := TherapyAvatar.BODY_RADIUS + enemy.definition.radius - CONTACT_ENTRY_DEPTH
	var front_crowd_radius := enemy.crowd_radius()
	var owner := resolve(owner_handle) as InfectionEnemy
	if owner != null and owner.definition != null:
		front_radius = TherapyAvatar.BODY_RADIUS + owner.definition.radius - CONTACT_ENTRY_DEPTH
		front_crowd_radius = owner.crowd_radius()
	var queue_rank := _contact_ring_wait_ranks[slot]
	return (
		front_radius
		+ front_crowd_radius
		+ enemy.crowd_radius()
		+ CONTACT_RING_WAIT_MARGIN
		+ float(queue_rank) * (enemy.crowd_radius() * 2.0 + CONTACT_RING_WAIT_MARGIN)
	)


func _contact_ring_owner_for_span(start: int, span: int) -> int:
	for offset in range(span):
		var candidate := int(_contact_ring_owners[posmod(start + offset, CONTACT_RING_MICRO_SLOTS)])
		if EntityHandle.is_valid(candidate):
			return candidate
	return EntityHandle.INVALID


func _contact_ring_nearest_owner_start(bearing: float) -> int:
	var best_start := -1
	var best_distance := INF
	for slot_value in _active_slots:
		var slot := int(slot_value)
		var start := _contact_ring_claim_starts[slot]
		if _retiring[slot] != 0 or start < 0:
			continue
		var distance := _contact_ring_angle_distance(
			_contact_ring_center_bearing(start, _contact_ring_claim_spans[slot]),
			bearing
		)
		if distance < best_distance - 0.0001 or (is_equal_approx(distance, best_distance) and start < best_start):
			best_start = start
			best_distance = distance
	return best_start


func _apply_contact_ring_cooldown(enemy: InfectionEnemy, start: int, span: int) -> void:
	var interval := 0.58 if enemy.definition.is_boss else 0.82
	var phase := _contact_ring_center_bearing(start, span) / TAU * interval
	var remaining := fposmod(phase - fposmod(_crowd_elapsed_seconds, interval), interval)
	enemy.contact_cooldown = maxf(enemy.contact_cooldown, remaining)


func _crowd_steering_for_direction(avatar_direction: Vector2, safe_direction: Vector2) -> Vector2:
	# InfectionEnemy adds this hint to its own avatar-facing direction before it
	# normalizes. Half-strength target intent keeps even an opposite ring target
	# inside the entity's 1.6 steering cap while resolving to the exact direction.
	return safe_direction.normalized() * 0.5 - avatar_direction.normalized()


func _query_nearest_crowd_candidates(slot: int, enemy: InfectionEnemy, search_radius: float) -> void:
	_crowd_candidates = _crowd_grid.query_circle_candidates_limited(
		enemy.global_position,
		search_radius,
		MAX_CROWD_QUERY_CANDIDATES,
		_crowd_candidates
	)
	_crowd_nearest_candidates.clear()
	_crowd_nearest_distances.clear()
	var radius_squared := search_radius * search_radius
	for handle in _crowd_candidates:
		var other_slot := EntityHandle.slot(handle)
		if other_slot < 0 or other_slot == slot or other_slot >= _typed_enemies.size() or _retiring[other_slot] != 0:
			continue
		var other := _typed_enemies[other_slot]
		if other == null or not other.is_targetable() or other.definition == null:
			continue
		var distance_squared := _crowd_topology.shortest_delta(enemy.global_position, other.global_position).length_squared()
		if distance_squared > radius_squared:
			continue
		if _crowd_nearest_candidates.size() < MAX_CROWD_NEIGHBORS:
			_crowd_nearest_candidates.append(handle)
			_crowd_nearest_distances.append(distance_squared)
			continue
		var farthest_index := 0
		var farthest_distance := float(_crowd_nearest_distances[0])
		for index in range(1, _crowd_nearest_distances.size()):
			if _crowd_nearest_distances[index] > farthest_distance:
				farthest_index = index
				farthest_distance = _crowd_nearest_distances[index]
		if distance_squared < farthest_distance:
			_crowd_nearest_candidates[farthest_index] = handle
			_crowd_nearest_distances[farthest_index] = distance_squared


func _project_crowd_velocity(desired_direction: Vector2, preferred_lateral: Vector2) -> Vector2:
	var resolved := desired_direction.normalized()
	# Project once against the constraint that the desired velocity violates the
	# most. Sequentially projecting against several neighbours made the last one
	# win and could reintroduce penetration into the first. The nearest front
	# blocker is the useful navigation boundary; the persistent lateral vector
	# chooses its stable passing side.
	var urgent_index := -1
	var urgent_violation := 0.0
	for constraint_index in range(_crowd_constraint_normals.size()):
		var normal := _crowd_constraint_normals[constraint_index]
		var inward_limit := clampf(float(_crowd_constraint_limits[constraint_index]), -0.95, 1.0)
		var violation := resolved.dot(normal) - inward_limit
		if violation > urgent_violation:
			urgent_violation = violation
			urgent_index = constraint_index
	if urgent_index >= 0:
		var normal := _crowd_constraint_normals[urgent_index]
		var inward_limit := clampf(float(_crowd_constraint_limits[urgent_index]), -0.95, 1.0)
		var tangent := normal.orthogonal()
		if tangent.dot(preferred_lateral) < 0.0:
			tangent = -tangent
		var tangent_length := sqrt(maxf(0.0, 1.0 - inward_limit * inward_limit))
		resolved = (normal * inward_limit + tangent * tangent_length).normalized()
	return resolved


func _overlap_axis(first_slot: int, second_slot: int) -> Vector2:
	var lower := mini(first_slot, second_slot)
	var upper := maxi(first_slot, second_slot)
	var angle := float((lower * 37 + upper * 17 + 23) % 360) * PI / 180.0
	var axis := Vector2.from_angle(angle)
	return axis if first_slot < second_slot else -axis


func _before_slot_released(slot: int, _entity: Node, handle: int) -> void:
	if _contact_ring_claim_starts[slot] >= 0:
		_release_contact_ring_claim(slot, handle)
	_typed_enemies[slot] = null
	_crowd_lane_signs[slot] = 0
	_crowd_lane_holds[slot] = 0
	_crowd_contact_latched[slot] = 0
	_crowd_resolved_directions[slot] = Vector2.ZERO
	_crowd_resolved_speeds[slot] = 1.0
	_contact_ring_claim_starts[slot] = -1
	_contact_ring_claim_spans[slot] = 0
	_contact_ring_wait_starts[slot] = -1
	_contact_ring_wait_ranks[slot] = 0
	_contact_ring_attack_armed[slot] = 0
	_contact_ring_reclaim_holds[slot] = 0
	if _critical_by_slot[slot] != 0:
		critical_count = maxi(0, critical_count - 1)
	else:
		regular_count = maxi(0, regular_count - 1)
	_critical_by_slot[slot] = 0
