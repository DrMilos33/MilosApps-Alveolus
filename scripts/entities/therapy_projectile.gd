class_name TherapyProjectile
extends Node2D

signal finished(projectile: TherapyProjectile)
signal discovery_ready(projectile: TherapyProjectile)
signal hostile_hit(projectile: TherapyProjectile, amount: float, profile: DamageProfile)

const DEFAULT_SPEED := 576.0
const HOSTILE_NORMAL := 0
const HOSTILE_DIAMOND := 1
const HOSTILE_DOUBLE_TURN := 2
const HOSTILE_HIT_RADIUS := 10.0
const BOUNDARY_RADIUS := 14.0

var target: InfectionEnemy
var topology: ArenaTopology
var direction: Vector2
var damage: float
var lifetime: float = 1.65
var speed: float = DEFAULT_SPEED
var travelled_distance: float = 0.0
var discovery_pending: bool = false
var damage_source: StringName = &"therapy"
var visual_body: UnitBody2D
var target_generation: int = -1
var target_handle: int = EntityHandle.INVALID
var target_resolver: Callable
var visual_previous_position: Vector2 = Vector2.ZERO
var visual_current_position: Vector2 = Vector2.ZERO
var visual_previous_angle: float = 0.0
var visual_current_angle: float = 0.0
var visual_motion_initialized: bool = false
var directional_mode: bool = false
var maximum_distance: float = INF
var impact_distance: float = -1.0
var hostile_mode: bool = false
var hostile_target: TherapyAvatar
var hostile_damage_profile: DamageProfile
var hostile_pattern: int = HOSTILE_NORMAL
var hostile_pattern_phase: float = 0.0
var hostile_origin: Vector2 = Vector2.ZERO
var hostile_forward: Vector2 = Vector2.RIGHT
var hostile_right: Vector2 = Vector2.DOWN
var hostile_wave_amplitude: float = 0.0
var hostile_wave_length: float = 180.0
var hostile_width_multiplier: float = 1.0
var hostile_first_turn_distance: float = 0.0
var hostile_second_leg_distance: float = 0.0
var hostile_turn_sign: float = 1.0
var hostile_turn_count: int = 0

func _ready() -> void:
	visual_body = UnitBody2D.new()
	visual_body.configure_polygon(PackedVector2Array([Vector2(-14, -6), Vector2(9, -6), Vector2(13, 0), Vector2(9, 6), Vector2(-14, 6)]))
	add_child(visual_body)

func get_highlight_body() -> UnitBody2D:
	return visual_body

func configure(
	target_enemy: InfectionEnemy,
	amount: float,
	arena_topology: ArenaTopology,
	should_announce: bool = false,
	source_id: StringName = &"therapy",
	entity_handle: int = EntityHandle.INVALID,
	resolve_target: Callable = Callable(),
	move_speed: float = DEFAULT_SPEED
) -> void:
	target = target_enemy
	damage = amount
	topology = arena_topology
	lifetime = 1.65
	speed = maxf(move_speed, 0.0)
	travelled_distance = 0.0
	discovery_pending = should_announce
	damage_source = source_id
	target_generation = target.activation_generation if is_instance_valid(target) else -1
	target_handle = entity_handle
	target_resolver = resolve_target
	direction = Vector2.RIGHT
	directional_mode = false
	hostile_mode = false
	hostile_width_multiplier = 1.0
	_apply_visual_width()
	maximum_distance = INF
	impact_distance = -1.0
	if _target_is_current():
		direction = topology.shortest_delta(global_position, target.global_position).normalized()
	rotation = direction.angle()
	reset_visual_motion()
	# ProjectileWorld owns fixed stepping and ProjectileRenderer owns visibility.
	# Discovery projectiles are explicitly promoted to a stable detail path by
	# the renderer after registration.
	hide()
	set_physics_process(false)


## Configures a fixed-heading projectile from one immutable treatment shot.
## The optional target is generation-checked at impact time, but the heading
## and impact distance never retarget after the fixed-tick aim sample.
func configure_directional(
	heading: Vector2,
	amount: float,
	arena_topology: ArenaTopology,
	max_distance: float,
	resolved_impact_distance: float = -1.0,
	resolved_target: InfectionEnemy = null,
	entity_handle: int = EntityHandle.INVALID,
	resolve_target: Callable = Callable(),
	source_id: StringName = &"treatment"
) -> void:
	target = resolved_target
	damage = amount
	topology = arena_topology
	speed = DEFAULT_SPEED
	travelled_distance = 0.0
	discovery_pending = false
	damage_source = source_id
	target_generation = target.activation_generation if is_instance_valid(target) else -1
	target_handle = entity_handle
	target_resolver = resolve_target
	direction = heading.normalized() if heading.length_squared() > 0.0001 else Vector2.RIGHT
	directional_mode = true
	hostile_mode = false
	hostile_width_multiplier = 1.0
	_apply_visual_width()
	maximum_distance = maxf(max_distance, 0.0)
	impact_distance = clampf(resolved_impact_distance, 0.0, maximum_distance) if resolved_impact_distance >= 0.0 else -1.0
	lifetime = maximum_distance / maxf(speed, 1.0) + 0.25
	rotation = direction.angle()
	reset_visual_motion()
	hide()
	set_physics_process(false)


func configure_hostile(
	heading: Vector2,
	amount: float,
	arena_topology: ArenaTopology,
	player: TherapyAvatar,
	profile: DamageProfile,
	pattern: int = HOSTILE_NORMAL,
	pattern_phase: float = 0.0,
	move_speed: float = 230.0,
	max_distance: float = 1050.0,
	wave_amplitude: float = 44.0,
	wave_length: float = 180.0,
	width_multiplier: float = 1.0,
	first_turn_distance: float = 0.0,
	second_leg_distance: float = 0.0
) -> void:
	target = null
	damage = maxf(0.0, amount)
	topology = arena_topology
	speed = maxf(move_speed, 1.0)
	travelled_distance = 0.0
	discovery_pending = false
	damage_source = &"enemy_projectile"
	target_generation = -1
	target_handle = EntityHandle.INVALID
	target_resolver = Callable()
	direction = heading.normalized() if heading.length_squared() > 0.0001 else Vector2.RIGHT
	directional_mode = false
	maximum_distance = maxf(max_distance, 1.0)
	impact_distance = -1.0
	lifetime = maximum_distance / speed + 0.35
	hostile_mode = true
	hostile_target = player
	hostile_damage_profile = profile
	hostile_pattern = pattern
	hostile_pattern_phase = fposmod(pattern_phase, 1.0)
	hostile_origin = global_position
	hostile_forward = direction
	hostile_right = Vector2(-direction.y, direction.x)
	hostile_wave_amplitude = maxf(0.0, wave_amplitude) if pattern == HOSTILE_DIAMOND else 0.0
	hostile_wave_length = maxf(32.0, wave_length)
	hostile_width_multiplier = maxf(width_multiplier, 0.1)
	hostile_first_turn_distance = maxf(first_turn_distance, 0.0)
	hostile_second_leg_distance = maxf(second_leg_distance, 0.0)
	hostile_turn_sign = -1.0 if hostile_pattern_phase < 0.5 else 1.0
	hostile_turn_count = 0
	_apply_visual_width()
	rotation = direction.angle()
	reset_visual_motion()
	hide()
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	step_fixed(delta)

func step_fixed(delta: float) -> void:
	_begin_visual_step()
	if _finish_if_outside_bounded_arena(global_position):
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_finish()
		return
	if hostile_mode:
		_step_hostile(delta)
		return
	if directional_mode:
		var step_distance := speed * delta
		if impact_distance >= 0.0 and travelled_distance + step_distance >= impact_distance:
			var impact_position := global_position + direction * maxf(0.0, impact_distance - travelled_distance)
			if _finish_if_outside_bounded_arena(impact_position):
				return
			global_position = impact_position
			travelled_distance = impact_distance
			if _target_is_current():
				target.take_damage(damage, damage_source)
			_finish()
			return
		if travelled_distance + step_distance >= maximum_distance:
			var final_position := global_position + direction * maxf(0.0, maximum_distance - travelled_distance)
			if _finish_if_outside_bounded_arena(final_position):
				return
			global_position = final_position
			travelled_distance = maximum_distance
			_finish()
			return
	elif _target_is_current():
		var target_delta := topology.shortest_delta(global_position, target.global_position) if topology != null else target.global_position - global_position
		var desired := target_delta.normalized()
		direction = direction.lerp(desired, clampf(delta * 7.0, 0.0, 1.0)).normalized()
		var hit_radius := target.definition.radius + 10.0
		if target_delta.length_squared() <= hit_radius * hit_radius:
			if _emit_discovery():
				return
			target.take_damage(damage, damage_source)
			_finish()
			return
	var next_position := global_position + direction * speed * delta
	if _finish_if_outside_bounded_arena(next_position):
		return
	global_position = next_position
	travelled_distance += speed * delta
	var resolved := topology.resolve_position(global_position) if topology != null else global_position
	var crossed_boundary := not resolved.is_equal_approx(global_position)
	if crossed_boundary:
		global_position = resolved
	rotation = direction.angle()
	if crossed_boundary:
		reset_visual_motion()
	else:
		visual_current_position = global_position
		visual_current_angle = rotation
	if travelled_distance >= 52.0:
		_emit_discovery()


func _step_hostile(delta: float) -> void:
	if hostile_pattern == HOSTILE_DOUBLE_TURN:
		_step_hostile_double_turn(delta)
		return
	var previous_position := global_position
	travelled_distance = minf(maximum_distance, travelled_distance + speed * delta)
	var lateral_offset := 0.0
	if hostile_pattern == HOSTILE_DIAMOND:
		var wave_position := fposmod(travelled_distance / hostile_wave_length + hostile_pattern_phase, 1.0)
		var triangle := 1.0 - 4.0 * absf(wave_position - 0.5)
		lateral_offset = triangle * hostile_wave_amplitude
	var unwrapped := hostile_origin + hostile_forward * travelled_distance + hostile_right * lateral_offset
	if _finish_if_outside_bounded_arena(unwrapped):
		return
	global_position = topology.resolve_position(unwrapped) if topology != null else unwrapped
	var motion := topology.shortest_delta(previous_position, global_position) if topology != null else global_position - previous_position
	if motion.length_squared() > 0.0001:
		direction = motion.normalized()
		rotation = direction.angle()
	var crossed_torus := not (global_position - previous_position).is_equal_approx(motion)
	if crossed_torus:
		reset_visual_motion()
	else:
		visual_current_position = global_position
		visual_current_angle = rotation
	_finish_hostile_if_hit_or_complete()


func _step_hostile_double_turn(delta: float) -> void:
	var previous_position := global_position
	var remaining := minf(speed * delta, maximum_distance - travelled_distance)
	while remaining > 0.0001:
		var next_turn_distance := INF
		if hostile_turn_count == 0 and hostile_first_turn_distance > 0.0:
			next_turn_distance = hostile_first_turn_distance
		elif hostile_turn_count == 1 and hostile_second_leg_distance > 0.0:
			next_turn_distance = hostile_first_turn_distance + hostile_second_leg_distance
		var segment := remaining
		if is_finite(next_turn_distance):
			segment = minf(segment, maxf(next_turn_distance - travelled_distance, 0.0))
		if segment > 0.0001:
			var next_position := global_position + direction * segment
			if _finish_if_outside_bounded_arena(next_position):
				return
			global_position = topology.resolve_position(next_position) if topology != null else next_position
			travelled_distance += segment
			remaining -= segment
		if is_finite(next_turn_distance) and travelled_distance >= next_turn_distance - 0.0001:
			direction = direction.rotated(hostile_turn_sign * PI * 0.5).normalized()
			hostile_turn_count += 1
			rotation = direction.angle()
			continue
		break
	var motion := topology.shortest_delta(previous_position, global_position) if topology != null else global_position - previous_position
	var crossed_torus := not (global_position - previous_position).is_equal_approx(motion)
	if crossed_torus:
		reset_visual_motion()
	else:
		visual_current_position = global_position
		visual_current_angle = rotation
	_finish_hostile_if_hit_or_complete()


func _finish_hostile_if_hit_or_complete() -> bool:
	if is_instance_valid(hostile_target):
		var hit_radius := TherapyAvatar.BODY_RADIUS + HOSTILE_HIT_RADIUS * hostile_width_multiplier
		var distance_squared := topology.distance_squared(global_position, hostile_target.global_position) if topology != null else global_position.distance_squared_to(hostile_target.global_position)
		if distance_squared <= hit_radius * hit_radius:
			hostile_hit.emit(self, damage, hostile_damage_profile)
			_finish()
			return true
	if travelled_distance >= maximum_distance:
		_finish()
		return true
	return false

func _draw() -> void:
	draw_line(Vector2(-15.0, 2.0), Vector2(5.0, 2.0), Color(AlveolusVisualTheme.PETROL, 0.16), 7.0, true)
	draw_line(Vector2(-15.0, 0.0), Vector2(4.0, 0.0), Color(AlveolusVisualTheme.TURQUOISE, 0.36), 6.0, true)
	draw_circle(Vector2(5.0, 0.0), 6.0, AlveolusVisualTheme.TEAL)
	draw_circle(Vector2(4.0, -1.0), 2.4, Color("effffd"))

func _finish() -> void:
	set_physics_process(false)
	hide()
	finished.emit(self)


func _finish_if_outside_bounded_arena(position: Vector2) -> bool:
	if topology == null or not topology.is_bounded() or topology.contains_position(position, BOUNDARY_RADIUS):
		return false
	_finish()
	return true

func recycle() -> void:
	set_physics_process(false)
	hide()
	target = null
	target_generation = -1
	target_handle = EntityHandle.INVALID
	target_resolver = Callable()
	topology = null
	direction = Vector2.ZERO
	lifetime = 1.65
	speed = DEFAULT_SPEED
	travelled_distance = 0.0
	discovery_pending = false
	damage_source = &"therapy"
	visual_motion_initialized = false
	directional_mode = false
	maximum_distance = INF
	impact_distance = -1.0
	hostile_mode = false
	hostile_target = null
	hostile_damage_profile = null
	hostile_pattern = HOSTILE_NORMAL
	hostile_pattern_phase = 0.0
	hostile_origin = Vector2.ZERO
	hostile_forward = Vector2.RIGHT
	hostile_right = Vector2.DOWN
	hostile_wave_amplitude = 0.0
	hostile_wave_length = 180.0
	hostile_width_multiplier = 1.0
	hostile_first_turn_distance = 0.0
	hostile_second_leg_distance = 0.0
	hostile_turn_sign = 1.0
	hostile_turn_count = 0
	_apply_visual_width()


func _apply_visual_width() -> void:
	if visual_body != null:
		visual_body.scale = Vector2(1.0, hostile_width_multiplier if hostile_mode else 1.0)


func reset_visual_motion() -> void:
	visual_previous_position = global_position
	visual_current_position = global_position
	visual_previous_angle = rotation
	visual_current_angle = rotation
	visual_motion_initialized = true
	reset_physics_interpolation()


func visual_interpolated_position(interpolation_fraction: float) -> Vector2:
	if not visual_motion_initialized:
		return global_position
	return visual_previous_position.lerp(visual_current_position, clampf(interpolation_fraction, 0.0, 1.0))


func visual_interpolated_angle(interpolation_fraction: float) -> float:
	if not visual_motion_initialized:
		return rotation
	return lerp_angle(visual_previous_angle, visual_current_angle, clampf(interpolation_fraction, 0.0, 1.0))


func _begin_visual_step() -> void:
	if not visual_motion_initialized:
		reset_visual_motion()
		return
	visual_previous_position = visual_current_position
	visual_current_position = global_position
	visual_previous_angle = visual_current_angle
	visual_current_angle = rotation


func _emit_discovery() -> bool:
	if not discovery_pending:
		return false
	discovery_pending = false
	discovery_ready.emit(self)
	return true

func _target_is_current() -> bool:
	if target == null:
		return false
	var generation_matches := (
		is_instance_valid(target)
		and not target.is_queued_for_deletion()
		and target.is_generation_valid(target_generation)
	)
	if not generation_matches:
		return false
	if EntityHandle.is_valid(target_handle) and target_resolver.is_valid():
		return target_resolver.call(target_handle) == target
	return true
