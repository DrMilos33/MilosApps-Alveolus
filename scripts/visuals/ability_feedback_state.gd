class_name AbilityFeedbackState
extends RefCounted

## One pooled, process-free visual event rendered by AbilityFeedbackWorld.

var handle: int = EntityHandle.INVALID
var definition: AbilityFeedbackDefinition
var origin: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var radius: float = 0.0
var length: float = 0.0
var width: float = 0.0
var duration: float = 0.0
var remaining: float = 0.0
var points: PackedVector2Array = PackedVector2Array()


func configure(
	event_handle: int,
	visual_definition: AbilityFeedbackDefinition,
	from: Vector2,
	to: Vector2,
	heading: Vector2,
	area_radius: float,
	line_length: float,
	line_width: float,
	visual_duration: float,
	visual_points: PackedVector2Array = PackedVector2Array()
) -> AbilityFeedbackState:
	handle = event_handle
	definition = visual_definition
	origin = from
	target = to
	direction = heading.normalized() if heading.length_squared() > 0.0001 else Vector2.RIGHT
	radius = maxf(area_radius, 0.0)
	length = maxf(line_length, 0.0)
	width = maxf(line_width, 0.0)
	duration = maxf(visual_duration, 0.001)
	remaining = duration
	points = visual_points.duplicate()
	return self


func progress() -> float:
	return clampf(1.0 - remaining / maxf(duration, 0.001), 0.0, 1.0)
