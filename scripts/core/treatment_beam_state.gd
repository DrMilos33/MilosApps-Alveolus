class_name TreatmentBeamState
extends RefCounted

## Process-free authoritative state for one persistent treatment beam. The
## world owns phase transitions and damage ticks; renderers consume snapshots.

var handle: int = EntityHandle.INVALID
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var length: float = 0.0
var width: float = 0.0
var damage: float = 0.0
var duration: float = 0.0
var tick_interval: float = 0.25
var return_enabled: bool = false
var source_id: StringName = &""
var phase_elapsed: float = 0.0
var next_tick_at: float = 0.0
var is_return: bool = false


func configure(
	beam_handle: int,
	beam_origin: Vector2,
	beam_direction: Vector2,
	beam_length: float,
	beam_width: float,
	beam_damage: float,
	phase_duration: float,
	interval: float,
	allow_return: bool,
	source: StringName
) -> TreatmentBeamState:
	handle = beam_handle
	origin = beam_origin
	direction = beam_direction.normalized() if beam_direction.length_squared() > 0.0001 else Vector2.RIGHT
	length = maxf(beam_length, 0.0)
	width = maxf(beam_width, 0.0)
	damage = maxf(beam_damage, 0.0)
	duration = maxf(phase_duration, 0.0)
	tick_interval = maxf(interval, 0.0001)
	return_enabled = allow_return
	source_id = source
	phase_elapsed = 0.0
	next_tick_at = 0.0
	is_return = false
	return self


func begin_return() -> bool:
	if is_return or not return_enabled:
		return false
	is_return = true
	phase_elapsed = 0.0
	next_tick_at = 0.0
	return true


func phase_origin(topology: ArenaTopology = null) -> Vector2:
	var value := origin + direction * length if is_return else origin
	return topology.wrap_position(value) if topology != null else value


func phase_direction() -> Vector2:
	return -direction if is_return else direction


func remaining() -> float:
	return maxf(0.0, duration - phase_elapsed)


func snapshot(topology: ArenaTopology = null) -> Dictionary:
	return {
		"handle": handle,
		"origin": phase_origin(topology),
		"direction": phase_direction(),
		"length": length,
		"width": width,
		"damage": damage,
		"duration": duration,
		"elapsed": phase_elapsed,
		"remaining": remaining(),
		"is_return": is_return,
		"source_id": source_id,
	}
