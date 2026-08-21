extends SceneTree

const ARENA_BOUNDS := Rect2(-1200.0, -675.0, 2400.0, 1350.0)
const EXPECTED_SIZE := Vector2(2400.0, 1350.0)
const LARGE_ARENA_BOUNDS := Rect2(-4800.0, -2700.0, 9600.0, 5400.0)
const LARGE_TEXTURE_SIZE := Vector2(4096.0, 2304.0)

var assertions := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := ContentCatalog.arena_visual_definitions()
	_assert_vector(RunConfig.new().arena_size, LARGE_ARENA_BOUNDS.size, "production arena dimensions are enlarged by 300 percent")
	var backdrop := ArenaBackdrop.new()
	# Production configures before inserting the arena into the Simulation tree.
	backdrop.configure(ARENA_BOUNDS, definitions[&"intro"])
	get_root().add_child(backdrop)
	await _wait_for_bake(backdrop)

	var initial := backdrop.bake_state_snapshot()
	_assert_true(bool(initial.get("ready", false)), "initial arena completes its static bake")
	_assert_true(not bool(initial.get("pending", true)), "initial bake has no pending work after capture")
	_assert_vector(initial.get("arena_size", Vector2.ZERO), EXPECTED_SIZE, "logical arena remains 2400x1350")
	_assert_vector(initial.get("texture_size", Vector2.ZERO), EXPECTED_SIZE, "baked texture is exactly 2400x1350")
	_assert_vector(initial.get("viewport_size", Vector2.ZERO), EXPECTED_SIZE, "offscreen target is exactly 2400x1350")
	_assert_equal(int(initial.get("viewport_updates", -1)), SubViewport.UPDATE_DISABLED, "render target is disabled after its one update")
	_assert_equal(StringName(initial.get("level_id", &"")), &"intro", "initial bake publishes the configured palette")
	_assert_equal(backdrop.get_child_count(), 1, "one reusable SubViewport is allocated")
	_assert_equal(backdrop.get_child(0).get_child_count(), 1, "one reusable offscreen draw canvas is allocated")
	_assert_true(int(initial.get("seam_segment_count", 0)) > 0, "torus seam is precomputed into static dash segments")
	_assert_equal(int(initial.get("corner_segment_count", 0)), 8, "four torus corners have two static markers each")

	var viewport_id := int(initial.get("viewport_instance_id", 0))
	var canvas_id := int(initial.get("canvas_instance_id", 0))
	var expected_generation := int(initial.get("generation", 0))
	var level_ids: Array[StringName] = [
		&"localized_focus",
		&"spreading_infection",
		&"severe_pneumonia",
		&"intro",
	]
	for cycle in range(12):
		var level_id: StringName = level_ids[cycle % level_ids.size()]
		backdrop.configure(ARENA_BOUNDS, definitions[level_id])
		expected_generation += 1
		await _wait_for_bake(backdrop)
		var state := backdrop.bake_state_snapshot()
		_assert_true(bool(state.get("ready", false)), "reconfigure %d completes its bake" % cycle)
		_assert_equal(int(state.get("generation", -1)), expected_generation, "reconfigure %d keeps the newest generation" % cycle)
		_assert_equal(StringName(state.get("level_id", &"")), level_id, "reconfigure %d bakes the requested level palette" % cycle)
		_assert_vector(state.get("texture_size", Vector2.ZERO), EXPECTED_SIZE, "reconfigure %d preserves texture size" % cycle)
		_assert_equal(int(state.get("viewport_updates", -1)), SubViewport.UPDATE_DISABLED, "reconfigure %d disables ongoing viewport updates" % cycle)
		_assert_equal(int(state.get("viewport_instance_id", 0)), viewport_id, "reconfigure %d reuses the SubViewport" % cycle)
		_assert_equal(int(state.get("canvas_instance_id", 0)), canvas_id, "reconfigure %d reuses the draw canvas" % cycle)
		_assert_equal(backdrop.get_child_count(), 1, "reconfigure %d does not leak viewport nodes" % cycle)
		_assert_equal(int(state.get("corner_segment_count", 0)), 8, "reconfigure %d retains the baked torus markers" % cycle)

	# Two configurations before a render frame must coalesce rather than letting
	# a stale completion publish the wrong level texture.
	backdrop.configure(ARENA_BOUNDS, definitions[&"localized_focus"])
	backdrop.configure(ARENA_BOUNDS, definitions[&"severe_pneumonia"])
	expected_generation += 2
	await _wait_for_bake(backdrop)
	var coalesced := backdrop.bake_state_snapshot()
	_assert_equal(int(coalesced.get("generation", -1)), expected_generation, "pending reconfigures retain only the newest generation")
	_assert_equal(StringName(coalesced.get("level_id", &"")), &"severe_pneumonia", "stale bake cannot replace the newest palette")
	_assert_true(bool(coalesced.get("ready", false)), "coalesced reconfigure ends in baked mode")
	_assert_equal(int(coalesced.get("viewport_updates", -1)), SubViewport.UPDATE_DISABLED, "coalesced bake leaves no render target updates")

	# The four-times-wider and four-times-higher production arena is baked once
	# into a Web-safe texture while preserving its aspect ratio. Logical gameplay
	# bounds remain full size; only the static background resolution is reduced.
	backdrop.configure(LARGE_ARENA_BOUNDS, definitions[&"intro"])
	await _wait_for_bake(backdrop)
	var large := backdrop.bake_state_snapshot()
	_assert_true(bool(large.get("ready", false)), "large production arena keeps the static one-shot bake path")
	_assert_vector(large.get("arena_size", Vector2.ZERO), LARGE_ARENA_BOUNDS.size, "large bake preserves full logical arena dimensions")
	_assert_vector(large.get("texture_size", Vector2.ZERO), LARGE_TEXTURE_SIZE, "large bake is capped to a Web-safe 4096-wide texture")
	_assert_equal(int(large.get("viewport_updates", -1)), SubViewport.UPDATE_DISABLED, "large bake leaves no ongoing render target updates")
	_assert_equal(int(large.get("viewport_instance_id", 0)), viewport_id, "large bake reuses the existing viewport")

	backdrop.configure(ARENA_BOUNDS, definitions[&"intro"])
	await _wait_for_bake(backdrop)
	var recovered := backdrop.bake_state_snapshot()
	_assert_true(bool(recovered.get("ready", false)), "smaller reconfigure remains valid after the large bake")
	_assert_vector(recovered.get("texture_size", Vector2.ZERO), EXPECTED_SIZE, "recovered bake restores exact arena size")
	_assert_equal(int(recovered.get("viewport_instance_id", 0)), viewport_id, "recovery still reuses the original viewport")
	_assert_equal(backdrop.get_child_count(), 1, "all bake and fallback cycles retain one viewport node")

	backdrop.queue_free()
	await process_frame
	if failures == 0:
		print("ALVEOLUS_ARENA_BACKDROP_BAKE_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_ARENA_BACKDROP_BAKE_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)


func _wait_for_bake(backdrop: ArenaBackdrop) -> void:
	for frame in range(8):
		await process_frame
		if bool(backdrop.bake_state_snapshot().get("ready", false)):
			return


func _wait_frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _assert_true(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _assert_vector(actual: Vector2, expected: Vector2, label: String) -> void:
	_assert_true(actual.is_equal_approx(expected), "%s (expected %s, got %s)" % [label, expected, actual])
