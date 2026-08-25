extends SceneTree

## Native Compatibility-renderer witness for intermittent batched enemy loss.
## Headless runs skip because their dummy renderer cannot validate body pixels.

const VIEW_SIZE := Vector2i(1280, 720)
const WORLD_CENTER := Vector2(4000.0, 1800.0)
const CHURN_CYCLES := 45
const BODY_SAMPLE_HALF_SIZE := 15
const MIN_BODY_PIXELS := 24

var assertions := 0
var failures: Array[String] = []
var renderer: CrowdRenderer
var topology := ArenaTopology.new(Rect2(-4800.0, -2700.0, 9600.0, 5400.0), ArenaTopology.BoundaryMode.BOUNDED)
var enemies: Array[InfectionEnemy] = []
var offsets: Array[Vector2] = []
var definitions: Array[EnemyDefinition] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("ALVEOLUS_CROWD_VISIBILITY_SKIPPED reason=headless")
		quit(0)
		return
	get_root().size = VIEW_SIZE
	RenderingServer.set_default_clear_color(Color.BLACK)
	var camera := Camera2D.new()
	camera.position = WORLD_CENTER
	camera.enabled = true
	get_root().add_child(camera)
	renderer = CrowdRenderer.new()
	get_root().add_child(renderer)
	renderer.configure(640, 1)
	var catalog := ContentCatalog.enemy_definitions()
	definitions = [catalog[&"pneumococcus"], catalog[&"bacterial_cluster"]]
	for index in range(24):
		var column := index % 6
		var row := index / 6
		var offset := Vector2((float(column) - 2.5) * 150.0, (float(row) - 1.5) * 135.0)
		offsets.append(offset)
		var enemy := InfectionEnemy.new()
		get_root().add_child(enemy)
		enemies.append(enemy)
		_activate_enemy(enemy, definitions[index % definitions.size()], WORLD_CENTER + offset, index % 2 == 0)
	await _settle()
	await _assert_visible_frame("initial")

	for cycle in range(CHURN_CYCLES):
		for lane in range(6):
			var index := (cycle * 7 + lane * 3) % enemies.size()
			var enemy := enemies[index]
			renderer.release_enemy(enemy, enemy.activation_generation)
			enemy.recycle()
			var phase := float((cycle + index) % 9 - 4) * 2.0
			var offset := offsets[index] + Vector2(phase, -phase * 0.5)
			_activate_enemy(
				enemy,
				definitions[(cycle + index + 1) % definitions.size()],
				WORLD_CENTER + offset,
				(cycle + index) % 2 == 0
			)
		await process_frame
		await _assert_visible_frame("churn_%02d" % cycle)
		if not failures.is_empty():
			break

	for enemy in enemies:
		if is_instance_valid(enemy):
			renderer.release_enemy(enemy, enemy.activation_generation)
			enemy.queue_free()
	renderer.queue_free()
	if failures.is_empty():
		print("ALVEOLUS_CROWD_VISIBILITY_OK assertions=%d cycles=%d" % [assertions, CHURN_CYCLES])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _activate_enemy(enemy: InfectionEnemy, definition: EnemyDefinition, position: Vector2, damaged: bool) -> void:
	enemy.global_position = position
	enemy.configure(definition, null, topology)
	var record := renderer.register_enemy(enemy)
	_check(not record.is_empty() and not bool(record.get("detailed", true)), "Enemy activation owns a batched slot")
	enemy.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	if damaged:
		enemy.take_damage(1.0, &"visibility_witness")


func _settle() -> void:
	for _frame in range(4):
		await process_frame


func _assert_visible_frame(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	_check(not image.is_empty() and image.get_size() == VIEW_SIZE, "%s captures the native viewport" % label)
	if image.is_empty() or image.get_size() != VIEW_SIZE:
		return
	for index in range(enemies.size()):
		var enemy := enemies[index]
		var screen_position := Vector2(VIEW_SIZE) * 0.5 + (enemy.global_position - WORLD_CENTER)
		var pixels := _body_pixel_count(image, Vector2i(roundi(screen_position.x), roundi(screen_position.y)))
		_check(pixels >= MIN_BODY_PIXELS, "%s keeps enemy %d body visible (%d pixels)" % [label, index, pixels])
	if not failures.is_empty():
		var directory := ProjectSettings.globalize_path("res://.codex-temp/evidence")
		DirAccess.make_dir_recursive_absolute(directory)
		image.save_png("%s/crowd_visibility_failure_%s.png" % [directory, label])


func _body_pixel_count(image: Image, center: Vector2i) -> int:
	var count := 0
	var minimum := center - Vector2i.ONE * BODY_SAMPLE_HALF_SIZE
	var maximum := center + Vector2i.ONE * BODY_SAMPLE_HALF_SIZE
	for y in range(maxi(minimum.y, 0), mini(maximum.y + 1, image.get_height())):
		for x in range(maxi(minimum.x, 0), mini(maximum.x + 1, image.get_width())):
			var color := image.get_pixel(x, y)
			if color.a > 0.5 and maxf(color.r, maxf(color.g, color.b)) > 0.12:
				count += 1
	return count


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
