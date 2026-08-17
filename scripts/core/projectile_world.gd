class_name ProjectileWorld
extends NodeEntityRegistry

var combat_capacity := CombatCapacity.defaults()
var _typed_projectiles: Array[TherapyProjectile] = []
var _typed_runtime_only: bool = true

func configure_projectile_world(runtime_capacity: CombatCapacity = null) -> ProjectileWorld:
	combat_capacity = runtime_capacity if runtime_capacity != null else CombatCapacity.defaults()
	super.configure(combat_capacity.max_projectile_states, &"step_fixed")
	_typed_projectiles.resize(combat_capacity.max_projectile_states)
	_typed_projectiles.fill(null)
	_typed_runtime_only = true
	return self

func register_projectile(projectile: Node, disable_automatic_physics: bool = true) -> int:
	var handle := super.register_entity(projectile, disable_automatic_physics)
	if not EntityHandle.is_valid(handle):
		return handle
	if projectile is TherapyProjectile:
		_typed_projectiles[EntityHandle.slot(handle)] = projectile as TherapyProjectile
	else:
		_typed_runtime_only = false
	return handle


func step_fixed(delta: float, session: RunSession = null) -> void:
	if not _typed_runtime_only:
		super.step_fixed(delta, session)
		return
	if delta <= 0.0:
		flush_deferred()
		return
	var count_at_start := _active_slots.size()
	for dense_index in range(count_at_start):
		var slot := int(_active_slots[dense_index])
		if _retiring[slot] != 0:
			continue
		var projectile := _typed_projectiles[slot]
		if projectile != null:
			projectile.step_fixed(delta)
	flush_deferred()


func _before_slot_released(slot: int, _entity: Node, _handle: int) -> void:
	_typed_projectiles[slot] = null
