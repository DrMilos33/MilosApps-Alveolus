class_name TherapyAvatar
extends CharacterBody2D

const MOVE_SPEED := 275.0
const BODY_RADIUS := 23.0
const DAMAGE_FLASH_SECONDS := 0.16
const WALK_FRAME_SECONDS := 0.12
const DOCTOR_DRAW_RECT := Rect2(-30.0, -44.0, 60.0, 60.0)

var arena_bounds: Rect2
var stats: PlayerStats
var topology: ArenaTopology
var input_enabled: bool = false
var immune_angle: float = 0.0
var camera: Camera2D
var visual_time: float = 0.0
var walk_frame_time: float = 0.0
var walk_frame: int = 0
var last_facing := Vector2.DOWN
var treatment_anim_time: float = 0.0
var damage_flash_time: float = 0.0
var visual_body: UnitBody2D
var doctor_texture: Texture2D
var immune_texture: Texture2D

func configure(bounds: Rect2, player_stats: PlayerStats, arena_topology: ArenaTopology) -> void:
	arena_bounds = bounds
	stats = player_stats
	topology = arena_topology
	queue_redraw()

func _ready() -> void:
	doctor_texture = VisualAssetCatalog.gameplay_sprite(&"doctor")
	immune_texture = VisualAssetCatalog.gameplay_sprite(&"immune_cell")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual_body = UnitBody2D.new()
	visual_body.configure_alpha_texture(doctor_texture, DOCTOR_DRAW_RECT, 0.08)
	add_child(visual_body)
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
	step_fixed(delta)

func step_fixed(_delta: float) -> void:
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
	var needs_redraw := false
	var treatment_was_active := treatment_anim_time > 0.0
	var damage_was_active := damage_flash_time > 0.0
	treatment_anim_time = maxf(0.0, treatment_anim_time - delta)
	damage_flash_time = maxf(0.0, damage_flash_time - delta)
	needs_redraw = treatment_was_active or damage_was_active
	if velocity.length_squared() > 1.0:
		var next_facing := velocity.normalized()
		if not next_facing.is_equal_approx(last_facing):
			last_facing = next_facing
			needs_redraw = true
		walk_frame_time += delta
		if walk_frame_time >= WALK_FRAME_SECONDS:
			walk_frame = (walk_frame + 1) % 4
			walk_frame_time = fmod(walk_frame_time, WALK_FRAME_SECONDS)
			needs_redraw = true
	else:
		if walk_frame != 0:
			walk_frame = 0
			needs_redraw = true
		walk_frame_time = 0.0
	if stats != null and stats.immune_level > 0:
		immune_angle = fmod(immune_angle + delta * 1.7, TAU)
		needs_redraw = true
	if needs_redraw:
		queue_redraw()

func get_highlight_body() -> UnitBody2D:
	return visual_body

func show_treatment_impulse() -> void:
	treatment_anim_time = 0.16
	queue_redraw()

func show_damage_flash() -> void:
	damage_flash_time = DAMAGE_FLASH_SECONDS
	queue_redraw()

func neutrophil_radius() -> float:
	if stats == null:
		return 0.0
	return 98.0 + float(stats.immune_level) * 18.0

func _draw() -> void:
	if doctor_texture != null:
		var moving := velocity.length_squared() > 1.0
		doctor_texture = VisualAssetCatalog.doctor_frame(last_facing, walk_frame, moving)
		var treatment_amount := treatment_anim_time / 0.16
		var damage_amount := clampf(damage_flash_time / DAMAGE_FLASH_SECONDS, 0.0, 1.0)
		var doctor_tint := Color.WHITE.lerp(Color(1.0, 0.46, 0.43, 1.0), damage_amount * 0.62)
		# Damage feedback deliberately changes only the tint. The small treatment
		# offset is unrelated to taking damage and never scales the character.
		draw_set_transform(Vector2(0.0, -treatment_amount), 0.0, Vector2.ONE)
		draw_texture_rect(doctor_texture, DOCTOR_DRAW_RECT, false, doctor_tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if stats == null or stats.immune_level <= 0:
		return
	var count := mini(stats.immune_level + 1, 4)
	var orbit_radius := neutrophil_radius() - 18.0
	for index in range(count):
		var angle := immune_angle + TAU * float(index) / float(count)
		var point := Vector2.from_angle(angle) * orbit_radius
		draw_circle(point + Vector2(0.0, 2.0), 12.0, Color(AlveolusVisualTheme.PETROL, 0.13))
		if immune_texture != null:
			draw_texture_rect(immune_texture, Rect2(point - Vector2.ONE * 12.0, Vector2.ONE * 24.0), false)
		else:
			draw_circle(point, 8.0, AlveolusVisualTheme.GOLD)
