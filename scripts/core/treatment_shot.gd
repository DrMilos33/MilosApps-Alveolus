class_name TreatmentShot
extends RefCounted

enum Mode {
	TRACKING,
	LINE,
}

var mode: Mode = Mode.TRACKING
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var target: Node2D
var damage: float = 0.0
var range_value: float = 0.0
var max_hits: int = 1
var hit_radius: float = 13.0
var source_id: StringName = &"treatment"

static func tracking(from: Vector2, target_node: Node2D, amount: float, max_range: float, source: StringName) -> TreatmentShot:
	var shot := TreatmentShot.new()
	shot.mode = Mode.TRACKING
	shot.origin = from
	shot.target = target_node
	shot.damage = amount
	shot.range_value = max_range
	shot.max_hits = 1
	shot.source_id = source
	return shot

static func line(from: Vector2, heading: Vector2, amount: float, max_range: float, hit_limit: int, source: StringName) -> TreatmentShot:
	var shot := TreatmentShot.new()
	shot.mode = Mode.LINE
	shot.origin = from
	shot.direction = heading.normalized() if heading.length_squared() > 0.0001 else Vector2.RIGHT
	shot.damage = amount
	shot.range_value = max_range
	shot.max_hits = maxi(1, hit_limit)
	shot.source_id = source
	return shot

## Resolves a torus-aware line without allocating physics bodies. This keeps
## broad and piercing treatments cheap even in the 600-enemy stress scenario.
func resolve_line_hits(candidates: Array, topology: ArenaTopology) -> Array:
	if mode != Mode.LINE or topology == null:
		return []
	var ranked: Array[Dictionary] = []
	for enemy in candidates:
		if not is_instance_valid(enemy) or not enemy.has_method("is_targetable") or not enemy.is_targetable():
			continue
		var delta := topology.shortest_delta(origin, enemy.global_position)
		var forward := delta.dot(direction)
		if forward < 0.0 or forward > range_value:
			continue
		var lateral := absf(delta.cross(direction))
		var body_radius := 0.0
		if enemy.get("definition") != null:
			body_radius = float(enemy.definition.radius)
		if lateral > hit_radius + body_radius:
			continue
		ranked.append({"enemy": enemy, "forward": forward})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return float(left.forward) < float(right.forward))
	var result: Array = []
	for item in ranked:
		result.append(item.enemy)
		if result.size() >= max_hits:
			break
	return result

