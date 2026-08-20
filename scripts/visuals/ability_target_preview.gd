class_name AbilityTargetPreview
extends Node2D

## Non-gameplay preview for targeted active abilities. The preview only reads
## resolved build values; applying an ability remains AbilityController's job.

var definition: AbilityDefinition
var build: RunBuildState
var topology: ArenaTopology
var origin: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var reduced_motion: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 9
	hide()


func begin(
	ability: AbilityDefinition,
	build_state: RunBuildState,
	arena_topology: ArenaTopology,
	start: Vector2,
	requested_target: Vector2,
	reduce_motion: bool = false
) -> bool:
	if ability == null or ability.target_mode == AbilityDefinition.TargetMode.SELF:
		return false
	definition = ability
	build = build_state
	topology = arena_topology
	origin = start
	reduced_motion = reduce_motion
	update_target(start, requested_target)
	show()
	return true


func update_target(start: Vector2, requested_target: Vector2) -> void:
	origin = start
	target = topology.wrap_position(requested_target) if topology != null else requested_target
	queue_redraw()


func cancel() -> void:
	definition = null
	build = null
	topology = null
	hide()
	queue_redraw()


func is_targeting() -> bool:
	return definition != null and visible


func resolved_target() -> Vector2:
	return target


func _draw() -> void:
	if definition == null:
		return
	var primary := AlveolusVisualTheme.COBALT
	var secondary := AlveolusVisualTheme.TEAL
	if definition.effect_id == &"defense_burst":
		primary = AlveolusVisualTheme.GOLD
	elif definition.effect_id in [&"focus_field", &"sample_pull"]:
		primary = AlveolusVisualTheme.TEAL
	match definition.target_mode:
		AbilityDefinition.TargetMode.CURSOR_DIRECTION:
			_draw_direction_preview(primary, secondary)
		AbilityDefinition.TargetMode.CURSOR_AREA:
			_draw_area_preview(primary, secondary)


func _draw_area_preview(primary: Color, secondary: Color) -> void:
	var radius := _resolved_value(RunBuildState.ABILITY_RADIUS, "radius", 150.0)
	for center in _wrapped_points(target, radius):
		var local_center := to_local(center)
		draw_circle(local_center, radius, Color(primary, 0.10), true)
		draw_arc(local_center, radius, 0.0, TAU, 64, Color(primary, 0.92), 3.0, true)
		draw_line(local_center - Vector2(12.0, 0.0), local_center + Vector2(12.0, 0.0), Color(secondary, 0.86), 2.0, true)
		draw_line(local_center - Vector2(0.0, 12.0), local_center + Vector2(0.0, 12.0), Color(secondary, 0.86), 2.0, true)


func _draw_direction_preview(primary: Color, secondary: Color) -> void:
	var direction := _shortest_delta(origin, target).normalized()
	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT
	var length := _resolved_value(RunBuildState.ABILITY_RANGE, "range", 620.0)
	length = _visible_line_length(origin, direction, length)
	var width := _resolved_value(RunBuildState.ABILITY_WIDTH, "width", 38.0)
	var endpoint := origin + direction * length
	var perpendicular := Vector2(-direction.y, direction.x) * width * 0.5
	var points := PackedVector2Array([
		to_local(origin + perpendicular),
		to_local(endpoint + perpendicular),
		to_local(endpoint - perpendicular),
		to_local(origin - perpendicular),
	])
	draw_colored_polygon(points, Color(primary, 0.11))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(primary, 0.92), 3.0, true)
	draw_line(to_local(origin), to_local(endpoint), Color(secondary, 0.74), 2.0, true)


func _resolved_value(stat_id: StringName, parameter: String, fallback: float) -> float:
	var base := float(definition.parameters.get(parameter, fallback))
	return build.value(stat_id, base, definition.tags) if build != null else base


func _shortest_delta(from: Vector2, to: Vector2) -> Vector2:
	return topology.shortest_delta(from, to) if topology != null else to - from


func _wrapped_points(position: Vector2, extent: float) -> PackedVector2Array:
	var result := PackedVector2Array([position])
	if topology == null or topology.is_bounded() or topology.bounds.size.x <= 0.0 or topology.bounds.size.y <= 0.0:
		return result
	var x_offsets := PackedFloat32Array([0.0])
	var y_offsets := PackedFloat32Array([0.0])
	if position.x - extent < topology.bounds.position.x:
		x_offsets.append(topology.bounds.size.x)
	if position.x + extent > topology.bounds.end.x:
		x_offsets.append(-topology.bounds.size.x)
	if position.y - extent < topology.bounds.position.y:
		y_offsets.append(topology.bounds.size.y)
	if position.y + extent > topology.bounds.end.y:
		y_offsets.append(-topology.bounds.size.y)
	result.clear()
	for x in x_offsets:
		for y in y_offsets:
			result.append(position + Vector2(x, y))
	return result


func _visible_line_length(start: Vector2, direction: Vector2, requested_length: float) -> float:
	return topology.limit_ray_length(start, direction, requested_length) if topology != null else maxf(requested_length, 0.0)
