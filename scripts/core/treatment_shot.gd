class_name TreatmentShot
extends RefCounted

enum Mode {
	TRACKING,
	LINE,
	DIRECTIONAL,
}

var mode: Mode = Mode.TRACKING
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var target: Node2D
var damage: float = 0.0
var range_value: float = 0.0
var requested_range_value: float = 0.0
var max_hits: int = 1
var hit_radius: float = 13.0
var source_id: StringName = &"treatment"
var shorten_at_hit_capacity: bool = false
var resolution_valid: bool = false
var impact_distance: float = -1.0
var resolved_targets: Array = []
var resolved_handles: PackedInt64Array = PackedInt64Array()

static func tracking(from: Vector2, target_node: Node2D, amount: float, max_range: float, source: StringName) -> TreatmentShot:
	var shot := TreatmentShot.new()
	shot.mode = Mode.TRACKING
	shot.origin = from
	shot.target = target_node
	shot.damage = amount
	shot.range_value = max_range
	shot.requested_range_value = max_range
	shot.max_hits = 1
	shot.source_id = source
	return shot

## A projectile intent with a fixed heading. Unlike TRACKING, its target cannot
## silently change after the fixed-tick aim sample was taken.
static func directional(from: Vector2, heading: Vector2, amount: float, max_range: float, source: StringName) -> TreatmentShot:
	var shot := TreatmentShot.new()
	shot.mode = Mode.DIRECTIONAL
	shot.origin = from
	shot.direction = heading.normalized() if heading.length_squared() > 0.0001 else Vector2.RIGHT
	shot.damage = amount
	shot.range_value = maxf(max_range, 0.0)
	shot.requested_range_value = shot.range_value
	shot.max_hits = 1
	shot.shorten_at_hit_capacity = true
	shot.source_id = source
	return shot

static func line(from: Vector2, heading: Vector2, amount: float, max_range: float, hit_limit: int, source: StringName, stop_at_capacity: bool = false) -> TreatmentShot:
	var shot := TreatmentShot.new()
	shot.mode = Mode.LINE
	shot.origin = from
	shot.direction = heading.normalized() if heading.length_squared() > 0.0001 else Vector2.RIGHT
	shot.damage = amount
	shot.range_value = maxf(max_range, 0.0)
	shot.requested_range_value = shot.range_value
	shot.max_hits = maxi(1, hit_limit)
	shot.source_id = source
	shot.shorten_at_hit_capacity = stop_at_capacity
	return shot

## Resolves the shot once against the node compatibility path. The resulting
## hit list and range are the canonical snapshot for both damage and feedback.
func resolve_node_snapshot(candidates: Array, topology: ArenaTopology) -> Array:
	resolved_targets.clear()
	resolved_handles.clear()
	resolution_valid = mode == Mode.LINE or mode == Mode.DIRECTIONAL
	impact_distance = -1.0
	range_value = requested_range_value
	if not resolution_valid or topology == null:
		return resolved_targets
	var ranked := _node_hit_records(candidates, topology)
	for index in range(mini(max_hits, ranked.size())):
		resolved_targets.append(ranked[index].enemy)
	_apply_resolved_length(ranked)
	return resolved_targets.duplicate()

## The packed-world equivalent of resolve_node_snapshot(). Integrators should
## consume resolved_handles rather than querying again with the shortened
## visual range, because range_value may end at the target's body surface.
func resolve_query_snapshot(query: CombatQuery) -> PackedInt64Array:
	resolved_targets.clear()
	resolved_handles.clear()
	resolution_valid = mode == Mode.LINE or mode == Mode.DIRECTIONAL
	impact_distance = -1.0
	range_value = requested_range_value
	if not resolution_valid or query == null:
		return resolved_handles
	var ranked := query.line_hits(origin, direction, requested_range_value, hit_radius, max_hits)
	for item in ranked:
		var handle := int(item.get("handle", EntityHandle.INVALID))
		if EntityHandle.is_valid(handle):
			resolved_handles.append(handle)
			var resolved: Variant = query.resolve(handle)
			if typeof(resolved) == TYPE_OBJECT and is_instance_valid(resolved):
				resolved_targets.append(resolved)
	_apply_resolved_length(ranked)
	return resolved_handles.duplicate()

## Spread volleys share this exclusion set so a target hit by an earlier ray
## does not consume a later ray's penetration budget. The later ray keeps
## searching front-to-back and can therefore still damage another enemy.
func resolve_query_snapshot_excluding(query: CombatQuery, excluded_handles: Dictionary) -> PackedInt64Array:
	resolved_targets.clear()
	resolved_handles.clear()
	resolution_valid = mode == Mode.LINE or mode == Mode.DIRECTIONAL
	impact_distance = -1.0
	range_value = requested_range_value
	if not resolution_valid or query == null:
		return resolved_handles
	var query_limit := max_hits + excluded_handles.size()
	var ranked := query.line_hits(origin, direction, requested_range_value, hit_radius, query_limit)
	var accepted: Array[Dictionary] = []
	for item in ranked:
		var handle := int(item.get("handle", EntityHandle.INVALID))
		if not EntityHandle.is_valid(handle) or excluded_handles.has(handle):
			continue
		excluded_handles[handle] = true
		resolved_handles.append(handle)
		accepted.append(item)
		var resolved: Variant = query.resolve(handle)
		if typeof(resolved) == TYPE_OBJECT and is_instance_valid(resolved):
			resolved_targets.append(resolved)
		if resolved_handles.size() >= max_hits:
			break
	_apply_resolved_length(accepted)
	return resolved_handles.duplicate()

## Resolves a torus-aware line without allocating physics bodies. This keeps
## broad and piercing treatments cheap even in the 600-enemy stress scenario.
func resolve_line_hits(candidates: Array, topology: ArenaTopology) -> Array:
	if mode != Mode.LINE and mode != Mode.DIRECTIONAL:
		return []
	if resolution_valid:
		return resolved_targets.duplicate()
	return resolve_node_snapshot(candidates, topology)

func _node_hit_records(candidates: Array, topology: ArenaTopology) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for enemy in candidates:
		if not is_instance_valid(enemy) or not enemy.has_method("is_targetable") or not enemy.is_targetable():
			continue
		var delta := topology.shortest_delta(origin, enemy.global_position)
		var forward := delta.dot(direction)
		if forward < 0.0 or forward > requested_range_value:
			continue
		var lateral := absf(delta.cross(direction))
		var body_radius := _node_body_radius(enemy)
		var combined_radius := hit_radius + body_radius
		if lateral > combined_radius:
			continue
		var half_chord := sqrt(maxf(combined_radius * combined_radius - lateral * lateral, 0.0))
		ranked.append({
			"enemy": enemy,
			"forward": forward,
			"entry_distance": clampf(forward - half_chord, 0.0, requested_range_value),
			"exit_distance": clampf(forward + half_chord, 0.0, requested_range_value),
		})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_entry := float(left.entry_distance)
		var right_entry := float(right.entry_distance)
		if not is_equal_approx(left_entry, right_entry):
			return left_entry < right_entry
		return (left.enemy as Object).get_instance_id() < (right.enemy as Object).get_instance_id()
	)
	return ranked

func _node_body_radius(enemy: Object) -> float:
	var definition_value: Variant = enemy.get("definition")
	if typeof(definition_value) != TYPE_OBJECT or not is_instance_valid(definition_value):
		return 0.0
	var definition_object := definition_value as Object
	return maxf(float(definition_object.get("radius")), 0.0)

func _apply_resolved_length(ranked: Array) -> void:
	if not shorten_at_hit_capacity or ranked.size() < max_hits:
		return
	var last_index := mini(max_hits, ranked.size()) - 1
	impact_distance = clampf(float(ranked[last_index].get("entry_distance", requested_range_value)), 0.0, requested_range_value)
	range_value = impact_distance
