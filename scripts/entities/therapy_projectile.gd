class_name TherapyProjectile
extends Node2D

signal finished(projectile: TherapyProjectile)
signal discovery_ready(projectile: TherapyProjectile)

const DEFAULT_SPEED := 720.0

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
var _arena_min: Vector2 = Vector2.ZERO
var _arena_max: Vector2 = Vector2.ZERO
var _arena_size: Vector2 = Vector2.ZERO
var _arena_half_size: Vector2 = Vector2.ZERO

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
	_cache_topology_bounds()
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
	_cache_topology_bounds()
	speed = DEFAULT_SPEED
	travelled_distance = 0.0
	discovery_pending = false
	damage_source = source_id
	target_generation = target.activation_generation if is_instance_valid(target) else -1
	target_handle = entity_handle
	target_resolver = resolve_target
	direction = heading.normalized() if heading.length_squared() > 0.0001 else Vector2.RIGHT
	directional_mode = true
	maximum_distance = maxf(max_distance, 0.0)
	impact_distance = clampf(resolved_impact_distance, 0.0, maximum_distance) if resolved_impact_distance >= 0.0 else -1.0
	lifetime = maximum_distance / maxf(speed, 1.0) + 0.25
	rotation = direction.angle()
	reset_visual_motion()
	hide()
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	step_fixed(delta)

func step_fixed(delta: float) -> void:
	_begin_visual_step()
	lifetime -= delta
	if lifetime <= 0.0:
		_finish()
		return
	if directional_mode:
		var step_distance := speed * delta
		if impact_distance >= 0.0 and travelled_distance + step_distance >= impact_distance:
			global_position += direction * maxf(0.0, impact_distance - travelled_distance)
			travelled_distance = impact_distance
			if _target_is_current():
				target.take_damage(damage, damage_source)
			_finish()
			return
		if travelled_distance + step_distance >= maximum_distance:
			global_position += direction * maxf(0.0, maximum_distance - travelled_distance)
			travelled_distance = maximum_distance
			_finish()
			return
	elif _target_is_current():
		var target_delta := target.global_position - global_position
		if _arena_size.x > 0.0:
			if target_delta.x > _arena_half_size.x:
				target_delta.x -= _arena_size.x
			elif target_delta.x < -_arena_half_size.x:
				target_delta.x += _arena_size.x
		if _arena_size.y > 0.0:
			if target_delta.y > _arena_half_size.y:
				target_delta.y -= _arena_size.y
			elif target_delta.y < -_arena_half_size.y:
				target_delta.y += _arena_size.y
		var desired := target_delta.normalized()
		direction = direction.lerp(desired, clampf(delta * 7.0, 0.0, 1.0)).normalized()
		var hit_radius := target.definition.radius + 10.0
		if target_delta.length_squared() <= hit_radius * hit_radius:
			if _emit_discovery():
				return
			target.take_damage(damage, damage_source)
			_finish()
			return
	global_position += direction * speed * delta
	travelled_distance += speed * delta
	var wrapped := global_position
	if _arena_size.x > 0.0 and _arena_size.y > 0.0:
		if wrapped.x < _arena_min.x:
			wrapped.x += _arena_size.x
		elif wrapped.x >= _arena_max.x:
			wrapped.x -= _arena_size.x
		if wrapped.y < _arena_min.y:
			wrapped.y += _arena_size.y
		elif wrapped.y >= _arena_max.y:
			wrapped.y -= _arena_size.y
	var crossed_torus := wrapped != global_position
	if crossed_torus:
		global_position = wrapped
	rotation = direction.angle()
	if crossed_torus:
		reset_visual_motion()
	else:
		visual_current_position = global_position
		visual_current_angle = rotation
	if travelled_distance >= 52.0:
		_emit_discovery()

func _draw() -> void:
	draw_line(Vector2(-15.0, 2.0), Vector2(5.0, 2.0), Color(AlveolusVisualTheme.PETROL, 0.16), 7.0, true)
	draw_line(Vector2(-15.0, 0.0), Vector2(4.0, 0.0), Color(AlveolusVisualTheme.TURQUOISE, 0.36), 6.0, true)
	draw_circle(Vector2(5.0, 0.0), 6.0, AlveolusVisualTheme.TEAL)
	draw_circle(Vector2(4.0, -1.0), 2.4, Color("effffd"))

func _finish() -> void:
	set_physics_process(false)
	hide()
	finished.emit(self)

func recycle() -> void:
	set_physics_process(false)
	hide()
	target = null
	target_generation = -1
	target_handle = EntityHandle.INVALID
	target_resolver = Callable()
	topology = null
	_arena_size = Vector2.ZERO
	_arena_half_size = Vector2.ZERO
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


func _cache_topology_bounds() -> void:
	if topology == null:
		_arena_min = Vector2.ZERO
		_arena_max = Vector2.ZERO
		_arena_size = Vector2.ZERO
		_arena_half_size = Vector2.ZERO
		return
	_arena_min = topology.bounds.position
	_arena_max = topology.bounds.end
	_arena_size = topology.bounds.size
	_arena_half_size = _arena_size * 0.5

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
