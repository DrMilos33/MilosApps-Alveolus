class_name PickupWorld
extends NodeEntityRegistry

var combat_capacity := CombatCapacity.defaults()
var _typed_pickups: Array[AnalysisPickup] = []
var _typed_runtime_only: bool = true

func configure_pickup_world(runtime_capacity: CombatCapacity = null) -> PickupWorld:
	combat_capacity = runtime_capacity if runtime_capacity != null else CombatCapacity.defaults()
	super.configure(combat_capacity.max_pickup_stacks, &"step_fixed")
	_typed_pickups.resize(combat_capacity.max_pickup_stacks)
	_typed_pickups.fill(null)
	_typed_runtime_only = true
	return self

func register_pickup(pickup: Node, disable_automatic_physics: bool = true) -> int:
	var handle := super.register_entity(pickup, disable_automatic_physics)
	if not EntityHandle.is_valid(handle):
		return handle
	if pickup is AnalysisPickup:
		_typed_pickups[EntityHandle.slot(handle)] = pickup as AnalysisPickup
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
		var pickup := _typed_pickups[slot]
		if pickup != null:
			pickup.step_fixed(delta)
	flush_deferred()


func _before_slot_released(slot: int, _entity: Node, _handle: int) -> void:
	_typed_pickups[slot] = null
