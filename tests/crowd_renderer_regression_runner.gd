extends SceneTree

## Stable-slot and consecutive-frame contracts for CrowdRenderer. The paths at
## 0, 119, 120 and 600 entities are deliberate regressions for the former
## threshold renderer that could expose stale MultiMesh slots for one frame.

const EXPECTED_REGULAR_EXTENT := 18.0 * 2.35
const ENEMY_CAPACITY := 640
const PICKUP_CAPACITY := 360
const MULTIMESH_STRIDE_2D_COLOR := 12
const EPSILON := 0.001

var assertions := 0
var failures := 0
var topology := ArenaTopology.new(Rect2(-900.0, -540.0, 1800.0, 1080.0))
var regular_definition: EnemyDefinition

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	regular_definition = ContentCatalog.enemy_definitions()[&"pneumococcus"]
	var renderer := CrowdRenderer.new()
	renderer.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_root().add_child(renderer)
	renderer.configure(ENEMY_CAPACITY, PICKUP_CAPACITY)
	# RenderingServer commands are deferred in headless mode. The renderer's
	# opt-in CPU mirror exposes the exact commands issued to each stable slot.
	renderer.set_debug_snapshots_enabled(true)
	var enemies: Array[InfectionEnemy] = []
	var pickups: Array[AnalysisPickup] = []

	_test_zero_path(renderer, enemies, pickups)
	_test_entity_owned_cluster_materialization_and_relocation()
	_test_batched_health_bar_lifecycle()
	_test_shooting_lock_status_lifecycle()
	_append_enemies(enemies, 119)
	_test_count_path(renderer, enemies, pickups, 119)
	var slots_at_119 := _slot_map(renderer, enemies)
	_append_enemies(enemies, 1)
	_test_count_path(renderer, enemies, pickups, 120)
	_assert_stable_slots(renderer, enemies.slice(0, 119), slots_at_119, "119 > 120 keeps every existing slot stable")
	_test_threshold_crossing_churn(renderer, enemies, pickups)
	_append_enemies(enemies, 480)
	_test_count_path(renderer, enemies, pickups, 600)
	_test_spawn_alpha_and_stale_generation(renderer, enemies, pickups)
	_test_simultaneous_release_and_reuse(renderer, enemies, pickups)
	await _test_pause_freezes_render_snapshot(renderer, enemies, pickups)
	_test_torus_teleport_resets_visual_motion(renderer, enemies, pickups)
	_test_pickup_slot_lifecycle(renderer, enemies, pickups)
	_test_unknown_visual_fallback(renderer)
	_test_capacity_fallback(renderer, enemies, pickups)

	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	for pickup in pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	renderer.queue_free()
	await process_frame
	if failures == 0:
		print("ALVEOLUS_CROWD_REGRESSION_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_CROWD_REGRESSION_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)

func _test_zero_path(renderer: CrowdRenderer, enemies: Array[InfectionEnemy], pickups: Array[AnalysisPickup]) -> void:
	renderer.sync(enemies, pickups)
	_assert_true(not renderer.is_batching(), "0 entities produce no active batch representation")
	_assert_equal(renderer.active_telegraph_count(), 0, "0 entities produce no spawn telegraphs")


## Production keeps debug snapshots disabled and uploads the visual endpoints
## owned by InfectionEnemy directly. Reproduce that exact path for the cluster
## which previously became opaque in the materialization callback and was then
## overwritten by its still-transparent previous endpoint on the next flush.
func _test_entity_owned_cluster_materialization_and_relocation() -> void:
	var cluster_definition: EnemyDefinition = ContentCatalog.enemy_definitions()[&"bacterial_cluster"]
	var renderer := CrowdRenderer.new()
	get_root().add_child(renderer)
	renderer.configure(4, 1)

	var cluster := InfectionEnemy.new()
	get_root().add_child(cluster)
	var spawn_position := Vector2(-241.0, 137.0)
	cluster.global_position = spawn_position
	cluster.configure(cluster_definition, null, topology)
	var record := renderer.register_enemy(cluster)
	var slot := int(record.get("slot", CrowdRenderer.INVALID_SLOT))
	var batch := renderer.batch_for_visual_id(cluster_definition.visual_id)
	_assert_true(slot >= 0 and batch != null, "Bacterial cluster leases the production MultiMesh path")
	_assert_true(batch.multimesh.custom_aabb == CrowdRenderer.BATCH_CUSTOM_AABB, "Enemy archetype batch owns the explicit arena-wide culling box")

	cluster.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	_assert_vector(cluster.visual_previous_size, cluster.visual_current_size, "Materialization atomically collapses cluster size endpoints")
	_assert_near(cluster.visual_previous_color.a, 1.0, "Materialization atomically makes the previous cluster endpoint opaque")
	_assert_near(cluster.visual_current_color.a, 1.0, "Materialization makes the current cluster endpoint opaque")
	_assert_cluster_multimesh_state(batch, slot, spawn_position, cluster.visual_extent(), "Immediate materialization")

	# A normal render-rate flush at fraction zero is the critical regression:
	# before the fix it restored the transparent/undersized pre-spawn endpoint.
	renderer.publish_snapshot()
	renderer.flush_render_state(0.0)
	_assert_cluster_multimesh_state(batch, slot, spawn_position, cluster.visual_extent(), "First runtime flush after materialization")

	var relocated_position := Vector2(318.0, -204.0)
	_assert_true(cluster.relocate_preserving_state(relocated_position), "Materialized cluster accepts an eligible offscreen relocation")
	renderer.flush_render_state(0.0)
	_assert_cluster_multimesh_state(batch, slot, relocated_position, cluster.visual_extent(), "Relocation flush")

	cluster.step_fixed(1.0 / 60.0)
	renderer.publish_snapshot()
	renderer.flush_render_state(0.0)
	_assert_cluster_multimesh_state(batch, slot, relocated_position, cluster.visual_extent(), "Normal runtime flush after relocation")

	renderer.release_enemy(cluster, cluster.activation_generation)
	cluster.queue_free()
	renderer.queue_free()


func _assert_cluster_multimesh_state(
	batch: MultiMeshInstance2D,
	slot: int,
	expected_position: Vector2,
	expected_extent: float,
	context: String
) -> void:
	# CrowdRenderer uploads complete packed buffers. Godot's headless
	# Compatibility path does not synchronously populate the separate
	# get_instance_* accessors after set_buffer(), so those accessors report an
	# identity transform even though the production buffer contains the draw
	# command. Decode the actual uploaded slot instead of enabling the renderer's
	# optional debug mirror.
	var buffer := batch.multimesh.get_buffer()
	var offset := slot * MULTIMESH_STRIDE_2D_COLOR
	_assert_true(buffer.size() >= offset + MULTIMESH_STRIDE_2D_COLOR, "%s uploads a complete cluster slot" % context)
	if buffer.size() < offset + MULTIMESH_STRIDE_2D_COLOR:
		return
	var transform := Transform2D(
		Vector2(buffer[offset], buffer[offset + 4]),
		Vector2(buffer[offset + 1], buffer[offset + 5]),
		Vector2(buffer[offset + 3], buffer[offset + 7])
	)
	var color := Color(buffer[offset + 8], buffer[offset + 9], buffer[offset + 10], buffer[offset + 11])
	_assert_vector(transform.origin, expected_position, "%s preserves the cluster position" % context)
	_assert_near(transform.x.length(), expected_extent, "%s preserves the cluster width" % context)
	_assert_near(transform.y.length(), expected_extent, "%s preserves the cluster height" % context)
	_assert_near(color.a, 1.0, "%s keeps the cluster visible" % context)

func _test_batched_health_bar_lifecycle() -> void:
	var renderer := CrowdRenderer.new()
	renderer.position = Vector2(37.0, -23.0)
	get_root().add_child(renderer)
	renderer.configure(4, 1)

	var batched := _make_enemy(701)
	var previous_position := Vector2(-172.0, 91.0)
	var current_position := Vector2(244.0, -57.0)
	batched.global_position = current_position
	batched.visual_previous_position = previous_position
	batched.visual_current_position = current_position
	batched.visual_motion_initialized = true
	var batched_record := renderer.register_enemy(batched)
	_assert_true(not bool(batched_record.get("detailed", true)), "Ordinary damaged enemy remains owned by the batch renderer")
	_assert_equal(renderer.active_enemy_health_bar_count(), 0, "Full-health batched enemy has no redundant health bar")

	batched.take_damage(batched.max_health * 0.25, &"health_bar_regression")
	_assert_equal(renderer.active_enemy_health_bar_count(), 1, "Damaging a batched enemy immediately exposes one renderer-owned health bar")
	_assert_near(renderer.enemy_health_bar_fraction(batched), 0.75, "Batched health bar reports the authoritative remaining-health fraction")
	var interpolation_fraction := 0.25
	var actual_rect := renderer.enemy_health_bar_rect(batched, interpolation_fraction)
	var expected_center := renderer.to_local(previous_position.lerp(current_position, interpolation_fraction))
	var expected_width := maxf(24.0, regular_definition.radius * 2.0)
	var expected_rect := Rect2(
		expected_center + Vector2(-expected_width * 0.5, -regular_definition.radius - 17.0),
		Vector2(expected_width, 6.0)
	)
	_assert_rect(actual_rect, expected_rect, "Batched health bar follows the interpolated enemy position in renderer-local space")
	_assert_true(actual_rect.size.x > 0.0 and actual_rect.size.y > 0.0 and actual_rect.position.is_finite(), "Batched health bar publishes a finite, drawable rectangle")

	var detailed := _make_enemy(702)
	detailed.global_position = Vector2(83.0, 136.0)
	detailed.reset_visual_motion()
	var detailed_record := renderer.register_enemy(detailed, true)
	_assert_true(bool(detailed_record.get("detailed", false)) and detailed.visible, "Forced-detailed enemy keeps its node-owned visual representation")
	detailed.take_damage(detailed.max_health * 0.25, &"health_bar_regression")
	_assert_equal(renderer.active_enemy_health_bar_count(), 1, "Detailed enemy does not duplicate its node-owned health bar in the batch renderer")

	var old_generation := batched.activation_generation
	var old_slot := renderer.enemy_slot_for(batched)
	renderer.release_enemy(batched, old_generation)
	_assert_equal(renderer.active_enemy_health_bar_count(), 0, "Releasing a damaged batched enemy synchronously removes its health bar")
	batched.recycle()
	batched.global_position = Vector2(-311.0, -109.0)
	batched.configure(regular_definition, null, topology)
	batched.spawn_timer = 0.0
	batched.reset_visual_motion()
	var replacement := renderer.register_enemy(batched)
	var new_generation := batched.activation_generation
	_assert_equal(renderer.enemy_slot_for(batched), old_slot, "Recycled enemy can safely reuse the released batch slot")
	_assert_equal(renderer.active_enemy_health_bar_count(), 0, "Recycled full-health generation never inherits the previous health bar")
	batched.take_damage(batched.max_health * 0.5, &"health_bar_regression")
	_assert_equal(renderer.active_enemy_health_bar_count(), 1, "New pooled generation owns exactly one new health bar after damage")
	_assert_near(renderer.enemy_health_bar_fraction(batched), 0.5, "Recycled generation reports its own health fraction")
	renderer.release_enemy(batched, old_generation)
	_assert_equal(renderer.enemy_slot_for(batched), int(replacement.get("slot", CrowdRenderer.INVALID_SLOT)), "Stale release generation cannot clear the recycled batch owner")
	_assert_equal(renderer.active_enemy_health_bar_count(), 1, "Stale release generation cannot remove the recycled owner's health bar")
	renderer.release_enemy(batched, new_generation)
	_assert_equal(renderer.active_enemy_health_bar_count(), 0, "Current release generation removes the recycled health bar")

	renderer.release_enemy(detailed, detailed.activation_generation)
	batched.queue_free()
	detailed.queue_free()
	renderer.queue_free()


func _test_shooting_lock_status_lifecycle() -> void:
	var renderer := CrowdRenderer.new()
	get_root().add_child(renderer)
	renderer.configure(2, 1)
	var enemy := _make_enemy(703)
	enemy.configure_projectile_modifiers(1.0, 1.0, 1.0, 10.0, true)
	renderer.register_enemy(enemy)
	_assert_equal(renderer.active_enemy_shooting_lock_count(), 0, "Ein normal schießender Gegner besitzt kein Verwirrtheitssymbol")
	enemy.apply_knockback(Vector2.RIGHT, 8.0, 0.1, 1.0)
	enemy.apply_defense_burst_shooting_lock()
	_assert_true(enemy.is_stunned() and enemy.projectiles_suppressed(), "Stoß setzt Stun und Schusssperre gleichzeitig")
	_assert_equal(renderer.active_enemy_shooting_lock_count(), 1, "Die Schusssperre registriert genau ein kleines Verwirrtheitssymbol")
	enemy.step_fixed(10.01)
	_assert_true(not enemy.projectiles_suppressed(), "Die zeitliche Schusssperre endet nach zehn Sekunden auch im Gegnerzustand")
	_assert_equal(renderer.active_enemy_shooting_lock_count(), 0, "Das Verwirrtheitssymbol endet synchron mit der zeitlichen Schusssperre")
	renderer.release_enemy(enemy, enemy.activation_generation)
	enemy.queue_free()
	var permanent_enemy := _make_enemy(704)
	permanent_enemy.configure_projectile_modifiers(1.0, 1.0, 1.0, -1.0, true)
	renderer.register_enemy(permanent_enemy)
	permanent_enemy.apply_defense_burst_shooting_lock()
	_assert_equal(renderer.active_enemy_shooting_lock_count(), 1, "Eine explizite permanente Sonderregel hält genau ein Verwirrtheitssymbol aktiv")
	permanent_enemy.step_fixed(30.0)
	_assert_equal(renderer.active_enemy_shooting_lock_count(), 1, "Das Symbol einer explizit permanenten Schusssperre läuft nicht zeitlich aus")
	renderer.release_enemy(permanent_enemy, permanent_enemy.activation_generation)
	_assert_equal(renderer.active_enemy_shooting_lock_count(), 0, "Entity-Freigabe entfernt das explizit permanente Verwirrtheitssymbol synchron")
	permanent_enemy.recycle()
	_assert_true(not permanent_enemy.projectiles_suppressed(), "Pool-Recycling übernimmt auch keine explizit permanente Schusssperre")
	permanent_enemy.queue_free()
	renderer.queue_free()

func _test_count_path(renderer: CrowdRenderer, enemies: Array[InfectionEnemy], pickups: Array[AnalysisPickup], expected_count: int) -> void:
	renderer.sync(enemies, pickups)
	renderer.flush_render_state(1.0)
	var batch := renderer.batch_for_visual_id(regular_definition.visual_id)
	_assert_true(batch != null, "%d path creates the expected visual batch" % expected_count)
	_assert_true(batch.multimesh.custom_aabb == CrowdRenderer.BATCH_CUSTOM_AABB, "%d path cannot be culled by the default local batch box" % expected_count)
	_assert_equal(batch.multimesh.visible_instance_count, expected_count, "%d path exposes exactly the highest owned slot range" % expected_count)
	_assert_equal(_unique_slot_count(renderer, enemies), expected_count, "%d path owns one unique slot per enemy" % expected_count)
	_assert_true(renderer.is_batching(), "%d path stays on the stable batch representation" % expected_count)
	for index in _sample_indices(expected_count):
		var enemy: InfectionEnemy = enemies[index]
		var slot := renderer.enemy_slot_for(enemy)
		var state := renderer.enemy_render_state(enemy)
		var transform: Transform2D = state.get("transform", Transform2D())
		_assert_true(bool(state.get("active", false)) and not bool(state.get("hidden", true)), "%d path publishes an active visible render command" % expected_count)
		_assert_vector(transform.origin, enemy.visual_current_position, "%d path slot %d uses the authoritative position" % [expected_count, slot])
		_assert_true(not enemy.visible, "%d path never duplicates the detailed enemy" % expected_count)
	if expected_count > 0:
		var state := renderer.enemy_render_state(enemies[0])
		var transform: Transform2D = state.get("transform", Transform2D())
		_assert_near(transform.x.length(), EXPECTED_REGULAR_EXTENT, "%d path preserves detailed sprite width" % expected_count)
		_assert_near(transform.y.length(), EXPECTED_REGULAR_EXTENT, "%d path preserves detailed sprite height" % expected_count)
		_assert_true(transform.x.x < 0.0 and transform.y.y < 0.0, "%d path preserves upright QuadMesh orientation" % expected_count)

func _test_threshold_crossing_churn(renderer: CrowdRenderer, enemies: Array[InfectionEnemy], pickups: Array[AnalysisPickup]) -> void:
	var crossing: InfectionEnemy = enemies.back()
	var old_generation := crossing.activation_generation
	var old_slot := renderer.enemy_slot_for(crossing)
	renderer.release_enemy(crossing, old_generation)
	enemies.erase(crossing)
	crossing.recycle()
	_assert_render_state_hidden(renderer.enemy_render_state(crossing), old_slot, "120 > 119 clears the former threshold slot synchronously")
	_test_count_path(renderer, enemies, pickups, 119)

	var replacement_position := Vector2(641.0, -377.0)
	crossing.global_position = replacement_position
	crossing.configure(regular_definition, null, topology)
	crossing.spawn_timer = 0.0
	crossing.reset_visual_motion()
	enemies.append(crossing)
	var replacement := renderer.register_enemy(crossing)
	_assert_equal(int(replacement.get("slot", CrowdRenderer.INVALID_SLOT)), old_slot, "119 > 120 reuses the cleared boundary slot")
	renderer.release_enemy(crossing, old_generation)
	_assert_equal(renderer.enemy_slot_for(crossing), old_slot, "Old threshold generation cannot clear the replacement")
	_test_count_path(renderer, enemies, pickups, 120)
	var state := renderer.enemy_render_state(crossing)
	var transform: Transform2D = state.get("transform", Transform2D())
	_assert_vector(transform.origin, replacement_position, "Boundary-crossing replacement never renders at its previous position")

func _test_spawn_alpha_and_stale_generation(renderer: CrowdRenderer, enemies: Array[InfectionEnemy], pickups: Array[AnalysisPickup]) -> void:
	var recycled: InfectionEnemy = enemies[311]
	var old_position := recycled.global_position
	var old_generation := recycled.activation_generation
	var released_slot := renderer.enemy_slot_for(recycled)
	renderer.release_enemy(recycled, old_generation)
	enemies.erase(recycled)
	recycled.recycle()
	_assert_render_state_hidden(renderer.enemy_render_state(recycled), released_slot, "Release clears transform and alpha before pool reuse")

	var new_position := Vector2(-733.0, 417.0)
	recycled.global_position = new_position
	recycled.configure(regular_definition, null, topology)
	enemies.append(recycled)
	var record := renderer.register_enemy(recycled)
	var reused_slot := int(record.get("slot", CrowdRenderer.INVALID_SLOT))
	_assert_equal(reused_slot, released_slot, "Pool reactivation can safely reuse the released visual slot")
	_assert_render_state_hidden(renderer.enemy_render_state(recycled), reused_slot, "New owner stays hidden until its first render flush")
	renderer.release_enemy(recycled, old_generation)
	_assert_equal(renderer.enemy_slot_for(recycled), reused_slot, "Stale generation cannot release the new activation")
	renderer.sync(enemies, pickups)
	renderer.flush_render_state(1.0)
	var spawn_state := renderer.enemy_render_state(recycled)
	var spawn_transform: Transform2D = spawn_state.get("transform", Transform2D())
	var spawn_color: Color = spawn_state.get("color", Color.TRANSPARENT)
	_assert_true(bool(spawn_state.get("active", false)) and not bool(spawn_state.get("hidden", true)), "First flush atomically activates the new pooled owner")
	_assert_vector(spawn_transform.origin, new_position, "First flushed frame uses the new spawn position")
	_assert_true(not spawn_transform.origin.is_equal_approx(old_position), "First flushed frame never exposes the pooled position")
	_assert_near(spawn_color.a, 0.0, "Enemy body is transparent during the telegraph")
	_assert_equal(renderer.active_telegraph_count(), 1, "Renderer owns exactly one telegraph for the materializing enemy")
	recycled.step_fixed(InfectionEnemy.SPAWN_TELEGRAPH_SECONDS + 0.075)
	renderer.publish_snapshot()
	renderer.flush_render_state(1.0)
	var fade_state := renderer.enemy_render_state(recycled)
	var fade_color: Color = fade_state.get("color", Color.TRANSPARENT)
	var fade_alpha := fade_color.a
	_assert_true(fade_alpha > 0.0 and fade_alpha < 1.0, "Body fades only during the materialization window")
	recycled.step_fixed(InfectionEnemy.SPAWN_MATERIALIZE_SECONDS)
	var immediate_materialized_state := renderer.enemy_render_state(recycled)
	var immediate_materialized_transform: Transform2D = immediate_materialized_state.get("transform", Transform2D())
	var immediate_materialized_color: Color = immediate_materialized_state.get("color", Color.TRANSPARENT)
	_assert_true(
		bool(immediate_materialized_state.get("active", false))
		and not bool(immediate_materialized_state.get("hidden", true)),
		"Materialization activates the leased slot without waiting for another render flush"
	)
	_assert_vector(immediate_materialized_transform.origin, new_position, "Immediate materialization keeps the pooled owner's current position")
	_assert_near(immediate_materialized_color.a, 1.0, "Immediate materialization removes the transient blank sprite frame")
	renderer.publish_snapshot()
	renderer.flush_render_state(1.0)
	var materialized_color: Color = renderer.enemy_render_state(recycled).get("color", Color.TRANSPARENT)
	_assert_near(materialized_color.a, 1.0, "Materialized body ends fully opaque")

func _test_simultaneous_release_and_reuse(renderer: CrowdRenderer, enemies: Array[InfectionEnemy], pickups: Array[AnalysisPickup]) -> void:
	var released: Array[InfectionEnemy] = []
	var released_slots := {}
	for index in range(64):
		var enemy: InfectionEnemy = enemies[40 + index]
		var slot := renderer.enemy_slot_for(enemy)
		released.append(enemy)
		released_slots[slot] = true
		renderer.release_enemy(enemy, enemy.activation_generation)
		enemies.erase(enemy)
		enemy.recycle()
	for enemy in released:
		var released_state := renderer.enemy_render_state(enemy)
		var released_slot := int(released_state.get("slot", CrowdRenderer.INVALID_SLOT))
		_assert_render_state_hidden(released_state, released_slot, "Simultaneous release clears slot %d synchronously" % released_slot)
	var newly_owned := {}
	for index in range(released.size()):
		var enemy := released[index]
		var new_position := topology.wrap_position(Vector2(-820.0 + float(index) * 29.0, 490.0 - float(index % 7) * 73.0))
		enemy.global_position = new_position
		enemy.configure(regular_definition, null, topology)
		enemies.append(enemy)
		var record := renderer.register_enemy(enemy)
		var slot := int(record.get("slot", CrowdRenderer.INVALID_SLOT))
		_assert_true(released_slots.has(slot), "Simultaneous reuse only leases a released slot")
		_assert_true(not newly_owned.has(slot), "Simultaneous reuse never leases a slot twice")
		newly_owned[slot] = true
		_assert_render_state_hidden(renderer.enemy_render_state(enemy), slot, "Reused slot is cleared before the new owner is flushed")
	renderer.sync(enemies, pickups)
	renderer.flush_render_state(1.0)
	for enemy in released:
		var state := renderer.enemy_render_state(enemy)
		var transform: Transform2D = state.get("transform", Transform2D())
		_assert_true(bool(state.get("active", false)) and not bool(state.get("hidden", true)), "Simultaneous reuse activates every new owner exactly once")
		_assert_vector(transform.origin, enemy.global_position, "Simultaneous reuse flushes only the new owner transform")

func _test_pause_freezes_render_snapshot(renderer: CrowdRenderer, enemies: Array[InfectionEnemy], pickups: Array[AnalysisPickup]) -> void:
	var enemy: InfectionEnemy = enemies[0]
	renderer.flush_render_state(0.5)
	var before_state := renderer.enemy_render_state(enemy)
	var before: Transform2D = before_state.get("transform", Transform2D())
	var spawn_before := enemy.spawn_timer
	paused = true
	for _frame in range(8):
		await process_frame
	var after_state := renderer.enemy_render_state(enemy)
	var after: Transform2D = after_state.get("transform", Transform2D())
	_assert_transform(after, before, "Pause freezes the stable visual slot across render frames")
	_assert_near(enemy.spawn_timer, spawn_before, "Pause freezes the enemy lifecycle represented by the slot")
	paused = false

func _test_torus_teleport_resets_visual_motion(renderer: CrowdRenderer, enemies: Array[InfectionEnemy], pickups: Array[AnalysisPickup]) -> void:
	var enemy: InfectionEnemy = enemies[1]
	enemy.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	enemy.global_position = Vector2(topology.bounds.end.x - 4.0, 11.0)
	enemy.reset_visual_motion()
	enemy.apply_displacement(Vector2(12.0, 0.0))
	renderer.mark_enemy_teleported(enemy)
	renderer.sync(enemies, pickups)
	renderer.flush_render_state(0.5)
	var state := renderer.enemy_render_state(enemy)
	var transform: Transform2D = state.get("transform", Transform2D())
	_assert_vector(transform.origin, enemy.global_position, "Torus teleport never interpolates across the full arena")
	_assert_true(topology.bounds.has_point(enemy.global_position), "Torus teleport remains inside the arena")

func _test_pickup_slot_lifecycle(renderer: CrowdRenderer, enemies: Array[InfectionEnemy], pickups: Array[AnalysisPickup]) -> void:
	var pickup := AnalysisPickup.new()
	get_root().add_child(pickup)
	pickup.global_position = Vector2(223.0, -147.0)
	# Keep this lifecycle case on the batched visual path. Guided tutorial
	# pickups intentionally use the detailed renderer and therefore own no slot.
	pickup.configure(null, 7, topology, 0.4, false, 276.0)
	_assert_near(pickup.guided_speed, 276.0, "Pickup activation applies its per-instance guided speed")
	pickups.append(pickup)
	var first := renderer.register_pickup(pickup)
	var first_slot := int(first.get("slot", CrowdRenderer.INVALID_SLOT))
	renderer.flush_render_state(1.0)
	var first_state := renderer.pickup_render_state(pickup)
	var first_transform: Transform2D = first_state.get("transform", Transform2D())
	_assert_true(bool(first_state.get("active", false)) and not bool(first_state.get("hidden", true)), "Pickup flush atomically activates its stable slot")
	_assert_vector(first_transform.origin, pickup.global_position, "Pickup slot uses the active pickup position")
	renderer.release_pickup(pickup)
	_assert_render_state_hidden(renderer.pickup_render_state(pickup), first_slot, "Pickup release clears its slot synchronously")
	pickups.erase(pickup)
	pickup.recycle()
	_assert_near(pickup.guided_speed, AnalysisPickup.DEFAULT_GUIDED_SPEED, "Pickup recycle restores the default guided speed")
	pickup.global_position = Vector2(-419.0, 302.0)
	pickup.configure(null, 3, topology, 1.2)
	_assert_near(pickup.guided_speed, AnalysisPickup.DEFAULT_GUIDED_SPEED, "Reused pickup without an override keeps the default guided speed")
	pickups.append(pickup)
	var second := renderer.register_pickup(pickup)
	_assert_equal(int(second.get("slot", CrowdRenderer.INVALID_SLOT)), first_slot, "Pickup pool reuse safely reuses its cleared slot")
	_assert_render_state_hidden(renderer.pickup_render_state(pickup), first_slot, "Reused pickup stays hidden until its first flush")
	renderer.sync(enemies, pickups)
	renderer.flush_render_state(1.0)
	var second_state := renderer.pickup_render_state(pickup)
	var second_transform: Transform2D = second_state.get("transform", Transform2D())
	_assert_vector(second_transform.origin, pickup.global_position, "Reused pickup slot never exposes the old position")

func _test_unknown_visual_fallback(renderer: CrowdRenderer) -> void:
	var definition := EnemyDefinition.create(
		&"unknown_test_enemy", "Unknown test enemy", 10.0, 0.0, 0.0, 0, 18.0, Color.MAGENTA,
		false, &"pneumococcus", &"missing_visual"
	)
	var enemy := InfectionEnemy.new()
	get_root().add_child(enemy)
	enemy.global_position = Vector2(371.0, -218.0)
	enemy.configure(definition, null, topology)
	var record := renderer.register_enemy(enemy)
	_assert_true(bool(record.get("detailed", false)), "Unknown visual_id uses the explicit detailed fallback")
	_assert_equal(renderer.enemy_slot_for(enemy), CrowdRenderer.INVALID_SLOT, "Unknown visual_id never leases a batch slot")
	_assert_true(enemy.visible, "Unknown visual_id remains represented by the safe detailed shape")
	_assert_true(enemy.visual_texture == null, "Unknown visual_id cannot inherit the analysis-pickup texture")
	_assert_true(renderer.batch_for_visual_id(&"missing_visual") == null, "Unknown visual_id never creates a false MultiMesh batch")
	renderer.release_enemy(enemy, enemy.activation_generation)
	enemy.queue_free()

func _test_capacity_fallback(renderer: CrowdRenderer, enemies: Array[InfectionEnemy], pickups: Array[AnalysisPickup]) -> void:
	while enemies.size() < ENEMY_CAPACITY:
		_append_enemies(enemies, 1)
	renderer.sync(enemies, pickups)
	var overflow := _make_enemy(ENEMY_CAPACITY)
	enemies.append(overflow)
	var record := renderer.register_enemy(overflow)
	_assert_true(bool(record.get("detailed", false)), "Enemy 641 uses a safe detailed fallback instead of an invalid slot")
	_assert_equal(renderer.enemy_slot_for(overflow), CrowdRenderer.INVALID_SLOT, "Enemy 641 never aliases an owned batch slot")
	_assert_true(overflow.visible, "Capacity fallback stays visibly represented")
	var batch := renderer.batch_for_visual_id(regular_definition.visual_id)
	_assert_equal(batch.multimesh.visible_instance_count, ENEMY_CAPACITY, "Batch capacity remains bounded at 640")

func _append_enemies(enemies: Array[InfectionEnemy], count: int) -> void:
	var offset := enemies.size()
	for index in range(count):
		enemies.append(_make_enemy(offset + index))

func _make_enemy(index: int) -> InfectionEnemy:
	var enemy := InfectionEnemy.new()
	get_root().add_child(enemy)
	var angle := TAU * float(index % 600) / 600.0
	var ring := 180.0 + float(index % 11) * 51.0
	enemy.global_position = topology.wrap_position(Vector2.from_angle(angle) * ring)
	enemy.configure(regular_definition, null, topology)
	enemy.spawn_timer = 0.0
	enemy.reset_visual_motion()
	return enemy

func _slot_map(renderer: CrowdRenderer, enemies: Array[InfectionEnemy]) -> Dictionary:
	var result := {}
	for enemy in enemies:
		result[enemy.get_instance_id()] = renderer.enemy_slot_for(enemy)
	return result

func _assert_stable_slots(renderer: CrowdRenderer, enemies: Array[InfectionEnemy], expected: Dictionary, message: String) -> void:
	for enemy in enemies:
		_assert_equal(renderer.enemy_slot_for(enemy), int(expected.get(enemy.get_instance_id(), CrowdRenderer.INVALID_SLOT)), message)

func _unique_slot_count(renderer: CrowdRenderer, enemies: Array[InfectionEnemy]) -> int:
	var slots := {}
	for enemy in enemies:
		var slot := renderer.enemy_slot_for(enemy)
		if slot >= 0:
			slots[slot] = true
	return slots.size()

func _sample_indices(count: int) -> Array[int]:
	var result: Array[int] = [0]
	for candidate in [count / 2, count - 1]:
		var index := int(candidate)
		if index >= 0 and index < count and not result.has(index):
			result.append(index)
	return result

func _assert_render_state_hidden(state: Dictionary, slot: int, message: String) -> void:
	var transform: Transform2D = state.get("transform", Transform2D())
	var color: Color = state.get("color", Color.TRANSPARENT)
	_assert_true(
		not bool(state.get("active", true))
		and bool(state.get("hidden", false))
		and int(state.get("slot", CrowdRenderer.INVALID_SLOT)) == slot
		and transform.x.length() <= EPSILON
		and transform.y.length() <= EPSILON
		and color.a <= EPSILON,
		message
	)

func _assert_transform(actual: Transform2D, expected: Transform2D, message: String) -> void:
	_assert_true(actual.origin.distance_to(expected.origin) <= EPSILON and actual.x.distance_to(expected.x) <= EPSILON and actual.y.distance_to(expected.y) <= EPSILON, message)

func _assert_vector(actual: Vector2, expected: Vector2, message: String) -> void:
	_assert_true(actual.distance_to(expected) <= EPSILON, "%s (%s != %s)" % [message, actual, expected])

func _assert_rect(actual: Rect2, expected: Rect2, message: String) -> void:
	_assert_true(
		actual.position.distance_to(expected.position) <= EPSILON
		and actual.size.distance_to(expected.size) <= EPSILON,
		"%s (%s != %s)" % [message, actual, expected]
	)

func _assert_near(actual: float, expected: float, message: String) -> void:
	_assert_true(absf(actual - expected) <= EPSILON, "%s (%.4f != %.4f)" % [message, actual, expected])

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (%s != %s)" % [message, str(actual), str(expected)])

func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)
