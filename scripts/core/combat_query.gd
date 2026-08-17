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
var maximum_body_radius: float = 96.0
var _prepare_callback: Callable
var _preparing: bool = false

func configure(
	arena_topology: ArenaTopology,
	provide_position: Callable,
	provide_radius: Callable = Callable(),
	provide_targetable: Callable = Callable(),
	resolve_handle: Callable = Callable(),
	cell_size: float = CombatSpatialGrid.DEFAULT_CELL_SIZE,
	max_body_radius: float = 96.0
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
		var distance_squared := topology.distance_squared(center, _position(handle))
		if distance_squared > max_range * max_range:
			continue
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
	var forwards: Array[float] = []
	var bounded_ordered := max_hits > 0 and max_hits < 128
	for handle in candidates:
		if not _targetable(handle):
			continue
		var delta := topology.shortest_delta(origin, _position(handle))
		var forward := delta.dot(direction)
		if forward < 0.0 or forward > length:
			continue
		if absf(delta.cross(direction)) > half_width + _radius(handle):
			continue
		if not bounded_ordered:
			result.append(handle)
			continue
		var insertion_index := 0
		while insertion_index < forwards.size() and forwards[insertion_index] <= forward:
			insertion_index += 1
		if insertion_index >= max_hits:
			continue
		result.insert(insertion_index, handle)
		forwards.insert(insertion_index, forward)
		if result.size() > max_hits:
			result.resize(max_hits)
			forwards.resize(max_hits)
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
