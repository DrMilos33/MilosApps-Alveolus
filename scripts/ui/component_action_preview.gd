class_name ComponentActionPreview
extends Control

## Tiny native animation preview for treatments and active abilities.
## It replaces heavyweight video/GIF assets with deterministic schematic motion
## and freezes to a useful still when reduced motion is enabled.

var component_id: StringName = &""
var accent: Color = AlveolusVisualTheme.TURQUOISE
var reduced_motion := false
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func present(id: StringName, color: Color, reduce_motion: bool = false) -> void:
	component_id = id
	accent = color
	reduced_motion = reduce_motion
	elapsed = 0.0
	show()
	set_process(not reduced_motion)
	queue_redraw()

func clear() -> void:
	component_id = &""
	hide()
	set_process(false)

func _process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, 2.0)
	queue_redraw()

func _draw() -> void:
	if component_id == &"" or size.x < 24.0 or size.y < 20.0:
		return
	var center := size * 0.5
	var phase := 0.45 if reduced_motion else elapsed / 2.0
	var left := Vector2(12.0, center.y)
	var right := Vector2(size.x - 12.0, center.y)
	draw_line(left, right, Color(accent, 0.20), 1.0, true)
	match component_id:
		&"treatment_spread":
			for offset in [-13.0, 0.0, 13.0]:
				var target := right + Vector2(0.0, offset)
				draw_line(left, target, Color(accent, 0.48), 2.0, true)
				draw_circle(left.lerp(target, phase), 3.0, accent)
		&"treatment_pierce", &"ability_treatment_line":
			draw_line(left, right, accent, 2.5, true)
			for ratio in [0.34, 0.62, 0.88]:
				draw_arc(left.lerp(right, ratio), 6.0, 0.0, TAU, 18, Color(accent, 0.72), 1.5, true)
		&"ability_focus_field", &"ability_protection_field":
			var pulse := 9.0 + sin(phase * TAU) * 3.0
			draw_circle(center, pulse, Color(accent, 0.13), true)
			draw_arc(center, pulse, 0.0, TAU, 24, accent, 2.0, true)
			draw_circle(center + Vector2(cos(phase * TAU), sin(phase * TAU)) * pulse, 2.6, accent)
		&"ability_emergency_support":
			var shield := PackedVector2Array([center + Vector2(0, -14), center + Vector2(13, -7), center + Vector2(9, 10), center + Vector2(0, 16), center + Vector2(-9, 10), center + Vector2(-13, -7)])
			draw_colored_polygon(shield, Color(accent, 0.14 + phase * 0.14))
			draw_polyline(PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[5], shield[0]]), accent, 2.0, true)
		&"ability_defense_burst":
			var radius := 5.0 + phase * minf(size.x, size.y) * 0.34
			draw_arc(center, radius, 0.0, TAU, 28, Color(accent, 1.0 - phase * 0.62), 2.0, true)
		&"ability_sample_pull":
			for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
				var start := center + Vector2.from_angle(angle) * 22.0
				draw_circle(start.lerp(center, phase), 3.0, accent)
		_:
			draw_arc(right, 7.0, 0.0, TAU, 20, Color(accent, 0.64), 1.5, true)
			draw_circle(left.lerp(right, phase), 3.2, accent)
