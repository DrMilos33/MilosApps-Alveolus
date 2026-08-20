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
var _maximum_body_radius: float = 72.0
var _maximum_crowd_radius: float = 97.2
var _crowd_phase: int = 0

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
const BYPASS_BIAS_MINIMUM := 0.9
const BYPASS_BIAS_MAXIMUM := 1.35
const CONTACT_ENTRY_DEPTH := 1.0
const CONTACT_RELEASE_MARGIN := 4.0
const SMALL_AVATAR_YIELD_DEPTH := 2.0
const CROWD_UPDATE_PHASES := 6
const CROWD_GRID_CELL_SIZE := 64.0

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
	_typed_runtime_only = true
	regular_count = 0
	critical_count = 0
	_crowd_phase = 0
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
	_prepare_crowd_steering()
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


func _prepare_crowd_steering() -> void:
	if _crowd_topology == null or not is_instance_valid(_crowd_avatar) or _active_slots.is_empty():
		return
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
		if posmod(slot, CROWD_UPDATE_PHASES) != _crowd_phase:
			continue
		_query_nearest_crowd_candidates(
			slot,
			enemy,
			enemy.crowd_radius() + _maximum_crowd_radius + CROWD_NEIGHBOR_MARGIN
		)
		var avatar_delta := _crowd_topology.shortest_delta(enemy.global_position, _crowd_avatar.global_position)
		var avatar_distance_squared := avatar_delta.length_squared()
		var chase_direction := avatar_delta.normalized() if avatar_distance_squared > 0.000001 else Vector2.RIGHT
		var lateral_axis := chase_direction.orthogonal()
		var avatar_distance := sqrt(maxf(avatar_distance_squared, 0.000001))
		var contact_radius := TherapyAvatar.BODY_RADIUS + enemy.definition.radius
		if _crowd_contact_latched[slot] != 0:
			if avatar_distance > contact_radius + CONTACT_RELEASE_MARGIN:
				_crowd_contact_latched[slot] = 0
			elif enemy.definition.id == SMALL_ENEMY_ID and avatar_distance < contact_radius - SMALL_AVATAR_YIELD_DEPTH:
				# Doctor Milos may still push through the smallest bacterium. This is
				# deliberately separate from enemy/enemy avoidance and never changes
				# the lane chosen by the crowd solver.
				var yield_direction := -chase_direction
				_crowd_resolved_directions[slot] = yield_direction
				_crowd_resolved_speeds[slot] = 1.0
				enemy.set_crowd_steering(yield_direction - chase_direction, 1.0)
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
			var delta := _crowd_topology.shortest_delta(enemy.global_position, other.global_position)
			var preferred_distance := enemy.crowd_radius() + other.crowd_radius()
			var influence_distance := preferred_distance + CROWD_NEIGHBOR_MARGIN
			var distance_squared := delta.length_squared()
			if distance_squared >= influence_distance * influence_distance:
				continue
			var distance := sqrt(maxf(distance_squared, 0.000001))
			var toward_other := delta / distance if distance_squared > 0.000001 else -_overlap_axis(slot, other_slot)
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
		if not neighbor_avoidance_active and avatar_distance <= contact_radius - CONTACT_ENTRY_DEPTH:
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
		_crowd_resolved_directions[slot] = safe_direction
		_crowd_resolved_speeds[slot] = 1.0
		enemy.set_crowd_steering(
			safe_direction - chase_direction,
			1.0
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


func _before_slot_released(slot: int, _entity: Node, _handle: int) -> void:
	_typed_enemies[slot] = null
	_crowd_lane_signs[slot] = 0
	_crowd_lane_holds[slot] = 0
	_crowd_contact_latched[slot] = 0
	_crowd_resolved_directions[slot] = Vector2.ZERO
	_crowd_resolved_speeds[slot] = 1.0
	if _critical_by_slot[slot] != 0:
		critical_count = maxi(0, critical_count - 1)
	else:
		regular_count = maxi(0, regular_count - 1)
	_critical_by_slot[slot] = 0
