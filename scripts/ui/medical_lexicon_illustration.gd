class_name MedicalLexiconIllustration
extends Control

var entry_id: StringName = &""
var accent: Color = Color("58dacb")
var locked: bool = false

func configure(id: StringName, color: Color) -> void:
	entry_id = id
	accent = color
	queue_redraw()

func set_locked(value: bool) -> void:
	locked = value
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var color := Color(accent, 0.18) if locked else accent
	var soft := Color(color, 0.14 if not locked else 0.05)
	draw_circle(center, 30.0, soft)
	match entry_id:
		&"pneumococcus":
			_draw_pneumococcus(center, color)
		&"bacterial_cluster":
			for offset in [Vector2(-14, -8), Vector2(11, -12), Vector2(-9, 12), Vector2(15, 10)]:
				draw_circle(center + offset, 10.0, color)
		&"infection_focus":
			draw_circle(center, 22.0, color)
			for index in range(8):
				draw_circle(center + Vector2.from_angle(TAU * index / 8.0) * 18.0, 5.5, color.lightened(0.15))
		&"analysis_pickup":
			var diamond := PackedVector2Array([center + Vector2(0, -22), center + Vector2(18, 0), center + Vector2(0, 22), center + Vector2(-18, 0)])
			draw_colored_polygon(diamond, color)
			draw_circle(center, 5.0, Color("eaf7ff", color.a))
		&"patient_stability":
			draw_rect(Rect2(center - Vector2(7, 24), Vector2(14, 48)), color, true)
			draw_rect(Rect2(center - Vector2(24, 7), Vector2(48, 14)), color, true)
		&"automatic_therapy":
			draw_line(center + Vector2(-26, 15), center + Vector2(17, -15), color, 5.0, true)
			draw_circle(center + Vector2(22, -18), 7.0, color)
			draw_arc(center + Vector2(22, -18), 13.0, 0.0, TAU, 20, color, 2.0, true)
		&"neutrophil_orbit":
			draw_circle(center, 8.0, color)
			draw_arc(center, 25.0, 0.0, TAU, 28, Color(color, color.a * 0.65), 2.0, true)
			draw_circle(center + Vector2(25, 0), 7.0, color)
			draw_circle(center - Vector2(25, 0), 7.0, color)
		&"supportive_oxygenation":
			for data in [[Vector2(-13, 10), 10.0], [Vector2(7, -10), 13.0], [Vector2(18, 15), 7.0]]:
				draw_arc(center + data[0], data[1], 0.0, TAU, 20, color, 3.0, true)
		&"boss_phases":
			for radius in [9.0, 18.0, 27.0]:
				draw_arc(center, radius, -PI * 0.70, PI * 0.45, 18, color, 4.0, true)
		&"research_reward":
			draw_line(center + Vector2(-8, -24), center + Vector2(-8, 2), color, 4.0, true)
			draw_line(center + Vector2(8, -24), center + Vector2(8, 2), color, 4.0, true)
			var flask := PackedVector2Array([center + Vector2(-8, 0), center + Vector2(-23, 24), center + Vector2(23, 24), center + Vector2(8, 0)])
			draw_colored_polygon(flask, Color(color, color.a * 0.72))
		_:
			draw_circle(center, 20.0, color)
	if locked:
		draw_line(center + Vector2(-20, -20), center + Vector2(20, 20), Color("789096"), 3.0, true)
		draw_line(center + Vector2(20, -20), center + Vector2(-20, 20), Color("789096"), 3.0, true)

func _draw_pneumococcus(center: Vector2, color: Color) -> void:
	draw_circle(center + Vector2(-10, 0), 14.0, color)
	draw_circle(center + Vector2(10, 0), 14.0, color.darkened(0.10))
	draw_arc(center, 27.0, 0.0, TAU, 24, Color(color.lightened(0.22), color.a * 0.65), 2.0, true)
