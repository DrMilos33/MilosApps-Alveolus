class_name SimpleIcon
extends Control

var kind: StringName = &"practice"
var accent: Color = Color("58dacb")

func configure(icon_kind: StringName, color: Color) -> void:
	kind = icon_kind
	accent = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var scale_factor := minf(size.x, size.y) / 48.0
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	match kind:
		&"back":
			draw_line(Vector2(14, -16), Vector2(-4, 0), accent, 3.0, true)
			draw_line(Vector2(-4, 0), Vector2(14, 16), accent, 3.0, true)
			draw_line(Vector2(-3, 0), Vector2(19, 0), accent, 3.0, true)
		&"play":
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -17), Vector2(17, 0), Vector2(-10, 17)]), accent)
		&"story", &"lexicon":
			draw_polyline(PackedVector2Array([Vector2(-19, -14), Vector2(-3, -9), Vector2(-3, 16), Vector2(-19, 10), Vector2(-19, -14)]), accent, 2.5, true)
			draw_polyline(PackedVector2Array([Vector2(19, -14), Vector2(3, -9), Vector2(3, 16), Vector2(19, 10), Vector2(19, -14)]), accent, 2.5, true)
			draw_line(Vector2(0, -8), Vector2(0, 17), Color(accent, 0.70), 2.0, true)
		&"clock":
			draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 28, accent, 2.5, true)
			draw_line(Vector2.ZERO, Vector2(0, -10), accent, 2.5, true)
			draw_line(Vector2.ZERO, Vector2(9, 5), accent, 2.5, true)
		&"boss":
			draw_circle(Vector2.ZERO, 13.0, Color(accent, 0.18))
			draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, accent, 2.5, true)
			for index in range(6):
				draw_circle(Vector2.from_angle(TAU * index / 6.0) * 18.0, 3.5, accent)
		&"clinic":
			draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 28, accent, 2.5, true)
			_draw_cross(Vector2.ZERO)
		&"offline":
			draw_arc(Vector2(-4, -2), 14.0, PI * 0.18, PI * 1.72, 22, accent, 2.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(9, -13), Vector2(18, -12), Vector2(14, -4)]), accent)
		&"antibiotic":
			draw_line(Vector2(-15, 15), Vector2(15, -15), accent, 8.0, true)
			draw_line(Vector2(-8, 8), Vector2(8, 8), Color("10222a"), 2.0, true)
		&"immune":
			draw_circle(Vector2.ZERO, 11.0, Color(accent, 0.25))
			draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 28, accent, 2.5, true)
			for index in range(5):
				draw_circle(Vector2.from_angle(TAU * index / 5.0) * 18.0, 3.0, accent)
		&"support":
			draw_arc(Vector2(-7, 4), 10.0, 0.0, TAU, 20, accent, 2.5, true)
			draw_arc(Vector2(8, -7), 12.0, 0.0, TAU, 20, accent, 2.5, true)
			draw_arc(Vector2(13, 12), 6.0, 0.0, TAU, 16, accent, 2.0, true)
		&"practice":
			draw_colored_polygon(PackedVector2Array([Vector2(-18, -5), Vector2(0, -18), Vector2(18, -5)]), Color(accent, 0.30))
			draw_rect(Rect2(-15, -5, 30, 22), Color(accent, 0.14), true)
			draw_rect(Rect2(-15, -5, 30, 22), accent, false, 2.0)
			_draw_cross(Vector2.ZERO)
		&"research", &"sample_logistics":
			draw_line(Vector2(-7, -17), Vector2(-7, 4), accent, 3.0, true)
			draw_line(Vector2(7, -17), Vector2(7, 4), accent, 3.0, true)
			draw_line(Vector2(-7, -17), Vector2(7, -17), accent, 3.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-7, 2), Vector2(-14, 17), Vector2(14, 17), Vector2(7, 2)]), Color(accent, 0.28))
			draw_polyline(PackedVector2Array([Vector2(-7, 2), Vector2(-14, 17), Vector2(14, 17), Vector2(7, 2)]), accent, 2.0, true)
		&"archive":
			for y in [-12.0, 0.0, 12.0]:
				draw_circle(Vector2(-14, y), 3.0, accent)
				draw_line(Vector2(-6, y), Vector2(16, y), accent, 2.0, true)
		&"settings":
			draw_circle(Vector2.ZERO, 14.0, Color(accent, 0.20))
			draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, accent, 3.0, true)
			draw_circle(Vector2.ZERO, 5.0, accent)
		&"stability_reserve":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -18), Vector2(16, -10), Vector2(12, 10), Vector2(0, 19), Vector2(-12, 10), Vector2(-16, -10)]), Color(accent, 0.18))
			draw_polyline(PackedVector2Array([Vector2(0, -18), Vector2(16, -10), Vector2(12, 10), Vector2(0, 19), Vector2(-12, 10), Vector2(-16, -10), Vector2(0, -18)]), accent, 2.0, true)
			_draw_cross(Vector2.ZERO)
		&"therapy_precision":
			for radius in [18.0, 11.0, 4.0]:
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, accent, 2.0, true)
			draw_line(Vector2(-21, 0), Vector2(21, 0), Color(accent, 0.55), 1.0)
			draw_line(Vector2(0, -21), Vector2(0, 21), Color(accent, 0.55), 1.0)
		&"preanalysis":
			draw_arc(Vector2(-4, -4), 12.0, 0.0, TAU, 24, accent, 3.0, true)
			draw_line(Vector2(5, 5), Vector2(18, 18), accent, 4.0, true)
		&"second_opinion":
			draw_line(Vector2(-18, 0), Vector2(-3, 0), accent, 3.0, true)
			draw_line(Vector2(-3, 0), Vector2(13, -13), accent, 3.0, true)
			draw_line(Vector2(-3, 0), Vector2(13, 13), accent, 3.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(11, -18), Vector2(20, -13), Vector2(11, -8)]), accent)
			draw_colored_polygon(PackedVector2Array([Vector2(11, 8), Vector2(20, 13), Vector2(11, 18)]), accent)
		_:
			draw_circle(Vector2.ZERO, 14.0, Color(accent, 0.25))
			draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, accent, 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_cross(offset: Vector2) -> void:
	draw_rect(Rect2(offset + Vector2(-3, -11), Vector2(6, 22)), accent, true)
	draw_rect(Rect2(offset + Vector2(-11, -3), Vector2(22, 6)), accent, true)
