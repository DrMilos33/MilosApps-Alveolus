class_name UnitBody2D
extends Node2D

## Non-rendering geometry component for interactive units. A unit owns one
## body; highlights and hit tests consume the same contours so they cannot
## drift apart. The body follows its owner automatically when it moves.

signal geometry_changed

var contours: Array[PackedVector2Array] = []
var _local_bounds := Rect2()
var _alpha_image: Image
var _alpha_display_rect := Rect2()
var _alpha_threshold: float = 0.10

func _init() -> void:
	set_notify_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		geometry_changed.emit()

func configure_polygon(points: PackedVector2Array) -> void:
	_clear_alpha_mask()
	set_contours([points])

func configure_circle(radius: float, center: Vector2 = Vector2.ZERO, segments: int = 40) -> void:
	_clear_alpha_mask()
	var points := PackedVector2Array()
	var safe_radius := maxf(radius, 1.0)
	var safe_segments := maxi(segments, 12)
	for index in range(safe_segments):
		points.append(center + Vector2.from_angle(TAU * float(index) / float(safe_segments)) * safe_radius)
	set_contours([points])

func configure_rect(rect: Rect2) -> void:
	_clear_alpha_mask()
	set_contours([PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])])

func configure_alpha_texture(texture: Texture2D, display_rect: Rect2, threshold: float = 0.10) -> void:
	contours.clear()
	_alpha_image = texture.get_image() if texture != null else null
	_alpha_display_rect = display_rect
	_alpha_threshold = clampf(threshold, 0.0, 1.0)
	_local_bounds = display_rect if _alpha_image != null and not _alpha_image.is_empty() else Rect2()
	geometry_changed.emit()

func set_contours(next_contours: Array) -> void:
	contours.clear()
	for value in next_contours:
		if value is PackedVector2Array and (value as PackedVector2Array).size() >= 3:
			contours.append((value as PackedVector2Array).duplicate())
	_recalculate_bounds()
	geometry_changed.emit()

func is_empty() -> bool:
	return contours.is_empty() and (_alpha_image == null or _alpha_image.is_empty())

func local_bounds() -> Rect2:
	return _local_bounds

func local_center() -> Vector2:
	return _local_bounds.get_center()

func contains_parent_point(parent_point: Vector2) -> bool:
	var local_point := transform.affine_inverse() * parent_point
	if _alpha_image != null and not _alpha_image.is_empty():
		if not _alpha_display_rect.has_point(local_point):
			return false
		var relative := (local_point - _alpha_display_rect.position) / _alpha_display_rect.size
		var pixel_x := clampi(int(floor(relative.x * float(_alpha_image.get_width()))), 0, _alpha_image.get_width() - 1)
		var pixel_y := clampi(int(floor(relative.y * float(_alpha_image.get_height()))), 0, _alpha_image.get_height() - 1)
		return _alpha_image.get_pixel(pixel_x, pixel_y).a >= _alpha_threshold
	for contour in contours:
		if Geometry2D.is_point_in_polygon(local_point, contour):
			return true
	return false

func uses_alpha_texture() -> bool:
	return _alpha_image != null and not _alpha_image.is_empty()

func contours_transformed(relative_transform: Transform2D, padding: float = 0.0) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var center := local_center()
	for contour in contours:
		var transformed := PackedVector2Array()
		for point in contour:
			var padded := point
			var from_center := point - center
			if not is_zero_approx(padding) and from_center.length_squared() > 0.0001:
				padded += from_center.normalized() * padding
			transformed.append(relative_transform * padded)
		result.append(transformed)
	return result

func _recalculate_bounds() -> void:
	if contours.is_empty():
		_local_bounds = Rect2()
		return
	var initialized := false
	var minimum := Vector2.ZERO
	var maximum := Vector2.ZERO
	for contour in contours:
		for point in contour:
			if not initialized:
				minimum = point
				maximum = point
				initialized = true
			else:
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	_local_bounds = Rect2(minimum, maximum - minimum) if initialized else Rect2()

func _clear_alpha_mask() -> void:
	_alpha_image = null
	_alpha_display_rect = Rect2()
