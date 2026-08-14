class_name TherapyProjectile
extends Node2D

signal finished(projectile: TherapyProjectile)
signal discovery_ready(projectile: TherapyProjectile)

var target: InfectionEnemy
var topology: ArenaTopology
var direction: Vector2
var damage: float
var lifetime: float = 1.65
var speed: float = 720.0
var travelled_distance: float = 0.0
var discovery_pending: bool = false

func configure(target_enemy: InfectionEnemy, amount: float, arena_topology: ArenaTopology, should_announce: bool = false) -> void:
	target = target_enemy
	damage = amount
	topology = arena_topology
	lifetime = 1.65
	travelled_distance = 0.0
	discovery_pending = should_announce
	direction = Vector2.RIGHT
	if is_instance_valid(target):
		direction = topology.shortest_delta(global_position, target.global_position).normalized()
	rotation = direction.angle()
	show()
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		_finish()
		return
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		var target_delta := topology.shortest_delta(global_position, target.global_position)
		var desired := target_delta.normalized()
		direction = direction.lerp(desired, clampf(delta * 7.0, 0.0, 1.0)).normalized()
		var hit_radius := target.definition.radius + 10.0
		if target_delta.length_squared() <= hit_radius * hit_radius:
			if _emit_discovery():
				return
			target.take_damage(damage, &"therapy")
			_finish()
			return
	global_position += direction * speed * delta
	travelled_distance += speed * delta
	var wrapped := topology.wrap_position_if_needed(global_position)
	if not wrapped.is_equal_approx(global_position):
		global_position = wrapped
		reset_physics_interpolation()
	rotation = direction.angle()
	if travelled_distance >= 52.0:
		_emit_discovery()

func _draw() -> void:
	draw_line(Vector2(-13.0, 0.0), Vector2(4.0, 0.0), Color(0.33, 0.90, 0.84, 0.28), 5.0)
	draw_circle(Vector2(4.0, 0.0), 5.0, Color("66ead9"))
	draw_circle(Vector2(4.0, 0.0), 2.0, Color("e7fffb"))

func _finish() -> void:
	set_physics_process(false)
	hide()
	finished.emit(self)

func recycle() -> void:
	set_physics_process(false)
	hide()
	target = null
	topology = null
	direction = Vector2.ZERO
	travelled_distance = 0.0
	discovery_pending = false

func _emit_discovery() -> bool:
	if not discovery_pending:
		return false
	discovery_pending = false
	discovery_ready.emit(self)
	return true
