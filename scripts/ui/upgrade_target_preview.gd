class_name UpgradeTargetPreview
extends Control

var target_type: StringName = &""
var target_object: Variant
var target_position: Vector2 = Vector2.ZERO
var highlighter: ObjectHighlighter

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlighter = ObjectHighlighter.new()
	highlighter.geometry_changed.connect(_on_target_geometry_changed)
	add_child(highlighter)
	hide()

func present(type: StringName, target: Variant) -> void:
	target_type = type
	target_object = target
	var accent := Color("76aaff") if target_type == &"stability_bar" else Color("f2bd68")
	var radius := 116.0 if target_type == &"avatar" else -1.0
	highlighter.follow(target_object, accent, 5.0, radius)
	target_position = highlighter.center()
	show()
	queue_redraw()

func clear() -> void:
	highlighter.clear()
	hide()
	target_type = &""
	target_object = null

func _draw() -> void:
	if target_type == &"":
		return
	var accent := Color("f2bd68")
	match target_type:
		&"avatar":
			for index in range(2):
				var point := target_position + Vector2.from_angle(float(index) * PI) * 98.0
				draw_circle(point, 10.0, Color(0.95, 0.73, 0.38, 0.28))
				draw_circle(point, 6.0, Color("f1bc62"))
			_draw_caption(target_position + Vector2(0, 138), "2 Neutrophile · Radius 116", accent)
		&"stability_bar":
			var bar := highlighter.bounds().grow(-5.0)
			draw_rect(bar, Color(0.28, 0.55, 0.75, 0.18), true)
			var segment_width := minf(28.0, bar.size.x * 0.18)
			draw_rect(Rect2(bar.end.x - segment_width, bar.position.y, segment_width, bar.size.y), Color("76aaff"), true)
			_draw_arrow(target_position + Vector2(145.0, 74.0), Vector2(bar.end.x + 4.0, target_position.y), Color("76aaff"))
			_draw_caption(Vector2(bar.end.x + 4.0, bar.end.y + 12.0), "+4 Stabilität", Color("76aaff"))
		&"enemy":
			var radius := highlighter.bounds().size.x * 0.5
			_draw_arrow(target_position + Vector2(95.0, -62.0), target_position + Vector2(radius * 0.70, -radius * 0.55), accent)
			_draw_caption(target_position + Vector2(0, -50), "Vorschau: 26", accent)

func _on_target_geometry_changed(bounds: Rect2) -> void:
	target_position = bounds.get_center()
	queue_redraw()

func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, 2.0, true)
	var direction := (to - from).normalized()
	var side := direction.orthogonal() * 7.0
	draw_colored_polygon(PackedVector2Array([to, to - direction * 13.0 + side, to - direction * 13.0 - side]), color)

func _draw_caption(position: Vector2, text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_rect(Rect2(position - Vector2(width * 0.5 + 8.0, 2.0), Vector2(width + 16.0, 22.0)), Color(0.03, 0.07, 0.09, 0.92), true)
	draw_string(font, position + Vector2(-width * 0.5, 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
