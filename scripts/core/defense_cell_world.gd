class_name DefenseCellWorld
extends RefCounted

## Fixed-step gameplay owner for the orbiting defense cells. The avatar only
## renders the published orbit snapshot; damage is produced exclusively by a
## real overlap at a cell position.
signal enemy_hit(handle: int, damage: float)

const ORBIT_SPEED := 1.7
const MIN_HIT_INTERVAL := 0.1
const DEFAULT_HIT_RADIUS := 15.0

var topology: ArenaTopology
var avatar: Node2D
var query: CombatQuery
var count: int = 0
var orbit_radius: float = 0.0
var hit_radius: float = DEFAULT_HIT_RADIUS
var damage: float = 0.0
var hit_interval: float = MIN_HIT_INTERVAL
var angle: float = 0.0
var _cooldowns: PackedFloat32Array = PackedFloat32Array()


func configure(arena_topology: ArenaTopology, avatar_node: Node2D, combat_query: CombatQuery) -> DefenseCellWorld:
	topology = arena_topology
	avatar = avatar_node
	query = combat_query
	return self


func configure_stats(cell_count: int, radius: float, collision_radius: float, hit_damage: float, interval: float = MIN_HIT_INTERVAL) -> void:
	var next_count := clampi(cell_count, 0, 12)
	var count_changed := next_count != count
	count = next_count
	orbit_radius = maxf(0.0, radius)
	hit_radius = maxf(1.0, collision_radius)
	damage = maxf(0.0, hit_damage)
	hit_interval = maxf(MIN_HIT_INTERVAL, interval)
	if count_changed:
		var previous := _cooldowns
		_cooldowns = PackedFloat32Array()
		_cooldowns.resize(count)
		for index in range(count):
			_cooldowns[index] = previous[index] if index < previous.size() else 0.0
	_publish_visual_snapshot()


func clear() -> void:
	count = 0
	_cooldowns = PackedFloat32Array()
	_publish_visual_snapshot()


func step_fixed(delta: float) -> void:
	if count <= 0 or damage <= 0.0 or topology == null or not is_instance_valid(avatar) or query == null:
		return
	angle = fmod(angle + maxf(delta, 0.0) * ORBIT_SPEED, TAU)
	for index in range(count):
		_cooldowns[index] = maxf(0.0, _cooldowns[index] - delta)
		if _cooldowns[index] > 0.0:
			continue
		var handles := query.circle(cell_position(index), hit_radius)
		if handles.is_empty():
			continue
		var chosen := int(handles[0])
		for raw_handle in handles:
			chosen = mini(chosen, int(raw_handle))
		_cooldowns[index] = hit_interval
		enemy_hit.emit(chosen, damage)
	_publish_visual_snapshot()


func cell_position(index: int) -> Vector2:
	if count <= 0 or not is_instance_valid(avatar):
		return Vector2.ZERO
	var cell_angle := angle + TAU * float(posmod(index, count)) / float(count)
	return topology.wrap_position(avatar.global_position + Vector2.from_angle(cell_angle) * orbit_radius)


func _publish_visual_snapshot() -> void:
	if is_instance_valid(avatar) and avatar.has_method("set_defense_cell_snapshot"):
		avatar.call("set_defense_cell_snapshot", angle, count, orbit_radius)
