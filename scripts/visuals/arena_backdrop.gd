class_name ArenaBackdrop
extends Node2D

## The organic arena contains many polygons and antialiased lines, but it is
## completely static for the lifetime of a configured level. Drawing those
## primitives in the gameplay viewport every frame wastes a large part of the
## Web canvas budget. A private SubViewport renders the exact same draw list
## once; afterwards this CanvasItem submits one textured quad only.
##
## The legacy draw list remains the safe fallback while a bake is pending and
## when a render target cannot be created. The viewport is reused across
## configure() calls and is disabled immediately after its one requested frame.

const MAX_BAKE_DIMENSION := 4096
const TORUS_SEAM_COLOR := Color(0.94, 0.31, 0.34, 0.72)
const TORUS_SEAM_INSET := 6.0
const TORUS_DASH_LENGTH := 22.0
const TORUS_DASH_GAP := 18.0
const TORUS_CORNER_LENGTH := 44.0

class BackdropBakeCanvas:
	extends Node2D

	var draw_callback: Callable

	func _draw() -> void:
		if draw_callback.is_valid():
			draw_callback.call(self)


var arena_bounds: Rect2
var visual: ArenaVisualDefinition
var base_texture: Texture2D
var alveoli: Array[Dictionary] = []
var capillaries: Array[PackedVector2Array] = []
var inflammation_spots: Array[Dictionary] = []
var torus_seam_segments: Array[PackedVector2Array] = []
var torus_corner_segments: Array[PackedVector2Array] = []

var _bake_viewport: SubViewport
var _bake_canvas: BackdropBakeCanvas
var _baked_texture: Texture2D
var _bake_generation: int = 0
var _bake_pending: bool = false
var _bake_ready: bool = false
var _bake_fallback_reason: String = "not_configured"
var _bake_frames_remaining: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if arena_bounds.size != Vector2.ZERO:
		_request_bake(_bake_generation)


func _process(_delta: float) -> void:
	if not _bake_pending:
		set_process(false)
		return
	_bake_frames_remaining -= 1
	if _bake_frames_remaining <= 0:
		_complete_bake(_bake_generation)


func configure(bounds: Rect2, definition: ArenaVisualDefinition) -> void:
	arena_bounds = bounds
	visual = definition
	base_texture = null
	alveoli.clear()
	capillaries.clear()
	inflammation_spots.clear()
	torus_seam_segments.clear()
	torus_corner_segments.clear()
	if visual != null and ResourceLoader.exists(visual.texture_path):
		base_texture = load(visual.texture_path) as Texture2D
	var rng := RandomNumberGenerator.new()
	rng.seed = visual.seed if visual != null else 3101
	for index in range(12):
		var center := Vector2(
			rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y)
		)
		var rx := rng.randf_range(86.0, 178.0)
		var ry := rng.randf_range(62.0, 126.0)
		var points := PackedVector2Array()
		for point_index in range(10):
			var angle := TAU * float(point_index) / 10.0
			var jitter := rng.randf_range(0.82, 1.16)
			points.append(Vector2(cos(angle) * rx, sin(angle) * ry) * jitter)
		alveoli.append({"center": center, "points": points, "rotation": rng.randf_range(-0.35, 0.35)})
	for branch_index in range(5):
		var points := PackedVector2Array()
		var y := rng.randf_range(bounds.position.y, bounds.end.y)
		var phase := rng.randf_range(0.0, TAU)
		for segment in range(12):
			var x := bounds.position.x + bounds.size.x * float(segment) / 11.0
			points.append(Vector2(x, y + sin(phase + float(segment) * 0.83) * rng.randf_range(22.0, 64.0)))
		capillaries.append(points)
	var spot_count := 2 + roundi(visual.inflammation_intensity * 6.0) if visual != null else 2
	for index in range(spot_count):
		inflammation_spots.append({
			"position": Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y)),
			"radius": rng.randf_range(150.0, 310.0)
		})
	_build_torus_seam()

	_bake_generation += 1
	_bake_pending = false
	_bake_ready = false
	_baked_texture = null
	_bake_fallback_reason = "bake_pending"
	queue_redraw()
	if is_inside_tree():
		_request_bake(_bake_generation)


func _draw() -> void:
	if arena_bounds.size == Vector2.ZERO:
		return
	if _bake_ready and _baked_texture != null:
		# One CanvasItem draw command replaces the full static primitive list.
		draw_texture_rect(_baked_texture, arena_bounds, false)
		return
	_draw_backdrop(self)


func _request_bake(generation: int) -> void:
	# Coalesce configure() calls made during one frame. Stale deferred requests
	# are rejected by the generation check in _begin_bake().
	call_deferred("_begin_bake", generation)


func _begin_bake(generation: int) -> void:
	if generation != _bake_generation or arena_bounds.size == Vector2.ZERO:
		return
	var requested_size := Vector2i(ceili(arena_bounds.size.x), ceili(arena_bounds.size.y))
	if requested_size.x <= 0 or requested_size.y <= 0:
		_set_bake_fallback("invalid_size")
		return
	if requested_size.x > MAX_BAKE_DIMENSION or requested_size.y > MAX_BAKE_DIMENSION:
		_set_bake_fallback("size_exceeds_safe_texture_limit")
		return
	if not _ensure_bake_resources():
		_set_bake_fallback("subviewport_unavailable")
		return

	_bake_pending = true
	_bake_ready = false
	_bake_fallback_reason = "bake_pending"
	_bake_viewport.size = requested_size
	_bake_canvas.position = -arena_bounds.position
	_bake_canvas.queue_redraw()
	_bake_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	# Waiting two idle frames guarantees that UPDATE_ONCE received a render
	# opportunity before its texture becomes the main viewport's source. Unlike
	# frame_post_draw this also settles deterministically on headless CI, where
	# rendering signals are intentionally not emitted.
	_bake_frames_remaining = 2
	set_process(true)


func _ensure_bake_resources() -> bool:
	if is_instance_valid(_bake_viewport) and is_instance_valid(_bake_canvas):
		return true
	_bake_viewport = SubViewport.new()
	if _bake_viewport == null:
		return false
	_bake_viewport.name = "StaticArenaBakeViewport"
	_bake_viewport.disable_3d = true
	_bake_viewport.transparent_bg = false
	_bake_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_bake_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Never inherit the gameplay world: otherwise a reconfigure during a run
	# could accidentally bake enemies or effects into the arena texture.
	_bake_viewport.world_2d = World2D.new()
	_bake_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bake_viewport)

	_bake_canvas = BackdropBakeCanvas.new()
	_bake_canvas.name = "StaticArenaBakeCanvas"
	_bake_canvas.draw_callback = _draw_backdrop
	_bake_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	_bake_viewport.add_child(_bake_canvas)
	return is_instance_valid(_bake_viewport.get_texture())


func _complete_bake(generation: int) -> void:
	if generation != _bake_generation or not is_instance_valid(_bake_viewport):
		return
	# UPDATE_ONCE normally disables itself after the rendered frame. Set it
	# explicitly as part of the contract so Web and native cannot keep updating.
	_bake_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var viewport_texture := _bake_viewport.get_texture()
	var expected_size := Vector2i(ceili(arena_bounds.size.x), ceili(arena_bounds.size.y))
	if viewport_texture == null or viewport_texture.get_size() != Vector2(expected_size):
		_set_bake_fallback("render_target_capture_failed")
		return
	_baked_texture = viewport_texture
	_bake_pending = false
	_bake_ready = true
	_bake_fallback_reason = ""
	set_process(false)
	queue_redraw()


func _set_bake_fallback(reason: String) -> void:
	if is_instance_valid(_bake_viewport):
		_bake_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_bake_pending = false
	_bake_ready = false
	_baked_texture = null
	_bake_fallback_reason = reason
	_bake_frames_remaining = 0
	set_process(false)
	queue_redraw()


func bake_state_snapshot() -> Dictionary:
	## Small read-only QA surface for regression tests and diagnostics.
	return {
		"generation": _bake_generation,
		"level_id": visual.level_id if visual != null else &"",
		"seed": visual.seed if visual != null else 0,
		"pending": _bake_pending,
		"ready": _bake_ready,
		"fallback_reason": _bake_fallback_reason,
		"arena_size": arena_bounds.size,
		"texture_size": _baked_texture.get_size() if _baked_texture != null else Vector2.ZERO,
		"viewport_size": Vector2(_bake_viewport.size) if is_instance_valid(_bake_viewport) else Vector2.ZERO,
		"viewport_updates": _bake_viewport.render_target_update_mode if is_instance_valid(_bake_viewport) else SubViewport.UPDATE_DISABLED,
		"viewport_instance_id": _bake_viewport.get_instance_id() if is_instance_valid(_bake_viewport) else 0,
		"canvas_instance_id": _bake_canvas.get_instance_id() if is_instance_valid(_bake_canvas) else 0,
		"seam_segment_count": torus_seam_segments.size(),
		"corner_segment_count": torus_corner_segments.size(),
	}


func _draw_backdrop(target: CanvasItem) -> void:
	var base := visual.base_color if visual != null else Color("10252b")
	target.draw_rect(arena_bounds, base, true)
	if base_texture != null:
		target.draw_texture_rect(base_texture, arena_bounds, true, Color(1.0, 1.0, 1.0, 0.52))
	var tissue := visual.tissue_color if visual != null else Color("23484b")
	var membrane := visual.membrane_color if visual != null else Color("779a91")
	for alveolus in alveoli:
		for offset in _wrapped_draw_offsets(alveolus["center"], 190.0):
			target.draw_set_transform(alveolus["center"] + offset, alveolus["rotation"], Vector2.ONE)
			target.draw_colored_polygon(alveolus["points"], Color(tissue, 0.075))
			target.draw_polyline(_closed(alveolus["points"]), Color(membrane, 0.10), 3.0, true)
			target.draw_polyline(_inner_outline(alveolus["points"]), Color(membrane.lightened(0.12), 0.055), 1.0, true)
	target.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var capillary := visual.capillary_color if visual != null else Color("492a33")
	for points in capillaries:
		target.draw_polyline(points, Color(capillary, 0.18), 5.0, true)
		target.draw_polyline(points, Color(capillary.lightened(0.20), 0.10), 1.5, true)
	var inflammation := visual.inflammation_color if visual != null else Color("a85e68")
	var strength := visual.inflammation_intensity if visual != null else 0.12
	for spot in inflammation_spots:
		for offset in _wrapped_draw_offsets(spot["position"], spot["radius"]):
			target.draw_circle(spot["position"] + offset, spot["radius"], Color(inflammation, 0.022 + strength * 0.030))
			target.draw_circle(spot["position"] + offset, spot["radius"] * 0.56, Color(inflammation, 0.018 + strength * 0.028))
	# A soft playable center without a rectangular arena frame.
	target.draw_circle(Vector2.ZERO, 520.0, Color(0.28, 0.50, 0.50, 0.018))
	for segment in torus_seam_segments:
		target.draw_polyline(segment, TORUS_SEAM_COLOR, 1.5, true)
	for segment in torus_corner_segments:
		target.draw_polyline(segment, Color(TORUS_SEAM_COLOR, 0.92), 2.5, true)


func _build_torus_seam() -> void:
	var left := arena_bounds.position.x + TORUS_SEAM_INSET
	var right := arena_bounds.end.x - TORUS_SEAM_INSET
	var top := arena_bounds.position.y + TORUS_SEAM_INSET
	var bottom := arena_bounds.end.y - TORUS_SEAM_INSET
	_append_dashed_edge(Vector2(left, top), Vector2(right, top))
	_append_dashed_edge(Vector2(left, bottom), Vector2(right, bottom))
	_append_dashed_edge(Vector2(left, top), Vector2(left, bottom))
	_append_dashed_edge(Vector2(right, top), Vector2(right, bottom))
	for corner in [Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)]:
		var horizontal_sign := 1.0 if is_equal_approx(corner.x, left) else -1.0
		var vertical_sign := 1.0 if is_equal_approx(corner.y, top) else -1.0
		torus_corner_segments.append(PackedVector2Array([corner, corner + Vector2(horizontal_sign * TORUS_CORNER_LENGTH, 0.0)]))
		torus_corner_segments.append(PackedVector2Array([corner, corner + Vector2(0.0, vertical_sign * TORUS_CORNER_LENGTH)]))


func _append_dashed_edge(from: Vector2, to: Vector2) -> void:
	var length := from.distance_to(to)
	if length <= 0.0:
		return
	var direction := from.direction_to(to)
	var cursor := TORUS_CORNER_LENGTH + TORUS_DASH_GAP
	var limit := length - TORUS_CORNER_LENGTH - TORUS_DASH_GAP
	while cursor < limit:
		var dash_end := minf(cursor + TORUS_DASH_LENGTH, limit)
		torus_seam_segments.append(PackedVector2Array([from + direction * cursor, from + direction * dash_end]))
		cursor += TORUS_DASH_LENGTH + TORUS_DASH_GAP


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result


func _inner_outline(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point * 0.82)
	return _closed(result)


func _wrapped_draw_offsets(center: Vector2, radius: float) -> Array[Vector2]:
	var xs: Array[float] = [0.0]
	var ys: Array[float] = [0.0]
	if center.x - radius < arena_bounds.position.x:
		xs.append(arena_bounds.size.x)
	if center.x + radius > arena_bounds.end.x:
		xs.append(-arena_bounds.size.x)
	if center.y - radius < arena_bounds.position.y:
		ys.append(arena_bounds.size.y)
	if center.y + radius > arena_bounds.end.y:
		ys.append(-arena_bounds.size.y)
	var offsets: Array[Vector2] = []
	for x in xs:
		for y in ys:
			offsets.append(Vector2(x, y))
	return offsets
