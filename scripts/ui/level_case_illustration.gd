class_name LevelCaseIllustration
extends Control

var case_order: int = 0
var tutorial: bool = false
var accent: Color = Color("76aaff")
var locked: bool = false

func configure(order: int, is_tutorial: bool, color: Color) -> void:
	case_order = order
	tutorial = is_tutorial
	accent = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_locked(value: bool) -> void:
	locked = value
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var tissue_texture := VisualAssetCatalog.alveolar_texture()
	if tissue_texture != null:
		# The archive art is intentionally unframed: a square texture field would
		# read like another nested tile and the previous ivory ring looked like a
		# placeholder badge. The faint tissue only gives the lungs local depth.
		draw_texture_rect(tissue_texture, Rect2(Vector2.ZERO, size), false, Color(1.0, 1.0, 1.0, 0.13))
	for offset in [Vector2(-22.0, -13.0), Vector2(23.0, -18.0), Vector2(-25.0, 21.0), Vector2(22.0, 22.0)]:
		draw_circle(center + offset, 9.0, Color(accent, 0.055))
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
		draw_circle(center + offset, 4.0 + float(case_order) * 0.5, AlveolusVisualTheme.CORAL)
		draw_circle(center + offset, 8.0 + float(case_order), Color(0.94, 0.44, 0.55, 0.12), false, 2.0, true)
	if locked:
		var lock_center := center + Vector2(24.0, 23.0)
		draw_circle(lock_center, 12.0, Color(AlveolusVisualTheme.PETROL_DEEP, 0.92))
		draw_arc(lock_center + Vector2(0.0, -3.0), 5.0, PI, TAU, 14, AlveolusVisualTheme.SKY_DEEP, 1.8, true)
		draw_rect(Rect2(lock_center + Vector2(-7.0, -2.0), Vector2(14.0, 11.0)), AlveolusVisualTheme.SKY_DEEP, false, 1.8)

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result
