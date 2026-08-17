class_name BioLumenBackdrop
extends Control

## Quiet alveolar/capillary backdrop used by dossier pages.
## It is deterministic, input-transparent and does not animate, keeping the
## living-membrane direction readable without becoming combat noise.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var base := Color(AlveolusVisualTheme.TURQUOISE, 0.035)
	var capillary := Color(AlveolusVisualTheme.COBALT, 0.030)
	var centers := [
		Vector2(size.x * 0.10, size.y * 0.18),
		Vector2(size.x * 0.24, size.y * 0.78),
		Vector2(size.x * 0.58, size.y * 0.22),
		Vector2(size.x * 0.84, size.y * 0.66),
		Vector2(size.x * 0.96, size.y * 0.14),
	]
	for index in range(centers.size()):
		var radius := 70.0 + float((index * 31) % 58)
		draw_circle(centers[index], radius, Color(base, 0.014), true)
		draw_arc(centers[index], radius, 0.0, TAU, 48, base, 0.8, true)
		draw_arc(centers[index] + Vector2(radius * 0.32, radius * 0.08), radius * 0.42, 0.0, TAU, 32, Color(AlveolusVisualTheme.TURQUOISE, 0.020), 0.8, true)
	for index in range(centers.size() - 1):
		var start: Vector2 = centers[index]
		var finish: Vector2 = centers[index + 1]
		var bend := (start + finish) * 0.5 + Vector2(0.0, -34.0 if index % 2 == 0 else 34.0)
		draw_polyline(PackedVector2Array([start, bend, finish]), capillary, 1.0, true)
