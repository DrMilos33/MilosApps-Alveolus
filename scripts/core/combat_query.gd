class_name CombatQuery
extends RefCounted

## Torus-aware query facade. Providers allow immediate integration with the
## existing Node runtime and can later point directly at packed world slots.

var topology: ArenaTopology
var grid: CombatSpatialGrid
var position_provider: Callable
var radius_provider: Callable
var targetable_provider: Callable
var resolver: Callable
var maximum_body_radius: float = 0.0
var _prepare_callback: Callable
var _preparing: bool = false

func configure(
	arena_topology: ArenaTopology,
	provide_position: Callable,
	provide_radius: Callable = Callable(),
	provide_targetable: Callable = Callable(),
	resolve_handle: Callable = Callable(),
	cell_size: float = CombatSpatialGrid.DEFAULT_CELL_SIZE,
	max_body_radius: float = 0.0
) -> CombatQuery:
	topology = arena_topology
	position_provider = provide_position
	radius_provider = provide_radius
	targetable_provider = provide_targetable
	resolver = resolve_handle
	maximum_body_radius = maxf(max_body_radius, 0.0)
	grid = CombatSpatialGrid.new().configure(topology, cell_size)
	return self

func set_prepare_callback(callback: Callable) -> CombatQuery:
	_prepare_callback = callback
	return self

func rebuild(handles: PackedInt64Array) -> void:
	if grid != null:
		grid.rebuild(handles, position_provider)

func nearest(center: Vector2, max_range: float, count: int = 1) -> PackedInt64Array:
	var result := PackedInt64Array()
	if not _configured() or count <= 0 or max_range < 0.0:
		return result
	_prepare()
	var candidates := grid.query_circle_candidates(center, max_range + maximum_body_radius)
	var result_distances: Array[float] = []
	for handle in candidates:
		if not _targetable(handle):
			continue
		var center_distance := sqrt(topology.distance_squared(center, _position(handle)))
		var surface_distance := maxf(0.0, center_distance - _radius(handle))
		if surface_distance > max_range:
			continue
		var distance_squared := surface_distance * surface_distance
		var insertion_index := 0
		while insertion_index < result_distances.size() and result_distances[insertion_index] <= distance_squared:
			insertion_index += 1
		if insertion_index >= count:
			continue
		result.insert(insertion_index, handle)
		result_distances.insert(insertion_index, distance_squared)
		if result.size() > count:
			result.resize(count)
			result_distances.resize(count)
	return result

func circle(center: Vector2, radius: float, max_results: int = -1) -> PackedInt64Array:
	var result := PackedInt64Array()
	if not _configured() or radius < 0.0 or max_results == 0:
		return result
	_prepare()
	var candidates := grid.query_circle_candidates(center, radius + maximum_body_radius)
	for handle in candidates:
		if not _targetable(handle):
			continue
		var combined_radius := radius + _radius(handle)
		if topology.distance_squared(center, _position(handle)) <= combined_radius * combined_radius:
			result.append(handle)
			if max_results > 0 and result.size() >= max_results:
				break
	return result

func line(origin: Vector2, heading: Vector2, length: float, half_width: float, max_hits: int = -1) -> PackedInt64Array:
	var result := PackedInt64Array()
	for item in line_hits(origin, heading, length, half_width, max_hits):
		result.append(int(item.handle))
	return result

## Ordered torus-aware line contacts. Besides the stable entity handle, every
## record exposes center-forward, body-surface entry and exit distances. This
## lets a renderer end a ray at exactly the same resolved collision used by
## gameplay, without a second spatial query.
func line_hits(origin: Vector2, heading: Vector2, length: float, half_width: float, max_hits: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _configured() or length < 0.0 or half_width < 0.0 or max_hits == 0:
		return result
	_prepare()
	var direction := heading.normalized() if heading.length_squared() > 0.0001 else Vector2.RIGHT
	var perpendicular := Vector2(-direction.y, direction.x)
	var center := topology.wrap_position(origin + direction * length * 0.5)
	var half_extent := Vector2(
		absf(direction.x) * length * 0.5 + absf(perpendicular.x) * half_width + maximum_body_radius,
		absf(direction.y) * length * 0.5 + absf(perpendicular.y) * half_width + maximum_body_radius
	)
	var candidates := grid.query_aabb_candidates(Rect2(center - half_extent, half_extent * 2.0))
	for handle in candidates:
		if not _targetable(handle):
			continue
		var delta := topology.shortest_delta(origin, _position(handle))
		var forward := delta.dot(direction)
		if forward < 0.0 or forward > length:
			continue
		var lateral := absf(delta.cross(direction))
		var body_radius := _radius(handle)
		var combined_radius := half_width + body_radius
		if lateral > combined_radius:
			continue
		var half_chord := sqrt(maxf(combined_radius * combined_radius - lateral * lateral, 0.0))
		result.append({
			"handle": int(handle),
			"forward": forward,
			"entry_distance": clampf(forward - half_chord, 0.0, length),
			"exit_distance": clampf(forward + half_chord, 0.0, length),
			"body_radius": body_radius,
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_entry := float(left.entry_distance)
		var right_entry := float(right.entry_distance)
		if not is_equal_approx(left_entry, right_entry):
			return left_entry < right_entry
		return int(left.handle) < int(right.handle)
	)
	if max_hits > 0 and result.size() > max_hits:
		result.resize(max_hits)
	return result

func resolve(handle: int) -> Variant:
	return resolver.call(handle) if resolver.is_valid() and EntityHandle.is_valid(handle) else null

func _prepare() -> void:
	if _preparing or not _prepare_callback.is_valid():
		return
	_preparing = true
	_prepare_callback.call()
	_preparing = false

func _configured() -> bool:
	return topology != null and grid != null and position_provider.is_valid()

func _position(handle: int) -> Vector2:
	var value: Variant = position_provider.call(handle)
	return value as Vector2 if typeof(value) == TYPE_VECTOR2 else Vector2.ZERO

func _radius(handle: int) -> float:
	return maxf(float(radius_provider.call(handle)), 0.0) if radius_provider.is_valid() else 0.0

func _targetable(handle: int) -> bool:
	return EntityHandle.is_valid(handle) and (bool(targetable_provider.call(handle)) if targetable_provider.is_valid() else true)
