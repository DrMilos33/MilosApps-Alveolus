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

var _cells: Array = []
var _occupied_cells: PackedInt32Array = PackedInt32Array()
var _occupied_flags: PackedByteArray = PackedByteArray()
var _visit_stamps: PackedInt32Array = PackedInt32Array()
var _query_stamp: int = 1

func configure(arena_topology: ArenaTopology, requested_cell_size: float = DEFAULT_CELL_SIZE) -> CombatSpatialGrid:
	topology = arena_topology
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

func query_aabb_candidates(rect: Rect2, output: PackedInt64Array = PackedInt64Array()) -> PackedInt64Array:
	return _query_box_candidates(rect.get_center(), rect.size.abs() * 0.5, output)

func cell_count() -> int:
	return _cells.size()

func _query_box_candidates(center: Vector2, half_extent: Vector2, output: PackedInt64Array) -> PackedInt64Array:
	output.clear()
	if _cells.is_empty() or topology == null:
		return output
	_begin_query()
	var wrapped_center := topology.wrap_position(center)
	var local_center := wrapped_center - topology.bounds.position
	var minimum := local_center - half_extent
	var maximum := local_center + half_extent
	var minimum_x := floori(minimum.x / _cell_width)
	var maximum_x := floori(maximum.x / _cell_width)
	var minimum_y := floori(minimum.y / _cell_height)
	var maximum_y := floori(maximum.y / _cell_height)
	var x_count := mini(columns, maximum_x - minimum_x + 1)
	var y_count := mini(rows, maximum_y - minimum_y + 1)
	var x_start := 0 if x_count == columns else minimum_x
	var y_start := 0 if y_count == rows else minimum_y
	for y_offset in range(y_count):
		var raw_y := y_start + y_offset
		for x_offset in range(x_count):
			var raw_x := x_start + x_offset
			var x := posmod(raw_x, columns)
			var y := posmod(raw_y, rows)
			var index := y * columns + x
			if _visit_stamps[index] == _query_stamp:
				continue
			_visit_stamps[index] = _query_stamp
			for handle in _cells[index]:
				output.append(int(handle))
	return output

func _cell_index(position: Vector2) -> int:
	if topology == null:
		return 0
	var local := position - _bounds_position
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
