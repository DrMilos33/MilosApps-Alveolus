class_name CombatSpatialGrid
extends RefCounted

const DEFAULT_CELL_SIZE := 128.0

var topology: ArenaTopology
var cell_size: float = DEFAULT_CELL_SIZE
var columns: int = 1
var rows: int = 1
var _cell_width: float = DEFAULT_CELL_SIZE
var _cell_height: float = DEFAULT_CELL_SIZE
var _bounds_position: Vector2 = Vector2.ZERO
var _bounds_size: Vector2 = Vector2.ONE
var _bounded: bool = false

var _cells: Array = []
var _occupied_cells: PackedInt32Array = PackedInt32Array()
var _occupied_flags: PackedByteArray = PackedByteArray()
var _visit_stamps: PackedInt32Array = PackedInt32Array()
var _query_stamp: int = 1

func configure(arena_topology: ArenaTopology, requested_cell_size: float = DEFAULT_CELL_SIZE) -> CombatSpatialGrid:
	topology = arena_topology
	_bounded = topology != null and topology.is_bounded()
	cell_size = maxf(requested_cell_size, 16.0)
	var size := topology.bounds.size if topology != null else Vector2.ONE * cell_size
	_bounds_position = topology.bounds.position if topology != null else Vector2.ZERO
	_bounds_size = size
	columns = maxi(1, ceili(size.x / cell_size))
	rows = maxi(1, ceili(size.y / cell_size))
	# The arena usually is not an exact multiple of the requested size. Using
	# equal effective cells keeps the final cell from extending past the torus
	# seam and makes seam queries include cell zero correctly.
	_cell_width = size.x / float(columns)
	_cell_height = size.y / float(rows)
	_cells.resize(columns * rows)
	for index in range(_cells.size()):
		_cells[index] = []
	_occupied_cells.clear()
	_occupied_flags.resize(_cells.size())
	_occupied_flags.fill(0)
	_visit_stamps.resize(_cells.size())
	_visit_stamps.fill(0)
	_query_stamp = 1
	return self

func clear() -> void:
	for index in _occupied_cells:
		(_cells[index] as Array).clear()
		_occupied_flags[index] = 0
	_occupied_cells.clear()

func rebuild(handles: PackedInt64Array, position_provider: Callable) -> void:
	clear()
	if not position_provider.is_valid():
		return
	for handle in handles:
		if EntityHandle.is_valid(handle):
			insert_unique(handle, position_provider.call(handle))

func insert(handle: int, position: Vector2) -> void:
	if not EntityHandle.is_valid(handle) or _cells.is_empty():
		return
	var index := _cell_index(position)
	var cell: Array = _cells[index]
	if not cell.has(handle):
		_mark_occupied(index)
		cell.append(handle)

## Fast rebuild path for already unique registry handles.
func insert_unique(handle: int, position: Vector2) -> void:
	if handle == EntityHandle.INVALID or _cells.is_empty():
		return
	var index := _cell_index(position)
	_mark_occupied(index)
	(_cells[index] as Array).append(handle)

func remove(handle: int, previous_position: Vector2) -> void:
	if not EntityHandle.is_valid(handle) or _cells.is_empty():
		return
	(_cells[_cell_index(previous_position)] as Array).erase(handle)

func move(handle: int, previous_position: Vector2, next_position: Vector2) -> void:
	var previous_index := _cell_index(previous_position)
	var next_index := _cell_index(next_position)
	if previous_index == next_index:
		return
	(_cells[previous_index] as Array).erase(handle)
	var next_cell: Array = _cells[next_index]
	if not next_cell.has(handle):
		_mark_occupied(next_index)
		next_cell.append(handle)

func query_circle_candidates(center: Vector2, radius: float, output: PackedInt64Array = PackedInt64Array()) -> PackedInt64Array:
	return _query_box_candidates(center, Vector2.ONE * maxf(radius, 0.0), output)


func query_circle_candidates_limited(
	center: Vector2,
	radius: float,
	maximum_candidates: int,
	output: PackedInt64Array = PackedInt64Array()
) -> PackedInt64Array:
	return _query_box_candidates(center, Vector2.ONE * maxf(radius, 0.0), output, maxi(maximum_candidates, 1))

func query_aabb_candidates(rect: Rect2, output: PackedInt64Array = PackedInt64Array()) -> PackedInt64Array:
	return _query_box_candidates(rect.get_center(), rect.size.abs() * 0.5, output)

func cell_count() -> int:
	return _cells.size()

func _query_box_candidates(center: Vector2, half_extent: Vector2, output: PackedInt64Array, maximum_candidates: int = -1) -> PackedInt64Array:
	output.clear()
	if _cells.is_empty() or topology == null:
		return output
	# Bounded scans never revisit a cell, so wrap-deduplication stamps and the
	# topology method dispatch are unnecessary on the production arena path.
	# WRAP retains the original stamp contract for seam-crossing queries.
	if not _bounded:
		_begin_query()
	var resolved_center := center
	if _bounded:
		if _bounds_size.x > 0.0 and _bounds_size.y > 0.0:
			resolved_center = Vector2(
				clampf(center.x, _bounds_position.x, _bounds_position.x + _bounds_size.x),
				clampf(center.y, _bounds_position.y, _bounds_position.y + _bounds_size.y)
			)
	else:
		resolved_center = topology.resolve_position(center)
	var local_center := resolved_center - topology.bounds.position
	var minimum := local_center - half_extent
	var maximum := local_center + half_extent
	var minimum_x := floori(minimum.x / _cell_width)
	var maximum_x := floori(maximum.x / _cell_width)
	var minimum_y := floori(minimum.y / _cell_height)
	var maximum_y := floori(maximum.y / _cell_height)
	if _bounded:
		minimum_x = clampi(minimum_x, 0, columns - 1)
		maximum_x = clampi(maximum_x, 0, columns - 1)
		minimum_y = clampi(minimum_y, 0, rows - 1)
		maximum_y = clampi(maximum_y, 0, rows - 1)
	if maximum_candidates > 0:
		# Limited broad-phase queries are used by crowd steering. Visit the source
		# cell first and expand in square rings, otherwise a top-left scan can fill
		# the budget with farther bodies while omitting a touching neighbor.
		var center_x := clampi(floori(local_center.x / _cell_width), 0, columns - 1)
		var center_y := clampi(floori(local_center.y / _cell_height), 0, rows - 1)
		var maximum_ring := maxi(
			maxi(absi(minimum_x - center_x), absi(maximum_x - center_x)),
			maxi(absi(minimum_y - center_y), absi(maximum_y - center_y))
		)
		for ring in range(maximum_ring + 1):
			for y_offset in range(-ring, ring + 1):
				for x_offset in range(-ring, ring + 1):
					if maxi(absi(x_offset), absi(y_offset)) != ring:
						continue
					var raw_x := center_x + x_offset
					var raw_y := center_y + y_offset
					if raw_x < minimum_x or raw_x > maximum_x or raw_y < minimum_y or raw_y > maximum_y:
						continue
					if _bounded and (raw_x < 0 or raw_x >= columns or raw_y < 0 or raw_y >= rows):
						continue
					var x := raw_x if _bounded else posmod(raw_x, columns)
					var y := raw_y if _bounded else posmod(raw_y, rows)
					var index := y * columns + x
					if not _bounded:
						if _visit_stamps[index] == _query_stamp:
							continue
						_visit_stamps[index] = _query_stamp
					for handle in _cells[index]:
						output.append(int(handle))
						if output.size() >= maximum_candidates:
							return output
		return output
	var x_count := mini(columns, maximum_x - minimum_x + 1)
	var y_count := mini(rows, maximum_y - minimum_y + 1)
	var x_start := 0 if x_count == columns else minimum_x
	var y_start := 0 if y_count == rows else minimum_y
	if _bounded:
		x_start = clampi(minimum_x, 0, columns - 1)
		y_start = clampi(minimum_y, 0, rows - 1)
		var x_end := clampi(maximum_x, 0, columns - 1)
		var y_end := clampi(maximum_y, 0, rows - 1)
		x_count = maxi(0, x_end - x_start + 1)
		y_count = maxi(0, y_end - y_start + 1)
	for y_offset in range(y_count):
		var raw_y := y_start + y_offset
		for x_offset in range(x_count):
			var raw_x := x_start + x_offset
			var x := raw_x if _bounded else posmod(raw_x, columns)
			var y := raw_y if _bounded else posmod(raw_y, rows)
			var index := y * columns + x
			if not _bounded:
				if _visit_stamps[index] == _query_stamp:
					continue
				_visit_stamps[index] = _query_stamp
			for handle in _cells[index]:
				output.append(int(handle))
				if maximum_candidates > 0 and output.size() >= maximum_candidates:
					return output
	return output

func _cell_index(position: Vector2) -> int:
	if topology == null:
		return 0
	var local := position - _bounds_position
	if _bounded:
		local.x = clampf(local.x, 0.0, _bounds_size.x)
		local.y = clampf(local.y, 0.0, _bounds_size.y)
	else:
		if local.x < 0.0 or local.x >= _bounds_size.x:
			local.x = fposmod(local.x, _bounds_size.x)
		if local.y < 0.0 or local.y >= _bounds_size.y:
			local.y = fposmod(local.y, _bounds_size.y)
	var x := clampi(floori(local.x / _cell_width), 0, columns - 1)
	var y := clampi(floori(local.y / _cell_height), 0, rows - 1)
	return y * columns + x

func _begin_query() -> void:
	_query_stamp += 1
	if _query_stamp >= 2147483647:
		_visit_stamps.fill(0)
		_query_stamp = 1

func _mark_occupied(index: int) -> void:
	if _occupied_flags[index] != 0:
		return
	_occupied_flags[index] = 1
	_occupied_cells.append(index)
