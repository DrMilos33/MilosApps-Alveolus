class_name GameplayZoneState
extends RefCounted

## Process-free authoritative state for a persistent active-ability area.

var handle: int = EntityHandle.INVALID
var effect_id: StringName = &""
var center: Vector2 = Vector2.ZERO
var radius: float = 0.0
var remaining: float = 0.0
var total_duration: float = 0.0
var parameters: Dictionary = {}
var tags: PackedStringArray = PackedStringArray()


func configure(
	zone_handle: int,
	effect: StringName,
	position: Vector2,
	area_radius: float,
	duration: float,
	values: Dictionary,
	context_tags: PackedStringArray = PackedStringArray()
) -> GameplayZoneState:
	handle = zone_handle
	effect_id = effect
	center = position
	radius = maxf(area_radius, 0.0)
	total_duration = maxf(duration, 0.0)
	remaining = total_duration
	parameters = values.duplicate(true)
	tags = context_tags.duplicate()
	return self


func contains(position: Vector2, topology: ArenaTopology) -> bool:
	return topology != null and topology.distance_squared(center, position) <= radius * radius


func progress() -> float:
	if total_duration <= 0.0:
		return 1.0
	return clampf(1.0 - remaining / total_duration, 0.0, 1.0)
