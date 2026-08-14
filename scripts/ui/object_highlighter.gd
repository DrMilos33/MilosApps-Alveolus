class_name ObjectHighlighter
extends Control

## Reusable outline for local silhouettes, screen-space shapes and live
## CanvasItems. It deliberately owns no input so it can be layered over any
## interactive object without changing that object's hit area.

signal geometry_changed(bounds: Rect2)

enum Shape {
	NONE,
	POLYGON,
	CIRCLE,
	RECT,
}

var accent: Color = Color("f2bd68")
var line_width: float = 2.0
var strength: float = 0.0
var shape: Shape = Shape.NONE
var tracked_target: Variant
var tracked_padding: float = 5.0
var tracked_radius: float = -1.0
var polygon := PackedVector2Array()
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
	tracked_target = null
	shape = Shape.POLYGON
	polygon = points.duplicate()
	accent = color
	_update_polygon_bounds()
	set_strength(amount)
	set_process(false)

func show_circle(center: Vector2, radius: float, color: Color, amount: float = 1.0) -> void:
	tracked_target = null
	shape = Shape.CIRCLE
	circle_center = center
	circle_radius = maxf(radius, 1.0)
	accent = color
	_set_bounds(Rect2(circle_center - Vector2.ONE * circle_radius, Vector2.ONE * circle_radius * 2.0))
	set_strength(amount)
	set_process(false)

func show_rect(rect: Rect2, color: Color, amount: float = 1.0) -> void:
	tracked_target = null
	shape = Shape.RECT
	outline_rect = rect
	accent = color
	_set_bounds(rect)
	set_strength(amount)
	set_process(false)

func follow(target: Variant, color: Color, padding: float = 5.0, radius: float = -1.0) -> void:
	tracked_target = target
	tracked_padding = padding
	tracked_radius = radius
	accent = color
	set_strength(1.0)
	set_process(true)
	_resolve_tracked_geometry()

func set_strength(amount: float) -> void:
	var next := clampf(amount, 0.0, 1.0)
	if is_equal_approx(next, strength):
		return
	strength = next
	visible = strength > 0.001 and shape != Shape.NONE
	queue_redraw()

func clear() -> void:
	tracked_target = null
	shape = Shape.NONE
	strength = 0.0
	set_process(false)
	hide()
	queue_redraw()

func center() -> Vector2:
	return geometry_bounds.get_center()

func bounds() -> Rect2:
	return geometry_bounds

func _process(_delta: float) -> void:
	_resolve_tracked_geometry()

func _resolve_tracked_geometry() -> void:
	if tracked_target == null:
		return
	if tracked_target is Control:
		var control := tracked_target as Control
		if not is_instance_valid(control):
			clear()
			return
		var rect := control.get_global_rect().grow(tracked_padding)
		var local_origin := get_global_rect().position
		show_rect(Rect2(rect.position - local_origin, rect.size), accent, strength)
		tracked_target = control
		set_process(true)
		return
	if tracked_target is Node2D:
		var node := tracked_target as Node2D
		if not is_instance_valid(node):
			clear()
			return
		var transform := node.get_global_transform_with_canvas()
		var local_origin := get_global_rect().position
		var position := transform.origin - local_origin
		var radius := tracked_radius if tracked_radius > 0.0 else _suggested_radius(node)
		var scale_factor := maxf(transform.x.length(), transform.y.length())
		show_circle(position, radius * maxf(scale_factor, 0.01), accent, strength)
		tracked_target = node
		set_process(true)
		return
	if tracked_target is Vector2:
		show_circle(tracked_target as Vector2, maxf(tracked_radius, 28.0), accent, strength)

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

func _update_polygon_bounds() -> void:
	if polygon.is_empty():
		_set_bounds(Rect2())
		return
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
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
	var glow := Color(accent, 0.18 * strength)
	var crisp := Color(accent, 0.95 * strength)
	match shape:
		Shape.POLYGON:
			if polygon.size() < 3:
				return
			var closed := polygon.duplicate()
			closed.append(polygon[0])
			draw_polyline(closed, glow, line_width + 7.0, true)
			draw_polyline(closed, crisp, line_width, true)
		Shape.CIRCLE:
			draw_arc(circle_center, circle_radius, 0.0, TAU, 48, glow, line_width + 7.0, true)
			draw_arc(circle_center, circle_radius, 0.0, TAU, 48, crisp, line_width, true)
		Shape.RECT:
			draw_rect(outline_rect, glow, false, line_width + 7.0, true)
			draw_rect(outline_rect, crisp, false, line_width, true)
