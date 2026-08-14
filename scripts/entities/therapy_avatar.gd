class_name TherapyAvatar
extends CharacterBody2D

const MOVE_SPEED := 275.0
const BODY_RADIUS := 23.0

var arena_bounds: Rect2
var stats: PlayerStats
var topology: ArenaTopology
var input_enabled: bool = false
var immune_angle: float = 0.0
var camera: Camera2D

func configure(bounds: Rect2, player_stats: PlayerStats, arena_topology: ArenaTopology) -> void:
	arena_bounds = bounds
	stats = player_stats
	topology = arena_topology
	queue_redraw()

func _ready() -> void:
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.limit_left = int(arena_bounds.position.x)
	camera.limit_top = int(arena_bounds.position.y)
	camera.limit_right = int(arena_bounds.end.x)
	camera.limit_bottom = int(arena_bounds.end.y)
	add_child(camera)
	camera.make_current()

func _physics_process(delta: float) -> void:
	if input_enabled:
		var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		velocity = direction * MOVE_SPEED
		move_and_slide()
		if topology != null:
			var wrapped := topology.wrap_position(global_position)
			if not wrapped.is_equal_approx(global_position):
				global_position = wrapped
				reset_physics_interpolation()
				camera.reset_smoothing()
	else:
		velocity = Vector2.ZERO

func _process(delta: float) -> void:
	if stats == null or stats.immune_level <= 0:
		return
	immune_angle = fmod(immune_angle + delta * 1.7, TAU)
	queue_redraw()

func neutrophil_radius() -> float:
	if stats == null:
		return 0.0
	return 98.0 + float(stats.immune_level) * 18.0

func _draw() -> void:
	# Treatment field and readable silhouette.
	draw_circle(Vector2.ZERO, 34.0, Color(0.22, 0.91, 0.82, 0.09))
	draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 32, Color(0.35, 0.94, 0.86, 0.58), 2.0, true)
	draw_circle(Vector2(0.0, -14.0), 10.0, Color("e8c8ad"))
	draw_rect(Rect2(-12.0, -4.0, 24.0, 28.0), Color("e7f1ef"), true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12.0, -4.0), Vector2(-2.0, 4.0), Vector2(-7.0, 24.0), Vector2(-15.0, 20.0)
	]), Color("b9d9d6"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(12.0, -4.0), Vector2(2.0, 4.0), Vector2(7.0, 24.0), Vector2(15.0, 20.0)
	]), Color("b9d9d6"))
	draw_line(Vector2(0.0, 1.0), Vector2(0.0, 22.0), Color("203946"), 2.0)
	draw_circle(Vector2(0.0, 10.0), 2.6, Color("e85f75"))

	if stats == null or stats.immune_level <= 0:
		return
	var count := mini(stats.immune_level + 1, 4)
	var orbit_radius := neutrophil_radius() - 18.0
	for index in range(count):
		var angle := immune_angle + TAU * float(index) / float(count)
		var point := Vector2.from_angle(angle) * orbit_radius
		draw_circle(point, 11.0, Color(0.96, 0.75, 0.39, 0.18))
		draw_circle(point, 7.0, Color("f1bc62"))
		draw_circle(point + Vector2(-2.0, 0.0), 2.0, Color("76543a"))
		draw_circle(point + Vector2(3.0, -1.0), 2.2, Color("76543a"))
