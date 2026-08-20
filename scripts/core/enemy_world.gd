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
var _maximum_body_radius: float = 72.0
var _maximum_crowd_radius: float = 97.2
var _crowd_phase: int = 0

const AVATAR_SPACING_FACTOR := 1.0
const MAX_CROWD_NEIGHBORS := 6
const MAX_CROWD_QUERY_CANDIDATES := 13
const MAX_AVATAR_NEIGHBORS := 12
const SMALL_ENEMY_ID := &"pneumococcus"
const CROWD_NEIGHBOR_MARGIN := 12.0
const MAX_CROWD_RADIUS_FACTOR := 1.25
const APPROACH_LANE_DISTANCE := 420.0
const MAX_APPROACH_BIAS := 0.62
const CROWD_UPDATE_PHASES := 6
const CROWD_GRID_CELL_SIZE := 64.0

func configure_enemy_world(runtime_capacity: CombatCapacity = null) -> EnemyWorld:
	combat_capacity = runtime_capacity if runtime_capacity != null else CombatCapacity.defaults()
	super.configure(combat_capacity.max_enemies, &"step_fixed")
	_critical_by_slot.resize(combat_capacity.max_enemies)
	_critical_by_slot.fill(0)
	_typed_enemies.resize(combat_capacity.max_enemies)
	_typed_enemies.fill(null)
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
	# Each enemy refreshes at 10 Hz while locomotion remains at 60 Hz. A body
	# behind another ignores it completely; side-by-side bodies split avoidance
	# reciprocally. This keeps the front line stable and lets the rear flow around
	# it at normal movement speed instead of producing a braking queue.
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
		var lane_strength := clampf(1.0 - avatar_distance / APPROACH_LANE_DISTANCE, 0.0, 1.0)
		var safe_direction := (
			chase_direction
			+ lateral_axis * _approach_lane_bias(slot) * lane_strength
		).normalized()
		var neighbor_avoidance_active := false
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
			var proximity := clampf(
				(influence_distance - distance) / CROWD_NEIGHBOR_MARGIN,
				0.0,
				1.0
			)
			proximity = proximity * proximity * (3.0 - 2.0 * proximity)
			var clearance := distance - preferred_distance
			var forward_alignment := toward_other.dot(chase_direction)
			if forward_alignment < -0.15:
				# A body already behind this enemy must not steer the front line.
				continue
			if enemy.definition.is_boss and not other.definition.is_boss:
				continue
			neighbor_avoidance_active = true
			var remaining_clearance := 1.0 - proximity
			var allowed_inward_speed := remaining_clearance * remaining_clearance * remaining_clearance * remaining_clearance
			if clearance <= 0.0:
				allowed_inward_speed = 0.0
			_crowd_constraint_normals.append(toward_other)
			_crowd_constraint_limits.append(allowed_inward_speed)

		var avatar_minimum := (TherapyAvatar.BODY_RADIUS + enemy.definition.radius) * AVATAR_SPACING_FACTOR
		var arrival_speed := clampf(
			(avatar_distance - avatar_minimum) / CROWD_NEIGHBOR_MARGIN,
			0.0,
			1.0
		)
		if avatar_distance_squared < avatar_minimum * avatar_minimum:
			var toward_avatar := avatar_delta / avatar_distance if avatar_distance_squared > 0.000001 else Vector2.RIGHT
			if enemy.definition.id == SMALL_ENEMY_ID:
				# Only the smallest bacterium yields when Doctor Milos pushes into it.
				safe_direction = -toward_avatar
		var avatar_constraint_active := arrival_speed < 0.9999
		if avatar_constraint_active:
			_crowd_constraint_normals.append(chase_direction)
			_crowd_constraint_limits.append(arrival_speed)
		if neighbor_avoidance_active or avatar_constraint_active:
			# Project the final intent, including a small bacterium yielding to the
			# avatar, against both body and avatar-boundary velocity constraints.
			var crowd_velocity := _project_crowd_velocity(safe_direction, lateral_axis)
			var crowd_speed := clampf(crowd_velocity.length(), 0.0, 1.0)
			if crowd_speed > 0.0001:
				safe_direction = crowd_velocity / crowd_speed
			# Full speed is retained whenever any safe tangent exists. Only a body
			# with no geometrically valid route waits behind the ring.
			arrival_speed = crowd_speed
		enemy.set_crowd_steering(
			safe_direction - chase_direction,
			arrival_speed
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


func _project_crowd_velocity(desired_direction: Vector2, lateral_axis: Vector2) -> Vector2:
	var best_direction := desired_direction.normalized()
	var best_speed := -1.0
	var best_preference := -INF
	var urgent_constraint_index := 0
	for index in range(1, _crowd_constraint_limits.size()):
		if _crowd_constraint_limits[index] < _crowd_constraint_limits[urgent_constraint_index]:
			urgent_constraint_index = index
	var urgent_normal := _crowd_constraint_normals[urgent_constraint_index]
	const CANDIDATE_COUNT := 6
	for candidate_index in range(CANDIDATE_COUNT):
		var candidate := desired_direction
		match candidate_index:
			1:
				candidate = lateral_axis
			2:
				candidate = -lateral_axis
			3:
				candidate = urgent_normal.orthogonal()
			4:
				candidate = -urgent_normal.orthogonal()
			5:
				candidate = -urgent_normal
		if candidate.length_squared() <= 0.0001:
			continue
		candidate = candidate.normalized()
		var allowed_speed := 1.0
		for constraint_index in range(_crowd_constraint_normals.size()):
			var inward_component := candidate.dot(_crowd_constraint_normals[constraint_index])
			var inward_limit := float(_crowd_constraint_limits[constraint_index])
			if inward_component > inward_limit + 0.0001:
				allowed_speed = minf(
					allowed_speed,
					inward_limit / maxf(inward_component, 0.0001)
				)
		var preference := candidate.dot(desired_direction) + candidate.dot(lateral_axis) * 0.04
		if allowed_speed > best_speed + 0.0001 or (
			is_equal_approx(allowed_speed, best_speed) and preference > best_preference
		):
			best_direction = candidate
			best_speed = allowed_speed
			best_preference = preference
	return best_direction * clampf(best_speed, 0.0, 1.0)


func _overlap_axis(first_slot: int, second_slot: int) -> Vector2:
	var lower := mini(first_slot, second_slot)
	var upper := maxi(first_slot, second_slot)
	var angle := float((lower * 37 + upper * 17 + 23) % 360) * PI / 180.0
	var axis := Vector2.from_angle(angle)
	return axis if first_slot < second_slot else -axis


func _approach_lane_bias(slot: int) -> float:
	var normalized := float(posmod(slot * 47 + 19, 101)) / 100.0
	# All lanes flow around the avatar in the same direction. Varying only their
	# curvature prevents counter-flow collisions while the spawn sectors still
	# distribute bodies around the full circle.
	return lerpf(0.18, MAX_APPROACH_BIAS, normalized)


func _before_slot_released(slot: int, _entity: Node, _handle: int) -> void:
	_typed_enemies[slot] = null
	if _critical_by_slot[slot] != 0:
		critical_count = maxi(0, critical_count - 1)
	else:
		regular_count = maxi(0, regular_count - 1)
	_critical_by_slot[slot] = 0
