class_name RunSession
extends Node

signal session_started(context: Variant)
signal pause_changed(paused: bool)
signal fixed_step_started(tick: int, delta: float)
signal fixed_step_finished(tick: int, delta: float)
signal session_finished(success: bool, reason: String)
signal session_cancelled

enum Lifecycle {
	IDLE,
	RUNNING,
	PAUSED,
	FINISHED,
	CANCELLED,
}

enum Phase {
	INPUT,
	CLOCK,
	SPAWN,
	ENEMY,
	QUERY,
	COMBAT,
	PROJECTILE,
	EVENT,
	SNAPSHOT,
}

var lifecycle: Lifecycle = Lifecycle.IDLE
var context: Variant
var elapsed: float = 0.0
var fixed_tick: int = 0
var auto_step: bool = true
var event_queue := CombatEventQueue.new()
var capacity := CombatCapacity.defaults()

var _systems: Array[Dictionary] = []
var _registration_sequence: int = 0
var _callable_systems: Array[FixedStepCallableSystem] = []

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func configure(runtime_capacity: CombatCapacity = null, automatically_step: bool = true) -> RunSession:
	capacity = runtime_capacity if runtime_capacity != null else CombatCapacity.defaults()
	auto_step = automatically_step
	set_physics_process(auto_step)
	return self

func register_system(system: Object, phase: Phase, order: int = 0) -> bool:
	if system == null or not system.has_method("step_fixed"):
		return false
	_registration_sequence += 1
	_systems.append({"system": system, "phase": int(phase), "order": order, "sequence": _registration_sequence})
	_systems.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.phase) != int(right.phase):
			return int(left.phase) < int(right.phase)
		if int(left.order) != int(right.order):
			return int(left.order) < int(right.order)
		return int(left.sequence) < int(right.sequence)
	)
	return true

func unregister_system(system: Object) -> void:
	for index in range(_systems.size() - 1, -1, -1):
		if _systems[index].system == system:
			_systems.remove_at(index)
	if system is FixedStepCallableSystem:
		_callable_systems.erase(system)

func register_callable(
	callback: Callable,
	phase: Phase,
	order: int = 0,
	pass_session: bool = false,
	begin_callback: Callable = Callable(),
	end_callback: Callable = Callable()
) -> FixedStepCallableSystem:
	if not callback.is_valid():
		return null
	var system := FixedStepCallableSystem.new().configure(callback, pass_session, begin_callback, end_callback)
	if not register_system(system, phase, order):
		return null
	_callable_systems.append(system)
	return system

func start(session_context: Variant = null) -> bool:
	if lifecycle == Lifecycle.RUNNING or lifecycle == Lifecycle.PAUSED:
		return false
	context = session_context
	elapsed = 0.0
	fixed_tick = 0
	event_queue.clear()
	lifecycle = Lifecycle.RUNNING
	for entry in _systems:
		var system: Object = entry.system
		if system.has_method("begin_session"):
			system.call("begin_session", self)
	session_started.emit(context)
	return true

func pause_session() -> bool:
	if lifecycle != Lifecycle.RUNNING:
		return false
	lifecycle = Lifecycle.PAUSED
	pause_changed.emit(true)
	return true

func resume_session() -> bool:
	if lifecycle != Lifecycle.PAUSED:
		return false
	lifecycle = Lifecycle.RUNNING
	pause_changed.emit(false)
	return true

func step_fixed(delta: float) -> bool:
	if lifecycle != Lifecycle.RUNNING or delta <= 0.0:
		return false
	fixed_tick += 1
	elapsed += delta
	fixed_step_started.emit(fixed_tick, delta)
	for entry in _systems:
		(entry.system as Object).call("step_fixed", delta, self)
		if lifecycle != Lifecycle.RUNNING:
			break
	fixed_step_finished.emit(fixed_tick, delta)
	return true

func finish(success: bool, reason: String = "") -> bool:
	if lifecycle != Lifecycle.RUNNING and lifecycle != Lifecycle.PAUSED:
		return false
	_end_systems()
	lifecycle = Lifecycle.FINISHED
	event_queue.clear()
	session_finished.emit(success, reason)
	return true

func cancel() -> bool:
	if lifecycle not in [Lifecycle.RUNNING, Lifecycle.PAUSED]:
		return false
	_end_systems()
	lifecycle = Lifecycle.CANCELLED
	event_queue.clear()
	session_cancelled.emit()
	return true

func reset() -> void:
	if lifecycle in [Lifecycle.RUNNING, Lifecycle.PAUSED]:
		_end_systems()
	event_queue.clear()
	context = null
	elapsed = 0.0
	fixed_tick = 0
	lifecycle = Lifecycle.IDLE

func is_active() -> bool:
	return lifecycle == Lifecycle.RUNNING or lifecycle == Lifecycle.PAUSED

func _physics_process(delta: float) -> void:
	if auto_step:
		step_fixed(delta)

func _end_systems() -> void:
	for entry in _systems:
		var system: Object = entry.system
		if system.has_method("end_session"):
			system.call("end_session", self)
