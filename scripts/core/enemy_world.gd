class_name EnemyWorld
extends NodeEntityRegistry

var combat_capacity := CombatCapacity.defaults()
var regular_count: int = 0
var critical_count: int = 0
var _critical_by_slot: PackedByteArray = PackedByteArray()
var _typed_enemies: Array[InfectionEnemy] = []
var _typed_runtime_only: bool = true
var _crowd_topology: ArenaTopology
var _crowd_avatar: TherapyAvatar
var _crowd_grid := CombatSpatialGrid.new()
var _crowd_bounded: bool = false
var _crowd_candidates := PackedInt64Array()
var _crowd_nearest_candidates := PackedInt64Array()
var _crowd_nearest_distances := PackedFloat32Array()
var _crowd_constraint_normals := PackedVector2Array()
var _crowd_constraint_limits := PackedFloat32Array()
var _crowd_lane_signs := PackedInt32Array()
var _crowd_lane_holds := PackedInt32Array()
var _crowd_contact_latched := PackedByteArray()
var _crowd_resolved_directions := PackedVector2Array()
var _crowd_resolved_speeds := PackedFloat32Array()
var _crowd_motion_guards := PackedByteArray()
var _crowd_motion_guard_counts := PackedByteArray()
var _direct_collision_mixed_guard_sets := PackedByteArray()
var _crowd_motion_guard_neighbors := PackedInt64Array()
var _crowd_motion_guard_distances := PackedFloat32Array()
var _direct_collision_radii := PackedFloat32Array()
var _direct_collision_active := PackedByteArray()
var _direct_collision_active_count: int = 0
var _direct_collision_blocker_handles := PackedInt64Array()
var _direct_collision_clear_ticks := PackedInt32Array()
var _direct_collision_corridor_blockers := PackedInt64Array()
var _direct_collision_corridor_directions := PackedVector2Array()
var _direct_collision_corridor_clearances := PackedFloat32Array()
var _direct_collision_corridor_open := PackedByteArray()
var _direct_collision_corridor_side_blockers := PackedInt64Array()
var _direct_collision_corridor_epochs := PackedInt64Array()
var _direct_collision_queued := PackedByteArray()
var _direct_collision_queue_blockers := PackedInt64Array()
var _direct_collision_previous_lane_signs := PackedInt32Array()
var _avatar_body_candidates := PackedInt64Array()
var _avatar_push_candidates := PackedInt64Array()
var _deferred_contact_candidates := PackedInt64Array()
var _contact_ring_owners := PackedInt64Array()
var _contact_ring_claim_starts := PackedInt32Array()
var _contact_ring_claim_spans := PackedInt32Array()
var _contact_ring_wait_starts := PackedInt32Array()
var _contact_ring_wait_ranks := PackedInt32Array()
var _contact_ring_wait_counts := PackedInt32Array()
var _contact_ring_attack_armed := PackedByteArray()
var _contact_ring_reclaim_holds := PackedInt32Array()
var _maximum_body_radius: float = 72.0
var _maximum_crowd_radius: float = 97.2
var _maximum_contact_radius: float = 1.0
var _crowd_phase: int = 0
var _direct_collision_prepare_epoch: int = 0
var _direct_collision_grid_dirty: bool = true
var _crowd_avatar_previous_position := Vector2.ZERO
var _crowd_avatar_position_valid: bool = false
var _crowd_avatar_stationary_this_tick: bool = true
var _contact_ring_active: bool = false
var _contact_ring_assignments_dirty: bool = false
var _contact_ring_saturated: bool = false
var _contact_ring_stationary_seconds: float = 0.0
var _contact_ring_moving_seconds: float = 0.0
var _crowd_elapsed_seconds: float = 0.0
var _crowd_profile_enabled: bool = false
var _crowd_profile_counters := PackedInt64Array()
var _bulk_eligible := PackedByteArray()
var _bulk_allowed := PackedByteArray()
var _bulk_pending := PackedByteArray()
var _bulk_active := PackedByteArray()
var _bulk_candidate_snapshots := PackedByteArray()
var _bulk_release_snapshots := PackedByteArray()
var _bulk_side_signs := PackedInt32Array()
var _bulk_lease_epochs := PackedInt64Array()
var _bulk_component_roots := PackedInt32Array()
var _bulk_blends := PackedFloat32Array()
var _bulk_origins := PackedVector2Array()
var _bulk_proposals := PackedVector2Array()
var _bulk_resolved := PackedVector2Array()
var _bulk_direct_directions := PackedVector2Array()
var _bulk_union_parents := PackedInt32Array()
var _bulk_union_ranks := PackedByteArray()
var _bulk_root_weights := PackedInt32Array()
var _bulk_root_queued_weights := PackedInt32Array()
var _bulk_root_min_handles := PackedInt64Array()
var _bulk_root_candidate_snapshots := PackedByteArray()
var _bulk_root_release_snapshots := PackedByteArray()
var _bulk_root_side_signs := PackedInt32Array()
var _bulk_root_lease_epochs := PackedInt64Array()
var _bulk_root_active := PackedByteArray()
var _bulk_neighbor_counts := PackedByteArray()
var _bulk_neighbor_handles := PackedInt64Array()
var _bulk_neighbor_distances := PackedFloat32Array()
var _bulk_build_neighbor_counts := PackedByteArray()
var _bulk_build_neighbor_handles := PackedInt64Array()
var _bulk_build_neighbor_distances := PackedFloat32Array()
var _bulk_ordered_slots := PackedInt32Array()
var _bulk_refresh_handles := PackedInt64Array()
var _bulk_snapshot_seconds: float = 0.0
var _bulk_next_lease_epoch: int = 1
var _bulk_refresh_cursor: int = 0
var _bulk_refresh_chunk_size: int = 0
var _bulk_refresh_in_progress: bool = false

enum CrowdProfileCounter {
	GRID_REBUILDS,
	GUARD_QUERIES,
	GUARD_CANDIDATES,
	CORRIDOR_EVALUATIONS,
	ACTIVE_BYPASS_TICKS,
	QUEUED_NO_CORRIDOR,
	BYPASS_STARTS,
	SIDE_SWITCHES,
	GRID_REBUILD_USEC,
	GUARD_PREPARE_USEC,
	MOVEMENT_USEC,
	BULK_SNAPSHOTS,
	BULK_ACTIVE_TICKS,
	BULK_PROJECTION_CANDIDATES,
	BULK_SOLVE_USEC,
	COUNT,
}

const AVATAR_SPACING_FACTOR := 1.0
const MAX_CROWD_NEIGHBORS := 6
const MAX_CROWD_QUERY_CANDIDATES := 21
const MAX_CROWD_MOTION_GUARDS := 16
const MAX_AVATAR_NEIGHBORS := 12
const SMALL_ENEMY_ID := &"pneumococcus"
const CROWD_NEIGHBOR_MARGIN := 18.0
const MAX_CROWD_RADIUS_FACTOR := 1.25
const FRONT_PRIORITY_EPSILON := 3.0
const FRONT_ALIGNMENT_MINIMUM := 0.18
const BYPASS_HOLD_UPDATES := 6
const BYPASS_BIAS_MINIMUM := 0.28
const BYPASS_BIAS_MAXIMUM := 0.58
const MINIMUM_FORWARD_PROGRESS := 0.0
const STATIONARY_AVATAR_SPEED_THRESHOLD := 12.0
const CONTACT_ENTRY_DEPTH := 1.0
const CONTACT_RELEASE_MARGIN := 4.0
const CROWD_UPDATE_PHASES := 6
const CROWD_MOTION_LOOKAHEAD_SECONDS := 13.0 / 60.0
const CROWD_MOTION_CLEARANCE := 2.0
const CROWD_MOTION_QUERY_MARGIN := 30.0
const CROWD_GRID_CELL_SIZE := 40.0
const DIRECT_COLLISION_PASSES := 2
const DIRECT_COLLISION_SKIN := 0.05
const DIRECT_COLLISION_EPSILON := 0.0001
const DIRECT_COLLISION_UPDATE_PHASES := 24
const DIRECT_COLLISION_GUARD_LOOKAHEAD := 50.0
const DIRECT_COLLISION_BYPASS_ACTIVATION_MARGIN := 8.0
const DIRECT_COLLISION_BYPASS_FORWARD_WEIGHT := 0.55
const DIRECT_COLLISION_BYPASS_LATERAL_WEIGHT := 0.835
const DIRECT_COLLISION_BYPASS_CLEAR_TICKS := 5
const DIRECT_COLLISION_CORRIDOR_RADII := 3.0
const DIRECT_COLLISION_CORRIDOR_DIRECTION_DOT := 0.98
const AVATAR_BODY_COLLISION_PASSES := 3
const AVATAR_BODY_COLLISION_SKIN := 0.05
const SMALL_AVATAR_PUSH_SPEED := 48.0
const CONTACT_RING_MICRO_SLOTS := 12
const CONTACT_RING_SMALL_SPAN := 2
const CONTACT_RING_CLUSTER_SPAN := 3
const CONTACT_RING_MAX_HARD_BODIES := 2
const CONTACT_RING_STATIONARY_ENTER_SECONDS := 0.25
const CONTACT_RING_MOVING_EXIT_SECONDS := 0.10
const CONTACT_RING_RESERVATION_MARGIN := 150.0
const CONTACT_RING_RESERVATION_RELEASE_MARGIN := 36.0
const CONTACT_RING_WAIT_MARGIN := 4.0
const CONTACT_RING_TARGET_TOLERANCE := 0.9
const CONTACT_RING_ATTACK_ARM_MARGIN := CONTACT_ENTRY_DEPTH + 0.1
const CONTACT_RING_CLAIM_CLEARANCE := 1.0
const CONTACT_RING_RECLAIM_HOLD_UPDATES := 6
const CLUSTER_ENEMY_ID := &"bacterial_cluster"
const BULK_CONTACT_MARGIN := 4.0
const BULK_SNAPSHOT_SECONDS := 0.25
const BULK_ENTER_WEIGHT := 18
const BULK_EXIT_WEIGHT := 12
const BULK_ENTER_QUEUED_RATIO := 0.45
const BULK_EXIT_QUEUED_RATIO := 0.20
const BULK_ENTER_SNAPSHOTS := 2
const BULK_EXIT_SNAPSHOTS := 4
const BULK_ARC_RADIANS := deg_to_rad(20.0)
const BULK_BLEND_IN_SECONDS := 0.20
const BULK_BLEND_OUT_SECONDS := 0.35
const BULK_PROJECTION_PASSES := 1
const BULK_BLEND_EPSILON := 0.001
const BULK_PAIR_LOOKAHEAD := 34.0
const MAX_BULK_NEIGHBORS := 8
const MAX_BULK_SNAPSHOT_CANDIDATES := 24
const BULK_SNAPSHOT_BUILD_PHASES := 4

func configure_enemy_world(runtime_capacity: CombatCapacity = null) -> EnemyWorld:
	combat_capacity = runtime_capacity if runtime_capacity != null else CombatCapacity.defaults()
	super.configure(combat_capacity.max_enemies, &"step_fixed")
	_critical_by_slot.resize(combat_capacity.max_enemies)
	_critical_by_slot.fill(0)
	_typed_enemies.resize(combat_capacity.max_enemies)
	_typed_enemies.fill(null)
	_crowd_lane_signs.resize(combat_capacity.max_enemies)
	_crowd_lane_signs.fill(0)
	_crowd_lane_holds.resize(combat_capacity.max_enemies)
	_crowd_lane_holds.fill(0)
	_crowd_contact_latched.resize(combat_capacity.max_enemies)
	_crowd_contact_latched.fill(0)
	_crowd_resolved_directions.resize(combat_capacity.max_enemies)
	_crowd_resolved_directions.fill(Vector2.ZERO)
	_crowd_resolved_speeds.resize(combat_capacity.max_enemies)
	_crowd_resolved_speeds.fill(1.0)
	_crowd_motion_guards.resize(combat_capacity.max_enemies)
	_crowd_motion_guards.fill(0)
	_crowd_motion_guard_counts.resize(combat_capacity.max_enemies)
	_crowd_motion_guard_counts.fill(0)
	_direct_collision_mixed_guard_sets.resize(combat_capacity.max_enemies)
	_direct_collision_mixed_guard_sets.fill(0)
	_crowd_motion_guard_neighbors.resize(combat_capacity.max_enemies * MAX_CROWD_MOTION_GUARDS)
	_crowd_motion_guard_neighbors.fill(EntityHandle.INVALID)
	_crowd_motion_guard_distances.resize(combat_capacity.max_enemies * MAX_CROWD_MOTION_GUARDS)
	_crowd_motion_guard_distances.fill(INF)
	_direct_collision_radii.resize(combat_capacity.max_enemies)
	_direct_collision_radii.fill(0.0)
	_direct_collision_active.resize(combat_capacity.max_enemies)
	_direct_collision_active.fill(0)
	_direct_collision_active_count = 0
	_direct_collision_blocker_handles.resize(combat_capacity.max_enemies)
	_direct_collision_blocker_handles.fill(EntityHandle.INVALID)
	_direct_collision_clear_ticks.resize(combat_capacity.max_enemies)
	_direct_collision_clear_ticks.fill(0)
	_direct_collision_corridor_blockers.resize(combat_capacity.max_enemies)
	_direct_collision_corridor_blockers.fill(EntityHandle.INVALID)
	_direct_collision_corridor_directions.resize(combat_capacity.max_enemies)
	_direct_collision_corridor_directions.fill(Vector2.ZERO)
	_direct_collision_corridor_clearances.resize(combat_capacity.max_enemies * 2)
	_direct_collision_corridor_clearances.fill(-INF)
	_direct_collision_corridor_open.resize(combat_capacity.max_enemies * 2)
	_direct_collision_corridor_open.fill(0)
	_direct_collision_corridor_side_blockers.resize(combat_capacity.max_enemies * 2)
	_direct_collision_corridor_side_blockers.fill(EntityHandle.INVALID)
	_direct_collision_corridor_epochs.resize(combat_capacity.max_enemies)
	_direct_collision_corridor_epochs.fill(-1)
	_direct_collision_queued.resize(combat_capacity.max_enemies)
	_direct_collision_queued.fill(0)
	_direct_collision_queue_blockers.resize(combat_capacity.max_enemies)
	_direct_collision_queue_blockers.fill(EntityHandle.INVALID)
	_direct_collision_previous_lane_signs.resize(combat_capacity.max_enemies)
	_direct_collision_previous_lane_signs.fill(0)
	_contact_ring_owners.resize(CONTACT_RING_MICRO_SLOTS)
	_contact_ring_owners.fill(EntityHandle.INVALID)
	_contact_ring_claim_starts.resize(combat_capacity.max_enemies)
	_contact_ring_claim_starts.fill(-1)
	_contact_ring_claim_spans.resize(combat_capacity.max_enemies)
	_contact_ring_claim_spans.fill(0)
	_contact_ring_wait_starts.resize(combat_capacity.max_enemies)
	_contact_ring_wait_starts.fill(-1)
	_contact_ring_wait_ranks.resize(combat_capacity.max_enemies)
	_contact_ring_wait_ranks.fill(0)
	_contact_ring_wait_counts.resize(CONTACT_RING_MICRO_SLOTS)
	_contact_ring_wait_counts.fill(0)
	_contact_ring_attack_armed.resize(combat_capacity.max_enemies)
	_contact_ring_attack_armed.fill(0)
	_contact_ring_reclaim_holds.resize(combat_capacity.max_enemies)
	_contact_ring_reclaim_holds.fill(0)
	_bulk_eligible.resize(combat_capacity.max_enemies)
	_bulk_eligible.fill(0)
	_bulk_allowed.resize(combat_capacity.max_enemies)
	_bulk_allowed.fill(0)
	_bulk_pending.resize(combat_capacity.max_enemies)
	_bulk_pending.fill(0)
	_bulk_active.resize(combat_capacity.max_enemies)
	_bulk_active.fill(0)
	_bulk_candidate_snapshots.resize(combat_capacity.max_enemies)
	_bulk_candidate_snapshots.fill(0)
	_bulk_release_snapshots.resize(combat_capacity.max_enemies)
	_bulk_release_snapshots.fill(0)
	_bulk_side_signs.resize(combat_capacity.max_enemies)
	_bulk_side_signs.fill(0)
	_bulk_lease_epochs.resize(combat_capacity.max_enemies)
	_bulk_lease_epochs.fill(0)
	_bulk_component_roots.resize(combat_capacity.max_enemies)
	_bulk_component_roots.fill(-1)
	_bulk_blends.resize(combat_capacity.max_enemies)
	_bulk_blends.fill(0.0)
	_bulk_origins.resize(combat_capacity.max_enemies)
	_bulk_origins.fill(Vector2.ZERO)
	_bulk_proposals.resize(combat_capacity.max_enemies)
	_bulk_proposals.fill(Vector2.ZERO)
	_bulk_resolved.resize(combat_capacity.max_enemies)
	_bulk_resolved.fill(Vector2.ZERO)
	_bulk_direct_directions.resize(combat_capacity.max_enemies)
	_bulk_direct_directions.fill(Vector2.ZERO)
	_bulk_union_parents.resize(combat_capacity.max_enemies)
	_bulk_union_parents.fill(-1)
	_bulk_union_ranks.resize(combat_capacity.max_enemies)
	_bulk_union_ranks.fill(0)
	_bulk_root_weights.resize(combat_capacity.max_enemies)
	_bulk_root_weights.fill(0)
	_bulk_root_queued_weights.resize(combat_capacity.max_enemies)
	_bulk_root_queued_weights.fill(0)
	_bulk_root_min_handles.resize(combat_capacity.max_enemies)
	_bulk_root_min_handles.fill(EntityHandle.INVALID)
	_bulk_root_candidate_snapshots.resize(combat_capacity.max_enemies)
	_bulk_root_candidate_snapshots.fill(0)
	_bulk_root_release_snapshots.resize(combat_capacity.max_enemies)
	_bulk_root_release_snapshots.fill(0)
	_bulk_root_side_signs.resize(combat_capacity.max_enemies)
	_bulk_root_side_signs.fill(0)
	_bulk_root_lease_epochs.resize(combat_capacity.max_enemies)
	_bulk_root_lease_epochs.fill(0)
	_bulk_root_active.resize(combat_capacity.max_enemies)
	_bulk_root_active.fill(0)
	_bulk_neighbor_counts.resize(combat_capacity.max_enemies)
	_bulk_neighbor_counts.fill(0)
	_bulk_neighbor_handles.resize(combat_capacity.max_enemies * MAX_BULK_NEIGHBORS)
	_bulk_neighbor_handles.fill(EntityHandle.INVALID)
	_bulk_neighbor_distances.resize(combat_capacity.max_enemies * MAX_BULK_NEIGHBORS)
	_bulk_neighbor_distances.fill(INF)
	_bulk_build_neighbor_counts.resize(combat_capacity.max_enemies)
	_bulk_build_neighbor_counts.fill(0)
	_bulk_build_neighbor_handles.resize(combat_capacity.max_enemies * MAX_BULK_NEIGHBORS)
	_bulk_build_neighbor_handles.fill(EntityHandle.INVALID)
	_bulk_build_neighbor_distances.resize(combat_capacity.max_enemies * MAX_BULK_NEIGHBORS)
	_bulk_build_neighbor_distances.fill(INF)
	_bulk_ordered_slots.clear()
	_bulk_refresh_handles.clear()
	_typed_runtime_only = true
	regular_count = 0
	critical_count = 0
	_maximum_contact_radius = 1.0
	_crowd_phase = 0
	_direct_collision_prepare_epoch = 0
	_direct_collision_grid_dirty = true
	_crowd_avatar_previous_position = Vector2.ZERO
	_crowd_avatar_position_valid = false
	_crowd_avatar_stationary_this_tick = true
	_contact_ring_active = false
	_contact_ring_assignments_dirty = false
	_contact_ring_saturated = false
	_contact_ring_stationary_seconds = 0.0
	_contact_ring_moving_seconds = 0.0
	_crowd_elapsed_seconds = 0.0
	_bulk_snapshot_seconds = 0.0
	_bulk_next_lease_epoch = 1
	_bulk_refresh_cursor = 0
	_bulk_refresh_chunk_size = 0
	_bulk_refresh_in_progress = false
	_crowd_profile_counters.resize(CrowdProfileCounter.COUNT)
	_crowd_profile_counters.fill(0)
	return self


func set_crowd_profile_enabled(enabled: bool) -> void:
	_crowd_profile_enabled = enabled
	reset_crowd_profile_counters()


func reset_crowd_profile_counters() -> void:
	if _crowd_profile_counters.size() != CrowdProfileCounter.COUNT:
		_crowd_profile_counters.resize(CrowdProfileCounter.COUNT)
	_crowd_profile_counters.fill(0)


func crowd_profile_snapshot() -> PackedInt64Array:
	return _crowd_profile_counters.duplicate()


## Configures the shared broad phase for the direct-chase body boundary. Enemy
## locomotion remains aimed at Doctor Milos; the world only clips a proposed
## step against another enemy's authored damage-contact circle and preserves a
## tangential remainder when one exists.
func configure_crowd_collision(
	arena_topology: ArenaTopology,
	avatar_node: TherapyAvatar,
	maximum_body_radius: float = 72.0
) -> EnemyWorld:
	_crowd_topology = arena_topology
	_crowd_bounded = arena_topology != null and arena_topology.is_bounded()
	_crowd_avatar = avatar_node
	_crowd_avatar_position_valid = is_instance_valid(avatar_node)
	_crowd_avatar_previous_position = avatar_node.global_position if _crowd_avatar_position_valid else Vector2.ZERO
	_crowd_avatar_stationary_this_tick = true
	_maximum_body_radius = maxf(maximum_body_radius, 1.0)
	_maximum_crowd_radius = _maximum_body_radius * MAX_CROWD_RADIUS_FACTOR
	_crowd_grid.configure(arena_topology, CROWD_GRID_CELL_SIZE)
	_direct_collision_grid_dirty = true
	return self

func register_enemy(enemy: Node, critical: bool = false, disable_automatic_physics: bool = true) -> int:
	if not is_instance_valid(enemy):
		return EntityHandle.INVALID
	var existing := allocated_handle_for(enemy)
	if existing != EntityHandle.INVALID:
		# Logical retirement invalidates targeting immediately, but the Node may
		# only be registered again after its physical lease has been flushed.
		return existing if is_active(existing) else EntityHandle.INVALID
	if not combat_capacity.can_allocate_enemy(regular_count, critical_count, critical):
		return EntityHandle.INVALID
	var handle := _register_new_entity(enemy, disable_automatic_physics)
	if not EntityHandle.is_valid(handle):
		return handle
	var slot := EntityHandle.slot(handle)
	if enemy is InfectionEnemy:
		var typed_enemy := enemy as InfectionEnemy
		_typed_enemies[slot] = typed_enemy
		_direct_collision_radii[slot] = typed_enemy.contact_body_radius()
		var collision_active := typed_enemy.definition != null and typed_enemy.is_targetable()
		_direct_collision_active[slot] = 1 if collision_active else 0
		if collision_active and _crowd_topology != null:
			_crowd_grid.insert_unique(handle, typed_enemy.global_position)
			_direct_collision_active_count += 1
		_maximum_contact_radius = maxf(_maximum_contact_radius, _direct_collision_radii[slot])
	else:
		# Generic test/dynamic entities retain the defensive Callable path.
		_typed_runtime_only = false
	_critical_by_slot[slot] = 1 if critical else 0
	# Lane state is reset only at a new physical lease. The first real blocker
	# selects a side and hysteresis keeps it stable through the complete pass.
	_crowd_lane_signs[slot] = 0
	_crowd_lane_holds[slot] = 0
	_crowd_contact_latched[slot] = 0
	_crowd_resolved_directions[slot] = Vector2.ZERO
	_crowd_resolved_speeds[slot] = 1.0
	_crowd_motion_guards[slot] = 0
	_crowd_motion_guard_counts[slot] = 0
	_direct_collision_mixed_guard_sets[slot] = 0
	_direct_collision_blocker_handles[slot] = EntityHandle.INVALID
	_direct_collision_clear_ticks[slot] = 0
	_invalidate_direct_collision_corridor(slot)
	_direct_collision_queued[slot] = 0
	_direct_collision_queue_blockers[slot] = EntityHandle.INVALID
	_direct_collision_previous_lane_signs[slot] = 0
	_contact_ring_claim_starts[slot] = -1
	_contact_ring_claim_spans[slot] = 0
	_contact_ring_wait_starts[slot] = -1
	_contact_ring_wait_ranks[slot] = 0
	_contact_ring_attack_armed[slot] = 0
	_contact_ring_reclaim_holds[slot] = 0
	_clear_bulk_slot(slot)
	_bulk_allowed[slot] = 1
	if _contact_ring_active:
		_contact_ring_assignments_dirty = true
		_contact_ring_saturated = false
	if critical:
		critical_count += 1
	else:
		regular_count += 1
	return handle

func register_entity(entity: Node, disable_automatic_physics: bool = true) -> int:
	return register_enemy(entity, false, disable_automatic_physics)


## Reuses the incrementally maintained direct-collision broad phase for
## placement queries. Callers must fall back to their complete registry index
## while materializing or generic entities are present.
func query_collision_candidates(
	center: Vector2,
	radius: float,
	output: PackedInt64Array = PackedInt64Array()
) -> PackedInt64Array:
	if _direct_collision_grid_dirty:
		_rebuild_direct_collision_grid()
	return _crowd_grid.query_circle_candidates(center, radius, output)


func collision_index_covers_all_active_enemies() -> bool:
	return _typed_runtime_only and _direct_collision_active_count == active_count()

func is_critical(handle: int) -> bool:
	return is_active(handle) and _critical_by_slot[EntityHandle.slot(handle)] != 0


## Game calls this immediately before TherapyAvatar.step_fixed(). The avatar's
## requested displacement is clipped against the same authored contact circles
## that deal damage. Large bodies are hard obstacles; small bacteria yield at a
## bounded physical push speed without changing either actor's movement stat.
func prepare_avatar_body_interaction(delta: float) -> void:
	if not is_instance_valid(_crowd_avatar):
		return
	var requested_delta := _crowd_avatar.desired_movement_delta(delta)
	if delta <= 0.0 or requested_delta.length_squared() <= DIRECT_COLLISION_EPSILON or _crowd_topology == null:
		_crowd_avatar.prepare_crowd_movement(requested_delta, requested_delta)
		return
	var movement_origin := _crowd_avatar.global_position
	var query_radius := (
		TherapyAvatar.CONTACT_RADIUS
		+ _maximum_contact_radius
		+ requested_delta.length()
		+ AVATAR_BODY_COLLISION_SKIN
	)
	_avatar_body_candidates = _crowd_grid.query_circle_candidates(
		movement_origin,
		query_radius,
		_avatar_body_candidates
	)
	var resolved_delta := requested_delta
	# Hard bodies are resolved first so a pushed small bacterium can never carry
	# Doctor Milos through a cluster, herd, ranged unit or boss behind it.
	for _pass_index in range(AVATAR_BODY_COLLISION_PASSES):
		var hard_changed := false
		for handle_value in _avatar_body_candidates:
			var handle := int(handle_value)
			var slot := EntityHandle.slot(handle)
			var enemy := _active_collision_enemy(handle)
			if enemy == null or enemy.definition.id == SMALL_ENEMY_ID:
				continue
			var clipped := _clip_avatar_delta_against_enemy(movement_origin, resolved_delta, enemy, slot)
			if not clipped.is_equal_approx(resolved_delta):
				resolved_delta = clipped
				hard_changed = true
		if not hard_changed:
			break

	# Small bodies remain real obstacles, but may be displaced slowly. The Doctor
	# advances only by the distance the bacterium could physically yield this tick.
	for _push_pass_index in range(2):
		var push_changed := false
		for push_handle_value in _avatar_body_candidates:
			var push_handle := int(push_handle_value)
			var push_enemy := _active_collision_enemy(push_handle)
			if push_enemy == null or push_enemy.definition.id != SMALL_ENEMY_ID:
				continue
			var pushed := _resolve_avatar_small_body(
				push_handle,
				movement_origin,
				resolved_delta,
				delta
			)
			if not pushed.is_equal_approx(resolved_delta):
				resolved_delta = pushed
				push_changed = true
		if not push_changed:
			break
	# A small-body projection may change the endpoint tangent. Reapply hard
	# constraints so that yielding bacteria can never open a path through a large
	# body at the side of the same contact pack.
	for _final_pass_index in range(AVATAR_BODY_COLLISION_PASSES):
		var final_changed := false
		for final_handle_value in _avatar_body_candidates:
			var final_handle := int(final_handle_value)
			var final_slot := EntityHandle.slot(final_handle)
			var final_enemy := _active_collision_enemy(final_handle)
			if final_enemy == null or final_enemy.definition.id == SMALL_ENEMY_ID:
				continue
			var final_clipped := _clip_avatar_delta_against_enemy(
				movement_origin,
				resolved_delta,
				final_enemy,
				final_slot
			)
			if not final_clipped.is_equal_approx(resolved_delta):
				resolved_delta = final_clipped
				final_changed = true
		if not final_changed:
			break

	var requested_direction := requested_delta.normalized()
	var forward_component := resolved_delta.dot(requested_direction)
	if forward_component < 0.0:
		resolved_delta -= requested_direction * forward_component
	_crowd_avatar.prepare_crowd_movement(resolved_delta, requested_delta)


## Relocation keeps the registry lease and entity state. Only local collision
## history is invalidated so the next direct-chase tick cannot reuse a stale
## blocker from the enemy's former sector.
func mark_enemy_relocated(handle: int, previous_position: Vector2 = Vector2.INF) -> bool:
	if not is_active(handle):
		return false
	var slot := EntityHandle.slot(handle)
	if slot < 0 or slot >= _typed_enemies.size():
		return false
	_invalidate_direct_collision_guard_slot(slot)
	var bulk_was_allowed := _bulk_allowed[slot] != 0
	_clear_bulk_slot(slot)
	_bulk_allowed[slot] = 1 if bulk_was_allowed else 0
	var enemy := _typed_enemies[slot]
	if (
		previous_position.is_finite()
		and enemy != null
		and _direct_collision_active[slot] != 0
		and not _direct_collision_grid_dirty
	):
		_release_relocated_blocker_from_neighbors(previous_position, handle)
		_crowd_grid.move(handle, previous_position, enemy.global_position)
		_insert_relocated_guard_for_neighbors(enemy.global_position, handle)
	else:
		_direct_collision_grid_dirty = true
		_invalidate_all_direct_collision_guards()
	return true


func _release_relocated_blocker_from_neighbors(position: Vector2, relocated_handle: int) -> void:
	var invalidation_radius := DIRECT_COLLISION_GUARD_LOOKAHEAD + _maximum_contact_radius * 2.0
	_crowd_candidates = _crowd_grid.query_circle_candidates(
		position,
		invalidation_radius,
		_crowd_candidates
	)
	for candidate_handle_value in _crowd_candidates:
		var candidate_handle := int(candidate_handle_value)
		if candidate_handle == relocated_handle or not is_active(candidate_handle):
			continue
		var candidate_slot := EntityHandle.slot(candidate_handle)
		if (
			int(_direct_collision_blocker_handles[candidate_slot]) == relocated_handle
			or int(_direct_collision_corridor_blockers[candidate_slot]) == relocated_handle
		):
			_invalidate_direct_collision_guard_slot(candidate_slot)


func _insert_relocated_guard_for_neighbors(position: Vector2, relocated_handle: int) -> void:
	var invalidation_radius := DIRECT_COLLISION_GUARD_LOOKAHEAD + _maximum_contact_radius * 2.0
	_crowd_candidates = _crowd_grid.query_circle_candidates(
		position,
		invalidation_radius,
		_crowd_candidates
	)
	for candidate_handle_value in _crowd_candidates:
		var candidate_handle := int(candidate_handle_value)
		if candidate_handle == relocated_handle or not is_active(candidate_handle):
			continue
		var candidate_slot := EntityHandle.slot(candidate_handle)
		# The arrival can close an already leased side. Clear that intent now,
		# insert the concrete body into the bounded collision guards, and let the
		# normal 24-phase refresh decide whether a new corridor exists.
		_clear_direct_collision_bypass(candidate_slot)
		_insert_direct_collision_guard(candidate_slot, relocated_handle)


func _insert_direct_collision_guard(slot: int, guard_handle: int) -> void:
	var enemy := _typed_enemies[slot]
	var guard_enemy := _active_collision_enemy(guard_handle)
	if enemy == null or guard_enemy == null:
		return
	var guard_slot := EntityHandle.slot(guard_handle)
	var guard_offset := slot * MAX_CROWD_MOTION_GUARDS
	var guard_count := int(_crowd_motion_guard_counts[slot])
	for guard_index in range(guard_count):
		if int(_crowd_motion_guard_neighbors[guard_offset + guard_index]) == guard_handle:
			return
	var center_delta := (
		guard_enemy.global_position - enemy.global_position
		if _crowd_bounded
		else _crowd_topology.shortest_delta(enemy.global_position, guard_enemy.global_position)
	)
	var surface_clearance := (
		center_delta.length()
		- float(_direct_collision_radii[slot])
		- float(_direct_collision_radii[guard_slot])
	)
	if surface_clearance > DIRECT_COLLISION_GUARD_LOOKAHEAD:
		return
	var guard_limit := _direct_collision_guard_limit(slot, float(_direct_collision_radii[slot]))
	var destination_index := guard_count
	if guard_count < guard_limit:
		guard_count += 1
	else:
		destination_index = 0
		for guard_index in range(1, guard_count):
			var stored_distance := float(_crowd_motion_guard_distances[guard_offset + destination_index])
			var candidate_distance := float(_crowd_motion_guard_distances[guard_offset + guard_index])
			if candidate_distance > stored_distance:
				destination_index = guard_index
		var worst_distance := float(_crowd_motion_guard_distances[guard_offset + destination_index])
		if surface_clearance >= worst_distance:
			return
	_crowd_motion_guard_neighbors[guard_offset + destination_index] = guard_handle
	_crowd_motion_guard_distances[guard_offset + destination_index] = surface_clearance
	_crowd_motion_guard_counts[slot] = guard_count
	_crowd_motion_guards[slot] = 1


func _invalidate_all_direct_collision_guards() -> void:
	for slot_value in _active_slots:
		var active_slot := int(slot_value)
		if _retiring[active_slot] == 0:
			_invalidate_direct_collision_guard_slot(active_slot)


func _invalidate_direct_collision_guard_slot(slot: int) -> void:
	if slot < 0 or slot >= _crowd_motion_guards.size():
		return
	_clear_direct_collision_bypass(slot)
	_direct_collision_queued[slot] = 0
	_direct_collision_queue_blockers[slot] = EntityHandle.INVALID
	_crowd_motion_guards[slot] = 0
	_crowd_motion_guard_counts[slot] = 0
	_direct_collision_mixed_guard_sets[slot] = 0


func _active_collision_enemy(handle: int) -> InfectionEnemy:
	var slot := EntityHandle.slot(handle)
	if (
		slot < 0
		or slot >= _typed_enemies.size()
		or _retiring[slot] != 0
		or _generations[slot] != EntityHandle.generation(handle)
		or _direct_collision_active[slot] == 0
	):
		return null
	var enemy := _typed_enemies[slot]
	return enemy if enemy != null and enemy.definition != null and enemy.is_targetable() else null


func _clip_avatar_delta_against_enemy(
	movement_origin: Vector2,
	requested_delta: Vector2,
	enemy: InfectionEnemy,
	enemy_slot: int
) -> Vector2:
	var to_enemy := (
		enemy.global_position - movement_origin
		if _crowd_bounded
		else _crowd_topology.shortest_delta(movement_origin, enemy.global_position)
	)
	var minimum_distance := TherapyAvatar.CONTACT_RADIUS + enemy.contact_body_radius()
	if (to_enemy - requested_delta).length_squared() >= minimum_distance * minimum_distance:
		return requested_delta
	var distance_squared := to_enemy.length_squared()
	var contact_normal := Vector2.ZERO
	var allowed_inward := 0.0
	if distance_squared <= DIRECT_COLLISION_EPSILON:
		contact_normal = Vector2.from_angle(float((enemy_slot * 53 + 17) % 360) * PI / 180.0)
	else:
		var distance := sqrt(distance_squared)
		contact_normal = to_enemy / distance
		allowed_inward = maxf(distance - minimum_distance - AVATAR_BODY_COLLISION_SKIN, 0.0)
	var inward_component := requested_delta.dot(contact_normal)
	if inward_component <= allowed_inward:
		return requested_delta
	return requested_delta - contact_normal * (inward_component - allowed_inward)


func _resolve_avatar_small_body(
	handle: int,
	movement_origin: Vector2,
	requested_delta: Vector2,
	delta: float
) -> Vector2:
	var slot := EntityHandle.slot(handle)
	var enemy := _active_collision_enemy(handle)
	if enemy == null:
		return requested_delta
	# An explicitly stunned/knocked body keeps its combat trajectory and behaves
	# as a hard obstacle for this tick; ordinary player contact never adds stun.
	if enemy.is_stunned():
		return _clip_avatar_delta_against_enemy(movement_origin, requested_delta, enemy, slot)
	var to_enemy := (
		enemy.global_position - movement_origin
		if _crowd_bounded
		else _crowd_topology.shortest_delta(movement_origin, enemy.global_position)
	)
	var minimum_distance := TherapyAvatar.CONTACT_RADIUS + enemy.contact_body_radius()
	if (to_enemy - requested_delta).length_squared() >= minimum_distance * minimum_distance:
		return requested_delta
	var distance_squared := to_enemy.length_squared()
	var contact_normal := Vector2.ZERO
	var allowed_inward := 0.0
	if distance_squared <= DIRECT_COLLISION_EPSILON:
		contact_normal = Vector2.from_angle(float((slot * 53 + 17) % 360) * PI / 180.0)
	else:
		var distance := sqrt(distance_squared)
		contact_normal = to_enemy / distance
		allowed_inward = maxf(distance - minimum_distance - AVATAR_BODY_COLLISION_SKIN, 0.0)
	var inward_component := requested_delta.dot(contact_normal)
	if inward_component <= allowed_inward:
		return requested_delta
	var required_yield := inward_component - allowed_inward
	var requested_push := minf(required_yield, SMALL_AVATAR_PUSH_SPEED * delta)
	var allowed_push := _small_body_push_distance(handle, enemy, contact_normal, requested_push)
	var actual_push := 0.0
	if allowed_push > DIRECT_COLLISION_EPSILON:
		var previous_position := enemy.global_position
		enemy.apply_crowd_resolved_position(previous_position + contact_normal * allowed_push)
		var movement := (
			enemy.global_position - previous_position
			if _crowd_bounded
			else _crowd_topology.shortest_delta(previous_position, enemy.global_position)
		)
		actual_push = maxf(movement.dot(contact_normal), 0.0)
		_crowd_grid.move(handle, previous_position, enemy.global_position)
	var unresolved_inward := maxf(required_yield - actual_push, 0.0)
	return requested_delta - contact_normal * unresolved_inward


func _small_body_push_distance(
	handle: int,
	enemy: InfectionEnemy,
	push_direction: Vector2,
	requested_distance: float
) -> float:
	if requested_distance <= DIRECT_COLLISION_EPSILON:
		return 0.0
	var own_radius := enemy.contact_body_radius()
	_avatar_push_candidates = _crowd_grid.query_circle_candidates(
		enemy.global_position,
		own_radius + _maximum_contact_radius + requested_distance + AVATAR_BODY_COLLISION_SKIN,
		_avatar_push_candidates
	)
	var allowed_distance := requested_distance
	for other_handle_value in _avatar_push_candidates:
		var other_handle := int(other_handle_value)
		if other_handle == handle:
			continue
		var other := _active_collision_enemy(other_handle)
		if other == null:
			continue
		var to_other := (
			other.global_position - enemy.global_position
			if _crowd_bounded
			else _crowd_topology.shortest_delta(enemy.global_position, other.global_position)
		)
		var forward := to_other.dot(push_direction)
		if forward <= 0.0:
			continue
		var minimum_distance := own_radius + other.contact_body_radius()
		var lateral_squared := maxf(to_other.length_squared() - forward * forward, 0.0)
		var minimum_squared := minimum_distance * minimum_distance
		if lateral_squared >= minimum_squared:
			continue
		var first_contact := forward - sqrt(maxf(minimum_squared - lateral_squared, 0.0))
		allowed_distance = minf(allowed_distance, maxf(first_contact - AVATAR_BODY_COLLISION_SKIN, 0.0))
	if _crowd_bounded and allowed_distance > 0.0:
		var candidate := enemy.global_position + push_direction * allowed_distance
		var bounded := _crowd_topology.resolve_position(candidate, enemy.definition.radius)
		allowed_distance = minf(allowed_distance, maxf((bounded - enemy.global_position).dot(push_direction), 0.0))
	return allowed_distance


func step_fixed(delta: float, session: RunSession = null) -> void:
	if not _typed_runtime_only:
		super.step_fixed(delta, session)
		return
	if delta <= 0.0:
		flush_deferred()
		return
	# Direct pursuit owns the desired movement. EnemyWorld supplies the exact
	# contact-circle boundary and a short cached side corridor. A follower with
	# no open corridor suppresses only its chase displacement; there are no
	# position slots, lane targets or self-generated retreat vectors.
	var profile_started_usec := Time.get_ticks_usec() if _crowd_profile_enabled else 0
	_update_crowd_avatar_motion_state()
	var grid_was_dirty := _direct_collision_grid_dirty
	if grid_was_dirty:
		_rebuild_direct_collision_grid()
	if _crowd_profile_enabled:
		if grid_was_dirty:
			_crowd_profile_counters[CrowdProfileCounter.GRID_REBUILDS] += 1
		_crowd_profile_counters[CrowdProfileCounter.GRID_REBUILD_USEC] += Time.get_ticks_usec() - profile_started_usec
		profile_started_usec = Time.get_ticks_usec()
	_direct_collision_prepare_epoch += 1
	_prepare_direct_collision_guards()
	_update_bulk_flow_state(delta)
	if _crowd_profile_enabled:
		_crowd_profile_counters[CrowdProfileCounter.GUARD_PREPARE_USEC] += Time.get_ticks_usec() - profile_started_usec
		profile_started_usec = Time.get_ticks_usec()
	# Production EnemyWorld leases contain only InfectionEnemy instances. Their
	# renderer and pool are released before a slot can be reused, so this typed
	# dense loop avoids 600 validity checks and dynamic Callable invocations per
	# fixed tick while retaining deterministic slot order.
	_bulk_pending.fill(0)
	var count_at_start := _active_slots.size()
	for dense_index in range(count_at_start):
		var slot := int(_active_slots[dense_index])
		if _retiring[slot] != 0:
			continue
		var enemy := _typed_enemies[slot]
		if enemy != null:
			var handle := EntityHandle.make(slot, _generations[slot])
			var movement_origin := enemy.global_position
			var occupied_before := _direct_collision_active[slot] != 0
			var bulk_motion := (
				occupied_before
				and _bulk_blends[slot] > BULK_BLEND_EPSILON
				and _bulk_enemy_eligible(enemy)
			)
			var suppress_direct_chase := (
				occupied_before
				and not bulk_motion
				and _direct_collision_queued[slot] != 0
				and _crowd_lane_signs[slot] == 0
				and not enemy.is_stunned()
				and _queued_blocker_still_at_contact(slot, enemy)
			)
			if suppress_direct_chase:
				enemy.step_queued_fixed(delta, true)
			else:
				enemy.step_fixed(delta, true)
			var occupied_after := enemy.definition != null and enemy.is_targetable()
			if occupied_before != occupied_after:
				_direct_collision_active_count += 1 if occupied_after else -1
			_direct_collision_active[slot] = 1 if occupied_after else 0
			if occupied_before and occupied_after:
				if bulk_motion:
					_bulk_origins[slot] = movement_origin
					_bulk_proposals[slot] = _bulk_desired_delta(slot, enemy, movement_origin, delta)
					_bulk_resolved[slot] = _bulk_proposals[slot]
					_bulk_pending[slot] = 1
					_direct_collision_queued[slot] = 0
					_direct_collision_queue_blockers[slot] = EntityHandle.INVALID
					enemy.apply_crowd_resolved_position(movement_origin)
				elif suppress_direct_chase:
					if _crowd_profile_enabled:
						_crowd_profile_counters[CrowdProfileCounter.QUEUED_NO_CORRIDOR] += 1
				else:
					_resolve_direct_collision(slot, enemy, movement_origin)
					if not enemy.global_position.is_equal_approx(movement_origin):
						_crowd_grid.move(handle, movement_origin, enemy.global_position)
			elif occupied_before:
				_crowd_grid.remove(handle, movement_origin)
			elif occupied_after:
				_crowd_grid.insert_unique(handle, enemy.global_position)
	_resolve_bulk_movements()
	_resolve_deferred_enemy_contacts()
	if _crowd_profile_enabled:
		_crowd_profile_counters[CrowdProfileCounter.MOVEMENT_USEC] += Time.get_ticks_usec() - profile_started_usec
	_crowd_phase = (_crowd_phase + 1) % DIRECT_COLLISION_UPDATE_PHASES
	flush_deferred()


func _update_crowd_avatar_motion_state() -> void:
	if not is_instance_valid(_crowd_avatar) or _crowd_topology == null:
		_crowd_avatar_position_valid = false
		_crowd_avatar_stationary_this_tick = true
		return
	var current_position := _crowd_avatar.global_position
	if not _crowd_avatar_position_valid:
		_crowd_avatar_previous_position = current_position
		_crowd_avatar_position_valid = true
		_crowd_avatar_stationary_this_tick = true
		return
	_crowd_avatar_stationary_this_tick = (
		_crowd_topology.distance_squared(_crowd_avatar_previous_position, current_position)
		<= DIRECT_COLLISION_EPSILON * DIRECT_COLLISION_EPSILON
	)
	_crowd_avatar_previous_position = current_position


func _update_bulk_flow_state(delta: float) -> void:
	for slot_value in _active_slots:
		var slot := int(slot_value)
		var target_blend := 1.0 if _bulk_active[slot] != 0 else 0.0
		var blend_seconds := BULK_BLEND_IN_SECONDS if target_blend > _bulk_blends[slot] else BULK_BLEND_OUT_SECONDS
		_bulk_blends[slot] = move_toward(
			float(_bulk_blends[slot]),
			target_blend,
			delta / maxf(blend_seconds, 0.001)
		)
		if _bulk_active[slot] == 0 and _bulk_blends[slot] <= BULK_BLEND_EPSILON:
			_bulk_blends[slot] = 0.0
			_bulk_side_signs[slot] = 0
			_bulk_lease_epochs[slot] = 0
	_bulk_snapshot_seconds += delta
	if _bulk_refresh_in_progress:
		_continue_bulk_component_refresh()
		return
	if _bulk_snapshot_seconds + 0.000001 < BULK_SNAPSHOT_SECONDS:
		return
	_bulk_snapshot_seconds = fmod(_bulk_snapshot_seconds, BULK_SNAPSHOT_SECONDS)
	_start_bulk_component_refresh()
	_continue_bulk_component_refresh()


func _start_bulk_component_refresh() -> void:
	_bulk_union_parents.fill(-1)
	_bulk_union_ranks.fill(0)
	_bulk_root_weights.fill(0)
	_bulk_root_queued_weights.fill(0)
	_bulk_root_min_handles.fill(EntityHandle.INVALID)
	_bulk_root_candidate_snapshots.fill(0)
	_bulk_root_release_snapshots.fill(0)
	_bulk_root_side_signs.fill(0)
	_bulk_root_lease_epochs.fill(0)
	_bulk_root_active.fill(0)
	_bulk_build_neighbor_counts.fill(0)
	_bulk_refresh_handles.clear()
	for slot_value in _active_slots:
		var slot := int(slot_value)
		var enemy := _typed_enemies[slot]
		var eligible := (
			_retiring[slot] == 0
			and _bulk_allowed[slot] != 0
			and _bulk_enemy_eligible(enemy)
		)
		_bulk_eligible[slot] = 1 if eligible else 0
		if eligible:
			_bulk_union_parents[slot] = slot
			_bulk_refresh_handles.append(EntityHandle.make(slot, _generations[slot]))
		else:
			_bulk_active[slot] = 0
			_bulk_candidate_snapshots[slot] = 0
			_bulk_release_snapshots[slot] = 0
	_bulk_refresh_cursor = 0
	_bulk_refresh_chunk_size = maxi(
		ceili(float(_bulk_refresh_handles.size()) / float(BULK_SNAPSHOT_BUILD_PHASES)),
		1
	)
	_bulk_refresh_in_progress = true


func _continue_bulk_component_refresh() -> void:
	if not _bulk_refresh_in_progress:
		return
	if _crowd_topology == null or _bulk_refresh_handles.is_empty():
		_finalize_bulk_component_refresh()
		return
	var end_index := mini(
		_bulk_refresh_cursor + _bulk_refresh_chunk_size,
		_bulk_refresh_handles.size()
	)
	for refresh_index in range(_bulk_refresh_cursor, end_index):
		var own_handle := int(_bulk_refresh_handles[refresh_index])
		var slot := EntityHandle.slot(own_handle)
		if not is_active(own_handle) or _bulk_eligible[slot] == 0:
			continue
		var enemy := _typed_enemies[slot]
		if enemy == null:
			continue
		var query_radius := (
			float(_direct_collision_radii[slot])
			+ _maximum_contact_radius
			+ BULK_PAIR_LOOKAHEAD
		)
		_crowd_candidates = _crowd_grid.query_circle_candidates_limited(
			enemy.global_position,
			query_radius,
			MAX_BULK_SNAPSHOT_CANDIDATES,
			_crowd_candidates
		)
		for candidate_value in _crowd_candidates:
			var candidate_handle := int(candidate_value)
			if candidate_handle == own_handle:
				continue
			var other_slot := EntityHandle.slot(candidate_handle)
			if (
				other_slot < 0
				or other_slot >= _bulk_eligible.size()
				or _retiring[other_slot] != 0
				or _generations[other_slot] != EntityHandle.generation(candidate_handle)
				or _direct_collision_active[other_slot] == 0
			):
				continue
			var other := _typed_enemies[other_slot]
			if other == null or other.definition == null or other.definition.is_boss:
				continue
			var other_is_bulk_eligible := _bulk_eligible[other_slot] != 0
			if other_is_bulk_eligible and candidate_handle < own_handle:
				continue
			var surface_gap := (
				_crowd_topology.distance(enemy.global_position, other.global_position)
				- float(_direct_collision_radii[slot])
				- float(_direct_collision_radii[other_slot])
			)
			if surface_gap <= BULK_PAIR_LOOKAHEAD:
				_insert_bulk_build_neighbor(slot, candidate_handle, surface_gap)
				if other_is_bulk_eligible:
					_insert_bulk_build_neighbor(other_slot, own_handle, surface_gap)
			if other_is_bulk_eligible and surface_gap <= BULK_CONTACT_MARGIN:
				_bulk_union(slot, other_slot)
	_bulk_refresh_cursor = end_index
	if _bulk_refresh_cursor >= _bulk_refresh_handles.size():
		_finalize_bulk_component_refresh()


func _finalize_bulk_component_refresh() -> void:
	_bulk_component_roots.fill(-1)
	var component_roots := PackedInt32Array()
	for handle_value in _bulk_refresh_handles:
		var handle := int(handle_value)
		if not is_active(handle):
			continue
		var slot := EntityHandle.slot(handle)
		if _bulk_eligible[slot] == 0:
			continue
		var root := _bulk_union_find(slot)
		_bulk_component_roots[slot] = root
		var weight := _bulk_enemy_weight(_typed_enemies[slot])
		if _bulk_root_weights[root] == 0:
			component_roots.append(root)
		_bulk_root_weights[root] += weight
		if _direct_collision_queued[slot] != 0:
			_bulk_root_queued_weights[root] += weight
		if _bulk_root_min_handles[root] == EntityHandle.INVALID or handle < int(_bulk_root_min_handles[root]):
			_bulk_root_min_handles[root] = handle
		_bulk_root_candidate_snapshots[root] = maxi(
			int(_bulk_root_candidate_snapshots[root]),
			int(_bulk_candidate_snapshots[slot])
		)
		_bulk_root_release_snapshots[root] = maxi(
			int(_bulk_root_release_snapshots[root]),
			int(_bulk_release_snapshots[slot])
		)
		if _bulk_active[slot] != 0:
			_bulk_root_active[root] = 1
		if _bulk_active[slot] != 0 or (_bulk_blends[slot] > BULK_BLEND_EPSILON and _bulk_lease_epochs[slot] > 0):
			var lease_epoch := int(_bulk_lease_epochs[slot])
			if _bulk_root_lease_epochs[root] == 0 or lease_epoch < int(_bulk_root_lease_epochs[root]):
				_bulk_root_lease_epochs[root] = lease_epoch
				_bulk_root_side_signs[root] = _bulk_side_signs[slot]
	for root_value in component_roots:
		var root := int(root_value)
		var weight := int(_bulk_root_weights[root])
		var queued_ratio := float(_bulk_root_queued_weights[root]) / float(weight) if weight > 0 else 0.0
		var lease_epoch := int(_bulk_root_lease_epochs[root])
		var active_component := _bulk_root_active[root] != 0
		var candidate_snapshots := 0
		var release_snapshots := 0
		if active_component:
			var below_exit := weight < BULK_EXIT_WEIGHT or queued_ratio < BULK_EXIT_QUEUED_RATIO
			release_snapshots = mini(int(_bulk_root_release_snapshots[root]) + 1, BULK_EXIT_SNAPSHOTS) if below_exit else 0
			if release_snapshots >= BULK_EXIT_SNAPSHOTS:
				active_component = false
		else:
			var qualifies := weight >= BULK_ENTER_WEIGHT and queued_ratio >= BULK_ENTER_QUEUED_RATIO
			candidate_snapshots = mini(int(_bulk_root_candidate_snapshots[root]) + 1, BULK_ENTER_SNAPSHOTS) if qualifies else 0
			if candidate_snapshots >= BULK_ENTER_SNAPSHOTS:
				active_component = true
				lease_epoch = _bulk_next_lease_epoch
				_bulk_next_lease_epoch += 1
				_bulk_root_lease_epochs[root] = lease_epoch
				_bulk_root_side_signs[root] = _bulk_choose_side(root)
		_bulk_root_candidate_snapshots[root] = candidate_snapshots
		_bulk_root_release_snapshots[root] = release_snapshots
		_bulk_root_lease_epochs[root] = lease_epoch
		_bulk_root_active[root] = 1 if active_component else 0
		if not active_component and lease_epoch <= 0:
			_bulk_root_side_signs[root] = 0
	for handle_value in _bulk_refresh_handles:
		var handle := int(handle_value)
		if not is_active(handle):
			continue
		var slot := EntityHandle.slot(handle)
		if _bulk_eligible[slot] == 0:
			continue
		var root := int(_bulk_component_roots[slot])
		_bulk_candidate_snapshots[slot] = _bulk_root_candidate_snapshots[root]
		_bulk_release_snapshots[slot] = _bulk_root_release_snapshots[root]
		_bulk_active[slot] = _bulk_root_active[root]
		_bulk_lease_epochs[slot] = _bulk_root_lease_epochs[root]
		_bulk_side_signs[slot] = _bulk_root_side_signs[root]
	var previous_counts := _bulk_neighbor_counts
	_bulk_neighbor_counts = _bulk_build_neighbor_counts
	_bulk_build_neighbor_counts = previous_counts
	var previous_handles := _bulk_neighbor_handles
	_bulk_neighbor_handles = _bulk_build_neighbor_handles
	_bulk_build_neighbor_handles = previous_handles
	var previous_distances := _bulk_neighbor_distances
	_bulk_neighbor_distances = _bulk_build_neighbor_distances
	_bulk_build_neighbor_distances = previous_distances
	var ordered_slots: Array[int] = []
	for handle_value in _bulk_refresh_handles:
		var handle := int(handle_value)
		if not is_active(handle):
			continue
		var slot := EntityHandle.slot(handle)
		if _bulk_eligible[slot] != 0:
			ordered_slots.append(slot)
	ordered_slots.sort_custom(Callable(self, "_bulk_slot_precedes"))
	_bulk_ordered_slots.clear()
	for slot in ordered_slots:
		_bulk_ordered_slots.append(slot)
	_bulk_refresh_in_progress = false
	_bulk_refresh_cursor = 0
	if _crowd_profile_enabled:
		_crowd_profile_counters[CrowdProfileCounter.BULK_SNAPSHOTS] += 1


func _insert_bulk_build_neighbor(slot: int, handle: int, surface_gap: float) -> void:
	var offset := slot * MAX_BULK_NEIGHBORS
	var count := mini(int(_bulk_build_neighbor_counts[slot]), MAX_BULK_NEIGHBORS)
	var insert_index := count
	for index in range(count):
		var existing_distance := float(_bulk_build_neighbor_distances[offset + index])
		var existing_handle := int(_bulk_build_neighbor_handles[offset + index])
		if surface_gap < existing_distance or (is_equal_approx(surface_gap, existing_distance) and handle < existing_handle):
			insert_index = index
			break
	if insert_index >= MAX_BULK_NEIGHBORS:
		return
	var final_count := mini(count + 1, MAX_BULK_NEIGHBORS)
	for index in range(final_count - 1, insert_index, -1):
		_bulk_build_neighbor_handles[offset + index] = _bulk_build_neighbor_handles[offset + index - 1]
		_bulk_build_neighbor_distances[offset + index] = _bulk_build_neighbor_distances[offset + index - 1]
	_bulk_build_neighbor_handles[offset + insert_index] = handle
	_bulk_build_neighbor_distances[offset + insert_index] = surface_gap
	_bulk_build_neighbor_counts[slot] = final_count


func _bulk_enemy_eligible(enemy: InfectionEnemy) -> bool:
	if enemy == null or enemy.definition == null or not enemy.can_be_relocated():
		return false
	if not enemy.definition.contact_enabled or enemy.definition.speed <= 0.0:
		return false
	return enemy.definition.id == SMALL_ENEMY_ID or enemy.definition.id == CLUSTER_ENEMY_ID


func _bulk_enemy_weight(enemy: InfectionEnemy) -> int:
	return 2 if enemy != null and enemy.definition != null and enemy.definition.id == CLUSTER_ENEMY_ID else 1


func _bulk_union(first_slot: int, second_slot: int) -> void:
	var first_root := _bulk_union_find(first_slot)
	var second_root := _bulk_union_find(second_slot)
	if first_root == second_root:
		return
	var first_rank := int(_bulk_union_ranks[first_root])
	var second_rank := int(_bulk_union_ranks[second_root])
	if first_rank < second_rank or (first_rank == second_rank and first_root > second_root):
		var swap_root := first_root
		first_root = second_root
		second_root = swap_root
	_bulk_union_parents[second_root] = first_root
	if first_rank == second_rank:
		_bulk_union_ranks[first_root] = mini(first_rank + 1, 255)


func _bulk_union_find(slot: int) -> int:
	var root := slot
	while _bulk_union_parents[root] != root:
		root = int(_bulk_union_parents[root])
	var cursor := slot
	while _bulk_union_parents[cursor] != cursor:
		var parent := int(_bulk_union_parents[cursor])
		_bulk_union_parents[cursor] = root
		cursor = parent
	return root


func _bulk_choose_side(root: int) -> int:
	var positive_pressure := 0.0
	var negative_pressure := 0.0
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _bulk_eligible[slot] == 0 or _bulk_component_roots[slot] != root:
			continue
		var enemy := _typed_enemies[slot]
		var toward_avatar := _crowd_topology.shortest_delta(
			enemy.global_position,
			_crowd_avatar.global_position
		)
		if toward_avatar.length_squared() <= DIRECT_COLLISION_EPSILON:
			continue
		var forward := toward_avatar.normalized()
		var tangent := forward.orthogonal()
		var sample_distance := float(_direct_collision_radii[slot]) + 48.0
		for sign_value in [1, -1]:
			var arc_direction := forward.rotated(BULK_ARC_RADIANS * float(sign_value))
			var sample_position := enemy.global_position + arc_direction * sample_distance
			var blocked := _crowd_bounded and not _crowd_topology.contains_position(
				sample_position,
				float(_direct_collision_radii[slot])
			)
			var side_pressure := 4.0 if blocked else 0.0
			_crowd_candidates = _crowd_grid.query_circle_candidates(
				sample_position,
				float(_direct_collision_radii[slot]) + _maximum_contact_radius + 12.0,
				_crowd_candidates
			)
			for candidate_value in _crowd_candidates:
				var candidate_handle := int(candidate_value)
				var other_slot := EntityHandle.slot(candidate_handle)
				if (
					other_slot < 0
					or other_slot >= _typed_enemies.size()
					or other_slot == slot
					or _retiring[other_slot] != 0
					or _generations[other_slot] != EntityHandle.generation(candidate_handle)
					or _direct_collision_active[other_slot] == 0
				):
					continue
				var other := _typed_enemies[other_slot]
				if other == null or other.definition == null or other.definition.is_boss:
					continue
				if _bulk_eligible[other_slot] != 0 and _bulk_union_find(other_slot) == root:
					continue
				var local_delta := _crowd_topology.shortest_delta(enemy.global_position, other.global_position)
				if local_delta.dot(forward) < -float(_direct_collision_radii[slot]):
					continue
				var lateral := local_delta.dot(tangent) * float(sign_value)
				if lateral > 0.0:
					side_pressure += 1.0 / maxf(lateral, 1.0)
			if sign_value > 0:
				positive_pressure += side_pressure
			else:
				negative_pressure += side_pressure
	if absf(positive_pressure - negative_pressure) <= DIRECT_COLLISION_EPSILON:
		return 1 if posmod(int(_bulk_root_min_handles[root]), 2) == 0 else -1
	return 1 if positive_pressure < negative_pressure else -1


func _bulk_desired_delta(
	slot: int,
	enemy: InfectionEnemy,
	movement_origin: Vector2,
	delta: float
) -> Vector2:
	if not is_instance_valid(_crowd_avatar) or _crowd_topology == null:
		return Vector2.ZERO
	var to_avatar := _crowd_topology.shortest_delta(movement_origin, _crowd_avatar.global_position)
	var distance := to_avatar.length()
	if distance <= DIRECT_COLLISION_EPSILON:
		_bulk_direct_directions[slot] = Vector2.ZERO
		return Vector2.ZERO
	var direct_direction := to_avatar / distance
	_bulk_direct_directions[slot] = direct_direction
	var blend := clampf(float(_bulk_blends[slot]), 0.0, 1.0)
	var side_sign := int(_bulk_side_signs[slot])
	if side_sign == 0:
		side_sign = 1 if posmod(int(_bulk_lease_epochs[slot]), 2) == 0 else -1
	var desired_direction := direct_direction.rotated(BULK_ARC_RADIANS * blend * float(side_sign))
	var step_length := maxf(
		enemy.definition.speed * enemy.speed_multiplier * enemy.status_speed_multiplier() * delta,
		0.0
	)
	var contact_radius := enemy.contact_body_radius() + TherapyAvatar.CONTACT_RADIUS
	var stop_radius := maxf(contact_radius - InfectionEnemy.DIRECT_CHASE_CONTACT_DEPTH, 0.0)
	var proposed_position := movement_origin + desired_direction * step_length
	var from_avatar := _crowd_topology.shortest_delta(
		_crowd_avatar.global_position,
		proposed_position
	)
	var proposed_distance := from_avatar.length()
	var clamped_distance := clampf(proposed_distance, stop_radius, distance)
	if proposed_distance > DIRECT_COLLISION_EPSILON and not is_equal_approx(proposed_distance, clamped_distance):
		proposed_position = _crowd_avatar.global_position + from_avatar * (clamped_distance / proposed_distance)
	var proposed := _crowd_topology.shortest_delta(movement_origin, proposed_position)
	# Numeric topology resolution may add a sub-pixel outward component. Clamp the
	# final endpoint back to the origin-distance circle so bulk flow never reads as
	# an enemy briefly fleeing from Doctor Milos.
	var final_distance := _crowd_topology.distance(movement_origin + proposed, _crowd_avatar.global_position)
	if final_distance > distance + DIRECT_COLLISION_EPSILON:
		var corrected_from_avatar := _crowd_topology.shortest_delta(
			_crowd_avatar.global_position,
			movement_origin + proposed
		)
		if corrected_from_avatar.length_squared() > DIRECT_COLLISION_EPSILON:
			proposed = (
				_crowd_avatar.global_position
				+ corrected_from_avatar.normalized() * distance
				- movement_origin
			)
	return proposed.limit_length(step_length)


func _resolve_bulk_movements() -> void:
	if _bulk_ordered_slots.is_empty():
		return
	var solve_started_usec := Time.get_ticks_usec() if _crowd_profile_enabled else 0
	var resolved_count := 0
	# The order is refreshed only with the 0.25-s topology snapshot. Front bodies
	# commit first, so the rear can inherit newly opened space in this same tick.
	for slot_value in _bulk_ordered_slots:
		var slot := int(slot_value)
		if slot < 0 or slot >= _bulk_pending.size() or _bulk_pending[slot] == 0:
			continue
		var enemy := _typed_enemies[slot]
		if enemy == null or not enemy.is_targetable():
			continue
		var handle := EntityHandle.make(slot, _generations[slot])
		var origin := _bulk_origins[slot]
		var resolved_delta := _bulk_project_cached_proposal(slot)
		_bulk_resolved[slot] = resolved_delta
		if resolved_delta.length_squared() + DIRECT_COLLISION_EPSILON < _bulk_proposals[slot].length_squared():
			_direct_collision_queued[slot] = 1
		enemy.apply_crowd_resolved_position(origin + resolved_delta)
		if not enemy.global_position.is_equal_approx(origin):
			_crowd_grid.move(handle, origin, enemy.global_position)
		resolved_count += 1
	if _crowd_profile_enabled and resolved_count > 0:
		_crowd_profile_counters[CrowdProfileCounter.BULK_ACTIVE_TICKS] += 1
		_crowd_profile_counters[CrowdProfileCounter.BULK_SOLVE_USEC] += Time.get_ticks_usec() - solve_started_usec


func _bulk_slot_precedes(first_slot: int, second_slot: int) -> bool:
	if not is_instance_valid(_crowd_avatar) or _crowd_topology == null:
		return first_slot < second_slot
	var first_enemy := _typed_enemies[first_slot]
	var second_enemy := _typed_enemies[second_slot]
	if first_enemy == null or second_enemy == null:
		return first_slot < second_slot
	var first_distance := _crowd_topology.distance_squared(
		first_enemy.global_position,
		_crowd_avatar.global_position
	)
	var second_distance := _crowd_topology.distance_squared(
		second_enemy.global_position,
		_crowd_avatar.global_position
	)
	if is_equal_approx(first_distance, second_distance):
		return first_slot < second_slot
	return first_distance < second_distance


func _bulk_project_cached_proposal(slot: int) -> Vector2:
	var origin := _bulk_origins[slot]
	var resolved_delta := _bulk_proposals[slot]
	var own_radius := float(_direct_collision_radii[slot])
	var neighbor_count := mini(int(_bulk_neighbor_counts[slot]), MAX_BULK_NEIGHBORS)
	var neighbor_offset := slot * MAX_BULK_NEIGHBORS
	if _crowd_profile_enabled:
		_crowd_profile_counters[CrowdProfileCounter.BULK_PROJECTION_CANDIDATES] += neighbor_count
	for _pass_index in range(BULK_PROJECTION_PASSES):
		for neighbor_index in range(neighbor_count):
			var other_handle := int(_bulk_neighbor_handles[neighbor_offset + neighbor_index])
			var other_slot := EntityHandle.slot(other_handle)
			if not _bulk_pair_is_current(other_handle, other_slot):
				continue
			resolved_delta = _bulk_clip_delta_against_circle(
				slot,
				origin,
				resolved_delta,
				other_slot,
				_typed_enemies[other_slot].global_position,
				own_radius + float(_direct_collision_radii[other_slot]) + DIRECT_COLLISION_SKIN
			)
		resolved_delta = _bulk_limit_resolved_delta(slot, resolved_delta)
	# Projection against a later neighbor can re-enter an earlier one. Waiting at
	# the already valid origin is the deterministic no-retreat fallback.
	for neighbor_index in range(neighbor_count):
		var other_handle := int(_bulk_neighbor_handles[neighbor_offset + neighbor_index])
		var other_slot := EntityHandle.slot(other_handle)
		if not _bulk_pair_is_current(other_handle, other_slot):
			continue
		var minimum_distance := (
			own_radius
			+ float(_direct_collision_radii[other_slot])
			+ DIRECT_COLLISION_SKIN
			- DIRECT_COLLISION_EPSILON
		)
		if _crowd_topology.distance_squared(
			origin + resolved_delta,
			_typed_enemies[other_slot].global_position
		) < minimum_distance * minimum_distance:
			return Vector2.ZERO
	return resolved_delta


func _bulk_pair_is_current(handle: int, slot: int) -> bool:
	if slot < 0 or slot >= _typed_enemies.size():
		return false
	if _retiring[slot] != 0 or _generations[slot] != EntityHandle.generation(handle):
		return false
	var enemy := _typed_enemies[slot]
	return (
		enemy != null
		and enemy.definition != null
		and not enemy.definition.is_boss
		and _direct_collision_active[slot] != 0
	)


func _bulk_limit_resolved_delta(slot: int, value: Vector2) -> Vector2:
	var enemy := _typed_enemies[slot]
	if enemy == null:
		return Vector2.ZERO
	var origin := _bulk_origins[slot]
	var resolved_delta := value.limit_length(_bulk_proposals[slot].length())
	if _crowd_bounded:
		var bounded_position := _crowd_topology.resolve_position(
			origin + resolved_delta,
			enemy.definition.radius
		)
		resolved_delta = bounded_position - origin
	var direct_direction := _bulk_direct_directions[slot]
	var forward := resolved_delta.dot(direct_direction)
	if forward < 0.0:
		resolved_delta -= direct_direction * forward
	resolved_delta = resolved_delta.limit_length(_bulk_proposals[slot].length())
	var origin_distance := _crowd_topology.distance(origin, _crowd_avatar.global_position)
	var resolved_distance := _crowd_topology.distance(origin + resolved_delta, _crowd_avatar.global_position)
	if resolved_distance > origin_distance + DIRECT_COLLISION_EPSILON:
		return Vector2.ZERO
	return resolved_delta


func _bulk_clip_delta_against_circle(
	slot: int,
	origin: Vector2,
	resolved_delta: Vector2,
	other_slot: int,
	other_position: Vector2,
	minimum_distance: float
) -> Vector2:
	var to_other := (
		other_position - origin
		if _crowd_bounded
		else _crowd_topology.shortest_delta(origin, other_position)
	)
	var end_to_other := to_other - resolved_delta
	var minimum_squared := minimum_distance * minimum_distance
	if end_to_other.length_squared() >= minimum_squared:
		return resolved_delta
	var distance_squared := to_other.length_squared()
	if distance_squared < minimum_squared:
		if end_to_other.length_squared() >= distance_squared - DIRECT_COLLISION_EPSILON:
			return resolved_delta
		var overlap_normal := (
			to_other.normalized()
			if distance_squared > DIRECT_COLLISION_EPSILON
			else _overlap_axis(slot, other_slot)
		)
		var overlap_inward := resolved_delta.dot(overlap_normal)
		return resolved_delta - overlap_normal * maxf(overlap_inward, 0.0)
	var motion_squared := resolved_delta.length_squared()
	if motion_squared <= DIRECT_COLLISION_EPSILON:
		return Vector2.ZERO
	var projection := to_other.dot(resolved_delta)
	var radius_term := distance_squared - minimum_squared
	var discriminant := projection * projection - motion_squared * radius_term
	if discriminant < 0.0:
		return resolved_delta
	var hit_fraction := clampf(
		(projection - sqrt(discriminant)) / motion_squared,
		0.0,
		1.0
	)
	var contact_delta := resolved_delta * maxf(hit_fraction - 0.001, 0.0)
	var contact_normal := (to_other - contact_delta).normalized()
	var remaining := resolved_delta - contact_delta
	var inward := remaining.dot(contact_normal)
	if inward > 0.0:
		remaining -= contact_normal * inward
	return contact_delta + remaining


func bulk_active_weight() -> int:
	var weight := 0
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _retiring[slot] == 0 and _bulk_active[slot] != 0:
			weight += _bulk_enemy_weight(_typed_enemies[slot])
	return weight


func bulk_active_component_count() -> int:
	var leases: Dictionary = {}
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _retiring[slot] == 0 and _bulk_active[slot] != 0:
			leases[int(_bulk_lease_epochs[slot])] = true
	return leases.size()


func bulk_member_state(handle: int) -> Dictionary:
	if not is_active(handle):
		return {}
	var slot := EntityHandle.slot(handle)
	return {
		"active": _bulk_active[slot] != 0,
		"blend": float(_bulk_blends[slot]),
		"side": int(_bulk_side_signs[slot]),
		"lease_epoch": int(_bulk_lease_epochs[slot]),
		"component_root": int(_bulk_component_roots[slot]),
	}


func set_bulk_flow_allowed(handle: int, allowed: bool) -> bool:
	if not is_active(handle):
		return false
	var slot := EntityHandle.slot(handle)
	if not allowed:
		_clear_bulk_slot(slot)
		return true
	_bulk_allowed[slot] = 1
	return true


func _clear_bulk_slot(slot: int) -> void:
	if slot < 0 or slot >= _bulk_active.size():
		return
	_bulk_eligible[slot] = 0
	_bulk_allowed[slot] = 0
	_bulk_pending[slot] = 0
	_bulk_active[slot] = 0
	_bulk_candidate_snapshots[slot] = 0
	_bulk_release_snapshots[slot] = 0
	_bulk_side_signs[slot] = 0
	_bulk_lease_epochs[slot] = 0
	_bulk_component_roots[slot] = -1
	_bulk_blends[slot] = 0.0
	_bulk_origins[slot] = Vector2.ZERO
	_bulk_proposals[slot] = Vector2.ZERO
	_bulk_resolved[slot] = Vector2.ZERO
	_bulk_direct_directions[slot] = Vector2.ZERO


func _queued_blocker_still_at_contact(slot: int, enemy: InfectionEnemy) -> bool:
	if not is_instance_valid(_crowd_avatar) or _crowd_topology == null:
		return false
	var blocker_handle := int(_direct_collision_queue_blockers[slot])
	var blocker := _active_collision_enemy(blocker_handle)
	if blocker == null:
		return false
	var toward_avatar := _crowd_topology.shortest_delta(enemy.global_position, _crowd_avatar.global_position)
	if toward_avatar.length_squared() <= DIRECT_COLLISION_EPSILON:
		return false
	var requested_direction := toward_avatar.normalized()
	if (
		_active_collision_enemy(int(_direct_collision_corridor_blockers[slot])) == null
		or not _direct_collision_cached_corridors_closed(slot, requested_direction)
	):
		return false
	var blocker_slot := EntityHandle.slot(blocker_handle)
	var to_blocker := (
		blocker.global_position - enemy.global_position
		if _crowd_bounded
		else _crowd_topology.shortest_delta(enemy.global_position, blocker.global_position)
	)
	var forward_distance := to_blocker.dot(requested_direction)
	if forward_distance <= 0.0:
		return false
	var minimum_distance := (
		float(_direct_collision_radii[slot])
		+ float(_direct_collision_radii[blocker_slot])
		+ DIRECT_COLLISION_SKIN
	)
	var perpendicular_squared := maxf(
		to_blocker.length_squared() - forward_distance * forward_distance,
		0.0
	)
	if perpendicular_squared >= minimum_distance * minimum_distance:
		return false
	var entry_distance := forward_distance - sqrt(
		minimum_distance * minimum_distance - perpendicular_squared
	)
	return entry_distance <= DIRECT_COLLISION_EPSILON


func _cached_closed_queue_still_blocked(slot: int, enemy: InfectionEnemy) -> bool:
	# This more expensive live-side validation runs only on the slot's distributed
	# refresh phase. The per-tick queue fast path checks only its one real contact
	# body and therefore remains O(1) for dense rear rows.
	# A new direct queue blocker cannot reuse the closed side corridors sampled
	# for an older body. Without this identity check a living stale corridor can
	# keep the scheduled refresh asleep forever while the front pack rearranges.
	if (
		int(_direct_collision_queue_blockers[slot])
		!= int(_direct_collision_corridor_blockers[slot])
	):
		return false
	if not _queued_blocker_still_at_contact(slot, enemy):
		return false
	var toward_avatar := _crowd_topology.shortest_delta(enemy.global_position, _crowd_avatar.global_position)
	if toward_avatar.length_squared() <= DIRECT_COLLISION_EPSILON:
		return false
	var requested_direction := toward_avatar.normalized()
	# The cached side blockers are validated at their current positions. A moved,
	# retired or freed side wakes this body; a physically unchanged closed pocket
	# can remain asleep without another full spatial query.
	return (
		not _direct_collision_cached_side_is_currently_open(
			slot,
			enemy.global_position,
			requested_direction,
			float(_direct_collision_radii[slot]),
			1
		)
		and not _direct_collision_cached_side_is_currently_open(
			slot,
			enemy.global_position,
			requested_direction,
			float(_direct_collision_radii[slot]),
			-1
		)
	)


func _resolve_deferred_enemy_contacts() -> void:
	if not is_instance_valid(_crowd_avatar) or _crowd_topology == null:
		for slot_value in _active_slots:
			var fallback_slot := int(slot_value)
			var fallback_enemy := _typed_enemies[fallback_slot]
			if fallback_enemy != null and _retiring[fallback_slot] == 0:
				fallback_enemy.resolve_deferred_contact()
		return
	var query_radius := TherapyAvatar.CONTACT_RADIUS + _maximum_contact_radius
	_deferred_contact_candidates = _crowd_grid.query_circle_candidates(
		_crowd_avatar.global_position,
		query_radius,
		_deferred_contact_candidates
	)
	for handle_value in _deferred_contact_candidates:
		var contact_enemy := _active_collision_enemy(int(handle_value))
		if contact_enemy != null:
			contact_enemy.resolve_deferred_contact()


func _rebuild_direct_collision_grid() -> void:
	_crowd_grid.clear()
	_direct_collision_active_count = 0
	if _crowd_topology == null:
		_direct_collision_grid_dirty = false
		return
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _retiring[slot] != 0:
			continue
		var enemy := _typed_enemies[slot]
		var collision_active := enemy != null and enemy.definition != null and enemy.is_targetable()
		_direct_collision_active[slot] = 1 if collision_active else 0
		if not collision_active:
			continue
		_crowd_grid.insert_unique(EntityHandle.make(slot, _generations[slot]), enemy.global_position)
		_direct_collision_active_count += 1
	_direct_collision_grid_dirty = false


func _prepare_direct_collision_guards() -> void:
	if _crowd_topology == null:
		return
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _retiring[slot] != 0:
			continue
		var enemy := _typed_enemies[slot]
		if _direct_collision_active[slot] == 0:
			continue
		# Bosses retain the shared collision registry for Doctor blocking, damage
		# contact and arena bounds, but never acquire an enemy-body queue or lane.
		if enemy != null and enemy.definition != null and enemy.definition.is_boss:
			_clear_direct_collision_bypass(slot)
			_crowd_motion_guard_counts[slot] = 0
			_direct_collision_mixed_guard_sets[slot] = 0
			_crowd_motion_guards[slot] = 1
			_direct_collision_queued[slot] = 0
			_direct_collision_queue_blockers[slot] = EntityHandle.INVALID
			continue
		# Active bulk members use the topology snapshot's bounded neighbor cache.
		# Keeping the legacy phase guards hot as well would duplicate the broad phase
		# without contributing to their movement result. Mark them stale so the first
		# ordinary chase tick after blend-out refreshes immediately.
		if _bulk_blends[slot] > BULK_BLEND_EPSILON and _bulk_enemy_eligible(enemy):
			_crowd_motion_guard_counts[slot] = 0
			_direct_collision_mixed_guard_sets[slot] = 0
			_crowd_motion_guards[slot] = 0
			continue
		var guard_limit := _direct_collision_guard_limit(
			slot,
			float(_direct_collision_radii[slot])
		)
		var must_reduce_guards := int(_crowd_motion_guard_counts[slot]) > guard_limit
		if (
			_crowd_motion_guards[slot] == 0
			or must_reduce_guards
			or posmod(slot, DIRECT_COLLISION_UPDATE_PHASES) == _crowd_phase
		):
			if (
				not must_reduce_guards
				and _crowd_motion_guards[slot] != 0
				and _direct_collision_queued[slot] != 0
				and _crowd_lane_signs[slot] == 0
				and _cached_closed_queue_still_blocked(slot, enemy)
			):
				continue
			_refresh_direct_collision_guards(slot, enemy)


func _refresh_direct_collision_guards(slot: int, enemy: InfectionEnemy) -> void:
	var own_contact_radius := float(_direct_collision_radii[slot])
	var query_radius := own_contact_radius + _maximum_contact_radius + DIRECT_COLLISION_GUARD_LOOKAHEAD
	_crowd_candidates = _crowd_grid.query_circle_candidates(
		enemy.global_position,
		query_radius,
		_crowd_candidates
	)
	_direct_collision_mixed_guard_sets[slot] = 1 if _direct_collision_candidates_use_mixed_radii(
		slot,
		enemy,
		own_contact_radius
	) else 0
	var guard_limit := _direct_collision_guard_limit(slot, own_contact_radius)
	if _crowd_profile_enabled:
		_crowd_profile_counters[CrowdProfileCounter.GUARD_QUERIES] += 1
		_crowd_profile_counters[CrowdProfileCounter.GUARD_CANDIDATES] += _crowd_candidates.size()
	var guard_offset := slot * MAX_CROWD_MOTION_GUARDS
	var guard_count := 0
	var requested_direction := Vector2.ZERO
	var own_target_distance := 0.0
	var maximum_front_distance_squared := 0.0
	if is_instance_valid(_crowd_avatar):
		var toward_avatar := _crowd_topology.shortest_delta(enemy.global_position, _crowd_avatar.global_position)
		if toward_avatar.length_squared() > DIRECT_COLLISION_EPSILON:
			own_target_distance = toward_avatar.length()
			requested_direction = toward_avatar / own_target_distance
			var maximum_front_distance := maxf(own_target_distance - FRONT_PRIORITY_EPSILON, 0.0)
			maximum_front_distance_squared = maximum_front_distance * maximum_front_distance
	var stored_blocker := int(_direct_collision_blocker_handles[slot])
	var corridor_blocker := (
		stored_blocker
		if _active_collision_enemy(stored_blocker) != null
		else EntityHandle.INVALID
	)
	var corridor_entry := INF
	for candidate_handle_value in _crowd_candidates:
		var candidate_handle := int(candidate_handle_value)
		var other_slot := EntityHandle.slot(candidate_handle)
		if (
			other_slot < 0
			or other_slot == slot
			or other_slot >= _typed_enemies.size()
			or _retiring[other_slot] != 0
			or _generations[other_slot] != EntityHandle.generation(candidate_handle)
		):
			continue
		var other := _typed_enemies[other_slot]
		if (
			other == null
			or _direct_collision_active[other_slot] == 0
			or other.definition == null
			or other.definition.is_boss
		):
			continue
		var center_delta := (
			other.global_position - enemy.global_position
			if _crowd_bounded
			else _crowd_topology.shortest_delta(enemy.global_position, other.global_position)
		)
		var surface_clearance := center_delta.length() - own_contact_radius - float(_direct_collision_radii[other_slot])
		if surface_clearance > DIRECT_COLLISION_GUARD_LOOKAHEAD:
			continue
		var guard_priority := _direct_collision_guard_priority(
			center_delta,
			surface_clearance,
			own_contact_radius,
			float(_direct_collision_radii[other_slot]),
			requested_direction
		)
		if corridor_blocker == EntityHandle.INVALID and not requested_direction.is_zero_approx():
			var forward_distance := center_delta.dot(requested_direction)
			if forward_distance > 0.0:
				var collision_distance := (
					own_contact_radius
					+ float(_direct_collision_radii[other_slot])
					+ DIRECT_COLLISION_SKIN
				)
				var perpendicular_squared := maxf(center_delta.length_squared() - forward_distance * forward_distance, 0.0)
				if perpendicular_squared < collision_distance * collision_distance:
					var candidate_entry := forward_distance - sqrt(collision_distance * collision_distance - perpendicular_squared)
					var other_target_distance_squared := _crowd_topology.distance_squared(
						other.global_position,
						_crowd_avatar.global_position
					)
					if (
						candidate_entry <= DIRECT_COLLISION_GUARD_LOOKAHEAD
						and other_target_distance_squared < maximum_front_distance_squared
						and (
							candidate_entry < corridor_entry
							or (is_equal_approx(candidate_entry, corridor_entry) and candidate_handle < corridor_blocker)
						)
					):
						corridor_entry = candidate_entry
						corridor_blocker = candidate_handle
		var destination_index := guard_count
		if guard_count < guard_limit:
			guard_count += 1
		else:
			var worst_index := 0
			for guard_index in range(1, guard_count):
				var worst_distance := float(_crowd_motion_guard_distances[guard_offset + worst_index])
				var candidate_distance := float(_crowd_motion_guard_distances[guard_offset + guard_index])
				var worst_handle := int(_crowd_motion_guard_neighbors[guard_offset + worst_index])
				var candidate_stored_handle := int(_crowd_motion_guard_neighbors[guard_offset + guard_index])
				if candidate_distance > worst_distance or (is_equal_approx(candidate_distance, worst_distance) and candidate_stored_handle > worst_handle):
					worst_index = guard_index
			var stored_worst_distance := float(_crowd_motion_guard_distances[guard_offset + worst_index])
			var stored_worst_handle := int(_crowd_motion_guard_neighbors[guard_offset + worst_index])
			if guard_priority > stored_worst_distance or (is_equal_approx(guard_priority, stored_worst_distance) and candidate_handle >= stored_worst_handle):
				continue
			destination_index = worst_index
		_crowd_motion_guard_neighbors[guard_offset + destination_index] = candidate_handle
		_crowd_motion_guard_distances[guard_offset + destination_index] = guard_priority
	# An active bypass leases its generation-safe blocker until release hysteresis
	# completes. Keep that exact body in the fresh guard set even if a dense cell
	# temporarily contributes three slightly nearer neighbors.
	if stored_blocker != EntityHandle.INVALID:
		var stored_present := false
		for guard_index in range(guard_count):
			if int(_crowd_motion_guard_neighbors[guard_offset + guard_index]) == stored_blocker:
				stored_present = true
				break
		if not stored_present:
			var stored_enemy := _active_collision_enemy(stored_blocker)
			if stored_enemy != null:
				var stored_slot := EntityHandle.slot(stored_blocker)
				var stored_delta := (
					stored_enemy.global_position - enemy.global_position
					if _crowd_bounded
					else _crowd_topology.shortest_delta(enemy.global_position, stored_enemy.global_position)
				)
				var stored_clearance := stored_delta.length() - own_contact_radius - float(_direct_collision_radii[stored_slot])
				if stored_clearance <= DIRECT_COLLISION_GUARD_LOOKAHEAD:
					var stored_index := guard_count
					if guard_count < guard_limit:
						guard_count += 1
					else:
						stored_index = 0
						for guard_index in range(1, guard_count):
							if float(_crowd_motion_guard_distances[guard_offset + guard_index]) > float(_crowd_motion_guard_distances[guard_offset + stored_index]):
								stored_index = guard_index
					_crowd_motion_guard_neighbors[guard_offset + stored_index] = stored_blocker
					_crowd_motion_guard_distances[guard_offset + stored_index] = stored_clearance
	# The complete phased query may identify a real front trigger which is not
	# among the three nearest surfaces in a dense edge cell. Keep that exact
	# trigger in the hot-path guards, otherwise a verified open corridor could
	# never turn into a lease and the follower would wait for another phase.
	if corridor_blocker != EntityHandle.INVALID and corridor_blocker != stored_blocker:
		var corridor_present := false
		for guard_index in range(guard_count):
			if int(_crowd_motion_guard_neighbors[guard_offset + guard_index]) == corridor_blocker:
				corridor_present = true
				break
		if not corridor_present:
			var corridor_enemy := _active_collision_enemy(corridor_blocker)
			if corridor_enemy != null:
				var corridor_slot := EntityHandle.slot(corridor_blocker)
				var corridor_delta := (
					corridor_enemy.global_position - enemy.global_position
					if _crowd_bounded
					else _crowd_topology.shortest_delta(enemy.global_position, corridor_enemy.global_position)
				)
				var corridor_clearance := (
					corridor_delta.length()
					- own_contact_radius
					- float(_direct_collision_radii[corridor_slot])
				)
				var corridor_index := guard_count
				if guard_count < guard_limit:
					guard_count += 1
				else:
					corridor_index = -1
					for guard_index in range(guard_count):
						var guard_handle := int(_crowd_motion_guard_neighbors[guard_offset + guard_index])
						if guard_handle == stored_blocker:
							continue
						if (
							corridor_index < 0
							or float(_crowd_motion_guard_distances[guard_offset + guard_index])
								> float(_crowd_motion_guard_distances[guard_offset + corridor_index])
						):
							corridor_index = guard_index
				if corridor_index >= 0:
					_crowd_motion_guard_neighbors[guard_offset + corridor_index] = corridor_blocker
					_crowd_motion_guard_distances[guard_offset + corridor_index] = corridor_clearance
	_refresh_direct_collision_corridor_cache(
		slot,
		enemy,
		own_contact_radius,
		corridor_blocker,
		requested_direction
	)
	_crowd_motion_guard_counts[slot] = guard_count
	_crowd_motion_guards[slot] = 1


func _refresh_direct_collision_corridor_cache(
	slot: int,
	enemy: InfectionEnemy,
	own_contact_radius: float,
	selected_blocker: int,
	requested_direction: Vector2
) -> void:
	_invalidate_direct_collision_corridor(slot)
	if not is_instance_valid(_crowd_avatar) or requested_direction.is_zero_approx():
		return
	if selected_blocker == EntityHandle.INVALID:
		return
	if _crowd_profile_enabled:
		_crowd_profile_counters[CrowdProfileCounter.CORRIDOR_EVALUATIONS] += 1
	var tangent := requested_direction.orthogonal()
	var positive_direction := (
		requested_direction * DIRECT_COLLISION_BYPASS_FORWARD_WEIGHT
		+ tangent * DIRECT_COLLISION_BYPASS_LATERAL_WEIGHT
	).normalized()
	var negative_direction := (
		requested_direction * DIRECT_COLLISION_BYPASS_FORWARD_WEIGHT
		- tangent * DIRECT_COLLISION_BYPASS_LATERAL_WEIGHT
	).normalized()
	var corridor_length := minf(
		own_contact_radius * DIRECT_COLLISION_CORRIDOR_RADII,
		DIRECT_COLLISION_GUARD_LOOKAHEAD
	)
	var positive_delta := positive_direction * corridor_length
	var negative_delta := negative_direction * corridor_length
	var positive_clearance := INF
	var negative_clearance := INF
	var positive_side_blocker := EntityHandle.INVALID
	var negative_side_blocker := EntityHandle.INVALID
	var positive_open := not _crowd_bounded or _crowd_topology.contains_position(
		enemy.global_position + positive_delta,
		own_contact_radius
	)
	var negative_open := not _crowd_bounded or _crowd_topology.contains_position(
		enemy.global_position + negative_delta,
		own_contact_radius
	)
	for candidate_handle_value in _crowd_candidates:
		var candidate_handle := int(candidate_handle_value)
		if candidate_handle == selected_blocker:
			continue
		var other_slot := EntityHandle.slot(candidate_handle)
		if (
			other_slot < 0
			or other_slot == slot
			or other_slot >= _typed_enemies.size()
			or _retiring[other_slot] != 0
			or _generations[other_slot] != EntityHandle.generation(candidate_handle)
		):
			continue
		var other := _typed_enemies[other_slot]
		if (
			other == null
			or _direct_collision_active[other_slot] == 0
			or other.definition == null
			or other.definition.is_boss
		):
			continue
		var to_other := (
			other.global_position - enemy.global_position
			if _crowd_bounded
			else _crowd_topology.shortest_delta(enemy.global_position, other.global_position)
		)
		var minimum_distance := own_contact_radius + float(_direct_collision_radii[other_slot])
		var minimum_squared := minimum_distance * minimum_distance
		var positive_fraction := clampf(to_other.dot(positive_delta) / (corridor_length * corridor_length), 0.0, 1.0)
		var negative_fraction := clampf(to_other.dot(negative_delta) / (corridor_length * corridor_length), 0.0, 1.0)
		var positive_squared := (to_other - positive_delta * positive_fraction).length_squared() - minimum_squared
		var negative_squared := (to_other - negative_delta * negative_fraction).length_squared() - minimum_squared
		if (
			positive_squared < positive_clearance
			or (is_equal_approx(positive_squared, positive_clearance) and candidate_handle < positive_side_blocker)
		):
			positive_clearance = positive_squared
			positive_side_blocker = candidate_handle
		if (
			negative_squared < negative_clearance
			or (is_equal_approx(negative_squared, negative_clearance) and candidate_handle < negative_side_blocker)
		):
			negative_clearance = negative_squared
			negative_side_blocker = candidate_handle
		if positive_squared < -DIRECT_COLLISION_EPSILON:
			positive_open = false
		if negative_squared < -DIRECT_COLLISION_EPSILON:
			negative_open = false
	var corridor_offset := slot * 2
	_direct_collision_corridor_blockers[slot] = selected_blocker
	_direct_collision_corridor_directions[slot] = requested_direction
	_direct_collision_corridor_clearances[corridor_offset] = positive_clearance
	_direct_collision_corridor_clearances[corridor_offset + 1] = negative_clearance
	_direct_collision_corridor_open[corridor_offset] = 1 if positive_open else 0
	_direct_collision_corridor_open[corridor_offset + 1] = 1 if negative_open else 0
	_direct_collision_corridor_side_blockers[corridor_offset] = positive_side_blocker
	_direct_collision_corridor_side_blockers[corridor_offset + 1] = negative_side_blocker
	_direct_collision_corridor_epochs[slot] = _direct_collision_prepare_epoch


func _direct_collision_guard_limit(slot: int, _contact_radius: float) -> int:
	# A standing mixed pack may touch up to eight differently sized bodies along
	# its stable outer boundary. Homogeneous packs retain the established bounded
	# set, while the moving-Doctor path stays at three and refreshes immediately.
	if not _crowd_avatar_stationary_this_tick:
		return 3
	if _direct_collision_mixed_guard_sets[slot] != 0:
		return 8
	return 5 if _crowd_lane_signs[slot] != 0 else 3


func _direct_collision_candidates_use_mixed_radii(
	slot: int,
	enemy: InfectionEnemy,
	own_contact_radius: float
) -> bool:
	if not _crowd_avatar_stationary_this_tick:
		return false
	for candidate_handle_value in _crowd_candidates:
		var candidate_handle := int(candidate_handle_value)
		var other_slot := EntityHandle.slot(candidate_handle)
		if (
			other_slot < 0
			or other_slot == slot
			or other_slot >= _typed_enemies.size()
			or _retiring[other_slot] != 0
			or _generations[other_slot] != EntityHandle.generation(candidate_handle)
		):
			continue
		var other := _typed_enemies[other_slot]
		if (
			other == null
			or _direct_collision_active[other_slot] == 0
			or other.definition == null
			or other.definition.is_boss
		):
			continue
		var other_contact_radius := float(_direct_collision_radii[other_slot])
		if is_equal_approx(other_contact_radius, own_contact_radius):
			continue
		var center_delta := (
			other.global_position - enemy.global_position
			if _crowd_bounded
			else _crowd_topology.shortest_delta(enemy.global_position, other.global_position)
		)
		if center_delta.length() - own_contact_radius - other_contact_radius <= DIRECT_COLLISION_GUARD_LOOKAHEAD:
			return true
	return false


func _direct_collision_guard_priority(
	center_delta: Vector2,
	surface_clearance: float,
	own_contact_radius: float,
	other_contact_radius: float,
	requested_direction: Vector2
) -> float:
	if not _crowd_avatar_stationary_this_tick or requested_direction.is_zero_approx():
		return surface_clearance
	var forward_distance := center_delta.dot(requested_direction)
	if forward_distance > 0.0:
		var collision_distance := own_contact_radius + other_contact_radius + DIRECT_COLLISION_SKIN
		var perpendicular_squared := maxf(
			center_delta.length_squared() - forward_distance * forward_distance,
			0.0
		)
		if perpendicular_squared < collision_distance * collision_distance:
			var entry_distance := forward_distance - sqrt(
				collision_distance * collision_distance - perpendicular_squared
			)
			if entry_distance <= DIRECT_COLLISION_GUARD_LOOKAHEAD:
				return maxf(entry_distance, 0.0)
	return DIRECT_COLLISION_GUARD_LOOKAHEAD + maxf(surface_clearance, 0.0)


## Clips one proposed fixed-tick displacement against nearby enemy contact
## circles. A free path stays direct. A leased, freshly verified side corridor
## may slide around its one front body; every unleased or additionally blocked
## contact waits instead of inventing a lateral direction. No pass may create a
## component opposite to the original movement direction.
func _resolve_direct_collision(slot: int, enemy: InfectionEnemy, movement_origin: Vector2) -> void:
	if _crowd_topology == null or enemy == null or enemy.definition == null:
		return
	if enemy.definition.is_boss:
		return
	var requested_delta := (
		enemy.global_position - movement_origin
		if _crowd_bounded
		else _crowd_topology.shortest_delta(movement_origin, enemy.global_position)
	)
	var requested_length_squared := requested_delta.length_squared()
	if requested_length_squared <= DIRECT_COLLISION_EPSILON * DIRECT_COLLISION_EPSILON:
		return
	_direct_collision_queued[slot] = 0
	_direct_collision_queue_blockers[slot] = EntityHandle.INVALID
	var own_contact_radius := float(_direct_collision_radii[slot])
	var requested_length := sqrt(requested_length_squared)
	var requested_direction := requested_delta / requested_length
	var resolved_delta := requested_delta
	var neighbor_count := mini(
		int(_crowd_motion_guard_counts[slot]),
		_direct_collision_guard_limit(slot, own_contact_radius)
	)
	var neighbor_offset := slot * MAX_CROWD_MOTION_GUARDS
	# Direct pursuit remains untouched until one genuine body blocks the proposed
	# sweep. That blocker leases one stable side while the enemy circles it; a
	# short clear-corridor hysteresis prevents frame-to-frame side switching.
	var bypass_delta := Vector2.ZERO
	if not enemy.is_stunned():
		bypass_delta = _direct_collision_obstacle_bypass(
			slot,
			movement_origin,
			requested_direction,
			requested_length,
			own_contact_radius,
			neighbor_offset,
			neighbor_count
		)
		if _crowd_avatar_stationary_this_tick and _crowd_lane_signs[slot] != 0:
			var boundary_delta := _direct_collision_boundary_follow_delta(
				slot,
				movement_origin,
				requested_direction,
				requested_length,
				own_contact_radius
			)
			if boundary_delta.length_squared() > DIRECT_COLLISION_EPSILON:
				bypass_delta = boundary_delta
	# Without a verified bypass the move remains perfectly radial. Clip that one
	# segment at the first real contact body instead of letting an old closed
	# corridor cache cancel the whole tick before contact.
	if bypass_delta.length_squared() <= DIRECT_COLLISION_EPSILON:
		var direct_delta := _direct_collision_clipped_direct_delta(
			slot,
			movement_origin,
			requested_direction,
			requested_length,
			own_contact_radius,
			neighbor_offset,
			neighbor_count
		)
		var direct_was_clipped := direct_delta.length_squared() + DIRECT_COLLISION_EPSILON < requested_length_squared
		_direct_collision_queued[slot] = 1 if direct_was_clipped else 0
		if direct_was_clipped and direct_delta.length_squared() <= DIRECT_COLLISION_EPSILON:
			if _crowd_profile_enabled:
				_crowd_profile_counters[CrowdProfileCounter.QUEUED_NO_CORRIDOR] += 1
		if not requested_delta.is_equal_approx(direct_delta):
			enemy.apply_crowd_resolved_position(movement_origin + direct_delta)
		return
	var motion_was_redirected := bypass_delta.length_squared() > DIRECT_COLLISION_EPSILON
	var route_became_blocked := false
	var leased_sign := int(_crowd_lane_signs[slot])
	var leased_side := requested_direction.orthogonal() * float(leased_sign)
	if bypass_delta.length_squared() > DIRECT_COLLISION_EPSILON:
		resolved_delta = bypass_delta
	for _pass_index in range(DIRECT_COLLISION_PASSES):
		var changed := false
		for neighbor_index in range(neighbor_count):
			var candidate_handle := int(_crowd_motion_guard_neighbors[neighbor_offset + neighbor_index])
			var other_slot := EntityHandle.slot(candidate_handle)
			if (
				other_slot < 0
				or other_slot == slot
				or other_slot >= _typed_enemies.size()
				or _retiring[other_slot] != 0
				or _generations[other_slot] != EntityHandle.generation(candidate_handle)
			):
				continue
			var other := _typed_enemies[other_slot]
			if (
				other == null
				or _direct_collision_active[other_slot] == 0
				or other.definition == null
				or other.definition.is_boss
			):
				continue
			var to_other := (
				other.global_position - movement_origin
				if _crowd_bounded
				else _crowd_topology.shortest_delta(movement_origin, other.global_position)
			)
			var minimum_distance := own_contact_radius + float(_direct_collision_radii[other_slot])
			var end_to_other := to_other - resolved_delta
			var minimum_squared := minimum_distance * minimum_distance
			if end_to_other.length_squared() >= minimum_squared:
				continue
			var distance_squared := to_other.length_squared()
			var contact_normal := Vector2.ZERO
			var allowed_inward := 0.0
			if distance_squared <= DIRECT_COLLISION_EPSILON:
				contact_normal = _overlap_axis(slot, other_slot)
			else:
				var distance := sqrt(distance_squared)
				contact_normal = to_other / distance
				allowed_inward = maxf(distance - minimum_distance - DIRECT_COLLISION_SKIN, 0.0)
			var inward_component := resolved_delta.dot(contact_normal)
			if inward_component <= allowed_inward:
				continue
			resolved_delta -= contact_normal * (inward_component - allowed_inward)
			var retreat_component := resolved_delta.dot(requested_direction)
			if retreat_component < 0.0:
				resolved_delta -= requested_direction * retreat_component
			var leased_side_component := resolved_delta.dot(leased_side)
			if leased_sign != 0 and leased_side_component < 0.0:
				resolved_delta -= leased_side * leased_side_component
			changed = true
			motion_was_redirected = true
		if not changed:
			break
	# A verified open side may touch more than one body along the same outer
	# surface. Two bounded projections let it glide along that surface without
	# changing its leased side. The final all-guard validation is authoritative:
	# if the arc would enter any contact circle, this tick waits at its valid
	# origin instead of pushing, repairing or choosing the opposite side.
	for neighbor_index in range(neighbor_count):
		var candidate_handle := int(_crowd_motion_guard_neighbors[neighbor_offset + neighbor_index])
		var other_slot := EntityHandle.slot(candidate_handle)
		if (
			other_slot < 0
			or other_slot == slot
			or other_slot >= _typed_enemies.size()
			or _retiring[other_slot] != 0
			or _generations[other_slot] != EntityHandle.generation(candidate_handle)
		):
			continue
		var other := _typed_enemies[other_slot]
		if (
			other == null
			or _direct_collision_active[other_slot] == 0
			or other.definition == null
			or other.definition.is_boss
		):
			continue
		var final_to_other := (
			other.global_position - (movement_origin + resolved_delta)
			if _crowd_bounded
			else _crowd_topology.shortest_delta(movement_origin + resolved_delta, other.global_position)
		)
		var minimum_distance := (
			own_contact_radius
			+ float(_direct_collision_radii[other_slot])
			+ DIRECT_COLLISION_SKIN
		)
		var validation_distance := minimum_distance - DIRECT_COLLISION_EPSILON
		if final_to_other.length_squared() < validation_distance * validation_distance:
			resolved_delta = Vector2.ZERO
			route_became_blocked = true
			break
	if route_became_blocked:
		_direct_collision_queued[slot] = 1
	var resolved_position := movement_origin + resolved_delta
	if motion_was_redirected and is_instance_valid(_crowd_avatar) and not enemy.is_stunned():
		var origin_to_avatar := (
			_crowd_avatar.global_position - movement_origin
			if _crowd_bounded
			else _crowd_topology.shortest_delta(movement_origin, _crowd_avatar.global_position)
		)
		var resolved_to_avatar := (
			_crowd_avatar.global_position - resolved_position
			if _crowd_bounded
			else _crowd_topology.shortest_delta(resolved_position, _crowd_avatar.global_position)
		)
		if resolved_to_avatar.length_squared() > origin_to_avatar.length_squared() + DIRECT_COLLISION_EPSILON:
			resolved_delta = Vector2.ZERO
			resolved_position = movement_origin
			_direct_collision_queued[slot] = 1
	if _direct_collision_queued[slot] != 0 and resolved_delta.length_squared() <= DIRECT_COLLISION_EPSILON:
		if _crowd_profile_enabled:
			_crowd_profile_counters[CrowdProfileCounter.QUEUED_NO_CORRIDOR] += 1
	if not requested_delta.is_equal_approx(resolved_delta):
		enemy.apply_crowd_resolved_position(resolved_position)


func _direct_collision_clipped_direct_delta(
	slot: int,
	movement_origin: Vector2,
	requested_direction: Vector2,
	requested_length: float,
	own_contact_radius: float,
	neighbor_offset: int,
	neighbor_count: int
) -> Vector2:
	var allowed_length := requested_length
	var allowed_blocker := EntityHandle.INVALID
	for neighbor_index in range(neighbor_count):
		var candidate_handle := int(_crowd_motion_guard_neighbors[neighbor_offset + neighbor_index])
		var other_slot := EntityHandle.slot(candidate_handle)
		if (
			other_slot < 0
			or other_slot == slot
			or other_slot >= _typed_enemies.size()
			or _retiring[other_slot] != 0
			or _generations[other_slot] != EntityHandle.generation(candidate_handle)
		):
			continue
		var other := _typed_enemies[other_slot]
		if (
			other == null
			or _direct_collision_active[other_slot] == 0
			or other.definition == null
			or other.definition.is_boss
		):
			continue
		var to_other := (
			other.global_position - movement_origin
			if _crowd_bounded
			else _crowd_topology.shortest_delta(movement_origin, other.global_position)
		)
		var forward_distance := to_other.dot(requested_direction)
		if forward_distance <= 0.0:
			continue
		var minimum_distance := (
			own_contact_radius
			+ float(_direct_collision_radii[other_slot])
			+ DIRECT_COLLISION_SKIN
		)
		var perpendicular_squared := maxf(
			to_other.length_squared() - forward_distance * forward_distance,
			0.0
		)
		var minimum_squared := minimum_distance * minimum_distance
		if perpendicular_squared >= minimum_squared:
			continue
		var entry_distance := forward_distance - sqrt(minimum_squared - perpendicular_squared)
		if (
			entry_distance < allowed_length - DIRECT_COLLISION_EPSILON
			or (
				is_equal_approx(entry_distance, allowed_length)
				and (allowed_blocker == EntityHandle.INVALID or candidate_handle < allowed_blocker)
			)
		):
			allowed_length = minf(allowed_length, maxf(entry_distance, 0.0))
			allowed_blocker = candidate_handle
	if allowed_length + DIRECT_COLLISION_EPSILON < requested_length:
		_direct_collision_queue_blockers[slot] = allowed_blocker
	return requested_direction * allowed_length


func _direct_collision_boundary_follow_delta(
	slot: int,
	movement_origin: Vector2,
	requested_direction: Vector2,
	requested_length: float,
	own_contact_radius: float
) -> Vector2:
	var sign_value := int(_crowd_lane_signs[slot])
	if sign_value == 0 or requested_length <= DIRECT_COLLISION_EPSILON:
		return Vector2.ZERO
	var blocker_handle := int(_direct_collision_blocker_handles[slot])
	var blocker := _active_collision_enemy(blocker_handle)
	if blocker == null:
		return Vector2.ZERO
	var blocker_slot := EntityHandle.slot(blocker_handle)
	var blocker_to_origin := (
		movement_origin - blocker.global_position
		if _crowd_bounded
		else _crowd_topology.shortest_delta(blocker.global_position, movement_origin)
	)
	var boundary_radius := blocker_to_origin.length()
	var minimum_radius := (
		own_contact_radius
		+ float(_direct_collision_radii[blocker_slot])
		+ DIRECT_COLLISION_SKIN
	)
	if boundary_radius + DIRECT_COLLISION_EPSILON < minimum_radius:
		return Vector2.ZERO
	var leased_side := requested_direction.orthogonal() * float(sign_value)
	var angle := minf(requested_length / maxf(boundary_radius, minimum_radius), 0.25)
	var positive_delta := blocker_to_origin.rotated(angle) - blocker_to_origin
	var negative_delta := blocker_to_origin.rotated(-angle) - blocker_to_origin
	var boundary_delta := (
		positive_delta
		if positive_delta.dot(leased_side) >= negative_delta.dot(leased_side)
		else negative_delta
	)
	if boundary_delta.dot(requested_direction) < -DIRECT_COLLISION_EPSILON:
		return Vector2.ZERO
	var resolved_position := movement_origin + boundary_delta
	if _crowd_bounded and not _crowd_topology.contains_position(resolved_position, own_contact_radius):
		return Vector2.ZERO
	if is_instance_valid(_crowd_avatar):
		var origin_distance_squared := _crowd_topology.distance_squared(
			movement_origin,
			_crowd_avatar.global_position
		)
		var resolved_distance_squared := _crowd_topology.distance_squared(
			resolved_position,
			_crowd_avatar.global_position
		)
		if resolved_distance_squared > origin_distance_squared + DIRECT_COLLISION_EPSILON:
			return Vector2.ZERO
	return boundary_delta


func _direct_collision_obstacle_bypass(
	slot: int,
	movement_origin: Vector2,
	requested_direction: Vector2,
	requested_length: float,
	own_contact_radius: float,
	neighbor_offset: int,
	neighbor_count: int
) -> Vector2:
	if not is_instance_valid(_crowd_avatar):
		_clear_direct_collision_bypass(slot)
		return Vector2.ZERO
	var stored_handle := int(_direct_collision_blocker_handles[slot])
	if stored_handle != EntityHandle.INVALID and _active_collision_enemy(stored_handle) == null:
		_clear_direct_collision_bypass(slot)
		return Vector2.ZERO
	var selected_blocker := EntityHandle.INVALID
	var selected_entry := INF
	var stored_still_blocks := false
	var stored_blocks_direct_path := false
	var own_target_distance := _crowd_topology.distance(movement_origin, _crowd_avatar.global_position)
	var remaining_to_contact := maxf(
		own_target_distance
			- TherapyAvatar.CONTACT_RADIUS
			- own_contact_radius
			+ InfectionEnemy.DIRECT_CHASE_CONTACT_DEPTH,
		0.0
	)
	for neighbor_index in range(neighbor_count):
		var candidate_handle := int(_crowd_motion_guard_neighbors[neighbor_offset + neighbor_index])
		var other := _active_collision_enemy(candidate_handle)
		if other == null:
			continue
		var other_slot := EntityHandle.slot(candidate_handle)
		var to_other := (
			other.global_position - movement_origin
			if _crowd_bounded
			else _crowd_topology.shortest_delta(movement_origin, other.global_position)
		)
		var minimum_distance := own_contact_radius + float(_direct_collision_radii[other_slot])
		var forward_distance := to_other.dot(requested_direction)
		if forward_distance <= 0.0:
			continue
		var collision_distance := minimum_distance + DIRECT_COLLISION_SKIN
		var perpendicular_squared := maxf(to_other.length_squared() - forward_distance * forward_distance, 0.0)
		if perpendicular_squared >= collision_distance * collision_distance:
			continue
		var candidate_entry := forward_distance - sqrt(
			collision_distance * collision_distance - perpendicular_squared
		)
		if (
			_crowd_avatar_stationary_this_tick
			and candidate_handle == stored_handle
			and candidate_entry <= remaining_to_contact
		):
			stored_blocks_direct_path = true
		if (
			candidate_entry > requested_length + DIRECT_COLLISION_BYPASS_ACTIVATION_MARGIN
			or candidate_entry > remaining_to_contact
		):
			continue
		# Only a body which is genuinely ahead in the chase can initiate a bypass.
		# Side-by-side peers therefore never invent opposing lateral forces.
		var other_target_distance := _crowd_topology.distance(other.global_position, _crowd_avatar.global_position)
		if other_target_distance + FRONT_PRIORITY_EPSILON >= own_target_distance:
			continue
		if candidate_handle == stored_handle:
			stored_still_blocks = true
		if candidate_entry < selected_entry:
			selected_entry = candidate_entry
			selected_blocker = candidate_handle

	if stored_handle != EntityHandle.INVALID:
		if stored_still_blocks:
			_direct_collision_clear_ticks[slot] = 0
		else:
			var may_release := not stored_blocks_direct_path
			if may_release:
				_direct_collision_clear_ticks[slot] += 1
				if _direct_collision_clear_ticks[slot] >= DIRECT_COLLISION_BYPASS_CLEAR_TICKS:
					_clear_direct_collision_bypass(slot)
					return Vector2.ZERO
			else:
				_direct_collision_clear_ticks[slot] = 0

	if stored_handle == EntityHandle.INVALID:
		if selected_blocker == EntityHandle.INVALID:
			return Vector2.ZERO

	# The tangent is derived from the current Doctor vector every tick. Only the
	# selected side and generation-safe blocker handle persist, so a moving Doctor
	# cannot leave the enemy following a stale world-space lane.
	var tangent := requested_direction.orthogonal()
	var current_sign := int(_crowd_lane_signs[slot])
	var positive_direction := (
		requested_direction * DIRECT_COLLISION_BYPASS_FORWARD_WEIGHT
		+ tangent * DIRECT_COLLISION_BYPASS_LATERAL_WEIGHT
	).normalized()
	var negative_direction := (
		requested_direction * DIRECT_COLLISION_BYPASS_FORWARD_WEIGHT
		- tangent * DIRECT_COLLISION_BYPASS_LATERAL_WEIGHT
	).normalized()
	var blocker_for_corridor := stored_handle if stored_handle != EntityHandle.INVALID else selected_blocker
	if current_sign != 0 and _crowd_profile_enabled:
		_crowd_profile_counters[CrowdProfileCounter.ACTIVE_BYPASS_TICKS] += 1
	if current_sign != 0:
		if (
			int(_direct_collision_corridor_blockers[slot]) != blocker_for_corridor
			or not _direct_collision_cached_side_is_currently_open(
				slot,
				movement_origin,
				requested_direction,
				own_contact_radius,
				current_sign
			)
		):
			_clear_direct_collision_bypass(slot)
			return Vector2.ZERO
	if current_sign == 0:
		# A body may enter the activation envelope between its distributed guard
		# phases. It waits for that slot's next complete local corridor sample
		# instead of leasing a side from stale geometry.
		if not (
			_direct_collision_corridor_epochs[slot] == _direct_collision_prepare_epoch
			and int(_direct_collision_corridor_blockers[slot]) == blocker_for_corridor
		):
			return Vector2.ZERO
		var positive_clearance := _direct_collision_cached_corridor_clearance(
			slot,
			1,
			requested_direction,
			blocker_for_corridor
		)
		var negative_clearance := _direct_collision_cached_corridor_clearance(
			slot,
			-1,
			requested_direction,
			blocker_for_corridor
		)
		if positive_clearance < 0.0 and negative_clearance < 0.0:
			return Vector2.ZERO
		var previous_sign := int(_direct_collision_previous_lane_signs[slot])
		if previous_sign > 0 and positive_clearance >= 0.0:
			current_sign = 1
		elif previous_sign < 0 and negative_clearance >= 0.0:
			current_sign = -1
		else:
			current_sign = 1
			if positive_clearance < 0.0 or negative_clearance > positive_clearance + DIRECT_COLLISION_EPSILON:
				current_sign = -1
			elif absf(positive_clearance - negative_clearance) <= DIRECT_COLLISION_EPSILON and posmod(slot, 2) != 0:
				current_sign = -1
		_direct_collision_blocker_handles[slot] = selected_blocker
		_direct_collision_clear_ticks[slot] = 0
		if _crowd_profile_enabled and previous_sign != 0 and previous_sign != current_sign:
			_crowd_profile_counters[CrowdProfileCounter.SIDE_SWITCHES] += 1
		_direct_collision_previous_lane_signs[slot] = current_sign
		_crowd_lane_signs[slot] = current_sign
		if _crowd_profile_enabled:
			_crowd_profile_counters[CrowdProfileCounter.BYPASS_STARTS] += 1
	var selected_delta := (positive_direction if current_sign > 0 else negative_direction) * requested_length
	# The forward weight is deliberately non-zero; any later projection may stall
	# this tick but can never turn the bypass into retreat.
	if selected_delta.dot(requested_direction) <= 0.0:
		return Vector2.ZERO
	_crowd_lane_holds[slot] += 1
	_crowd_resolved_directions[slot] = requested_direction
	return selected_delta


func _direct_collision_cached_side_is_currently_open(
	slot: int,
	movement_origin: Vector2,
	requested_direction: Vector2,
	own_contact_radius: float,
	sign_value: int
) -> bool:
	var tangent := requested_direction.orthogonal()
	var side_direction := (
		requested_direction * DIRECT_COLLISION_BYPASS_FORWARD_WEIGHT
		+ tangent * DIRECT_COLLISION_BYPASS_LATERAL_WEIGHT * float(sign_value)
	).normalized()
	var corridor_length := minf(
		own_contact_radius * DIRECT_COLLISION_CORRIDOR_RADII,
		DIRECT_COLLISION_GUARD_LOOKAHEAD
	)
	var corridor_delta := side_direction * corridor_length
	if _crowd_bounded and not _crowd_topology.contains_position(
		movement_origin + corridor_delta,
		own_contact_radius
	):
		return false
	var corridor_index := slot * 2 + (0 if sign_value > 0 else 1)
	var side_blocker_handle := int(_direct_collision_corridor_side_blockers[corridor_index])
	var side_blocker := _active_collision_enemy(side_blocker_handle)
	if side_blocker == null:
		return true
	var side_blocker_slot := EntityHandle.slot(side_blocker_handle)
	var to_side_blocker := (
		side_blocker.global_position - movement_origin
		if _crowd_bounded
		else _crowd_topology.shortest_delta(movement_origin, side_blocker.global_position)
	)
	var minimum_distance := (
		own_contact_radius
		+ float(_direct_collision_radii[side_blocker_slot])
		+ DIRECT_COLLISION_SKIN
	)
	var fraction := clampf(
		to_side_blocker.dot(corridor_delta) / (corridor_length * corridor_length),
		0.0,
		1.0
	)
	return (
		(to_side_blocker - corridor_delta * fraction).length_squared()
		>= minimum_distance * minimum_distance
	)


func _clear_direct_collision_bypass(slot: int) -> void:
	if slot < 0 or slot >= _direct_collision_blocker_handles.size():
		return
	_direct_collision_blocker_handles[slot] = EntityHandle.INVALID
	_direct_collision_clear_ticks[slot] = 0
	_crowd_lane_signs[slot] = 0
	_crowd_lane_holds[slot] = 0
	_crowd_resolved_directions[slot] = Vector2.ZERO
	_invalidate_direct_collision_corridor(slot)


func _direct_collision_cached_corridor_clearance(
	slot: int,
	sign_value: int,
	requested_direction: Vector2,
	expected_blocker: int
) -> float:
	if (
		int(_direct_collision_corridor_blockers[slot]) != expected_blocker
		or _direct_collision_corridor_directions[slot].dot(requested_direction) < DIRECT_COLLISION_CORRIDOR_DIRECTION_DOT
	):
		return -INF
	var corridor_index := slot * 2 + (0 if sign_value > 0 else 1)
	if _direct_collision_corridor_open[corridor_index] == 0:
		return -INF
	return float(_direct_collision_corridor_clearances[corridor_index])


func _direct_collision_cached_corridors_closed(slot: int, requested_direction: Vector2) -> bool:
	if (
		_direct_collision_corridor_blockers[slot] == EntityHandle.INVALID
		or _direct_collision_corridor_directions[slot].dot(requested_direction) < DIRECT_COLLISION_CORRIDOR_DIRECTION_DOT
	):
		return false
	var corridor_offset := slot * 2
	return (
		_direct_collision_corridor_open[corridor_offset] == 0
		and _direct_collision_corridor_open[corridor_offset + 1] == 0
	)


func _invalidate_direct_collision_corridor(slot: int) -> void:
	if slot < 0 or slot >= _direct_collision_corridor_blockers.size():
		return
	var corridor_offset := slot * 2
	_direct_collision_corridor_blockers[slot] = EntityHandle.INVALID
	_direct_collision_corridor_directions[slot] = Vector2.ZERO
	_direct_collision_corridor_clearances[corridor_offset] = -INF
	_direct_collision_corridor_clearances[corridor_offset + 1] = -INF
	_direct_collision_corridor_open[corridor_offset] = 0
	_direct_collision_corridor_open[corridor_offset + 1] = 0
	_direct_collision_corridor_side_blockers[corridor_offset] = EntityHandle.INVALID
	_direct_collision_corridor_side_blockers[corridor_offset + 1] = EntityHandle.INVALID
	_direct_collision_corridor_epochs[slot] = -1


func _resolve_crowd_motion(slot: int, enemy: InfectionEnemy, movement_origin: Vector2) -> void:
	var resolved_delta := _crowd_topology.shortest_delta(movement_origin, enemy.global_position)
	if resolved_delta.length_squared() <= 0.000001:
		return
	var neighbor_count := int(_crowd_motion_guard_counts[slot])
	var neighbor_offset := slot * MAX_CROWD_MOTION_GUARDS
	for _pass_index in range(3):
		var changed := false
		for neighbor_index in range(neighbor_count):
			var other_handle := int(_crowd_motion_guard_neighbors[neighbor_offset + neighbor_index])
			var other_slot := EntityHandle.slot(other_handle)
			if other_slot < 0 or other_slot == slot or other_slot >= _typed_enemies.size() or _retiring[other_slot] != 0:
				continue
			var other := _typed_enemies[other_slot]
			if other == null or not other.is_targetable() or other.definition == null:
				continue
			var minimum_distance := enemy.crowd_radius() + other.crowd_radius() + CROWD_MOTION_CLEARANCE
			var to_other := _crowd_topology.shortest_delta(movement_origin, other.global_position)
			var start_distance_squared := to_other.length_squared()
			var end_to_other := to_other - resolved_delta
			var end_distance_squared := end_to_other.length_squared()
			if start_distance_squared < minimum_distance * minimum_distance:
				# Existing penetration is never repaired by moving either body. It may
				# resolve naturally, but this step may not make it deeper.
				if end_distance_squared >= start_distance_squared - 0.0001:
					continue
				var normal := to_other.normalized() if start_distance_squared > 0.000001 else _overlap_axis(slot, other_slot)
				var inward := resolved_delta.dot(normal)
				if inward > 0.0:
					resolved_delta -= normal * inward
					changed = true
				continue
			if end_distance_squared >= minimum_distance * minimum_distance:
				continue
			var motion_squared := resolved_delta.length_squared()
			if motion_squared <= 0.000001:
				continue
			var projection := to_other.dot(resolved_delta)
			var radius_term := start_distance_squared - minimum_distance * minimum_distance
			var discriminant := projection * projection - motion_squared * radius_term
			if discriminant < 0.0:
				continue
			var hit_fraction := clampf(
				(projection - sqrt(discriminant)) / motion_squared,
				0.0,
				1.0
			)
			var contact_delta := resolved_delta * maxf(hit_fraction - 0.001, 0.0)
			var contact_normal := (to_other - contact_delta).normalized()
			var remaining := resolved_delta - contact_delta
			var remaining_inward := remaining.dot(contact_normal)
			if remaining_inward > 0.0:
				remaining -= contact_normal * remaining_inward
			resolved_delta = contact_delta + remaining
			changed = true
		if not changed:
			break
	if not _crowd_topology.shortest_delta(movement_origin, enemy.global_position).is_equal_approx(resolved_delta):
		enemy.apply_crowd_resolved_position(movement_origin + resolved_delta)


func _prepare_crowd_steering(delta: float) -> void:
	if _crowd_topology == null or not is_instance_valid(_crowd_avatar) or _active_slots.is_empty():
		return
	_crowd_elapsed_seconds += delta
	_update_contact_ring_mode(delta)
	_refresh_contact_ring_claims()
	# Ring ownership is event-driven. Claims and queue ranks remain stable until a
	# body is added, released, stunned or the mode changes, so scanning all 600
	# bodies every tick only created timing spikes and visible retargeting.
	if _contact_ring_assignments_dirty:
		_prepare_contact_ring_assignments()
	if not _contact_ring_active:
		_crowd_grid.clear()
		for slot_value in _active_slots:
			var slot := int(slot_value)
			if _retiring[slot] != 0:
				continue
			var enemy := _typed_enemies[slot]
			if enemy == null or not enemy.is_targetable() or enemy.definition == null:
				continue
			_crowd_grid.insert_unique(EntityHandle.make(slot, _generations[slot]), enemy.global_position)

	var strongest_avatar_block := Vector2.ZERO
	var strongest_avatar_overlap := 0.0
	# Resolve a bounded local safe direction rather than applying displacement.
	# Each enemy refreshes at 10 Hz while locomotion remains at 60 Hz. The body
	# closer to the avatar owns the lane; only its follower curves around it. A
	# persistent circulation side and short release hysteresis prevent the
	# left/right replanning that otherwise reads as visible shaking.
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _retiring[slot] != 0:
			continue
		var enemy := _typed_enemies[slot]
		if enemy == null or not enemy.is_targetable() or enemy.definition == null:
			continue
		var avatar_delta := _crowd_topology.shortest_delta(enemy.global_position, _crowd_avatar.global_position)
		var avatar_distance_squared := avatar_delta.length_squared()
		var avatar_distance := sqrt(maxf(avatar_distance_squared, 0.000001))
		var contact_radius := _contact_radius(enemy)
		var ring_claimed := _contact_ring_active and _contact_ring_claim_starts[slot] >= 0
		if (
			_contact_ring_active
			and not ring_claimed
			and (not _contact_ring_saturated or _contact_ring_is_hard_body(enemy))
			and avatar_distance <= contact_radius + CONTACT_RING_RESERVATION_MARGIN
		):
			# A ring may activate before any enemy arrives. The first waiter that
			# crosses reservation range claims directly; rescanning all 600 bodies for
			# every later arrival caused periodic frame spikes. The first rejected
			# claim marks the geometry full until a release/new registration event.
			var entering_handle := EntityHandle.make(slot, _generations[slot])
			if _try_claim_contact_ring(entering_handle, enemy, avatar_delta):
				ring_claimed = true
			else:
				_contact_ring_saturated = true
		if (
			posmod(slot, CROWD_UPDATE_PHASES) != _crowd_phase
			and not ring_claimed
			and _crowd_contact_latched[slot] == 0
		):
			continue
		_crowd_motion_guards[slot] = 0
		_crowd_motion_guard_counts[slot] = 0
		var avatar_chase_direction := avatar_delta.normalized() if avatar_distance_squared > 0.000001 else Vector2.RIGHT
		var chase_direction := avatar_chase_direction
		var lateral_axis := chase_direction.orthogonal()
		var ring_target_active := false
		var ring_target_distance := INF
		var ring_wait_owner_handle := EntityHandle.INVALID
		if _contact_ring_active:
			var ring_target := Vector2.ZERO
			if ring_claimed:
				_contact_ring_wait_starts[slot] = -1
				ring_target = _contact_ring_target_position(
					_contact_ring_claim_starts[slot],
					_contact_ring_claim_spans[slot],
					contact_radius - CONTACT_ENTRY_DEPTH,
					enemy.crowd_radius()
				)
				ring_target_active = true
			else:
				var span := _contact_ring_span(enemy)
				var bearing := _contact_ring_bearing_from_avatar_delta(avatar_delta)
				var wait_start := _contact_ring_wait_starts[slot]
				if wait_start < 0:
					wait_start = _contact_ring_desired_start(span, bearing)
				_contact_ring_wait_starts[slot] = wait_start
				ring_wait_owner_handle = _contact_ring_owner_for_span(wait_start, span)
				if avatar_distance <= contact_radius + CONTACT_RING_RESERVATION_MARGIN + CONTACT_RING_RESERVATION_RELEASE_MARGIN:
					ring_target = _contact_ring_target_position(
						wait_start,
						span,
						_contact_ring_wait_radius(slot, enemy, wait_start, span),
						enemy.crowd_radius()
					)
					ring_target_active = true
			if ring_target_active:
				var target_delta := _crowd_topology.shortest_delta(enemy.global_position, ring_target)
				if not ring_claimed:
					# A waiter may already stand inside its nominal queue radius. Moving it
					# back out to that bookkeeping target reads as an unexplained shove away
					# from the Doctor. Preserve only a possible tangential slot correction;
					# claimed attackers still travel normally to their exact contact point.
					var radial_progress := target_delta.dot(avatar_chase_direction)
					if radial_progress < 0.0:
						target_delta -= avatar_chase_direction * radial_progress
				ring_target_distance = target_delta.length()
				if ring_target_distance > 0.0001:
					chase_direction = target_delta / ring_target_distance
					lateral_axis = chase_direction.orthogonal()
			if ring_claimed and _contact_ring_attack_armed[slot] == 0:
				var contact_step := (
					enemy.definition.speed
					* enemy.speed_multiplier
					* enemy.status_speed_multiplier()
					* delta
				)
				if ring_target_distance <= contact_step + CONTACT_RING_ATTACK_ARM_MARGIN:
					_apply_contact_ring_cooldown(enemy, _contact_ring_claim_starts[slot], _contact_ring_claim_spans[slot])
					_contact_ring_attack_armed[slot] = 1
			if ring_claimed and ring_target_distance <= CONTACT_RING_TARGET_TOLERANCE:
				if _crowd_contact_latched[slot] == 0:
					_crowd_contact_latched[slot] = 1
					if _contact_ring_attack_armed[slot] == 0:
						_apply_contact_ring_cooldown(enemy, _contact_ring_claim_starts[slot], _contact_ring_claim_spans[slot])
						_contact_ring_attack_armed[slot] = 1
		if _crowd_contact_latched[slot] != 0:
			if avatar_distance > contact_radius + CONTACT_RELEASE_MARGIN:
				_crowd_contact_latched[slot] = 0
			else:
				# Contact never reverses locomotion. The old small-body yield branch
				# moved an enemy away under its own power when the Doctor approached,
				# which looked like fleeing and broke the surrounding shell.
				_crowd_resolved_directions[slot] = chase_direction
				_crowd_resolved_speeds[slot] = 0.0
				enemy.set_crowd_steering(Vector2.ZERO, 0.0)
				continue
		if _contact_ring_active:
			# A stationary Doctor has deterministic contact slots and radial queues.
			# Running the generic predictive lane solver on those already-owned paths
			# made the queue shake and needlessly issued hundreds of broad-phase
			# queries. Bodies outside reservation range simply approach the Doctor;
			# once close enough their persistent wait slot becomes their direct target.
			var ring_speed := 1.0
			if ring_target_active:
				if ring_target_distance <= CONTACT_RING_TARGET_TOLERANCE:
					ring_speed = 0.0
				else:
					var refresh_steps := 1.0 if ring_claimed else float(CROWD_UPDATE_PHASES)
					ring_speed = clampf(
						ring_target_distance / maxf(
							enemy.definition.speed * enemy.speed_multiplier * enemy.status_speed_multiplier()
							* delta * refresh_steps,
							0.001
						),
						0.0,
						1.0
					)
			_crowd_resolved_directions[slot] = chase_direction
			_crowd_resolved_speeds[slot] = ring_speed
			enemy.set_crowd_steering(
				_crowd_steering_for_direction(avatar_chase_direction, chase_direction, ring_target_active),
				ring_speed
			)
			continue
		_query_nearest_crowd_candidates(
			slot,
			enemy,
			enemy.crowd_radius()
			+ _maximum_crowd_radius
			+ CROWD_NEIGHBOR_MARGIN
			+ CROWD_MOTION_QUERY_MARGIN
		)
		var safe_direction := chase_direction
		var neighbor_avoidance_active := false
		var strongest_bypass_proximity := 0.0
		var current_movement_speed := maxf(
			enemy.definition.speed * enemy.speed_multiplier * enemy.status_speed_multiplier(),
			0.001
		)
		_crowd_constraint_normals.clear()
		_crowd_constraint_limits.clear()
		for other_handle in _crowd_nearest_candidates:
			var other_slot := EntityHandle.slot(other_handle)
			if other_slot < 0 or other_slot == slot or other_slot >= _typed_enemies.size() or _retiring[other_slot] != 0:
				continue
			var other := _typed_enemies[other_slot]
			if other == null or not other.is_targetable() or other.definition == null:
				continue
			if _contact_ring_active:
				if ring_claimed and _contact_ring_claim_starts[other_slot] >= 0:
					continue
				if not ring_claimed and other_handle == ring_wait_owner_handle:
					continue
			var neighbor_delta := _crowd_topology.shortest_delta(enemy.global_position, other.global_position)
			var preferred_distance := enemy.crowd_radius() + other.crowd_radius()
			var influence_distance := preferred_distance + CROWD_NEIGHBOR_MARGIN
			var distance_squared := neighbor_delta.length_squared()
			if distance_squared >= influence_distance * influence_distance:
				continue
			var distance := sqrt(maxf(distance_squared, 0.000001))
			var toward_other := neighbor_delta / distance if distance_squared > 0.000001 else -_overlap_axis(slot, other_slot)
			var clearance := distance - preferred_distance
			var forward_alignment := toward_other.dot(chase_direction)
			var other_avatar_delta := _crowd_topology.shortest_delta(other.global_position, _crowd_avatar.global_position)
			var other_avatar_distance := other_avatar_delta.length()
			var other_has_priority := _crowd_contact_latched[other_slot] != 0
			if not other_has_priority:
				other_has_priority = other_avatar_distance < avatar_distance - FRONT_PRIORITY_EPSILON
			if not other_has_priority and absf(other_avatar_distance - avatar_distance) <= FRONT_PRIORITY_EPSILON:
				other_has_priority = other_slot < slot
			if not other_has_priority or (forward_alignment < FRONT_ALIGNMENT_MINIMUM and clearance >= 0.0):
				# A follower never steers the front line. Equal-depth bodies resolve
				# ownership through their stable slot, so the correction is one-sided.
				continue
			if enemy.definition.is_boss and not other.definition.is_boss:
				continue
			neighbor_avoidance_active = true
			var proximity := clampf(
				(influence_distance - distance) / CROWD_NEIGHBOR_MARGIN,
				0.0,
				1.0
			)
			if proximity > strongest_bypass_proximity:
				strongest_bypass_proximity = proximity
			# Resolve relative velocity, not motion against a fictional stationary
			# blocker. Matching the leader's normal component keeps the shell stable;
			# existing overlap adds a small separating component. This lets both bodies
			# continue moving instead of the follower slowly closing the gap.
			var other_normalized_projection := 0.0
			if _crowd_contact_latched[other_slot] == 0 and not other.is_stunned():
				var other_chase_direction := other_avatar_delta.normalized() if other_avatar_distance > 0.0001 else Vector2.RIGHT
				var other_resolved_direction := _crowd_resolved_directions[other_slot]
				if other_resolved_direction.length_squared() <= 0.0001:
					other_resolved_direction = other_chase_direction
				var other_movement_speed := other.definition.speed * other.speed_multiplier * other.status_speed_multiplier()
				other_normalized_projection = (
					other_resolved_direction.dot(toward_other)
					* other_movement_speed * float(_crowd_resolved_speeds[other_slot])
					/ current_movement_speed
				)
			var clearance_fraction := clampf(clearance / CROWD_NEIGHBOR_MARGIN, 0.0, 1.0)
			var allowed_inward_speed := lerpf(other_normalized_projection, 1.0, clearance_fraction)
			if clearance < 0.0:
				allowed_inward_speed -= clampf(-clearance / CROWD_NEIGHBOR_MARGIN, 0.0, 0.45)
			allowed_inward_speed = clampf(allowed_inward_speed, -0.45, 1.0)
			_crowd_constraint_normals.append(toward_other)
			_crowd_constraint_limits.append(allowed_inward_speed)

		# Only the actual front body owns a contact position. A follower already
		# inside the shell must finish its bypass instead of latching into the same
		# space and freezing a visible pile.
		if (
			not _contact_ring_active
			and not neighbor_avoidance_active
			and avatar_distance <= contact_radius - CONTACT_ENTRY_DEPTH
		):
			_crowd_contact_latched[slot] = 1
			_crowd_resolved_directions[slot] = chase_direction
			_crowd_resolved_speeds[slot] = 0.0
			enemy.set_crowd_steering(Vector2.ZERO, 0.0)
			continue

		if neighbor_avoidance_active:
			if _crowd_lane_holds[slot] <= 0:
				# Every local lane uses the same circulation handedness. Choosing
				# independently "away" from two adjacent bodies made their escape
				# paths face each other and produced the visible head-on wobble.
				_crowd_lane_signs[slot] = 1
			_crowd_lane_holds[slot] = BYPASS_HOLD_UPDATES
		elif _crowd_lane_holds[slot] > 0:
			_crowd_lane_holds[slot] -= 1
			if _crowd_lane_holds[slot] <= 0:
				_crowd_lane_signs[slot] = 0
		var lane_active := neighbor_avoidance_active or _crowd_lane_holds[slot] > 0
		# The continuous guard is geometric rather than behavioral. A front body
		# may intentionally ignore followers for steering priority, but it still
		# must not cross a side neighbor between two phased steering refreshes.
		_store_motion_guard_neighbors(slot, enemy)
		var lane_sign := _crowd_lane_signs[slot] if _crowd_lane_signs[slot] != 0 else 1
		var preferred_lateral := lateral_axis * float(lane_sign)
		if lane_active:
			var bypass_bias := lerpf(
				BYPASS_BIAS_MINIMUM,
				BYPASS_BIAS_MAXIMUM,
				strongest_bypass_proximity
			)
			safe_direction = (chase_direction + preferred_lateral * bypass_bias).normalized()
		if neighbor_avoidance_active:
			safe_direction = _project_crowd_velocity(
				safe_direction,
				preferred_lateral,
				Vector2.ZERO if ring_target_active else avatar_chase_direction
			)
		var resolved_speed := 1.0
		if ring_target_active:
			if ring_target_distance <= CONTACT_RING_TARGET_TOLERANCE:
				resolved_speed = 0.0
			else:
				var refresh_steps := 1.0 if ring_claimed else float(CROWD_UPDATE_PHASES)
				resolved_speed = clampf(
					ring_target_distance / maxf(current_movement_speed * delta * refresh_steps, 0.001),
					0.0,
					1.0
				)
		_crowd_resolved_directions[slot] = safe_direction
		_crowd_resolved_speeds[slot] = resolved_speed
		enemy.set_crowd_steering(
			_crowd_steering_for_direction(avatar_chase_direction, safe_direction, ring_target_active),
			resolved_speed
		)

	_crowd_phase = (_crowd_phase + 1) % CROWD_UPDATE_PHASES
	if _contact_ring_active:
		_crowd_avatar.set_crowd_blocking(Vector2.ZERO)
		return
	_crowd_candidates = _crowd_grid.query_circle_candidates_limited(
		_crowd_avatar.global_position,
		TherapyAvatar.BODY_RADIUS + _maximum_body_radius,
		MAX_AVATAR_NEIGHBORS,
		_crowd_candidates
	)
	for handle in _crowd_candidates:
		var enemy := resolve(handle) as InfectionEnemy
		if enemy == null or not enemy.is_targetable() or enemy.definition == null or enemy.definition.id == SMALL_ENEMY_ID:
			continue
		var avatar_delta := _crowd_topology.shortest_delta(enemy.global_position, _crowd_avatar.global_position)
		var avatar_minimum := _contact_radius(enemy) * AVATAR_SPACING_FACTOR
		var avatar_distance_squared := avatar_delta.length_squared()
		if avatar_distance_squared >= avatar_minimum * avatar_minimum:
			continue
		var avatar_distance := sqrt(maxf(avatar_distance_squared, 0.000001))
		var avatar_overlap := 1.0 - avatar_distance / maxf(avatar_minimum, 0.001)
		if avatar_overlap <= strongest_avatar_overlap:
			continue
		var toward_avatar := avatar_delta / avatar_distance if avatar_distance_squared > 0.000001 else Vector2.RIGHT
		strongest_avatar_overlap = avatar_overlap
		strongest_avatar_block = -toward_avatar * clampf(avatar_overlap * 1.35, 0.0, 1.0)
	_crowd_avatar.set_crowd_blocking(strongest_avatar_block)


func contact_ring_is_active() -> bool:
	return _contact_ring_active


func contact_ring_claim_count() -> int:
	var count := 0
	for slot in _active_slots:
		if _retiring[slot] == 0 and _contact_ring_claim_starts[slot] >= 0:
			count += 1
	return count


func contact_ring_claim(handle: int) -> Dictionary:
	if not is_active(handle):
		return {}
	var slot := EntityHandle.slot(handle)
	var start := _contact_ring_claim_starts[slot]
	if start < 0:
		return {}
	return {
		"start": start,
		"span": _contact_ring_claim_spans[slot],
		"latched": _crowd_contact_latched[slot] != 0,
	}


func _update_contact_ring_mode(delta: float) -> void:
	var avatar_stationary := (
		_crowd_avatar.velocity.length_squared()
		<= STATIONARY_AVATAR_SPEED_THRESHOLD * STATIONARY_AVATAR_SPEED_THRESHOLD
	)
	if avatar_stationary:
		_contact_ring_stationary_seconds += delta
		_contact_ring_moving_seconds = 0.0
		if not _contact_ring_active and _contact_ring_stationary_seconds >= CONTACT_RING_STATIONARY_ENTER_SECONDS:
			_set_contact_ring_active(true)
	else:
		_contact_ring_stationary_seconds = 0.0
		_contact_ring_moving_seconds += delta
		if _contact_ring_active and _contact_ring_moving_seconds >= CONTACT_RING_MOVING_EXIT_SECONDS:
			_set_contact_ring_active(false)


func _set_contact_ring_active(active: bool) -> void:
	if _contact_ring_active == active:
		return
	_contact_ring_active = active
	_clear_contact_ring_claims()
	_contact_ring_assignments_dirty = active
	_contact_ring_saturated = false
	for slot_value in _active_slots:
		var slot := int(slot_value)
		_crowd_contact_latched[slot] = 0
		_crowd_lane_signs[slot] = 0
		_crowd_lane_holds[slot] = 0
		_crowd_resolved_directions[slot] = Vector2.ZERO
		_crowd_resolved_speeds[slot] = 1.0
		_contact_ring_wait_starts[slot] = -1
		_contact_ring_wait_ranks[slot] = 0
		_contact_ring_attack_armed[slot] = 0
		var enemy := _typed_enemies[slot]
		if enemy != null:
			enemy.set_crowd_steering(Vector2.ZERO, 1.0)


func _refresh_contact_ring_claims() -> void:
	if not _contact_ring_active:
		return
	for micro_slot in range(CONTACT_RING_MICRO_SLOTS):
		var handle := int(_contact_ring_owners[micro_slot])
		if not EntityHandle.is_valid(handle):
			continue
		var slot := EntityHandle.slot(handle)
		if slot < 0 or slot >= _typed_enemies.size() or _contact_ring_claim_starts[slot] != micro_slot:
			continue
		var enemy := resolve(handle) as InfectionEnemy
		if enemy == null or not enemy.is_targetable() or enemy.definition == null or enemy.is_stunned():
			_release_contact_ring_claim(slot, handle)
			continue
		var avatar_distance := _crowd_topology.distance(enemy.global_position, _crowd_avatar.global_position)
		var contact_radius := _contact_radius(enemy)
		var release_distance := (
			contact_radius + CONTACT_RELEASE_MARGIN
			if _crowd_contact_latched[slot] != 0
			else contact_radius + CONTACT_RING_RESERVATION_MARGIN + CONTACT_RING_RESERVATION_RELEASE_MARGIN
		)
		if avatar_distance > release_distance:
			_release_contact_ring_claim(slot, handle)


func _prepare_contact_ring_assignments() -> void:
	if not _contact_ring_active:
		return
	_contact_ring_assignments_dirty = false
	_contact_ring_saturated = false
	_contact_ring_wait_counts.fill(0)
	for slot_value in _active_slots:
		var slot := int(slot_value)
		_contact_ring_wait_ranks[slot] = 0
		if _retiring[slot] != 0:
			continue
		var enemy := _typed_enemies[slot]
		if enemy == null or not enemy.is_targetable() or enemy.definition == null or enemy.is_stunned():
			continue
		var avatar_delta := _crowd_topology.shortest_delta(enemy.global_position, _crowd_avatar.global_position)
		var avatar_distance := avatar_delta.length()
		var contact_radius := _contact_radius(enemy)
		var handle := EntityHandle.make(slot, _generations[slot])
		if _contact_ring_reclaim_holds[slot] > 0:
			_contact_ring_reclaim_holds[slot] = maxi(
				_contact_ring_reclaim_holds[slot] - CROWD_UPDATE_PHASES,
				0
			)
		if (
			_contact_ring_claim_starts[slot] < 0
			and _contact_ring_reclaim_holds[slot] <= 0
			and avatar_distance <= contact_radius + CONTACT_RING_RESERVATION_MARGIN
		):
			if not _try_claim_contact_ring(handle, enemy, avatar_delta):
				_contact_ring_saturated = true
		if _contact_ring_claim_starts[slot] >= 0:
			_contact_ring_wait_starts[slot] = -1
			continue
		var span := _contact_ring_span(enemy)
		if _contact_ring_wait_starts[slot] < 0:
			var desired_wait_start := _contact_ring_desired_start(
				span,
				_contact_ring_bearing_from_avatar_delta(avatar_delta)
			)
			var owner_wait_start := _contact_ring_nearest_owner_start(
				_contact_ring_bearing_from_avatar_delta(avatar_delta)
			)
			_contact_ring_wait_starts[slot] = owner_wait_start if owner_wait_start >= 0 else desired_wait_start
		var wait_start := _contact_ring_wait_starts[slot]
		_contact_ring_wait_ranks[slot] = _contact_ring_wait_counts[wait_start]
		_contact_ring_wait_counts[wait_start] += 1


func _try_claim_contact_ring(handle: int, enemy: InfectionEnemy, avatar_delta: Vector2) -> bool:
	if not EntityHandle.is_valid(handle) or enemy == null or enemy.definition == null:
		return false
	var slot := EntityHandle.slot(handle)
	if _contact_ring_claim_starts[slot] >= 0:
		return true
	if _contact_ring_is_hard_body(enemy) and _contact_ring_hard_claim_count() >= CONTACT_RING_MAX_HARD_BODIES:
		return false
	var span := _contact_ring_span(enemy)
	var bearing := _contact_ring_bearing_from_avatar_delta(avatar_delta)
	var best_start := -1
	var best_distance := INF
	for start in range(CONTACT_RING_MICRO_SLOTS):
		if not _contact_ring_span_is_free(start, span) or not _contact_ring_target_is_clear(enemy, start, span):
			continue
		var distance := _contact_ring_angle_distance(_contact_ring_center_bearing(start, span), bearing)
		if distance < best_distance - 0.0001 or (is_equal_approx(distance, best_distance) and start < best_start):
			best_start = start
			best_distance = distance
	if best_start < 0:
		if _contact_ring_is_hard_body(enemy):
			return _try_claim_cluster_with_small_preemption(handle, enemy, bearing, span)
		return false
	return _assign_contact_ring_claim(handle, slot, best_start, span)


func _try_claim_cluster_with_small_preemption(
	handle: int,
	enemy: InfectionEnemy,
	bearing: float,
	span: int
) -> bool:
	# Small bacteria may have claimed first and fragmented all three-slot arcs.
	# A red group is an explicit direct attacker, so choose the closest arc that
	# requires the fewest small owners to yield. Other large bodies are never
	# displaced, and this event-only search does not alter normal locomotion.
	var best_start := -1
	var best_distance := INF
	var best_victims := PackedInt64Array()
	for start in range(CONTACT_RING_MICRO_SLOTS):
		var target := _contact_ring_target_position(
			start,
			span,
			_contact_radius(enemy) - CONTACT_ENTRY_DEPTH,
			enemy.crowd_radius()
		)
		var victims := PackedInt64Array()
		var blocked_by_large_body := false
		for micro_slot in range(CONTACT_RING_MICRO_SLOTS):
			var other_handle := int(_contact_ring_owners[micro_slot])
			if not EntityHandle.is_valid(other_handle):
				continue
			var other_slot := EntityHandle.slot(other_handle)
			if (
				other_slot < 0
				or other_slot >= _typed_enemies.size()
				or _retiring[other_slot] != 0
				or _contact_ring_claim_starts[other_slot] != micro_slot
			):
				continue
			var other := _typed_enemies[other_slot]
			if other == null or other.definition == null:
				continue
			var spans_overlap := false
			for offset in range(span):
				if int(_contact_ring_owners[posmod(start + offset, CONTACT_RING_MICRO_SLOTS)]) == other_handle:
					spans_overlap = true
					break
			var other_target := _contact_ring_target_position(
				_contact_ring_claim_starts[other_slot],
				_contact_ring_claim_spans[other_slot],
				_contact_radius(other) - CONTACT_ENTRY_DEPTH,
				other.crowd_radius()
			)
			var minimum_distance := enemy.crowd_radius() + other.crowd_radius() + CONTACT_RING_CLAIM_CLEARANCE
			var geometrically_blocked := (
				_crowd_topology.distance_squared(target, other_target)
				< minimum_distance * minimum_distance
			)
			if not spans_overlap and not geometrically_blocked:
				continue
			if other.definition.id != SMALL_ENEMY_ID:
				blocked_by_large_body = true
				break
			victims.append(other_handle)
		if blocked_by_large_body:
			continue
		var distance := _contact_ring_angle_distance(_contact_ring_center_bearing(start, span), bearing)
		if (
			best_start < 0
			or victims.size() < best_victims.size()
			or (
				victims.size() == best_victims.size()
				and (distance < best_distance - 0.0001 or (is_equal_approx(distance, best_distance) and start < best_start))
			)
		):
			best_start = start
			best_distance = distance
			best_victims = victims
	if best_start < 0:
		return false
	for victim_handle in best_victims:
		var victim_slot := EntityHandle.slot(victim_handle)
		if victim_slot >= 0 and victim_slot < _typed_enemies.size():
			_release_contact_ring_claim(victim_slot, victim_handle)
	if not _contact_ring_span_is_free(best_start, span) or not _contact_ring_target_is_clear(enemy, best_start, span):
		return false
	return _assign_contact_ring_claim(handle, EntityHandle.slot(handle), best_start, span)


func _assign_contact_ring_claim(handle: int, slot: int, start: int, span: int) -> bool:
	for offset in range(span):
		_contact_ring_owners[posmod(start + offset, CONTACT_RING_MICRO_SLOTS)] = handle
	_contact_ring_claim_starts[slot] = start
	_contact_ring_claim_spans[slot] = span
	_contact_ring_wait_starts[slot] = -1
	_contact_ring_wait_ranks[slot] = 0
	_contact_ring_attack_armed[slot] = 0
	_contact_ring_reclaim_holds[slot] = 0
	return true


func _release_contact_ring_claim(slot: int, handle: int) -> void:
	if slot < 0 or slot >= _contact_ring_claim_starts.size():
		return
	for micro_slot in range(CONTACT_RING_MICRO_SLOTS):
		if int(_contact_ring_owners[micro_slot]) == handle:
			_contact_ring_owners[micro_slot] = EntityHandle.INVALID
	_contact_ring_claim_starts[slot] = -1
	_contact_ring_claim_spans[slot] = 0
	_contact_ring_wait_starts[slot] = -1
	_contact_ring_wait_ranks[slot] = 0
	_contact_ring_attack_armed[slot] = 0
	_contact_ring_reclaim_holds[slot] = CONTACT_RING_RECLAIM_HOLD_UPDATES
	_contact_ring_assignments_dirty = _contact_ring_active
	_contact_ring_saturated = false
	_crowd_contact_latched[slot] = 0
	_crowd_resolved_directions[slot] = Vector2.ZERO
	_crowd_resolved_speeds[slot] = 1.0
	_crowd_motion_guards[slot] = 0
	var enemy := resolve(handle) as InfectionEnemy
	if enemy != null:
		enemy.set_crowd_steering(Vector2.ZERO, 1.0)


func _clear_contact_ring_claims() -> void:
	_contact_ring_owners.fill(EntityHandle.INVALID)
	_contact_ring_claim_starts.fill(-1)
	_contact_ring_claim_spans.fill(0)
	_contact_ring_wait_starts.fill(-1)
	_contact_ring_wait_ranks.fill(0)
	_contact_ring_wait_counts.fill(0)
	_contact_ring_attack_armed.fill(0)
	_contact_ring_reclaim_holds.fill(0)


func _contact_radius(enemy: InfectionEnemy) -> float:
	if enemy == null:
		return TherapyAvatar.CONTACT_RADIUS
	return TherapyAvatar.CONTACT_RADIUS + enemy.contact_body_radius()


func _contact_ring_span(enemy: InfectionEnemy) -> int:
	match enemy.definition.id:
		SMALL_ENEMY_ID:
			return CONTACT_RING_SMALL_SPAN
		CLUSTER_ENEMY_ID:
			return CONTACT_RING_CLUSTER_SPAN
	var contact_radius := maxf(_contact_radius(enemy), 0.001)
	var radius_ratio := clampf(enemy.crowd_radius() / contact_radius, 0.0, 0.999)
	var angular_diameter := 2.0 * asin(radius_ratio)
	return clampi(ceili(angular_diameter / (TAU / float(CONTACT_RING_MICRO_SLOTS))), 1, CONTACT_RING_MICRO_SLOTS)


func _contact_ring_is_hard_body(enemy: InfectionEnemy) -> bool:
	# The product cap applies to red bacterial groups specifically. Bosses, nests
	# and future roles still obey geometry but do not consume these two places.
	return enemy.definition.id == CLUSTER_ENEMY_ID


func _contact_ring_hard_claim_count() -> int:
	var count := 0
	for micro_slot in range(CONTACT_RING_MICRO_SLOTS):
		var handle := int(_contact_ring_owners[micro_slot])
		if not EntityHandle.is_valid(handle):
			continue
		var slot := EntityHandle.slot(handle)
		if slot < 0 or slot >= _typed_enemies.size() or _retiring[slot] != 0:
			continue
		# A multi-slot owner is counted exactly once at the first slot of its span.
		if _contact_ring_claim_starts[slot] != micro_slot:
			continue
		var enemy := _typed_enemies[slot]
		if enemy != null and enemy.definition != null and _contact_ring_is_hard_body(enemy):
			count += 1
	return count


func _contact_ring_span_is_free(start: int, span: int) -> bool:
	for offset in range(span):
		if EntityHandle.is_valid(int(_contact_ring_owners[posmod(start + offset, CONTACT_RING_MICRO_SLOTS)])):
			return false
	return true


func _contact_ring_target_is_clear(enemy: InfectionEnemy, start: int, span: int) -> bool:
	var target := _contact_ring_target_position(
		start,
		span,
		_contact_radius(enemy) - CONTACT_ENTRY_DEPTH,
		enemy.crowd_radius()
	)
	for micro_slot in range(CONTACT_RING_MICRO_SLOTS):
		var other_handle := int(_contact_ring_owners[micro_slot])
		if not EntityHandle.is_valid(other_handle):
			continue
		var other_slot := EntityHandle.slot(other_handle)
		if other_slot < 0 or other_slot >= _typed_enemies.size() or _retiring[other_slot] != 0:
			continue
		if _contact_ring_claim_starts[other_slot] != micro_slot:
			continue
		var other := _typed_enemies[other_slot]
		if other == null or other.definition == null:
			continue
		var other_target := _contact_ring_target_position(
			_contact_ring_claim_starts[other_slot],
			_contact_ring_claim_spans[other_slot],
			_contact_radius(other) - CONTACT_ENTRY_DEPTH,
			other.crowd_radius()
		)
		var minimum_distance := enemy.crowd_radius() + other.crowd_radius() + CONTACT_RING_CLAIM_CLEARANCE
		if _crowd_topology.distance_squared(target, other_target) < minimum_distance * minimum_distance:
			return false
	return true


func _contact_ring_bearing_from_avatar_delta(avatar_delta: Vector2) -> float:
	return fposmod((-avatar_delta).angle(), TAU) if avatar_delta.length_squared() > 0.000001 else 0.0


func _contact_ring_center_bearing(start: int, span: int) -> float:
	return fposmod(
		(float(start) + float(span) * 0.5) * TAU / float(CONTACT_RING_MICRO_SLOTS),
		TAU
	)


func _contact_ring_angle_distance(first: float, second: float) -> float:
	return absf(fposmod(first - second + PI, TAU) - PI)


func _contact_ring_desired_start(span: int, bearing: float) -> int:
	var scaled := bearing * float(CONTACT_RING_MICRO_SLOTS) / TAU - float(span) * 0.5
	return posmod(roundi(scaled), CONTACT_RING_MICRO_SLOTS)


func _contact_ring_target_position(start: int, span: int, radial_distance: float, body_radius: float) -> Vector2:
	var bearing := _contact_ring_center_bearing(start, span)
	return _crowd_topology.resolve_position(
		_crowd_avatar.global_position + Vector2.from_angle(bearing) * maxf(radial_distance, 1.0),
		body_radius
	)


func _contact_ring_wait_radius(slot: int, enemy: InfectionEnemy, start: int, span: int) -> float:
	var owner_handle := _contact_ring_owner_for_span(start, span)
	var front_radius := _contact_radius(enemy) - CONTACT_ENTRY_DEPTH
	var front_crowd_radius := enemy.crowd_radius()
	var owner := resolve(owner_handle) as InfectionEnemy
	if owner != null and owner.definition != null:
		front_radius = _contact_radius(owner) - CONTACT_ENTRY_DEPTH
		front_crowd_radius = owner.crowd_radius()
	var queue_rank := _contact_ring_wait_ranks[slot]
	return (
		front_radius
		+ front_crowd_radius
		+ enemy.crowd_radius()
		+ CONTACT_RING_WAIT_MARGIN
		+ float(queue_rank) * (enemy.crowd_radius() * 2.0 + CONTACT_RING_WAIT_MARGIN)
	)


func _contact_ring_owner_for_span(start: int, span: int) -> int:
	for offset in range(span):
		var candidate := int(_contact_ring_owners[posmod(start + offset, CONTACT_RING_MICRO_SLOTS)])
		if EntityHandle.is_valid(candidate):
			return candidate
	return EntityHandle.INVALID


func _contact_ring_nearest_owner_start(bearing: float) -> int:
	var best_start := -1
	var best_distance := INF
	for micro_slot in range(CONTACT_RING_MICRO_SLOTS):
		var handle := int(_contact_ring_owners[micro_slot])
		if not EntityHandle.is_valid(handle):
			continue
		var slot := EntityHandle.slot(handle)
		if slot < 0 or slot >= _typed_enemies.size() or _retiring[slot] != 0:
			continue
		var start := _contact_ring_claim_starts[slot]
		if start != micro_slot:
			continue
		var distance := _contact_ring_angle_distance(
			_contact_ring_center_bearing(start, _contact_ring_claim_spans[slot]),
			bearing
		)
		if distance < best_distance - 0.0001 or (is_equal_approx(distance, best_distance) and start < best_start):
			best_start = start
			best_distance = distance
	return best_start


func _apply_contact_ring_cooldown(enemy: InfectionEnemy, start: int, span: int) -> void:
	var interval := 0.58 if enemy.definition.is_boss else 0.82
	var phase := _contact_ring_center_bearing(start, span) / TAU * interval
	var remaining := fposmod(phase - fposmod(_crowd_elapsed_seconds, interval), interval)
	enemy.contact_cooldown = maxf(enemy.contact_cooldown, remaining)


func _crowd_steering_for_direction(
	avatar_direction: Vector2,
	safe_direction: Vector2,
	direct_target: bool = false
) -> Vector2:
	# Moving enemies receive a relative correction. Their own chase direction is
	# recomputed every fixed tick, so a phased crowd refresh cannot leave a stale
	# world-space vector that visibly flips or points away from Doctor Milos.
	if not direct_target:
		return safe_direction.normalized() - avatar_direction.normalized()
	# Fixed ring and queue targets may sit off the direct avatar ray. Preserve the
	# stronger target intent only for those stable, stationary destinations.
	return safe_direction.normalized() * 0.5 - avatar_direction.normalized()


func _query_nearest_crowd_candidates(slot: int, enemy: InfectionEnemy, search_radius: float) -> void:
	_crowd_candidates = _crowd_grid.query_circle_candidates_limited(
		enemy.global_position,
		search_radius,
		MAX_CROWD_QUERY_CANDIDATES,
		_crowd_candidates
	)
	_crowd_nearest_candidates.clear()
	_crowd_nearest_distances.clear()
	var radius_squared := search_radius * search_radius
	for handle in _crowd_candidates:
		var other_slot := EntityHandle.slot(handle)
		if other_slot < 0 or other_slot == slot or other_slot >= _typed_enemies.size() or _retiring[other_slot] != 0:
			continue
		var other := _typed_enemies[other_slot]
		if other == null or not other.is_targetable() or other.definition == null:
			continue
		var distance_squared := _crowd_topology.shortest_delta(enemy.global_position, other.global_position).length_squared()
		if distance_squared > radius_squared:
			continue
		if _crowd_nearest_candidates.size() < MAX_CROWD_NEIGHBORS:
			_crowd_nearest_candidates.append(handle)
			_crowd_nearest_distances.append(distance_squared)
			continue
		var farthest_index := 0
		var farthest_distance := float(_crowd_nearest_distances[0])
		for index in range(1, _crowd_nearest_distances.size()):
			if _crowd_nearest_distances[index] > farthest_distance:
				farthest_index = index
				farthest_distance = _crowd_nearest_distances[index]
		if distance_squared < farthest_distance:
			_crowd_nearest_candidates[farthest_index] = handle
			_crowd_nearest_distances[farthest_index] = distance_squared


func _store_motion_guard_neighbors(slot: int, enemy: InfectionEnemy) -> void:
	var count := 0
	var offset := slot * MAX_CROWD_MOTION_GUARDS
	for guard_index in range(MAX_CROWD_MOTION_GUARDS):
		_crowd_motion_guard_neighbors[offset + guard_index] = EntityHandle.INVALID
		_crowd_motion_guard_distances[offset + guard_index] = INF
	var own_speed := enemy.definition.speed * enemy.speed_multiplier * enemy.status_speed_multiplier()
	for candidate_index in range(_crowd_nearest_candidates.size()):
		var handle := int(_crowd_nearest_candidates[candidate_index])
		var other_slot := EntityHandle.slot(handle)
		if other_slot < 0 or other_slot == slot or other_slot >= _typed_enemies.size() or _retiring[other_slot] != 0:
			continue
		var other := _typed_enemies[other_slot]
		if other == null or not other.is_targetable() or other.definition == null:
			continue
		var other_speed := other.definition.speed * other.speed_multiplier * other.status_speed_multiplier()
		var guard_distance := (
			enemy.crowd_radius()
			+ other.crowd_radius()
			+ (own_speed + other_speed) * CROWD_MOTION_LOOKAHEAD_SECONDS
			+ 2.0
		)
		var distance_squared := float(_crowd_nearest_distances[candidate_index])
		if distance_squared > guard_distance * guard_distance:
			continue
		if (
			count >= MAX_CROWD_MOTION_GUARDS
			and distance_squared >= float(_crowd_motion_guard_distances[offset + MAX_CROWD_MOTION_GUARDS - 1])
		):
			continue
		var insert_index := mini(count, MAX_CROWD_MOTION_GUARDS - 1)
		while insert_index > 0 and distance_squared < float(_crowd_motion_guard_distances[offset + insert_index - 1]):
			if insert_index < MAX_CROWD_MOTION_GUARDS:
				_crowd_motion_guard_neighbors[offset + insert_index] = _crowd_motion_guard_neighbors[offset + insert_index - 1]
				_crowd_motion_guard_distances[offset + insert_index] = _crowd_motion_guard_distances[offset + insert_index - 1]
			insert_index -= 1
		if insert_index < MAX_CROWD_MOTION_GUARDS:
			_crowd_motion_guard_neighbors[offset + insert_index] = handle
			_crowd_motion_guard_distances[offset + insert_index] = distance_squared
		count = mini(count + 1, MAX_CROWD_MOTION_GUARDS)
	_crowd_motion_guard_counts[slot] = count
	_crowd_motion_guards[slot] = 1 if count > 0 else 0


func _project_crowd_velocity(
	desired_direction: Vector2,
	preferred_lateral: Vector2,
	minimum_progress_direction: Vector2 = Vector2.ZERO
) -> Vector2:
	var resolved := desired_direction.normalized()
	var preferred := preferred_lateral.normalized()
	# One stable blocking boundary is enough for locomotion. Continuously checking
	# the three nearest imminent contacts below is what guarantees geometry; this
	# projection only selects a readable lane and therefore stays O(neighbours).
	var urgent_index := -1
	var urgent_violation := 0.0
	for constraint_index in range(_crowd_constraint_normals.size()):
		var normal := _crowd_constraint_normals[constraint_index]
		var inward_limit := clampf(float(_crowd_constraint_limits[constraint_index]), -0.45, 1.0)
		var violation := resolved.dot(normal) - inward_limit
		if violation > urgent_violation:
			urgent_violation = violation
			urgent_index = constraint_index
	if urgent_index >= 0:
		var normal := _crowd_constraint_normals[urgent_index]
		var inward_limit := clampf(float(_crowd_constraint_limits[urgent_index]), -0.45, 1.0)
		var tangent := normal.orthogonal()
		if tangent.dot(preferred) < 0.0:
			tangent = -tangent
		var tangent_length := sqrt(maxf(0.0, 1.0 - inward_limit * inward_limit))
		resolved = (normal * inward_limit + tangent * tangent_length).normalized()
	var progress := minimum_progress_direction.normalized()
	if not progress.is_zero_approx():
		var forward := resolved.dot(progress)
		if forward < MINIMUM_FORWARD_PROGRESS:
			resolved -= progress * (forward - MINIMUM_FORWARD_PROGRESS)
			if resolved.length_squared() > 0.000001:
				resolved = resolved.normalized()
			else:
				resolved = preferred
	return resolved


func _overlap_axis(first_slot: int, second_slot: int) -> Vector2:
	var lower := mini(first_slot, second_slot)
	var upper := maxi(first_slot, second_slot)
	var angle := float((lower * 37 + upper * 17 + 23) % 360) * PI / 180.0
	var axis := Vector2.from_angle(angle)
	return axis if first_slot < second_slot else -axis


func _before_slot_released(slot: int, _entity: Node, handle: int) -> void:
	if _contact_ring_claim_starts[slot] >= 0:
		_release_contact_ring_claim(slot, handle)
	var collision_enemy := _typed_enemies[slot]
	if _direct_collision_active[slot] != 0 and collision_enemy != null and _crowd_topology != null:
		_crowd_grid.remove(handle, collision_enemy.global_position)
		_direct_collision_active_count = maxi(0, _direct_collision_active_count - 1)
	_typed_enemies[slot] = null
	_direct_collision_radii[slot] = 0.0
	_direct_collision_active[slot] = 0
	_clear_direct_collision_bypass(slot)
	_direct_collision_queued[slot] = 0
	_direct_collision_queue_blockers[slot] = EntityHandle.INVALID
	_direct_collision_previous_lane_signs[slot] = 0
	_clear_bulk_slot(slot)
	_crowd_contact_latched[slot] = 0
	_crowd_resolved_directions[slot] = Vector2.ZERO
	_crowd_resolved_speeds[slot] = 1.0
	_crowd_motion_guards[slot] = 0
	_crowd_motion_guard_counts[slot] = 0
	_contact_ring_claim_starts[slot] = -1
	_contact_ring_claim_spans[slot] = 0
	_contact_ring_wait_starts[slot] = -1
	_contact_ring_wait_ranks[slot] = 0
	_contact_ring_attack_armed[slot] = 0
	_contact_ring_reclaim_holds[slot] = 0
	if _critical_by_slot[slot] != 0:
		critical_count = maxi(0, critical_count - 1)
	else:
		regular_count = maxi(0, regular_count - 1)
	_critical_by_slot[slot] = 0
