class_name AnalysisPickup
extends Node2D

signal collected(value: int)

var target: TherapyAvatar
var topology: ArenaTopology
var analysis_value: int = 1
var phase: float = 0.0
var trail_vector: Vector2 = Vector2.ZERO
var guided_to_target: bool = false

func configure(
	target_node: TherapyAvatar,
	value: int,
	arena_topology: ArenaTopology,
	start_phase: float = 0.0,
	guided: bool = false
) -> void:
	target = target_node
	analysis_value = value
	topology = arena_topology
	phase = start_phase
	trail_vector = Vector2.ZERO
	guided_to_target = guided
	show()
	set_physics_process(true)
	queue_redraw()

func absorb(value: int) -> void:
	analysis_value += maxi(value, 0)
	queue_redraw()

func recycle() -> void:
	set_physics_process(false)
	hide()
	target = null
	topology = null
	trail_vector = Vector2.ZERO
	guided_to_target = false

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or target.stats == null:
		return
	var target_delta := topology.shortest_delta(global_position, target.global_position)
	var distance_squared := target_delta.length_squared()
	var pickup_range := target.stats.pickup_range
	if not guided_to_target and distance_squared > pickup_range * pickup_range:
		if trail_vector != Vector2.ZERO:
			trail_vector = Vector2.ZERO
			queue_redraw()
		return
	var distance := sqrt(distance_squared)
	phase = fmod(phase + delta * 3.0, TAU)
	var speed := 680.0 if guided_to_target else lerpf(160.0, 520.0, 1.0 - distance / maxf(pickup_range, 1.0))
	var before := global_position
	if distance > 0.001:
		global_position += target_delta * (minf(speed * delta, distance) / distance)
	trail_vector = (before - global_position).limit_length(22.0)
	var wrapped := topology.wrap_position_if_needed(global_position)
	if not wrapped.is_equal_approx(global_position):
		global_position = wrapped
		reset_physics_interpolation()
	var remaining_squared := topology.distance_squared(global_position, target.global_position)
	if remaining_squared <= 28.0 * 28.0:
		set_physics_process(false)
		hide()
		collected.emit(analysis_value)
		return
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(phase) * 0.12
	var stack_scale := 1.0 + minf(log(maxf(float(analysis_value), 1.0)) * 0.13, 0.65)
	pulse *= stack_scale
	if trail_vector.length_squared() > 0.1:
		draw_line(trail_vector, Vector2.ZERO, Color(0.46, 0.67, 1.0, 0.34), 3.0, true)
	draw_circle(Vector2.ZERO, 10.0 * pulse, Color(0.45, 0.70, 1.0, 0.15))
	draw_circle(Vector2.ZERO, 5.5 * pulse, Color("76aaff"))
	draw_circle(Vector2(-1.5, -1.5), 1.8, Color("e9f2ff"))
