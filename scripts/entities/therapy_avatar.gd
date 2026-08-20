class_name TherapyAvatar
extends CharacterBody2D

const MOVE_SPEED := PlayerStats.BASE_MOVEMENT_SPEED
const BODY_RADIUS := 23.0
const DAMAGE_FLASH_SECONDS := 0.16
const WALK_FRAME_SECONDS := 0.12
const DOCTOR_DRAW_RECT := Rect2(-30.0, -44.0, 60.0, 60.0)
const CHARACTER_NAME_TEXT := "Doctor Milos"
const CHARACTER_NAME_RECT := Rect2(-72.0, -71.0, 144.0, 24.0)

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
var character_name_label: Label
var _character_name_visible := false
var _defense_cell_count: int = 0
var _defense_cell_radius: float = 0.0
var _crowd_blocking := Vector2.ZERO

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
	_build_character_name_label()
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
		if direction.length_squared() > 0.0001 and _crowd_blocking.length_squared() > 0.0001:
			var blocking_normal := _crowd_blocking.normalized()
			var blocked_component := direction.dot(blocking_normal)
			if blocked_component > 0.0:
				# Remove only movement into the larger body. Tangential movement stays
				# available, so the player can slide out instead of being trapped.
				direction -= blocking_normal * blocked_component * clampf(_crowd_blocking.length(), 0.0, 1.0)
		var resolved_speed := stats.movement_speed if stats != null else MOVE_SPEED
		velocity = direction * resolved_speed
		move_and_slide()
		if topology != null:
			var wrapped := topology.wrap_position(global_position)
			if not wrapped.is_equal_approx(global_position):
				global_position = wrapped
				reset_physics_interpolation()
				camera.reset_smoothing()
	else:
		velocity = Vector2.ZERO


func set_crowd_blocking(blocking: Vector2) -> void:
	_crowd_blocking = blocking.limit_length(1.0)


func crowd_blocking() -> Vector2:
	return _crowd_blocking

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
	if needs_redraw:
		queue_redraw()

func get_highlight_body() -> UnitBody2D:
	return visual_body


func set_character_name_visible(visible_value: bool) -> void:
	_character_name_visible = visible_value
	if character_name_label != null:
		character_name_label.visible = visible_value


func is_character_name_visible() -> bool:
	return _character_name_visible


## DefenseCellWorld owns gameplay and publishes the identical orbit snapshot
## used here. The avatar never advances a second render-only orbit.
func set_defense_cell_snapshot(angle: float, count: int, radius: float) -> void:
	immune_angle = angle
	_defense_cell_count = clampi(count, 0, 12)
	_defense_cell_radius = maxf(radius, 0.0)
	queue_redraw()

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


func _build_character_name_label() -> void:
	character_name_label = Label.new()
	character_name_label.name = "CharacterName"
	character_name_label.text = CHARACTER_NAME_TEXT
	character_name_label.position = CHARACTER_NAME_RECT.position
	character_name_label.size = CHARACTER_NAME_RECT.size
	character_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	character_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_name_label.z_index = 3
	character_name_label.add_theme_font_override("font", AlveolusVisualTheme.heading_font())
	character_name_label.add_theme_font_size_override("font_size", AlveolusVisualTheme.TEXT_CAPTION)
	character_name_label.add_theme_color_override("font_color", AlveolusVisualTheme.IVORY)
	character_name_label.add_theme_color_override("font_outline_color", Color(AlveolusVisualTheme.PETROL, 0.92))
	character_name_label.add_theme_constant_override("outline_size", 3)
	character_name_label.visible = _character_name_visible
	add_child(character_name_label)

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

	if _defense_cell_count <= 0:
		return
	var count := _defense_cell_count
	var orbit_radius := _defense_cell_radius
	for index in range(count):
		var angle := immune_angle + TAU * float(index) / float(count)
		var point := Vector2.from_angle(angle) * orbit_radius
		draw_circle(point + Vector2(0.0, 2.0), 12.0, Color(AlveolusVisualTheme.PETROL, 0.13))
		if immune_texture != null:
			draw_texture_rect(immune_texture, Rect2(point - Vector2.ONE * 12.0, Vector2.ONE * 24.0), false)
		else:
			draw_circle(point, 8.0, AlveolusVisualTheme.GOLD)
