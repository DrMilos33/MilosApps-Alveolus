class_name TalentTreeBranch
extends Control

## One responsive, focusable talent branch. The parent draws dependency lines
## behind regular Button children so the tree remains native Godot UI for mouse,
## keyboard and gamepad input.

const NODE_HEIGHT := 64.0
const ROW_GAP := 20.0
const OUTER_PADDING := 8.0
const MINIMUM_NODE_WIDTH := 104.0
const MAXIMUM_NODE_WIDTH := 164.0

var _nodes: Dictionary = {}
var _layout: Dictionary = {}
var _requirements: Dictionary = {}
var _states: Dictionary = {}
var _maximum_tier: int = 0
var _exit_top: Control
var _exit_left: Control
var _exit_right: Control
var _exit_bottom: Control
var branch_accent: Color = AlveolusVisualTheme.COBALT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_nodes)


func configure_accent(color: Color) -> void:
	branch_accent = color
	queue_redraw()


func add_talent_node(
	id: StringName,
	button: Button,
	tier: int,
	lane: int,
	required_ids: PackedStringArray,
	state: StringName
) -> void:
	if id == &"" or button == null:
		return
	_nodes[id] = button
	_layout[id] = Vector2i(clampi(lane, 0, 2), maxi(0, tier))
	_requirements[id] = required_ids.duplicate()
	_states[id] = state
	_maximum_tier = maxi(_maximum_tier, maxi(0, tier))
	add_child(button)
	custom_minimum_size.y = OUTER_PADDING * 2.0 + float(_maximum_tier + 1) * NODE_HEIGHT + float(_maximum_tier) * ROW_GAP
	_layout_nodes.call_deferred()


func node_count() -> int:
	return _nodes.size()


func edge_count() -> int:
	var count := 0
	for requirements_value in _requirements.values():
		count += (requirements_value as PackedStringArray).size()
	return count


func node_button(id: StringName) -> Button:
	return _nodes.get(id) as Button


func root_button() -> Button:
	var best: Button = null
	var best_tier := 999
	var best_lane_distance := 999
	for id_value in _nodes:
		var coordinates := _layout[id_value] as Vector2i
		var lane_distance := absi(coordinates.x - 1)
		if coordinates.y < best_tier or (coordinates.y == best_tier and lane_distance < best_lane_distance):
			best_tier = coordinates.y
			best_lane_distance = lane_distance
			best = _nodes[id_value] as Button
	return best


func configure_focus_exits(top: Control, left: Control, right: Control, bottom: Control) -> void:
	_exit_top = top
	_exit_left = left
	_exit_right = right
	_exit_bottom = bottom
	_configure_focus_neighbors.call_deferred()


func _layout_nodes() -> void:
	if not is_inside_tree() or size.x <= 0.0 or _nodes.is_empty():
		return
	var usable_width := maxf(1.0, size.x - OUTER_PADDING * 2.0)
	var node_width := clampf((usable_width - 16.0) * 0.5, MINIMUM_NODE_WIDTH, MAXIMUM_NODE_WIDTH)
	var lane_step := maxf(0.0, (usable_width - node_width) * 0.5)
	for id_value in _nodes:
		var id := StringName(id_value)
		var button := _nodes[id] as Button
		var coordinates := _layout[id] as Vector2i
		button.position = Vector2(
			OUTER_PADDING + lane_step * float(coordinates.x),
			OUTER_PADDING + float(coordinates.y) * (NODE_HEIGHT + ROW_GAP)
		)
		button.size = Vector2(node_width, NODE_HEIGHT)
	_configure_focus_neighbors()
	queue_redraw()


func _draw() -> void:
	for child_id_value in _requirements:
		var child_id := StringName(child_id_value)
		var child := _nodes.get(child_id) as Button
		if child == null:
			continue
		for parent_id_value in _requirements[child_id] as PackedStringArray:
			var parent_id := StringName(parent_id_value)
			var parent := _nodes.get(parent_id) as Button
			if parent == null:
				continue
			var start := parent.position + Vector2(parent.size.x * 0.5, parent.size.y)
			var finish := child.position + Vector2(child.size.x * 0.5, 0.0)
			var middle_y := (start.y + finish.y) * 0.5
			var color := _edge_color(child_id)
			draw_polyline(PackedVector2Array([
				start,
				Vector2(start.x, middle_y),
				Vector2(finish.x, middle_y),
				finish,
			]), Color(AlveolusVisualTheme.PETROL_DEEP, 0.86), 4.0, true)
			draw_polyline(PackedVector2Array([
				start,
				Vector2(start.x, middle_y),
				Vector2(finish.x, middle_y),
				finish,
			]), color, 2.0, true)


func _edge_color(child_id: StringName) -> Color:
	match StringName(_states.get(child_id, &"locked")):
		&"active":
			return branch_accent.lerp(AlveolusVisualTheme.TEAL, 0.42)
		&"available":
			return Color(branch_accent, 0.88)
		_:
			return Color(AlveolusVisualTheme.SKY_DEEP, 0.30)


func _configure_focus_neighbors() -> void:
	# Rebuilding the talent view removes the previous branch before queued
	# layout callbacks are flushed. Never derive NodePaths from stale controls.
	if not is_inside_tree():
		return
	for id_value in _nodes:
		var id := StringName(id_value)
		var button := _nodes[id] as Button
		if button == null or not button.is_inside_tree():
			continue
		var coordinates := _layout[id] as Vector2i
		var left := _nearest_in_tier(coordinates.y, coordinates.x, -1)
		var right := _nearest_in_tier(coordinates.y, coordinates.x, 1)
		var parents: PackedStringArray = _requirements.get(id, PackedStringArray())
		var parent := _nodes.get(StringName(parents[0])) as Button if not parents.is_empty() else null
		var child := _first_child(id)
		button.focus_neighbor_left = button.get_path_to(left if left != null else (_exit_left if is_instance_valid(_exit_left) else button))
		button.focus_neighbor_right = button.get_path_to(right if right != null else (_exit_right if is_instance_valid(_exit_right) else button))
		button.focus_neighbor_top = button.get_path_to(parent if parent != null else (_exit_top if is_instance_valid(_exit_top) else button))
		button.focus_neighbor_bottom = button.get_path_to(child if child != null else (_exit_bottom if is_instance_valid(_exit_bottom) else button))


func _nearest_in_tier(tier: int, lane: int, direction: int) -> Button:
	var best: Button = null
	var best_distance := 99
	for id_value in _nodes:
		var coordinates := _layout[id_value] as Vector2i
		if coordinates.y != tier:
			continue
		var delta := coordinates.x - lane
		if signi(delta) != signi(direction):
			continue
		if absi(delta) < best_distance:
			best_distance = absi(delta)
			best = _nodes[id_value] as Button
	return best


func _first_child(parent_id: StringName) -> Button:
	var best: Button = null
	var best_lane_distance := 99
	var parent_coordinates := _layout[parent_id] as Vector2i
	for child_id_value in _requirements:
		var requirements_value := _requirements[child_id_value] as PackedStringArray
		if not requirements_value.has(String(parent_id)):
			continue
		var coordinates := _layout[child_id_value] as Vector2i
		var lane_distance := absi(coordinates.x - parent_coordinates.x)
		if lane_distance < best_lane_distance:
			best_lane_distance = lane_distance
			best = _nodes[child_id_value] as Button
	return best
