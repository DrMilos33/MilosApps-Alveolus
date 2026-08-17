@tool
class_name CampusBackdrop
extends Control

## Lightweight, code-native environment behind the editor-authored campus.
## It gives the isometric tiles a horizon, surrounding grounds and a contact
## shadow without reintroducing the legacy generated campus plates.

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const SKY_TOP := Color("d9edf0")
const SKY_BOTTOM := Color("9dc9cd")
const DISTANT_GROUND := Color("6f9f91")
const NEAR_GROUND := Color("4f8075")
const PETROL_SHADOW := Color("12383f")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_draw_sky()
	_draw_horizon()
	_draw_surrounding_grounds()


func _draw_sky() -> void:
	const BAND_COUNT := 32
	var horizon_y := _point(Vector2(0.0, 292.0)).y
	for index in range(BAND_COUNT):
		var from_ratio := float(index) / float(BAND_COUNT)
		var to_ratio := float(index + 1) / float(BAND_COUNT)
		var color := SKY_TOP.lerp(SKY_BOTTOM, (from_ratio + to_ratio) * 0.5)
		draw_rect(
			Rect2(0.0, horizon_y * from_ratio, size.x, horizon_y * (to_ratio - from_ratio) + 1.0),
			color
		)


func _draw_horizon() -> void:
	var far_hills := PackedVector2Array([
		_point(Vector2(0.0, 286.0)),
		_point(Vector2(0.0, 240.0)),
		_point(Vector2(128.0, 214.0)),
		_point(Vector2(252.0, 245.0)),
		_point(Vector2(382.0, 198.0)),
		_point(Vector2(518.0, 242.0)),
		_point(Vector2(666.0, 206.0)),
		_point(Vector2(806.0, 246.0)),
		_point(Vector2(946.0, 210.0)),
		_point(Vector2(1090.0, 244.0)),
		_point(Vector2(1280.0, 204.0)),
		_point(Vector2(1280.0, 286.0)),
	])
	draw_colored_polygon(far_hills, Color(DISTANT_GROUND, 0.72))

	var near_hills := PackedVector2Array([
		_point(Vector2(0.0, 318.0)),
		_point(Vector2(0.0, 274.0)),
		_point(Vector2(186.0, 250.0)),
		_point(Vector2(344.0, 282.0)),
		_point(Vector2(526.0, 248.0)),
		_point(Vector2(708.0, 286.0)),
		_point(Vector2(902.0, 252.0)),
		_point(Vector2(1080.0, 282.0)),
		_point(Vector2(1280.0, 248.0)),
		_point(Vector2(1280.0, 318.0)),
	])
	draw_colored_polygon(near_hills, Color(NEAR_GROUND, 0.88))

	for tree_data in [
		Vector3(86.0, 238.0, 30.0),
		Vector3(174.0, 256.0, 24.0),
		Vector3(1084.0, 252.0, 28.0),
		Vector3(1190.0, 226.0, 34.0),
	]:
		var center := _point(Vector2(tree_data.x, tree_data.y))
		var radius: float = float(tree_data.z) * _scale_factor()
		draw_circle(center, radius, Color(PETROL_SHADOW, 0.18))
		draw_circle(center + Vector2(radius * 0.55, radius * 0.12), radius * 0.72, Color(PETROL_SHADOW, 0.14))


func _draw_surrounding_grounds() -> void:
	var ground_top := _point(Vector2(0.0, 286.0)).y
	draw_rect(Rect2(0.0, ground_top, size.x, size.y - ground_top), Color("86aa91"))

	# Broad, low-contrast paths keep the environment from reading as an empty
	# color field while staying behind the interactive tile map.
	var path_color := Color("d7d0b6", 0.26)
	var path_width := 34.0 * _scale_factor()
	draw_polyline(PackedVector2Array([
		_point(Vector2(-40.0, 570.0)),
		_point(Vector2(248.0, 474.0)),
		_point(Vector2(520.0, 464.0)),
		_point(Vector2(792.0, 534.0)),
		_point(Vector2(1320.0, 430.0)),
	]), path_color, path_width, true)
	draw_polyline(PackedVector2Array([
		_point(Vector2(188.0, 720.0)),
		_point(Vector2(360.0, 574.0)),
		_point(Vector2(618.0, 514.0)),
		_point(Vector2(774.0, 352.0)),
	]), Color(path_color, 0.18), path_width * 0.62, true)

	# Several nested contact shadows visually seat the authored isometric board
	# in the surrounding campus grounds instead of letting it float in a void.
	var shadow_outer := PackedVector2Array([
		_point(Vector2(628.0, 148.0)),
		_point(Vector2(1210.0, 414.0)),
		_point(Vector2(650.0, 712.0)),
		_point(Vector2(58.0, 430.0)),
	])
	draw_colored_polygon(shadow_outer, Color(PETROL_SHADOW, 0.13))
	var shadow_inner := PackedVector2Array([
		_point(Vector2(632.0, 178.0)),
		_point(Vector2(1170.0, 424.0)),
		_point(Vector2(648.0, 684.0)),
		_point(Vector2(104.0, 428.0)),
	])
	draw_colored_polygon(shadow_inner, Color(PETROL_SHADOW, 0.11))

	for y in [596.0, 642.0, 688.0]:
		draw_line(
			_point(Vector2(0.0, y)),
			_point(Vector2(1280.0, y - 82.0)),
			Color("e7eee3", 0.08),
			1.5 * _scale_factor(),
			true
		)


func _point(design_point: Vector2) -> Vector2:
	return Vector2(design_point.x * size.x / DESIGN_SIZE.x, design_point.y * size.y / DESIGN_SIZE.y)


func _scale_factor() -> float:
	return minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
