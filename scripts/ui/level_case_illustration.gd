class_name LevelCaseIllustration
extends Control

var case_order: int = 0
var tutorial: bool = false
var accent: Color = Color("76aaff")

func configure(order: int, is_tutorial: bool, color: Color) -> void:
	case_order = order
	tutorial = is_tutorial
	accent = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var tissue := Color(accent, 0.10)
	draw_circle(center, minf(size.x, size.y) * 0.46, tissue)
	draw_line(center + Vector2(0, -27), center + Vector2(0, -10), Color(accent, 0.78), 4.0, true)
	draw_line(center + Vector2(0, -10), center + Vector2(-10, 1), Color(accent, 0.78), 3.0, true)
	draw_line(center + Vector2(0, -10), center + Vector2(10, 1), Color(accent, 0.78), 3.0, true)
	var left_lung := PackedVector2Array([
		center + Vector2(-9, -7), center + Vector2(-25, -20), center + Vector2(-34, -4),
		center + Vector2(-31, 23), center + Vector2(-10, 30), center + Vector2(-5, 8)
	])
	var right_lung := PackedVector2Array([
		center + Vector2(9, -7), center + Vector2(25, -20), center + Vector2(34, -4),
		center + Vector2(31, 23), center + Vector2(10, 30), center + Vector2(5, 8)
	])
	draw_colored_polygon(left_lung, Color(accent, 0.18))
	draw_colored_polygon(right_lung, Color(accent, 0.18))
	draw_polyline(_closed(left_lung), accent, 2.2, true)
	draw_polyline(_closed(right_lung), accent, 2.2, true)
	var focus_count := 1 if tutorial else mini(5, case_order + 1)
	for index in range(focus_count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var offset := Vector2(side * (16.0 + float(index % 2) * 5.0), -2.0 + float(index / 2) * 12.0)
		draw_circle(center + offset, 4.0 + float(case_order) * 0.5, Color("ef7188"))
		draw_circle(center + offset, 8.0 + float(case_order), Color(0.94, 0.44, 0.55, 0.12), false, 2.0, true)

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result
