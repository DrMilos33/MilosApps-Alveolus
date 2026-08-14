class_name ArenaBackdrop
extends Node2D

var arena_bounds: Rect2
var visual: ArenaVisualDefinition
var base_texture: Texture2D
var alveoli: Array[Dictionary] = []
var capillaries: Array[PackedVector2Array] = []
var inflammation_spots: Array[Dictionary] = []

func configure(bounds: Rect2, definition: ArenaVisualDefinition) -> void:
	arena_bounds = bounds
	visual = definition
	alveoli.clear()
	capillaries.clear()
	inflammation_spots.clear()
	if visual != null and ResourceLoader.exists(visual.texture_path):
		base_texture = load(visual.texture_path) as Texture2D
	var rng := RandomNumberGenerator.new()
	rng.seed = visual.seed if visual != null else 3101
	for index in range(34):
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
	for branch_index in range(9):
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
	queue_redraw()

func _draw() -> void:
	if arena_bounds.size == Vector2.ZERO:
		return
	var base := visual.base_color if visual != null else Color("10252b")
	draw_rect(arena_bounds, base, true)
	if base_texture != null:
		draw_texture_rect(base_texture, arena_bounds, true, Color(0.34, 0.45, 0.43, 0.10))
	var tissue := visual.tissue_color if visual != null else Color("23484b")
	var membrane := visual.membrane_color if visual != null else Color("779a91")
	for alveolus in alveoli:
		for offset in _wrapped_draw_offsets(alveolus["center"], 190.0):
			draw_set_transform(alveolus["center"] + offset, alveolus["rotation"], Vector2.ONE)
			draw_colored_polygon(alveolus["points"], Color(tissue, 0.19))
			draw_polyline(_closed(alveolus["points"]), Color(membrane, 0.15), 3.0, true)
			draw_polyline(_inner_outline(alveolus["points"]), Color(membrane.lightened(0.12), 0.055), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var capillary := visual.capillary_color if visual != null else Color("492a33")
	for points in capillaries:
		draw_polyline(points, Color(capillary, 0.34), 5.0, true)
		draw_polyline(points, Color(capillary.lightened(0.20), 0.10), 1.5, true)
	var inflammation := visual.inflammation_color if visual != null else Color("a85e68")
	var strength := visual.inflammation_intensity if visual != null else 0.12
	for spot in inflammation_spots:
		for offset in _wrapped_draw_offsets(spot["position"], spot["radius"]):
			draw_circle(spot["position"] + offset, spot["radius"], Color(inflammation, 0.022 + strength * 0.030))
			draw_circle(spot["position"] + offset, spot["radius"] * 0.56, Color(inflammation, 0.018 + strength * 0.028))
	# A soft playable center without a rectangular arena frame.
	draw_circle(Vector2.ZERO, 520.0, Color(0.28, 0.50, 0.50, 0.018))

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
