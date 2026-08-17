class_name EnemyWorld
extends NodeEntityRegistry

var combat_capacity := CombatCapacity.defaults()
var regular_count: int = 0
var critical_count: int = 0
var _critical_by_slot: PackedByteArray = PackedByteArray()
var _typed_enemies: Array[InfectionEnemy] = []
var _typed_runtime_only: bool = true

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
	flush_deferred()

func _before_slot_released(slot: int, _entity: Node, _handle: int) -> void:
	_typed_enemies[slot] = null
	if _critical_by_slot[slot] != 0:
		critical_count = maxi(0, critical_count - 1)
	else:
		regular_count = maxi(0, regular_count - 1)
	_critical_by_slot[slot] = 0
