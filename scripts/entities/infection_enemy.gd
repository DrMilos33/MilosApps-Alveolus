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

const SPAWN_TELEGRAPH_SECONDS := 0.55
const SPAWN_MATERIALIZE_SECONDS := 0.15
const SPAWN_TOTAL_SECONDS := SPAWN_TELEGRAPH_SECONDS + SPAWN_MATERIALIZE_SECONDS
const DEATH_SECONDS := 0.18

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

func configure(
	enemy_definition: EnemyDefinition,
	target_node: TherapyAvatar,
	arena_topology: ArenaTopology,
	health_scale: float = 1.0,
	movement_scale: float = 1.0,
	contact_scale: float = 1.0,
	boss_phases: PackedInt32Array = PackedInt32Array()
) -> void:
	definition = enemy_definition
	target = target_node
	topology = arena_topology
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
	show()
	set_physics_process(true)
	queue_redraw()

func recycle() -> void:
	set_physics_process(false)
	hide()
	target = null
	topology = null
	phase_minions = PackedInt32Array()

func is_targetable() -> bool:
	return spawn_timer <= 0.0 and not dying and health > 0.0

func _physics_process(delta: float) -> void:
	var feedback_was_active := hit_flash > 0.0 or hit_scale_time > 0.0
	hit_flash = maxf(0.0, hit_flash - delta)
	hit_scale_time = maxf(0.0, hit_scale_time - delta)
	if spawn_timer > 0.0:
		spawn_timer = maxf(0.0, spawn_timer - delta)
		if is_zero_approx(spawn_timer):
			reset_physics_interpolation()
			queue_redraw()
			if not materialized_emitted:
				materialized_emitted = true
				materialized.emit(self)
		return
	if dying:
		death_timer = maxf(0.0, death_timer - delta)
		queue_redraw()
		if is_zero_approx(death_timer) and not defeat_emitted:
			defeat_emitted = true
			defeated.emit(self, definition.analysis_value, definition.is_boss)
			if is_physics_processing():
				recycle()
		return
	if definition == null or not is_instance_valid(target):
		return
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	var to_target := topology.shortest_delta(global_position, target.global_position)
	var distance_squared := to_target.length_squared()
	if distance_squared > 0.1:
		var distance := sqrt(distance_squared)
		global_position += to_target * (definition.speed * speed_multiplier * delta / distance)
		var wrapped := topology.wrap_position_if_needed(global_position)
		if not wrapped.is_equal_approx(global_position):
			global_position = wrapped
			reset_physics_interpolation()
	var contact_radius := definition.radius + TherapyAvatar.BODY_RADIUS
	if distance_squared <= contact_radius * contact_radius and contact_cooldown <= 0.0:
		pressure_applied.emit(definition.contact_damage * damage_multiplier)
		contact_cooldown = 0.82 if not definition.is_boss else 0.58
	if feedback_was_active:
		queue_redraw()

func take_damage(amount: float, source: StringName = &"therapy") -> void:
	if amount <= 0.0 or not is_targetable():
		return
	var applied := minf(amount, health)
	last_damage_source = source
	health -= amount
	hit_flash = 0.10
	hit_scale_time = 0.08
	damage_feedback.emit(global_position, applied)
	damage_applied.emit(self, applied, source)
	health_changed.emit(maxf(health, 0.0), max_health)
	_check_boss_phases()
	if health <= 0.0:
		health = 0.0
		dying = true
		death_timer = DEATH_SECONDS
	queue_redraw()

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
	if dying:
		alpha = clampf(death_timer / DEATH_SECONDS, 0.0, 1.0)
	var visual_scale := 1.0
	if hit_scale_time > 0.0:
		visual_scale = 1.0 + 0.12 * (hit_scale_time / 0.08)
	if dying:
		visual_scale *= lerpf(0.35, 1.0, alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * visual_scale)
	var body_color := Color.WHITE if hit_flash > 0.0 else definition.color
	body_color.a *= alpha
	if definition.is_boss:
		draw_circle(Vector2.ZERO, definition.radius + 13.0, Color(body_color, 0.16 * alpha))
		draw_circle(Vector2.ZERO, definition.radius, body_color)
		for index in range(10):
			var angle := TAU * float(index) / 10.0
			var p := Vector2.from_angle(angle) * (definition.radius * 0.70)
			draw_circle(p, 12.0, body_color.lightened(0.12))
		draw_arc(Vector2.ZERO, definition.radius + 4.0, 0.0, TAU, 36, Color("f4a1af", alpha), 4.0, true)
	elif definition.id == &"bacterial_cluster":
		for offset in [Vector2(-13, -8), Vector2(10, -12), Vector2(-8, 11), Vector2(15, 10)]:
			draw_circle(offset, 16.0, body_color)
			draw_arc(offset, 14.0, 0.0, TAU, 18, body_color.lightened(0.23), 2.0, true)
	else:
		draw_circle(Vector2(-8.0, 0.0), definition.radius * 0.72, body_color)
		draw_circle(Vector2(8.0, 0.0), definition.radius * 0.72, body_color.darkened(0.08))
		draw_arc(Vector2.ZERO, definition.radius + 2.0, 0.0, TAU, 20, Color(body_color.lightened(0.25), 0.55 * alpha), 2.0, true)

	if (definition.is_boss or health < max_health) and not dying:
		var width := definition.radius * 2.0
		var fraction := clampf(health / max_health, 0.0, 1.0)
		draw_rect(Rect2(-width * 0.5, -definition.radius - 17.0, width, 5.0), Color("26343b", alpha), true)
		draw_rect(Rect2(-width * 0.5, -definition.radius - 17.0, width * fraction, 5.0), Color("f0788e", alpha), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
