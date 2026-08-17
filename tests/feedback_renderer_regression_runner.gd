extends SceneTree

const CAPACITY := 80
const PARTICLES_PER_BURST := 4
const EPSILON := 0.0001

var assertions := 0
var failures := 0
var finished_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var simulation_root := Node2D.new()
	simulation_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_root().add_child(simulation_root)
	var renderer := FeedbackRenderer.new().configure(CAPACITY)
	renderer.burst_finished.connect(_on_burst_finished)
	simulation_root.add_child(renderer)
	var bursts: Array[VisualBurst] = []

	for index in range(CAPACITY):
		var burst := VisualBurst.new()
		burst.global_position = Vector2(float(index * 3), float(index % 11) * 7.0)
		burst.configure(&"spark", Color("4dcac1"), PARTICLES_PER_BURST, 10.0, 24.0)
		_assert_true(renderer.register_burst(burst), "Burst %d reserves one fixed lifecycle slot" % index)
		bursts.append(burst)
	renderer.flush_render_state()
	_assert_equal(renderer.active_count(), CAPACITY, "All 80 feedback effects remain visible on FULL quality")
	_assert_equal(renderer.available_count(), 0, "Feedback capacity is strictly bounded")
	_assert_equal(renderer.active_particle_count(), CAPACITY * PARTICLES_PER_BURST, "All requested feedback particles are represented")
	_assert_equal(renderer.batch().multimesh.visible_instance_count, CAPACITY * PARTICLES_PER_BURST, "One dense MultiMesh contains every visible particle")
	_assert_equal(renderer.get_child_count(), 1, "Feedback renderer owns one CanvasItem regardless of effect count")
	var object_variant: Variant = bursts[0]
	_assert_true(not (object_variant is Node), "VisualBurst has no Node and no per-effect process callback")

	var overflow := VisualBurst.new().configure(&"spark", Color.WHITE, 4, 1.0, 16.0)
	_assert_true(not renderer.register_burst(overflow), "The 81st effect is rejected without allocating a Node")

	var reused := bursts[17]
	var old_generation := reused.activation_generation
	_assert_true(renderer.release_burst(reused, old_generation), "Current activation releases synchronously")
	_assert_equal(renderer.active_count(), CAPACITY - 1, "Release returns its fixed slot")
	reused.recycle()
	reused.global_position = Vector2(640.0, -310.0)
	reused.configure(&"spark", Color("ef7766"), 6, 10.0, 32.0)
	_assert_true(renderer.register_burst(reused), "Pooled shell registers with a new generation")
	_assert_true(not renderer.release_burst(reused, old_generation), "Stale generation cannot clear the replacement")
	_assert_equal(renderer.active_count(), CAPACITY, "Stale release leaves all current effects intact")

	var paused_burst := bursts[0]
	var remaining_before_pause := paused_burst.remaining
	paused = true
	await process_frame
	await process_frame
	_assert_near(paused_burst.remaining, remaining_before_pause, "Pause freezes the central feedback lifecycle")
	paused = false

	for burst in bursts:
		burst.remaining = 0.001
	await process_frame
	await process_frame
	_assert_equal(finished_count, CAPACITY, "Every timed effect completes exactly once")
	_assert_equal(renderer.active_count(), 0, "Completed feedback releases every slot")
	_assert_equal(renderer.batch().multimesh.visible_instance_count, 0, "No expired particle remains visible")
	_assert_equal(renderer.available_count(), CAPACITY, "All lifecycle slots return after expiry")

	renderer.clear()
	simulation_root.queue_free()
	await process_frame
	if failures == 0:
		print("ALVEOLUS_FEEDBACK_RENDERER_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_FEEDBACK_RENDERER_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)


func _on_burst_finished(_burst: VisualBurst) -> void:
	finished_count += 1


func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (actual=%s expected=%s)" % [message, actual, expected])


func _assert_near(actual: float, expected: float, message: String) -> void:
	_assert_true(absf(actual - expected) <= EPSILON, "%s (actual=%.6f expected=%.6f)" % [message, actual, expected])
