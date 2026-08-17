class_name FixedStepCallableSystem
extends RefCounted

## Adapter for incrementally moving existing Game callbacks into RunSession
## phases without making RunSession depend on Game or a scene node.

var callback: Callable
var begin_callback: Callable
var end_callback: Callable
var pass_session: bool = false

func configure(
	step_callback: Callable,
	include_session: bool = false,
	on_begin: Callable = Callable(),
	on_end: Callable = Callable()
) -> FixedStepCallableSystem:
	callback = step_callback
	pass_session = include_session
	begin_callback = on_begin
	end_callback = on_end
	return self

func begin_session(session: RunSession) -> void:
	if begin_callback.is_valid():
		begin_callback.call(session)

func step_fixed(delta: float, session: RunSession) -> void:
	if not callback.is_valid():
		return
	if pass_session:
		callback.call(delta, session)
	else:
		callback.call(delta)

func end_session(session: RunSession) -> void:
	if end_callback.is_valid():
		end_callback.call(session)
