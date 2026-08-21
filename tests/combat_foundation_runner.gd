extends SceneTree

class FakeEnemyDefinition:
	extends RefCounted
	var radius: float = 12.0

class FakeEnemy:
	extends Node2D
	var definition := FakeEnemyDefinition.new()
	var health: float = 200.0
	var targetable: bool = true
	var speed_status: float = 1.0
	var contact_status: float = 1.0
	var displacement: Vector2 = Vector2.ZERO
	func is_targetable() -> bool:
		return targetable and health > 0.0
	func take_damage(amount: float, source: StringName = &"") -> void:
		health -= amount
	func set_status_modifier(source: StringName, movement: float = 1.0, contact: float = 1.0) -> void:
		speed_status = movement
		contact_status = contact
	func clear_status_modifier(source: StringName) -> void:
		speed_status = 1.0
		contact_status = 1.0
	func apply_displacement(offset: Vector2) -> void:
		displacement += offset
		global_position += offset

class FakeAvatar:
	extends Node2D
	var last_facing: Vector2 = Vector2.RIGHT

class FakePickup:
	extends Node2D
	var guided_to_target: bool = false

class FakeRunState:
	extends RefCounted
	var stability: float = 40.0
	var maximum: float = 100.0
	func change_stability(amount: float) -> void:
		stability = clampf(stability + amount, 0.0, maximum)

var assertions := 0
var failures := 0
var topology := ArenaTopology.new(Rect2(-500.0, -500.0, 1000.0, 1000.0))
var enemies: Array = []
var pickups: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_catalogs()
	_test_build_state()
	_test_runtime()
	_test_surface_range_contract()
	await _test_abilities()
	await _test_treatments()
	_test_enemy_status_contract()
	if failures == 0:
		print("ALVEOLUS_COMBAT_FOUNDATION_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_COMBAT_FOUNDATION_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)

func _test_catalogs() -> void:
	var treatments := TreatmentDefinition.catalog()
	_assert_equal(treatments.size(), 3, "Three base treatments are defined")
	_assert_true(treatments.has(&"treatment_precision"), "Prepared-loadout precision ID is stable")
	_assert_equal(treatments[&"treatment_spread"].base_projectiles, 3, "Spread treatment starts with three shots")
	_assert_equal(treatments[&"treatment_pierce"].max_hits, 4, "Piercing treatment hits four enemies")
	var abilities := AbilityDefinition.catalog()
	_assert_equal(abilities.size(), 6, "Six active abilities are defined")
	_assert_near(abilities[&"ability_focus_field"].cooldown, 16.0, "Focus cooldown matches the design")
	_assert_near(float(abilities[&"ability_emergency_support"].parameters.shield), 8.0, "Emergency support declares shield capacity")

func _test_build_state() -> void:
	var treatment: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_precision"]
	var build := RunBuildState.from_treatment(treatment)
	build.add_modifier(ModifierDefinition.create(&"flat", RunBuildState.TREATMENT_DAMAGE, ModifierDefinition.Operation.ADD, 8.0))
	build.add_modifier(ModifierDefinition.create(&"scale", RunBuildState.TREATMENT_DAMAGE, ModifierDefinition.Operation.MULTIPLY, 1.5))
	_assert_near(build.value(RunBuildState.TREATMENT_DAMAGE), 32.0, "Gameplay damage resolves to an integer after additions and multipliers")
	build.add_modifier(ModifierDefinition.create(&"cap", RunBuildState.TREATMENT_DAMAGE, ModifierDefinition.Operation.CLAMP_MAX, 30.0))
	_assert_near(build.value(RunBuildState.TREATMENT_DAMAGE), 30.0, "Upper clamp is deterministic")
	var precise_only := ModifierDefinition.create(&"tagged", RunBuildState.TREATMENT_DAMAGE, ModifierDefinition.Operation.ADD, 10.0, &"tag_source", PackedStringArray(["precise"]))
	build.add_modifier(precise_only)
	_assert_near(build.value(RunBuildState.TREATMENT_DAMAGE, 0.0, PackedStringArray(["spread"])), 30.0, "Missing tags exclude a modifier")
	build.remove_modifier(&"cap")
	_assert_near(build.value(RunBuildState.TREATMENT_DAMAGE, 0.0, treatment.tags), 47.0, "Matching tags apply before the integer gameplay boundary")
	_assert_equal(build.remove_source(&"tag_source"), 1, "Modifiers can be cleared by source")
	var preview := ModifierDefinition.create(&"preview", RunBuildState.TREATMENT_INTERVAL, ModifierDefinition.Operation.MULTIPLY, 0.8)
	_assert_near(build.value_with(preview, treatment.base_interval), treatment.base_interval * 0.8, "Preview uses the same resolver without mutating state")
	_assert_true(not build.has_modifier(&"preview"), "Preview modifier is not retained")
	var reaction_modifier := ModifierDefinition.from_dict(
		{"stat_id": &"ability_cooldown", "operation": &"multiply", "value": 0.9},
		&"reaction_accel",
		&"reaction"
	)
	_assert_equal(reaction_modifier.operation, ModifierDefinition.Operation.MULTIPLY, "Reaction dictionaries map into the shared modifier model")
	_assert_equal(reaction_modifier.source_id, &"reaction", "Mapped modifiers preserve their removable source")

func _test_runtime() -> void:
	var ability: AbilityDefinition = AbilityDefinition.catalog()[&"ability_focus_field"]
	var runtime := AbilityRuntime.new(ability)
	_assert_true(runtime.is_ready(), "Ability starts ready")
	runtime.start_cooldown(0.5)
	_assert_near(runtime.cooldown_remaining, 8.0, "Cooldown multiplier is applied once")
	runtime.tick(3.0)
	_assert_near(runtime.cooldown_remaining, 5.0, "Runtime advances through explicit delta")
	runtime.reduce(2.0)
	_assert_near(runtime.cooldown_remaining, 3.0, "Cooldown can be reduced by talents")
	runtime.scale_remaining(0.5)
	_assert_near(runtime.cooldown_remaining, 1.5, "Finding readiness can halve remaining cooldown")
	runtime.reset()
	_assert_true(runtime.is_ready(), "Cooldown reset makes ability ready")


func _test_surface_range_contract() -> void:
	var enemy := FakeEnemy.new()
	enemy.definition.radius = 20.0
	enemy.global_position = Vector2(118.0, 0.0)
	get_root().add_child(enemy)
	var strategy := TreatmentStrategy.new()
	var ranked := strategy.ranked_targets(Vector2.ZERO, [enemy], topology, 100.0)
	_assert_equal(ranked.size(), 1, "Treatment range includes a body edge inside range when its center is outside")
	var handle := EntityHandle.make(0, 1)
	var query := CombatQuery.new().configure(
		topology,
		func(_handle: int) -> Vector2: return enemy.global_position,
		func(_handle: int) -> float: return enemy.definition.radius,
		func(_handle: int) -> bool: return true,
		Callable(),
		64.0,
		20.0
	)
	query.rebuild(PackedInt64Array([handle]))
	_assert_equal(query.nearest(Vector2.ZERO, 100.0, 1), PackedInt64Array([handle]), "Nearest query ranks and filters by body-surface distance")
	enemy.free()

func _test_abilities() -> void:
	var avatar := FakeAvatar.new()
	avatar.position = Vector2(480.0, 0.0)
	get_root().add_child(avatar)
	var state := FakeRunState.new()
	var build := RunBuildState.new({RunBuildState.ACTIVE_COOLDOWN: 1.0, RunBuildState.SUPPORT_EFFECT: 1.0, RunBuildState.FINDING_PROGRESS: 1.0})
	var controller := AbilityController.new()
	get_root().add_child(controller)
	controller.configure(build, topology, avatar, _provide_enemies, _provide_pickups, state)
	_assert_equal(controller.process_mode, Node.PROCESS_MODE_PAUSABLE, "Ability controller inherits simulation pauses")

	var abilities := AbilityDefinition.catalog()
	controller.equip(AbilityController.SLOT_Q, abilities[&"ability_focus_field"])
	_assert_true(controller.use_slot(AbilityController.SLOT_Q, Vector2(-480.0, 0.0)), "Focus field can be used across the torus seam")
	_assert_near(controller.treatment_damage_multiplier(Vector2(-475.0, 0.0)), 1.25, "Focus boosts treatment inside its wrapped area")
	_assert_true(controller.treatment_target_priority_bonus(Vector2(-475.0, 0.0)) > 1000.0, "Focus strongly prioritizes its area")
	_assert_true(not controller.use_slot(AbilityController.SLOT_Q, Vector2.ZERO), "Ability cannot be reused during cooldown")
	controller.step(7.1)
	_assert_near(controller.treatment_damage_multiplier(Vector2(-475.0, 0.0)), 1.0, "Focus zone expires through paused simulation time only")

	controller.equip(AbilityController.SLOT_E, abilities[&"ability_emergency_support"])
	_assert_true(controller.use_slot(AbilityController.SLOT_E, Vector2.ZERO), "Self support can be used")
	_assert_near(state.stability, 54.0, "Emergency support restores exactly 14 state")
	_assert_near(controller.absorb_pressure(5.0), 0.0, "Shield absorbs incoming contact pressure")
	_assert_near(controller.absorb_pressure(6.0), 3.0, "Shield returns only unabsorbed pressure")
	controller.grant_shield(8.0)
	controller.grant_shield(8.0)
	_assert_near(controller.shield_maximum, 8.0, "Repeated support refills but cannot stack shield capacity")

	var close_enemy := FakeEnemy.new()
	close_enemy.position = Vector2(-470.0, 0.0)
	get_root().add_child(close_enemy)
	enemies = [close_enemy]
	controller.equip(AbilityController.SLOT_Q, abilities[&"ability_defense_burst"])
	controller.use_slot(AbilityController.SLOT_Q, Vector2(-480.0, 0.0))
	_assert_near(close_enemy.health, 200.0, "Stoß starts as pure control without base damage")
	_assert_near(close_enemy.displacement.length(), 120.0, "Defense burst applies the stronger 120 displacement")

	close_enemy.position = Vector2(-450.0, 0.0)
	controller.equip(AbilityController.SLOT_Q, abilities[&"ability_protection_field"])
	controller.use_slot(AbilityController.SLOT_Q, Vector2(-450.0, 0.0))
	controller.step(0.01)
	_assert_near(close_enemy.speed_status, 0.65, "Protective field slows enemies")
	_assert_near(close_enemy.contact_status, 0.65, "Protective field reduces contact pressure")
	controller.step(6.1)
	_assert_near(close_enemy.speed_status, 1.0, "Expired protection clears its named status")

	var sample := FakePickup.new()
	sample.position = Vector2(-460.0, 0.0)
	get_root().add_child(sample)
	pickups = [sample]
	var finding_events: Array[float] = []
	controller.finding_progress_requested.connect(func(amount: float) -> void: finding_events.append(amount))
	controller.equip(AbilityController.SLOT_Q, abilities[&"ability_sample_pull"])
	controller.use_slot(AbilityController.SLOT_Q, Vector2(-470.0, 0.0))
	_assert_true(sample.guided_to_target, "Sample pull guides floor samples to the player")
	_assert_equal(finding_events, [6.0], "Sample pull reports deterministic finding progress")

	close_enemy.health = 200.0
	close_enemy.position = Vector2(-470.0, 0.0)
	controller.equip(AbilityController.SLOT_Q, abilities[&"ability_treatment_line"])
	controller.use_slot(AbilityController.SLOT_Q, Vector2(-450.0, 0.0))
	_assert_near(close_enemy.health, 170.0, "Treatment line deals 30 damage through the torus seam")

	close_enemy.health = 200.0
	var fallback_burst := AbilityDefinition.create(
		&"fallback_burst", "Fallback burst", AbilityDefinition.TargetMode.CURSOR_AREA,
		0.0, &"defense_burst", {}, 0, PackedStringArray(["active", "defense"])
	)
	controller.equip(AbilityController.SLOT_Q, fallback_burst)
	var burst_result := controller.execute_command(AbilityCommand.create(AbilityController.SLOT_Q, Vector2(-480.0, 0.0), 1001))
	_assert_near(float(burst_result.values.damage), 0.0, "Stoß fallback starts at zero damage")
	_assert_near(burst_result.radius, CombatDistanceScale.world_from_stage(5), "Defense-burst fallback radius comes from central distance stage five")

	close_enemy.health = 200.0
	var fallback_line := AbilityDefinition.create(
		&"fallback_line", "Fallback line", AbilityDefinition.TargetMode.CURSOR_DIRECTION,
		0.0, &"treatment_line", {}, 0, PackedStringArray(["active", "treatment", "line"])
	)
	controller.equip(AbilityController.SLOT_Q, fallback_line)
	var line_result := controller.execute_command(AbilityCommand.create(AbilityController.SLOT_Q, Vector2(-450.0, 0.0), 1002))
	_assert_near(float(line_result.values.damage), 30.0, "Treatment-line fallback uses the current 30 damage contract")

	controller.queue_free()
	avatar.queue_free()
	close_enemy.queue_free()
	sample.queue_free()
	enemies.clear()
	pickups.clear()
	await process_frame

func _test_treatments() -> void:
	var avatar := FakeAvatar.new()
	avatar.position = Vector2(480.0, 0.0)
	get_root().add_child(avatar)
	var first := FakeEnemy.new()
	first.position = Vector2(-470.0, 0.0)
	get_root().add_child(first)
	var second := FakeEnemy.new()
	second.position = Vector2(-430.0, 0.0)
	get_root().add_child(second)
	enemies = [first, second]
	var definitions := TreatmentDefinition.catalog()

	var precise: TreatmentDefinition = definitions[&"treatment_precision"]
	var precise_build := RunBuildState.from_treatment(precise)
	var default_precise_shots := PreciseTreatmentStrategy.new().create_shots(avatar.position, Vector2.RIGHT, enemies, topology, precise, precise_build)
	_assert_equal(default_precise_shots.size(), 1, "Impuls erzeugt vor dem Zusatzziel-Ausbau exakt ein Projektil")
	precise_build.set_base(RunBuildState.TREATMENT_PROJECTILES, 2.0)
	var precise_shots := PreciseTreatmentStrategy.new().create_shots(avatar.position, Vector2.RIGHT, enemies, topology, precise, precise_build)
	_assert_equal(precise_shots.size(), 2, "Impuls erzeugt für jedes zusätzliche Projektil einen eigenen Schuss")
	_assert_equal(precise_shots[0].mode, TreatmentShot.Mode.TRACKING, "Precision produces tracking shots")

	var spread: TreatmentDefinition = definitions[&"treatment_spread"]
	var spread_shots := SpreadTreatmentStrategy.new().create_shots(avatar.position, Vector2.RIGHT, enemies, topology, spread, RunBuildState.from_treatment(spread))
	_assert_equal(spread_shots.size(), 3, "Spread strategy creates three distinct rays")
	_assert_true(not spread_shots[0].direction.is_equal_approx(spread_shots[2].direction), "Spread rays use different angles")

	var pierce: TreatmentDefinition = definitions[&"treatment_pierce"]
	var piercing_shots := PiercingTreatmentStrategy.new().create_shots(avatar.position, Vector2.RIGHT, enemies, topology, pierce, RunBuildState.from_treatment(pierce))
	_assert_equal(piercing_shots.size(), 1, "Piercing strategy creates one line")
	_assert_equal(piercing_shots[0].resolve_line_hits(enemies, topology).size(), 2, "Piercing line resolves ordered seam-aware hits")

	var controller := TreatmentController.new()
	get_root().add_child(controller)
	controller.configure(precise, precise_build, topology, avatar, _provide_enemies)
	_assert_equal(controller.process_mode, Node.PROCESS_MODE_PAUSABLE, "Treatment controller inherits simulation pauses")
	var fired := controller.step(0.2)
	_assert_equal(fired.size(), 2, "Controller emits the selected strategy's shot intents")
	_assert_true(controller.cooldown_remaining > 0.0, "Treatment cooldown starts after an attempt")

	controller.queue_free()
	avatar.queue_free()
	first.queue_free()
	second.queue_free()
	enemies.clear()
	await process_frame

func _test_enemy_status_contract() -> void:
	var enemy := InfectionEnemy.new()
	enemy.set_status_modifier(&"field", 0.65, 0.7)
	enemy.set_status_modifier(&"finding", 0.8, 1.0)
	_assert_near(enemy.status_speed_multiplier(), 0.52, "Enemy status sources combine multiplicatively")
	_assert_near(enemy.status_contact_multiplier(), 0.7, "Contact and movement modifiers remain independent")
	enemy.clear_status_modifier(&"field")
	_assert_near(enemy.status_speed_multiplier(), 0.8, "Clearing one source preserves other statuses")
	enemy.recycle()
	_assert_near(enemy.status_speed_multiplier(), 1.0, "Pooling clears temporary statuses")
	enemy.free()

func _provide_enemies() -> Array:
	return enemies

func _provide_pickups() -> Array:
	return pickups

func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (%s != %s)" % [message, str(actual), str(expected)])

func _assert_near(actual: float, expected: float, message: String) -> void:
	_assert_true(absf(actual - expected) <= 0.001, "%s (%.4f != %.4f)" % [message, actual, expected])
