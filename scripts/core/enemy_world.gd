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

const ENEMY_SPACING_FACTOR := 0.76
const AVATAR_SPACING_FACTOR := 0.82
const MAX_PAIR_CORRECTION := 7.0
const MAX_AVATAR_CORRECTION := 9.0
const MAX_CROWD_NEIGHBORS := 6
const MAX_AVATAR_NEIGHBORS := 12

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
	return self


## Enables the central, broad-phase-backed soft body blocking pass. Enemies
## retain a little visual overlap so dense crowds flow naturally, while the
## avatar can push through regular bodies slowly instead of being hard-locked.
func configure_crowd_collision(
	arena_topology: ArenaTopology,
	avatar_node: TherapyAvatar,
	maximum_body_radius: float = 72.0
) -> EnemyWorld:
	_crowd_topology = arena_topology
	_crowd_avatar = avatar_node
	_maximum_body_radius = maxf(maximum_body_radius, 1.0)
	_crowd_grid.configure(arena_topology, CombatSpatialGrid.DEFAULT_CELL_SIZE)
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
	_resolve_crowd_collisions()
	flush_deferred()


func _resolve_crowd_collisions() -> void:
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

	# Resolve the nearest local overlap per body in stable slot order. Repeating
	# this bounded pass on fixed ticks separates dense crowds without turning
	# 600 bodies into an O(n²) hot path.
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _retiring[slot] != 0:
			continue
		var enemy := _typed_enemies[slot]
		if enemy == null or not enemy.is_targetable() or enemy.definition == null:
			continue
		_crowd_candidates = _crowd_grid.query_circle_candidates_limited(
			enemy.global_position,
			enemy.definition.radius + _maximum_body_radius,
			MAX_CROWD_NEIGHBORS,
			_crowd_candidates
		)
		var nearest: InfectionEnemy
		var nearest_slot := -1
		var nearest_distance_squared := INF
		for other_handle in _crowd_candidates:
			var other_slot := EntityHandle.slot(other_handle)
			if other_slot < 0 or other_slot == slot or other_slot >= _typed_enemies.size() or _retiring[other_slot] != 0:
				continue
			var other := _typed_enemies[other_slot]
			if other == null or not other.is_targetable() or other.definition == null:
				continue
			var distance_squared := _crowd_topology.shortest_delta(enemy.global_position, other.global_position).length_squared()
			if distance_squared < nearest_distance_squared:
				nearest = other
				nearest_slot = other_slot
				nearest_distance_squared = distance_squared
		if nearest != null:
			_resolve_enemy_neighbor(enemy, nearest, slot, nearest_slot)

	_resolve_avatar_blocking()


func _resolve_enemy_neighbor(first: InfectionEnemy, second: InfectionEnemy, first_slot: int, second_slot: int) -> void:
	var delta := _crowd_topology.shortest_delta(first.global_position, second.global_position)
	var minimum_distance := (first.definition.radius + second.definition.radius) * ENEMY_SPACING_FACTOR
	var distance_squared := delta.length_squared()
	if distance_squared >= minimum_distance * minimum_distance:
		return
	var distance := sqrt(maxf(distance_squared, 0.000001))
	var direction := delta / distance if distance_squared > 0.000001 else Vector2.from_angle(float((first_slot * 37 + second_slot * 17) % 360) * PI / 180.0)
	var correction := minf((minimum_distance - distance) * 0.55, MAX_PAIR_CORRECTION)
	var first_weight := 1.0
	if first.definition.is_boss and not second.definition.is_boss:
		first_weight = 0.18
	first.apply_crowd_correction(-direction * correction * first_weight)


func _resolve_avatar_blocking() -> void:
	_crowd_candidates = _crowd_grid.query_circle_candidates_limited(
		_crowd_avatar.global_position,
		TherapyAvatar.BODY_RADIUS + _maximum_body_radius,
		MAX_AVATAR_NEIGHBORS,
		_crowd_candidates
	)
	for handle in _crowd_candidates:
		var enemy := resolve(handle) as InfectionEnemy
		if enemy == null or not enemy.is_targetable() or enemy.definition == null:
			continue
		var delta := _crowd_topology.shortest_delta(_crowd_avatar.global_position, enemy.global_position)
		var minimum_distance := (TherapyAvatar.BODY_RADIUS + enemy.definition.radius) * AVATAR_SPACING_FACTOR
		var distance_squared := delta.length_squared()
		if distance_squared >= minimum_distance * minimum_distance:
			continue
		var distance := sqrt(maxf(distance_squared, 0.000001))
		var direction := delta / distance if distance_squared > 0.000001 else Vector2.RIGHT
		var correction := minf(minimum_distance - distance, MAX_AVATAR_CORRECTION)
		# Regular enemies yield more than the doctor, preventing effortless passage
		# without turning a dense ring into an immediate movement prison.
		var avatar_share := 0.62 if enemy.definition.is_boss else 0.28
		_crowd_avatar.apply_crowd_correction(-direction * correction * avatar_share)
		enemy.apply_crowd_correction(direction * correction * (1.0 - avatar_share))

func _before_slot_released(slot: int, _entity: Node, _handle: int) -> void:
	_typed_enemies[slot] = null
	if _critical_by_slot[slot] != 0:
		critical_count = maxi(0, critical_count - 1)
	else:
		regular_count = maxi(0, regular_count - 1)
	_critical_by_slot[slot] = 0
