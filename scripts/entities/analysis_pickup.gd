class_name AnalysisPickup
extends Node2D

signal collected(value: int)

const DEFAULT_GUIDED_SPEED := 680.0
const BODY_RADIUS := 12.0

var target: TherapyAvatar
var topology: ArenaTopology
var analysis_value: int = 1
var phase: float = 0.0
var trail_vector: Vector2 = Vector2.ZERO
var guided_to_target: bool = false
var guided_speed: float = DEFAULT_GUIDED_SPEED
var decorative_trail_enabled: bool = true
var visual_texture: Texture2D
var visual_body: UnitBody2D
var visual_previous_position: Vector2 = Vector2.ZERO
var visual_current_position: Vector2 = Vector2.ZERO
var visual_previous_size: Vector2 = Vector2.ZERO
var visual_current_size: Vector2 = Vector2.ZERO
var visual_motion_initialized: bool = false

func _ready() -> void:
	visual_texture = VisualAssetCatalog.gameplay_sprite(&"analysis_pickup")
	visual_body = UnitBody2D.new()
	visual_body.configure_circle(12.0, Vector2.ZERO, 24)
	add_child(visual_body)

func get_highlight_body() -> UnitBody2D:
	return visual_body

func configure(
	target_node: TherapyAvatar,
	value: int,
	arena_topology: ArenaTopology,
	start_phase: float = 0.0,
	guided: bool = false,
	move_speed: float = DEFAULT_GUIDED_SPEED
) -> void:
	target = target_node
	analysis_value = value
	topology = arena_topology
	if topology != null:
		global_position = topology.resolve_position(global_position, BODY_RADIUS)
	phase = start_phase
	trail_vector = Vector2.ZERO
	guided_to_target = guided
	guided_speed = maxf(move_speed, 0.0)
	reset_visual_snapshot()
	# PickupWorld steps this state and CrowdRenderer selects its one visual path.
	hide()
	set_physics_process(false)
	queue_redraw()

func absorb(value: int) -> void:
	analysis_value += maxi(value, 0)
	visual_current_size = _visual_size()
	queue_redraw()

func recycle() -> void:
	set_physics_process(false)
	hide()
	target = null
	topology = null
	trail_vector = Vector2.ZERO
	guided_to_target = false
	guided_speed = DEFAULT_GUIDED_SPEED
	visual_motion_initialized = false

func _physics_process(delta: float) -> void:
	step_fixed(delta)

func step_fixed(delta: float) -> void:
	_begin_visual_step()
	if topology != null:
		var bounded_position := topology.resolve_position(global_position, BODY_RADIUS)
		if not bounded_position.is_equal_approx(global_position):
			global_position = bounded_position
			if topology.is_wrapping():
				reset_visual_motion()
			else:
				visual_current_position = global_position
	if not is_instance_valid(target) or target.stats == null:
		return
	var target_delta := topology.shortest_delta(global_position, target.global_position) if topology != null else target.global_position - global_position
	var distance_squared := target_delta.length_squared()
	var pickup_range := target.stats.pickup_range
	if not guided_to_target and distance_squared > pickup_range * pickup_range:
		if trail_vector != Vector2.ZERO:
			trail_vector = Vector2.ZERO
			queue_redraw()
		return
	var distance := sqrt(distance_squared)
	phase = fmod(phase + delta * 3.0, TAU)
	var speed := guided_speed if guided_to_target else lerpf(160.0, 520.0, 1.0 - distance / maxf(pickup_range, 1.0))
	var before := global_position
	if distance > 0.001:
		global_position += target_delta * (minf(speed * delta, distance) / distance)
	trail_vector = (before - global_position).limit_length(22.0)
	var resolved := topology.resolve_position(global_position, BODY_RADIUS) if topology != null else global_position
	if not resolved.is_equal_approx(global_position):
		global_position = resolved
		if topology != null and topology.is_wrapping():
			reset_visual_motion()
		else:
			visual_current_position = global_position
	else:
		visual_current_position = global_position
	visual_current_size = _visual_size()
	var remaining_distance := maxf(0.0, distance - speed * delta)
	if remaining_distance <= 28.0:
		set_physics_process(false)
		hide()
		collected.emit(analysis_value)
		return
	queue_redraw()


func reset_visual_motion() -> void:
	visual_previous_position = global_position
	visual_current_position = global_position
	visual_motion_initialized = true
	reset_physics_interpolation()


func reset_visual_snapshot() -> void:
	reset_visual_motion()
	visual_current_size = _visual_size()
	visual_previous_size = visual_current_size


func visual_interpolated_position(interpolation_fraction: float) -> Vector2:
	if not visual_motion_initialized:
		return global_position
	return visual_previous_position.lerp(visual_current_position, clampf(interpolation_fraction, 0.0, 1.0))


func visual_interpolated_size(interpolation_fraction: float) -> Vector2:
	return visual_previous_size.lerp(visual_current_size, clampf(interpolation_fraction, 0.0, 1.0))


func _begin_visual_step() -> void:
	if not visual_motion_initialized:
		reset_visual_snapshot()
		return
	visual_previous_position = visual_current_position
	visual_current_position = global_position
	visual_previous_size = visual_current_size


func _visual_size() -> Vector2:
	var stack_scale := 1.0 + minf(log(maxf(float(analysis_value), 1.0)) * 0.13, 0.65)
	var pulse := 1.0 + sin(phase) * 0.06
	return Vector2.ONE * 28.0 * stack_scale * pulse


func _draw() -> void:
	var pulse := 1.0 + sin(phase) * 0.12
	var stack_scale := 1.0 + minf(log(maxf(float(analysis_value), 1.0)) * 0.13, 0.65)
	pulse *= stack_scale
	if decorative_trail_enabled and trail_vector.length_squared() > 0.1:
		draw_line(trail_vector, Vector2.ZERO, Color(AlveolusVisualTheme.COBALT, 0.28), 3.0, true)
	draw_circle(Vector2.ZERO, 11.0 * pulse, Color(AlveolusVisualTheme.COBALT, 0.12))
	if visual_texture != null:
		draw_texture_rect(visual_texture, Rect2(Vector2.ONE * -14.0 * pulse, Vector2.ONE * 28.0 * pulse), false)
	else:
		draw_circle(Vector2.ZERO, 6.0 * pulse, AlveolusVisualTheme.COBALT)
