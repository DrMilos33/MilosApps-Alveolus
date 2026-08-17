extends SceneTree

## Generation-safe stress contracts for the reusable runtime foundations.

class TestEntity extends Node:
	var steps := 0
	var world: NodeEntityRegistry
	var handle: int = EntityHandle.INVALID
	var release_on_step := false

	func step_fixed(_delta: float, _session: RunSession = null) -> void:
		steps += 1
		if release_on_step and world != null:
			world.release(handle)

var assertions := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_600_plus_reserve_and_simultaneous_reuse()
	_test_simultaneous_release_during_fixed_step()
	_test_stale_deferred_event_after_slot_reuse()
	_test_session_pause_freezes_registered_world()
	if failures == 0:
		print("ALVEOLUS_RUNTIME_CHURN_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_RUNTIME_CHURN_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)

func _test_600_plus_reserve_and_simultaneous_reuse() -> void:
	var world := EnemyWorld.new().configure_enemy_world()
	var nodes: Array[TestEntity] = []
	var regular_handles := PackedInt64Array()
	for index in range(CombatCapacity.DEFAULT_REGULAR_ENEMIES):
		var entity := TestEntity.new()
		nodes.append(entity)
		regular_handles.append(world.register_enemy(entity))
	_assert_equal(world.regular_count, 600, "World accepts all 600 regular enemies")
	var rejected_regular := TestEntity.new()
	_assert_true(not EntityHandle.is_valid(world.register_enemy(rejected_regular)), "Regular enemy 601 cannot consume the critical reserve")
	rejected_regular.free()
	var critical_handles := PackedInt64Array()
	for index in range(CombatCapacity.DEFAULT_CRITICAL_RESERVE):
		var entity := TestEntity.new()
		nodes.append(entity)
		critical_handles.append(world.register_enemy(entity, true))
	_assert_equal(world.critical_count, 40, "Critical reserve accepts exactly 40 entities")
	_assert_equal(world.active_count(), 640, "Total world capacity is exactly 640")
	var rejected_critical := TestEntity.new()
	_assert_true(not EntityHandle.is_valid(world.register_enemy(rejected_critical, true)), "Entity 641 is rejected without aliasing a slot")
	rejected_critical.free()

	var released := PackedInt64Array()
	for index in range(0, regular_handles.size(), 3):
		var handle := int(regular_handles[index])
		released.append(handle)
		_assert_true(world.release(handle), "Simultaneous release request is accepted")
		_assert_true(world.resolve(handle) == null, "Retiring handle becomes stale immediately")
		var retiring_node: TestEntity = nodes[index]
		_assert_equal(world.allocated_handle_for(retiring_node), handle, "Retiring Node retains its physical lease until flush")
		_assert_true(not EntityHandle.is_valid(world.register_enemy(retiring_node)), "Retiring Node cannot acquire a second registry slot")
	_assert_equal(world.active_count(), 640 - released.size(), "Pending simultaneous deaths leave active count exact")
	_assert_equal(world.flush_deferred(), released.size(), "All simultaneous deaths flush once")
	var reused_slots := {}
	for old_handle in released:
		var replacement := TestEntity.new()
		nodes.append(replacement)
		var new_handle := world.register_enemy(replacement)
		_assert_true(EntityHandle.is_valid(new_handle), "Released capacity is reusable")
		_assert_true(EntityHandle.generation(new_handle) != EntityHandle.generation(int(old_handle)), "Reused slot advances its generation")
		_assert_true(world.resolve(int(old_handle)) == null, "Old handle never resolves to its replacement")
		var slot := EntityHandle.slot(new_handle)
		_assert_true(not reused_slots.has(slot), "A simultaneously freed slot is leased only once")
		reused_slots[slot] = true
	_assert_equal(world.active_count(), 640, "World returns to full capacity after safe reuse")
	world.clear()
	for node in nodes:
		node.free()

func _test_simultaneous_release_during_fixed_step() -> void:
	var world := NodeEntityRegistry.new().configure(120)
	var nodes: Array[TestEntity] = []
	for index in range(120):
		var entity := TestEntity.new()
		entity.world = world
		entity.release_on_step = index % 2 == 0
		entity.handle = world.register_entity(entity)
		nodes.append(entity)
	world.step_fixed(1.0 / 60.0)
	_assert_equal(world.active_count(), 60, "Entities can die simultaneously during one deterministic fixed step")
	for index in range(nodes.size()):
		_assert_equal(nodes[index].steps, 1, "Every entity present at tick start steps at most once")
		if index % 2 == 0:
			_assert_true(world.resolve(nodes[index].handle) == null, "Self-released handle is stale after the tick")
	world.step_fixed(1.0 / 60.0)
	for index in range(nodes.size()):
		_assert_equal(nodes[index].steps, 1 if index % 2 == 0 else 2, "Released entities never step in later ticks")
	world.clear()
	for node in nodes:
		node.free()

func _test_stale_deferred_event_after_slot_reuse() -> void:
	var world := NodeEntityRegistry.new().configure(1)
	var first := TestEntity.new()
	var old_handle := world.register_entity(first)
	var queue := CombatEventQueue.new()
	queue.push(&"damage", old_handle, EntityHandle.INVALID, 12.0)
	world.release(old_handle, false)
	var replacement := TestEntity.new()
	var new_handle := world.register_entity(replacement)
	var resolved_nodes: Array[Node] = []
	queue.flush_to(func(event: CombatEventQueue.CombatEvent) -> void:
		resolved_nodes.append(world.resolve(event.subject_handle))
	)
	_assert_true(EntityHandle.slot(old_handle) == EntityHandle.slot(new_handle), "Deferred-event test actually reuses the same slot")
	_assert_true(EntityHandle.generation(old_handle) != EntityHandle.generation(new_handle), "Deferred-event replacement has a new generation")
	_assert_true(resolved_nodes == [null], "Stale deferred damage cannot target the replacement")
	world.clear()
	first.free()
	replacement.free()

func _test_session_pause_freezes_registered_world() -> void:
	var world := NodeEntityRegistry.new().configure(1)
	var entity := TestEntity.new()
	world.register_entity(entity)
	var session := RunSession.new().configure(null, false)
	_assert_true(session.register_system(world, RunSession.Phase.ENEMY), "Session accepts the reusable world")
	_assert_true(session.start(), "Session starts")
	_assert_true(session.step_fixed(1.0 / 60.0), "Running session advances its world")
	_assert_equal(entity.steps, 1, "World entity advances in running session")
	_assert_true(session.pause_session(), "Session enters explicit pause lifecycle")
	_assert_true(not session.step_fixed(1.0 / 60.0), "Paused session rejects fixed steps")
	_assert_equal(entity.steps, 1, "Pause freezes every registered world entity")
	_assert_true(session.resume_session(), "Session resumes")
	_assert_true(session.step_fixed(1.0 / 60.0), "Resumed session advances again")
	_assert_equal(entity.steps, 2, "Entity advances exactly once after resume")
	session.cancel()
	world.clear()
	entity.free()
	session.free()

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (%s != %s)" % [message, str(actual), str(expected)])

func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)
