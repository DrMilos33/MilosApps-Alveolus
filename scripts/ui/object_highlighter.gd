class_name ObjectHighlighter
extends Control

const UnitBodyComponent = preload("res://scripts/ui/unit_body_2d.gd")

## Reusable outline for local silhouettes, screen-space shapes and live
## CanvasItems. It deliberately owns no input so it can be layered over any
## interactive object without changing that object's hit area.

signal geometry_changed(bounds: Rect2)

enum Shape {
	NONE,
	POLYGON,
	CONTOURS,
	CIRCLE,
	RECT,
}

var accent: Color = Color("f2bd68")
var line_width: float = 2.0
var strength: float = 0.0
var shape: Shape = Shape.NONE
var tracked_target: Variant
var tracked_body: Variant
var tracked_padding: float = 5.0
var tracked_radius: float = -1.0
var polygon := PackedVector2Array()
var contours: Array[PackedVector2Array] = []
var circle_center := Vector2.ZERO
var circle_radius: float = 0.0
var outline_rect := Rect2()
var geometry_bounds := Rect2()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	hide()

func show_polygon(points: PackedVector2Array, color: Color, amount: float = 1.0) -> void:
	_stop_tracking()
	accent = color
	_set_contours([points], Shape.POLYGON)
	set_strength(amount)

func show_contours(points: Array, color: Color, amount: float = 1.0) -> void:
	_stop_tracking()
	accent = color
	_set_contours(points, Shape.CONTOURS)
	set_strength(amount)

func show_circle(center: Vector2, radius: float, color: Color, amount: float = 1.0) -> void:
	_stop_tracking()
	accent = color
	_set_circle(center, radius)
	set_strength(amount)

func show_rect(rect: Rect2, color: Color, amount: float = 1.0) -> void:
	_stop_tracking()
	accent = color
	_set_rect(rect)
	set_strength(amount)

func follow(target: Variant, color: Color, padding: float = 5.0, radius: float = -1.0) -> void:
	bind_target(target, color, padding, radius, 1.0)

func bind_target(target: Variant, color: Color, padding: float = 5.0, radius: float = -1.0, amount: float = 1.0) -> void:
	_stop_tracking()
	tracked_target = target
	tracked_padding = padding
	tracked_radius = radius
	accent = color
	tracked_body = _unit_body_for(target)
	if tracked_body != null and not tracked_body.geometry_changed.is_connected(_on_tracked_body_geometry_changed):
		tracked_body.geometry_changed.connect(_on_tracked_body_geometry_changed)
	_resolve_tracked_geometry()
	set_strength(amount)
	_update_tracking_process()

func set_strength(amount: float) -> void:
	var next := clampf(amount, 0.0, 1.0)
	if is_equal_approx(next, strength):
		return
	strength = next
	visible = strength > 0.001 and shape != Shape.NONE
	_update_tracking_process()
	queue_redraw()

func clear() -> void:
	_stop_tracking()
	shape = Shape.NONE
	strength = 0.0
	hide()
	queue_redraw()

func center() -> Vector2:
	return geometry_bounds.get_center()

func bounds() -> Rect2:
	return geometry_bounds

func _process(_delta: float) -> void:
	_resolve_tracked_geometry()

func _on_tracked_body_geometry_changed() -> void:
	_resolve_tracked_geometry()

func _resolve_tracked_geometry() -> void:
	if tracked_target == null:
		return
	var body: Variant = tracked_body if is_instance_valid(tracked_body) else _unit_body_for(tracked_target)
	if body != null:
		tracked_body = body
		var body_transform := _relative_canvas_transform(body)
		var body_contours: Array[PackedVector2Array] = body.contours_transformed(body_transform, tracked_padding)
		if body_contours.is_empty():
			# Alpha-mask bodies expose precise hit testing without a precomputed
			# polygon. Highlight their owning unit at the same screen position
			# instead of silently collapsing the hint target to (0, 0).
			var radius := tracked_radius if tracked_radius > 0.0 else _suggested_radius(tracked_target)
			var scale_factor := maxf(body_transform.x.length(), body_transform.y.length())
			_set_circle(body_transform.origin, (radius + tracked_padding) * maxf(scale_factor, 0.01))
		else:
			_set_contours(body_contours, Shape.CONTOURS)
		visible = strength > 0.001 and shape != Shape.NONE
		return
	if tracked_target is Control:
		var control := tracked_target as Control
		if not is_instance_valid(control):
			clear()
			return
		var rect := Rect2(-Vector2.ONE * tracked_padding, control.size + Vector2.ONE * tracked_padding * 2.0)
		var relative := _relative_canvas_transform(control)
		_set_contours([PackedVector2Array([
			relative * rect.position,
			relative * Vector2(rect.end.x, rect.position.y),
			relative * rect.end,
			relative * Vector2(rect.position.x, rect.end.y),
		])], Shape.CONTOURS)
		return
	if tracked_target is Node2D:
		var node := tracked_target as Node2D
		if not is_instance_valid(node):
			clear()
			return
		var relative := _relative_canvas_transform(node)
		var position := relative.origin
		var radius := tracked_radius if tracked_radius > 0.0 else _suggested_radius(node)
		var scale_factor := maxf(relative.x.length(), relative.y.length())
		_set_circle(position, (radius + tracked_padding) * maxf(scale_factor, 0.01))
		return
	if tracked_target is Vector2:
		_set_circle(tracked_target as Vector2, maxf(tracked_radius, 28.0) + tracked_padding)

func _unit_body_for(target: Variant) -> Variant:
	if target is Node2D and (target as Node2D).get_script() == UnitBodyComponent:
		return target
	if target is Object and is_instance_valid(target) and (target as Object).has_method("get_highlight_body"):
		var candidate: Variant = (target as Object).call("get_highlight_body")
		if candidate is Node2D and (candidate as Node2D).get_script() == UnitBodyComponent:
			return candidate
	return null

func _relative_canvas_transform(target: CanvasItem) -> Transform2D:
	return get_global_transform_with_canvas().affine_inverse() * target.get_global_transform_with_canvas()

func _stop_tracking() -> void:
	if tracked_body != null and is_instance_valid(tracked_body) and tracked_body.geometry_changed.is_connected(_on_tracked_body_geometry_changed):
		tracked_body.geometry_changed.disconnect(_on_tracked_body_geometry_changed)
	tracked_body = null
	tracked_target = null
	set_process(false)

func _update_tracking_process() -> void:
	var needs_polling := tracked_target != null and tracked_body == null and strength > 0.001
	set_process(needs_polling)

func _set_contours(next_contours: Array, next_shape: int) -> void:
	contours.clear()
	for value in next_contours:
		if value is PackedVector2Array and (value as PackedVector2Array).size() >= 3:
			contours.append((value as PackedVector2Array).duplicate())
	polygon = contours[0].duplicate() if contours.size() == 1 else PackedVector2Array()
	shape = next_shape if not contours.is_empty() else Shape.NONE
	_update_contour_bounds()
	queue_redraw()

func _set_circle(center: Vector2, radius: float) -> void:
	shape = Shape.CIRCLE
	circle_center = center
	circle_radius = maxf(radius, 1.0)
	_set_bounds(Rect2(circle_center - Vector2.ONE * circle_radius, Vector2.ONE * circle_radius * 2.0))
	queue_redraw()

func _set_rect(rect: Rect2) -> void:
	shape = Shape.RECT
	outline_rect = rect
	_set_bounds(rect)
	queue_redraw()

func _suggested_radius(node: Node2D) -> float:
	if node is InfectionEnemy:
		var enemy := node as InfectionEnemy
		if enemy.definition != null:
			return enemy.definition.radius + 6.0
	if node is AnalysisPickup:
		return 16.0
	if node is TherapyProjectile:
		return 14.0
	if node is TherapyAvatar:
		return TherapyAvatar.BODY_RADIUS + 10.0
	return 30.0

func _update_contour_bounds() -> void:
	if contours.is_empty():
		_set_bounds(Rect2())
		return
	var minimum := contours[0][0]
	var maximum := contours[0][0]
	for contour in contours:
		for point in contour:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	_set_bounds(Rect2(minimum, maximum - minimum))

func _set_bounds(next: Rect2) -> void:
	if geometry_bounds.is_equal_approx(next):
		return
	geometry_bounds = next
	geometry_changed.emit(geometry_bounds)
	queue_redraw()

func _draw() -> void:
	if strength <= 0.001:
		return
	var glow := Color(accent, 0.13 * strength)
	var crisp := Color(accent, 0.95 * strength)
	match shape:
		Shape.POLYGON, Shape.CONTOURS:
			for contour in contours:
				var closed := contour.duplicate()
				closed.append(contour[0])
				draw_polyline(closed, glow, line_width + 4.0, true)
				draw_polyline(closed, crisp, line_width, true)
		Shape.CIRCLE:
			draw_arc(circle_center, circle_radius, 0.0, TAU, 48, glow, line_width + 4.0, true)
			draw_arc(circle_center, circle_radius, 0.0, TAU, 48, crisp, line_width, true)
		Shape.RECT:
			draw_rect(outline_rect, glow, false, line_width + 4.0, true)
			draw_rect(outline_rect, crisp, false, line_width, true)
