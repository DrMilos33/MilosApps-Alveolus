class_name ArenaTopology
extends RefCounted

var bounds: Rect2

func _init(arena_bounds: Rect2 = Rect2()) -> void:
	bounds = arena_bounds

func wrap_position(position: Vector2) -> Vector2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return position
	return Vector2(
		fposmod(position.x - bounds.position.x, bounds.size.x) + bounds.position.x,
		fposmod(position.y - bounds.position.y, bounds.size.y) + bounds.position.y
	)

func wrap_position_if_needed(position: Vector2) -> Vector2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return position
	var wrapped := position
	if wrapped.x < bounds.position.x:
		wrapped.x += bounds.size.x
	elif wrapped.x >= bounds.end.x:
		wrapped.x -= bounds.size.x
	if wrapped.y < bounds.position.y:
		wrapped.y += bounds.size.y
	elif wrapped.y >= bounds.end.y:
		wrapped.y -= bounds.size.y
	return wrapped

func shortest_delta(from: Vector2, to: Vector2) -> Vector2:
	var delta := to - from
	if bounds.size.x > 0.0:
		if delta.x > bounds.size.x * 0.5:
			delta.x -= bounds.size.x
		elif delta.x < -bounds.size.x * 0.5:
			delta.x += bounds.size.x
	if bounds.size.y > 0.0:
		if delta.y > bounds.size.y * 0.5:
			delta.y -= bounds.size.y
		elif delta.y < -bounds.size.y * 0.5:
			delta.y += bounds.size.y
	return delta

func distance_squared(from: Vector2, to: Vector2) -> float:
	return shortest_delta(from, to).length_squared()

func distance(from: Vector2, to: Vector2) -> float:
	return sqrt(distance_squared(from, to))
