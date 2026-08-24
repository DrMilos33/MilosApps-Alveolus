extends SceneTree

const EXPECTED_TRAIT_IDS: Array[StringName] = [
	&"monster_resistance_20",
	&"monster_defense_10",
	&"monster_speed_15",
	&"monster_health_15",
	&"monster_damage_15",
	&"double_boss",
	&"monster_spawn_10",
	&"experience_10",
]

var assertions: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_contract()
	_test_resistance_compilation_and_damage_resolution()
	await _test_runtime_config_and_double_boss()
	_finish()


func _test_catalog_contract() -> void:
	var levels := ContentCatalog.level_definitions()
	_equal(levels.size(), 7, "Der Fallkatalog enthält Intro plus sechs Hauptfälle")
	var expected_ids: Array[StringName] = [
		&"intro",
		&"early_localized_focus",
		&"localized_focus",
		&"advancing_infection",
		&"spreading_infection",
		&"critical_infection",
		&"severe_pneumonia",
	]
	var expected_intervals: Array[Vector2] = [
		Vector2(1.10, 0.55),
		Vector2(1.16125, 0.26875),
		Vector2(1.03375, 0.23375),
		Vector2(0.9075, 0.200),
		Vector2(0.780, 0.165),
		Vector2(0.720, 0.150),
		Vector2(0.660, 0.135),
	]
	for order in range(levels.size()):
		_equal(levels[order].id, expected_ids[order], "Order %d besitzt die feste Fall-ID" % order)
		_equal(levels[order].order, order, "Fall-ID %s bewahrt Order %d" % [levels[order].id, order])
		_near(levels[order].initial_spawn_interval, expected_intervals[order].x, "Order %d bewahrt sein anfängliches Spawnintervall" % order)
		_near(levels[order].final_spawn_interval, expected_intervals[order].y, "Order %d bewahrt sein finales Spawnintervall" % order)
		if order > 0:
			_near(levels[order].boss_spawn_seconds, 300.0, "Order %d ruft den Boss nach fünf Minuten" % order)
			_near(levels[order].spawn_ramp_seconds, 300.0, "Order %d verteilt die Standardwelle über fünf Minuten" % order)

	var enemies := ContentCatalog.enemy_definitions()
	_near((enemies[&"pneumococcus"] as EnemyDefinition).speed, 54.0, "Bakterium verwendet die um 20 Prozent erhöhte Basisgeschwindigkeit")
	_near((enemies[&"bacterial_cluster"] as EnemyDefinition).speed, 54.0, "Bakteriengruppe verwendet die um 20 Prozent erhöhte Basisgeschwindigkeit")
	_near((enemies[&"minor_focus"] as EnemyDefinition).speed, 24.0, "Kleiner Herd verwendet die um 20 Prozent erhöhte Basisgeschwindigkeit")
	_near((enemies[&"infection_focus"] as EnemyDefinition).speed, 45.0, "Infektionsherd verwendet die um 50 Prozent erhöhte Bossgeschwindigkeit")
	_near((enemies[&"localized_boss"] as EnemyDefinition).speed, 42.0, "Bakterienkern verwendet die um 50 Prozent erhöhte Bossgeschwindigkeit")
	_near(PlayerStats.BASE_MOVEMENT_SPEED, 180.0, "Doctor Milos verwendet die neue Basisgeschwindigkeit")

	var treatments := TreatmentDefinition.catalog()
	_near((treatments[&"treatment_precision"] as TreatmentDefinition).base_damage, 13.0, "Impuls verwendet ganzzahligen Basisschaden")
	_near((treatments[&"treatment_spread"] as TreatmentDefinition).base_damage, 5.0, "Streuimpuls verwendet den neuen Schaden")
	_near((treatments[&"treatment_pierce"] as TreatmentDefinition).base_damage, 9.0, "Durchdringender Impuls verwendet den neuen Schaden")

	var abilities := AbilityDefinition.catalog()
	var burst := abilities[&"ability_defense_burst"] as AbilityDefinition
	var line := abilities[&"ability_treatment_line"] as AbilityDefinition
	_equal(burst.display_name, "Stoß", "Abwehrstoß verwendet den freigegebenen sichtbaren Namen")
	_near(float(burst.parameters.get("damage", 0.0)), 0.0, "Stoß startet ohne Schaden")
	_near(float(burst.parameters.get("knockback", 0.0)), 120.0, "Abwehrstoß verwendet den stärkeren Rückstoß")
	_equal(line.display_name, "Fetter lazer", "Behandlungslinie verwendet den freigegebenen sichtbaren Namen")
	_near(float(line.parameters.get("damage", 0.0)), 30.0, "Behandlungslinie verwendet den neuen Schaden")

	var traits := ContentCatalog.case_trait_definitions()
	_equal(_sorted_string_names(traits.keys()), _sorted_string_names(EXPECTED_TRAIT_IDS), "Genau die acht neuen sichtbaren Fallmerkmale sind aktiv")
	for reserved_id in ContentCatalog.reserved_case_trait_ids():
		_false(traits.has(reserved_id), "Reservierte alte Fallmerkmal-ID %s ist nicht wieder aktiv" % String(reserved_id))
	for id in EXPECTED_TRAIT_IDS:
		var definition := traits[id] as CaseTraitDefinition
		_true(
			definition != null
			and definition.id == id
			and not definition.modifiers.is_empty()
			and definition.semantic_role in [&"negative", &"mixed", &"positive"],
			"Fallmerkmal %s ist strukturell gültig" % String(id)
		)
	var expected_roles := {
		&"monster_resistance_20": &"negative",
		&"monster_defense_10": &"negative",
		&"monster_speed_15": &"negative",
		&"monster_health_15": &"negative",
		&"monster_damage_15": &"negative",
		&"double_boss": &"mixed",
		&"monster_spawn_10": &"mixed",
		&"experience_10": &"positive",
	}
	for id in expected_roles:
		_equal((traits[id] as CaseTraitDefinition).semantic_role, expected_roles[id], "Fallmerkmal %s liefert die zentrale semantische Rolle" % String(id))
	_equal(ContentCatalog.finding_definitions().size(), 2, "Nur Gruppenbildung und verdeckte Nester bleiben aktiv")


func _test_resistance_compilation_and_damage_resolution() -> void:
	var enemies := ContentCatalog.enemy_definitions()
	var source := (enemies[&"pneumococcus"] as EnemyDefinition).resistance_profile
	var source_before := source.effective_percentages.duplicate()
	var compiled := ResistanceProfile.with_effective_percentage_bonus(&"test_runtime", source, 20.0)
	_true(compiled != source, "Der Lauf kompiliert ein eigenes Widerstandsprofil statt die Katalogresource zu mutieren")
	_equal(source.effective_percentages, source_before, "Die geteilte Katalogresource bleibt unverändert")
	for type_id in DamageTypeCatalog.ALL_IDS:
		var expected := minf(source.effective_percent_for_type(type_id) + 20.0, MitigationCurve.RESISTANCE_CAP_PERCENT)
		_near(compiled.effective_percent_for_type(type_id), expected, "%s erhält exakt 20 effektive Prozentpunkte bis zum Cap" % String(type_id))

	var enemy := InfectionEnemy.new()
	enemy.runtime_resistance_profile = compiled
	enemy.runtime_defense = 10.0
	var profile := DamageProfile.single(&"test_water", &"water")
	var expected_damage := CombatDamageResolver.resolve(100.0, profile, compiled, 10.0)
	_near(CombatDamageResolver.resolve_against_enemy(100.0, profile, enemy), expected_damage, "Der zentrale Gegnerresolver kombiniert Typresistenz und Verteidigung")
	enemy.free()


func _test_runtime_config_and_double_boss() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	game.persistence_enabled = false
	game.meta.reset_defaults()
	game.discovery_manager.configure(game.discovery_definitions, {})
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = _level_by_id(game.levels, &"spreading_infection")
	_true(game.selected_level != null and game.selected_level.order == 4, "Spezialboss- und Doppelboss-Test verwendet spreading_infection auf Order 4")

	_assert_trait_config(game, &"monster_resistance_20", "enemy_resistance_effective_bonus", 20.0)
	_assert_trait_config(game, &"monster_defense_10", "enemy_defense", 10.0)
	_assert_trait_config(game, &"monster_speed_15", "enemy_speed_multiplier", game.selected_level.enemy_speed_multiplier * 1.15)
	_assert_trait_config(game, &"monster_health_15", "enemy_health_start", game.selected_level.enemy_health_start * 1.15)
	_assert_trait_config(game, &"monster_damage_15", "contact_damage_multiplier", game.selected_level.contact_damage_multiplier * 1.15)
	_assert_trait_config(game, &"double_boss", "boss_count", 2.0)
	_assert_trait_config(game, &"monster_spawn_10", "spawn_rate_multiplier", 1.10)
	_assert_trait_config(game, &"experience_10", "experience_gain_multiplier", 1.10)

	var context := RunContext.create(
		game.selected_level.id,
		0xCA5E2026,
		PreparedLoadout.default_loadout(),
		{},
		&"double_boss",
		&""
	)
	game.start_run(context)
	game.set_physics_process(false)
	game.treatment_controller.enabled = false
	game.spawn_accumulator = 999999.0
	var run_seed_before: int = game.config.random_seed
	game._reset_spawn_position_sequence()
	var expected_content_rng := RandomNumberGenerator.new()
	expected_content_rng.state = game.rng.state
	expected_content_rng.randf_range(0.0, TAU)
	expected_content_rng.randf_range(0.0, TAU)
	var first_attempt_position: Vector2 = game._spawn_position_around_avatar(500.0)
	var second_position: Vector2 = game._spawn_position_around_avatar(500.0)
	_true(
		game.topology.shortest_delta(first_attempt_position, second_position).length() > 100.0,
		"Aufeinanderfolgende Gegner verteilen sich deutlich auf dem Spawnring"
	)
	_equal(game.rng.state, expected_content_rng.state, "Räumliche Verteilung verschiebt keine späteren Inhaltswürfe")
	game._reset_spawn_position_sequence()
	var retry_position: Vector2 = game._spawn_position_around_avatar(500.0)
	_true(
		game.topology.shortest_delta(first_attempt_position, retry_position).length() > 1.0,
		"Ein neuer Versuch beginnt an einer anderen räumlichen Position"
	)
	_equal(game.config.random_seed, run_seed_before, "Die räumliche Variation verändert den reproduzierbaren Fall-Seed nicht")
	_equal(game.config.boss_count, 2, "Der Doppelboss-Vertrag erreicht RunConfig")
	_equal(game.state.boss_count_target, 2, "RunState erwartet beide Bosse")
	game.stats.immune_level = 1
	game._immune_step(0.0)
	_near(game.defense_cell_world.orbit_radius, 120.0, "Game leitet Radiusstufe 4 an den Abwehrzellenorbit weiter")
	_near(game.defense_cell_world.hit_radius, 15.0, "Game hält die physische Abwehrzellenhitbox fest klein")
	game.build_state.add_modifier(ModifierDefinition.create(
		&"test_defense_orbit",
		RunBuildState.DEFENSE_CELL_RADIUS,
		ModifierDefinition.Operation.ADD,
		30.0,
		&"test",
		PackedStringArray(["defense_cell"])
	))
	game._immune_step(0.0)
	_near(game.defense_cell_world.orbit_radius, 150.0, "Radius-Buildmodifikator vergrößert ausschließlich den Abwehrzellenorbit")
	_near(game.defense_cell_world.hit_radius, 15.0, "Radius-Buildmodifikator vergrößert die physische Hitbox nicht")
	game.build_state.remove_modifier(&"test_defense_orbit")
	game.stats.immune_level = 0
	game.defense_cell_world.clear()

	var finish_events := [0]
	var finish_success := [false]
	game.state.run_finished.connect(func(success: bool, _reason: String) -> void:
		finish_events[0] += 1
		finish_success[0] = success
	)
	game.state.trigger_event_boss()
	var handles: PackedInt64Array = game.active_boss_handle_snapshot()
	_equal(handles.size(), 2, "Doppelboss erzeugt exakt zwei generationssichere Handles")
	_true(handles[0] != handles[1], "Beide Bosse besitzen verschiedene Handles")
	var first := game.enemy_world.resolve(handles[0]) as InfectionEnemy
	var second := game.enemy_world.resolve(handles[1]) as InfectionEnemy
	_true(is_instance_valid(first) and is_instance_valid(second), "Beide Boss-Handles sind direkt auflösbar")
	if not is_instance_valid(first) or not is_instance_valid(second):
		game.queue_free()
		return
	first.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	second.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	_true(first.is_targetable() and second.is_targetable(), "Beide Bosse materialisieren regulär")
	_near(first.speed_multiplier, game.selected_level.enemy_speed_multiplier * 1.35, "Der Fall-4-Boss erhält den zusätzlichen Geschwindigkeitsfaktor")
	game.enemy_attack_director.step_fixed(0.65, game.run_session)
	var hostile_count := 0
	for projectile in game.projectiles:
		if projectile is TherapyProjectile and (projectile as TherapyProjectile).hostile_mode:
			hostile_count += 1
	_equal(hostile_count, 4, "Zwei Bosse erzeugen beim ersten Angriff je exakt zwei Gegnerprojektile")
	_equal(game.hostile_projectile_renderer.active_count(), 4, "Alle Gegnerprojektile besitzen genau einen stabilen feindlichen Renderslot")
	var initial_snapshot: Dictionary = game.active_boss_health_snapshot()
	_near(float(initial_snapshot.get("current", 0.0)), first.max_health + second.max_health, "Boss-HUD aggregiert das aktuelle Leben beider Bosse")
	_near(float(initial_snapshot.get("maximum", 0.0)), first.max_health + second.max_health, "Boss-HUD aggregiert das Maximalleben beider Bosse")
	_equal(int(initial_snapshot.get("remaining", 0)), 2, "Boss-HUD meldet zwei verbleibende Bosse")
	var seen_without_boss_phase: Dictionary = {}
	for discovery_id in game.discovery_definitions:
		if discovery_id != &"boss_phases":
			seen_without_boss_phase[discovery_id] = true
	game.discovery_manager.configure(game.discovery_definitions, seen_without_boss_phase)
	first.take_damage(first.max_health * 0.31)
	_equal(game.boss_aggregate_phase, 1, "Die erste erreichte Doppelbossphase wird aggregiert")
	_equal(game.discovery_manager.active.get("target"), first, "Bossphasen-Discovery verwendet den tatsächlich emittierenden Boss")
	game._on_discovery_dismissed()
	first.take_damage(first.max_health * 0.31)
	_equal(game.boss_aggregate_phase, 2, "Die höchste erreichte Phase steigt deterministisch")
	second.take_damage(second.max_health * 0.31)
	_equal(game.boss_aggregate_phase, 2, "Eine niedrigere Phase des zweiten Bosses lässt die aggregierte Anzeige nicht zurückspringen")

	var stale_handle := int(handles[0])
	first.take_damage(first.health)
	_equal(finish_events[0], 0, "Der erste Bosstod beendet den Lauf nicht")
	_true(game.state.active, "Der Lauf bleibt nach dem ersten Bosstod aktiv")
	_equal(game.state.bosses_defeated, 1, "RunState zählt den ersten Boss genau einmal")
	_false(game.state.boss_defeated, "Der finale Bossvertrag ist nach dem ersten Tod noch offen")
	_equal(game.active_boss_handle_snapshot().size(), 1, "Nach dem ersten Tod bleibt genau ein Boss-Handle")
	_true(game.enemy_world.resolve(stale_handle) == null, "Das freigegebene Boss-Handle kann keine gepoolte Generation adressieren")
	var remaining_snapshot: Dictionary = game.active_boss_health_snapshot()
	_near(float(remaining_snapshot.get("current", 0.0)), second.health, "Das aggregierte aktuelle Leben enthält nur noch den verbleibenden Boss")
	_near(float(remaining_snapshot.get("maximum", 0.0)), float(initial_snapshot.get("maximum", 0.0)), "Das aggregierte Maximum bleibt über beide Bosse stabil")
	_equal(int(remaining_snapshot.get("remaining", 0)), 1, "Boss-HUD meldet nach dem ersten Tod einen verbleibenden Boss")

	second.take_damage(second.health)
	_equal(finish_events[0], 1, "Der zweite Bosstod beendet den Lauf genau einmal")
	_true(bool(finish_success[0]), "Der finale Bosstod beendet den Lauf erfolgreich")
	_false(game.state.active, "RunState ist nach dem finalen Boss beendet")
	_true(game.state.boss_defeated, "Der finale Bossvertrag ist abgeschlossen")
	_equal(game.state.bosses_defeated, 2, "RunState zählt exakt beide Bosse")
	_equal(game.active_boss_handle_snapshot().size(), 0, "Nach dem finalen Tod bleiben keine Boss-Handles")
	_false(game.state.mark_boss_defeated(), "Eine verspätete Bossmeldung kann den beendeten Lauf nicht erneut abschließen")
	_equal(finish_events[0], 1, "Verspätete Bossmeldungen emittieren kein zweites Ergebnis")

	game.queue_free()
	await process_frame


func _assert_trait_config(game: Node, trait_id: StringName, property_name: String, expected: float) -> void:
	game.config = RunConfig.from_level(game.selected_level)
	game._apply_case_trait_to_config(trait_id)
	_near(float(game.config.get(property_name)), expected, "Fallmerkmal %s kompiliert %s zentral in RunConfig" % [String(trait_id), property_name])
	if trait_id == &"monster_health_15":
		_near(game.config.enemy_health_end, game.selected_level.enemy_health_end * 1.15, "Robuste Erreger skalieren auch das spätere Gegnerleben")
		_near(game.config.boss_health_multiplier, game.selected_level.boss_health_multiplier * 1.15, "Robuste Erreger skalieren ausdrücklich auch Bossleben")


func _level_by_id(levels: Array[LevelDefinition], id: StringName) -> LevelDefinition:
	for level in levels:
		if level.id == id:
			return level
	return null


func _sorted_string_names(values: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for value in values:
		result.append(String(value))
	result.sort()
	return result


func _true(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)


func _false(value: bool, message: String) -> void:
	_true(not value, message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String) -> void:
	assertions += 1
	if not is_equal_approx(actual, expected):
		failures.append("%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_CASE_MODIFIER_RUNTIME_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("ALVEOLUS_CASE_MODIFIER_RUNTIME_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
	quit(1)
