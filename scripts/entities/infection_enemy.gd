class_name InfectionEnemy
extends Node2D

signal defeated(enemy: InfectionEnemy, analysis_value: int, was_boss: bool)
signal pressure_applied(amount: float)
signal minions_requested(origin: Vector2, count: int)
signal damage_feedback(position: Vector2, amount: float)
signal health_changed(current: float, maximum: float)
signal boss_phase_changed(phase: int)
signal materialized(enemy: InfectionEnemy)
signal damage_applied(enemy: InfectionEnemy, amount: float, source: StringName)
signal visual_release_requested(enemy: InfectionEnemy, generation: int)

const SPAWN_TELEGRAPH_SECONDS := 0.55
const SPAWN_MATERIALIZE_SECONDS := 0.15
const SPAWN_TOTAL_SECONDS := SPAWN_TELEGRAPH_SECONDS + SPAWN_MATERIALIZE_SECONDS
const DEATH_SECONDS := 0.0
const HIT_REACTION_SECONDS := 0.09

var definition: EnemyDefinition
var target: TherapyAvatar
var topology: ArenaTopology
var health: float
var max_health: float
var speed_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var phase_minions: PackedInt32Array = PackedInt32Array()
var next_phase_index: int = 0
var contact_cooldown: float = 0.0
var hit_flash: float = 0.0
var hit_scale_time: float = 0.0
var spawn_timer: float = SPAWN_TOTAL_SECONDS
var dying: bool = false
var death_timer: float = 0.0
var defeat_emitted: bool = false
var materialized_emitted: bool = false
var last_damage_source: StringName = &""
var visual_texture: Texture2D
var visual_body: UnitBody2D
var status_speed_multipliers: Dictionary = {}
var status_contact_multipliers: Dictionary = {}
var _cached_status_speed_multiplier: float = 1.0
var _cached_status_contact_multiplier: float = 1.0
var activation_generation: int = 0
var activation_active: bool = false
var visual_previous_position: Vector2 = Vector2.ZERO
var visual_current_position: Vector2 = Vector2.ZERO
var visual_previous_size: Vector2 = Vector2.ZERO
var visual_current_size: Vector2 = Vector2.ZERO
var visual_previous_color: Color = Color.TRANSPARENT
var visual_current_color: Color = Color.TRANSPARENT
var visual_motion_initialized: bool = false
var detailed_visual_required: bool = false
var _arena_min: Vector2 = Vector2.ZERO
var _arena_max: Vector2 = Vector2.ZERO
var _arena_size: Vector2 = Vector2.ZERO
var _arena_half_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	visual_body = UnitBody2D.new()
	add_child(visual_body)
	_configure_visual()

func configure(
	enemy_definition: EnemyDefinition,
	target_node: TherapyAvatar,
	arena_topology: ArenaTopology,
	health_scale: float = 1.0,
	movement_scale: float = 1.0,
	contact_scale: float = 1.0,
	boss_phases: PackedInt32Array = PackedInt32Array()
) -> void:
	activation_generation += 1
	activation_active = true
	definition = enemy_definition
	target = target_node
	topology = arena_topology
	_cache_topology_bounds()
	max_health = definition.max_health * health_scale
	health = max_health
	speed_multiplier = movement_scale
	damage_multiplier = contact_scale
	phase_minions = boss_phases
	next_phase_index = 0
	contact_cooldown = 0.0
	hit_flash = 0.0
	hit_scale_time = 0.0
	spawn_timer = SPAWN_TOTAL_SECONDS
	dying = false
	death_timer = 0.0
	defeat_emitted = false
	materialized_emitted = false
	last_damage_source = &""
	status_speed_multipliers.clear()
	status_contact_multipliers.clear()
	_cached_status_speed_multiplier = 1.0
	_cached_status_contact_multiplier = 1.0
	detailed_visual_required = definition.is_boss or definition.id == &"minor_focus"
	_configure_visual()
	reset_visual_snapshot()
	# Visual ownership is transferred atomically to CrowdRenderer immediately
	# after configuration. The world, not this node, advances fixed simulation.
	hide()
	set_physics_process(false)
	queue_redraw()

func recycle() -> void:
	if activation_active:
		visual_release_requested.emit(self, activation_generation)
	activation_active = false
	activation_generation += 1
	set_physics_process(false)
	hide()
	target = null
	topology = null
	_arena_size = Vector2.ZERO
	_arena_half_size = Vector2.ZERO
	phase_minions = PackedInt32Array()
	status_speed_multipliers.clear()
	status_contact_multipliers.clear()
	_cached_status_speed_multiplier = 1.0
	_cached_status_contact_multiplier = 1.0
	visual_motion_initialized = false

func is_targetable() -> bool:
	return activation_active and spawn_timer <= 0.0 and not dying and health > 0.0

func current_handle() -> Dictionary:
	return {
		"instance_id": get_instance_id(),
		"generation": activation_generation,
	}

func is_generation_valid(generation: int) -> bool:
	return activation_active and activation_generation == generation

func set_detailed_visual_required(required: bool) -> void:
	detailed_visual_required = required or (definition != null and (definition.is_boss or definition.id == &"minor_focus"))

func requires_detailed_visual() -> bool:
	return detailed_visual_required or definition == null or definition.is_boss or definition.id == &"minor_focus"

func reset_visual_motion() -> void:
	visual_previous_position = global_position
	visual_current_position = global_position
	visual_motion_initialized = true
	reset_physics_interpolation()


func reset_visual_snapshot() -> void:
	reset_visual_motion()
	_sync_visual_appearance()
	visual_previous_size = visual_current_size
	visual_previous_color = visual_current_color

func visual_interpolated_position(interpolation_fraction: float) -> Vector2:
	if not visual_motion_initialized:
		return global_position
	return visual_previous_position.lerp(visual_current_position, clampf(interpolation_fraction, 0.0, 1.0))


func visual_interpolated_size(interpolation_fraction: float) -> Vector2:
	return visual_previous_size.lerp(visual_current_size, clampf(interpolation_fraction, 0.0, 1.0))


func visual_interpolated_color(interpolation_fraction: float) -> Color:
	return visual_previous_color.lerp(visual_current_color, clampf(interpolation_fraction, 0.0, 1.0))

func get_highlight_body() -> UnitBody2D:
	return visual_body

func _configure_visual() -> void:
	if definition == null:
		return
	visual_texture = VisualAssetCatalog.gameplay_sprite(definition.visual_id)
	if visual_body != null:
		visual_body.configure_circle(definition.radius * (1.08 if not definition.is_boss else 1.04), Vector2.ZERO, 32)

func _visual_rect() -> Rect2:
	var extent := visual_extent()
	return Rect2(Vector2.ONE * -extent * 0.5, Vector2.ONE * extent)

func visual_extent() -> float:
	if definition == null:
		return 0.0
	if definition.id == &"bacterial_cluster":
		return definition.radius * 2.15
	return definition.radius * (2.25 if definition.is_boss else 2.35)

func _physics_process(delta: float) -> void:
	step_fixed(delta)

func step_fixed(delta: float) -> void:
	if not activation_active:
		return
	_begin_visual_step()
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		_sync_visual_appearance()
		queue_redraw()
	if spawn_timer > 0.0:
		spawn_timer = maxf(0.0, spawn_timer - delta)
		_sync_visual_appearance()
		if is_zero_approx(spawn_timer):
			reset_visual_motion()
			queue_redraw()
			if not materialized_emitted:
				materialized_emitted = true
				materialized.emit(self)
		return
	if dying:
		_complete_defeat()
		return
	if definition == null or not is_instance_valid(target):
		return
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	var to_target := target.global_position - global_position
	if _arena_size.x > 0.0:
		if to_target.x > _arena_half_size.x:
			to_target.x -= _arena_size.x
		elif to_target.x < -_arena_half_size.x:
			to_target.x += _arena_size.x
	if _arena_size.y > 0.0:
		if to_target.y > _arena_half_size.y:
			to_target.y -= _arena_size.y
		elif to_target.y < -_arena_half_size.y:
			to_target.y += _arena_size.y
	var distance_squared := to_target.length_squared()
	if distance_squared > 0.1:
		var distance := sqrt(distance_squared)
		global_position += to_target * (definition.speed * speed_multiplier * _cached_status_speed_multiplier * delta / distance)
		var wrapped := global_position
		if _arena_size.x > 0.0 and _arena_size.y > 0.0:
			if wrapped.x < _arena_min.x:
				wrapped.x += _arena_size.x
			elif wrapped.x >= _arena_max.x:
				wrapped.x -= _arena_size.x
			if wrapped.y < _arena_min.y:
				wrapped.y += _arena_size.y
			elif wrapped.y >= _arena_max.y:
				wrapped.y -= _arena_size.y
		if wrapped != global_position:
			global_position = wrapped
			reset_visual_motion()
		else:
			visual_current_position = global_position
	var contact_radius := definition.radius + TherapyAvatar.BODY_RADIUS
	if distance_squared <= contact_radius * contact_radius and contact_cooldown <= 0.0:
		pressure_applied.emit(definition.contact_damage * damage_multiplier * _cached_status_contact_multiplier)
		contact_cooldown = 0.82 if not definition.is_boss else 0.58

## Temporary combat effects use named sources so overlapping systems can be
## refreshed or removed without restoring stale values from another effect.
func set_status_modifier(source: StringName, movement_multiplier: float = 1.0, contact_multiplier: float = 1.0) -> void:
	if source.is_empty():
		return
	status_speed_multipliers[source] = maxf(0.0, movement_multiplier)
	status_contact_multipliers[source] = maxf(0.0, contact_multiplier)
	_refresh_status_products()

func clear_status_modifier(source: StringName) -> void:
	status_speed_multipliers.erase(source)
	status_contact_multipliers.erase(source)
	_refresh_status_products()

func status_speed_multiplier() -> float:
	return _cached_status_speed_multiplier

func status_contact_multiplier() -> float:
	return _cached_status_contact_multiplier

func apply_displacement(offset: Vector2) -> void:
	if offset.length_squared() <= 0.0001 or dying or spawn_timer > 0.0:
		return
	global_position += offset
	if topology != null:
		global_position = topology.wrap_position(global_position)
	reset_visual_motion()

func _begin_visual_step() -> void:
	if not visual_motion_initialized:
		reset_visual_motion()
		return
	visual_previous_position = visual_current_position
	visual_current_position = global_position
	visual_previous_size = visual_current_size
	visual_previous_color = visual_current_color


func _sync_visual_appearance() -> void:
	if definition == null:
		visual_current_size = Vector2.ZERO
		visual_current_color = Color.TRANSPARENT
		return
	var visual_scale := 1.0
	var alpha := 1.0
	if spawn_timer > 0.0:
		var progress := 1.0 - spawn_timer / SPAWN_TOTAL_SECONDS
		visual_scale = lerpf(0.55, 1.0, clampf(progress, 0.0, 1.0))
		alpha = 0.0 if spawn_timer > SPAWN_MATERIALIZE_SECONDS else clampf(1.0 - spawn_timer / SPAWN_MATERIALIZE_SECONDS, 0.0, 1.0)
	var reaction := hit_reaction_amount()
	var extent := visual_extent() * visual_scale
	visual_current_size = Vector2(extent * (1.0 + reaction * 0.055), extent * (1.0 - reaction * 0.035))
	visual_current_color = Color.WHITE.lerp(Color(1.0, 0.39, 0.33), reaction * 0.68)
	visual_current_color.a = alpha


func _cache_topology_bounds() -> void:
	if topology == null:
		_arena_min = Vector2.ZERO
		_arena_max = Vector2.ZERO
		_arena_size = Vector2.ZERO
		_arena_half_size = Vector2.ZERO
		return
	_arena_min = topology.bounds.position
	_arena_max = topology.bounds.end
	_arena_size = topology.bounds.size
	_arena_half_size = _arena_size * 0.5

func _refresh_status_products() -> void:
	_cached_status_speed_multiplier = 1.0
	for source in status_speed_multipliers:
		_cached_status_speed_multiplier *= float(status_speed_multipliers[source])
	_cached_status_contact_multiplier = 1.0
	for source in status_contact_multipliers:
		_cached_status_contact_multiplier *= float(status_contact_multipliers[source])

func take_damage(amount: float, source: StringName = &"therapy") -> void:
	if amount <= 0.0 or not is_targetable():
		return
	var applied := minf(amount, health)
	last_damage_source = source
	health -= amount
	hit_flash = HIT_REACTION_SECONDS
	_sync_visual_appearance()
	damage_applied.emit(self, applied, source)
	health_changed.emit(maxf(health, 0.0), max_health)
	_check_boss_phases()
	if health <= 0.0:
		health = 0.0
		dying = true
		death_timer = 0.0
		_complete_defeat()
		return
	queue_redraw()

func hit_reaction_amount() -> float:
	return clampf(hit_flash / HIT_REACTION_SECONDS, 0.0, 1.0)

func _complete_defeat() -> void:
	if defeat_emitted or definition == null:
		return
	defeat_emitted = true
	defeated.emit(self, definition.analysis_value, definition.is_boss)

func _check_boss_phases() -> void:
	if not definition.is_boss or max_health <= 0.0:
		return
	var thresholds := [0.70, 0.40]
	var fraction := health / max_health
	while next_phase_index < phase_minions.size() and next_phase_index < thresholds.size() and fraction <= thresholds[next_phase_index]:
		var phase := next_phase_index + 1
		minions_requested.emit(global_position, int(phase_minions[next_phase_index]))
		boss_phase_changed.emit(phase)
		next_phase_index += 1

func _draw() -> void:
	if definition == null:
		return
	var alpha := 1.0
	if spawn_timer > 0.0:
		var elapsed := SPAWN_TOTAL_SECONDS - spawn_timer
		var pulse_progress := clampf(elapsed / SPAWN_TELEGRAPH_SECONDS, 0.0, 1.0)
		var pulse_radius := lerpf(definition.radius * 2.1, definition.radius * 0.9, pulse_progress)
		draw_circle(Vector2.ZERO, pulse_radius, Color(definition.color, 0.06 + pulse_progress * 0.10))
		draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 28, Color(definition.color, 0.58 * (1.0 - pulse_progress * 0.45)), 2.0, true)
		if elapsed < SPAWN_TELEGRAPH_SECONDS:
			return
		alpha = clampf((elapsed - SPAWN_TELEGRAPH_SECONDS) / SPAWN_MATERIALIZE_SECONDS, 0.0, 1.0)
	var body_color := definition.color
	body_color.a *= alpha
	if visual_texture != null:
		if definition.is_boss:
			draw_circle(Vector2.ZERO, definition.radius + 13.0, Color(AlveolusVisualTheme.CORAL, 0.16 * alpha))
		var reaction := hit_reaction_amount()
		var reaction_scale := Vector2(1.0 + reaction * 0.055, 1.0 - reaction * 0.035)
		var reaction_tint := Color.WHITE.lerp(Color(1.0, 0.39, 0.33), reaction * 0.68)
		reaction_tint.a = alpha
		draw_set_transform(Vector2.ZERO, 0.0, reaction_scale)
		draw_texture_rect(visual_texture, _visual_rect(), false, reaction_tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif definition.is_boss:
		draw_circle(Vector2.ZERO, definition.radius, body_color)
	else:
		draw_circle(Vector2(-8.0, 0.0), definition.radius * 0.72, body_color)
		draw_circle(Vector2(8.0, 0.0), definition.radius * 0.72, body_color.darkened(0.08))
		draw_arc(Vector2.ZERO, definition.radius + 2.0, 0.0, TAU, 20, Color(body_color.lightened(0.25), 0.55 * alpha), 2.0, true)

	if (definition.is_boss or health < max_health) and not dying:
		var width := definition.radius * 2.0
		var fraction := clampf(health / max_health, 0.0, 1.0)
		draw_rect(Rect2(-width * 0.5, -definition.radius - 17.0, width, 6.0), Color(AlveolusVisualTheme.IVORY_DEEP, alpha), true)
		draw_rect(Rect2(-width * 0.5, -definition.radius - 17.0, width * fraction, 6.0), Color(AlveolusVisualTheme.CORAL, alpha), true)
