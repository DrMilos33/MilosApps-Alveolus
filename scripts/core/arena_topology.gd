class_name ArenaTopology
extends RefCounted

enum BoundaryMode {
	WRAP,
	BOUNDED,
}

var bounds: Rect2
var boundary_mode: int = BoundaryMode.WRAP

func _init(arena_bounds: Rect2 = Rect2(), mode: int = BoundaryMode.WRAP) -> void:
	bounds = arena_bounds
	boundary_mode = BoundaryMode.BOUNDED if mode == BoundaryMode.BOUNDED else BoundaryMode.WRAP

func is_wrapping() -> bool:
	return boundary_mode == BoundaryMode.WRAP

func is_bounded() -> bool:
	return boundary_mode == BoundaryMode.BOUNDED

func resolve_position(position: Vector2, body_radius: float = 0.0) -> Vector2:
	if is_bounded():
		return clamp_position(position, body_radius)
	return _wrapped_position(position)

func wrap_position(position: Vector2) -> Vector2:
	return resolve_position(position)

func _wrapped_position(position: Vector2) -> Vector2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return position
	return Vector2(
		fposmod(position.x - bounds.position.x, bounds.size.x) + bounds.position.x,
		fposmod(position.y - bounds.position.y, bounds.size.y) + bounds.position.y
	)

func wrap_position_if_needed(position: Vector2) -> Vector2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return position
	if is_bounded():
		return clamp_position(position)
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

func clamp_position(position: Vector2, body_radius: float = 0.0) -> Vector2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return position
	var radius := maxf(body_radius, 0.0)
	var minimum := bounds.position + Vector2.ONE * radius
	var maximum := bounds.end - Vector2.ONE * radius
	if minimum.x > maximum.x:
		minimum.x = bounds.get_center().x
		maximum.x = minimum.x
	if minimum.y > maximum.y:
		minimum.y = bounds.get_center().y
		maximum.y = minimum.y
	return Vector2(
		clampf(position.x, minimum.x, maximum.x),
		clampf(position.y, minimum.y, maximum.y)
	)

func contains_position(position: Vector2, body_radius: float = 0.0) -> bool:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return true
	var radius := maxf(body_radius, 0.0)
	var minimum := bounds.position + Vector2.ONE * radius
	var maximum := bounds.end - Vector2.ONE * radius
	var center := bounds.get_center()
	var x_inside := is_equal_approx(position.x, center.x) if minimum.x > maximum.x else position.x >= minimum.x and position.x <= maximum.x
	var y_inside := is_equal_approx(position.y, center.y) if minimum.y > maximum.y else position.y >= minimum.y and position.y <= maximum.y
	return x_inside and y_inside

func limit_ray_length(origin: Vector2, direction: Vector2, requested_length: float) -> float:
	var safe_length := maxf(requested_length, 0.0)
	if safe_length <= 0.0 or is_wrapping() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return safe_length
	if direction.length_squared() <= 0.000001:
		return 0.0
	var start := clamp_position(origin)
	var heading := direction.normalized()
	var boundary_distance := INF
	if heading.x > 0.000001:
		boundary_distance = minf(boundary_distance, (bounds.end.x - start.x) / heading.x)
	elif heading.x < -0.000001:
		boundary_distance = minf(boundary_distance, (bounds.position.x - start.x) / heading.x)
	if heading.y > 0.000001:
		boundary_distance = minf(boundary_distance, (bounds.end.y - start.y) / heading.y)
	elif heading.y < -0.000001:
		boundary_distance = minf(boundary_distance, (bounds.position.y - start.y) / heading.y)
	return minf(safe_length, maxf(boundary_distance, 0.0))

func shortest_delta(from: Vector2, to: Vector2) -> Vector2:
	var delta := to - from
	if is_bounded():
		return delta
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
