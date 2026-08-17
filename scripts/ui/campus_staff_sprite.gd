class_name CampusStaffSprite
extends TextureRect

var path_start: Vector2
var path_end: Vector2
var phase: float = 0.0
var travel_speed: float = 0.08
var walk_clock: float = 0.0
var reduced_motion: bool = false

func configure(start: Vector2, finish: Vector2, offset: float, speed: float = 0.08) -> void:
	path_start = start
	path_end = finish
	phase = offset
	travel_speed = speed
	texture = VisualAssetCatalog.doctor_frame(Vector2.RIGHT, 0, true)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(40.0, 40.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1.0, 1.0, 1.0, 0.92)
	_update_position()

func _process(delta: float) -> void:
	if reduced_motion:
		return
	phase = fmod(phase + delta * travel_speed, 1.0)
	walk_clock += delta
	_update_position()

func _update_position() -> void:
	var ping_pong := 1.0 - absf(phase * 2.0 - 1.0)
	position = path_start.lerp(path_end, ping_pong)
	var direction := (path_end - path_start).normalized()
	if phase >= 0.5:
		direction = -direction
	texture = VisualAssetCatalog.doctor_frame(direction, int(floor(walk_clock / 0.14)), true)

func _ready() -> void:
	add_to_group(&"alveolus_reduced_motion")

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	set_process(not enabled)
