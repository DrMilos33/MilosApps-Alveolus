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
var _maximum_body_radius: float = 72.0
var _maximum_crowd_radius: float = 97.2
var _crowd_phase: int = 0

const AVATAR_SPACING_FACTOR := 0.84
const MAX_CROWD_NEIGHBORS := 6
const MAX_AVATAR_NEIGHBORS := 12
const SMALL_ENEMY_ID := &"pneumococcus"
const CROWD_NEIGHBOR_MARGIN := 8.0
const CROWD_TIME_HORIZON := 0.70
const MAX_CROWD_RADIUS_FACTOR := 1.25
const APPROACH_LANE_DISTANCE := 340.0
const MAX_APPROACH_BIAS := 0.44
const MIN_BLOCKED_SPEED := 0.08
const DIRECTLY_AHEAD_EPSILON := 0.08
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
	# Resolve a bounded local safe velocity rather than applying displacement.
	# Each enemy refreshes at 10 Hz while locomotion remains at 60 Hz. Rear agents
	# brake behind a body in front, and close pairs choose stable opposing sides.
	# This mirrors reciprocal velocity avoidance without adding 600 server agents.
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _retiring[slot] != 0:
			continue
		var enemy := _typed_enemies[slot]
		if enemy == null or not enemy.is_targetable() or enemy.definition == null:
			continue
		if posmod(slot, 6) != _crowd_phase:
			continue
		_crowd_candidates = _crowd_grid.query_circle_candidates_limited(
			enemy.global_position,
			enemy.crowd_radius() + _maximum_crowd_radius + CROWD_NEIGHBOR_MARGIN,
			MAX_CROWD_NEIGHBORS,
			_crowd_candidates
		)
		var avatar_delta := _crowd_topology.shortest_delta(enemy.global_position, _crowd_avatar.global_position)
		var avatar_distance_squared := avatar_delta.length_squared()
		var chase_direction := avatar_delta.normalized() if avatar_distance_squared > 0.000001 else Vector2.RIGHT
		var desired_speed := enemy.definition.speed * enemy.speed_multiplier * enemy.status_speed_multiplier()
		var desired_velocity := chase_direction * desired_speed
		var lateral_axis := chase_direction.orthogonal()
		var lateral_avoidance := Vector2.ZERO
		var overlap_recovery := Vector2.ZERO
		var avatar_escape := Vector2.ZERO
		var strongest_forward_block := 0.0
		for other_handle in _crowd_candidates:
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
			var forward_alignment := toward_other.dot(chase_direction)
			if forward_alignment > 0.0:
				strongest_forward_block = maxf(
					strongest_forward_block,
					proximity * forward_alignment
				)
			var other_avatar_delta := _crowd_topology.shortest_delta(other.global_position, _crowd_avatar.global_position)
			var other_chase_direction := other_avatar_delta.normalized() if other_avatar_delta.length_squared() > 0.000001 else Vector2.RIGHT
			var other_speed := other.definition.speed * other.speed_multiplier * other.status_speed_multiplier()
			var relative_closing_speed := (desired_velocity - other_chase_direction * other_speed).dot(toward_other)
			var clearance := distance - preferred_distance
			if clearance <= 0.0:
				strongest_forward_block = 1.0
				var penetration_fraction := clampf(-clearance / maxf(preferred_distance, 0.001), 0.0, 1.0)
				overlap_recovery -= toward_other * penetration_fraction * 0.85
			elif relative_closing_speed > 0.0001:
				var collision_risk := clampf(
					1.0 - clearance / (relative_closing_speed * CROWD_TIME_HORIZON),
					0.0,
					1.0
				)
				strongest_forward_block = maxf(strongest_forward_block, collision_risk)
			var side_offset := toward_other.dot(lateral_axis)
			var avoid_side := signf(side_offset)
			if absf(side_offset) <= DIRECTLY_AHEAD_EPSILON:
				avoid_side = 1.0 if slot < other_slot else -1.0
			var importance := 0.35 if enemy.definition.is_boss and not other.definition.is_boss else 1.0
			lateral_avoidance -= lateral_axis * avoid_side * proximity * importance

		var avatar_minimum := (TherapyAvatar.BODY_RADIUS + enemy.definition.radius) * AVATAR_SPACING_FACTOR
		var avatar_arrival_block := clampf(
			(avatar_minimum + CROWD_NEIGHBOR_MARGIN - sqrt(maxf(avatar_distance_squared, 0.000001)))
			/ CROWD_NEIGHBOR_MARGIN,
			0.0,
			1.0
		)
		strongest_forward_block = maxf(strongest_forward_block, avatar_arrival_block)
		if avatar_distance_squared < avatar_minimum * avatar_minimum:
			var avatar_distance := sqrt(maxf(avatar_distance_squared, 0.000001))
			var avatar_overlap := 1.0 - avatar_distance / maxf(avatar_minimum, 0.001)
			var toward_avatar := avatar_delta / avatar_distance if avatar_distance_squared > 0.000001 else Vector2.RIGHT
			if enemy.definition.id == SMALL_ENEMY_ID:
				# Only the smallest bacterium yields when Doctor Milos pushes into it.
				avatar_escape = -toward_avatar * (1.05 + avatar_overlap * 0.25)
		if avatar_distance_squared > 0.000001 and avatar_distance_squared < APPROACH_LANE_DISTANCE * APPROACH_LANE_DISTANCE:
			var avatar_distance := sqrt(avatar_distance_squared)
			var toward_avatar := avatar_delta / avatar_distance
			var lane_strength := 1.0 - avatar_distance / APPROACH_LANE_DISTANCE
			# A stable per-slot lane bias prevents every pursuer from aiming at the
			# exact same center line. It remains subordinate to the chase direction,
			# so enemies still reach contact instead of orbiting indefinitely.
			lateral_avoidance += toward_avatar.orthogonal() * _approach_lane_bias(slot) * lane_strength
		var crowded_speed := lerpf(1.0, MIN_BLOCKED_SPEED, strongest_forward_block)
		enemy.set_crowd_steering(
			lateral_avoidance.limit_length(0.65)
			+ overlap_recovery.limit_length(0.85)
			+ avatar_escape,
			crowded_speed
		)

	_crowd_phase = (_crowd_phase + 1) % 6
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
func _overlap_axis(first_slot: int, second_slot: int) -> Vector2:
	var lower := mini(first_slot, second_slot)
	var upper := maxi(first_slot, second_slot)
	var angle := float((lower * 37 + upper * 17 + 23) % 360) * PI / 180.0
	var axis := Vector2.from_angle(angle)
	return axis if first_slot < second_slot else -axis


func _approach_lane_bias(slot: int) -> float:
	var normalized := float(posmod(slot * 47 + 19, 101)) / 100.0
	return (normalized * 2.0 - 1.0) * MAX_APPROACH_BIAS

func _before_slot_released(slot: int, _entity: Node, _handle: int) -> void:
	_typed_enemies[slot] = null
	if _critical_by_slot[slot] != 0:
		critical_count = maxi(0, critical_count - 1)
	else:
		regular_count = maxi(0, regular_count - 1)
	_critical_by_slot[slot] = 0
