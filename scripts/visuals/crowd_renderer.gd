class_name CrowdRenderer
extends Node2D

## Large crowds are rendered as three MultiMeshes instead of hundreds of
## independent CanvasItems. Below the threshold the detailed entity drawings
## stay active, so discoveries, health bars and close-up feedback keep their
## original appearance.

const BATCH_THRESHOLD := 120
const TEXTURE_SIZE := 72

var _enemy_capacity: int
var _pickup_capacity: int
var _batching: bool = false
var _regular_batch: MultiMeshInstance2D
var _cluster_batch: MultiMeshInstance2D
var _pickup_batch: MultiMeshInstance2D
var _last_enemies: Array[InfectionEnemy] = []
var _last_pickups: Array[AnalysisPickup] = []

func configure(enemy_capacity: int, pickup_capacity: int) -> void:
	_enemy_capacity = enemy_capacity
	_pickup_capacity = pickup_capacity
	_regular_batch = _create_batch(_make_enemy_texture(false), enemy_capacity, 2)
	_cluster_batch = _create_batch(_make_enemy_texture(true), enemy_capacity, 2)
	_pickup_batch = _create_batch(_make_pickup_texture(), pickup_capacity, 1)

func sync(enemies: Array[InfectionEnemy], pickups: Array[AnalysisPickup]) -> void:
	_last_enemies = enemies
	_last_pickups = pickups
	var eligible_enemies := 0
	var eligible_pickups := 0
	for enemy in enemies:
		if _can_batch_enemy(enemy):
			eligible_enemies += 1
	for pickup in pickups:
		if _can_batch_pickup(pickup):
			eligible_pickups += 1
	var should_batch := eligible_enemies + eligible_pickups >= BATCH_THRESHOLD
	if not should_batch:
		_disable_batching(enemies, pickups)
		return

	_batching = true
	var regular_count := 0
	var cluster_count := 0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not _can_batch_enemy(enemy):
			enemy.show()
			continue
		enemy.hide()
		var batch := _cluster_batch if enemy.definition.id == &"bacterial_cluster" else _regular_batch
		var index := cluster_count if enemy.definition.id == &"bacterial_cluster" else regular_count
		_set_enemy_instance(batch.multimesh, index, enemy)
		if enemy.definition.id == &"bacterial_cluster":
			cluster_count += 1
		else:
			regular_count += 1

	var pickup_count := 0
	for pickup in pickups:
		if not is_instance_valid(pickup):
			continue
		if not _can_batch_pickup(pickup):
			pickup.show()
			continue
		pickup.hide()
		_set_pickup_instance(_pickup_batch.multimesh, pickup_count, pickup)
		pickup_count += 1

	_regular_batch.multimesh.visible_instance_count = regular_count
	_cluster_batch.multimesh.visible_instance_count = cluster_count
	_pickup_batch.multimesh.visible_instance_count = pickup_count

func clear() -> void:
	_disable_batching(_last_enemies, _last_pickups)
	_last_enemies = []
	_last_pickups = []

func is_batching() -> bool:
	return _batching

func _disable_batching(enemies: Array[InfectionEnemy], pickups: Array[AnalysisPickup]) -> void:
	if _batching:
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.is_physics_processing():
				enemy.show()
		for pickup in pickups:
			if is_instance_valid(pickup) and pickup.is_physics_processing():
				pickup.show()
	_batching = false
	if _regular_batch != null:
		_regular_batch.multimesh.visible_instance_count = 0
		_cluster_batch.multimesh.visible_instance_count = 0
		_pickup_batch.multimesh.visible_instance_count = 0

func _can_batch_enemy(enemy: InfectionEnemy) -> bool:
	return is_instance_valid(enemy) and enemy.definition != null and not enemy.definition.is_boss

func _can_batch_pickup(pickup: AnalysisPickup) -> bool:
	return is_instance_valid(pickup) and not pickup.guided_to_target

func _set_enemy_instance(multimesh: MultiMesh, index: int, enemy: InfectionEnemy) -> void:
	if index >= _enemy_capacity:
		return
	var visual_scale := 1.0
	var alpha := 1.0
	if enemy.spawn_timer > 0.0:
		var progress := 1.0 - enemy.spawn_timer / InfectionEnemy.SPAWN_TOTAL_SECONDS
		visual_scale = lerpf(0.55, 1.0, clampf(progress, 0.0, 1.0))
		alpha = lerpf(0.18, 1.0, clampf(progress, 0.0, 1.0))
	elif enemy.dying:
		alpha = clampf(enemy.death_timer / InfectionEnemy.DEATH_SECONDS, 0.0, 1.0)
		visual_scale = lerpf(0.35, 1.0, alpha)
	elif enemy.hit_scale_time > 0.0:
		visual_scale = 1.0 + 0.12 * enemy.hit_scale_time / 0.08
	var radius_scale := enemy.definition.radius / (30.0 if enemy.definition.id == &"bacterial_cluster" else 22.0)
	var transform := Transform2D(0.0, Vector2.ONE * visual_scale * radius_scale, 0.0, enemy.position)
	multimesh.set_instance_transform_2d(index, transform)
	var color := Color.WHITE if enemy.hit_flash > 0.0 else enemy.definition.color
	color.a = alpha
	multimesh.set_instance_color(index, color)

func _set_pickup_instance(multimesh: MultiMesh, index: int, pickup: AnalysisPickup) -> void:
	if index >= _pickup_capacity:
		return
	var stack_scale := 1.0 + minf(log(maxf(float(pickup.analysis_value), 1.0)) * 0.13, 0.65)
	var pulse := 1.0 + sin(pickup.phase) * 0.06
	multimesh.set_instance_transform_2d(index, Transform2D(0.0, Vector2.ONE * stack_scale * pulse, 0.0, pickup.position))
	multimesh.set_instance_color(index, Color("76aaff"))

func _create_batch(texture: Texture2D, capacity: int, layer: int) -> MultiMeshInstance2D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(TEXTURE_SIZE, TEXTURE_SIZE)
	multimesh.mesh = quad
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0
	var batch := MultiMeshInstance2D.new()
	batch.multimesh = multimesh
	batch.texture = texture
	batch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	batch.z_index = layer
	add_child(batch)
	return batch

func _make_enemy_texture(cluster: bool) -> Texture2D:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var centers: Array[Vector2]
	var radius: float
	if cluster:
		centers = [Vector2(25, 25), Vector2(46, 23), Vector2(27, 47), Vector2(48, 46)]
		radius = 14.0
	else:
		centers = [Vector2(28, 36), Vector2(44, 36)]
		radius = 15.5
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var point := Vector2(x + 0.5, y + 0.5)
			var coverage := 0.0
			for center in centers:
				var distance := point.distance_to(center)
				coverage = maxf(coverage, clampf(radius + 1.0 - distance, 0.0, 1.0))
			if coverage > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, coverage))
	return ImageTexture.create_from_image(image)

func _make_pickup_texture() -> Texture2D:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(TEXTURE_SIZE, TEXTURE_SIZE) * 0.5
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var alpha := 0.0
			if distance <= 6.5:
				alpha = clampf(7.5 - distance, 0.0, 1.0)
			elif distance <= 11.5:
				alpha = 0.16 * clampf(12.5 - distance, 0.0, 1.0)
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
