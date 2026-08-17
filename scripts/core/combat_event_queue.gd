class_name CombatEventQueue
extends RefCounted

## Deferred FIFO queue. Events pushed while a flush is in progress stay in the
## pending queue for the next flush, preventing re-entrant mutation of worlds.

class CombatEvent extends RefCounted:
	var sequence: int = 0
	var type: StringName = &""
	var subject_handle: int = EntityHandle.INVALID
	var source_handle: int = EntityHandle.INVALID
	var amount: float = 0.0
	var position: Vector2 = Vector2.ZERO
	var payload: Variant

	func configure(
		next_sequence: int,
		event_type: StringName,
		subject: int,
		source: int,
		event_amount: float,
		event_position: Vector2,
		event_payload: Variant
	) -> void:
		sequence = next_sequence
		type = event_type
		subject_handle = subject
		source_handle = source
		amount = event_amount
		position = event_position
		payload = event_payload

	func reset() -> void:
		sequence = 0
		type = &""
		subject_handle = EntityHandle.INVALID
		source_handle = EntityHandle.INVALID
		amount = 0.0
		position = Vector2.ZERO
		payload = null

var _pending: Array[CombatEvent] = []
var _pool: Array[CombatEvent] = []
var _next_sequence: int = 1

func push(
	type: StringName,
	subject_handle: int = EntityHandle.INVALID,
	source_handle: int = EntityHandle.INVALID,
	amount: float = 0.0,
	position: Vector2 = Vector2.ZERO,
	payload: Variant = null
) -> int:
	if type == &"":
		return 0
	var event: CombatEvent = _pool.pop_back() if not _pool.is_empty() else CombatEvent.new()
	var sequence: int = _next_sequence
	_next_sequence += 1
	event.configure(sequence, type, subject_handle, source_handle, amount, position, payload)
	_pending.append(event)
	return sequence

func pending_count() -> int:
	return _pending.size()

func is_empty() -> bool:
	return _pending.is_empty()

func flush_to(consumer: Callable) -> int:
	if not consumer.is_valid() or _pending.is_empty():
		return 0
	var processing := _pending
	_pending = []
	for event in processing:
		consumer.call(event)
		_release(event)
	return processing.size()

## Transfers ownership to the caller. Call recycle_events() after processing.
func take_all() -> Array[CombatEvent]:
	var result := _pending
	_pending = []
	return result

func recycle_events(events: Array[CombatEvent]) -> void:
	for event in events:
		_release(event)
	events.clear()

func clear() -> void:
	for event in _pending:
		_release(event)
	_pending.clear()

func pooled_count() -> int:
	return _pool.size()

func _release(event: CombatEvent) -> void:
	if event == null:
		return
	event.reset()
	_pool.append(event)
