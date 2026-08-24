extends SceneTree

const CAPACITY := 512
const EPSILON := 0.001

var assertions := 0
var failures := 0
var topology := ArenaTopology.new(Rect2(-900.0, -540.0, 1800.0, 1080.0))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var renderer := ProjectileRenderer.new()
	renderer.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_root().add_child(renderer)
	renderer.configure(CAPACITY)
	renderer.set_debug_snapshots_enabled(true)
	var projectiles: Array[TherapyProjectile] = []
	var handles := PackedInt64Array()

	for index in range(CAPACITY):
		var projectile := TherapyProjectile.new()
		get_root().add_child(projectile)
		projectile.global_position = Vector2(float(index * 7 - 900), float(index % 29) * 13.0 - 180.0)
		if index == 0:
			projectile.configure_hostile(Vector2.RIGHT, 4.0, topology, null, null, TherapyProjectile.HOSTILE_NORMAL, 0.0, 205.0, 1050.0, 44.0, 180.0, 1.5)
		else:
			projectile.configure(null, 18.0, topology, index == 7)
		projectile.rotation = float(index % 17) * 0.17
		var handle := EntityHandle.make(index, 1)
		_assert_true(renderer.register_projectile(projectile, handle, index == 7), "Slot %d registers exactly once" % index)
		if index in [0, 119, 120, 511]:
			var first_state := renderer.render_state(handle)
			_assert_true(bool(first_state.get("hidden", false)), "Slot %d stays hidden before its first published snapshot" % index)
			_assert_true(not projectile.visible, "Slot %d never exposes its Node body at the origin or an old position" % index)
		projectiles.append(projectile)
		handles.append(handle)

	renderer.publish_snapshot()
	renderer.flush_render_state(1.0)
	_assert_equal(renderer.active_count(), CAPACITY, "All 512 gameplay projectiles keep one renderer activation")
	_assert_equal(renderer.batch().multimesh.visible_instance_count, CAPACITY, "The stable batch covers the complete projectile capacity")
	for index in [0, 119, 120, 255, 511]:
		var projectile := projectiles[index]
		var state := renderer.render_state(handles[index])
		_assert_true(not projectile.visible, "Normal projectile %d never duplicates its batch visual" % index)
		_assert_true(bool(state.get("active", false)) and not bool(state.get("detailed", true)), "Normal projectile %d owns its batch slot" % index)
		var transform: Transform2D = state.get("transform", Transform2D())
		_assert_vector(transform.origin, projectile.global_position, "Normal projectile %d renders at the configured position" % index)
	var wide_transform: Transform2D = renderer.render_state(handles[0]).get("transform", Transform2D())
	var standard_transform: Transform2D = renderer.render_state(handles[119]).get("transform", Transform2D())
	_assert_near(wide_transform.x.length(), ProjectileRenderer.PROJECTILE_EXTENT.x, "Wide hostile projectile keeps the standard visual length")
	_assert_near(wide_transform.y.length(), ProjectileRenderer.PROJECTILE_EXTENT.y * 1.5, "Wide hostile projectile expands only its cross-axis by 50 percent")
	_assert_near(standard_transform.y.length(), ProjectileRenderer.PROJECTILE_EXTENT.y, "Adjacent default projectile keeps the standard cross-axis")

	var discovery := projectiles[7]
	var discovery_state := renderer.render_state(handles[7])
	_assert_true(discovery.visible, "Discovery projectile remains a concrete visible tooltip target")
	_assert_true(bool(discovery_state.get("detailed", false)), "Discovery projectile has one stable detail path")
	_assert_true(discovery.get_highlight_body() != null, "Discovery projectile retains visible bounds for tutorial pointers")

	_test_torus_snapshot_snap(renderer, projectiles[2], handles[2])
	_test_angle_interpolation(renderer, projectiles[4], handles[4])
	await _test_pause_freezes_snapshot(renderer, projectiles[3], handles[3])
	_test_generation_safe_reuse(renderer, projectiles[0], handles[0])
	_test_simultaneous_release(renderer, projectiles, handles)
	_test_repeated_pool_reuse(renderer, projectiles[1], handles[1])

	renderer.clear()
	_assert_equal(renderer.active_count(), 0, "Clear releases all projectile visuals")
	_assert_equal(renderer.batch().multimesh.visible_instance_count, 0, "Clear hides the entire batch")
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	renderer.queue_free()
	await process_frame
	if failures == 0:
		print("ALVEOLUS_PROJECTILE_RENDERER_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_PROJECTILE_RENDERER_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)


func _test_torus_snapshot_snap(renderer: ProjectileRenderer, projectile: TherapyProjectile, handle: int) -> void:
	projectile.global_position = Vector2(890.0, 73.0)
	renderer.publish_snapshot()
	renderer.flush_render_state(1.0)
	projectile.global_position = Vector2(-890.0, 73.0)
	renderer.publish_snapshot()
	renderer.flush_render_state(0.5)
	var state := renderer.render_state(handle)
	var transform: Transform2D = state.get("transform", Transform2D())
	_assert_vector(transform.origin, projectile.global_position, "Torus crossing snaps both snapshots instead of interpolating through the arena")


func _test_pause_freezes_snapshot(renderer: ProjectileRenderer, projectile: TherapyProjectile, handle: int) -> void:
	var baseline := Vector2(227.0, -141.0)
	projectile.global_position = baseline
	renderer.publish_snapshot()
	renderer.flush_render_state(1.0)
	var before: Transform2D = renderer.render_state(handle).get("transform", Transform2D())
	paused = true
	# Even if an external caller mutates simulation data, the pausable renderer
	# cannot publish or upload a new command while the run is paused.
	projectile.global_position = Vector2(-611.0, 318.0)
	await process_frame
	await process_frame
	var during: Transform2D = renderer.render_state(handle).get("transform", Transform2D())
	_assert_vector(during.origin, before.origin, "Pause freezes projectile render snapshots across render frames")
	projectile.global_position = baseline
	paused = false
	renderer.publish_snapshot()
	renderer.flush_render_state(1.0)


func _test_angle_interpolation(renderer: ProjectileRenderer, projectile: TherapyProjectile, handle: int) -> void:
	projectile.rotation = 0.0
	renderer.publish_snapshot()
	renderer.flush_render_state(1.0)
	projectile.rotation = PI * 0.5
	renderer.publish_snapshot()
	renderer.flush_render_state(0.5)
	var transform: Transform2D = renderer.render_state(handle).get("transform", Transform2D())
	var actual_angle := transform.x.normalized().angle()
	var expected_angle := lerp_angle(0.0, PI * 0.5, 0.5) + ProjectileRenderer.QUAD_TEXTURE_ROTATION
	_assert_true(absf(angle_difference(actual_angle, expected_angle)) <= EPSILON, "Homing rotation uses previous/current angle interpolation between physics ticks")


func _test_generation_safe_reuse(renderer: ProjectileRenderer, projectile: TherapyProjectile, old_handle: int) -> void:
	var old_slot := EntityHandle.slot(old_handle)
	_assert_true(renderer.release_projectile(projectile, old_handle), "Release synchronously accepts the current generation")
	var released_state := renderer.render_state(old_handle)
	_assert_true(bool(released_state.get("hidden", false)), "Release clears the old render command before pool reuse")
	projectile.recycle()
	_assert_near(projectile.hostile_width_multiplier, 1.0, "Pool reuse clears hostile projectile width")
	projectile.global_position = Vector2(731.0, -403.0)
	projectile.configure(null, 24.0, topology)
	projectile.rotation = 0.73
	var replacement_handle := EntityHandle.make(old_slot, EntityHandle.generation(old_handle) + 1)
	_assert_true(renderer.register_projectile(projectile, replacement_handle), "Recycled node binds to the next handle generation")
	_assert_true(not renderer.release_projectile(projectile, old_handle), "Stale generation cannot clear its replacement")
	renderer.publish_snapshot()
	renderer.flush_render_state(1.0)
	var replacement_state := renderer.render_state(replacement_handle)
	var transform: Transform2D = replacement_state.get("transform", Transform2D())
	_assert_vector(transform.origin, projectile.global_position, "Replacement never renders at the old activation position")


func _test_simultaneous_release(renderer: ProjectileRenderer, projectiles: Array[TherapyProjectile], handles: PackedInt64Array) -> void:
	var released := 0
	for index in range(12, 112):
		if renderer.release_projectile(projectiles[index], handles[index]):
			released += 1
	_assert_equal(released, 100, "100 simultaneous releases are processed exactly once")
	_assert_equal(renderer.active_count(), CAPACITY - 100, "Dense projectile records contain no skipped release")
	for index in range(12, 112):
		_assert_true(bool(renderer.render_state(handles[index]).get("hidden", false)), "Released slot %d is synchronously hidden" % index)


func _test_repeated_pool_reuse(renderer: ProjectileRenderer, projectile: TherapyProjectile, initial_handle: int) -> void:
	var slot := EntityHandle.slot(initial_handle)
	var current_handle := initial_handle
	for cycle in range(500):
		_assert_true(renderer.release_projectile(projectile, current_handle), "Reuse cycle %d releases the current generation" % cycle)
		projectile.recycle()
		_assert_near(projectile.speed, TherapyProjectile.DEFAULT_SPEED, "Reuse cycle %d resets the pooled projectile speed" % cycle)
		projectile.global_position = Vector2(float(cycle % 37) * 21.0 - 350.0, float(cycle % 23) * 17.0 - 180.0)
		var configured_speed := 312.0 if cycle % 2 == 0 else TherapyProjectile.DEFAULT_SPEED
		projectile.configure(null, 18.0, topology, false, &"therapy", EntityHandle.INVALID, Callable(), configured_speed)
		_assert_near(projectile.speed, configured_speed, "Reuse cycle %d applies only its configured projectile speed" % cycle)
		projectile.rotation = float(cycle % 31) * 0.11
		current_handle = EntityHandle.make(slot, EntityHandle.generation(current_handle) + 1)
		_assert_true(renderer.register_projectile(projectile, current_handle), "Reuse cycle %d registers the replacement" % cycle)
		renderer.publish_snapshot()
		renderer.flush_render_state(1.0)
		var state := renderer.render_state(current_handle)
		var transform: Transform2D = state.get("transform", Transform2D())
		_assert_vector(transform.origin, projectile.global_position, "Reuse cycle %d publishes only the current position" % cycle)


func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (actual=%s expected=%s)" % [message, actual, expected])


func _assert_vector(actual: Vector2, expected: Vector2, message: String) -> void:
	_assert_true(actual.distance_to(expected) <= EPSILON, "%s (actual=%s expected=%s)" % [message, actual, expected])


func _assert_near(actual: float, expected: float, message: String) -> void:
	_assert_true(absf(actual - expected) <= EPSILON, "%s (actual=%.3f expected=%.3f)" % [message, actual, expected])
