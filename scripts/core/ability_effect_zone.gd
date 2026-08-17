class_name AbilityEffectZone
extends RefCounted

var id: int = 0
var effect_id: StringName
var center: Vector2
var radius: float
var remaining: float
var total_duration: float
var parameters: Dictionary

static func create(zone_id: int, effect: StringName, position: Vector2, area_radius: float, duration: float, values: Dictionary) -> AbilityEffectZone:
	var zone := AbilityEffectZone.new()
	zone.id = zone_id
	zone.effect_id = effect
	zone.center = position
	zone.radius = area_radius
	zone.remaining = maxf(duration, 0.0)
	zone.total_duration = maxf(duration, 0.0)
	zone.parameters = values.duplicate(true)
	return zone

func tick(delta: float) -> bool:
	remaining = maxf(0.0, remaining - maxf(delta, 0.0))
	return remaining > 0.0

func contains(position: Vector2, topology: ArenaTopology) -> bool:
	return topology != null and topology.distance_squared(center, position) <= radius * radius

